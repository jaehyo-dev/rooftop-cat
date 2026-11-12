class_name BoosterSlots
extends HBoxContainer
## 부스터 칸 3개 (시작 화면·결과 카드가 같이 씀, PLAN 1번): 아이콘 + 가진 개수. 누르면 켜짐/꺼짐(여러 개 같이).
## 0개인 칸을 누르면 want_shop (상점 부스터 탭으로). 켠 목록은 main.boosters_on 하나뿐이고 판이 시작될 때 main이 줄인다.

signal want_shop
signal toggled_on(kind: String, on: bool)

const KINDS := ["dash_start", "bell_start", "fish_bonus"]
const SIZE := 104.0  # 칸 (그림자 포함)

var main: Node
var _slots := {}   # 종류 → UiButton
var _counts := {}  # 종류 → Label


func _init(main_node: Node) -> void:
	main = main_node
	name = "BoosterSlots"
	add_theme_constant_override("separation", int(UiKit.GAP * 1.5))
	for kind: String in KINDS:
		var b := UiKit.button("", "cream")
		b.name = kind
		b.custom_minimum_size = Vector2(SIZE, SIZE)
		var art := UiKit.icon(UiKit.ICONS[kind], 56)
		art.position = Vector2((SIZE - 56) * 0.5, UiKit.GAP)  # 위 가운데
		b.add_child(art)
		var count := UiKit.label("0", UiKit.SUB, UiKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER)
		count.position = Vector2(UiKit.GAP, SIZE - UiKit.SHADOW_Y - 36 - UiKit.GAP * 0.5)  # 아래 가운데 (둥근 테두리 안)
		count.size = Vector2(SIZE - UiKit.PAD, 36)
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


## 개수·켜짐을 다시 그린다 (켠 칸은 주황 + 크림 글자, 0개는 흐리게)
func refresh() -> void:
	for kind: String in KINDS:
		var n: int = main.save.booster_count(kind)
		var b: UiButton = _slots[kind]
		var lit: bool = main.boosters_on.has(kind) and n > 0
		b.set_fill(UiKit.ORANGE if lit else UiKit.PAPER)
		var count: Label = _counts[kind]
		count.text = "x%d" % n
		count.add_theme_color_override("font_color", UiKit.CREAM if lit else UiKit.BROWN)
		count.add_theme_constant_override("outline_size", UiKit.OUTLINE if lit else 0)
		b.dimmed = n <= 0
