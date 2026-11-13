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
## 장애물(obstacles, CoursePlacer): 몸 타원의 Balance.OBSTACLE_HIT_SCALE배로 판정. 부딪히면 하트 -1 + 무적(invuln_time), 속도는 그대로.
##   하트 0이면 게임 끝. 투명화·무적·구제 중에는 맞지 않는다. 비둘기 위치는 시간이 아니라 고양이 x의 함수다 (obstacle_left).
## 아이템: 몸에 닿은 생선은 fish에 더하고, 종이상자는 하나만 가진다(has_box). 상자를 가진 채 화면 맨 아래까지
## 떨어지면 상자를 쓰고 가까운 앞 옥상 위로 올라간다(구제). 구제 중에는 벽을 통과하고 입력을 받지 않으며 아이템도 먹지 않는다.
## 질주(dashing, PLAN 3·15번): 전용 분기 _dash_step. 벽·트램펄린·전봇대 판을 보지 않고 보이지 않는 발판 위를 달리며 장애물을 부순다.
##   점프·더블점프는 된다 (발판 아래로는 떨어지지 않음). 착지 옥상 위에서는 새로 뛰지 못하고, 땅에 있어야 질주가 끝난다.
##   남은 질주 거리가 앞 생성 범위보다 짧아지면 장애물 없는 착지 옥상을 끼워 넣고, 그 옥상 위에서 끝나 빈 곳에 내려놓는 일이 구조적으로 없다.
## 생선 길(FishRoad)과 콤보(combo): 필수 생선(bonus 없음)이 먹는 타원 뒤로 지나가면 콤보가 끊긴다. 질주·털실·구제·투명화 중과 질주 직후는 끊지 않는다.
## 털실(magnet_time): 반경 안 생선이 날아옴. 황금 생선: 생선 +GOLD_FISH. 쿠키: 하트 +1. 통조림: 화면 안 장애물이 생선으로 바뀜.
## 방울(has_bell): 다음 한 번의 부딪힘을 막는다 (하트보다 먼저 쓰임, 하나만 가짐).
## 줄줄이 고양이(parade, 시험판): parade_on일 때만. 점수(거리·생선)에 줄 배수, 부딪히면 맨 뒤가 도망 (A: 하트도 잃음, B: 줄이 있으면 하트 대신).

## 이번 step에서 일어난 일 (화면 연출용). step마다 지워진다.
var jumped := false
var landed := false
var fell := false             # 떨어져서 이번 step에 게임이 끝남
var ghosted := false  # 벽에 부딪혀 투명화가 시작됨
var rescued := false  # 종이상자로 구제가 시작됨
var bounced := false  # 빨래줄에서 튕김 (결과는 bounce_result)
var double_jumped := false  # 더블점프를 씀
var stage_rose := false  # 속도 단계가 올라 빨라지기 시작함
## 이번 step에 부딪힌 장애물 (튕겨 나가는 연출용). 없으면 빈 Dictionary
var hit_obstacle := {}
## 이번 step에 먹은 아이템들 (먹는 연출용)
var picked: Array[Dictionary] = []
var dash_started := false
var dash_ended := false
var bell_blocked := false  # 방울이 부딪힘을 막음 (막힌 장애물은 hit_obstacle)
var scared := false  # 부딪혀 맨 뒤 고양이가 도망감 (줄줄이 시험판)
## 이번 step에 질주로 부순 장애물들, 통조림으로 바뀐 장애물들 (x는 그 순간 판정 왼쪽 끝)
var smashed: Array[Dictionary] = []
var canned: Array[Dictionary] = []
## 이번 step에 부딪히지 않고 몸 뒤로 지나간 장애물들 (미션 "피하기"용. 질주·무적·투명화·구제 중에 지나간 것은 빠짐)
var passed: Array[Dictionary] = []

var x := 0.0
var y := 0.0
var vy := 0.0
var on_ground := true
var speed := Balance.RUN_SPEED
## 지금 속도 단계 (1부터, SpeedCurve)
var stage := 1
## 단계가 올라 빨라지기 시작한 뒤 지난 시간 (신호 연출용). 오르기 전이면 큰 값
var time_since_stage_rise := 99.0
## false면 속도가 그대로 (속도별 테스트용)
var accelerate := true
## 떨어져서 게임이 끝났는지. 끝나면 step은 아무것도 하지 않는다
var game_over := false
## 끝난 이유: "fall"(떨어짐), "hearts"(하트 0). 끝나기 전에는 빈 글자
var end_reason := ""
## 달린 시간 (초)
var elapsed := 0.0
var roofs: Array[Dictionary] = []
## 틈을 가로지르는 빨래줄들 (옥상 생성 때 roof.line에서 꺼내 둠). 지나간 것은 지운다
var structures: Array[Dictionary] = []
## 아직 먹지 않은 아이템 (ItemPlacer 형식). 먹거나 지나간 아이템은 지운다
var items: Array[Dictionary] = []
## 아직 지나가지 않은 장애물 (CoursePlacer 형식). 부딪히거나 지나간 것은 지운다
var obstacles: Array[Dictionary] = []
## 남은 하트 (저장하지 않음, 판마다 Balance.HEARTS_MAX)
var hearts := Balance.HEARTS_MAX
## 부딪힌 뒤 무적 남은 시간
var invuln_time := 0.0
## 마지막으로 부딪힌 뒤 지난 시간 (비틀거림·금 간 하트 연출용). 부딪히기 전이면 큰 값
var time_since_hit := 99.0
## 이번 판에 먹은 생선 수
var fish := 0
## 생선 점수와 콤보. 점수 = score()
var combo := FishCombo.new()
## 종이상자를 가지고 있는지 (한 번에 1개만)
var has_box := false
## 종이상자로 구제되어 올라가는 중인지
var rescuing := false
## 질주 중인지, 질주 남은 시간 (0이어도 착지 옥상에 닿을 때까지 질주 중)
var dashing := false
var dash_time := 0.0
## 털실 자석 남은 시간
var magnet_time := 0.0
## 금빛 방울을 가지고 있는지 (한 번에 1개만)
var has_bell := false
## 줄줄이 고양이 시험판: 켜져 있는지, 줄 상태, 줄 배수로 더 받은 거리 점수(미터, 소수 포함)
var parade_on := false
var parade: CatParade
var parade_bonus := 0.0
## 고양이 앞으로 화면 끝까지 거리 (통조림 범위). 화면 너비에 따라 world_view가 넘겨준다
var view_ahead := 940.0
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
var road := FishRoad.new()  # 생선 길 (옥상 생성 때 깐다)
var slots: ItemSlots  # 아이템 자리에 놓을 것 고르기
## 강화 단계와 이번 판 부스터 (review/v0.7.0/PLAN.md 3-1). 없으면 전부 0단계 = v0.6.0 판
var perks: Perks
var _dash_boost := false  # "질주로 출발" 부스터: BOOSTER_DASH_AT초에 질주를 아직 시작하지 않음
var _course: CoursePlacer  # 손으로 짠 구간 배치. null이면 옥상 생성기만 쓴다 (옥상·구조물만 보는 테스트용)
var _start_x := 0.0
var _ground_roof := {}      # 지금 서 있는 옥상
var _ghost_roof := {}       # 투명화로 통과해 올라설 옥상 (부딪힌 벽의 옥상)
var _was_pressed := false
var _jumped := false        # 마지막으로 옥상에 선 뒤 점프했는지
var _holding := false       # 점프 중 아직 누르고 있어 속도를 유지하는 중
var _hold_time := 0.0
var _hold_max := JumpModel.max_hold_time()  # 이번 점프에서 속도를 유지할 수 있는 최대 시간 (첫 점프·더블점프가 다름)
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
var _dash_landing := {}     # 질주가 끝날 착지 옥상
var _dash_land_time := 0.0  # 착지 옥상 위에 들어온 뒤 지난 시간
var _dash_base := 0.0       # 마지막 보이지 않는 발판 높이 (틈 위에서 이어 씀)
var _dash_ease := 0.0       # 질주가 끝난 뒤 속도가 돌아오는 남은 시간
var _next_target_x := 0.0   # 질주 중 다음 부술 것을 놓을 수 있는 위치
var _dash_line_x := 0.0    # 질주용 생선 줄: 다음 생선 자리
var _dash_arc_x := 0.0     # 질주용 생선 줄: 이 자리부터 다음 공중 호
var _dash_line_top := 0.0  # 질주용 생선 줄: 마지막 발판 높이 (틈 위에서는 그대로)
var _targets_made := 0      # 지금까지 놓은 부술 것 수 (음수 번호, 종류 차례)


## start_speed: 처음 달리는 속도 (accelerate = false로 속도를 고정하는 테스트용). 앞쪽 옥상 간격을 이 속도에 맞춰 바로 만들기 때문에 생성할 때 정한다
## use_course: false면 구간 없이 옥상 생성기만 쓴다 (옥상·구조물만 보는 테스트용)
## run_perks: 강화·부스터 (null이면 Perks.new() = 0단계, 부스터 없음)
func _init(seed_value: int, start_speed: float = Balance.RUN_SPEED, use_course: bool = true, run_perks: Perks = null) -> void:
	perks = run_perks if run_perks != null else Perks.new()
	speed = start_speed
	_generator = RoofGenerator.new(seed_value)
	_placer = ItemPlacer.new(seed_value)
	slots = ItemSlots.new(seed_value, perks.cookie_gap())
	combo.step = perks.combo_step()
	parade = CatParade.new(seed_value)
	has_bell = perks.has_booster("bell_start")
	_dash_boost = perks.has_booster("dash_start")
	if use_course:
		_course = CoursePlacer.new(_generator, seed_value)
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
	stage_rose = false
	hit_obstacle = {}
	picked.clear()
	dash_started = false
	dash_ended = false
	bell_blocked = false
	scared = false
	parade.met.clear()
	parade.fled.clear()
	smashed.clear()
	canned.clear()
	passed.clear()
	if game_over:
		return
	elapsed += dt
	time_since_stage_rise += dt
	if accelerate:
		speed = SpeedCurve.speed_at(elapsed)
		var now := SpeedCurve.stage_at(elapsed)
		if now != stage and SpeedCurve.rises(now):
			stage_rose = true
			time_since_stage_rise = 0.0
		stage = now
	ghost_time = maxf(0.0, ghost_time - dt)
	invuln_time = maxf(0.0, invuln_time - dt)
	magnet_time = maxf(0.0, magnet_time - dt)
	_dash_ease = maxf(0.0, _dash_ease - dt)
	time_since_hit += dt
	var press_started := pressed and not _was_pressed
	_was_pressed = pressed
	time_since_land += dt
	time_since_jump += dt
	time_since_bounce += dt
	time_since_double_jump += dt
	_press_age = 0.0 if press_started else _press_age + dt

	var x_before := x
	_move_forward(vx() * dt)
	if parade_on:
		parade_bonus += maxf(0.0, x - x_before) / Balance.PX_PER_METER * (parade.multiplier() - 1.0)
	_fill_roofs()
	_pick_items(dt)
	if _dash_boost and elapsed >= Balance.BOOSTER_DASH_AT and not dashing:
		_dash_boost = false
		_start_dash()
	_hit_obstacles()
	if parade_on and not game_over:
		parade.update(self, dt)
	if not dashing:
		combo.tick(dt)
	if game_over:
		return

	if dashing:
		_dash_step(dt, pressed, press_started)
		return

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
	dt = _hold_rise(dt, pressed)
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
		end_reason = "fall"


## 누르고 있는 동안 점프 속도로 올라간다. 중력으로 움직일 남은 시간을 돌려준다
func _hold_rise(dt: float, pressed: bool) -> float:
	if _holding and pressed and _hold_time < _hold_max:
		var hold_dt := minf(dt, _hold_max - _hold_time)
		_hold_time += hold_dt
		vy = JumpModel.jump_speed()
		y += vy * hold_dt
		return dt - hold_dt
	_holding = false
	return dt


## 가로 위치 at_x 아래에 있는 옥상. 없으면 빈 Dictionary
func roof_at(at_x: float) -> Dictionary:
	for roof in roofs:
		if at_x >= roof.left and at_x <= roof.right:
			return roof
	return {}


## 거리 점수 (미터, 소수점 버림): 시작 위치에서 앞으로 간 거리
func distance() -> int:
	return int(maxf(0.0, x - _start_x) / Balance.PX_PER_METER)


## 점수: 거리 + 생선 점수 (+ 줄 배수로 더 받은 거리 점수)
func score() -> int:
	return distance() + combo.points + int(parade_bonus)


## 생선 점수에 곱할 줄 배수 (줄줄이 시험판이 아니면 1)
func parade_mult() -> float:
	return parade.multiplier() if parade_on else 1.0


## 점프 중 아직 누르고 있어 올라가는 중인지 (화면 연출용)
func is_holding() -> bool:
	return _holding and not on_ground


## 지금 점프에서 누른 시간의 비율 (0 = 톡, 1 = 최대로 누름)
func hold_ratio() -> float:
	return clampf(_hold_time / _hold_max, 0.0, 1.0)


## 이제 어떤 옥상에도 올라설 수 없이 떨어지는 중인지 (허우적거리는 연출용).
## 발밑이나 바로 앞 옥상보다 아래로 내려가 착지도, 투명화 통과(몸 높이 안쪽)도 못 하는 경우.
func is_doomed() -> bool:
	if on_ground or rescuing or dashing or vy >= 0.0 or not _ride_line.is_empty():
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


## 지금 앞으로 가는 속도 (트램펄린 발사 중이면 발사 속도, 질주 중이면 질주 속도, 질주 직후에는 서서히 돌아옴)
func vx() -> float:
	var dash_v := minf(speed * Balance.DASH_MULT, Balance.DASH_MAX_SPEED)
	if dashing:
		return dash_v
	return maxf(maxf(speed, _launch_vx), lerpf(speed, dash_v, _dash_ease / Balance.DASH_EASE))


## 달려 들어갈 때 닿는 자리 (몸 가운데): 그물 가운데쯤
static func run_in_x(tramp: Dictionary) -> float:
	return tramp.left + Balance.TRAMP_RUN_IN


## 서 있는 옥상 위, 아직 닿지 않은(몸 가운데가 오른쪽 끝 전) 받아 주는 트램펄린. 없으면 빈 Dictionary
func _tramp_ahead() -> Dictionary:
	if dashing:
		return {}
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
	if rescuing or dashing:
		return  # 구제·질주 중에는 벽을 통과한다
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


## 몸(타원)에 닿은 아이템을 먹는다. 구제 중에는 먹지 않는다. 털실 중에는 반경 안 생선을 끌어당긴다
func _pick_items(dt: float) -> void:
	var center_y := y + Balance.CAT_BODY_SIZE.y * 0.5
	var radius := Balance.CAT_BODY_SIZE * 0.5 + Vector2.ONE * Balance.ITEM_RADIUS
	var open_can := false
	var start_dash := false
	var bites: Array[int] = []  # 이번 step에 먹은 생선 점수 (놓침을 먼저 처리한 뒤 더한다: 끊긴 뒤 먹은 것은 x1)
	var pull := magnet_radius()
	var bonus := Balance.DASH_FISH_MULT if dashing else 1  # 질주 중 생선 점수 2배 (콤보 배수와 곱함)
	for i in range(items.size() - 1, -1, -1):
		var item := items[i]
		if item.x < x - 1000.0:
			items.remove_at(i)  # 지나간 아이템
			continue
		if item.x > x + radius.x and pull <= 0.0:
			continue  # 아직 앞 (생선 길이 촘촘해 대부분 여기서 끝난다)
		if item.x < x - radius.x:
			# 먹는 타원 뒤로 지나감: 필수 생선이면 콤보가 끊긴다 (한 번만)
			if item.kind == "fish" and not item.has("bonus"):
				item.bonus = true
				if not (dashing or rescuing or magnet_time > 0.0 or ghost_time > 0.0 or _dash_ease > 0.0):
					combo.cut()
		if rescuing:
			continue
		if pull > 0.0 and (item.kind == "fish" or item.kind == "gold"):
			var at := Vector2(item.x, item.y)
			if at.distance_to(Vector2(x, center_y)) <= pull:
				at = at.move_toward(Vector2(x, center_y), maxf(Balance.MAGNET_SPEED, vx() + 400.0) * dt)  # 질주 중 뒤에 남은 생선도 따라오게
				item.x = at.x
				item.y = at.y
		var d := Vector2((item.x - x) / radius.x, (item.y - center_y) / radius.y)
		if d.length_squared() > 1.0 or not _can_take(item.kind):
			continue
		match item.kind:
			"fish":
				fish += 1
				bites.append(roundi(perks.fish_points() * bonus * parade_mult()))
			"gold":
				fish += Balance.GOLD_FISH
				bites.append(roundi(perks.gold_points() * bonus * parade_mult()))
			"box":
				has_box = true
			"bell":
				has_bell = true
			"yarn":
				magnet_time = perks.magnet_time()
			"cookie":
				hearts += 1
			"can":
				open_can = true
			"dash":
				start_dash = true
		picked.append(item)
		items.remove_at(i)
	for points in bites:
		combo.eat(points)
	if open_can:
		_open_can()
	if start_dash:
		_start_dash()  # 생선을 바꿔 깔므로 위 반복이 끝난 뒤에


## 생선을 끌어당기는 반경: 털실(MAGNET_RADIUS x 털실 강화)과 질주(DASH_MAGNET_RADIUS) 중 큰 쪽, 둘 다 없으면 0
func magnet_radius() -> float:
	return maxf(perks.magnet_radius() if magnet_time > 0.0 else 0.0, Balance.DASH_MAGNET_RADIUS if dashing else 0.0)


## 이미 가지고 있거나 소용없으면 그대로 둔다
func _can_take(kind: String) -> bool:
	match kind:
		"box":
			return not has_box
		"bell":
			return not has_bell
		"cookie":
			return hearts < Balance.HEARTS_MAX
		"dash":
			return not dashing
	return true


## 통조림: 화면 안 장애물이 전부 생선으로 바뀐다 (화면 밖은 그대로)
func _open_can() -> void:
	for i in range(obstacles.size() - 1, -1, -1):
		var o := obstacles[i]
		var left := obstacle_left(o, x)
		if left > x + view_ahead or left + o.w < x - Balance.CAT_SCREEN_X:
			continue
		var was := o.duplicate()
		was.x = left
		canned.append(was)
		obstacles.remove_at(i)
		var cans: Array[Dictionary] = []
		for n in Balance.CAN_FISH:
			cans.append({"kind": "fish", "x": left + o.w * 0.5 + (n - 1) * Balance.FISH_SPACING, "y": o.base + Balance.ITEM_LIFT})
		FishRoad.add_one_line(items, cans)


## 질주 시작: 다른 상태를 전부 지우고 전용 분기로 들어간다
func _start_dash() -> void:
	dashing = true
	dash_started = true
	dash_time = perks.dash_time()
	_dash_landing = {}
	_dash_land_time = 0.0
	_next_target_x = 0.0
	_dash_base = y
	on_ground = true  # 그림은 달리기, 일반 착지·떨어짐 코드는 타지 않음
	vy = 0.0
	ghost_time = 0.0
	invuln_time = 0.0
	_ghost_roof = {}
	_launch_vx = 0.0
	_ride_line = {}
	_held_top = NAN
	_buffer = 0.0
	_coyote = 0.0
	_holding = false
	_floating = false
	_jumped = false
	_double_used = false
	_replace_with_dash_line()


## 질주 중: 보이지 않는 발판을 따라 달리며 뛸 수 있고, 착지 옥상 위 땅에서 끝낸다
func _dash_step(dt: float, pressed: bool, press_started: bool) -> void:
	_add_dash_target()
	var over_landing: bool = not _dash_landing.is_empty() and x - Balance.CAT_FOOT_HALF >= _dash_landing.left
	if press_started and not over_landing:  # 착지 옥상 길이(DASH_LAND_SECONDS)가 남은 체공보다 길어 그 위에 내려온다
		if on_ground:
			_start_jump(pressed)
		elif not _double_used:
			_start_double(pressed)
	var floor_y := _dash_floor()
	if on_ground:
		y = move_toward(y, floor_y, Balance.DASH_RISE_SPEED * dt)
	else:
		_dash_air(_hold_rise(dt, pressed), floor_y)
	dash_time = maxf(0.0, dash_time - dt)
	if not over_landing:
		return
	_dash_land_time += dt
	if on_ground and dash_time == 0.0 and _dash_land_time >= Balance.DASH_LAND_WAIT:
		dashing = false
		dash_ended = true
		invuln_time = Balance.DASH_END_INVULN
		_dash_ease = Balance.DASH_EASE
		_land_on(_dash_landing)


## 질주 중 공중: 보이지 않는 발판(floor_y)에 닿으면 선다. 그사이 발판이 몸보다 높아졌으면 그 자리에서 달리며 올라간다
func _dash_air(dt: float, floor_y: float) -> void:
	var prev_y := y
	if dt > 0.0:
		var moved := JumpModel.integrate(y, vy, dt, _floating)
		y = moved.x
		vy = moved.y
	if vy > 0.0 or y > floor_y:
		return
	y = minf(floor_y, prev_y)
	vy = 0.0
	on_ground = true
	_holding = false
	_floating = false
	_jumped = false
	_double_used = false
	landed = true
	time_since_land = 0.0


## 화면 밖 옥상 위에 부술 것을 하나 놓는다 (질주가 끝나기 전에 닿는 자리만, 착지 옥상은 비워 둠)
func _add_dash_target() -> void:
	var at := x + view_ahead + Balance.DASH_TARGET_AHEAD
	if at < _next_target_x or at > x + dash_time * vx():
		return
	var roof := roof_at(at)
	var kind: String = Balance.DASH_TARGETS[_targets_made % Balance.DASH_TARGETS.size()]
	var info: Dictionary = Balance.OBSTACLES[kind]
	if roof.is_empty() or roof.get("platform", false) or is_same(roof, _dash_landing) or at + info.w > roof.right:
		return
	_targets_made += 1
	obstacles.append({"id": -_targets_made, "kind": kind, "x": at, "w": info.w, "y0": roof.top + info.y0, "y1": roof.top + info.y1, "base": roof.top})
	_next_target_x = at + Balance.DASH_TARGET_GAP * vx()


## 질주가 시작되면 앞쪽 생선(땅 줄과 호, 부술 장애물 위 호 포함)을 치우고 질주용 줄로 바꾼다
func _replace_with_dash_line() -> void:
	items = items.filter(func(item: Dictionary) -> bool: return item.x <= x or not FishRoad.is_fish(item))
	_dash_line_x = x + Balance.FISH_SPACING
	_dash_arc_x = x + Balance.DASH_FISH_GAP * 0.5 * vx()
	_dash_line_top = _dash_base
	_lay_dash_line(roofs[-1].right - vx() * Balance.DASH_LOOK)


## 질주용 줄을 end까지 깐다: 보이지 않는 발판 위 땅 줄 사이사이에 최대 점프 호가 이어지는 한 줄 (놓쳐도 안 끊김).
func _lay_dash_line(end: float) -> void:
	var route := FishRoad.path(JumpModel.max_hold_time(), -1.0)
	var v := vx()
	var line: Array[Dictionary] = []
	while _dash_line_x < end:
		var at := _dash_line_x
		var top := _dash_top_at(at)
		_dash_line_top = _dash_line_top if top == -INF else top
		var arc_end: float = at + route[-1].x * v
		if at >= _dash_arc_x and arc_end <= x + dash_time * v and (_dash_landing.is_empty() or arc_end <= _dash_landing.left):
			_dash_arc_x = at + Balance.DASH_FISH_GAP * v
			var walked := 0.0
			for i in range(1, route.size()):
				walked += Vector2((route[i].x - route[i - 1].x) * v, route[i].y - route[i - 1].y).length()
				if walked >= Balance.FISH_SPACING:
					walked -= Balance.FISH_SPACING
					var fish_x: float = at + route[i].x * v
					# 호 아래로 옥상이 높아지면 그 위로 (건물 속에 묻히지 않게)
					var fish_y: float = maxf(_dash_line_top + route[i].y, _dash_top_at(fish_x)) + Balance.ITEM_LIFT
					line.append({"kind": "fish", "x": fish_x, "y": fish_y, "bonus": true})
			_dash_line_x = arc_end + Balance.FISH_SPACING * 0.5
		else:
			if road.is_free(at):
				line.append({"kind": "fish", "x": at, "y": _dash_line_top + Balance.ITEM_LIFT, "bonus": true})
			_dash_line_x += Balance.FISH_SPACING
	FishRoad.add_one_line(items, line)


## 보이지 않는 발판 높이: 발밑과 곧 닿을 옥상(판 제외) 중 가장 높은 곳. 틈 위에서 앞 옥상이 아직 멀면 마지막 발판 높이 그대로
func _dash_floor() -> float:
	var top := _dash_top_at(x)
	if top > -INF:
		_dash_base = top
	return _dash_base


## 몸이 at에 있을 때 발판이 될 옥상 높이. 없으면(틈 위) -INF
func _dash_top_at(at: float) -> float:
	var horizon := at + vx() * Balance.DASH_LOOK
	var top := -INF
	for roof in roofs:
		if roof.left > horizon:
			break
		if roof.right >= at - Balance.CAT_FOOT_HALF and not roof.get("platform", false):
			top = maxf(top, roof.top)
	return top


## 부딪힌 장애물의 하트를 깎는다 (땅 위·탑승·떠오름에서 step이 일찍 끝나므로 아이템 판정 옆에서 본다)
func _hit_obstacles() -> void:
	var safe := rescuing or ghost_time > 0.0 or invuln_time > 0.0
	for i in range(obstacles.size() - 1, -1, -1):
		var o := obstacles[i]
		var left := obstacle_left(o, x)
		if left + o.w < x - 1000.0:
			obstacles.remove_at(i)  # 지나간 장애물
		elif left + o.w < x - Balance.CAT_BODY_SIZE.x * 0.5:
			if not o.has("passed"):
				o.passed = true  # 한 번만
				if not (safe or dashing):
					passed.append(o)
		elif dashing:
			# 높이와 상관없이 몸 앞이 닿으면 부순다 (이미 지나친 것은 그대로)
			if left <= front() and left + o.w >= x:
				var was := o.duplicate()
				was.x = left
				smashed.append(was)
				obstacles.remove_at(i)
		elif not safe and body_hits(o, x, y):
			safe = true  # 한 step에 하나만
			hit_obstacle = o
			obstacles.remove_at(i)
			invuln_time = Balance.INVULN_TIME
			if has_bell:
				has_bell = false  # 방울이 대신 막는다 (하트·콤보 그대로)
				bell_blocked = true
				continue
			scared = parade_on and parade.scare()
			if scared and parade.mode == "B":
				combo.cut()  # B: 하트 대신 맨 뒤 고양이가 도망 (하트 깨짐 연출이 없게 time_since_hit는 그대로)
				continue
			hearts -= 1
			combo.cut()
			time_since_hit = 0.0
			if hearts <= 0:
				game_over = true
				end_reason = "hearts"


## 장애물 판정 왼쪽 끝. 비둘기는 고양이 x의 함수라 시간·속도가 달라도 고양이 가운데가 o.x에 올 때 항상 그 자리에서 만난다
static func obstacle_left(o: Dictionary, cat_x: float) -> float:
	return o.x - o.get("k", 0.0) * (cat_x - o.x)


## 비둘기가 앞으로 ahead픽셀 안(화면 오른쪽 끝)에 들어올 때까지 남은 시간 (달리는 속도 run_vx)
static func flock_eta(o: Dictionary, cat_x: float, run_vx: float, ahead: float) -> float:
	return (obstacle_left(o, cat_x) - cat_x - ahead) / (run_vx * (1.0 + o.k))


## 고양이(가운데 cat_x, 발끝 feet)의 작은 타원이 장애물 상자에 닿는지
static func body_hits(o: Dictionary, cat_x: float, feet: float) -> bool:
	var left := obstacle_left(o, cat_x)
	var center_y := feet + Balance.CAT_BODY_SIZE.y * 0.5
	var near := Vector2(clampf(cat_x, left, left + o.w), clampf(center_y, o.y0, o.y1))
	var radius := Balance.CAT_BODY_SIZE * 0.5 * Balance.OBSTACLE_HIT_SCALE
	return ((near - Vector2(cat_x, center_y)) / radius).length_squared() < 1.0


## 발 범위가 옥상에 걸쳐 있는지
func _feet_over(roof: Dictionary) -> bool:
	return x + Balance.CAT_FOOT_HALF >= roof.left and x - Balance.CAT_FOOT_HALF <= roof.right


func _start_jump(pressed: bool) -> void:
	on_ground = false
	_coyote = 0.0
	_buffer = 0.0
	_held_top = NAN
	vy = JumpModel.jump_speed()
	_jumped = true
	_floating = false
	# 눌렀다 이미 뗀 입력(버퍼)이면 최소 높이로 뛴다
	_holding = pressed
	_hold_time = 0.0
	_hold_max = JumpModel.max_hold_time()
	time_since_jump = 0.0
	jumped = true


## 더블점프: 떨어지던 속도를 지우고 첫 점프와 같은 속도로 다시 올라간다 (누르는 동안 double_max_hold까지 유지)
func _start_double(pressed: bool) -> void:
	_double_used = true
	_floating = true
	_jumped = true  # 점프 없이 떨어지다 썼어도 모서리 투명화 구제를 받는다
	_coyote = 0.0
	_buffer = 0.0
	_held_top = NAN
	vy = JumpModel.jump_speed()
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
	if dashing:
		return {}
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


## 남은 질주 거리가 생성 범위보다 짧아지면 다음 옥상은 장애물 없는 넓은 착지 옥상. 아니면 빈 Dictionary
func _landing_roof() -> Dictionary:
	if not dashing or not _dash_landing.is_empty() or _generator.has_pending() or dash_time * vx() >= Balance.ROOF_LOOKAHEAD + Balance.DASH_LAND_EARLY:
		return {}
	if _course:
		_course.drop_queue()
	var left: float = roofs[-1].right + Balance.ROOF_GAP_MIN
	# 단계가 올라 빨라져도 남은 체공 안에 지나치지 않게 다음 단계 속도로 길이를 잰다
	var fastest := minf(RoofGenerator.arrival_speed(speed) * Balance.DASH_MULT, Balance.DASH_MAX_SPEED)
	_dash_landing = {"left": left, "right": left + fastest * Balance.DASH_LAND_SECONDS, "top": roofs[-1].top}
	return _dash_landing


## 고양이가 이 옥상을 지날 때의 속도들 [도착 속도, (달라지면) 떠날 때 속도]. 생선 길을 실제로 달릴 속도에 맞춘다
func _road_speeds(roof: Dictionary) -> Array:
	if not accelerate:
		return [speed]
	var arrive := SpeedCurve.speed_at(elapsed + (roof.left - x) / maxf(speed, 1.0))
	var leave := SpeedCurve.speed_at(elapsed + (roof.right - x) / maxf(speed, 1.0))
	return [arrive] if arrive == leave else [arrive, leave]


## 고양이 앞쪽까지 옥상을 만들고, 지나간 옥상은 지운다
func _fill_roofs() -> void:
	while roofs[-1].right < x + Balance.ROOF_LOOKAHEAD:
		var roof := _landing_roof()
		if roof.is_empty():
			roof = _course.next_roof(roofs[-1], speed, stage) if _course else _generator.next_roof(roofs[-1], speed)
		var placed: Array[Dictionary] = []
		if roof.has("segment"):
			obstacles.append_array(roof.obs)
			for slot: Dictionary in roof.slots:
				placed.append_array(slots.fill(slot, elapsed, hearts, has_bell))
		else:
			placed = _placer.items_for(roofs[-1], roof, elapsed)
		for item in placed:
			if item.y <= roof.top + Balance.ITEM_LIFT:
				road.reserve(item.x)  # 땅 위 아이템 자리에는 생선을 겹치지 않는다
		var road_fish := road.extend(roofs[-1], roof, _road_speeds(roof))
		# 질주가 닿는 구간(착지 옥상까지)의 생선은 질주용 줄이 대신한다. 생선 길을 먼저 놓아 아이템 자리 생선이 빠진다
		var in_dash := dashing and (_dash_landing.is_empty() or is_same(roof, _dash_landing))
		if in_dash:
			road_fish.clear()
			placed = placed.filter(func(item: Dictionary) -> bool: return not FishRoad.is_fish(item))
		FishRoad.add_one_line(items, road_fish)
		FishRoad.add_one_line(items, placed)
		roofs.append(roof)
		if in_dash:
			_lay_dash_line(road.next_ground_x() if is_same(roof, _dash_landing) else roof.right - vx() * Balance.DASH_LOOK)
		if roof.has("line"):
			structures.append(roof.line)
		if roof.has("tramp"):
			structures.append(roof.tramp)
	while roofs.size() > 1 and roofs[0].right < x - 1000.0:
		roofs.pop_front()
	while not structures.is_empty() and structures[0].right < x - 1000.0:
		structures.pop_front()
