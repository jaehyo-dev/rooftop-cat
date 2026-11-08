class_name JumpModel
## 누르는 시간 → 점프 높이, 최대 점프로 닿는 거리 계산 (화면과 분리된 순수 계산).
##
## 점프 방식: 누르는 순간 jump_speed()로 올라가기 시작하고, 누르고 있는 동안(최대 max_hold_time())
## 그 속도를 유지한다. 떼거나 최대 시간이 지나면 중력으로 감속해 떨어진다.
## 그래서 높이 = JUMP_MIN_HEIGHT + jump_speed() x 누른 시간 이고, 최대 JUMP_MAX_HEIGHT에서 멈춘다.


## 올라가는 속도 (톡 눌렀을 때 최소 높이가 되는 속도)
static func jump_speed() -> float:
	return sqrt(2.0 * Balance.GRAVITY * Balance.JUMP_MIN_HEIGHT)


## 속도를 유지할 수 있는 최대 시간 (이만큼 누르면 최대 높이)
static func max_hold_time() -> float:
	return (Balance.JUMP_MAX_HEIGHT - Balance.JUMP_MIN_HEIGHT) / jump_speed()


## 누른 시간(초)에 따른 점프 높이
static func height_for_hold(hold: float) -> float:
	return Balance.JUMP_MIN_HEIGHT + jump_speed() * clampf(hold, 0.0, max_hold_time())


## hold초 누른 점프로 출발 높이보다 rise만큼 높은(음수면 낮은) 곳에 내려앉을 때까지 걸리는 시간.
## 닿을 수 없는 높이면 -1.
static func air_time(hold: float, rise: float) -> float:
	if rise > height_for_hold(hold):
		return -1.0
	var v := jump_speed()
	hold = clampf(hold, 0.0, max_hold_time())
	var top_of_hold := v * hold
	# 손을 뗀 뒤: 높이 = top_of_hold + v t - g t^2 / 2 = rise 의 큰 근 (내려오는 쪽)
	var g := Balance.GRAVITY
	return hold + (v + sqrt(v * v + 2.0 * g * (top_of_hold - rise))) / g


## 최대 점프의 체공 시간 (닿을 수 없는 높이면 -1)
static func max_air_time(rise: float) -> float:
	return air_time(max_hold_time(), rise)


## 최대 점프로 넘을 수 있는 가로 거리 (속도 speed, 높이 차 rise)
static func max_reach(speed: float, rise: float) -> float:
	var t := max_air_time(rise)
	return speed * t if t >= 0.0 else 0.0


## 높이 top에서 위로 v0의 속도로 던져 올려 높이 level까지 내려올 때까지의 시간 (닿을 수 없으면 -1)
static func fall_time(top: float, v0: float, level: float) -> float:
	var g := Balance.GRAVITY
	var disc := v0 * v0 + 2.0 * g * (top - level)
	return (v0 + sqrt(disc)) / g if disc >= 0.0 else -1.0


# --- 더블점프 ---

## 더블점프에서 속도를 유지할 수 있는 최대 시간 (이만큼 누르면 DOUBLE_JUMP_MAX_HEIGHT)
static func double_max_hold() -> float:
	return (Balance.DOUBLE_JUMP_MAX_HEIGHT - Balance.JUMP_MIN_HEIGHT) / jump_speed()


## 중력으로 dt만큼 진행한 (높이, 세로 속도). floating이면(더블점프 뒤) |세로 속도| < DOUBLE_FLOAT_SPEED 구간만 중력을 줄인다.
## 구간 경계(+-DOUBLE_FLOAT_SPEED)를 지나는 순간에서 쪼개 정확히 적분해 프레임 간격과 상관없이 같은 궤적이 나온다
static func integrate(y: float, vy: float, dt: float, floating: bool) -> Vector2:
	var g := Balance.GRAVITY
	var f := Balance.DOUBLE_FLOAT_SPEED
	var left := dt
	if floating and vy > f and (vy - f) / g < left:
		var t1 := (vy - f) / g
		y += vy * t1 - 0.5 * g * t1 * t1
		vy = f
		left -= t1
	if floating and vy > -f and vy <= f:
		var gf := g * Balance.DOUBLE_FLOAT_GRAVITY
		var t2 := minf(left, (vy + f) / gf)
		y += vy * t2 - 0.5 * gf * t2 * t2
		vy = -f if t2 < left else vy - gf * t2
		left -= t2
	y += vy * left - 0.5 * g * left * left
	vy -= g * left
	return Vector2(y, vy)


## 높이 y, 세로 속도 vy에서 내려오며 높이 level을 지날 때까지의 시간 (floating은 integrate와 같음). 못 닿으면 -1
static func fall_to(y: float, vy: float, level: float, floating: bool) -> float:
	var g := Balance.GRAVITY
	var f := Balance.DOUBLE_FLOAT_SPEED
	var t := 0.0
	if floating:
		if vy > f:
			var t1 := (vy - f) / g
			y += vy * t1 - 0.5 * g * t1 * t1
			vy = f
			t += t1
		if vy > -f:
			var gf := g * Balance.DOUBLE_FLOAT_GRAVITY
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


## 위로 v0의 속도로 출발해 hold초 그 속도를 유지한 뒤 중력으로 움직일 때, 출발 t초 뒤의 (높이, 세로 속도)
static func launch_state(v0: float, hold: float, t: float) -> Vector2:
	if t <= hold:
		return Vector2(v0 * t, v0)
	var s := t - hold
	return Vector2(v0 * hold + v0 * s - 0.5 * Balance.GRAVITY * s * s, v0 - Balance.GRAVITY * s)


## (v0, hold)로 출발해 t_press초에 더블점프(최대로 누름)를 썼을 때 출발 높이 기준 rise를 내려 지날 때까지의 총 시간. 못 닿으면 -1
static func double_total_time(v0: float, hold: float, t_press: float, rise: float) -> float:
	var at := launch_state(v0, hold, t_press)
	var hd := double_max_hold()
	var t := fall_to(at.x + jump_speed() * hd, jump_speed(), rise, true)
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
