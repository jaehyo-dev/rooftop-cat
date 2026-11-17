extends RefCounted
## 캡처용 밟기 입력 찾기 (자동 테스트 아님, tools/qa_parade.gd가 씀): 끝없는 평지·고정 속도에서 장애물을 차례로 밟는 [점프, 슬라이딩] 입력을 찾는다.
## 장애물마다 기다림·누름 길이·더블점프 때를 훑어 처음 밟히는 것을 고르고(앞 입력은 그대로 다시 재생), 공중에서 장애물 위에 오면 내려찍기.
## 판이 같은 규칙(RunnerSim)이라 화면 판에서 같은 속도·같은 상대 자리로 재생하면 같은 장면이 된다.

const DT := 1.0 / 120.0


## layout = [[종류, 몸 가운데에서 앞 거리]...]
static func _sim(layout: Array, speed: float) -> RunnerSim:
	var sim := RunnerSim.new(1, speed, false)
	sim.accelerate = false
	sim.items.clear()
	sim.structures.clear()
	sim.roofs.clear()
	sim.roofs.append({"left": -1000.0, "right": 1.0e7, "top": 0.0})
	sim.set("_ground_roof", sim.roofs[0])
	sim.y = 0.0
	for i in layout.size():
		var info: Dictionary = Balance.OBSTACLES[layout[i][0]]
		var o := {"id": 800 + i, "kind": layout[i][0], "x": layout[i][1], "w": info.w, "y0": info.y0, "y1": info.y1, "base": 0.0}
		if o.kind == "flock":
			o.k = Balance.FLOCK_SPEED / speed
		sim.obstacles.append(o)
	return sim


## 공중에서 target 가운데 위에 왔으면 내려찍기
static func dive_now(sim: RunnerSim, target: Dictionary) -> bool:
	var to: float = RunnerSim.obstacle_left(target, sim.x) + target.w * 0.5 - sim.x
	var fall_t: float = maxf(0.0, sim.y - target.y1) / Balance.DIVE_SPEED
	return not sim.on_ground and sim.y > target.y1 + 5.0 and to < sim.vx() * fall_t + 20.0 and to > -30.0


static func plan(layout: Array, speed: float) -> Array:
	var inputs: Array = []
	for k in layout.size():
		var found := false
		for wait in range(0, 150, 3):
			for hold in [0.25, 0.15, 0.06]:
				for second in [-1, 20, 30, 40, 50, 60]:
					var cand := inputs.duplicate()
					for i in wait:
						cand.append([false, false])
					for i in int(hold / DT) + 1:
						cand.append([true, false])
					if second >= 0:
						for i in second:
							cand.append([false, false])
						for i in 20:
							cand.append([true, false])
					var r := _try(layout, speed, cand, k)
					if not r.is_empty():
						inputs = r
						found = true
						break
				if found:
					break
			if found:
				break
		if not found:
			push_error("밟기 입력 못 찾음: %s" % [layout[k]])
			return inputs
	for i in 240:
		inputs.append([false, false])
	return inputs


## cand 다음 내려찍기 규칙으로 k번째를 밟으면 그 step까지의 입력, 아니면 []
static func _try(layout: Array, speed: float, cand: Array, k: int) -> Array:
	var sim := _sim(layout, speed)
	var out: Array = []
	var target: Dictionary = sim.obstacles[k]
	for i in cand.size() + 300:
		var inp: Array = cand[i] if i < cand.size() else [false, dive_now(sim, target)]
		sim.step(DT, inp[0], inp[1])
		out.append(inp)
		if not sim.hit_obstacle.is_empty() or sim.game_over:
			return []
		for s in sim.stomped:
			if s.id == target.id:
				return out
			if s.id > target.id:
				return []  # 뒤 것을 먼저 밟음 (앞 것은 이미 찾은 입력으로 밟은 것)
	return []


## 확인용: 입력대로 했을 때 밟은 종류 순서
static func check(layout: Array, speed: float, inputs: Array) -> Array:
	var sim := _sim(layout, speed)
	var out := []
	for inp in inputs:
		sim.step(DT, inp[0], inp[1])
		for s in sim.stomped:
			out.append("%s x%d" % [s.kind, s.chain])
		if not sim.hit_obstacle.is_empty():
			out.append("맞음 " + sim.hit_obstacle.kind)
	return out
