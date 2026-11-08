class_name TuningPanel
extends Control
## 로컬 플레이 빌드 전용 설정 패널: 점프 무게 A·B·C(다음 판부터), 안개 M1·M2·M3(바로).
## PC는 숫자 키 1~6, 휴대폰은 화면 오른쪽 위 버튼. 사용자가 고르면 값을 고정하고 이 파일을 지운다 (PLAN 13번).
## 버튼 터치가 점프가 되지 않게, World보다 먼저 입력을 받아 처리하고 막는다 (트리에서 뒤에 있는 노드가 _input을 먼저 받음).

const BUTTON := Vector2(72.0, 64.0)
const GAP := 8.0
const MARGIN := 12.0
const GROUP_GAP := 20.0
const FONT := preload("res://assets/fonts/gaegu/Gaegu-Bold.ttf")
const BROWN := Color(0.353, 0.275, 0.212)
const CREAM := Color(1, 0.97, 0.9)
const HIGHLIGHT := Color("#ffd166")
const JUMPS := ["A", "B", "C"]
const MISTS := ["M1", "M2", "M3"]
const OFFICIAL_HOST := "jaehyo-dev.github.io"

var _world: Node2D


## 배포된 사이트에서는 보이지 않게 한다 (로컬 서버·에디터 실행에서만)
static func allowed(host: String = "") -> bool:
	if host.is_empty() and OS.has_feature("web"):
		host = str(JavaScriptBridge.eval("location.hostname"))
	return host != OFFICIAL_HOST


func _init(world: Node2D) -> void:
	_world = world
	name = "TuningPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10


func _ready() -> void:
	_world.restarted.connect(queue_redraw)
	get_viewport().size_changed.connect(queue_redraw)


## 버튼 칸 (index 0~2 = 점프, 3~5 = 안개), 오른쪽 위에 한 줄로
func _button_rect(index: int) -> Rect2:
	var total := 6.0 * BUTTON.x + 4.0 * GAP + GROUP_GAP
	var x := get_viewport_rect().size.x - MARGIN - total + index * (BUTTON.x + GAP) + (GROUP_GAP - GAP if index >= 3 else 0.0)
	return Rect2(x, MARGIN, BUTTON.x, BUTTON.y)


## index번 설정을 고른다 (0~2 점프, 3~5 안개)
func choose(index: int) -> void:
	if index < 3:
		_world.next_jump_preset = JUMPS[index]
	else:
		_world.mist_preset = MISTS[index - 3]
		_world.queue_redraw()
		_world.get_node("FrontMist").queue_redraw()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.physical_keycode - KEY_1
		if index >= 0 and index < 6:
			choose(index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		for i in 6:
			if _button_rect(i).has_point(event.position):
				choose(i)
				get_viewport().set_input_as_handled()
				return


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.border_color = BROWN
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	for i in 6:
		var label: String = JUMPS[i] if i < 3 else MISTS[i - 3]
		var active: bool = label == (JumpModel.preset if i < 3 else _world.mist_preset)
		box.bg_color = Color(HIGHLIGHT if active else CREAM, 0.9 if active else 0.55)
		var rect := _button_rect(i)
		draw_style_box(box, rect)
		if i < 3 and label == _world.next_jump_preset and not active:
			draw_rect(rect.grow(-4.0), BROWN, false, 2.0)  # 다음 판에 적용될 설정
		_text(rect.get_center() + Vector2(0.0, 10.0), label, 30)
	var pending: bool = _world.next_jump_preset != JumpModel.preset
	# Gaegu 글꼴에 화살표·가운뎃점이 없어 글자로만 쓴다
	var status := "점프 %s%s, 안개 %s" % [JumpModel.preset, " (다음 판 %s)" % _world.next_jump_preset if pending else "", _world.mist_preset]
	_text(Vector2(get_viewport_rect().size.x - MARGIN - 200.0, MARGIN + BUTTON.y + 26.0), status, 24)


func _text(center: Vector2, text: String, font_size: int) -> void:
	var at := center - Vector2(FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5, 0.0)
	draw_string_outline(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, CREAM)
	draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, BROWN)
