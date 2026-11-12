class_name MenuScreen
extends Control
## 상점·미션 화면의 공통 틀: 멈춘 게임 화면 위 크림 가림막, 가운데 1280x720 상자(휴대폰 1558 넓이에서도 가운데),
## 왼쪽 위 [뒤로], 오른쪽 위 지갑(알약 칩, 생선이 날아와 닿으면 숫자가 차오름).
## 열 때 요소가 차례로 살짝 올라오며 나타나고(UiKit.enter), 닫을 때 흐려지며 사라진다.

signal back

const BOX := Vector2(1280, 720)
const OPEN_TIME := 0.25
const EDGE := 24.0         # 화면 가장자리 여백 (GAP x 3)
const TOP_H := 96.0        # 위 줄(뒤로·탭·지갑) 높이, 그림자 포함
const WALLET_W := 288.0
const WALLET_RIGHT := 24.0  # 지갑 숫자 오른쪽 여백 (둥근 끝)

var main: Node
var box := Control.new()
var wallet := Control.new()
var _wallet_label := UiKit.label("0", UiKit.NUM)
var _shown_fish := 0.0  # 지갑에 보이는 수 (날아온 생선만큼 차오름)
var _closing: Tween    # 닫는 중 (그 사이 다시 열면 멈춤)
var _fx: Array = []    # 지금 도는 연출 (다음 누름 때 UiKit.finish로 바로 끝냄)


func _init(main_node: Node, screen_name: String) -> void:
	main = main_node
	name = screen_name
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.color = UiKit.VEIL
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:  # 화면이 흔들려도 가장자리가 비지 않게 넉넉히
		veil.set_offset(side, -UiKit.PAD * 2.0)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		veil.set_offset(side, UiKit.PAD * 2.0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	box.name = "Box"
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -BOX.x * 0.5
	box.offset_right = BOX.x * 0.5
	box.offset_top = -BOX.y * 0.5
	box.offset_bottom = BOX.y * 0.5
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # 줄여 그린 아이콘이 계단지지 않게 (자식이 물려받음)
	add_child(box)
	var back_button := UiKit.button("", "cream", UiKit.ICONS.back)
	back_button.name = "Back"
	back_button.add_theme_constant_override("icon_max_width", 56)
	back_button.position = Vector2(EDGE, EDGE)
	back_button.size = Vector2(TOP_H, TOP_H)
	back_button.pressed.connect(func() -> void: back.emit())
	box.add_child(back_button)
	# 지갑: 알약 칩 + 둥근 받침 위 생선 + 숫자, 오른쪽 위에 빨래집게
	wallet.name = "Wallet"
	wallet.size = Vector2(WALLET_W, TOP_H)
	wallet.position = Vector2(BOX.x - EDGE - WALLET_W, EDGE)
	var tag := UiKit.panel("chip")
	tag.set_anchors_preset(Control.PRESET_FULL_RECT)
	wallet.add_child(tag)
	var base := UiKit.icon_base(UiKit.ICONS.fish, UiKit.BASE_S)
	base.position = Vector2(UiKit.GAP, (TOP_H - UiKit.SHADOW_Y - UiKit.BASE_S) * 0.5).round()
	wallet.add_child(base)
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wallet_label.position = Vector2(UiKit.GAP * 2.0 + UiKit.BASE_S, 0)
	_wallet_label.size = Vector2(WALLET_W - _wallet_label.position.x - WALLET_RIGHT, TOP_H - UiKit.SHADOW_Y)
	wallet.add_child(_wallet_label)
	box.add_child(wallet)


## 들어올 때 차례로 나타날 요소 (자식이 바꿈)
func enter_order() -> Array:
	return box.get_children()


func open() -> void:
	if _closing:
		_closing.kill()  # 닫히는 중에 다시 열면 "숨기기"가 나중에 실행되지 않게
		_closing = null
	_set_buttons(Control.MOUSE_FILTER_STOP)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shown_fish = main.save.fish()
	set_wallet(main.save.fish())
	refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, OPEN_TIME * 0.6)
	UiKit.enter(enter_order())


func close() -> void:
	finish_fx()
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 사라지는 동안 뒤 화면 터치를 막지 않게
	_set_buttons(Control.MOUSE_FILTER_IGNORE)
	_closing = create_tween()
	_closing.tween_property(self, "modulate:a", 0.0, OPEN_TIME * 0.6)
	_closing.tween_callback(func() -> void:
		visible = false
		_closing = null)


func _set_buttons(filter: Control.MouseFilter) -> void:
	for b in find_children("*", "Button", true, false):
		(b as Button).mouse_filter = filter


## 화면 내용 다시 그리기 (자식이 채움)
func refresh() -> void:
	pass


## 지갑 숫자를 바로 바꾼다 (사기처럼 줄어들 때)
func set_wallet(fish: int) -> void:
	_shown_fish = fish
	_show_wallet(fish)


func _show_wallet(fish: int) -> void:
	_wallet_label.text = UiKit.comma(fish)
	UiKit.fit(_wallet_label, _wallet_label.size.x, UiKit.NUM)


## 받은 생선이 from(상자 좌표)에서 지갑으로 날아가며 숫자가 차오름. 끝나면 실제 지갑 값
func fly_to_wallet(from: Vector2, amount: int) -> void:
	var count := clampi(amount / 100, 4, 10)
	var step := float(amount) / count
	var target: int = main.save.fish()
	track(UiKit.fly(box, from, wallet_spot(), count, func(i: int) -> void:
		_shown_fish = target if i == count - 1 else _shown_fish + step
		_show_wallet(int(_shown_fish))
		UiKit.pop(wallet, 0.08)))


## 지갑 생선 자리 (상자 좌표)
func wallet_spot() -> Vector2:
	return wallet.position + Vector2(UiKit.GAP + UiKit.BASE_S * 0.5, (TOP_H - UiKit.SHADOW_Y) * 0.5)


## control 안의 점을 상자 좌표로
func to_box(control: Control, local: Vector2) -> Vector2:
	return box.get_global_transform().affine_inverse() * control.get_global_transform() * local


## 연출 기억 (Tween 하나 또는 여러 개)
func track(what: Variant) -> void:
	if what is Array:
		_fx.append_array(what)
	else:
		_fx.append(what)


## 앞 연출을 끝 모습으로 (누를 때마다 먼저 부름: 연출 중에도 바로 다음 누름을 받음)
func finish_fx() -> void:
	for i in 4:  # 끝나며 다음 연출을 거는 것(도장 → 생선)까지
		if _fx.is_empty():
			return
		var list := _fx.duplicate()
		_fx.clear()
		UiKit.finish(list)


## 쿵: 소리 + 화면 흔들림 + at(상자 좌표)에 잉크 방울
func thump(at: Vector2) -> void:
	main.play_ui("thud")
	track(UiKit.shake(self))
	track(UiKit.burst(box, at, 9, "ink", 64.0))
