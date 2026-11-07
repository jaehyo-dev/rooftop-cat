extends Node2D
## 게임 화면: 입력을 모아 RunnerSim을 고정 간격으로 진행시키고, 옥상(임시 그림)·아이템을 그리고 고양이(CatView)를 움직인다.
## 충돌 판정은 로직(RunnerSim)이 Balance.CAT_BODY_SIZE·CAT_FOOT_HALF로 하고, 고양이 그림은 같은 크기로 그리기만 한다.
## 떨어지면 game_over를 알리고, 잠시(Balance.RESTART_DELAY) 뒤 새로 누르면 새 판을 시작한다.

## 떨어져서 게임이 끝남 (meters = 이번 거리 점수)
signal game_over(meters: int)
## 새 판을 시작함
signal restarted

## 로직을 진행시키는 고정 간격 (화면 주사율과 상관없이 같은 손맛)
const STEP := 1.0 / 120.0
const MAX_STEPS_PER_FRAME := 12

const SKY_TOP := Color("#cfe6f2")
const SKY_BOTTOM := Color("#fbe9d4")
const ROOF_FILL := Color("#b98b6e")
const ROOF_EDGE := Color("#8a5f4a")
const ROOF_WALL := Color("#d7b49a")
## 아이템 그림 (assets/sprites/items/, 화면에 그릴 너비)
const FISH_TEXTURE := preload("res://assets/sprites/items/fish.png")
const BOX_TEXTURE := preload("res://assets/sprites/items/box.png")
## 구조물 그림 (assets/sprites/structures/, 화면에 그릴 크기)
const LINE_TEXTURE := preload("res://assets/sprites/structures/clothesline.png")
const POLE_TEXTURE := preload("res://assets/sprites/structures/pole.png")
const LINE_DRAW_WIDTH := 216.0   # 빨래줄 그림 너비 (기둥이 옥상에 닿도록 LINE_HEIGHT에 맞춘 크기)
const LINE_ROPE_FRAC := 0.2      # 빨래줄 그림에서 줄이 있는 높이 (그림 위에서부터 비율)
const POLE_WIDEN := 1.35         # 전봇대 그림을 가로로 넓혀 꼭대기가 고양이가 서기에 충분해 보이게
const POLE_EMBED := 8.0          # 기둥 아래가 옥상에 묻히는 정도
const LINE_BOUNCE_ANIM := 0.16   # 밟았을 때 줄이 출렁이는 시간 (초)
const FISH_WIDTH := 56.0
const BOX_WIDTH := 60.0
const RESCUE_BOX_WIDTH := 120.0  # 구제할 때 고양이를 받치는 상자
const POP_TIME := 0.3            # 먹은 아이템이 떠오르며 사라지는 시간

var sim := RunnerSim.new(randi())
var cat := CatView.new()
var _touches := {}
var _accumulator := 0.0
var _over_time := 0.0        # 게임 끝 뒤 지난 시간
var _was_pressed := false
var _wait_release := false  # 다시 시작한 손가락을 뗄 때까지 점프로 치지 않음
## 누른 신호를 로직이 한 번 볼 때까지 남겨 둔다: 한 프레임 안에 누르고 뗀 짧은 탭(느린 휴대폰)도 놓치지 않게
var _tap_pending := false
var _pops: Array[Dictionary] = []  # 먹은 아이템 연출 {"kind", "x", "y", "t"}
var _was_rescuing := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # 아이템 그림을 크게 줄여 그려도 거칠지 않게
	cat.name = "Cat"
	add_child(cat)
	_place_cat(0.0)


func _process(delta: float) -> void:
	var pressed := is_pressed()
	var press_started := pressed and not _was_pressed
	_was_pressed = pressed
	if sim.game_over:
		_over_time += delta
		_tap_pending = false
		if press_started and _over_time >= Balance.RESTART_DELAY:
			restart()
		return
	_wait_release = _wait_release and pressed
	_accumulator = minf(_accumulator + delta, STEP * MAX_STEPS_PER_FRAME)
	while _accumulator >= STEP:
		sim.step(STEP, pressed and not _wait_release)
		for item in sim.picked:
			_pops.append({"kind": item.kind, "x": item.x, "y": item.y, "t": 0.0})
		if _was_rescuing and not sim.rescuing:
			# 구제 끝: 받쳐 준 상자가 고양이 발밑에서 사라진다
			_pops.append({"kind": "box", "x": sim.x, "y": sim.y, "t": 0.0})
		_was_rescuing = sim.rescuing
		_tap_pending = false
		pressed = is_pressed()
		_accumulator -= STEP
		if sim.game_over:
			_over_time = 0.0
			game_over.emit(sim.distance())
			break
	for pop in _pops:
		pop.t += delta
	_pops = _pops.filter(func(pop: Dictionary) -> bool: return pop.t < POP_TIME)
	_place_cat(delta)
	queue_redraw()


## 고양이를 로직 위치(발끝)에 놓고 자세를 맞춘다
func _place_cat(delta: float) -> void:
	cat.position = Vector2(Balance.CAT_SCREEN_X, get_viewport_rect().size.y - sim.y)
	cat.show_state(sim, delta)


## 새 판: 새 옥상(새 시드)에서 처음 속도로 다시 달린다
func restart() -> void:
	sim = RunnerSim.new(randi())
	_accumulator = 0.0
	_pops.clear()
	_was_rescuing = false
	_wait_release = true
	_place_cat(0.0)
	restarted.emit()
	queue_redraw()


func _input(event: InputEvent) -> void:
	# 휴대폰 터치와 PC 마우스 클릭(터치로 흉내 냄)을 손가락별로 기억한다
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
			_tap_pending = true
		else:
			_touches.erase(event.index)
	elif event is InputEventKey and event.physical_keycode == KEY_SPACE and event.pressed and not event.echo:
		_tap_pending = true


func _notification(what: int) -> void:
	# 다른 앱·탭으로 넘어가면 뗀 신호를 못 받을 수 있으니 누름 상태를 지운다
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_touches.clear()


## 지금 누르고 있는지 (화면 어디든 터치, 마우스 클릭, 스페이스바)
func is_pressed() -> bool:
	return _tap_pending or not _touches.is_empty() or Input.is_physical_key_pressed(KEY_SPACE)


func _draw() -> void:
	var size := get_viewport_rect().size
	var ground := size.y  # 로직 높이 0 = 화면 맨 아래
	var offset := Balance.CAT_SCREEN_X - sim.x  # 로직 x → 화면 x

	# 하늘 (위아래 두 색)
	draw_polygon([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)],
			[SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM])

	for roof in sim.roofs:
		var left: float = roof.left + offset
		var right: float = roof.right + offset
		if right < 0.0 or left > size.x:
			continue
		var top: float = ground - roof.top
		draw_rect(Rect2(left, top, right - left, ground - top), ROOF_WALL)
		draw_rect(Rect2(left - 6.0, top, right - left + 12.0, 18.0), ROOF_FILL)
		draw_rect(Rect2(left - 6.0, top + 18.0, right - left + 12.0, 4.0), ROOF_EDGE)

	for structure in sim.structures:
		_draw_structure(structure, offset, ground)

	for item in sim.items:
		# 살짝 위아래로 떠 있어 눈에 띄게 (자리마다 박자를 다르게)
		var bob := 4.0 * sin(sim.elapsed * 4.0 + item.x * 0.01)
		_draw_item(item.kind, Vector2(item.x + offset, ground - item.y + bob), 1.0, 1.0)
	for pop in _pops:
		var k: float = pop.t / POP_TIME
		_draw_item(pop.kind, Vector2(pop.x + offset, ground - pop.y - 40.0 * k), 1.0 + 0.5 * k, 1.0 - k)
	if sim.rescuing:
		# 고양이 발밑에서 상자가 받쳐 올린다 (고양이는 자식 노드라 상자 위에 그려짐)
		var h := RESCUE_BOX_WIDTH * BOX_TEXTURE.get_height() / BOX_TEXTURE.get_width()
		draw_texture_rect(BOX_TEXTURE, Rect2(Balance.CAT_SCREEN_X - RESCUE_BOX_WIDTH * 0.5, ground - sim.y - h * 0.35,
				RESCUE_BOX_WIDTH, h), false)


## 구조물 그림: 빨래줄은 줄이 발판 높이에, 전봇대는 꼭대기 판이 발판 높이에 오게 그린다
func _draw_structure(structure: Dictionary, offset: float, ground: float) -> void:
	var cx: float = (structure.left + structure.right) * 0.5 + offset
	if cx < -200.0 or cx > get_viewport_rect().size.x + 200.0:
		return
	if structure.kind == "pole":
		var h: float = Balance.POLE_HEIGHT + POLE_EMBED
		var w := h * POLE_TEXTURE.get_width() / POLE_TEXTURE.get_height() * POLE_WIDEN
		draw_texture_rect(POLE_TEXTURE, Rect2(cx - w * 0.5, ground - structure.base - Balance.POLE_HEIGHT, w, h), false)
		return
	var line_h := LINE_DRAW_WIDTH * LINE_TEXTURE.get_height() / LINE_TEXTURE.get_width()
	# 밟은 직후에는 아래로 눌렸다 돌아오게 세로로 줄였다 늘린다 (기둥 아래는 그대로)
	var squash := 1.0
	if structure == sim.bounced_line and sim.time_since_bounce < LINE_BOUNCE_ANIM:
		squash = 1.0 - 0.18 * sin(PI * sim.time_since_bounce / LINE_BOUNCE_ANIM)
	var bottom: float = ground - structure.base + (line_h * (1.0 - LINE_ROPE_FRAC) - Balance.LINE_HEIGHT)
	draw_texture_rect(LINE_TEXTURE, Rect2(cx - LINE_DRAW_WIDTH * 0.5, bottom - line_h * squash, LINE_DRAW_WIDTH, line_h * squash), false)


## 아이템 그림을 가운데 pos에 그린다 (zoom 배율, alpha 투명도)
func _draw_item(kind: String, pos: Vector2, zoom: float, alpha: float) -> void:
	if pos.x < -100.0 or pos.x > get_viewport_rect().size.x + 100.0:
		return
	var texture: Texture2D = FISH_TEXTURE if kind == "fish" else BOX_TEXTURE
	var w := (FISH_WIDTH if kind == "fish" else BOX_WIDTH) * zoom
	var h := w * texture.get_height() / texture.get_width()
	draw_texture_rect(texture, Rect2(pos - Vector2(w, h) * 0.5, Vector2(w, h)), false, Color(1, 1, 1, alpha))
