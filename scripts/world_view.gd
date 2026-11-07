extends Node2D
## 게임 화면: 입력을 모아 RunnerSim을 고정 간격으로 진행시키고, 옥상(임시 그림)을 그리고 고양이(CatView)를 움직인다.
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

var sim := RunnerSim.new(randi())
var cat := CatView.new()
var _touches := {}
var _accumulator := 0.0
var _over_time := 0.0        # 게임 끝 뒤 지난 시간
var _was_pressed := false
var _wait_release := false  # 다시 시작한 손가락을 뗄 때까지 점프로 치지 않음
## 누른 신호를 로직이 한 번 볼 때까지 남겨 둔다: 한 프레임 안에 누르고 뗀 짧은 탭(느린 휴대폰)도 놓치지 않게
var _tap_pending := false


func _ready() -> void:
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
		_tap_pending = false
		pressed = is_pressed()
		_accumulator -= STEP
		if sim.game_over:
			_over_time = 0.0
			game_over.emit(sim.distance())
			break
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
