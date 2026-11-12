class_name Plate
extends StyleBox
## 메뉴 판·버튼·칩 하나를 그리는 StyleBox (v0.7.0 2c-polish). 모양 값은 모두 UiKit의 "UI 스타일" 상수(ART_BIBLE "UI 스타일" 표)에서 온다.
## 그리는 순서: 그림자(아래로 SHADOW_Y, 같은 모양) → 몸(채움 + 테두리) → 안쪽 판(코르크처럼 테두리 안 다른 색) → 윗면 빛 → 지나가는 빛.
## 컨트롤 사각형 = 몸 + 아래 그림자 자리. 눌리면 몸이 그림자 쪽으로 PRESS_Y 내려가고, 고르면 LIFT_Y 떠올라 그림자가 깊어 보인다.

var fill := UiKit.PANEL
var border := UiKit.BROWN
var radius := UiKit.R_PANEL      # UiKit.R_PILL = 높이의 절반
var shadow := true
var gloss := 0.0                 # 윗면 빛 세기 (0 = 없음, 1 = 버튼)
var gloss_color := UiKit.GLOSS
var inner_fill := Color.TRANSPARENT  # 테두리 안쪽 inner_inset 만큼 들어간 판 색 (코르크판)
var inner_inset := 0.0
var press := 0.0   # 0..1 눌림
var lift := 0.0    # 0..1 고름 (떠오름)
var shine := -1.0  # 0..1 지나가는 빛 자리 (음수 = 없음)
var side := UiKit.PAD  # 왼쪽·오른쪽 안쪽 여백 (아이콘+글자 묶음을 가운데로 둘 때 UiButton이 바꿈)

var _flat := StyleBoxFlat.new()


func _init() -> void:
	_flat.anti_aliasing = true
	_flat.anti_aliasing_size = 1.0
	_set_margins()


func _set_margins() -> void:
	content_margin_left = side
	content_margin_right = side
	content_margin_top = UiKit.GAP + press * UiKit.PRESS_Y
	content_margin_bottom = UiKit.GAP + (UiKit.SHADOW_Y if shadow else 0.0) - press * UiKit.PRESS_Y


## 눌림 값을 바꾸면 글자도 같이 내려가게 여백을 다시 맞춘다
func set_press(k: float) -> void:
	press = k
	_set_margins()
	emit_changed()


## 몸이 그려지는 사각형 (컨트롤 사각형 안, 눌림·고름 반영)
func body_rect(rect: Rect2) -> Rect2:
	var r := Rect2(rect.position.round(), rect.size.round())
	if shadow:
		r.size.y -= UiKit.SHADOW_Y
	r.position.y += roundf(press * UiKit.PRESS_Y - lift * UiKit.LIFT_Y)
	return r


func corner(rect: Rect2) -> float:
	return rect.size.y * 0.5 if radius == UiKit.R_PILL else minf(radius, rect.size.y * 0.5)


func _rounded(canvas: RID, rect: Rect2, color: Color, r: float, border_w: float = 0.0, border_c: Color = Color.TRANSPARENT) -> void:
	_flat.bg_color = color
	_flat.border_color = border_c
	_flat.set_border_width_all(int(border_w))
	_flat.set_corner_radius_all(int(r))
	_flat.draw(canvas, rect)


func _draw(canvas: RID, rect: Rect2) -> void:
	var body := body_rect(rect)
	var r := corner(body)
	if shadow:
		var base := Rect2(rect.position.round(), rect.size.round())
		base.size.y -= UiKit.SHADOW_Y
		_rounded(canvas, Rect2(base.position + Vector2(0, UiKit.SHADOW_Y), base.size), UiKit.SHADOW, r)
	_rounded(canvas, body, fill, r, UiKit.LINE, border)
	if inner_inset > 0.0:
		var inside := body.grow(-inner_inset)
		_rounded(canvas, inside, inner_fill, maxf(4.0, r - inner_inset), UiKit.LINE * 0.5, border)
	if gloss > 0.0:
		_draw_gloss(canvas, body, r)
	if shine >= 0.0 and shine <= 1.0:
		_draw_shine(canvas, body, r)


## 윗면 빛: 테두리 안쪽 위에 알약 모양 밝은 띠 (몸 높이의 40%)
func _draw_gloss(canvas: RID, body: Rect2, r: float) -> void:
	var inset := UiKit.LINE + 3.0
	var band := Rect2(body.position + Vector2(inset + r * 0.25, inset), Vector2(body.size.x - 2.0 * (inset + r * 0.25), (body.size.y - 2.0 * inset) * 0.4))
	if band.size.x <= 4.0 or band.size.y <= 2.0:
		return
	_rounded(canvas, band, Color(gloss_color, gloss_color.a * gloss), band.size.y * 0.5)


## 지나가는 빛: 기울어진 밝은 띠를 몸 모양 안으로 잘라 그린다 (살 수 있는 버튼, 몇 초마다 한 번)
func _draw_shine(canvas: RID, body: Rect2, r: float) -> void:
	var inside := body.grow(-UiKit.LINE)
	var w := inside.size.y * 0.6
	var x := lerpf(inside.position.x - inside.size.y - w, inside.end.x, shine)
	var top := inside.position.y
	var bottom := inside.end.y
	var skew := inside.size.y * 0.5
	var band := PackedVector2Array([Vector2(x + skew, top), Vector2(x + skew + w, top), Vector2(x + w, bottom), Vector2(x, bottom)])
	for piece in Geometry2D.intersect_polygons(band, UiKit.rounded_polygon(inside, maxf(0.0, r - UiKit.LINE))):
		RenderingServer.canvas_item_add_polygon(canvas, piece, PackedColorArray([UiKit.SHINE]))
