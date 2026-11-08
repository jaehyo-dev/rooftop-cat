extends RefCounted
## 사람 기준 통과 검사 (PLAN 맨 앞 "통과"의 뜻, 4번 3~5): 진짜 RunnerSim으로 구간을 위험마다 차례로 넘는다.
## 위험마다 누름 창 100ms 이상(가운데서 ±50ms 흔들려도 통과), 누름 길이가 흔들려도, 착지 깊이가 달라도, 판정을 8픽셀 넓혀도 통과해야 한다.
## 벽에 닿아 투명화로 구제되는 길은 인정하지 않는다. 트램펄린은 닿는 때 ±50ms 누름, 전봇대는 판을 거쳐 건넌다.

const DT := 1.0 / 60.0
const GROW := 8.0            # 장애물 판정을 이만큼 넓혀 본다
const WINDOW_POINTS := 4     # 1/30초 간격 4점 = 100ms
const SCAN_RATE := 30.0
const MAX_LOOK := 1.4        # 위험 앞 이 시간 안에서 누를 때를 찾는다
const TRAMP_PRESS_CENTER := -0.015  # 트램펄린 누름 창(-0.18~+0.15)의 가운데

var sim: RunnerSim
var roofs: Array[Dictionary] = []
var obstacles: Array[Dictionary] = []
var structures: Array[Dictionary] = []
var run_speed := 0.0
## 찾은 동작 이름들 (톡, 중간, 길게, 더블, 트램펄린)
var actions: Array[String] = []
var why := ""


## 쉬운 동작부터: [이름, [[누름 길이, 더블 누르는 시각(없으면 -1)], ...]]. 흔들린 경우 전부 통과해야 한다
static func action_list() -> Array:
	var hold := JumpModel.max_hold_time()
	var apex := hold + JumpModel.jump_speed() / Balance.GRAVITY
	return [["톡", [[0.05, -1.0], [0.10, -1.0]]], ["중간", [[0.13, -1.0], [0.18, -1.0]]], ["길게", [[hold, -1.0]]], ["더블", [[hold, apex - 0.05], [hold, apex + 0.05]]]]


## 구간 id를 속도 v·밀도 density로 펴고 뒤에 tail("plain", "tramp", "pole")을 붙인 세계
func setup_segment(id: String, v: float, density: float, tail: String, speed_when_run: float = 0.0) -> void:
	var made := CoursePlacer.build(id, v, density, 0.0, 170.0)  # 오르막까지 트램펄린을 놓을 수 있는 높이 (TRAMP_TOP_MAX)
	var prev: Dictionary = made[-1]
	var generator := RoofGenerator.new(1)
	var base := {"left": prev.right, "right": prev.right + 800.0, "top": prev.top}
	var after: Array[Dictionary] = []
	if tail == "tramp":
		after.append(generator._tramp_roof(prev, base, v, 1.0))
	elif tail == "pole":
		after.append(generator._pole_roofs(prev, base, v, 1.0))
		after.append(generator.next_roof(after[0], v))
	else:
		var rise := minf(Balance.ROOF_TOP_STEP, Balance.ROOF_TOP_MAX - prev.top)
		after.append({"left": prev.right + RoofGenerator.max_gap(v, rise), "right": 0.0, "top": prev.top + rise})
	after[-1].right = after[-1].left + 8000.0  # 끝까지 왔다는 표시 겸 런아웃: 생성기가 더 만들지 않게 길게
	var list: Array[Dictionary] = []
	list.append_array(made)
	list.append_array(after)
	var obs: Array[Dictionary] = []
	for roof in made:
		obs.append_array(roof.obs)
	setup_world(list, obs, speed_when_run if speed_when_run > 0.0 else v)


## 직접 만든 세계 (마지막 옥상에 내려서면 통과). 장애물 상자는 GROW만큼 넓혀 둔다
func setup_world(world: Array[Dictionary], obs: Array[Dictionary], v: float) -> void:
	roofs = world
	run_speed = v
	structures = []
	for roof in world:
		if roof.has("tramp"):
			structures.append(roof.tramp)
	obstacles = []
	for o in obs:
		var wide := o.duplicate()
		wide.x -= GROW
		wide.w += 2.0 * GROW
		wide.y0 -= GROW
		wide.y1 += GROW
		obstacles.append(wide)
	if sim == null:
		sim = RunnerSim.new(1, v, false)


## 첫 옥상 왼쪽에서 depth초 들어간 곳에 내려앉았다고 치고 끝까지 간다. 막히면 false, 이유는 why
func walk(depth: float) -> bool:
	actions = []
	why = ""
	var roof: Dictionary = roofs[0]
	var x: float = roof.left + depth * run_speed
	for _i in 16:
		if is_same(roof, roofs[-1]):
			return true
		var hazard := _run_free(x, roof)
		if hazard.kind == "done":
			return true
		var landed: Dictionary = _pass_tramp(x, roof, hazard) if hazard.kind == "tramp" else _pass_hazard(x, roof, hazard)
		if landed.is_empty():
			return false
		x = landed.x
		roof = landed.roof
	why = "위험이 너무 많음"
	return false


## x에서 누르지 않고 달려 첫 위험을 찾는다 {"kind": hit/wall/edge/tramp/done, "x", "clear": 넘어서 내려설 x, "t": 닿기까지 시간}
func _run_free(x: float, roof: Dictionary) -> Dictionary:
	_place(x, roof)
	var t := 0.0
	while t < 30.0:
		sim.step(DT, false)
		t += DT
		if not sim.hit_obstacle.is_empty():
			var o := sim.hit_obstacle
			return {"kind": "hit", "x": sim.x, "clear": RunnerSim.obstacle_left(o, sim.x) + o.w + Balance.CAT_BODY_SIZE.x * 0.5 * Balance.OBSTACLE_HIT_SCALE}
		if sim.is_riding() or sim.bounced:
			return {"kind": "tramp", "x": sim.x, "t": t}
		if sim.ghosted:
			return {"kind": "wall", "x": sim.x, "clear": sim.x}
		if not sim.on_ground:
			return {"kind": "edge", "x": sim.x, "clear": roof.right}
	return {"kind": "done"}


## 쉬운 동작부터 100ms 이상 연속으로 통과하는 누를 때를 찾아 그 가운데로 뛴다. 내려선 {"x", "roof"}, 못 찾으면 빈 Dictionary
func _pass_hazard(x: float, roof: Dictionary, hazard: Dictionary) -> Dictionary:
	var count := int(minf((hazard.x - x) / run_speed, MAX_LOOK) * SCAN_RATE)
	for action: Array in action_list():
		var streak := 0
		for k in count + 2:  # 마지막 칸은 창을 닫는 자리
			var ok := k <= count
			var press_x: float = hazard.x - k / SCAN_RATE * run_speed
			if ok:
				for variant: Array in action[1]:
					var land := _flight(press_x, roof, variant[0], variant[1])
					if land.is_empty() or land.x <= hazard.clear or (hazard.kind == "edge" and is_same(land.roof, roof)):
						ok = false
						break
			if ok:
				streak += 1
			elif streak >= WINDOW_POINTS:
				# 창 가운데로 뛴다 (사람은 끝자리를 노리지 않는다: 판 가운데에 내려서 다음 뜀에 여유가 있다)
				var middle: float = hazard.x - (k - 1 - (streak - 1) * 0.5) / SCAN_RATE * run_speed
				var variants: Array = action[1]
				var center: Array = variants[0]
				if variants.size() == 2:
					center = [(variants[0][0] + variants[1][0]) * 0.5, (variants[0][1] + variants[1][1]) * 0.5 if variants[0][1] >= 0.0 else -1.0]
				var land := _flight(middle, roof, center[0], center[1])
				if not land.is_empty():
					actions.append(action[0])
					return land
				why = "x=%.0f %s: 가운데 입력 실패" % [hazard.x, action[0]]
				return {}
			else:
				streak = 0
	why = "%s x=%.0f: 100ms 창 없음" % [hazard.kind, hazard.x]
	return {}


## press_x에서 hold초 누른 점프 (double_at >= 0이면 그때 더블점프 최대). 맞거나 벽·떨어짐·트램펄린에 실리면 빈 Dictionary
func _flight(press_x: float, roof: Dictionary, hold: float, double_at: float) -> Dictionary:
	_place(press_x, roof)
	var double_end := double_at + JumpModel.double_max_hold()
	var t := 0.0
	while t < 6.0:
		sim.step(DT, t < hold or (double_at >= 0.0 and t >= double_at and t < double_end))
		t += DT
		if sim.hearts < Balance.HEARTS_MAX or sim.ghosted or sim.game_over or sim.is_riding() or sim.bounced:
			return {}
		if sim.landed:
			return {"x": sim.x, "roof": sim.get("_ground_roof")}
	return {}


## 트램펄린: 닿는 때 기준 누름 창 가운데 ±50ms 모두 다음 옥상에 내려서야 한다
func _pass_tramp(x: float, roof: Dictionary, hazard: Dictionary) -> Dictionary:
	var land := {}
	for offset in [TRAMP_PRESS_CENTER - 0.05, TRAMP_PRESS_CENTER + 0.05, TRAMP_PRESS_CENTER]:
		land = {}
		_place(x, roof)
		var press_at: float = hazard.t + offset
		var t := 0.0
		while t < 8.0:
			sim.step(DT, t >= press_at and t < press_at + 0.07)
			t += DT
			if sim.game_over or sim.hearts < Balance.HEARTS_MAX or sim.ghosted:
				break
			if sim.landed and not is_same(sim.get("_ground_roof"), roof):
				land = {"x": sim.x, "roof": sim.get("_ground_roof")}
				break
		if land.is_empty():
			why = "트램펄린 x=%.0f: 닿는 때 %+.0fms 누름 실패" % [hazard.x, offset * 1000.0]
			return {}
	actions.append("트램펄린")
	return land


## 고양이를 옥상 위 x에 세워 처음부터 다시 (같은 RunnerSim을 다시 써서 빠르게)
func _place(x: float, roof: Dictionary) -> void:
	sim.accelerate = false
	sim.speed = run_speed
	sim.roofs = roofs.duplicate()
	sim.obstacles = obstacles.duplicate()
	sim.structures = structures.duplicate()
	sim.items.clear()
	sim.x = x
	sim.y = roof.top
	sim.vy = 0.0
	sim.on_ground = true
	sim.game_over = false
	sim.hearts = Balance.HEARTS_MAX
	sim.invuln_time = 0.0
	sim.ghost_time = 0.0
	sim.rescuing = false
	sim.has_box = false
	sim._ground_roof = roof
	sim._ghost_roof = {}
	sim._was_pressed = false
	sim._jumped = false
	sim._holding = false
	sim._hold_time = 0.0
	sim._double_used = false
	sim._floating = false
	sim._press_age = 99.0
	sim._held_top = NAN
	sim._ride_line = {}
	sim._ride_time = 0.0
	sim._slack_line = {}
	sim._launch_vx = 0.0
	sim._buffer = 0.0
	sim._coyote = 0.0
