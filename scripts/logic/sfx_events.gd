class_name SfxEvents
## RunnerSim의 이번 step 결과 → 낼 효과음 이름 (화면·소리와 분리된 순수 계산).

const ALL := ["jump", "double_jump", "land", "fish", "boing", "perfect", "fall", "stage_up", "coo"]


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
		if item.kind == "fish":
			out.append("fish")
			break  # 한 step에 여러 마리여도 한 번
	if sim.stage_rose:
		out.append("stage_up")
	if fall_start:
		out.append("fall")
	return out
