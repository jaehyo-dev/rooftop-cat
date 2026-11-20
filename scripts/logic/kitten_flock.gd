class_name KittenFlock
extends RefCounted
## 떠다니는 아기 배치와 움직임 (2026-11-19, 화면 좌표, 화면과 분리된 순수 계산). world_view가 프레임마다 step을 부른다.
## (피라미드 자리는 진열장처럼 보이고 구름이 한 덩어리가 되며 무리가 덩어리째 늦게 따라와 바꿈, 디렉터 확인)
## - 줄줄이(기본): 주인공 발끝 높이를 기록해 두고 아기 i는 (i+1) x KITTEN_CHAIN_DELAY초 전 높이를 따라간다 → 점프하면 앞에서부터 차례로 출렁.
##   간격은 구름 폭보다 조금 넓게. 줄이 화면 왼쪽을 넘으면 위로 굽혀 구름끼리 안 겹치게. 굽힐 때는 곧은 비탈(계단처럼 보임, 디렉터 확인)
##   대신 앞은 가파르고 뒤로 갈수록 덜 올라가는 활 모양 (끝을 아래로 말지는 않음: 끝 아기들이 위아래로 쌓여 출렁일 때 부딪힘).
##   아기는 주인공보다 앞(위 층)에 그린다 (요정). 슬라이딩 동안(과 일어나는 그림 동안)은 줄 모양 그대로 SLIDE_LIFT만큼 위로, 오르내림 모두 SLIDE_EASE초에.
## - 요정 무리(비교용): 주인공 뒤쪽 위 둥근 구역의 자리마다 작은 원·8자 궤도를 다른 박자로, 아기마다 다른 빠르기의 스프링으로 따라감.
## - 공통: 구름끼리 겹치면 밀어냄, 지붕 아래·왼쪽 위 생선 수 위로 못 감, 움직이는 방향으로 기울기, 내려올 때 구름 납작.
## - 구름 타기(2026-11-20, 줄줄이의 새 기본, 예전 앉기와 시험 단추로 바꿈): 앉아 기다리는 자세로 빠르게 날면 스티커를 끄는 것처럼 보여(디렉터)
##   구름에 엎드려 타고 난다. 줄은 주인공 등 높이에서 뒤로 낮게 늘어지는 혜성 꼬리(뒤로 갈수록 RIDE_RISE씩만 높아짐),
##   주인공이 빨라지는 순간(점프·더블점프·질주) 아기마다 조금씩 더 뒤로 늘어졌다 스프링으로 따라붙고(drag), 착지 땐 살짝 앞으로.
##   평소엔 줄을 따라 앞에서 뒤로 흐르는 느린 물결. 자리가 모자라면 주인공을 오른쪽으로 옮기고(shift, 최대 SHIFT_MAX) 그래도 모자라면 간격을 좁힘.
##   구름 꼬리 조각(puffs)을 아기마다 뒤로 떨어뜨림.
## 길이 값은 0.46배 아기 기준이고 지금 크기 비율(r = 크기 / 0.46)을 곱해 쓴다.

const MODES := ["줄줄이", "요정 무리"]
static var mode_pick := 0  # MODES 번호 (로컬 시험 단추로 바꿈, 실행하는 동안 유지)
const RIDES := ["예전(앉기)", "새(구름 타기)"]
static var ride := true    # 줄줄이에서 구름 타기 (시험 단추로 예전 앉기와 바꿈)

const CLOUD_W := 80.0      # 구름 방석 폭 (앉은 아기 몸 폭 정도)
const CLOUD_H := 0.8       # 구름 높이 / 폭 (겹침 판정은 이 타원으로)
const EDGE := 12.0         # 화면 왼쪽 끝과 구름 사이 (구름 밖으로 나온 꼬리까지 화면 안에)
const HUD_BOTTOM := 160.0  # 왼쪽 위 생선 수 아래 끝 (화면 y)
const HEAD := 62.0         # 앉은 아기 발끝~귀 끝
const TOP_SQUEEZE := 0.12  # 높이 하한을 넘은 높이의 이만큼만 더 올라감 (딱 멈추지 않게)
const FLOOR_LIFT := 45.0   # 지붕에서 발끝까지 최소 (구름 아래 끝이 지붕에 닿을 정도)
const MAX_TILT := 0.1745   # 최대 기울기 (라디안, 10도)
const TILT_SPEED := 700.0  # 이 세로 속도(픽셀/초)에서 최대 기울기
const TILT_RATE := 10.0    # 기울기가 목표를 따라가는 빠르기 (1/초, 튀지 않게)
const SQUASH := 0.22       # 구름이 가장 납작해지는 정도 (내려오는 속도 SQUASH_SPEED 이상)
const SQUASH_SPEED := 800.0
const JOIN_TIME := 0.6     # 새로 온 아기는 이 시간 동안 천천히 따라가다 (날아오는 게 보이게) 제 빠르기로
const JOIN_SPEED := 900.0  # 날아오는 동안 가장 빠른 속도 (픽셀/초, 순간이동처럼 안 보이게)
const MAX_SPEED := 1600.0  # 보이는 자리가 움직이는 가장 빠른 속도 (픽셀/초, 밀어내기로 튀지 않게. 주인공 점프 약 1100)
const BEND := 0.5         # 활 모양: 맨 뒤 칸의 올라가는 각도 = 맨 앞 칸의 (1 - BEND)배 (0.6이면 앞쪽이 거의 세로로 쌓여 점프 때 구름이 닿음)
const SLIDE_LIFT := 24.0   # 슬라이딩 때 줄 전체를 올리는 픽셀 (낮게 엎드린 주인공 몸통을 아기 구름이 덜 가리게)
const SLIDE_EASE := 0.18   # 올라가고 내려오는 데 걸리는 시간 (초, 순간이동처럼 안 보이게 0.15 이상)
const HISTORY := 1.0       # 주인공 높이 기록 길이 (초, 6마리 x 0.12 보다 길게)
## 구름 타기 (길이는 0.46배 기준 x r, RIDE_BACK만 화면 픽셀)
const RIDE_BACK := 108.0             # 맨 앞 아기 발끝(배 아랫선) 가로: 주인공 발끝에서 이만큼 뒤 (90이면 주인공 꼬리 위에 얹혀 보임)
const RIDE_FIRST_Y := -120.0         # 맨 앞 아기 배 아랫선 높이 (주인공 등 높이쯤, 세운 꼬리 끝과 안 겹치게 조금 위)
const RIDE_GAP := 100.0              # 아기 사이 기본 간격 (구름이 조금 겹쳐 이어진 꼬리처럼)
const RIDE_GAP_MIN := 0.7            # 기본 크기(작게) 6마리에서 좁힌 간격이 이 배율 위인지 테스트가 확인
const RIDE_RISE := 7.0               # 뒤로 한 칸마다 높아지는 정도 (아주 조금)
const RIDE_TAIL := -88.0             # 탄 구름 뒤 끝 가로 (발끝 기준, world_view가 구름 자리를 이 값에서 정함): 화면 왼쪽 안에 둘 끝
const RIDE_SEP := 0.62               # 구름 타기 겹침 판정 거리 = RIDE_GAP x 이 값 (구름이 길쭉해 조금 겹쳐도 됨)
const SHIFT_MAX := 60.0              # 주인공 화면 자리를 오른쪽으로 옮기는 최대 (화면 픽셀, 앞 시야가 이만큼 줄어듦)
const SHIFT_TIME := 0.5              # 옮기는 데 걸리는 시간 (초)
const WAVE := 3.0                    # 평소 물결 세로 폭의 반 (화면 픽셀, 위아래 합 6px)
const WAVE_HZ := 0.55                # 물결 빠르기
const WAVE_STEP := 0.9               # 아기 한 칸마다 늦는 위상 (라디안, 앞에서 뒤로 흐름)
const DRAG_HZ := 1.6                 # 늘어졌다 따라붙는 스프링 (느려서 늘어진 게 보임)
const DRAG_DAMP := 0.5
const DRAG := {"jump": 32.0, "double": 38.0, "dash": 60.0, "land": -12.0}  # 뒤로 늘어지는 정도 (0.46배 기준, - = 앞으로)
const DRAG_MORE := 0.3               # 뒤 아기일수록 한 칸마다 이 비율만큼 더 늘어짐
const EDGE_SOFT := 0.3               # 늘어질 때 화면 왼쪽 경계를 넘은 만큼의 이 비율만 더 감 (최대 EDGE_OVER x r)
const EDGE_OVER := 40.0
## 구름 꼬리 조각: 아기마다 PUFF_GAP초 간격으로 구름 뒤 끝에서 떨어져 PUFF_LIFE초에 작아지며 사라짐. 화면 전체 PUFF_MAX개까지 (폰 성능)
const PUFF_GAP := Vector2(0.15, 0.25)
const PUFF_LIFE := 0.4
const PUFF_MAX := 18
const PUFF_KINDS := 3
const PUFF_FROM := Vector2(-58.0, 12.0)   # 아기 발끝에서 구름 뒤 아래 끝 (0.46배 기준)
const PUFF_SPEED := Vector2(-150.0, 85.0) # 떨어지는 속도 (화면 픽셀/초, 뒤로·아래: 촘촘한 줄에서 뒤 아기 구름 밑에 가리지 않게)

## 아기마다 {발끝 화면 자리, 기울기(라디안, + = 앞으로), 구름 배율}. 자리 수 = Balance.PARADE_MAX
var pos: Array[Vector2] = []
var tilt: Array[float] = []
var cloud: Array[Vector2] = []
var _springs: Array = []       # 자리 스프링 (Spring, 빈 자리 null)
var _clouds: Array = []        # 구름 배율 스프링
var _age: Array[float] = []    # 자리 잡기 시작한 뒤 지난 시간
var _landed: Array[bool] = []  # 날아와 자리 근처에 닿았는지 (닿기 전엔 다른 아기를 밀지 않고 지나감)
var _hist: Array[Vector2] = [] # (시각, 주인공 발끝 화면 y), 오래된 것부터
var _t := 0.0
var _lift := 0.0               # 슬라이딩 올리기 진행 (0 = 제자리, 1 = SLIDE_LIFT만큼 위)
## 구름 타기: 주인공을 오른쪽으로 옮긴 화면 픽셀 (world_view가 주인공·세계 그림에 더함)
var shift := 0.0
var _shift_from := 0.0
var _shift_to := 0.0
var _shift_t := 1.0
var _drags: Array = []         # 아기마다 늘어짐 스프링 (가로만 씀, 목표 0)
var _n := 0                    # 지난 step의 아기 수
var _puff_in: Array[float] = []
## 구름 꼬리 조각 {"p": 화면 자리, "t": 지난 시간, "kind": 그림 번호, "s": 크기 배율}
var puffs: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value
	for i in Balance.PARADE_MAX:
		_drags.append(Spring.new(DRAG_HZ, DRAG_DAMP, Vector2.ZERO))
		_puff_in.append(_rng.randf_range(0.0, PUFF_GAP.y))
		pos.append(Vector2.ZERO)
		tilt.append(0.0)
		cloud.append(Vector2.ONE)
		_springs.append(null)
		_clouds.append(null)
		_age.append(0.0)
		_landed.append(true)


static func ratio() -> float:
	return CatParade.size_k() / 0.46


## 발끝이 올라갈 수 있는 화면 y 하한 (머리가 생선 수 아래)
static func top() -> float:
	return HUD_BOTTOM + HEAD * ratio() + 8.0


## y가 top보다 위(작음)면 넘은 만큼의 TOP_SQUEEZE배만 올라가게
static func soft_top(y: float, limit: float) -> float:
	return y if y >= limit else limit - (limit - y) * TOP_SQUEEZE


## 아기 i(0부터)가 n마리일 때 쉬는 자리: 주인공 발끝에서 (가로, 세로) 픽셀 (세로는 위가 -)
static func rest(i: int, n: int) -> Vector2:
	var r := ratio()
	if mode_pick == 1:
		var center := Vector2(-Balance.KITTEN_CHAIN_BACK, 0.0) + Balance.KITTEN_FLOCK_CENTER * r
		if i >= Balance.KITTEN_FLOCK_ANGLES.size():
			return center
		var a := deg_to_rad(Balance.KITTEN_FLOCK_ANGLES[i])
		return center + Vector2(cos(a), sin(a) * 0.85) * Balance.KITTEN_FLOCK_RADIUS * r
	if ride:
		return Vector2(-RIDE_BACK - (i * ride_gap(n)), (RIDE_FIRST_Y - RIDE_RISE * i) * r)
	var first := Vector2(-Balance.KITTEN_CHAIN_BACK, 0.0) + Balance.KITTEN_CHAIN_FIRST * r
	var gap := Balance.KITTEN_CHAIN_GAP * r
	var room := Balance.CAT_SCREEN_X + first.x - EDGE - CLOUD_W * r * 0.5  # 맨 앞에서 화면 왼쪽 끝까지
	var a := _bend_angle(n - 1, room / gap)
	var at := first
	for k in i:  # 칸 k는 각도 a x (1 - BEND x k/(칸 수-1))로 위로, 구름 타원 거리로 gap
		var t := a * (1.0 - BEND * k / maxf(n - 2, 1))
		at += Vector2(-cos(t), -CLOUD_H * sin(t)) * gap
	return at


## 구름 타기: n마리일 때 주인공을 오른쪽으로 옮길 화면 픽셀 (맨 뒤 구름 뒤 끝이 화면 왼쪽 EDGE 안에 들도록, 최대 SHIFT_MAX)
static func lead_shift(n: int) -> float:
	if not (ride and mode_pick == 0):
		return 0.0
	return clampf(_ride_need(n, RIDE_GAP * ratio()), 0.0, SHIFT_MAX)


## 구름 타기 아기 사이 간격: 옮긴 뒤에도 모자라면 화면 안에 들게 좁힘
static func ride_gap(n: int) -> float:
	var gap := RIDE_GAP * ratio()
	var need := _ride_need(n, gap) - lead_shift(n)
	if need <= 0.0 or n < 2:
		return gap
	return gap - need / (n - 1)  # 큰 아기(시험 단추 0.36·0.46배)는 많이 겹쳐도 화면 안에


## 간격 gap으로 n마리를 늘어놓을 때 화면 왼쪽에서 모자라는 픽셀 (주인공 기본 자리 기준)
static func _ride_need(n: int, gap: float) -> float:
	var tail := Balance.CAT_SCREEN_X - RIDE_BACK - (n - 1) * gap + RIDE_TAIL * ratio()
	return EDGE - tail


## 칸 m개의 가로 합(gap 단위)이 room 안에 들어가는 가장 작은 첫 칸 각도 (넉넉하면 0 = 한 줄)
static func _bend_angle(m: int, room: float) -> float:
	var width := func(a: float) -> float:
		var sum := 0.0
		for k in m:
			sum += cos(a * (1.0 - BEND * k / maxf(m - 1, 1)))
		return sum
	if width.call(0.0) <= room:
		return 0.0
	var lo := 0.0
	var hi := PI * 0.5
	for _k in 30:
		var mid := (lo + hi) * 0.5
		if width.call(mid) > room:
			lo = mid
		else:
			hi = mid
	return hi


## 요정 무리 궤도: 짝수는 작은 원, 홀수는 8자 (아기마다 다른 박자)
static func orbit(i: int, quirk: float, t: float) -> Vector2:
	var p := TAU * (Balance.KITTEN_ORBIT_HZ * (0.75 + 0.5 * quirk) * t + quirk)
	var o := Vector2(cos(p), sin(p)) if i % 2 == 0 else Vector2(sin(p), sin(2.0 * p) * 0.5)
	return o * Balance.KITTEN_ORBIT * ratio()


## 아기 i가 at(화면)에서 자리를 잡기 시작 (만남: 기다리던 자리, 시험 단추: 쉬는 자리)
func place(i: int, at: Vector2) -> void:
	_springs[i] = Spring.new(1.0, 1.0, at)
	_drags[i] = Spring.new(DRAG_HZ, DRAG_DAMP, Vector2.ZERO)
	_clouds[i] = Spring.new(Balance.KITTEN_CLOUD_HZ, Balance.KITTEN_CLOUD_DAMP)
	_age[i] = 0.0
	_landed[i] = false
	pos[i] = at
	tilt[i] = 0.0
	cloud[i] = Vector2.ONE


## 순간 충격 (한 마리가 날아갈 때 남은 아기 움찔)
func kick(i: int, offset: Vector2) -> void:
	if _springs[i] != null:
		_springs[i].kick(offset)


## 구름 타기: 주인공이 빨라지는 순간(jump·double·dash) 줄이 뒤로 늘어졌다 따라붙음, land는 살짝 앞으로. 뒤 아기일수록 더
func drag(kind: String) -> void:
	if not (ride and mode_pick == 0):
		return
	for i in _n:  # 지금 탄 아기만 (빈 자리에 쌓였다가 나중에 한꺼번에 나오지 않게)
		_drags[i].kick(Vector2(-DRAG[kind] * ratio() * (1.0 + DRAG_MORE * i), 0.0))


## 아기 i의 세로 속도 (화면 픽셀/초, + = 내려감). 구름 타기 올라가기·내려가기 그림을 고를 때
func vy(i: int) -> float:
	return _springs[i].velocity.y if _springs[i] != null else 0.0


## 구름 타기 평소 물결: 아기 i의 세로 (앞에서 뒤로 흐름, 위상이 이어짐)
func wave(i: int) -> float:
	return WAVE * sin(TAU * WAVE_HZ * _t - WAVE_STEP * i)


## dt초 진행. lead = 주인공 발끝 화면 자리, cats = CatParade.cats (자리 잡은 아기만, place 뒤), floor_at(화면 x) = 그 아래 지붕 화면 y (없으면 INF),
## sliding = 주인공이 길게 엎드린 그림(슬라이딩·일어나기)일 때 (줄을 조금 올림)
func step(dt: float, lead: Vector2, cats: Array, floor_at: Callable, sliding: bool = false) -> void:
	if dt <= 0.0:
		return
	var shown := pos.duplicate()  # 지난 프레임에 보인 자리
	_t += dt
	_hist.append(Vector2(_t, lead.y))
	while _hist.size() > 2 and _hist[1].x < _t - HISTORY:
		_hist.pop_front()
	var n := cats.size()
	_n = n
	var r := ratio()
	var chain := mode_pick == 0
	var riding := ride and chain
	var want_shift := lead_shift(n)
	if want_shift != _shift_to:  # 마리 수가 바뀜: 지금 자리에서 SHIFT_TIME초에 걸쳐 부드럽게
		_shift_from = shift
		_shift_to = want_shift
		_shift_t = 0.0
	_shift_t = minf(1.0, _shift_t + dt / SHIFT_TIME)
	shift = lerpf(_shift_from, _shift_to, smoothstep(0.0, 1.0, _shift_t))
	_lift = move_toward(_lift, 1.0 if sliding else 0.0, dt / SLIDE_EASE)
	var lift := Vector2(0.0, -SLIDE_LIFT * smoothstep(0.0, 1.0, _lift))
	# 높이 뛰면 맨 위 자리가 생선 수에 닿을 때부터 무리 모양 그대로 부드럽게 눌림 (아기마다 따로 누르면 위에 한 줄로 쌓여 겹침)
	var rest_top := 0.0
	for i in n:
		rest_top = minf(rest_top, rest(i, n).y + lift.y - Balance.KITTEN_BOB)
	var limit := top()
	for i in n:
		var q: float = cats[i].quirk
		var spring: Spring = _springs[i]
		_age[i] += dt
		var hz: float = Balance.KITTEN_CHAIN_HZ if chain else Balance.KITTEN_FOLLOW_HZ * (0.7 + 0.6 * q)  # 무리는 아기마다 빠르기가 다름
		spring.omega = TAU * hz * minf(1.0, 0.25 + 0.75 * _age[i] / JOIN_TIME)
		spring.damping = Balance.KITTEN_CHAIN_DAMP if chain else Balance.KITTEN_FOLLOW_DAMP
		var lead_y := _lead_y(_t - (i + 1) * Balance.KITTEN_CHAIN_DELAY) if chain else lead.y
		lead_y = soft_top(lead_y + rest_top, limit) - rest_top
		var to := Vector2(lead.x, lead_y) + rest(i, n) + lift
		if riding:
			to += Vector2(_drags[i].step(Vector2.ZERO, dt).x, wave(i))
			var edge := EDGE - RIDE_TAIL * r  # 늘어질 때 왼쪽 경계는 넘은 만큼의 EDGE_SOFT만 (맨 뒤가 경계에 쌓이지 않게, 최대 EDGE_OVER x r)
			if to.x < edge:
				to.x = maxf(edge - (edge - to.x) * EDGE_SOFT, edge - EDGE_OVER * r)
		else:
			to += CatParade.bob(_t, fmod(q + 0.381 * i, 1.0))  # 둥실 박자가 아기마다 다름 (자리 번호로도 어긋남)
		if not chain:
			to += orbit(i, q, _t)
		to.y = minf(to.y, floor_at.call(to.x) - FLOOR_LIFT * r)
		var was := spring.value
		spring.step(to, dt)
		if _age[i] < JOIN_TIME * 2.0:  # 날아오는 중: 너무 빠르지 않게
			spring.velocity = spring.velocity.limit_length(JOIN_SPEED)
			spring.value = was + (spring.value - was).limit_length(JOIN_SPEED * dt)
		pos[i] = spring.value
		_landed[i] = _landed[i] or spring.value.distance_to(to) < CLOUD_W * r
	var low: Array[float] = []
	for i in n:
		low.append(floor_at.call(pos[i].x) - FLOOR_LIFT * r)
	var left := EDGE - RIDE_TAIL * r - EDGE_OVER * r if riding else EDGE + CLOUD_W * r * 0.5
	_separate(n, r, Rect2(left, limit - 20.0 * r, INF, INF), low, minf(RIDE_GAP * r * RIDE_SEP, ride_gap(n) * 0.9) if riding else CLOUD_W * r * 1.05)  # 좁힌 줄을 밀어내 뭉치지 않게
	for i in n:
		pos[i] = shown[i] + (pos[i] - shown[i]).limit_length(MAX_SPEED * dt)  # 기다리던 옥상에서 막 뜬 아기도 바닥 위로 튀지 않게
		pos[i].y = maxf(pos[i].y, limit - 20.0 * r)  # 슬라이딩으로 올라갈 때도 생선 수 위로 안 감
		var vy: float = _springs[i].velocity.y
		var want := clampf(vy / TILT_SPEED, -1.0, 1.0) * MAX_TILT  # 올라가면(-) 뒤로, 내려오면(+) 앞으로
		tilt[i] += (want - tilt[i]) * (1.0 - exp(-TILT_RATE * dt))
		var s := clampf(vy / SQUASH_SPEED, 0.0, 1.0) * SQUASH
		cloud[i] = _clouds[i].step(Vector2(1.0 + s, 1.0 - s), dt)
	_step_puffs(dt, n if riding else 0, r)


## 구름 꼬리 조각: 움직이고 늙히고, 자리 잡은 아기마다 간격이 되면 하나씩 (PUFF_MAX를 넘으면 그 아기는 다음 차례로)
func _step_puffs(dt: float, n: int, r: float) -> void:
	for p in puffs:
		p.t += dt
		p.p += PUFF_SPEED * dt
	puffs = puffs.filter(func(p: Dictionary) -> bool: return p.t < PUFF_LIFE)
	for i in n:
		_puff_in[i] -= dt
		if _puff_in[i] > 0.0:
			continue
		_puff_in[i] += _rng.randf_range(PUFF_GAP.x, PUFF_GAP.y)
		if _landed[i] and puffs.size() < PUFF_MAX:
			puffs.append({"p": pos[i] + PUFF_FROM * r * cloud[i], "t": 0.0, "kind": _rng.randi() % PUFF_KINDS, "s": _rng.randf_range(0.8, 1.15)})


## t초 때 주인공 발끝 높이 (기록 사이는 선형, 기록보다 앞이면 가장 오래된 값)
func _lead_y(t: float) -> float:
	for k in range(_hist.size() - 1, 0, -1):
		var a := _hist[k - 1]
		if a.x <= t:
			var b := _hist[k]
			return lerpf(a.y, b.y, clampf((t - a.x) / maxf(b.x - a.x, 0.0001), 0.0, 1.0))
	return _hist[0].y


## 구름(폭 CLOUD_W·높이 CLOUD_H배 타원)끼리 겹치면 반씩 밀어냄 (보이는 자리만, 스프링은 그대로라 매 프레임 같은 만큼 밀려 떨리지 않음).
## 밀 때마다 화면 왼쪽·생선 수(box 왼쪽 위)·지붕(low) 안으로 되돌려, 끝에 닿은 아기 대신 다른 아기가 밀려남. 날아오는 중인 아기는 빼고
func _separate(n: int, r: float, box: Rect2, low: Array[float], d_min: float) -> void:
	for pass_i in 8:
		for a in n:
			for b in range(a + 1, n):
				if not (_landed[a] and _landed[b]):
					continue
				var d := pos[b] - pos[a]
				d.y /= CLOUD_H
				var len := d.length()
				if len >= d_min:
					continue
				var push := (d / len if len > 0.01 else Vector2.LEFT) * (d_min - len) * 0.5
				push.y *= CLOUD_H
				pos[a] -= push
				pos[b] += push
		for i in n:
			pos[i] = Vector2(maxf(pos[i].x, box.position.x), clampf(pos[i].y, box.position.y, low[i]))
