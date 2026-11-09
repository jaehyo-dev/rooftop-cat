class_name SfxEvents
## RunnerSim의 이번 step 결과 → 낼 효과음 이름 (화면·소리와 분리된 순수 계산).

const ALL := ["jump", "double_jump", "land", "fish", "boing", "perfect", "fall", "stage_up", "coo", "pang", "bell"]


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
	for item in sim.picked:
		if item.kind != "box":
			out.append("bell" if item.kind == "bell" else "fish")
			break  # 한 step에 여러 마리여도 한 번
	if not sim.smashed.is_empty() or not sim.canned.is_empty():
		out.append("pang")
	if sim.bell_blocked:
		out.append("bell")
	if sim.stage_rose or sim.dash_started:
		out.append("stage_up")
	if fall_start:
		out.append("fall")
	return out
