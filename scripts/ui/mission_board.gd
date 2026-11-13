class_name MissionBoard
extends MenuScreen
## 미션 (v0.7.0 2c, 시안 08 "미션 b"): 위에 등급 리본(배지·이름·경험치 막대), 코르크 게시판에 일일 3장·주간 3장 쪽지.
## 쪽지: 아이콘, 문구, 진행 막대 + 숫자, 보상(생선·경험치), 버튼 하나(깸 → [받기] / 진행 중 → [바꾸기 값]).
## 바꾸기는 생선이 들고 진행이 사라져서 한 번 더 눌러야 바뀐다("정말?"). 받으면 생선이 지갑으로 날아가고 발바닥 도장이 쾅.
## 미션 판단은 Missions(claim·swap·can_swap)가 한다.

## 미션 값 이름(MissionTable stat) → 아이콘
const STAT_ICONS := {"meters": "footprints", "fish": "fish", "combo": "combo", "mult": "combo", "stage": "speed", "stage_ups": "speed",
		"dash": "snack", "smash": "smash", "smash_one": "smash", "double": "jump", "pole": "jump", "tramp": "tramp", "perfect": "tramp",
		"gold": "gold", "yarn": "yarn", "can": "can", "bell": "bell", "runs": "rank_face", "daily_done": "note_check",
		"full_day": "note_check", "shop": "basket", "pass_flock": "jump", "pass_pot": "jump", "pass_tank": "jump", "pass_ac": "jump"}
const NOTE := Vector2(368, 212)  # 쪽지 (그림자 포함)
const NOTE_GAP := 32.0
const CORK := Rect2(16, 116, 1248, 600)
const ROWS_Y := [144.0, 420.0]   # 게시판 안쪽(나무 테두리 12px 안)에 위아래 여백 16   # 머리글 위 (일일·주간), 쪽지는 그 아래 HEAD_H + GAP
const HEAD_H := 48.0
const PIN := Vector2(UiKit.GAP, -UiKit.PAD)  # 압정: 쪽지 왼쪽 위 모서리 (글자·머리글을 가리지 않게)
const PIN_SIZE := 40.0
const CONFIRM_TIME := 2.5  # 바꾸기 "정말?"이 기다리는 시간
const COUNT_W := 144.0     # 진행 숫자 칸 넓이 (막대는 그 왼쪽)
const RANK_TEXT_X := 96.0
const RANK_TEXT_W := 680.0
const WOBBLE := 0.017      # 약 1도      # 받을 쪽지 흔들림 (라디안)
const WOBBLE_TIME := 1.6

var _rank := Control.new()
var _rank_label := UiKit.label("", UiKit.BODY)
var _rank_xp := UiKit.label("", UiKit.SUB, UiKit.SUB_BROWN, HORIZONTAL_ALIGNMENT_RIGHT)
var _headers := [UiKit.label("", UiKit.SUB, UiKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER), UiKit.label("", UiKit.SUB, UiKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER)]
var _notes := []         # [weekly, slot] 순서로 6장 Control
var _confirm := {"key": "", "t": 0.0}  # 바꾸기 확인 중인 쪽지 ("d0" 등)
var _stamped := {}       # 이번에 받아 도장을 찍을 쪽지 key → 받은 생선
var _seen_level := 0     # 지난번 열었을 때 등급 (오르면 열 때 배지를 쿵)
var _face: TextureRect
var _wobble_t := 0.0


func _init(main_node: Node) -> void:
	super(main_node, "Missions")
	# 등급: 링 배지 + 이름 + 경험치 막대 (뒤로·지갑 사이)
	_rank.name = "Rank"
	_rank.position = Vector2(EDGE + TOP_H + UiKit.GAP * 3.0, EDGE)
	_rank.size = Vector2(808, TOP_H)
	_rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := UiKit.panel("chip")  # 등급도 양옆(뒤로·지갑)처럼 알약 판 안에
	chip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rank.add_child(chip)
	var ring := Control.new()
	ring.name = "Ring"
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(_draw_rank.bind(ring))
	_rank.add_child(ring)
	_rank_label.position = Vector2(RANK_TEXT_X, 6)
	_rank_label.size = Vector2(RANK_TEXT_W - 200, 40)
	_rank.add_child(_rank_label)
	_rank_xp.position = Vector2(RANK_TEXT_X + RANK_TEXT_W - 200, 8)
	_rank_xp.size = Vector2(200, 36)
	_rank.add_child(_rank_xp)
	_face = UiKit.icon(UiKit.ICONS.rank_face, 56)
	_face.position = Vector2(UiKit.PAD + 4, (TOP_H - UiKit.SHADOW_Y - 56) * 0.5)
	_rank.add_child(_face)
	box.add_child(_rank)
	# 코르크판
	var cork := UiKit.panel("cork")
	cork.name = "Cork"
	cork.position = CORK.position
	cork.size = CORK.size
	box.add_child(cork)
	var x0 := CORK.position.x + (CORK.size.x - 3.0 * NOTE.x - 2.0 * NOTE_GAP) * 0.5
	for i in 2:
		var tag := UiKit.panel("chip", false)  # 그림자 없이 (높이를 글자에 다 씀)
		tag.name = "Header%d" % i
		tag.position = Vector2(x0 + PIN.x + PIN_SIZE + UiKit.GAP, ROWS_Y[i])  # 첫 쪽지 압정 오른쪽부터
		tag.size = Vector2(320, HEAD_H)
		var h: Label = _headers[i]
		h.position = Vector2(UiKit.PAD, 0)
		tag.add_child(h)
		box.add_child(tag)
	for i in 6:
		var note := Control.new()
		note.name = "Note%d" % i
		note.position = Vector2(x0 + (i % 3) * (NOTE.x + NOTE_GAP), ROWS_Y[i / 3] + HEAD_H + UiKit.GAP)
		note.size = NOTE
		note.pivot_offset = PIN + Vector2(PIN_SIZE * 0.5, PIN_SIZE * 0.5)  # 압정을 축으로 흔들림
		box.add_child(note)
		_notes.append(note)


func _key(weekly: bool, slot: int) -> String:
	return ("w" if weekly else "d") + str(slot)


func refresh() -> void:
	finish_fx()  # 쪽지를 다시 만들기 전에 도장·생선 연출을 끝냄 (도장이 사라져 지갑이 덜 찬 채 남지 않게)
	var data: Dictionary = main.save.data
	var r: Dictionary = data.rank
	_rank_label.text = "%s  %d등급" % [CatRank.rank_name(r.level), r.level]
	UiKit.fit(_rank_label, _rank_label.size.x, UiKit.BODY)
	_rank_xp.text = "경험치 %s/%s" % [UiKit.comma(r.xp), UiKit.comma(CatRank.next_xp(r.level))]
	UiKit.fit(_rank_xp, _rank_xp.size.x, UiKit.SUB)
	_rank.get_node("Ring").queue_redraw()
	var now: Dictionary = main.clock.now()
	_headers[0].text = "오늘의 미션   (남은 시간 %s)" % DayClock.left_text(DayClock.seconds_to_next_day(now))
	_headers[1].text = "이번 주 미션   (남은 시간 %s)" % DayClock.left_text(DayClock.seconds_to_next_week(now))
	for h: Label in _headers:  # 이름표는 글 길이에 맞춤
		h.size = Vector2(ceilf(UiKit.FONT.get_string_size(h.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SUB).x), HEAD_H)
		h.get_parent().size.x = h.size.x + UiKit.PAD * 2.0
	for i in 6:
		_fill_note(_notes[i], i >= 3, i % 3)


func _draw_rank(ring: Control) -> void:
	var level: int = main.save.data.rank.level
	UiKit.draw_rank_ring(ring, Vector2(UiKit.PAD + 32, (TOP_H - UiKit.SHADOW_Y) * 0.5), 26.0, level)
	var k := float(main.save.data.rank.xp) / CatRank.next_xp(level)
	UiKit.draw_bar(ring, Rect2(RANK_TEXT_X, 48, RANK_TEXT_W, 22), k, UiKit.ORANGE)


## 쪽지 한 장을 다시 만든다
func _fill_note(note: Control, weekly: bool, slot: int) -> void:
	for child in note.get_children():
		note.remove_child(child)
		child.queue_free()
	note.rotation = 0.0
	note.set_meta("wobble", false)
	var list: Array = main.save.data.missions.weekly if weekly else main.save.data.missions.daily
	if slot >= list.size():
		return
	var entry: Dictionary = list[slot]
	var row: Dictionary = MissionTable.WEEKLY[entry.id] if weekly else MissionTable.DAILY[entry.id]
	var reward := Missions.reward(entry.id)
	var key := _key(weekly, slot)
	var paper := UiKit.panel("note")
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	note.add_child(paper)
	var pin := UiKit.icon(UiKit.PIN_RED if not weekly else UiKit.PIN_YELLOW, PIN_SIZE)
	pin.position = PIN
	note.add_child(pin)
	var base := UiKit.icon_base(UiKit.ICONS[STAT_ICONS.get(row.stat, "note_check")], UiKit.BASE_S)
	base.position = Vector2(UiKit.PAD, UiKit.PAD)
	note.add_child(base)
	var text_x := UiKit.PAD * 2.0 + UiKit.BASE_S
	var text := UiKit.label("")
	text.position = Vector2(text_x, 12)
	text.size = Vector2(NOTE.x - text_x - UiKit.PAD, 72)  # 아이콘 받침과 같은 세로 가운데
	UiKit.wrap_fit(text, Missions.text(entry.id), text.size.x, 2, UiKit.BODY)  # 띄어쓰기에서만 줄바꿈, 두 줄 안
	note.add_child(text)
	# 진행 막대 + 숫자
	var bar := Control.new()
	bar.position = Vector2(UiKit.PAD, 82)
	bar.size = Vector2(NOTE.x - UiKit.PAD * 2.0, 32)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		UiKit.draw_bar(bar, Rect2(0, 3, bar.size.x - COUNT_W - UiKit.GAP, 26), float(entry.progress) / entry.target, UiKit.GREEN if entry.done else UiKit.ORANGE))
	var count := UiKit.label("%s/%s" % [UiKit.comma(entry.progress), UiKit.comma(entry.target)], UiKit.SUB, UiKit.SUB_BROWN, HORIZONTAL_ALIGNMENT_RIGHT)
	UiKit.fit(count, COUNT_W, UiKit.SUB)  # 99,999/99,999도 칸 안에
	count.position = Vector2(bar.size.x - COUNT_W, 1)  # 막대와 같은 높이 (글자 모양이 위로 치우쳐 1px 내림)
	count.size = Vector2(COUNT_W, 32)
	bar.add_child(count)
	note.add_child(bar)
	# 보상: 생선 + 숫자, 아래 경험치
	var bottom := NOTE.y - UiKit.SHADOW_Y - UiKit.GAP - UiKit.MIN_BUTTON  # 아래 줄 위 (버튼과 같은 높이)
	var fish := UiKit.icon(UiKit.ICONS.fish, 40)
	fish.position = Vector2(UiKit.PAD, bottom + 4)
	note.add_child(fish)
	var gift := UiKit.label(UiKit.comma(reward.fish), UiKit.NUM)
	gift.position = Vector2(UiKit.PAD + 48, bottom)
	gift.size = Vector2(120, 48)
	UiKit.fit(gift, gift.size.x, UiKit.NUM)
	note.add_child(gift)
	# 등급 경험치는 미션을 깬 순간 들어옴 (받기는 생선만). 깬 쪽지는 "받음"으로 (받기 뒤 경험치가 안 오르는 것처럼 보이지 않게)
	var xp := UiKit.label(("경험치 +%d 받음" if entry.done else "경험치 +%d") % reward.xp, UiKit.SUB, UiKit.SUB_BROWN)
	xp.position = Vector2(UiKit.PAD, bottom + 52)
	xp.size = Vector2(NOTE.x - UiKit.PAD * 2.0 - 152 - UiKit.GAP, 32)
	UiKit.fit(xp, xp.size.x, UiKit.SUB)
	note.add_child(xp)
	var spot := Vector2(NOTE.x - UiKit.PAD - 152, bottom)
	# 버튼: 받기 / 바꾸기 / (받음 = 도장)
	if Missions.can_claim(entry):
		var take := UiKit.button("받기", "orange")
		take.name = "Claim"
		take.hot = true
		take.position = spot
		take.size = Vector2(152, UiKit.MIN_BUTTON)
		take.pressed.connect(claim.bind(weekly, slot))
		note.add_child(take)
		note.set_meta("wobble", true)  # 받을 쪽지는 살짝 흔들림
	elif entry.done:
		var stamp := UiKit.icon(UiKit.ICONS.stamp, 80)
		stamp.name = "Stamp"
		stamp.position = Vector2(NOTE.x - UiKit.PAD - 100, bottom + UiKit.GAP)
		stamp.pivot_offset = stamp.size * 0.5  # 가운데를 축으로 기울임
		stamp.rotation = -0.2
		stamp.modulate.a = 0.9
		for child in note.get_children():  # 받은 쪽지는 흐리게, 도장만 진하게 (받은 것·안 받은 것이 한눈에)
			if child is CanvasItem and child != pin:
				(child as CanvasItem).modulate.a = UiKit.DONE_ALPHA
		note.add_child(stamp)
		if _stamped.has(key):
			var got: int = _stamped[key]
			_stamped.erase(key)
			track(UiKit.stamp(stamp, -0.2, _stamp_hit.bind(note, stamp, got)))
	elif Missions.can_swap(main.save.data, weekly, slot):
		var price := Missions.swap_price(main.save.data, weekly)
		var asking: bool = _confirm.key == key
		# 값을 먼저 보여 주고, 한 번 누르면 "정말?" (진행이 사라지므로)
		# 보조 버튼: 윗면 빛 없이, "바꾸기" + 생선 가격 두 줄 (받기보다 덜 눈에 띄게, 값이 생선인 걸 보이게)
		var swap := UiKit.button("", "orange" if asking else "cream")
		swap.name = "Swap"
		swap.plate.gloss = 1.0 if asking else 0.0  # 확인("바꿀까요?")은 다른 주황 버튼과 같은 모양
		var top := UiKit.label("바꿀까요?" if asking else "바꾸기", UiKit.SUB, UiKit.CREAM if asking else UiKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER)
		if asking:
			UiKit.on_orange(top)
		top.position = Vector2(UiKit.GAP, UiKit.GAP)
		top.size = Vector2(152 - UiKit.PAD, 34)
		UiKit.fit(top, top.size.x - UiKit.PAD * 2.0, UiKit.SUB)  # 버튼 둥근 끝 안쪽에 맞춤
		swap.add_child(top)
		var cost := HBoxContainer.new()
		cost.alignment = BoxContainer.ALIGNMENT_CENTER
		cost.add_theme_constant_override("separation", int(UiKit.GAP * 0.5))
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost.position = Vector2(UiKit.GAP, 40)
		cost.size = Vector2(152 - UiKit.PAD, 36)
		cost.add_child(UiKit.icon(UiKit.ICONS.fish, 32))
		cost.add_child(UiKit.label(UiKit.comma(price), UiKit.SUB, UiKit.CREAM if asking else UiKit.BROWN))
		swap.add_child(cost)
		swap.position = spot
		swap.size = Vector2(152, UiKit.MIN_BUTTON)
		swap.pressed.connect(swap_pressed.bind(weekly, slot))
		note.add_child(swap)


## 받기 (2c 피드백): 도장이 위에서 휙 내려와 쿵 찍힘(화면 흔들림·잉크) → 생선이 지갑으로 날아가 숫자가 차오름.
## 여러 장을 빨리 받으면 앞 연출을 끝 모습으로 넘기고 바로 다음 쿵
func claim(weekly: bool, slot: int) -> void:
	finish_fx()
	var before: int = main.save.fish()
	var got := Missions.claim(main.save.data, weekly, slot)
	if got <= 0:
		return
	main.save.save()
	main.play_ui("whoosh")
	set_wallet(before)  # 날아온 생선만큼 여기서부터 차오름
	var note: Control = _notes[slot + (3 if weekly else 0)]
	_stamped[_key(weekly, slot)] = got
	_fill_note(note, weekly, slot)
	main.refresh_menus()


func _stamp_hit(note: Control, stamp: Control, got: int) -> void:
	thump(to_box(stamp, stamp.size * 0.5))
	main.play_ui("claim")
	fly_to_wallet(note.position + Vector2(UiKit.PAD + 20, NOTE.y - 64), got)


## 열 때 지난번보다 등급이 올랐으면 리본 배지를 쿵 (판에서 미션을 깨 오른 등급)
func open() -> void:
	super.open()
	var level: int = main.save.data.rank.level
	if _seen_level > 0 and level > _seen_level:
		main.play_ui("whoosh")
		track(UiKit.stamp(_face, 0.0, func() -> void:
			thump(to_box(_face, _face.size * 0.5))
			main.play_ui("rank_up")
			track(UiKit.burst(box, to_box(_face, _face.size * 0.5), 10, "star", 110.0))))
	_seen_level = level


## 바꾸기: 첫 번째는 "정말?"으로 묻고, CONFIRM_TIME 안에 한 번 더 누르면 생선을 내고 바꾼다
func swap_pressed(weekly: bool, slot: int) -> void:
	finish_fx()
	var key := _key(weekly, slot)
	if _confirm.key != key:
		_confirm = {"key": key, "t": 0.0}
		main.play_ui("booster_on")
		refresh()
		return
	_confirm = {"key": "", "t": 0.0}
	var result := Missions.swap(main.save.data, weekly, slot)
	if result == "money":
		main.play_ui("no_money")
		refresh()
		return
	if result != "":
		refresh()
		return
	main.save.save()
	main.play_ui("swap")
	set_wallet(main.save.fish())
	refresh()
	# 쪽지가 뒤집히듯 (가로로 접혔다 펴짐)
	var note: Control = _notes[slot + (3 if weekly else 0)]
	note.scale = Vector2(0.05, 1.0)
	note.create_tween().tween_property(note, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_wobble_t = fmod(_wobble_t + delta, WOBBLE_TIME)
	for note: Control in _notes:
		if note.get_meta("wobble", false):
			note.rotation = WOBBLE * sin(TAU * _wobble_t / WOBBLE_TIME + note.position.x * 0.01)
	if _confirm.key != "":
		_confirm.t += delta
		if _confirm.t > CONFIRM_TIME:
			_confirm = {"key": "", "t": 0.0}
			refresh()
