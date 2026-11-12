class_name StartMenu
extends Control
## 시작 화면 (v0.7.0 2c, 시안 01 "스타트 A", 2c-polish): 멈춘 게임 화면 위에 오른쪽 카드 메뉴 + 위쪽 정보 띠 3개(알약 칩 + 둥근 받침 아이콘).
## 카드: 큰 [시작] · 부스터 칸 3개 · [상점] [미션]. 버튼이 아닌 빈 곳 터치·스페이스도 시작(World.start_pressed).
## 카드는 오른쪽에서 부드럽게 들어오고 [시작]을 누르면 오른쪽으로 빠진다.

signal start
signal open_shop(tab: String)
signal open_missions

const CARD_W := 400.0
const SLIDE_TIME := 0.32
const EDGE := 24.0        # 화면 가장자리 여백
const CARD_TOP := 128.0   # 카드 위 (정보 띠 아래)
const BAND_H := 88.0      # 정보 띠 높이 (그림자 포함)
const BAND := 256.0       # 최고 기록·지갑 띠 넓이
const RANK_BAND := 328.0  # 등급 띠 넓이
const ROLL_TIME := 0.6
const XP_W := 80.0        # 등급 띠 경험치 숫자 칸    # 정보 띠 숫자가 굴러가며 차오르는 시간

var main: Node
var boosters: BoosterSlots
var card := Control.new()
var _best := UiKit.label("0", UiKit.NUM)
var _wallet := UiKit.label("0", UiKit.NUM)
var _rank_name := UiKit.label("", UiKit.SUB)
var _rank_xp := UiKit.label("", UiKit.SUB, UiKit.SUB_BROWN, HORIZONTAL_ALIGNMENT_RIGHT)
var _rank_bar := Control.new()
var _mission_dot := UiKit.badge()
var _shop_dot := UiKit.badge(28.0)  # 새로 살 수 있는 강화 (숫자 없는 점)
var _bands := Control.new()
var _shown := {}   # 띠 글자 → 지금 보이는 수 (굴러가는 중)
var _rolls := {}   # 띠 글자 → Tween


func _init(main_node: Node) -> void:
	main = main_node
	name = "StartMenu"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # 줄여 그린 아이콘이 계단지지 않게


func _ready() -> void:
	_build_bands()
	_build_card()
	refresh()


## 정보 띠: 알약 칩 + 왼쪽 둥근 받침 위 아이콘, 오른쪽에 작은 이름표(caption) + 값 (2c-polish 아트 검토: 기록이 화폐처럼 보임)
func _band(art: Texture2D, value: Control, width: float, x: float, caption: String = "") -> Control:
	var band := Control.new()
	band.position = Vector2(x, 0)
	band.size = Vector2(width, BAND_H)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := UiKit.panel("chip")
	chip.set_anchors_preset(Control.PRESET_FULL_RECT)
	band.add_child(chip)
	var base := UiKit.icon_base(art, UiKit.BASE_S)
	base.position = Vector2(UiKit.GAP, (BAND_H - UiKit.SHADOW_Y - UiKit.BASE_S) * 0.5).round()
	band.add_child(base)
	var text_x := UiKit.GAP * 2.0 + UiKit.BASE_S
	value.position = Vector2(text_x, 0)
	value.size = Vector2(width - text_x - UiKit.PAD * 1.5, BAND_H - UiKit.SHADOW_Y)
	if caption != "":
		var head := UiKit.label(caption, UiKit.SUB, UiKit.SUB_BROWN)
		head.position = Vector2(text_x, 6)
		head.size = Vector2(value.size.x, 28)
		band.add_child(head)
		value.position.y = 34
		value.size.y = 42
	band.add_child(value)
	return band


func _build_bands() -> void:
	_bands.name = "Bands"
	_bands.position = Vector2(EDGE, EDGE)
	_bands.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bands.add_child(_band(UiKit.ICONS.star, _best, BAND, 0.0, "최고 점수"))
	_bands.add_child(_band(UiKit.ICONS.fish, _wallet, BAND, BAND + UiKit.PAD, "가진 생선"))
	# 등급: 이름 + 경험치 막대 (세로 가운데)
	var rank := Control.new()
	rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner_w := RANK_BAND - UiKit.GAP * 2.0 - UiKit.BASE_S - UiKit.PAD * 1.5
	_rank_name.position = Vector2(0, UiKit.GAP)
	_rank_name.size = Vector2(inner_w, 32)
	rank.add_child(_rank_name)
	_rank_xp.position = Vector2(inner_w - XP_W, 38)  # 막대 오른쪽에 경험치 숫자
	_rank_xp.size = Vector2(XP_W, 32)
	rank.add_child(_rank_xp)
	_rank_bar.position = Vector2(0, 46)
	_rank_bar.size = Vector2(inner_w - XP_W - UiKit.GAP, 22)
	rank.add_child(_rank_bar)
	_rank_bar.draw.connect(func() -> void:
		var r: Dictionary = main.save.data.rank
		UiKit.draw_bar(_rank_bar, Rect2(Vector2.ZERO, _rank_bar.size), float(r.xp) / CatRank.next_xp(r.level), UiKit.ORANGE))
	_bands.add_child(_band(UiKit.ICONS.rank_face, rank, RANK_BAND, (BAND + UiKit.PAD) * 2.0))
	add_child(_bands)


func _build_card() -> void:
	card.name = "Card"
	card.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	card.offset_left = -CARD_W - EDGE
	card.offset_right = -EDGE
	card.offset_top = CARD_TOP
	card.offset_bottom = -64  # 오른쪽 아래 버전 글자와 겹치지 않게
	var paper := UiKit.panel("panel")
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(paper)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, UiKit.PAD * 1.5)
	box.offset_bottom = -UiKit.PAD * 1.5 - UiKit.SHADOW_Y
	box.add_theme_constant_override("separation", int(UiKit.PAD))
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)
	var title := Control.new()  # 게임 이름은 리본 위에 (2c-polish 아트 검토: 보통 글씨 한 줄뿐)
	title.name = "Title"
	title.custom_minimum_size = Vector2(0, 72)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.draw.connect(func() -> void:
		var w := title.size.x - UiKit.PAD * 3.0
		UiKit.draw_ribbon(title, Rect2((title.size.x - w) * 0.5, 0, w, 64)))
	var title_text := UiKit.on_orange(UiKit.label("지붕 위의 고냥이", UiKit.TITLE, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	title_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_text.offset_bottom = -8
	UiKit.fit(title_text, CARD_W - UiKit.PAD * 3.0 - UiKit.PAD * 4.0, UiKit.TITLE)  # 리본 띠 안
	title.add_child(title_text)
	box.add_child(title)
	var go := UiKit.button("시작", "orange", null, UiKit.TITLE)
	go.name = "Start"
	go.hot = true  # 가만히 있어도 빛이 지나감 (누를 곳)
	go.custom_minimum_size = Vector2(0, 112)
	go.pressed.connect(func() -> void: start.emit())
	box.add_child(go)
	var slots_head := UiKit.label("부스터 켜고 시작", UiKit.SUB, UiKit.SUB_BROWN, HORIZONTAL_ALIGNMENT_CENTER)
	slots_head.name = "SlotsHead"
	box.add_child(slots_head)
	boosters = BoosterSlots.new(main)
	boosters.alignment = BoxContainer.ALIGNMENT_CENTER
	boosters.want_shop.connect(func() -> void: open_shop.emit("boosters"))
	box.add_child(boosters)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiKit.PAD))
	box.add_child(row)
	for pair in [["Shop", "상점", "basket"], ["Missions", "미션", "note_check"]]:
		var b := UiKit.button(pair[1], "cream", UiKit.ICONS[pair[2]])
		b.name = pair[0]
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	row.get_node("Shop").pressed.connect(func() -> void: open_shop.emit("upgrades"))
	row.get_node("Missions").pressed.connect(func() -> void: open_missions.emit())
	# 받을 미션 보상 수 (빨간 동그라미), 새로 살 수 있는 강화 (빨간 점): 버튼 오른쪽 위
	for pair in [["Missions", _mission_dot], ["Shop", _shop_dot]]:
		var b: Control = row.get_node(pair[0])
		var dot: Control = pair[1]
		b.add_child(dot)
		b.resized.connect(func() -> void: dot.position = Vector2(b.size.x - dot.size.x * 0.75, -dot.size.y * 0.3).round())
	add_child(card)


## 값 다시 쓰기 (화면을 열 때·사거나 받은 뒤). 기록·지갑 숫자는 바뀌면 굴러가며 차오름
func refresh() -> void:
	var save: SaveData = main.save
	_roll(_best, save.best_score())
	_roll(_wallet, save.fish())
	var r: Dictionary = save.data.rank
	_rank_name.text = "%s %d등급" % [CatRank.rank_name(r.level), r.level]
	_rank_xp.text = "%s/%s" % [UiKit.comma(r.xp), UiKit.comma(CatRank.next_xp(r.level))]
	UiKit.fit(_rank_xp, XP_W, UiKit.SUB)
	UiKit.fit(_rank_name, _rank_name.size.x, UiKit.SUB)
	_rank_bar.queue_redraw()
	UiKit.badge_text(_mission_dot, Missions.pending(save.data))
	_shop_dot.visible = main.shop_has_new()
	(_shop_dot.get_child(0) as Label).text = ""
	boosters.refresh()


## 숫자 굴러가기: 보이는 수에서 새 수까지 ROLL_TIME 동안 (처음·같은 수는 바로)
func _roll(label: Label, to: int) -> void:
	var from: int = _shown.get(label, to)
	_shown[label] = to
	if _rolls.has(label) and _rolls[label].is_valid():
		_rolls[label].kill()
	if from == to or not is_visible_in_tree():
		_show_number(label, to)
		return
	var tween := label.create_tween()
	tween.tween_method(func(v: float) -> void: _show_number(label, roundi(v)), float(from), float(to), ROLL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: UiKit.pop(label, 0.12))
	_rolls[label] = tween


func _show_number(label: Label, n: int) -> void:
	label.text = UiKit.comma(n)
	UiKit.fit(label, label.size.x, UiKit.NUM)


## 카드를 오른쪽으로 밀어 둔 거리 (0 = 제자리). 앵커 여백을 옮겨 화면 넓이와 상관없이 맞음
func _shift(x: float) -> void:
	card.offset_left = -CARD_W - EDGE + x
	card.offset_right = -EDGE + x


## 카드가 오른쪽에서 들어옴
func slide_in() -> void:
	visible = true
	refresh()
	_shift(CARD_W + 60.0)
	var tween := card.create_tween()
	tween.tween_method(_shift, CARD_W + 60.0, 0.0, SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bands.modulate.a = 1.0
	UiKit.enter(_bands.get_children(), Vector2(0, -24))  # 띠가 하나씩 위에서 내려옴


## 카드가 오른쪽으로 빠지고 숨음 (판은 바로 시작됨)
func slide_out() -> void:
	var tween := card.create_tween().set_parallel()
	tween.tween_method(_shift, 0.0, CARD_W + 60.0, SLIDE_TIME * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_bands, "modulate:a", 0.0, SLIDE_TIME * 0.6)
	tween.chain().tween_callback(func() -> void:
		visible = false
		_shift(0.0))


## 버튼 자리 (World.touch_blockers): 카드만 막는다. 빈 곳·정보 띠는 시작
func blockers() -> Array[Control]:
	return [card]
