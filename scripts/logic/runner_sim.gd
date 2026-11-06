class_name RunnerSim
extends RefCounted
## 자동 달리기 + 누르는 만큼 점프 + 옥상 생성 (화면과 분리된 로직).
## step(dt, pressed)를 고정 시간 간격으로 부른다. 같은 시드·같은 입력이면 결과가 항상 같다.
##
## 좌표: x는 고양이 몸 가운데의 가로 위치(앞으로 갈수록 커짐), y는 고양이 발끝 높이(위로 커짐).
## 고양이는 몸 가운데(x)가 옥상 위에 있을 때만 그 옥상에 설 수 있다.

## 이번 step에서 일어난 일 (화면 연출용). step마다 지워진다.
var jumped := false
var landed := false
var fell := false

var x := 0.0
var y := 0.0
var vy := 0.0
var on_ground := true
var speed := Balance.RUN_SPEED
var roofs: Array[Dictionary] = []
## 착지한 뒤 지난 시간 (납작해짐 연출용). 착지 전이면 큰 값
var time_since_land := 99.0

var _generator: RoofGenerator
var _was_pressed := false
var _holding := false       # 점프 중 아직 누르고 있어 속도를 유지하는 중
var _hold_time := 0.0
var _buffer := 0.0          # 공중에서 누른 입력을 남겨 둔 시간
var _coyote := 0.0          # 옥상 끝을 지난 뒤 점프를 받아 주는 남은 시간


## start_speed: 처음 달리는 속도. 앞쪽 옥상 간격을 이 속도에 맞춰 바로 만들기 때문에 생성할 때 정한다
func _init(seed_value: int, start_speed: float = Balance.RUN_SPEED) -> void:
	speed = start_speed
	_generator = RoofGenerator.new(seed_value)
	roofs.append(RoofGenerator.first_roof(-400.0))
	y = roofs[0].top
	_fill_roofs()


## 시간 dt만큼 진행. pressed = 지금 화면(또는 스페이스바)을 누르고 있는지
func step(dt: float, pressed: bool) -> void:
	jumped = false
	landed = false
	fell = false
	var press_started := pressed and not _was_pressed
	_was_pressed = pressed
	time_since_land += dt

	x += speed * dt
	_fill_roofs()

	if press_started:
		_buffer = Balance.JUMP_BUFFER_TIME
	else:
		_buffer = maxf(0.0, _buffer - dt)

	if on_ground or _coyote > 0.0:
		if _buffer > 0.0:
			_start_jump(pressed)

	if on_ground:
		var roof := roof_at(x)
		if roof.is_empty() or roof.top != y:
			# 옥상 끝을 지나 발밑이 비었다
			on_ground = false
			_coyote = Balance.COYOTE_TIME
		return

	_coyote = maxf(0.0, _coyote - dt)
	if _holding and pressed and _hold_time < JumpModel.max_hold_time():
		var hold_dt := minf(dt, JumpModel.max_hold_time() - _hold_time)
		_hold_time += hold_dt
		vy = JumpModel.jump_speed()
		y += vy * hold_dt
		dt -= hold_dt
	else:
		_holding = false
	if dt > 0.0:
		# 등가속도 운동을 정확히 적분해 프레임 간격과 상관없이 같은 높이가 나오게 한다
		var prev_y := y
		y += vy * dt - 0.5 * Balance.GRAVITY * dt * dt
		vy -= Balance.GRAVITY * dt
		_check_landing(prev_y)

	if y < Balance.FALL_LIMIT:
		fell = true
		_respawn()


## 가로 위치 at_x 아래에 있는 옥상. 없으면 빈 Dictionary
func roof_at(at_x: float) -> Dictionary:
	for roof in roofs:
		if at_x >= roof.left and at_x <= roof.right:
			return roof
	return {}


func _start_jump(pressed: bool) -> void:
	on_ground = false
	_coyote = 0.0
	_buffer = 0.0
	vy = JumpModel.jump_speed()
	# 눌렀다 이미 뗀 입력(버퍼)이면 최소 높이로 뛴다
	_holding = pressed
	_hold_time = 0.0
	jumped = true


func _check_landing(prev_y: float) -> void:
	if vy > 0.0:
		return
	var roof := roof_at(x)
	# 위에서 옥상 높이를 지나 내려왔을 때만 선다 (옆 벽에 부딪힌 경우는 계속 떨어짐)
	if not roof.is_empty() and prev_y >= roof.top and y <= roof.top:
		y = roof.top
		vy = 0.0
		on_ground = true
		_holding = false
		landed = true
		time_since_land = 0.0


## 1단계 임시 처리: 떨어지면 앞쪽 옥상 위에서 다시 달린다 (2단계에서 게임 끝으로 바뀜)
func _respawn() -> void:
	for roof in roofs:
		if roof.right > x + 200.0:
			x = maxf(x, roof.left + 80.0)
			y = roof.top
			break
	vy = 0.0
	on_ground = true
	_holding = false
	_coyote = 0.0
	_buffer = 0.0
	time_since_land = 99.0
	_fill_roofs()


## 고양이 앞쪽까지 옥상을 만들고, 지나간 옥상은 지운다
func _fill_roofs() -> void:
	while roofs[-1].right < x + Balance.ROOF_LOOKAHEAD:
		roofs.append(_generator.next_roof(roofs[-1], speed))
	while roofs.size() > 1 and roofs[0].right < x - 1000.0:
		roofs.pop_front()
