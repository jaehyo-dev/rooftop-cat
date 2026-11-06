extends RefCounted
## 밸런스 봇: 사람처럼 타이밍이 조금씩 어긋나게 점프하며 한 판을 끝까지 플레이하고, 버틴 시간을 잰다.
##
## 봇이 노리는 점프: 옥상에 내려설 때마다 "다음 옥상까지 최대로 눌러 닿을 수 있는 구간"의 가운데에서 누르려 한다.
## 실력(skill)은 두 가지 실수로 나타낸다 (시드로 고정된 무작위 값):
## - timing: 누르는 순간이 어긋나는 정도 (초, 표준편차). 빠를수록 같은 시간 실수가 더 먼 거리가 된다
## - short_hold: 손을 일찍 떼는 정도 (최대로 누를 시간에 대한 비율, 표준편차)
## shortcut: 사람의 반응 속도·피로는 흉내 내지 않음. 실제 플레이 기록이 생기면 그 값으로 실력 수치를 맞춘다

const DT := 1.0 / 120.0

## 실력별 실수 크기. 초보 = 처음 해 보는 사람, 익숙함 = 몇 판 해 본 사람, 숙련 = 많이 해 본 사람
const SKILLS := {
	"초보": {"timing": 0.085, "short_hold": 0.35},
	"익숙함": {"timing": 0.05, "short_hold": 0.2},
	"숙련": {"timing": 0.035, "short_hold": 0.12},
}


## seed_value로 정해진 옥상에서 한 판 플레이하고 버틴 시간(초)을 돌려준다. max_time초를 버티면 max_time
static func play(skill: Dictionary, seed_value: int, max_time: float) -> float:
	var sim := RunnerSim.new(seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var planned_roof := {}   # 점프를 계획한 옥상 (내려설 때마다 새로 계획)
	var press_x := INF       # 이 위치에 오면 누른다
	var hold := 0.0          # 누를 시간
	var hold_left := 0.0
	while not sim.game_over and sim.elapsed < max_time:
		var ground: Dictionary = sim.get("_ground_roof")
		if sim.on_ground and not is_same(ground, planned_roof):
			planned_roof = ground
			press_x = _ideal_press_x(sim) + rng.randfn(0.0, skill.timing) * sim.speed
			hold = JumpModel.max_hold_time() * clampf(1.0 - absf(rng.randfn(0.0, skill.short_hold)), 0.0, 1.0)
		if sim.x >= press_x:
			press_x = INF
			hold_left = hold + DT  # 누르는 첫 step은 점프 시작이라 한 칸 더 누른다
		sim.step(DT, hold_left > 0.0)
		hold_left -= DT
	return minf(sim.elapsed, max_time)


## 최대로 눌러 다음 옥상에 내려앉을 수 있는 누름 위치 구간의 가운데
static func _ideal_press_x(sim: RunnerSim) -> float:
	var here := sim.roofs.find(sim.get("_ground_roof"))
	if here < 0 or here + 1 >= sim.roofs.size():
		return INF
	var roof: Dictionary = sim.roofs[here]
	var next: Dictionary = sim.roofs[here + 1]
	# 지금 속도로 계산 (점프하는 동안 빨라지는 건 아주 조금이라 무시)
	var reach := sim.speed * JumpModel.max_air_time(next.top - roof.top)
	var earliest: float = next.left - Balance.CAT_FOOT_HALF - reach + 10.0  # 이보다 일찍 누르면 앞발이 못 걸침
	var latest: float = roof.right + Balance.CAT_FOOT_HALF - 10.0          # 이보다 늦으면 발밑이 빔
	return (earliest + latest) * 0.5
