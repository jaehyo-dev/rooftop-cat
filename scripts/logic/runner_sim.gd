class_name RunnerSim
extends RefCounted
## 자동 달리기(점점 빨라짐) + 누르는 만큼 점프 + 옥상 생성 + 떨어지면 게임 끝 (화면과 분리된 로직).
## step(dt, pressed)를 고정 시간 간격으로 부른다. 같은 시드·같은 입력이면 결과가 항상 같다.
##
## 좌표: x는 고양이 몸 가운데의 가로 위치(앞으로 갈수록 커짐), y는 고양이 발끝 높이(위로 커짐).
## 충돌 판정은 몸 크기(Balance.CAT_BODY_SIZE) 기준:
## - 서기·착지: 발 범위(x ± Balance.CAT_FOOT_HALF)가 옥상에 걸치면 된다.
## - 벽: 몸 앞쪽(x + 몸 너비의 절반)이 자기보다 높은 옥상 벽에 닿았을 때
##   - 달리다 부딪혔거나, 점프했는데 살짝 모자라 몸이 모서리에 걸렸으면(몸 높이 안쪽) 잠시 투명해져(ghost_time)
##     벽을 통과하고, 발 범위가 그 옥상에 걸치면 옥상 위로 떠올라 올라선다.
##   - 점프 없이 틈으로 떨어지는 중이거나 너무 낮게 부딪혔으면 벽에 막혀 그대로 떨어진다 (투명화가 남아 있어도).

## 이번 step에서 일어난 일 (화면 연출용). step마다 지워진다.
var jumped := false
var landed := false
var fell := false             # 떨어져서 이번 step에 게임이 끝남
var ghosted := false  # 벽에 부딪혀 투명화가 시작됨

var x := 0.0
var y := 0.0
var vy := 0.0
var on_ground := true
var speed := Balance.RUN_SPEED
## false면 속도가 그대로 (속도별 테스트용)
var accelerate := true
## 떨어져서 게임이 끝났는지. 끝나면 step은 아무것도 하지 않는다
var game_over := false
## 달린 시간 (초)
var elapsed := 0.0
var roofs: Array[Dictionary] = []
## 투명화 남은 시간 (0이면 보통 상태)
var ghost_time := 0.0
## 착지한 뒤 지난 시간 (납작해짐 연출용). 착지 전이면 큰 값
var time_since_land := 99.0
## 점프한 뒤 지난 시간 (웅크림·도약 연출용). 점프 전이면 큰 값
var time_since_jump := 99.0

var _generator: RoofGenerator
var _start_speed := Balance.RUN_SPEED
var _start_x := 0.0
var _ground_roof := {}      # 지금 서 있는 옥상
var _ghost_roof := {}       # 투명화로 통과해 올라설 옥상 (부딪힌 벽의 옥상)
var _was_pressed := false
var _jumped := false        # 마지막으로 옥상에 선 뒤 점프했는지
var _holding := false       # 점프 중 아직 누르고 있어 속도를 유지하는 중
var _hold_time := 0.0
var _buffer := 0.0          # 공중에서 누른 입력을 남겨 둔 시간
var _coyote := 0.0          # 옥상 끝을 지난 뒤 점프를 받아 주는 남은 시간


## start_speed: 처음 달리는 속도. 앞쪽 옥상 간격을 이 속도에 맞춰 바로 만들기 때문에 생성할 때 정한다
func _init(seed_value: int, start_speed: float = Balance.RUN_SPEED) -> void:
	speed = start_speed
	_start_speed = start_speed
	_generator = RoofGenerator.new(seed_value)
	roofs.append(RoofGenerator.first_roof(-400.0))
	_ground_roof = roofs[0]
	y = roofs[0].top
	_start_x = x
	_fill_roofs()


## 시간 dt만큼 진행. pressed = 지금 화면(또는 스페이스바)을 누르고 있는지
func step(dt: float, pressed: bool) -> void:
	jumped = false
	landed = false
	fell = false
	ghosted = false
	if game_over:
		return
	elapsed += dt
	if accelerate:
		speed = SpeedCurve.speed_at(elapsed, _start_speed)
	ghost_time = maxf(0.0, ghost_time - dt)
	var press_started := pressed and not _was_pressed
	_was_pressed = pressed
	time_since_land += dt
	time_since_jump += dt

	_move_forward(speed * dt)
	_fill_roofs()

	if press_started:
		_buffer = Balance.JUMP_BUFFER_TIME
	else:
		_buffer = maxf(0.0, _buffer - dt)

	if (on_ground or _coyote > 0.0) and _buffer > 0.0:
		_start_jump(pressed)

	if ghost_time > 0.0 and _ghost_rise(dt):
		return

	if on_ground:
		if not _feet_over(_ground_roof):
			# 발 범위가 옥상 끝을 다 지나 발밑이 비었다
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
		game_over = true


## 가로 위치 at_x 아래에 있는 옥상. 없으면 빈 Dictionary
func roof_at(at_x: float) -> Dictionary:
	for roof in roofs:
		if at_x >= roof.left and at_x <= roof.right:
			return roof
	return {}


## 거리 점수 (미터, 소수점 버림): 시작 위치에서 앞으로 간 거리
func distance() -> int:
	return int(maxf(0.0, x - _start_x) / Balance.PX_PER_METER)


## 점프 중 아직 누르고 있어 올라가는 중인지 (화면 연출용)
func is_holding() -> bool:
	return _holding and not on_ground


## 지금 점프에서 누른 시간의 비율 (0 = 톡, 1 = 최대로 누름)
func hold_ratio() -> float:
	return clampf(_hold_time / JumpModel.max_hold_time(), 0.0, 1.0)


## 이제 어떤 옥상에도 올라설 수 없이 떨어지는 중인지 (허우적거리는 연출용).
## 발밑이나 바로 앞 옥상보다 아래로 내려가 착지도, 투명화 통과(몸 높이 안쪽)도 못 하는 경우.
func is_doomed() -> bool:
	if on_ground or vy >= 0.0:
		return false
	for roof in roofs:
		if roof.right < x - Balance.CAT_FOOT_HALF:
			continue
		# 발이 옥상에 걸쳐 있는데 옥상보다 아래면 아래에서 올라설 수 없다.
		# 앞 옥상이면 점프했을 때만 투명화로 오를 수 있는 높이(몸 높이)까지 괜찮다 (점프 없이 떨어지면 벽에 막힘)
		var margin: float = Balance.CAT_BODY_SIZE.y if _jumped and not _feet_over(roof) else 0.0
		return y < roof.top - margin
	return true


## 몸 앞쪽 끝의 가로 위치
func front() -> float:
	return x + Balance.CAT_BODY_SIZE.x * 0.5


## 앞으로 distance만큼 간다. 몸 앞쪽이 자기 발보다 높은 옥상 벽에 닿으면 투명화가 시작된다
func _move_forward(distance: float) -> void:
	var old_front := front()
	x += distance
	for roof in roofs:
		if roof.top > y and roof.left >= old_front - 0.001 and roof.left < front():
			var near_miss: bool = _jumped and roof.top - y <= Balance.CAT_BODY_SIZE.y
			# 투명화로 떠오르는 중(발이 올라설 옥상 위)에 닿은 벽도 통과한다
			var rising: bool = ghost_time > 0.0 and not _ghost_roof.is_empty() and _feet_over(_ghost_roof)
			if on_ground or near_miss or rising:
				# 투명화 중에 또 부딪히면 시간은 그대로 두고 올라설 옥상만 바꾼다
				if ghost_time == 0.0:
					ghost_time = Balance.GHOST_TIME
					ghosted = true
				_ghost_roof = roof
			else:
				# 투명화가 남아 있어도 틈으로 떨어지다 닿은 벽은 통과하지 못한다
				x = roof.left - Balance.CAT_BODY_SIZE.x * 0.5
				ghost_time = 0.0
			return


## 투명화 중 발 범위가 부딪힌 옥상에 걸치면 그 옥상 위로 떠오른다. 떠오르는 중이면 true
func _ghost_rise(dt: float) -> bool:
	var roof := _ghost_roof
	if roof.is_empty() or not (_feet_over(roof) and roof.top > y):
		return false
	on_ground = false
	_holding = false
	vy = 0.0
	y = minf(roof.top, y + Balance.GHOST_RISE_SPEED * dt)
	if y >= roof.top:
		_land_on(roof)
	return true


## 발 범위가 옥상에 걸쳐 있는지
func _feet_over(roof: Dictionary) -> bool:
	return x + Balance.CAT_FOOT_HALF >= roof.left and x - Balance.CAT_FOOT_HALF <= roof.right


func _start_jump(pressed: bool) -> void:
	on_ground = false
	_coyote = 0.0
	_buffer = 0.0
	vy = JumpModel.jump_speed()
	_jumped = true
	# 눌렀다 이미 뗀 입력(버퍼)이면 최소 높이로 뛴다
	_holding = pressed
	_hold_time = 0.0
	time_since_jump = 0.0
	jumped = true


func _check_landing(prev_y: float) -> void:
	if vy > 0.0:
		return
	for roof in roofs:
		# 위에서 옥상 높이를 지나 내려왔을 때만 선다 (아래에서 벽에 부딪힌 경우는 계속 떨어짐)
		if _feet_over(roof) and prev_y >= roof.top and y <= roof.top:
			_land_on(roof)
			return


func _land_on(roof: Dictionary) -> void:
	y = roof.top
	vy = 0.0
	on_ground = true
	_ground_roof = roof
	_holding = false
	_jumped = false
	landed = true
	time_since_land = 0.0


## 고양이 앞쪽까지 옥상을 만들고, 지나간 옥상은 지운다
func _fill_roofs() -> void:
	while roofs[-1].right < x + Balance.ROOF_LOOKAHEAD:
		roofs.append(_generator.next_roof(roofs[-1], speed))
	while roofs.size() > 1 and roofs[0].right < x - 1000.0:
		roofs.pop_front()
