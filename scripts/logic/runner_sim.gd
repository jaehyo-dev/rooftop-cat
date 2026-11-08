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
## 더블점프: 공중에서 새로 누르면 1회 (첫 점프와 같은 방식, 최대 DOUBLE_JUMP_MAX_HEIGHT, 꼭대기에서 잠깐 떠 있음).
##   옥상·판에 서거나(투명화·구제 뒤 착지 포함) 줄을 눌러 튕기면 다시 생긴다. 점프 없이 떨어지다 코요테가 지나 쓴 것도 "점프함".
##   누른 순간 아래 발판에 곧(옥상·판 JUMP_BUFFER_TIME, 줄 LINE_BLOCK_EARLY 안) 닿을 것으로 계산되면 더블점프로 쓰지 않고
##   착지 점프·줄 누름으로 남긴다. 예측이 빗나가 그 발판 높이를 지나 내려갔는데 못 서면 그 step에 바로 더블점프로 바꾼다.
##   투명화로 떠오르는 중·구제 중에는 쓰지 않는다.
## 구조물(넓은 틈, RoofGenerator): 빨래줄(structures)은 틈을 가로지르는 줄로, 위에서 내려와 닿으면 줄에 실렸다가
##   누름 타이밍(닿기 LINE_PRESS_EARLY 전 ~ 닿은 뒤 LINE_RIDE_TIME, 새로 누른 것만)에 따라 튕긴다: 퍼펙트·누름은 높이 튕기고
##   더블점프가 다시 생김, 안 누름·너무 이른 누름은 낮게 튕기고 줄이 느슨해져 다시 받아 주지 않는다.
##   실려 있는 동안 발이 다음 옥상에 걸치면 바로 착지. 전봇대는 틈 한가운데 판(roofs에 들어 있는 platform 옥상)으로,
##   위에서 내려앉으면 서고 올라서면 다시 뛸 수 있다. 판은 벽 판정이 없다(몸이 닿아도 막히지 않음).
##   특수 틈 다음 옥상(no_ghost)은 벽에 닿아도 투명화 구제가 없다.
## 트램펄린(structures, kind "tramp", v0.5.0 2a-2): 옥상 끝 발사대. 판정은 빨래줄과 같은 코드(_touch_line·_ride·_bounce)를 쓴다.
##   달려 들어가 몸 가운데가 run_in_x를 지나거나 위에서 내려와 발이 걸치면 닿음. 닿기 LINE_BLOCK_EARLY 안의 땅 위 누름은 점프가 아니라
##   트램펄린 누름으로 남긴다. 누름·퍼펙트는 앞으로 발사(가로 속도 tramp.good_vx·perfect_vx, 내려설 때까지), 안 누름·이른 누름은
##   제자리에서 낮게 튀고(가로 속도 그대로) 다시 받아 주지 않는다.
## 아이템: 몸에 닿은 생선은 fish에 더하고, 종이상자는 하나만 가진다(has_box). 상자를 가진 채 화면 맨 아래까지
## 떨어지면 상자를 쓰고 가까운 앞 옥상 위로 올라간다(구제). 구제 중에는 벽을 통과하고 입력을 받지 않는다.

## 이번 step에서 일어난 일 (화면 연출용). step마다 지워진다.
var jumped := false
var landed := false
var fell := false             # 떨어져서 이번 step에 게임이 끝남
var ghosted := false  # 벽에 부딪혀 투명화가 시작됨
var rescued := false  # 종이상자로 구제가 시작됨
var bounced := false  # 빨래줄에서 튕김 (결과는 bounce_result)
var double_jumped := false  # 더블점프를 씀
## 이번 step에 먹은 아이템들 (먹는 연출용)
var picked: Array[Dictionary] = []

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
## 틈을 가로지르는 빨래줄들 (옥상 생성 때 roof.line에서 꺼내 둠). 지나간 것은 지운다
var structures: Array[Dictionary] = []
## 아직 먹지 않은 아이템 (ItemPlacer 형식). 먹거나 지나간 아이템은 지운다
var items: Array[Dictionary] = []
## 이번 판에 먹은 생선 수
var fish := 0
## 종이상자를 가지고 있는지 (한 번에 1개만)
var has_box := false
## 종이상자로 구제되어 올라가는 중인지
var rescuing := false
## 투명화 남은 시간 (0이면 보통 상태)
var ghost_time := 0.0
## 착지한 뒤 지난 시간 (납작해짐 연출용). 착지 전이면 큰 값
var time_since_land := 99.0
## 점프한 뒤 지난 시간 (웅크림·도약 연출용). 점프 전이면 큰 값
var time_since_jump := 99.0
## 마지막으로 밟아 튕긴 빨래줄과 그 뒤 지난 시간 (줄이 출렁이는 연출용)
var bounced_line := {}
var time_since_bounce := 99.0
## 마지막 줄 튕김 결과: "perfect", "good", "early"(너무 이른 누름), "miss"(안 누름). 다음 튕김까지 남아 있음
var bounce_result := ""
## 더블점프를 쓴 뒤 지난 시간 (공중제비 연출용). 쓰기 전이면 큰 값
var time_since_double_jump := 99.0

var _generator: RoofGenerator
var _placer: ItemPlacer
var _start_speed := Balance.RUN_SPEED
var _start_x := 0.0
var _ground_roof := {}      # 지금 서 있는 옥상
var _ghost_roof := {}       # 투명화로 통과해 올라설 옥상 (부딪힌 벽의 옥상)
var _was_pressed := false
var _jumped := false        # 마지막으로 옥상에 선 뒤 점프했는지
var _holding := false       # 점프 중 아직 누르고 있어 속도를 유지하는 중
var _hold_time := 0.0
var _hold_max := JumpModel.max_hold_time()  # 이번 점프에서 누를 수 있는 최대 시간 (첫 점프·더블점프가 다름)
var _press_y := 0.0         # 이번 점프를 누른 자리의 높이 (손을 뗄 때 얼마나 올라왔는지 봄)
var _double_used := false   # 이번 공중에서 더블점프를 썼는지 (서거나 줄을 눌러 튕기면 다시 생김)
var _floating := false      # 더블점프 궤적이라 꼭대기에서 중력이 줄어드는 중
var _press_age := 99.0      # 마지막으로 새로 누른 뒤 지난 시간, 이번 step 시작 기준 (줄 누름 판정)
var _held_top := NAN        # 착지·줄 누름으로 남겨 둔 공중 누름: 이 높이를 지나 내려갔는데 못 서면 더블점프로 바꾼다
var _ride_line := {}        # 지금 실려 있는 빨래줄 (닿은 뒤 튕기기 전)
var _ride_time := 0.0       # 줄에 실린 뒤 지난 시간
var _slack_line := {}       # 실패 튕김으로 느슨해진 줄 (이 줄은 다시 받아 주지 않음)
var _launch_vx := 0.0       # 트램펄린 발사 가로 속도 (내려설 때까지, 0이면 달리는 속도)
var _buffer := 0.0          # 공중에서 누른 입력을 남겨 둔 시간
var _coyote := 0.0          # 옥상 끝을 지난 뒤 점프를 받아 주는 남은 시간


## start_speed: 처음 달리는 속도. 앞쪽 옥상 간격을 이 속도에 맞춰 바로 만들기 때문에 생성할 때 정한다
func _init(seed_value: int, start_speed: float = Balance.RUN_SPEED) -> void:
	speed = start_speed
	_start_speed = start_speed
	_generator = RoofGenerator.new(seed_value)
	_placer = ItemPlacer.new(seed_value)
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
	rescued = false
	bounced = false
	double_jumped = false
	picked.clear()
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
	time_since_bounce += dt
	time_since_double_jump += dt
	_press_age = 0.0 if press_started else _press_age + dt

	_move_forward(vx() * dt)
	_fill_roofs()
	_pick_items()

	if rescuing:
		_rescue_rise(dt)
		return

	if press_started:
		_buffer = Balance.JUMP_BUFFER_TIME
	else:
		_buffer = maxf(0.0, _buffer - dt)

	if (on_ground or _coyote > 0.0) and _buffer > 0.0:
		var tramp := _tramp_ahead() if on_ground else {}
		if not tramp.is_empty() and run_in_x(tramp) - x <= speed * Balance.LINE_BLOCK_EARLY:
			_buffer = 0.0  # 트램펄린 바로 앞 누름은 점프가 아니라 트램펄린 누름 (닿을 때 _press_age로 판정)
		else:
			_start_jump(pressed)
	elif press_started and not on_ground:
		_air_press(pressed)

	if ghost_time > 0.0 and _ghost_rise(dt):
		return

	if not _ride_line.is_empty():
		_ride(dt, press_started)
		return

	if on_ground:
		var tramp := _tramp_ahead()
		if not tramp.is_empty() and x >= run_in_x(tramp):
			# 달려 들어가 몸 가운데가 그물 가운데쯤을 지남 = 닿음 (after = 이번 step에서 닿은 뒤 지난 시간)
			on_ground = false
			_coyote = 0.0
			_touch_line(tramp, minf(dt, (x - run_in_x(tramp)) / maxf(speed, 1.0)), dt)
			return
		if not _feet_over(_ground_roof):
			# 발 범위가 옥상 끝을 다 지나 발밑이 비었다
			on_ground = false
			_coyote = Balance.COYOTE_TIME
		return

	_coyote = maxf(0.0, _coyote - dt)
	if _holding and pressed and _hold_time < _hold_max:
		var hold_dt := minf(dt, _hold_max - _hold_time)
		_hold_time += hold_dt
		var held := JumpModel.hold_state(vy, hold_dt)
		y += held.x
		vy = held.y
		dt -= hold_dt
	elif _holding:
		_holding = false
		vy = JumpModel.release_speed(y - _press_y, vy)
	if dt > 0.0:
		# 등가속도 운동을 정확히 적분해 프레임 간격과 상관없이 같은 높이가 나오게 한다 (떠 있는 구간 경계에서 쪼갬)
		var prev_y := y
		var moved := JumpModel.integrate(y, vy, dt, _floating)
		y = moved.x
		vy = moved.y
		_check_landing(prev_y, dt)
	# 착지·줄 누름으로 남겨 둔 누름이 빗나감: 그 발판 높이를 지나 내려갔는데 서지 못했으면 지금 더블점프로
	if not is_nan(_held_top) and not on_ground and _ride_line.is_empty() and not bounced and y < _held_top:
		_held_top = NAN
		if _can_double():
			_start_double(pressed)

	if has_box and y < Balance.RESCUE_HEIGHT:
		# 종이상자가 받쳐 준다 (한 번만)
		has_box = false
		rescuing = true
		rescued = true
		_launch_vx = 0.0
		_holding = false
		_floating = false
		_held_top = NAN
		_buffer = 0.0  # 구제 중에는 입력을 받지 않으니, 직전에 누른 입력이 복귀 뒤 점프로 남지 않게 지운다
		vy = 0.0
		ghost_time = 0.0
	elif y < Balance.FALL_LIMIT:
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
	return clampf(_hold_time / _hold_max, 0.0, 1.0)


## 이제 어떤 옥상에도 올라설 수 없이 떨어지는 중인지 (허우적거리는 연출용).
## 발밑이나 바로 앞 옥상보다 아래로 내려가 착지도, 투명화 통과(몸 높이 안쪽)도 못 하는 경우.
func is_doomed() -> bool:
	if on_ground or rescuing or vy >= 0.0 or not _ride_line.is_empty():
		return false
	for roof in roofs:
		if roof.right < x - Balance.CAT_FOOT_HALF:
			continue
		# 발이 옥상에 걸쳐 있는데 옥상보다 아래면 아래에서 올라설 수 없다.
		# 앞 옥상이면 점프했을 때만 투명화로 오를 수 있는 높이(몸 높이)까지 괜찮다 (점프 없이 떨어지면 벽에 막힘)
		if roof.get("platform", false) and y < roof.top:
			continue  # 판은 위에서만 서니, 판 높이 아래로 내려왔으면 판은 이제 상관없다 (그 뒤 옥상으로 판단)
		var margin: float = Balance.CAT_BODY_SIZE.y if _jumped and not _feet_over(roof) and not roof.get("no_ghost", false) else 0.0
		if _can_double():
			margin += Balance.DOUBLE_JUMP_MAX_HEIGHT  # 더블점프가 남아 있으면 아직 오를 수 있음 (그림용 대략값)
		return y < roof.top - margin
	return true


## 고양이가 내려앉을 옥상(발 범위가 아직 다 지나가지 않은 가장 가까운 옥상·판)의 높이 (세로 카메라용). 없으면 0
func landing_top() -> float:
	for roof in roofs:
		if roof.right >= x - Balance.CAT_FOOT_HALF:
			return roof.top
	return 0.0


## 지금 앞으로 가는 속도 (트램펄린 발사 중이면 발사 속도)
func vx() -> float:
	return maxf(speed, _launch_vx)


## 달려 들어갈 때 닿는 자리 (몸 가운데): 그물 가운데쯤
static func run_in_x(tramp: Dictionary) -> float:
	return tramp.left + Balance.TRAMP_RUN_IN


## 서 있는 옥상 위, 아직 닿지 않은(몸 가운데가 오른쪽 끝 전) 받아 주는 트램펄린. 없으면 빈 Dictionary
func _tramp_ahead() -> Dictionary:
	for s in structures:
		if s.kind == "tramp" and not is_same(s, _slack_line) and x <= s.right \
				and s.left >= _ground_roof.left and s.right <= _ground_roof.right and s.base == _ground_roof.top:
			return s
	return {}


## 몸 앞쪽 끝의 가로 위치
func front() -> float:
	return x + Balance.CAT_BODY_SIZE.x * 0.5


## 앞으로 distance만큼 간다. 몸 앞쪽이 자기 발보다 높은 옥상 벽에 닿으면 투명화가 시작된다
func _move_forward(distance: float) -> void:
	var old_front := front()
	x += distance
	if rescuing:
		return  # 구제 중에는 벽을 통과한다
	for roof in roofs:
		if roof.top > y and roof.left >= old_front - 0.001 and roof.left < front() and not roof.get("platform", false):
			var near_miss: bool = _jumped and roof.top - y <= Balance.CAT_BODY_SIZE.y
			# 투명화로 떠오르는 중(발이 올라설 옥상 위)에 닿은 벽도 통과한다
			var rising: bool = ghost_time > 0.0 and not _ghost_roof.is_empty() and _feet_over(_ghost_roof)
			if (on_ground or near_miss or rising) and not roof.get("no_ghost", false):
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
	_held_top = NAN
	vy = 0.0
	y = minf(roof.top, y + Balance.GHOST_RISE_SPEED * dt)
	if y >= roof.top:
		_land_on(roof)
	return true


## 구제 중: 발 범위가 아직 다 지나가지 않은 가장 가까운 옥상 높이로 올라가, 발이 그 옥상에 걸치면 올라선다
func _rescue_rise(dt: float) -> void:
	for roof in roofs:
		if roof.right < x + Balance.CAT_FOOT_HALF:
			continue
		y = move_toward(y, roof.top, Balance.RESCUE_RISE_SPEED * dt)
		if y == roof.top and _feet_over(roof):
			rescuing = false
			_land_on(roof)
		return


## 몸(타원)에 닿은 아이템을 먹는다. 상자를 이미 가지고 있으면 상자는 그대로 둔다
func _pick_items() -> void:
	var center_y := y + Balance.CAT_BODY_SIZE.y * 0.5
	var radius := Balance.CAT_BODY_SIZE * 0.5 + Vector2.ONE * Balance.ITEM_RADIUS
	for i in range(items.size() - 1, -1, -1):
		var item := items[i]
		if item.x < x - 1000.0:
			items.remove_at(i)  # 지나간 아이템
			continue
		var d := Vector2((item.x - x) / radius.x, (item.y - center_y) / radius.y)
		if d.length_squared() > 1.0 or (item.kind == "box" and has_box):
			continue
		if item.kind == "fish":
			fish += 1
		else:
			has_box = true
		picked.append(item)
		items.remove_at(i)


## 발 범위가 옥상에 걸쳐 있는지
func _feet_over(roof: Dictionary) -> bool:
	return x + Balance.CAT_FOOT_HALF >= roof.left and x - Balance.CAT_FOOT_HALF <= roof.right


func _start_jump(pressed: bool) -> void:
	on_ground = false
	_coyote = 0.0
	_buffer = 0.0
	_held_top = NAN
	# 눌렀다 이미 뗀 입력(버퍼)이면 최소 높이로 뛴다
	vy = JumpModel.jump_speed() if pressed else JumpModel.release_speed(0.0, JumpModel.jump_speed())
	_press_y = y
	_jumped = true
	_floating = false
	_holding = pressed
	_hold_time = 0.0
	_hold_max = JumpModel.max_hold_time()
	time_since_jump = 0.0
	jumped = true


## 더블점프: 떨어지던 속도를 지우고 다시 올라간다 (누르는 동안 double_max_hold까지 첫 점프처럼)
func _start_double(pressed: bool) -> void:
	_double_used = true
	_floating = true
	_jumped = true  # 점프 없이 떨어지다 썼어도 모서리 투명화 구제를 받는다
	_coyote = 0.0
	_buffer = 0.0
	_held_top = NAN
	vy = JumpModel.double_speed() if pressed else JumpModel.release_speed(0.0, JumpModel.double_speed())
	_press_y = y
	_holding = pressed
	_hold_time = 0.0
	_hold_max = JumpModel.double_max_hold()
	time_since_double_jump = 0.0
	double_jumped = true


## 더블점프를 쓸 수 있는지 (공중, 아직 안 씀, 투명화로 떠오르는 중·구제 중·줄에 실린 중이 아님)
func _can_double() -> bool:
	if on_ground or rescuing or _double_used or not _ride_line.is_empty():
		return false
	return not (ghost_time > 0.0 and not _ghost_roof.is_empty() and _feet_over(_ghost_roof) and _ghost_roof.top > y)


## 코요테가 지난 공중에서 새로 누름: 곧 닿을 발판이 있으면 착지 점프·줄 누름으로 남기고, 아니면 더블점프
func _air_press(pressed: bool) -> void:
	var touch := line_touch_eta(Balance.LINE_BLOCK_EARLY)
	if not touch.is_empty():
		_held_top = touch.line.top  # 줄 누름 판정은 닿을 때 _press_age로 (_buffer는 쓰지 않음)
		_buffer = 0.0
		return
	var land := _surface_eta(Balance.JUMP_BUFFER_TIME, false)
	if not land.is_empty():
		_held_top = land.surface.top  # _buffer가 남아 있어 착지하자마자 뛴다
		return
	if _can_double():
		_start_double(pressed)


## 지금 움직임 그대로 within초 안에 위에서 내려와 닿는 첫 발판. {"surface", "t", "x"} 또는 빈 Dictionary.
## lines_only면 받아 주는 빨래줄만, 아니면 옥상·판만 본다. 앞으로 갈 거리는 지금 속도로 계산
func _surface_eta(within: float, lines_only: bool) -> Dictionary:
	if on_ground or not _ride_line.is_empty() or rescuing:
		return {}
	var candidates: Array = []
	if lines_only:
		for line in structures:
			if not is_same(line, _slack_line):
				candidates.append(line)
	else:
		candidates = roofs
	var best := {}
	for surface in candidates:
		if surface.top > y:
			continue  # 이미 그 높이 아래 (아래에서는 서지 않음)
		var t := JumpModel.fall_to(y, vy, surface.top, _floating)
		if t < 0.0 or t > within:
			continue
		var at_x := x + vx() * t
		# step은 앞으로 먼저 간 뒤 착지를 보므로, 닿는 자리는 최대 한 프레임(1/60초) 거리만큼 앞일 수 있다
		var slop := vx() / 60.0
		if at_x + Balance.CAT_FOOT_HALF + slop >= surface.left and at_x - Balance.CAT_FOOT_HALF <= surface.right and (best.is_empty() or t < best.t):
			best = {"surface": surface, "t": t, "x": at_x}
	return best


## 지금 움직임 그대로 within초 안에 닿을 빨래줄 {"line", "t"(남은 시간), "x"(닿는 가로 위치)}. 줄에 실려 있으면 t = 0. 없으면 빈 Dictionary
## (화면의 "눌러!" 안내와 공중 누름 판정에 씀)
func line_touch_eta(within: float) -> Dictionary:
	if not _ride_line.is_empty():
		return {"line": _ride_line, "t": 0.0, "x": x}
	if on_ground:
		# 달려 들어가는 트램펄린: 몸 가운데가 닿는 자리에 오는 때
		var tramp := _tramp_ahead()
		var eta: float = INF if tramp.is_empty() else (run_in_x(tramp) - x) / maxf(speed, 1.0)
		return {"line": tramp, "t": maxf(eta, 0.0), "x": run_in_x(tramp)} if eta <= within else {}
	var hit := _surface_eta(within, true)
	return {} if hit.is_empty() else {"line": hit.surface, "t": hit.t, "x": hit.x}


## 지금 줄에 실려 있는지 (닿은 뒤 튕기기 전)
func is_riding() -> bool:
	return not _ride_line.is_empty()


## 실패 튕김으로 느슨해져 더 받아 주지 않는 줄인지
func is_slack(line: Dictionary) -> bool:
	return is_same(line, _slack_line)


func _check_landing(prev_y: float, dt: float) -> void:
	if vy > 0.0:
		return
	# 위에서 지나 내려온 발판 중 가장 높은 것에 선다 (옥상과 구조물. 높이가 같으면 먼저 본 구조물)
	var best := {}
	for surface in structures + roofs:
		if is_same(surface, _slack_line):
			continue  # 느슨해진 줄은 받아 주지 않는다
		# 위에서 높이를 지나 내려왔을 때만 선다 (아래에서 벽에 부딪힌 경우는 계속 떨어짐)
		if _feet_over(surface) and prev_y >= surface.top and y <= surface.top and (best.is_empty() or surface.top > best.top):
			best = surface
	if best.is_empty():
		return
	if best.has("kind"):  # 빨래줄·트램펄린
		# 이번 step 안에서 줄에 닿은 뒤 지난 시간 (높이가 줄을 지난 비율로 나눔): 판정이 프레임 간격에 덜 흔들리게
		var after: float = dt * (best.top - y) / maxf(prev_y - y, 0.0001)
		_touch_line(best, after, dt)
	else:
		_land_on(best)


## 줄에 닿음: 닿기 전 누름이면 바로 판정해 튕기고, 아니면 줄에 실려 닿은 뒤 누름을 기다린다. after = 닿은 뒤 이미 지난 시간
func _touch_line(line: Dictionary, after: float, dt: float) -> void:
	y = line.top
	vy = 0.0
	_holding = false
	_held_top = NAN
	# 닿는 순간에서 본 마지막 새 누름 (_press_age는 이번 step 시작 기준, 닿은 때는 step 시작 + (dt - after))
	var age := _press_age + dt - after
	if age >= 0.0 and age <= Balance.LINE_BLOCK_EARLY:
		if age <= Balance.LINE_PERFECT:
			_bounce(line, "perfect")
		elif age <= Balance.LINE_PRESS_EARLY:
			_bounce(line, "good")
		else:
			_bounce(line, "early")
		return
	_ride_line = line
	_ride_time = after
	_ride(0.0, false)


## 줄에 실려 있는 동안: 닿은 뒤 새로 누르면 판정해 튕기고, LINE_RIDE_TIME이 지나면 실패 튕김. 발이 다음 옥상에 걸치면 착지
func _ride(dt: float, press_started: bool) -> void:
	var line := _ride_line
	_ride_time += dt
	y = line.top
	vy = 0.0
	for roof in roofs:
		if roof.left >= line.right - 0.001 and _feet_over(roof) and not roof.get("platform", false):
			_ride_line = {}
			_land_on(roof)
			return
	if press_started:
		_ride_line = {}
		# 누른 때는 이번 step 시작 (_touch_line의 _press_age와 같은 기준이라 프레임 간격에 따라 창이 바뀌지 않음)
		_bounce(line, "perfect" if _ride_time - dt <= Balance.LINE_PERFECT else "good")
	elif _ride_time > Balance.LINE_RIDE_TIME:
		_ride_line = {}
		_bounce(line, "miss")


## 빨래줄·트램펄린에서 튕긴다. result: perfect / good (더블점프 다시 생김, 트램펄린은 앞으로 발사) / early / miss (낮게, 다시 안 받아 줌)
func _bounce(line: Dictionary, result: String) -> void:
	var tramp: bool = line.kind == "tramp"
	var height := Balance.TRAMP_MISS_HEIGHT if tramp else Balance.LINE_MISS_HEIGHT
	if result == "perfect":
		height = Balance.TRAMP_PERFECT_HEIGHT if tramp else Balance.LINE_PERFECT_HEIGHT
		_launch_vx = line.perfect_vx if tramp else 0.0
	elif result == "good":
		height = Balance.TRAMP_GOOD_HEIGHT if tramp else Balance.LINE_GOOD_HEIGHT
		_launch_vx = line.good_vx if tramp else 0.0
	if result == "perfect" or result == "good":
		_double_used = false
	else:
		_slack_line = line
	y = line.top
	vy = RoofGenerator.line_bounce_speed(height)
	_held_top = NAN  # 이 누름은 튕김에 썼다 (남겨 두면 튕긴 뒤 줄·그물 높이를 지나 내려올 때 더블점프로 바뀜)
	_buffer = 0.0
	_holding = false
	_floating = false
	_jumped = true  # 튕겨 오르다 살짝 모자라 모서리에 걸려도 투명화로 구제됨 (점프와 같은 취급)
	bounced = true
	bounce_result = result
	bounced_line = line
	time_since_bounce = 0.0


func _land_on(roof: Dictionary) -> void:
	y = roof.top
	vy = 0.0
	on_ground = true
	_ground_roof = roof
	_holding = false
	_jumped = false
	_double_used = false
	_floating = false
	_held_top = NAN
	_ride_line = {}
	_launch_vx = 0.0
	landed = true
	time_since_land = 0.0


## 고양이 앞쪽까지 옥상을 만들고, 지나간 옥상은 지운다
func _fill_roofs() -> void:
	while roofs[-1].right < x + Balance.ROOF_LOOKAHEAD:
		var roof := _generator.next_roof(roofs[-1], speed)
		items.append_array(_placer.items_for(roofs[-1], roof))
		roofs.append(roof)
		if roof.has("line"):
			structures.append(roof.line)
		if roof.has("tramp"):
			structures.append(roof.tramp)
	while roofs.size() > 1 and roofs[0].right < x - 1000.0:
		roofs.pop_front()
	while not structures.is_empty() and structures[0].right < x - 1000.0:
		structures.pop_front()
