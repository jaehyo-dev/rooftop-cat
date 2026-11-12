class_name UiKit
extends RefCounted
## 메뉴 화면 공용 부품 (v0.7.0 2c): 종이 패널·버튼·글자·아이콘, 작은 연출(톡 튀기·생선 날아가기·도장 쾅).
## 판·버튼은 tools/make_ui_paper.py가 그린 평면 종이, 압정·집게·아이콘은 Codex 색연필 그림(assets/sprites/ui/). 글자는 그림에 없고 Gaegu 글꼴로 쓴다.
## 버튼은 화면 높이의 12%(720의 86.4px) 이상: MIN_BUTTON.

const BROWN := Color(0.353, 0.275, 0.212)
const CREAM := Color(1, 0.97, 0.9)
const RED := Color(0.878, 0.251, 0.184)
const GREEN := Color(0.45, 0.62, 0.36)
const INK := Color(0.72, 0.22, 0.2, 0.85)  # 도장 잉크 (발바닥 도장 빨강)
const MIN_BUTTON := 88.0
const FONT_MIN := 18  # 글자를 줄여 넣을 때 가장 작은 크기 (휴대폰 0.54배에서도 읽히게)
const FONT := preload("res://assets/fonts/gaegu/Gaegu-Bold.ttf")

## 종이 그림과 9칸 나누기 여백 (그림 픽셀, 가장자리 테두리가 늘어나지 않게).
## tools/make_ui_paper.py가 그린 "거의 평면" 종이 (2c 피드백 B 확정, 2026-11-12)
const PAPER := {
	"panel": [preload("res://assets/sprites/ui/panel.png"), 40],
	"note": [preload("res://assets/sprites/ui/note.png"), 30],
	"cork": [preload("res://assets/sprites/ui/cork.png"), 48],
	"orange": [preload("res://assets/sprites/ui/orange.png"), 40],
	"cream": [preload("res://assets/sprites/ui/cream.png"), 40],
}


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
## 등급 배지 테두리 색 (1~10등급, PLAN 9번: 크림 → 하늘 → 초록 → 분홍 → 보라, 뒤는 금빛)
const RANK_RINGS := [Color("#f3e3c3"), Color("#9fd0e8"), Color("#9cc98a"), Color("#f2a7b8"), Color("#b9a0dc"),
		Color("#e8a21a"), Color("#f08a5d"), Color("#7fb3e0"), Color("#c9b8f0"), Color("#ffd166")]

## 연출 시간 (초)
const POP_TIME := 0.18
const FLY_TIME := 0.55
const STAMP_TIME := 0.2  # 휙 내려오는 시간 (그 뒤 0.16초 눌렸다 돌아옴)


## 종이 패널 (9칸 늘림)
static func paper(kind: String = "panel") -> NinePatchRect:
	var rect := NinePatchRect.new()
	rect.texture = PAPER[kind][0]
	var m: int = PAPER[kind][1]
	rect.patch_margin_left = m
	rect.patch_margin_top = m
	rect.patch_margin_right = m
	rect.patch_margin_bottom = m
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func _box(kind: String, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = PAPER[kind][0]
	box.set_texture_margin_all(PAPER[kind][1])
	box.set_content_margin_all(14.0)
	box.content_margin_left = 26.0
	box.content_margin_right = 26.0
	box.modulate_color = tint
	return box


## 종이 버튼: kind "orange"(주 버튼) / "cream". 스페이스가 버튼을 누르지 않게 포커스 없음 (점프와 겹치지 않게)
static func button(text: String, kind: String = "cream", icon: Texture2D = null, font_size: int = 40) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(MIN_BUTTON, MIN_BUTTON)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, BROWN)
	b.add_theme_color_override("font_disabled_color", Color(BROWN, 0.5))
	b.add_theme_color_override("font_outline_color", CREAM)
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_stylebox_override("normal", _box(kind))
	b.add_theme_stylebox_override("hover", _box(kind, Color(1.04, 1.02, 1.0)))
	b.add_theme_stylebox_override("pressed", _box(kind, Color(0.88, 0.84, 0.8)))
	b.add_theme_stylebox_override("hover_pressed", _box(kind, Color(0.88, 0.84, 0.8)))
	b.add_theme_stylebox_override("disabled", _box(kind, Color(1, 1, 1, 0.55)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if icon:
		b.icon = icon
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 64)
	return b


static func label(text: String, font_size: int = 32, color: Color = BROWN, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", CREAM)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


static func icon(texture: Texture2D, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## 빨간 동그라미 숫자 (받을 미션 보상 수). 글자는 badge_text로 바꿈
static func badge(diameter: float = 46.0) -> Control:  # 휴대폰에서도 숫자가 보이게 (2c-fix: 38은 폰에서 숫자가 안 보임)
	var dot := Control.new()
	dot.name = "Dot"
	dot.size = Vector2(diameter, diameter)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.draw.connect(func() -> void:
		dot.draw_circle(dot.size * 0.5, diameter * 0.5 + 2.0, CREAM)
		dot.draw_circle(dot.size * 0.5, diameter * 0.5, RED))
	var text := label("", int(diameter * 0.7), CREAM, HORIZONTAL_ALIGNMENT_CENTER)
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
	var l := label(text, 40, color, HORIZONTAL_ALIGNMENT_CENTER)
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
## 기본은 생선 (받기 → 지갑, 사기 → 패널), 부스터 사기는 부스터 그림 하나
static func fly(layer: Control, from: Vector2, to: Vector2, count: int, on_each: Callable = Callable(),
		texture: Texture2D = ICONS.fish, size: float = 44.0, time: float = FLY_TIME) -> Array[Tween]:
	var out: Array[Tween] = []
	for i in count:
		var fish := icon(texture, size)
		fish.size = Vector2(size, size)
		fish.position = from - fish.size * 0.5 + Vector2((i * 37) % 60 - 30, (i * 23) % 40 - 20) * (1.0 if count > 1 else 0.0)  # 번호로 흩뜨림 (무작위 없음)
		layer.add_child(fish)
		var start := fish.position
		var end := to - fish.size * 0.5
		var lift := Vector2(0, -120.0 - 30.0 * (i % 3))
		var tween := fish.create_tween()
		tween.tween_interval(0.06 * i)
		tween.tween_method(func(k: float) -> void:
			fish.position = start.lerp(end, k) + lift * 4.0 * k * (1.0 - k)  # 위로 둥글게
			fish.rotation = -0.6 * (1.0 - k)
			fish.scale = Vector2.ONE * lerpf(1.2, 0.7, k), 0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			if on_each.is_valid():
				on_each.call(i)
			fish.queue_free())
		out.append(tween)
	return out


## 둥근 등급 배지: 얼굴 그림 + 등급 색 테두리 (그리기 함수, canvas = 그릴 Control)
static func draw_rank_ring(canvas: CanvasItem, center: Vector2, radius: float, level: int) -> void:
	var color: Color = RANK_RINGS[clampi(level, 1, RANK_RINGS.size()) - 1]
	canvas.draw_circle(center, radius + 7.0, BROWN)
	canvas.draw_circle(center, radius + 4.0, color)


## 손그림 느낌 진행 막대 (갈색 테두리 + 크림 바탕 + 색 채움)
static func draw_bar(canvas: CanvasItem, rect: Rect2, k: float, fill: Color) -> void:
	var r := rect.size.y * 0.5
	_round_rect(canvas, rect.grow(3.0), BROWN)
	_round_rect(canvas, rect, CREAM)
	if k > 0.0:
		var w := maxf(rect.size.y, rect.size.x * clampf(k, 0.0, 1.0))
		_round_rect(canvas, Rect2(rect.position, Vector2(w, rect.size.y)), fill)
	canvas.draw_line(rect.position + Vector2(r, 4.0), rect.position + Vector2(rect.size.x - r, 4.0), Color(1, 1, 1, 0.35), 2.0, true)


static func _round_rect(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(rect.size.y * 0.5))
	box.anti_aliasing = true
	canvas.draw_style_box(box, rect)
