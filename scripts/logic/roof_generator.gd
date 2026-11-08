class_name RoofGenerator
extends RefCounted
## 옥상을 하나씩 이어서 만든다. 옥상 사이 간격은 항상 최대 점프로 넘을 수 있는 범위 안에 있다.
## 옥상 하나 = {"left": 왼쪽 x, "right": 오른쪽 x, "top": 높이(아래에서 위로)}
## 같은 시드면 항상 같은 옥상이 나온다.
##
## 특수 틈: 일부 틈은 점프 한 번으로 못 건너게 넓히고 구조물을 둔다 (별도 난수로 정하니 일반 틈의 난수 흐름은 그대로).
## 넓은 틈은 "점프 + 더블점프를 다 써도" 못 건너는 너비다.
## - 트램펄린 틈: 두 옥상 높이를 같게 하고(TRAMP_TOP_MAX 이하에서만), 앞 옥상 끝에 트램펄린(roof.tramp)을 둔다.
##   누름·퍼펙트 튕김은 앞으로 발사(가로 속도 good_vx·perfect_vx)되어 항상 다음 옥상에 내려앉고, 다음 옥상은 퍼펙트 + 더블점프로도
##   지나치지 않게 넓다. 빨래줄 틈(Balance.LINE_ENABLED일 때만, 지금은 꺼짐)은 두 옥상 사이를 줄(roof.line)이 가로지른다.
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
		# 줄·트램펄린 틈을 못 만드는 높이면 일반 틈 (전봇대로 바꾸면 전봇대가 v0.4.1보다 잦아짐)
		var special := {}
		if not is_line:
			special = _pole_roofs(prev, roof, speed, t)
		elif Balance.LINE_ENABLED:
			special = _line_roof(prev, roof, speed, t)
		else:
			special = _tramp_roof(prev, roof, speed, t)
		if not special.is_empty():
			return special
	return roof


## 일반 옥상 (특수 틈이 아닐 때)
func _plain_roof(prev: Dictionary, speed: float) -> Dictionary:
	var top := clampf(prev.top + _rng.randf_range(-Balance.ROOF_TOP_STEP, Balance.ROOF_TOP_STEP),
			Balance.ROOF_TOP_MIN, Balance.ROOF_TOP_MAX)
	var gap := _rng.randf_range(Balance.ROOF_GAP_MIN, max_gap(speed, top - prev.top))
	var left: float = prev.right + gap
	var width_min := min_width(arrival_speed(speed))  # 다음 단계 속도로 톡 뛰어도 지나치지 않게
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


## 옥상에 도착할 때의 속도 = 다음 단계 속도: 옥상은 ROOF_LOOKAHEAD 앞에서 만들고, 그 거리는 많아야 5.1초라 가장 짧은 단계(15초)보다 짧아 한 단계만 넘는다
static func arrival_speed(speed: float) -> float:
	return SpeedCurve.next_speed(speed)


## 점프 + 더블점프(둘 다 최대, 가장 멀리 가는 때)로도 높이 차 rise의 옥상을 못 건너는 가장 좁은 틈. 옥상 끝에서 마지막으로
## 뛸 수 있는 위치(발 범위 + 코요테 + 한 칸)에서 뛴 거리가 다음 옥상 발 범위에 닿는 거리보다 여유만큼 더 넓다
static func clear_gap(speed: float, rise: float) -> float:
	var v := arrival_speed(speed)
	return JumpModel.max_double_reach(v, rise) + 2.0 * Balance.CAT_FOOT_HALF + v * (Balance.COYOTE_TIME + 1.0 / 120.0) + Balance.SPECIAL_GAP_MARGIN


## 빨래줄 틈: base(일반 옥상)의 너비를 쓰되 높이는 prev와 같게, 틈은 못 건너는 최소 ~ 최소 + 누름 튕김 한 번의 거리 x LINE_GAP_SPAN.
## 옥상이 LINE_TOP_MAX보다 높으면 빈 Dictionary
func _line_roof(prev: Dictionary, base: Dictionary, speed: float, t: float) -> Dictionary:
	if prev.top > Balance.LINE_TOP_MAX:
		return {}
	var v := arrival_speed(speed)
	var rope: float = prev.top + Balance.LINE_HEIGHT
	var good_flight := v * JumpModel.fall_time(rope, line_bounce_speed(Balance.LINE_GOOD_HEIGHT), prev.top)
	var min_gap := clear_gap(speed, 0.0)
	var left: float = prev.right + lerpf(min_gap, min_gap + good_flight * Balance.LINE_GAP_SPAN, t)
	var width := maxf(base.right - base.left, line_landing_width(v))
	return {"left": left, "right": left + width, "top": prev.top, "no_ghost": true,
			"line": {"kind": "line", "left": prev.right, "right": left, "top": rope, "base": prev.top}}


## 줄에서 height만큼 튕겨 오르는 세로 속도
static func line_bounce_speed(height: float) -> float:
	return sqrt(2.0 * Balance.GRAVITY * height)


## 줄 끝(가장 늦게 실려 있다 튕긴 자리)에서 퍼펙트로 튕기고 더블점프까지 가장 멀리 써도 줄 다음 옥상 안에 내려앉는 너비 (도착 속도 v)
static func line_landing_width(v: float) -> float:
	var flight := JumpModel.best_double(line_bounce_speed(Balance.LINE_PERFECT_HEIGHT), 0.0, -Balance.LINE_HEIGHT).x
	return Balance.CAT_FOOT_HALF + v * (Balance.LINE_RIDE_TIME + flight) + 120.0


## 트램펄린 틈: prev 끝(TRAMP_INSET 안쪽)에 트램펄린을 두고, 틈은 못 건너는 최소 ~ 최소 + TRAMP_GAP_SPAN, 다음 옥상 높이는 prev와 같게.
## 발사 속도(good_vx, perfect_vx)를 트램펄린에 적어 둔다. 옥상이 TRAMP_TOP_MAX보다 높으면 빈 Dictionary
func _tramp_roof(prev: Dictionary, base: Dictionary, speed: float, t: float) -> Dictionary:
	if prev.top > Balance.TRAMP_TOP_MAX:
		return {}
	var min_gap := clear_gap(speed, 0.0)
	var left: float = prev.right + lerpf(min_gap, min_gap + Balance.TRAMP_GAP_SPAN, t)
	var right: float = prev.right - Balance.TRAMP_INSET
	var tramp := {"kind": "tramp", "left": right - Balance.TRAMP_WIDTH, "right": right, "top": prev.top + Balance.TRAMP_LIFT, "base": prev.top}
	# 가장 일찍 튕기는 자리 = 위에서 내려와 뒷발 끝만 걸친 때
	var earliest: float = tramp.left - Balance.CAT_FOOT_HALF
	tramp.good_vx = (left + Balance.TRAMP_LAND_IN - earliest) / tramp_flight(Balance.TRAMP_GOOD_HEIGHT)
	tramp.perfect_vx = (left + Balance.TRAMP_LAND_IN + Balance.TRAMP_PERFECT_EXTRA - earliest) / tramp_flight(Balance.TRAMP_PERFECT_HEIGHT)
	var width := maxf(base.right - base.left, tramp_landing_right(tramp, arrival_speed(speed)) - left)
	return {"left": left, "right": left + width, "top": prev.top, "no_ghost": true, "tramp": tramp}


## 트램펄린 그물에서 height만큼 튕겨 옥상 높이(그물보다 TRAMP_LIFT 아래)까지 내려오는 시간 (더블점프 없이)
static func tramp_flight(height: float) -> float:
	return JumpModel.fall_time(Balance.TRAMP_LIFT, line_bounce_speed(height), 0.0)


## 가장 늦게 튕긴 자리(앞발 끝만 걸쳐 내려와 끝까지 실려 있던 때, 속도 v)에서 누름·퍼펙트로 튕기고 더블점프까지 가장 멀리 썼을 때
## 다음 옥상에 서려면 옥상이 이어져야 하는 오른쪽 끝 (발 범위 + 여유 120 포함)
static func tramp_landing_right(tramp: Dictionary, v: float) -> float:
	var latest: float = tramp.right + Balance.CAT_FOOT_HALF + v * Balance.LINE_RIDE_TIME
	var far := 0.0
	for c in [[tramp.good_vx, Balance.TRAMP_GOOD_HEIGHT], [tramp.perfect_vx, Balance.TRAMP_PERFECT_HEIGHT]]:
		var t := JumpModel.best_double(line_bounce_speed(c[1]), 0.0, -Balance.TRAMP_LIFT).x
		far = maxf(far, maxf(c[0], v) * t)
	return latest + far + Balance.CAT_FOOT_HALF + 120.0


## 전봇대 판 앞이나 뒤 틈의 상한: 점프 + 더블점프 최대 거리 x POLE_GAP_SAFETY, 화면에 보이는 거리(POLE_GAP_VIEW_MAX) 이하
static func pole_gap_max(speed: float, rise: float) -> float:
	return minf(Balance.POLE_GAP_SAFETY * JumpModel.max_double_reach(speed, rise), Balance.POLE_GAP_VIEW_MAX)


## 전봇대 틈: 판 옥상을 돌려주고 그 다음 옥상(base 너비·높이)은 _pending에 둔다. 못 만들면 빈 Dictionary
func _pole_roofs(prev: Dictionary, base: Dictionary, speed: float, t: float) -> Dictionary:
	var top: float = base.top
	var plate_top := maxf(prev.top, top)
	var plate_width := lerpf(Balance.POLE_WIDTH_START, Balance.POLE_WIDTH_MIN,
			clampf(inverse_lerp(Balance.RUN_SPEED, Balance.SPEED_MAX, speed), 0.0, 1.0))
	var max1 := pole_gap_max(speed, plate_top - prev.top)  # prev → 판
	var max2 := pole_gap_max(speed, top - plate_top)       # 판 → 다음
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
