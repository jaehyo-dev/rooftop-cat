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


## 최대 점프로 출발 높이보다 rise만큼 높은(음수면 낮은) 곳에 내려앉을 때까지 걸리는 시간.
## 닿을 수 없는 높이면 -1.
static func max_air_time(rise: float) -> float:
	if rise > Balance.JUMP_MAX_HEIGHT:
		return -1.0
	var v := jump_speed()
	var hold := max_hold_time()
	var top_of_hold := v * hold
	# 손을 뗀 뒤: 높이 = top_of_hold + v t - g t^2 / 2 = rise 의 큰 근 (내려오는 쪽)
	var g := Balance.GRAVITY
	var t := (v + sqrt(v * v + 2.0 * g * (top_of_hold - rise))) / g
	return hold + t


## 최대 점프로 넘을 수 있는 가로 거리 (속도 speed, 높이 차 rise)
static func max_reach(speed: float, rise: float) -> float:
	var t := max_air_time(rise)
	return speed * t if t >= 0.0 else 0.0
