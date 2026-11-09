class_name SfxEvents
## RunnerSim의 이번 step 결과 → 낼 효과음 이름 (화면·소리와 분리된 순수 계산).

const FISH_GAP := 0.07  # 생선 소리가 이 시간 안에 다시 나면 하나로 친다 (초)

const ALL := ["jump", "double_jump", "land", "fish", "pickup", "boing", "perfect", "fall", "stage_up", "coo", "pang", "bell"]


## fall_start: 끝날 떨어짐이 이번에 처음 확정됐는지 (부르는 쪽이 한 번만 true로)
static func sounds(sim: RunnerSim, fall_start: bool) -> Array[String]:
	var out: Array[String] = []
	if sim.jumped:
		out.append("jump")
	if sim.double_jumped:
		out.append("double_jump")
	if sim.landed:
		out.append("land")
	if sim.bounced:
		out.append("boing")
		if sim.bounce_result == "perfect":
			out.append("perfect")
	var bite := ""  # 한 step에 여러 개여도 한 번. 생선과 같이 먹으면 아이템 소리
	for item in sim.picked:
		if item.kind == "bell":
			bite = "bell"
		elif item.kind == "fish":
			bite = "fish" if bite.is_empty() else bite
		elif item.kind != "box" and bite != "bell":
			bite = "pickup"
	if not bite.is_empty():
		out.append(bite)
	if not sim.smashed.is_empty() or not sim.canned.is_empty():
		out.append("pang")
	if sim.bell_blocked:
		out.append("bell")
	if sim.stage_rose or sim.dash_started:
		out.append("stage_up")
	if fall_start:
		out.append("fall")
	return out


## 생선 소리를 새로 틀지 (now·last = 판 안 시각. 새 판이면 시각이 되돌아간다)
static func fish_due(now: float, last: float) -> bool:
	return now - last >= FISH_GAP or now < last
