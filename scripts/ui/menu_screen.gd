class_name MenuScreen
extends Control
## 상점·미션 화면의 공통 틀: 멈춘 게임 화면 위 크림 가림막, 가운데 1280x720 상자(휴대폰 1558 넓이에서도 가운데),
## 왼쪽 위 [뒤로], 오른쪽 위 지갑(빨래집게로 꽂은 종이, 생선이 날아와 닿으면 숫자가 차오름).
## 열 때 아래에서 살짝 올라오며 나타나고, 닫을 때 흐려지며 사라진다.

signal back

const BOX := Vector2(1280, 720)
const OPEN_TIME := 0.25
const WALLET_RIGHT := 64.0  # 지갑 오른쪽 집게 자리

var main: Node
var box := Control.new()
var wallet := Control.new()
var _wallet_label := UiKit.label("0", 40)
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
	veil.color = Color(1, 0.96, 0.9, 0.55)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:  # 화면이 흔들려도 가장자리가 비지 않게 넉넉히
		veil.set_offset(side, -20.0)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		veil.set_offset(side, 20.0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	box.name = "Box"
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -BOX.x * 0.5
	box.offset_right = BOX.x * 0.5
	box.offset_top = -BOX.y * 0.5
	box.offset_bottom = BOX.y * 0.5
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var back_button := UiKit.button("", "cream", UiKit.ICONS.back)
	back_button.name = "Back"
	back_button.add_theme_constant_override("icon_max_width", 56)
	back_button.position = Vector2(20, 14)
	back_button.size = Vector2(UiKit.MIN_BUTTON + 12, UiKit.MIN_BUTTON)
	back_button.pressed.connect(func() -> void: back.emit())
	box.add_child(back_button)
	wallet.name = "Wallet"
	wallet.position = Vector2(BOX.x - 310, 14)
	wallet.size = Vector2(290, 88)
	var tag := UiKit.paper("cream")
	tag.set_anchors_preset(Control.PRESET_FULL_RECT)
	wallet.add_child(tag)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	row.offset_left = 22
	row.offset_right = -WALLET_RIGHT  # 오른쪽 위 집게 자리는 비움
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiKit.icon(UiKit.ICONS.fish, 64))
	_wallet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_wallet_label)
	wallet.add_child(row)
	var clip := UiKit.icon(UiKit.CLIP, 56)
	clip.position = Vector2(wallet.size.x - 60, -14)
	wallet.add_child(clip)
	box.add_child(wallet)


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
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, OPEN_TIME)
	tween.tween_property(box, "offset_top", -BOX.y * 0.5, OPEN_TIME).from(-BOX.y * 0.5 + 40.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(box, "offset_bottom", BOX.y * 0.5, OPEN_TIME).from(BOX.y * 0.5 + 40.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
	UiKit.fit(_wallet_label, wallet.size.x - 22 - 64 - 4 - WALLET_RIGHT, 40)


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
	return wallet.position + Vector2(50, 44)


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
