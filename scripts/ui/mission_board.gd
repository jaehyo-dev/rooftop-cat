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
const NOTE := Vector2(372, 226)
const CONFIRM_TIME := 2.5  # 바꾸기 "정말?"이 기다리는 시간
const COUNT_W := 150.0     # 진행 숫자 칸 넓이 (막대는 그 왼쪽)

var _rank := Control.new()
var _rank_label := UiKit.label("", 34)
var _headers := [UiKit.label("", 28), UiKit.label("", 28)]
var _notes := []         # [weekly, slot] 순서로 6장 Control
var _confirm := {"key": "", "t": 0.0}  # 바꾸기 확인 중인 쪽지 ("d0" 등)
var _stamped := {}       # 이번에 받아 도장을 찍을 쪽지 key


func _init(main_node: Node) -> void:
	super(main_node, "Missions")
	# 등급 리본
	_rank.name = "Rank"
	_rank.position = Vector2(150, 10)
	_rank.size = Vector2(780, 96)
	_rank.draw.connect(_draw_rank)
	_rank_label.position = Vector2(112, 4)
	_rank_label.size = Vector2(620, 44)
	_rank.add_child(_rank_label)
	var face := UiKit.icon(UiKit.ICONS.rank_face, 92)
	face.position = Vector2(6, 2)
	face.size = Vector2(92, 92)
	_rank.add_child(face)
	box.add_child(_rank)
	# 코르크판
	var cork := UiKit.paper("cork")
	cork.name = "Cork"
	cork.position = Vector2(14, 108)
	cork.size = Vector2(1252, 608)
	box.add_child(cork)
	# 머리글: 나무 테두리·코르크 무늬 위에서도 읽히게 크림색 이름표 안에 (압정보다 위, 2c-fix)
	for i in 2:
		var tag := Panel.new()
		tag.name = "Header%d" % i
		tag.position = Vector2(56, 110 + i * 300)
		tag.size = Vector2(300, 40)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = UiKit.CREAM
		style.border_color = UiKit.BROWN
		style.set_border_width_all(3)
		style.set_corner_radius_all(18)
		style.anti_aliasing = true
		tag.add_theme_stylebox_override("panel", style)
		var h: Label = _headers[i]
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		tag.add_child(h)
		box.add_child(tag)
	for i in 6:
		var note := Control.new()
		note.name = "Note%d" % i
		note.position = Vector2(64 + (i % 3) * (NOTE.x + 22), 170 + (i / 3) * 300)
		note.size = NOTE
		box.add_child(note)
		_notes.append(note)


func _key(weekly: bool, slot: int) -> String:
	return ("w" if weekly else "d") + str(slot)


func refresh() -> void:
	var data: Dictionary = main.save.data
	var r: Dictionary = data.rank
	_rank_label.text = "%s  %d등급    %s / %s" % [CatRank.rank_name(r.level), r.level, UiKit.comma(r.xp), UiKit.comma(CatRank.next_xp(r.level))]
	UiKit.fit(_rank_label, _rank_label.size.x, 34)
	_rank.queue_redraw()
	var now: Dictionary = main.clock.now()
	_headers[0].text = "오늘의 미션   (남은 시간 %s)" % DayClock.left_text(DayClock.seconds_to_next_day(now))
	_headers[1].text = "이번 주 미션   (남은 시간 %s)" % DayClock.left_text(DayClock.seconds_to_next_week(now))
	for h: Label in _headers:
		h.get_parent().size.x = UiKit.FONT.get_string_size(h.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 40.0  # 이름표는 글 길이에 맞춤
	for i in 6:
		_fill_note(_notes[i], i >= 3, i % 3)


func _draw_rank() -> void:
	var level: int = main.save.data.rank.level
	UiKit.draw_rank_ring(_rank, Vector2(52, 48), 40.0, level)
	var k := float(main.save.data.rank.xp) / CatRank.next_xp(level)
	UiKit.draw_bar(_rank, Rect2(116, 54, 620, 26), k, Color("#e98a7a"))


## 쪽지 한 장을 다시 만든다
func _fill_note(note: Control, weekly: bool, slot: int) -> void:
	for child in note.get_children():
		note.remove_child(child)
		child.queue_free()
	var list: Array = main.save.data.missions.weekly if weekly else main.save.data.missions.daily
	if slot >= list.size():
		return
	var entry: Dictionary = list[slot]
	var row: Dictionary = MissionTable.WEEKLY[entry.id] if weekly else MissionTable.DAILY[entry.id]
	var reward := Missions.reward(entry.id)
	var key := _key(weekly, slot)
	var paper := UiKit.paper("note")
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	note.add_child(paper)
	var pin := UiKit.icon(UiKit.PIN_RED if not weekly else UiKit.PIN_YELLOW, 34)
	pin.position = Vector2(NOTE.x * 0.5 - 17, -18)
	note.add_child(pin)
	var art := UiKit.icon(UiKit.ICONS[STAT_ICONS.get(row.stat, "note_check")], 58)
	art.position = Vector2(20, 22)
	note.add_child(art)
	var text := UiKit.label(UiKit.wrap(Missions.text(entry.id), 29, NOTE.x - 104), 29)  # 띄어쓰기에서만 줄바꿈
	text.position = Vector2(88, 14)
	text.size = Vector2(NOTE.x - 104, 76)
	note.add_child(text)
	# 진행 막대 + 숫자
	var bar := Control.new()
	bar.position = Vector2(24, 94)
	bar.size = Vector2(NOTE.x - 48, 32)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		UiKit.draw_bar(bar, Rect2(0, 6, bar.size.x - COUNT_W - 10, 20), float(entry.progress) / entry.target, UiKit.GREEN if entry.done else Color("#f0a04b")))
	var count := UiKit.label("%s/%s" % [UiKit.comma(entry.progress), UiKit.comma(entry.target)], 26, UiKit.BROWN, HORIZONTAL_ALIGNMENT_RIGHT)
	UiKit.fit(count, COUNT_W, 26)  # 99,999/99,999도 칸 안에
	count.position = Vector2(bar.size.x - COUNT_W, 0)
	count.size = Vector2(COUNT_W, 32)
	bar.add_child(count)
	note.add_child(bar)
	# 보상
	var gift := HBoxContainer.new()
	gift.position = Vector2(18, NOTE.y - 100)
	gift.size = Vector2(176, 88)
	gift.add_theme_constant_override("separation", 4)
	gift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gift.add_child(UiKit.icon(UiKit.ICONS.fish, 40))
	gift.add_child(UiKit.label(UiKit.comma(reward.fish), 28))
	gift.add_child(UiKit.label("+%d" % reward.xp, 22, Color("#c0605a")))  # 등급 경험치
	note.add_child(gift)
	# 버튼: 받기 / 바꾸기 / (받음 = 도장)
	if Missions.can_claim(entry):
		var take := UiKit.button("받기", "orange", null, 38)
		take.name = "Claim"
		take.position = Vector2(NOTE.x - 168, NOTE.y - 100)
		take.size = Vector2(150, UiKit.MIN_BUTTON)
		take.pressed.connect(claim.bind(weekly, slot))
		note.add_child(take)
	elif entry.done:
		var stamp := UiKit.icon(UiKit.ICONS.stamp, 96)
		stamp.name = "Stamp"
		stamp.position = Vector2(NOTE.x - 132, NOTE.y - 100)  # 진행 숫자 아래 (겹치지 않게)
		stamp.size = Vector2(96, 96)
		stamp.pivot_offset = stamp.size * 0.5  # 가운데를 축으로 기울임
		stamp.rotation = -0.2
		stamp.modulate = Color(1, 1, 1, 0.9)
		note.add_child(stamp)
		if _stamped.has(key):
			_stamped.erase(key)
			UiKit.stamp(stamp)
	elif Missions.can_swap(main.save.data, weekly, slot):
		var price := Missions.swap_price(main.save.data, weekly)
		var asking: bool = _confirm.key == key
		# 값을 먼저 보여 주고, 한 번 누르면 "정말?" (진행이 사라지므로)
		var swap := UiKit.button("정말?" if asking else UiKit.comma(price), "orange" if asking else "cream", UiKit.ICONS.swap, 28)
		swap.name = "Swap"
		swap.add_theme_constant_override("icon_max_width", 34)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var style: StyleBoxTexture = swap.get_theme_stylebox(state)
			style.content_margin_left = 14.0
			style.content_margin_right = 14.0
		swap.position = Vector2(NOTE.x - 168, NOTE.y - 100)
		swap.size = Vector2(150, UiKit.MIN_BUTTON)
		swap.pressed.connect(swap_pressed.bind(weekly, slot))
		note.add_child(swap)


## 받기: 생선이 지갑으로 날아가고 도장이 쾅
func claim(weekly: bool, slot: int) -> void:
	var before: int = main.save.fish()
	var got := Missions.claim(main.save.data, weekly, slot)
	if got <= 0:
		return
	main.save.save()
	main.play_ui("claim")
	set_wallet(before)  # 날아온 생선만큼 여기서부터 차오름
	var note: Control = _notes[slot + (3 if weekly else 0)]
	fly_to_wallet(note.position + Vector2(90, NOTE.y - 54), got)
	_stamped[_key(weekly, slot)] = true
	_fill_note(note, weekly, slot)
	main.refresh_menus()


## 바꾸기: 첫 번째는 "정말?"으로 묻고, CONFIRM_TIME 안에 한 번 더 누르면 생선을 내고 바꾼다
func swap_pressed(weekly: bool, slot: int) -> void:
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
	note.pivot_offset = NOTE * 0.5
	note.scale = Vector2(0.05, 1.0)
	note.create_tween().tween_property(note, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _confirm.key != "":
		_confirm.t += delta
		if _confirm.t > CONFIRM_TIME:
			_confirm = {"key": "", "t": 0.0}
			refresh()
