class_name UiKit
extends RefCounted
## 메뉴 화면 공용 부품 (v0.7.0 2c-polish): 판·버튼·칩·아이콘 받침·게이지·리본·글자, 작은 연출(톡 튀기·생선 날아가기·도장 쾅).
## 모양 값(색, 모서리, 테두리, 그림자, 윗면 빛, 눌림, 여백, 글자 크기)은 아래 "UI 스타일" 상수만 쓴다.
## 이 상수는 ART_BIBLE.md "UI 스타일" 표와 같아야 하고, 메뉴 화면 코드에 표에 없는 값이 있으면 tests/test_ui_style.gd가 실패한다.
## 판·버튼은 코드로 그린다(Plate). 압정·집게·아이콘은 Codex 색연필 그림(assets/sprites/ui/), 글자는 Gaegu 글꼴.

# --- UI 스타일: 색 (ART_BIBLE "UI 스타일" 표) ---
const PANEL := Color("#fff3dc")         # 판 크림 (큰 판)
const PAPER := Color("#fffbf0")         # 쪽지 크림 (쪽지·칩·크림 버튼·빈 칸)
const ORANGE := Color("#f39a45")        # 주황 기본 (주 버튼·채운 칸)
const ORANGE_LIGHT := Color("#ffc47e")  # 주황 밝음 (주황 위 윗면 빛·빛 원)
const ORANGE_DARK := Color("#c8692a")   # 주황 어두움 (고른 테두리·리본 꼬리·Lv 알약)
const GREEN := Color("#4f8236")         # 초록 (다음 값·다 찬 막대)
const RED := Color("#e0402f")           # 빨강 (알림 점·모자람)
const BROWN := Color("#5a4636")         # 갈색 선·제목·본문 글자
const SUB_BROWN := Color("#8c705a")     # 보조 글자
const TROUGH := Color("#ecd8b6")        # 홈 (게이지·막대 바탕)
const WOOD := Color("#c4925f")          # 코르크판 나무 테두리
const CORK := Color("#d9ab73")          # 코르크판 안
const SHADOW := Color("#5a46364d")      # 그림자 (갈색 30%)
const GLOSS := Color("#ffffff8c")       # 윗면 빛 (흰색 55%)
const SHINE := Color("#ffffff73")       # 지나가는 빛 (흰색 45%)
const INK := Color("#b83833d9")         # 도장 잉크 (85%)
const VEIL := Color("#fff3dc99")        # 상점·미션 뒤 가림막 (판 크림 60%)
const CREAM := PAPER                    # 주황 위 글자 색
# --- 모양 ---
const R_CHIP := 12.0     # 작은 칩·쪽지·게이지 칸
const R_BUTTON := 22.0   # 버튼·목록 줄
const R_PANEL := 28.0    # 큰 판
const R_PILL := 999.0    # 알약 (높이의 절반)
const LINE := 4.0        # 테두리 굵기 (색은 BROWN 하나, 고른 줄만 ORANGE_DARK)
const SHADOW_Y := 6.0    # 그림자: 아래로 6px, 같은 모양, SHADOW 색
const PRESS_Y := 4.0     # 누르면 몸이 4px 내려감
const PRESS_DARKEN := 0.08  # 누르면 8% 어두워짐
const LIFT_Y := 3.0      # 고른 줄은 3px 떠오름 (그림자가 그만큼 깊어 보임)
const DIM_ALPHA := 0.5   # 불가·모자람: 50% 흐림
const STATE_TIME := 0.12 # 상태 전환 시간 (초)
const SHINE_EVERY := 2.6 # 지나가는 빛 간격 (초)
const SHINE_TIME := 0.55 # 빛이 한 번 지나가는 시간 (초)
const GAP := 8.0         # 여백 단위 (모든 간격은 8의 배수)
const PAD := 16.0        # 판·버튼 안쪽 여백 (GAP x 2)
# --- 글자 (Gaegu Bold) ---
const TITLE := 48        # 제목 (갈색)
const BODY := 34         # 본문 (갈색)
const SUB := 26          # 보조 (연한 갈색)
const NUM := 40          # 숫자 (갈색, 지갑·기록·가격)
const NUM_BIG := 72      # 큰 숫자 (결과 카드 점수 하나)
const OUTLINE := 6       # 주황·리본 위 크림 글자의 갈색 테두리
# --- 아이콘 받침 (둥근 크림 받침 + 갈색 링) ---
const BASE_S := 72.0
const BASE_L := 152.0
const BASE_ART := 0.74   # 받침 안 그림 크기 비율

const MIN_BUTTON := 88.0  # 버튼은 화면 높이의 12% 이상
const FONT_MIN := 18  # 글자를 줄여 넣을 때 가장 작은 크기 (휴대폰 0.54배에서도 읽히게)
const FONT := preload("res://assets/fonts/gaegu/Gaegu-Bold.ttf")

const PIN_RED := preload("res://assets/sprites/ui/pin_red.png")
const PIN_YELLOW := preload("res://assets/sprites/ui/pin_yellow.png")
const CLIP := preload("res://assets/sprites/ui/clip.png")

const ICONS := {
	"combo": preload("res://assets/sprites/ui/icons/combo.png"),
	"clock": preload("res://assets/sprites/ui/icons/clock.png"),
	"cookie_clock": preload("res://assets/sprites/ui/icons/cookie_clock.png"),
	"dash_start": preload("res://assets/sprites/ui/icons/dash_start.png"),
	"bell_start": preload("res://assets/sprites/ui/icons/bell_start.png"),
	"fish_bonus": preload("res://assets/sprites/ui/icons/fish_bonus.png"),
	"footprints": preload("res://assets/sprites/ui/icons/footprints.png"),
	"jump": preload("res://assets/sprites/ui/icons/jump.png"),
	"smash": preload("res://assets/sprites/ui/icons/smash.png"),
	"items": preload("res://assets/sprites/ui/icons/items.png"),
	"swap": preload("res://assets/sprites/ui/icons/swap.png"),
	"rank_face": preload("res://assets/sprites/ui/icons/rank_face.png"),
	"basket": preload("res://assets/sprites/ui/icons/basket.png"),
	"note_check": preload("res://assets/sprites/ui/icons/note_check.png"),
	"star": preload("res://assets/sprites/ui/icons/star.png"),
	"back": preload("res://assets/sprites/ui/icons/back.png"),
	"speed": preload("res://assets/sprites/ui/icons/speed.png"),
	"stamp": preload("res://assets/sprites/ui/icons/stamp.png"),
	"fish": preload("res://assets/sprites/items/fish.png"),
	"snack": preload("res://assets/sprites/items/snack.png"),
	"yarn": preload("res://assets/sprites/items/yarn.png"),
	"gold": preload("res://assets/sprites/items/gold.png"),
	"cookie": preload("res://assets/sprites/items/cookie.png"),
	"can": preload("res://assets/sprites/items/can.png"),
	"bell": preload("res://assets/sprites/items/bell.png"),
	"tramp": preload("res://assets/sprites/structures/trampoline_rest.png"),
}
## 등급 배지 링 색 (1~10등급, PLAN 9번: 크림 → 하늘 → 초록 → 분홍 → 보라, 뒤는 금빛)
const RANK_RINGS := [Color("#f3e3c3"), Color("#9fd0e8"), Color("#9cc98a"), Color("#f2a7b8"), Color("#b9a0dc"),
		Color("#e8a21a"), Color("#f08a5d"), Color("#7fb3e0"), Color("#c9b8f0"), Color("#ffd166")]

## 연출 시간 (초)
const POP_TIME := 0.18
const FLY_TIME := 0.55
const STAMP_TIME := 0.2  # 휙 내려오는 시간 (그 뒤 0.16초 눌렸다 돌아옴)
const ENTER_STEP := 0.04 # 화면에 들어올 때 요소마다 늦추는 시간
const ENTER_TIME := 0.22


## 판 (Panel + Plate). kind: "panel" 큰 판 / "note" 쪽지 / "chip" 알약 칩 / "cork" 코르크 게시판 / "trough" 홈
static func panel(kind: String = "panel", shadow: bool = true) -> Panel:
	var p := Panel.new()
	var box := plate(kind)
	box.shadow = shadow and box.shadow
	box.set_press(0.0)
	p.add_theme_stylebox_override("panel", box)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_meta("plate", kind)
	return p


static func plate(kind: String) -> Plate:
	var box := Plate.new()
	match kind:
		"note":
			box.fill = PAPER
			box.radius = R_CHIP
		"chip":
			box.fill = PAPER
			box.radius = R_PILL
		"cork":
			box.fill = WOOD
			box.inner_fill = CORK
			box.inner_inset = PAD
		"trough":
			box.fill = TROUGH
			box.radius = R_PILL
			box.shadow = false
	box.set_press(0.0)
	return box


## 버튼: tone "orange"(주 버튼, 크림 글자 + 갈색 테두리) / "cream"
static func button(text: String, tone: String = "cream", art: Texture2D = null, font_size: int = BODY) -> UiButton:
	var b := UiButton.new(ORANGE if tone == "orange" else PAPER, R_BUTTON)
	b.text = text
	b.custom_minimum_size = Vector2(MIN_BUTTON, MIN_BUTTON)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_constant_override("h_separation", int(GAP))
	tone_text(b, tone)
	if art:
		b.icon = art
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 56)
	return b


## 버튼 글자 색: 주황 위는 크림 글자 + 갈색 테두리, 크림 위는 갈색
static func tone_text(b: Button, tone: String) -> void:
	var color := CREAM if tone == "orange" else BROWN
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(state, color)
	b.add_theme_color_override("font_outline_color", BROWN)
	b.add_theme_constant_override("outline_size", OUTLINE if tone == "orange" else 0)


static func label(text: String, font_size: int = BODY, color: Color = BROWN, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", BROWN)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 주황·리본 위 글자 (크림 + 갈색 테두리)
static func on_orange(l: Label) -> Label:
	l.add_theme_color_override("font_color", CREAM)
	l.add_theme_constant_override("outline_size", OUTLINE)
	return l


## 한 줄 글자가 width 안에 들어가게 글자 크기를 base에서 FONT_MIN까지 줄인다 (긴 숫자·이름)
static func fit(l: Label, width: float, base: int) -> void:
	var size := base
	while size > FONT_MIN and FONT.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	l.add_theme_font_size_override("font_size", size)


## 띄어쓰기에서만 줄을 바꾼 글 (width 안, 글자 크기 size). Godot 자동 줄바꿈은 한글을 글자 사이에서도 끊어
## "길어져 / 요."처럼 끝 글자가 혼자 남으므로 화면 글은 이걸로 나눈다 (2c-fix). 원래 있던 줄바꿈은 그대로
static func wrap(text: String, size: int, width: float) -> String:
	var out := PackedStringArray()
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var trial := word if line == "" else line + " " + word
			if line != "" and FONT.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return "\n".join(out)


## 여러 줄 글: 띄어쓰기에서 나눠 lines줄 안에 들도록 글자 크기를 base에서 FONT_MIN까지 줄인다 (가장 긴 미션 문구)
static func wrap_fit(l: Label, text: String, width: float, lines: int, base: int) -> void:
	var size := base
	while size > FONT_MIN and UiKit.wrap(text, size, width).count("\n") >= lines:
		size -= 1
	l.text = UiKit.wrap(text, size, width)
	l.add_theme_font_size_override("font_size", size)


static func icon(texture: Texture2D, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.size = t.custom_minimum_size
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## 아이콘 받침: 그림자 + 크림 원 + 갈색 링, 가운데에 그림 (size = BASE_S 또는 BASE_L). 그림은 get_meta("art")
static func icon_base(texture: Texture2D, size: float) -> Control:
	var base := Control.new()
	base.custom_minimum_size = Vector2(size, size)
	base.size = base.custom_minimum_size
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.draw.connect(func() -> void: draw_disc(base, base.size * 0.5, size * 0.5, PAPER))
	var art := icon(texture, roundf(size * BASE_ART))
	art.position = ((base.size - art.size) * 0.5).round()
	base.add_child(art)
	base.set_meta("art", art)
	return base


## 둥근 받침 원 (그림자 + 채움 + 링), 계단 없이
static func draw_disc(canvas: CanvasItem, center: Vector2, radius: float, fill: Color, ring: Color = BROWN) -> void:
	canvas.draw_circle(center + Vector2(0, SHADOW_Y * 0.5), radius - LINE * 0.5, SHADOW, true, -1.0, true)
	canvas.draw_circle(center, radius - LINE, fill, true, -1.0, true)
	canvas.draw_arc(center, radius - LINE * 0.5 - 1.0, 0.0, TAU, 96, ring, LINE, true)


## 알림 점: 빨간 동그라미 (+ 숫자). count가 0이면 숨김. 숫자 없는 점은 show_dot
static func badge(diameter: float = 44.0) -> Control:
	var dot := Control.new()
	dot.name = "Dot"
	dot.size = Vector2(diameter, diameter)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.draw.connect(func() -> void: draw_disc(dot, dot.size * 0.5, diameter * 0.5, RED, PAPER))
	var text := on_orange(label("", SUB, CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	text.add_theme_constant_override("outline_size", 0)
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	dot.add_child(text)
	return dot


static func badge_text(dot: Control, count: int) -> void:
	(dot.get_child(0) as Label).text = str(count)
	dot.visible = count > 0


## 천 단위 쉼표
static func comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## 둥근 사각형 모양 점들 (지나가는 빛을 몸 모양으로 자를 때)
static func rounded_polygon(rect: Rect2, r: float) -> PackedVector2Array:
	r = minf(r, minf(rect.size.x, rect.size.y) * 0.5)
	var points := PackedVector2Array()
	var centers := [rect.position + Vector2(rect.size.x - r, r), rect.end - Vector2(r, r), rect.position + Vector2(r, rect.size.y - r), rect.position + Vector2(r, r)]
	for c in 4:
		for i in 9:
			points.append(centers[c] + Vector2.from_angle(-PI * 0.5 + PI * 0.5 * (c + i / 8.0)) * r)
	return points


## 알약 모양 막대 (홈 + 채움 + 윗면 빛). 미션 진행·등급 경험치
static func draw_bar(canvas: CanvasItem, rect: Rect2, k: float, fill: Color) -> void:
	var trough := plate("trough")
	trough.draw(canvas.get_canvas_item(), rect)
	var inside := rect.grow(-LINE - 2.0)
	if k > 0.0:
		var w := maxf(inside.size.y, inside.size.x * clampf(k, 0.0, 1.0))
		_cell(canvas, Rect2(inside.position, Vector2(w, inside.size.y)), fill)


## 게이지 칸 하나: 둥근 채움 + 윗면 밝은 줄
static func _cell(canvas: CanvasItem, rect: Rect2, fill: Color) -> void:
	var box := StyleBoxFlat.new()
	box.anti_aliasing = true
	box.bg_color = fill
	box.set_corner_radius_all(int(minf(R_CHIP, rect.size.y * 0.5)))
	canvas.draw_style_box(box, rect)
	var light := ORANGE_LIGHT if fill == ORANGE else Color(GLOSS, 0.45)
	var band := Rect2(rect.position + Vector2(rect.size.y * 0.35, 2.0), Vector2(rect.size.x - rect.size.y * 0.7, maxf(2.0, rect.size.y * 0.28)))
	if band.size.x > 2.0:
		box.bg_color = light
		box.set_corner_radius_all(int(band.size.y * 0.5))
		canvas.draw_style_box(box, band)


## 단계 게이지 칸 자리 (게이지 사각형 안, 크기·간격이 정확히 같은 정수 픽셀). 남는 폭은 양 끝 여백으로
static func gauge_cells(rect: Rect2, count: int) -> Array[Rect2]:
	var inside := rect.grow(-LINE - 3.0)
	var gap := 4.0
	var w := floorf((inside.size.x - gap * (count - 1)) / count)
	var x0 := roundf(inside.position.x + (inside.size.x - (w * count + gap * (count - 1))) * 0.5)
	var out: Array[Rect2] = []
	for i in count:
		out.append(Rect2(x0 + i * (w + gap), roundf(inside.position.y), w, roundf(inside.size.y)))
	return out


## 단계 게이지: 알약 홈 안에 count칸. 채운 칸(level개) = 주황 + 윗면 밝은 줄, 빈 칸 = 크림 + 안쪽 옅은 그림자,
## 다음 칸(살 단계) = pulse(0..1)만큼 은은한 주황. pop_i 칸은 pop(0..1)만큼 커졌다 돌아옴
static func draw_gauge(canvas: CanvasItem, rect: Rect2, level: int, count: int, pulse: float, pop_i: int = -1, pop: float = 0.0) -> void:
	plate("trough").draw(canvas.get_canvas_item(), rect)
	var cells := gauge_cells(rect, count)
	for i in count:
		var cell: Rect2 = cells[i]
		if i == pop_i and pop > 0.0:
			cell = cell.grow(3.0 * pop)
		if i < level:
			_cell(canvas, cell, ORANGE)
		else:
			_cell(canvas, cell, PAPER)
			var box := StyleBoxFlat.new()  # 안쪽 옅은 그림자 (위쪽이 살짝 어두움)
			box.anti_aliasing = true
			box.bg_color = Color(SHADOW, SHADOW.a * 0.45)
			box.set_corner_radius_all(int(minf(R_CHIP, cell.size.y * 0.5)))
			box.set_corner_radius(CORNER_BOTTOM_LEFT, 0)
			box.set_corner_radius(CORNER_BOTTOM_RIGHT, 0)
			canvas.draw_style_box(box, Rect2(cell.position, Vector2(cell.size.x, 3.0)).grow_individual(-2.0, 0, -2.0, 0))
			if i == level and pulse > 0.0:
				_cell(canvas, cell, Color(ORANGE, 0.2 + 0.35 * pulse))


## 리본: 가운데 띠(주황, 갈색 테두리) + 양쪽 아래로 접힌 꼬리(주황 어두움, V자 홈). rect = 가운데 띠
static func draw_ribbon(canvas: CanvasItem, rect: Rect2, fill: Color = ORANGE) -> void:
	var drop := rect.size.y * 0.28
	var tail := rect.size.y * 0.7
	for side: float in [-1.0, 1.0]:
		var x0 := rect.position.x if side < 0 else rect.end.x
		var y0 := rect.position.y + drop
		var y1 := rect.end.y + drop
		var out := x0 + side * tail
		var points := PackedVector2Array([Vector2(x0 - side * GAP * 2.0, y0), Vector2(out, y0), Vector2(out - side * tail * 0.35, (y0 + y1) * 0.5),
				Vector2(out, y1), Vector2(x0 - side * GAP * 2.0, y1)])
		canvas.draw_colored_polygon(points, ORANGE_DARK)
		points.append(points[0])
		canvas.draw_polyline(points, BROWN, LINE, true)
	var box := Plate.new()
	box.fill = fill
	box.radius = R_CHIP
	box.shadow = false
	box.gloss = 1.0
	box.gloss_color = ORANGE_LIGHT
	box.draw(canvas.get_canvas_item(), rect)


## 오른쪽 화살표 (글꼴에 "→"가 없어 그림으로): 주황 채움 + 갈색 테두리
static func draw_arrow(canvas: CanvasItem, center: Vector2, size: float) -> void:
	var h := size * 0.5
	var shaft := size * 0.18
	var points := PackedVector2Array([center + Vector2(-h, -shaft), center + Vector2(h * 0.1, -shaft), center + Vector2(h * 0.1, -h * 0.75),
			center + Vector2(h, 0), center + Vector2(h * 0.1, h * 0.75), center + Vector2(h * 0.1, shaft), center + Vector2(-h, shaft)])
	canvas.draw_colored_polygon(points, ORANGE)
	points.append(points[0])
	canvas.draw_polyline(points, BROWN, LINE, true)


## 둥근 빛 원 (큰 아이콘 뒤): 가운데 주황 밝음 → 바깥 투명. 배경이라 그림 칸(TextureRect)이 아닌 그리기로
static func glow(size: float) -> Control:
	var g := Gradient.new()
	g.set_color(0, Color(ORANGE_LIGHT, 0.75))
	g.set_color(1, Color(ORANGE_LIGHT, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var c := Control.new()
	c.name = "Glow"
	c.size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: c.draw_texture_rect(tex, Rect2(Vector2.ZERO, c.size), false))
	return c


## 화면에 들어올 때: 요소마다 ENTER_STEP씩 늦게, 아래에서 살짝 올라오며 나타남
static func enter(controls: Array, from: Vector2 = Vector2(0, 24)) -> void:
	for i in controls.size():
		var c: Control = controls[i]
		var rest := c.position
		c.modulate.a = 0.0
		c.position = rest + from
		var tween := c.create_tween().set_parallel()
		tween.tween_property(c, "modulate:a", 1.0, ENTER_TIME).set_delay(ENTER_STEP * i)
		tween.tween_property(c, "position", rest, ENTER_TIME).set_delay(ENTER_STEP * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 톡 튀기: 커졌다 돌아옴 (pivot은 가운데)
static func pop(control: Control, amount: float = 0.25) -> void:
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE * (1.0 + amount), POP_TIME * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, POP_TIME * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 도장 쿵 (2c 피드백): 위에서 크게 기울어진 채 내려와(휙) 찍히는 순간 납작하게 눌렸다 돌아온다.
## 찍히는 순간 on_hit()을 부른다 (쿵 소리·화면 흔들림·잉크는 부르는 쪽이 정함). 끝까지 STAMP_TIME + 0.16초
static func stamp(control: Control, angle: float = -0.2, on_hit: Callable = Callable()) -> Tween:
	control.pivot_offset = control.size * 0.5
	var rest := control.position
	control.position = rest + Vector2(30.0, -90.0)
	control.scale = Vector2.ONE * 2.4
	control.rotation = angle - 0.35
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.set_parallel()
	tween.tween_property(control, "scale", Vector2.ONE, STAMP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(control, "position", rest, STAMP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(control, "rotation", angle, STAMP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, STAMP_TIME * 0.4)
	tween.chain().tween_callback(func() -> void:
		if on_hit.is_valid():
			on_hit.call())
	tween.chain().tween_property(control, "scale", Vector2(1.14, 0.84), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(control, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween


## 버튼이 눌리며 살짝 찌그러짐 (가로로 넓고 세로로 납작 → 돌아옴)
static func squash(control: Control) -> Tween:
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2(1.08, 0.88), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween


## 흔들림 (화면 흔들림은 메뉴 화면·결과 카드를 통째로): Juice.shake_offset, 끝나면 제자리.
## 흔들리는 중에 또 흔들어도 제자리가 밀리지 않게 처음 자리를 meta로 기억한다
static func shake(control: Control, strength: float = 6.0, time: float = 0.14) -> Tween:
	if not control.has_meta("shake_rest"):
		control.set_meta("shake_rest", control.position)
	var rest: Vector2 = control.get_meta("shake_rest")
	var tween := control.create_tween()
	tween.tween_method(func(t: float) -> void: control.position = rest + Juice.shake_offset(t, time, strength), 0.0, time, time)
	tween.tween_callback(func() -> void:
		control.position = rest
		control.remove_meta("shake_rest"))
	return tween


## 조각이 at(layer 좌표)에서 사방으로 튀어 사라진다. kind "star" = 작은 별 그림, "ink" = 도장 잉크 방울.
## 번호로 방향·거리를 정해 무작위 없음
static func burst(layer: Control, at: Vector2, count: int, kind: String = "star", reach: float = 70.0) -> Tween:
	var pieces: Array[Control] = []
	for i in count:
		var piece: Control
		if kind == "star":
			piece = icon(ICONS.star, 26.0 + 8.0 * (i % 3))
		else:
			piece = Control.new()
			piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var r := 4.0 + 3.0 * (i % 3)
			piece.draw.connect(func() -> void: piece.draw_circle(piece.size * 0.5, r, INK))
			piece.custom_minimum_size = Vector2(r, r) * 2.0
		piece.size = piece.custom_minimum_size
		piece.position = at - piece.size * 0.5
		layer.add_child(piece)
		pieces.append(piece)
	var tween := layer.create_tween().set_parallel()
	for i in count:
		var piece := pieces[i]
		var dir := Vector2.from_angle(TAU * (i + 0.3 * (i % 2)) / count - PI * 0.5)
		var far := reach * (0.7 + 0.3 * ((i * 7) % 5) / 4.0)
		var end := piece.position + dir * far + (Vector2(0, 18) if kind == "ink" else Vector2.ZERO)
		tween.tween_property(piece, "position", end, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(piece, "rotation", 2.0 * dir.x, 0.32)
		tween.tween_property(piece, "modulate:a", 0.0, 0.18).set_delay(0.16)
	tween.chain().tween_callback(func() -> void:
		for piece in pieces:
			piece.queue_free())
	return tween


## 글자가 위로 떠오르며 사라짐 (부스터 "+1")
static func float_text(layer: Control, at: Vector2, text: String, color: Color = GREEN) -> Tween:
	var l := label(text, NUM, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.size = Vector2(120, 50)
	l.position = at - l.size * 0.5
	layer.add_child(l)
	pop(l, 0.4)
	var tween := l.create_tween().set_parallel()
	tween.tween_property(l, "position:y", l.position.y - 50.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.35)
	tween.chain().tween_callback(l.queue_free)
	return tween


## 연출을 바로 끝 모습으로 (빨리 연달아 누르면 앞 연출을 짧게 끝냄). 끝에서 부르는 콜백도 다 불린다
static func finish(tweens: Array) -> void:
	for tween: Tween in tweens:
		if tween and tween.is_valid() and tween.is_running():
			tween.custom_step(60.0)
	tweens.clear()


## 그림 count개가 from에서 to로 포물선을 그리며 날아간다 (layer 좌표). 하나 닿을 때마다 on_each(i)를 부른다.
## 기본은 생선 (받기 → 지갑, 사기 → 패널), 부스터 사기는 부스터 그림 하나.
## 길(곡선 꼭대기 포함)은 layer 사각형 안에 머문다 (2c-polish: 지갑에서 출발한 생선이 화면 위로 나갔음): fly_path
static func fly(layer: Control, from: Vector2, to: Vector2, count: int, on_each: Callable = Callable(),
		texture: Texture2D = ICONS.fish, size: float = 44.0, time: float = FLY_TIME) -> Array[Tween]:
	var out: Array[Tween] = []
	var bounds := Rect2(Vector2.ZERO, layer.size)
	for i in count:
		var fish := icon(texture, size)
		fish.name = "Fly%d" % i
		fish.set_meta("fly", true)  # 이름은 앞 연출 그림과 겹치면 바뀔 수 있어 표시로 찾음 (테스트)
		fish.pivot_offset = fish.size * 0.5  # 가운데를 축으로 돌고 줄어듦
		var path := fly_path(from, to, i, count, size, bounds)
		fish.position = path[0] - fish.size * 0.5
		layer.add_child(fish)
		var tween := fish.create_tween()
		tween.tween_interval(0.06 * i)
		tween.tween_method(func(k: float) -> void:
			fish.position = fly_point(path, k) - fish.size * 0.5
			fish.rotation = -0.6 * (1.0 - k)
			fish.scale = Vector2.ONE * lerpf(1.2, 0.7, k), 0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			if on_each.is_valid():
				on_each.call(i)
			fish.queue_free())
		out.append(tween)
	return out


## 날아가는 길 [출발 가운데, 도착 가운데, 위로 솟는 높이]. 번호로 흩뜨려 무작위 없음.
## 그림이 1.2배로 커지고 기울어도 bounds 안에 들도록 가장자리 여유(size)를 두고, 꼭대기가 넘으면 솟는 높이를 줄인다
static func fly_path(from: Vector2, to: Vector2, i: int, count: int, size: float, bounds: Rect2) -> Array:
	var safe := bounds.grow(-size * 0.85 - 2.0)
	var spread := Vector2((i * 37) % 60 - 30, (i * 23) % 40 - 20) if count > 1 else Vector2.ZERO
	var start := (from + spread).clamp(safe.position, safe.end)
	var end := to.clamp(safe.position, safe.end)
	var lift := 120.0 + 30.0 * (i % 3)
	# 꼭대기 높이 ≈ 가운데 높이 - lift. 넘으면 lift를 줄임 (0 = 곧게)
	while lift > 0.0 and fly_point([start, end, lift], _peak_k(start, end, lift)).y < safe.position.y:
		lift = maxf(0.0, lift - 10.0)
	return [start, end, lift]


static func fly_point(path: Array, k: float) -> Vector2:
	return (path[0] as Vector2).lerp(path[1], k) + Vector2(0, -path[2]) * 4.0 * k * (1.0 - k)  # 위로 둥글게


## 곡선이 가장 높은 k (y(k) = s + (e - s)k - 4Lk(1-k) 의 최소: dy/dk = 0)
static func _peak_k(start: Vector2, end: Vector2, lift: float) -> float:
	return clampf(0.5 - (end.y - start.y) / (8.0 * lift), 0.0, 1.0)


## 둥근 등급 배지 링: 등급 색 띠 + 갈색 링 (얼굴 그림은 위에 따로). canvas = 그릴 Control
static func draw_rank_ring(canvas: CanvasItem, center: Vector2, radius: float, level: int) -> void:
	var color: Color = RANK_RINGS[clampi(level, 1, RANK_RINGS.size()) - 1]
	draw_disc(canvas, center, radius + GAP + LINE, color)
	canvas.draw_circle(center, radius, PAPER, true, -1.0, true)
	canvas.draw_arc(center, radius, 0.0, TAU, 96, BROWN, LINE * 0.5, true)
