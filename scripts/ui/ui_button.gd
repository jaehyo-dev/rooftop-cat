class_name UiButton
extends Button
## 메뉴 버튼 (v0.7.0 2c-polish): Plate 하나로 네 상태를 그린다. 상태가 바뀌면 UiKit.STATE_TIME 동안 부드럽게 옮겨 간다.
## - 기본 / 누름(몸이 PRESS_Y 내려가고 조금 어두워짐, 글자·안의 그림도 같이) / 불가(흐림) / 강조(hot: 몇 초마다 빛이 지나감)
## - picked: 목록에서 고른 줄 (주황 테두리 + 떠오름). dimmed: 누를 수는 있지만 흐리게 (생선이 모자란 사기 버튼)

var plate := Plate.new()
var hot := false
var picked := false
var dimmed := false
var _press := 0.0
var _pick := 0.0
var _dim := 0.0
var _hover := 0.0
var _shift := 0.0   # 안의 그림을 지금 내려 둔 거리
var _shine_t := 0.0
var _base_fill: Color
var _from_fill: Color   # 채움 색이 바뀔 때 이전 색 (STATE_TIME 동안 섞음)
var _fill_k := 1.0
var _group_key := ""


func _init(fill: Color = UiKit.PAPER, corner: float = UiKit.R_BUTTON) -> void:
	focus_mode = Control.FOCUS_NONE  # 스페이스가 버튼을 누르지 않게 (점프와 겹치지 않게)
	plate.fill = fill
	plate.radius = corner
	plate.gloss = 1.0
	plate.gloss_color = UiKit.ORANGE_LIGHT if fill == UiKit.ORANGE else UiKit.GLOSS
	_base_fill = fill
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		add_theme_stylebox_override(state, plate)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## 채움 색 바꾸기 (켠 부스터 칸 = 주황)
func set_fill(fill: Color) -> void:
	if fill == _base_fill:
		return
	_from_fill = _shown_fill() if is_inside_tree() else fill
	_fill_k = 0.0 if is_inside_tree() else 1.0
	_base_fill = fill
	plate.gloss_color = UiKit.ORANGE_LIGHT if fill == UiKit.ORANGE else UiKit.GLOSS
	_apply()


## 바로 목표 상태로 (처음 그릴 때 0.12초 전환이 보이지 않게)
func settle() -> void:
	_pick = 1.0 if picked else 0.0
	_dim = 1.0 if (disabled or dimmed) else 0.0
	_apply()


func _process(delta: float) -> void:
	_center_group()
	var mode := get_draw_mode()
	var step := delta / UiKit.STATE_TIME
	var press := move_toward(_press, 1.0 if mode in [DRAW_PRESSED, DRAW_HOVER_PRESSED] else 0.0, step)
	var pick := move_toward(_pick, 1.0 if picked else 0.0, step)
	var dim := move_toward(_dim, 1.0 if (disabled or dimmed) else 0.0, step)
	var hover := move_toward(_hover, 1.0 if mode == DRAW_HOVER else 0.0, step)
	var fill_k := move_toward(_fill_k, 1.0, step)
	var shine := -1.0
	if hot and not disabled:
		_shine_t += delta
		shine = fmod(_shine_t, UiKit.SHINE_EVERY) / UiKit.SHINE_TIME
	if press == _press and pick == _pick and dim == _dim and hover == _hover and shine == plate.shine and fill_k == _fill_k:
		return
	_fill_k = fill_k
	_press = press
	_pick = pick
	_dim = dim
	_hover = hover
	plate.shine = shine if shine <= 1.0 else -1.0
	_apply()


func _apply() -> void:
	plate.set_press(_press)
	plate.lift = _pick
	plate.border = UiKit.BROWN.lerp(UiKit.ORANGE_DARK, _pick)
	plate.fill = _shown_fill().darkened(UiKit.PRESS_DARKEN * _press).lightened(0.04 * _hover)
	modulate.a = lerpf(1.0, UiKit.DIM_ALPHA, _dim)
	var shift := roundf(_press * UiKit.PRESS_Y - _pick * UiKit.LIFT_Y)
	if shift != _shift:
		for child in get_children():
			if child is Control:
				(child as Control).position.y += shift - _shift
		_shift = shift
	queue_redraw()


## 아이콘 + 글자를 한 묶음으로 가운데에 (Godot 버튼은 아이콘을 왼쪽 끝에 붙여 글자와 멀어짐)
func _center_group() -> void:
	var key := "%s|%s|%s" % [text, size, icon]
	if key == _group_key:
		return
	_group_key = key
	var side := UiKit.PAD
	if icon and text != "":
		var font_size := get_theme_font_size("font_size")
		var art_w := float(get_theme_constant("icon_max_width"))
		var group := art_w + get_theme_constant("h_separation") + get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		side = maxf(UiKit.PAD, floorf((size.x - group) * 0.5))
		alignment = HORIZONTAL_ALIGNMENT_LEFT
	plate.side = side
	plate.set_press(_press)


func _shown_fill() -> Color:
	return _from_fill.lerp(_base_fill, _fill_k) if _fill_k < 1.0 else _base_fill


## 지금 몸 사각형 (자기 좌표, 꼬리·배지 자리 계산용)
func body() -> Rect2:
	return plate.body_rect(Rect2(Vector2.ZERO, size))
