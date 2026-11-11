class_name StartMenu
extends Control
## 시작 화면 (v0.7.0 2c, 시안 01 "스타트 A"): 멈춘 게임 화면 위에 오른쪽 종이 카드 메뉴 + 위쪽 정보 띠 3개.
## 카드: 큰 [시작] · 부스터 칸 3개 · [상점] [미션]. 버튼이 아닌 빈 곳 터치·스페이스도 시작(World.start_pressed).
## 카드는 오른쪽에서 부드럽게 들어오고 [시작]을 누르면 오른쪽으로 빠진다.

signal start
signal open_shop(tab: String)
signal open_missions

const CARD_W := 400.0
const SLIDE_TIME := 0.32

var main: Node
var boosters: BoosterSlots
var card := Control.new()
var _best := UiKit.label("0", 40)
var _wallet := UiKit.label("0", 40)
var _rank_name := UiKit.label("", 26)
var _rank_bar := Control.new()
var _mission_dot := UiKit.badge()
var _bands := HBoxContainer.new()


func _init(main_node: Node) -> void:
	main = main_node
	name = "StartMenu"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	_build_bands()
	_build_card()
	refresh()


func _band(art: Texture2D, value: Control, width: float) -> Control:
	var band := UiKit.paper("cream")
	band.custom_minimum_size = Vector2(width, 84)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	row.offset_left = 18
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiKit.icon(art, 60))
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	band.add_child(row)
	return band


func _build_bands() -> void:
	_bands.name = "Bands"
	_bands.position = Vector2(24, 18)
	_bands.add_theme_constant_override("separation", 16)
	_bands.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bands.add_child(_band(UiKit.ICONS.star, _best, 250))
	_bands.add_child(_band(UiKit.ICONS.fish, _wallet, 250))
	# 등급: 배지 + 이름 + 경험치 막대
	var rank := VBoxContainer.new()
	rank.add_theme_constant_override("separation", 0)
	rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank.add_child(_rank_name)
	_rank_bar.custom_minimum_size = Vector2(190, 24)
	_rank_bar.draw.connect(func() -> void:
		var r: Dictionary = main.save.data.rank
		UiKit.draw_bar(_rank_bar, Rect2(Vector2(4, 4), _rank_bar.size - Vector2(8, 8)), float(r.xp) / CatRank.next_xp(r.level), UiKit.GREEN))
	rank.add_child(_rank_bar)
	_bands.add_child(_band(UiKit.ICONS.rank_face, rank, 300))
	add_child(_bands)


func _build_card() -> void:
	card.name = "Card"
	card.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	card.offset_left = -CARD_W - 28
	card.offset_right = -28
	card.offset_top = 118
	card.offset_bottom = -64  # 오른쪽 아래 버전 글자와 겹치지 않게
	var paper := UiKit.paper("panel")
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(paper)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 30)
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)
	box.add_child(UiKit.label("지붕 위의 고냥이", 42, UiKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER))
	var go := UiKit.button("시작", "orange", null, 68)
	go.name = "Start"
	go.custom_minimum_size = Vector2(0, 118)
	go.pressed.connect(func() -> void: start.emit())
	box.add_child(go)
	boosters = BoosterSlots.new(main)
	boosters.alignment = BoxContainer.ALIGNMENT_CENTER
	boosters.want_shop.connect(func() -> void: open_shop.emit("boosters"))
	box.add_child(boosters)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for pair in [["Shop", "상점", "basket"], ["Missions", "미션", "note_check"]]:
		var b := UiKit.button(pair[1], "cream", UiKit.ICONS[pair[2]], 40)
		b.name = pair[0]
		b.custom_minimum_size = Vector2(0, 100)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	row.get_node("Shop").pressed.connect(func() -> void: open_shop.emit("upgrades"))
	row.get_node("Missions").pressed.connect(func() -> void: open_missions.emit())
	# 받을 미션 보상 수 (빨간 동그라미)
	_mission_dot.position = Vector2(-10, -12)
	row.get_node("Missions").add_child(_mission_dot)
	add_child(card)


## 값 다시 쓰기 (화면을 열 때·사거나 받은 뒤)
func refresh() -> void:
	var save: SaveData = main.save
	_best.text = UiKit.comma(save.best_score())
	_wallet.text = UiKit.comma(save.fish())
	var r: Dictionary = save.data.rank
	_rank_name.text = "%s %d등급" % [CatRank.rank_name(r.level), r.level]
	_rank_bar.queue_redraw()
	UiKit.badge_text(_mission_dot, Missions.pending(save.data))
	boosters.refresh()


## 카드를 오른쪽으로 밀어 둔 거리 (0 = 제자리). 앵커 여백을 옮겨 화면 넓이와 상관없이 맞음
func _shift(x: float) -> void:
	card.offset_left = -CARD_W - 28 + x
	card.offset_right = -28 + x


## 카드가 오른쪽에서 들어옴
func slide_in() -> void:
	visible = true
	refresh()
	_shift(CARD_W + 60.0)
	var tween := card.create_tween()
	tween.tween_method(_shift, CARD_W + 60.0, 0.0, SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bands.modulate.a = 0.0
	_bands.create_tween().tween_property(_bands, "modulate:a", 1.0, SLIDE_TIME)


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
