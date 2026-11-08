class_name JumpModel
## 누르는 시간 → 점프 높이, 최대 점프로 닿는 거리 계산 (화면과 분리된 순수 계산).
##
## 점프 무게 설정(Balance.JUMP_PRESETS, v0.5.0 2b 마무리에서 사용자가 하나를 고름)에 따라 누르는 동안의 움직임이 다르다.
## A: 누르는 동안(최대 max_hold_time()) 일정한 속도로 올라가고, 떼면 gravity()로 감속한다.
## B·C: 누르는 동안 hold_gravity()로 감속하는 포물선(처음이 가장 빠르고 꼭대기에서 느려짐), 떼면 속도를 잘라(release_speed) 바로 꺾인다.
## 어느 설정이든 톡 누르면 JUMP_MIN_HEIGHT, 끝까지 누르면 JUMP_MAX_HEIGHT.
## 설정은 정적 값이라 use_preset 뒤에 만든 판부터 적용한다 (옥상 간격이 이 값으로 계산되므로 판 중간에 바꾸지 않는다).
## shortcut: 설정을 전역 값 하나로 둠, 사용자가 고른 뒤 상수로 고정하면 없어진다

static var preset := "A"
static var _g := Balance.GRAVITY
static var _g_hold := 0.0
static var _float_g := Balance.DOUBLE_FLOAT_GRAVITY


## 점프 무게 설정을 고른다. fall_ratio·max_air가 있으면 "떨어질 때 중력 / 누르는 동안 중력 = fall_ratio, 최대 점프 체공 = max_air"가 되는 중력을 계산한다
static func use_preset(preset_name: String) -> void:
	var p: Dictionary = Balance.JUMP_PRESETS[preset_name]
	preset = preset_name
	_float_g = p.float_gravity
	if p.has("fall_ratio"):
		var rise_time: float = p.max_air / (1.0 + 1.0 / sqrt(p.fall_ratio))
		_g_hold = 2.0 * Balance.JUMP_MAX_HEIGHT / (rise_time * rise_time)
		_g = _g_hold * p.fall_ratio
	else:
		_g = Balance.GRAVITY
		_g_hold = 0.0


## 손을 떼었거나 누르지 않을 때의 중력 (튕김·떨어짐 모두)
static func gravity() -> float:
	return _g


## 누르고 있는 동안의 중력 (0이면 일정한 속도로 올라감)
static func hold_gravity() -> float:
	return _g_hold


## 더블점프 꼭대기에서 중력에 곱하는 값 (1이면 떠 있음 없음)
static func float_gravity() -> float:
	return _float_g


## 눌러서 height까지 오르는 출발 속도 (A는 높이와 상관없이 톡 눌렀을 때 최소 높이가 되는 속도)
static func _press_speed(height: float) -> float:
	if _g_hold == 0.0:
		return sqrt(2.0 * _g * Balance.JUMP_MIN_HEIGHT)
	return sqrt(2.0 * _g_hold * height)


## height까지 오르려고 누를 수 있는 최대 시간
static func _press_time(height: float) -> float:
	var v := _press_speed(height)
	return (height - Balance.JUMP_MIN_HEIGHT) / v if _g_hold == 0.0 else v / _g_hold


## 첫 점프의 출발 속도
static func jump_speed() -> float:
	return _press_speed(Balance.JUMP_MAX_HEIGHT)


## 속도를 유지(B·C는 포물선으로 계속 상승)할 수 있는 최대 시간 (이만큼 누르면 최대 높이)
static func max_hold_time() -> float:
	return _press_time(Balance.JUMP_MAX_HEIGHT)


## 위로 v0로 출발해 t초 누르고 있을 때 (올라간 높이, 세로 속도)
static func hold_state(v0: float, t: float) -> Vector2:
	return Vector2(v0 * t - 0.5 * _g_hold * t * t, v0 - _g_hold * t)


## 손을 뗀 순간의 세로 속도. risen = 누른 자리에서 올라간 높이, vy = 뗄 때 속도.
## B·C: 최소 높이까지는 올라가게 하고, 그 위에서 떼면 JUMP_CUT_RISE만 더 오르고 바로 꺾인다. A는 그대로
static func release_speed(risen: float, vy: float) -> float:
	if _g_hold == 0.0:
		return vy
	return minf(vy, sqrt(2.0 * _g * maxf(Balance.JUMP_MIN_HEIGHT - risen, Balance.JUMP_CUT_RISE)))


## v0로 출발해 hold초 누르고 뗀 직후의 (올라간 높이, 세로 속도)
static func released_state(v0: float, hold: float) -> Vector2:
	var s := hold_state(v0, hold)
	return Vector2(s.x, release_speed(s.x, s.y))


## 누른 시간(초)에 따른 점프 높이
static func height_for_hold(hold: float) -> float:
	var s := released_state(jump_speed(), clampf(hold, 0.0, max_hold_time()))
	return s.x + s.y * s.y / (2.0 * _g)


## hold초 누른 첫 점프의 꼭대기 시각 (누른 순간부터)
static func apex_time(hold: float) -> float:
	return hold + released_state(jump_speed(), hold).y / _g


## hold초 누른 점프로 출발 높이보다 rise만큼 높은(음수면 낮은) 곳에 내려앉을 때까지 걸리는 시간.
## 닿을 수 없는 높이면 -1.
static func air_time(hold: float, rise: float) -> float:
	if rise > height_for_hold(hold):
		return -1.0
	hold = clampf(hold, 0.0, max_hold_time())
	var s := released_state(jump_speed(), hold)
	return hold + _descend(s.x, s.y, _g, rise)


## 최대 점프의 체공 시간 (닿을 수 없는 높이면 -1)
static func max_air_time(rise: float) -> float:
	return air_time(max_hold_time(), rise)


## 최대 점프로 넘을 수 있는 가로 거리 (속도 speed, 높이 차 rise)
static func max_reach(speed: float, rise: float) -> float:
	var t := max_air_time(rise)
	return speed * t if t >= 0.0 else 0.0


## 높이 top에서 위로 v0의 속도로 던져 올려 높이 level까지 내려올 때까지의 시간 (닿을 수 없으면 -1)
static func fall_time(top: float, v0: float, level: float) -> float:
	var g := _g
	var disc := v0 * v0 + 2.0 * g * (top - level)
	return (v0 + sqrt(disc)) / g if disc >= 0.0 else -1.0


# --- 더블점프 ---

## 더블점프의 출발 속도
static func double_speed() -> float:
	return _press_speed(Balance.DOUBLE_JUMP_MAX_HEIGHT)


## 더블점프에서 누를 수 있는 최대 시간 (이만큼 누르면 DOUBLE_JUMP_MAX_HEIGHT)
static func double_max_hold() -> float:
	return _press_time(Balance.DOUBLE_JUMP_MAX_HEIGHT)


## 중력으로 dt만큼 진행한 (높이, 세로 속도). floating이면(더블점프 뒤) |세로 속도| < DOUBLE_FLOAT_SPEED 구간만 중력을 줄인다.
## 구간 경계(+-DOUBLE_FLOAT_SPEED)를 지나는 순간에서 쪼개 정확히 적분해 프레임 간격과 상관없이 같은 궤적이 나온다
static func integrate(y: float, vy: float, dt: float, floating: bool) -> Vector2:
	var g := _g
	var f := Balance.DOUBLE_FLOAT_SPEED
	var left := dt
	if floating and vy > f and (vy - f) / g < left:
		var t1 := (vy - f) / g
		y += vy * t1 - 0.5 * g * t1 * t1
		vy = f
		left -= t1
	if floating and vy > -f and vy <= f:
		var gf := g * _float_g
		var t2 := minf(left, (vy + f) / gf)
		y += vy * t2 - 0.5 * gf * t2 * t2
		vy = -f if t2 < left else vy - gf * t2
		left -= t2
	y += vy * left - 0.5 * g * left * left
	vy -= g * left
	return Vector2(y, vy)


## 높이 y, 세로 속도 vy에서 내려오며 높이 level을 지날 때까지의 시간 (floating은 integrate와 같음). 못 닿으면 -1
static func fall_to(y: float, vy: float, level: float, floating: bool) -> float:
	var g := _g
	var f := Balance.DOUBLE_FLOAT_SPEED
	var t := 0.0
	if floating:
		if vy > f:
			var t1 := (vy - f) / g
			y += vy * t1 - 0.5 * g * t1 * t1
			vy = f
			t += t1
		if vy > -f:
			var gf := g * _float_g
			var t2 := (vy + f) / gf
			var end_y := y + vy * t2 - 0.5 * gf * t2 * t2
			if end_y <= level:
				var d := _descend(y, vy, gf, level)
				return t + d if d >= 0.0 else -1.0
			y = end_y
			vy = -f
			t += t2
	var d2 := _descend(y, vy, g, level)
	return t + d2 if d2 >= 0.0 else -1.0


## y + vy t - g t^2 / 2 = level 의 큰 근 (내려오는 쪽). 없거나 이미 지났으면 -1
static func _descend(y: float, vy: float, g: float, level: float) -> float:
	var disc := vy * vy + 2.0 * g * (y - level)
	if disc < 0.0:
		return -1.0
	var t := (vy + sqrt(disc)) / g
	return t if t >= 0.0 else -1.0


## 위로 v0의 속도로 출발해 hold초 누른 뒤 중력으로 움직일 때, 출발 t초 뒤의 (높이, 세로 속도). hold가 0이면 누르지 않은 튕김 (속도를 자르지 않음)
static func launch_state(v0: float, hold: float, t: float) -> Vector2:
	if t <= hold:
		return hold_state(v0, t)
	var at := released_state(v0, hold) if hold > 0.0 else Vector2(0.0, v0)
	var s := t - hold
	return Vector2(at.x + at.y * s - 0.5 * _g * s * s, at.y - _g * s)


## (v0, hold)로 출발해 t_press초에 더블점프(최대로 누름)를 썼을 때 출발 높이 기준 rise를 내려 지날 때까지의 총 시간. 못 닿으면 -1
static func double_total_time(v0: float, hold: float, t_press: float, rise: float) -> float:
	var at := launch_state(v0, hold, t_press)
	var hd := double_max_hold()
	var top := hold_state(double_speed(), hd)
	var t := fall_to(at.x + top.x, top.y, rise, true)
	return t_press + hd + t if t >= 0.0 else -1.0


## (v0, hold)로 출발한 뒤 더블점프(최대)를 가장 멀리 가는 때에 썼을 때: x = 총 시간(못 닿으면 -1), y = 더블점프를 누른 시각.
## 누르는 시각을 훑어 찾는다 (옥상 생성·테스트 때만 부름)
static func best_double(v0: float, hold: float, rise: float) -> Vector2:
	# 더블점프로 rise에 닿을 수 있는 가장 늦은 시각: 그 높이에서 더블점프 최대 높이만큼 아래까지 내려온 때
	var reach_down := rise - Balance.DOUBLE_JUMP_MAX_HEIGHT
	var start := launch_state(v0, hold, hold)
	var t_last := hold + fall_to(start.x, start.y, reach_down, false)
	if t_last < hold:
		t_last = hold
	var best := Vector2(-1.0, hold)
	const SAMPLES := 160
	for i in SAMPLES + 1:
		var tp := lerpf(hold, t_last, float(i) / SAMPLES)
		var total := double_total_time(v0, hold, tp, rise)
		if total > best.x:
			best = Vector2(total, tp)
	# 가장 좋은 칸 양옆에서 한 번 더 좁혀 찾는다
	var step := (t_last - hold) / SAMPLES
	var lo := maxf(hold, best.y - step)
	var hi := minf(t_last, best.y + step)
	for i in 30:
		var m1 := lerpf(lo, hi, 1.0 / 3.0)
		var m2 := lerpf(lo, hi, 2.0 / 3.0)
		if double_total_time(v0, hold, m1, rise) < double_total_time(v0, hold, m2, rise):
			lo = m1
		else:
			hi = m2
	var tp2 := (lo + hi) * 0.5
	var total2 := double_total_time(v0, hold, tp2, rise)
	return Vector2(total2, tp2) if total2 > best.x else best


## 첫 점프(최대) + 더블점프(최대)를 가장 좋은 때에 썼을 때의 체공 시간 (높이 차 rise, 못 닿으면 -1)
static func max_double_air_time(rise: float) -> float:
	return best_double(jump_speed(), max_hold_time(), rise).x


## 첫 점프 + 더블점프로 넘을 수 있는 가장 먼 가로 거리 (속도 speed, 높이 차 rise)
static func max_double_reach(speed: float, rise: float) -> float:
	var t := max_double_air_time(rise)
	return speed * t if t >= 0.0 else 0.0
