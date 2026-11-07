class_name RoofGenerator
extends RefCounted
## 옥상을 하나씩 이어서 만든다. 옥상 사이 간격은 항상 최대 점프로 넘을 수 있는 범위 안에 있다.
## 옥상 하나 = {"left": 왼쪽 x, "right": 오른쪽 x, "top": 높이(아래에서 위로)}
## 같은 시드면 항상 같은 옥상이 나온다.
##
## 특수 틈: 일부 틈은 점프 한 번으로 못 건너게 넓히고 구조물을 둔다 (별도 난수로 정하니 일반 틈의 난수 흐름은 그대로).
## - 빨래줄 틈: 두 옥상 높이를 같게 하고, 틈 전체를 줄이 가로지른다. 다음 옥상(roof.line = 줄 판정)은 튕김이 넘치지 않게 넓다.
## - 전봇대 틈: 틈 한가운데 작은 판 옥상(platform = true, 벽 판정 없는 발판)이 끼고, 그 다음 옥상이 이어진다.
## 특수 틈 다음 옥상은 no_ghost = true (벽에 닿아도 투명화 구제 없음: 줄·판을 거치지 않고 건너는 걸 막는다).

var _rng := RandomNumberGenerator.new()
var _special_rng := RandomNumberGenerator.new()
var _pending: Array[Dictionary] = []  # 전봇대 틈에서 판 뒤에 이어질 옥상
var _made := 0  # 지금까지 만든 일반 옥상 수


func _init(seed_value: int) -> void:
	_rng.seed = seed_value
	_special_rng.seed = hash(seed_value) ^ 0x2545f491


## 시작 옥상 (고양이가 서 있는 넓은 옥상)
static func first_roof(left: float) -> Dictionary:
	return {"left": left, "right": left + Balance.ROOF_FIRST_WIDTH, "top": (Balance.ROOF_TOP_MIN + Balance.ROOF_TOP_MAX) * 0.5}


## prev 다음 옥상(전봇대 틈이면 판 옥상). speed는 지금 달리는 속도 (빠를수록 간격이 넓어질 수 있음)
func next_roof(prev: Dictionary, speed: float) -> Dictionary:
	if not _pending.is_empty():
		return _pending.pop_front()
	var roof := _plain_roof(prev, speed)
	var wants_special := _special_rng.randf() < Balance.SPECIAL_GAP_CHANCE
	var is_line := _special_rng.randf() < Balance.LINE_SHARE
	var t := _special_rng.randf()
	_made += 1
	if wants_special and _made > Balance.SPECIAL_GAP_AFTER:
		var special := _line_roof(prev, roof, speed, t) if is_line else _pole_roofs(prev, roof, speed, t)
		if not special.is_empty():
			return special
	return roof


## 일반 옥상 (특수 틈이 아닐 때)
func _plain_roof(prev: Dictionary, speed: float) -> Dictionary:
	var top := clampf(prev.top + _rng.randf_range(-Balance.ROOF_TOP_STEP, Balance.ROOF_TOP_STEP),
			Balance.ROOF_TOP_MIN, Balance.ROOF_TOP_MAX)
	var gap := _rng.randf_range(Balance.ROOF_GAP_MIN, max_gap(speed, top - prev.top))
	var left: float = prev.right + gap
	var width_min := min_width(speed)
	return {"left": left, "right": left + _rng.randf_range(width_min, maxf(Balance.ROOF_WIDTH_MAX, width_min * 1.5)), "top": top}


## 가장 짧게 뛰어도(톡 누름) 이 옥상을 지나쳐 버리지 않는 최소 너비.
## 가장 높은 곳에서 내려오는 짧은 점프가 가장 멀리 가므로 그 거리를 기준으로 한다.
static func min_width(speed: float) -> float:
	return maxf(Balance.ROOF_WIDTH_MIN, speed * JumpModel.air_time(0.0, -Balance.ROOF_TOP_STEP))


## 높이 차 rise일 때 허용하는 최대 간격 (최대 점프 거리 x 여유, 최소 간격보다 작아지지 않음)
static func max_gap(speed: float, rise: float) -> float:
	return maxf(Balance.ROOF_GAP_MIN, JumpModel.max_reach(speed, rise) * gap_safety(speed))


## 속도에 따른 간격 여유: 처음 속도에서 ROOF_GAP_SAFETY_START, 최대 속도에서 ROOF_GAP_SAFETY
static func gap_safety(speed: float) -> float:
	var t := inverse_lerp(Balance.RUN_SPEED, Balance.SPEED_MAX, speed)
	return lerpf(Balance.ROOF_GAP_SAFETY_START, Balance.ROOF_GAP_SAFETY, clampf(t, 0.0, 1.0))


## 특수 틈을 건너는 데 쓰는 속도: 옥상은 2200픽셀 앞에서 만들어서 도착할 때는 더 빠르다 (못 건넘 기준은 빠른 쪽으로)
static func arrival_speed(speed: float) -> float:
	return minf(Balance.SPEED_MAX, speed + Balance.SPEED_GAIN * Balance.ROOF_LOOKAHEAD / speed)


## 점프 한 번(최대)으로 높이 차 rise의 옥상을 못 건너는 가장 좁은 틈. 옥상 끝에서 마지막으로 뛸 수 있는 위치
## (발 범위 + 코요테 + 한 칸)에서 뛴 최대 점프가 다음 옥상 발 범위에 닿는 거리보다 여유만큼 더 넓다
static func clear_gap(speed: float, rise: float) -> float:
	var v := arrival_speed(speed)
	return JumpModel.max_reach(v, rise) + 2.0 * Balance.CAT_FOOT_HALF + v * (Balance.COYOTE_TIME + 1.0 / 120.0) + Balance.SPECIAL_GAP_MARGIN


## 빨래줄 틈: base(일반 옥상)의 너비를 쓰되 높이는 prev와 같게, 틈은 못 건너는 최소 ~ 최소 + 튕김 한 번의 거리
func _line_roof(prev: Dictionary, base: Dictionary, speed: float, t: float) -> Dictionary:
	var v := arrival_speed(speed)
	var rope: float = prev.top + Balance.LINE_HEIGHT
	var normal_flight := v * JumpModel.fall_time(rope, sqrt(2.0 * Balance.GRAVITY * Balance.LINE_BOUNCE_HEIGHT), prev.top)
	var boost_flight := v * JumpModel.fall_time(rope, sqrt(2.0 * Balance.GRAVITY * Balance.LINE_BOOST_HEIGHT), prev.top)
	var min_gap := clear_gap(speed, 0.0)
	var left: float = prev.right + lerpf(min_gap, min_gap + normal_flight * Balance.LINE_GAP_SPAN, t)
	# 줄 끝에서 더 높이 튕겨도 이 옥상 안에 내려앉을 너비
	var width := maxf(base.right - base.left, Balance.CAT_FOOT_HALF + boost_flight + 120.0)
	return {"left": left, "right": left + width, "top": prev.top, "no_ghost": true,
			"line": {"kind": "line", "left": prev.right, "right": left, "top": rope, "base": prev.top}}


## 전봇대 틈: 판 옥상을 돌려주고 그 다음 옥상(base 너비·높이)은 _pending에 둔다. 못 만들면 빈 Dictionary
func _pole_roofs(prev: Dictionary, base: Dictionary, speed: float, t: float) -> Dictionary:
	var top: float = base.top
	var plate_top := maxf(prev.top, top)
	var plate_width := lerpf(Balance.POLE_WIDTH_START, Balance.POLE_WIDTH_MIN,
			clampf(inverse_lerp(Balance.RUN_SPEED, Balance.SPEED_MAX, speed), 0.0, 1.0))
	var max1 := Balance.POLE_GAP_SAFETY * JumpModel.max_reach(speed, plate_top - prev.top)  # prev → 판
	var max2 := Balance.POLE_GAP_SAFETY * JumpModel.max_reach(speed, top - plate_top)       # 판 → 다음
	var min_gap := clear_gap(speed, top - prev.top)
	var cap := plate_width + max1 + max2
	if cap < min_gap or max1 < Balance.ROOF_GAP_MIN or max2 < Balance.ROOF_GAP_MIN:
		return {}  # 판을 거쳐도 건너기 어려운 높이 차라 일반 틈으로
	var gap := lerpf(min_gap, minf(cap, min_gap + Balance.POLE_GAP_SPAN), t)
	var gap1 := clampf((gap - plate_width) * 0.5, Balance.ROOF_GAP_MIN, max1)
	var gap2 := gap - plate_width - gap1
	if gap2 > max2:
		gap2 = max2
		gap1 = gap - plate_width - gap2
	if gap1 < Balance.ROOF_GAP_MIN or gap2 < Balance.ROOF_GAP_MIN:
		return {}
	var plate_left: float = prev.right + gap1
	var left := plate_left + plate_width + gap2
	_pending.append({"left": left, "right": left + (base.right - base.left), "top": top, "no_ghost": true})
	return {"left": plate_left, "right": plate_left + plate_width, "top": plate_top, "platform": true}
