class_name BoosterSlots
extends HBoxContainer
## 부스터 칸 3개 (시작 화면·결과 카드가 같이 씀, PLAN 1번): 아이콘 + 가진 개수. 누르면 켜짐/꺼짐(여러 개 같이).
## 0개인 칸을 누르면 want_shop (상점 부스터 탭으로). 켠 목록은 main.boosters_on 하나뿐이고 판이 시작될 때 main이 줄인다.

signal want_shop
signal toggled_on(kind: String, on: bool)

const KINDS := ["dash_start", "bell_start", "fish_bonus"]
const SIZE := 100.0

var main: Node
var _slots := {}   # 종류 → Button
var _counts := {}  # 종류 → Label


func _init(main_node: Node) -> void:
	main = main_node
	name = "BoosterSlots"
	add_theme_constant_override("separation", 10)
	for kind: String in KINDS:
		var b := UiKit.button("", "cream")
		b.name = kind
		b.custom_minimum_size = Vector2(SIZE, SIZE)
		var art := UiKit.icon(UiKit.ICONS[kind], SIZE - 50.0)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 20  # 위 가운데: 아래 개수 글자와 겹치지 않고 둥근 테두리 안에
		art.offset_top = 6
		art.offset_right = -20
		art.offset_bottom = -44
		b.add_child(art)
		var count := UiKit.label("0", 30, UiKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER)  # 휴대폰(0.54배)에서도 읽히게
		count.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 9)  # 아래 가운데 (둥근 테두리 안)
		count.grow_horizontal = Control.GROW_DIRECTION_BOTH
		count.grow_vertical = Control.GROW_DIRECTION_BEGIN
		b.add_child(count)
		b.pressed.connect(press.bind(kind))
		add_child(b)
		_slots[kind] = b
		_counts[kind] = count


## 칸 누름: 가진 게 없으면 상점으로, 있으면 켜고 끔
func press(kind: String) -> void:
	var on: Array = main.boosters_on
	if main.save.booster_count(kind) <= 0:
		want_shop.emit()
		return
	if on.has(kind):
		on.erase(kind)
	else:
		on.append(kind)
	toggled_on.emit(kind, on.has(kind))
	UiKit.pop(_slots[kind], 0.15)
	refresh()


## 개수·켜짐을 다시 그린다 (켠 칸은 주황 종이 + 진하게, 0개는 흐리게)
func refresh() -> void:
	for kind: String in KINDS:
		var n: int = main.save.booster_count(kind)
		var b: Button = _slots[kind]
		var lit: bool = main.boosters_on.has(kind) and n > 0
		var style := "orange" if lit else "cream"
		for state in ["normal", "hover"]:
			b.add_theme_stylebox_override(state, UiKit._box(style))
		_counts[kind].text = "x%d" % n
		b.modulate = Color(1, 1, 1, 1.0 if n > 0 else 0.55)
