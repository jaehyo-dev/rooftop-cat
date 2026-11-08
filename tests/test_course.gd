extends TestCase
## 구간 배치(CoursePlacer)와 장애물·하트 판정, 사람 기준 통과 검사 (PLAN 1·2·4·5번).

const Human := preload("res://tests/human_check.gd")


## 시드 하나로 옥상을 count개 만든다. stage_of(i)로 단계를 준다 (없으면 단계 stage 고정)
func _course(seed_value: int, stage: int, count: int) -> Array[Dictionary]:
	var placer := CoursePlacer.new(RoofGenerator.new(seed_value), seed_value)
	var roofs: Array[Dictionary] = [RoofGenerator.first_roof(-400.0)]
	for i in count:
		roofs.append(placer.next_roof(roofs[-1], Balance.SPEED_STAGES[stage - 1][1], stage))
	return roofs


func _sequence(roofs: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	var inside := false
	for roof in roofs:
		if roof.has("segment"):
			if not inside or ids[-1] != roof.segment:
				ids.append(roof.segment)
			inside = true
		else:
			inside = false
	return ids


func test_같은_시드면_같은_맵_다른_시드면_다른_맵() -> void:
	assert_eq(_course(5, 6, 200), _course(5, 6, 200))
	assert_true(_course(5, 6, 200) != _course(6, 6, 200))


func test_처음은_고정_대본_쉼은_일반_틈만() -> void:
	var roofs := _course(3, 1, 12)
	assert_eq(_sequence(roofs).slice(0, 5), Balance.SEGMENT_SCRIPT, "E1 E2 E3 E4 E2")
	for roof in roofs:
		assert_false(roof.has("tramp") or roof.get("platform", false), "대본 중에는 특수 틈이 없다")


func test_구간이_나오는_단계와_연속_금지와_높이_범위() -> void:
	for stage in range(1, 13):
		for seed_value in 4:
			var roofs := _course(seed_value, stage, 150)
			var seq := _sequence(roofs)
			for i in range(Balance.SEGMENT_SCRIPT.size(), seq.size()):
				assert_true(CourseData.SEGMENTS[seq[i]].min_stage <= stage, "단계 %d에 %s" % [stage, seq[i]])
				assert_true(seq[i] != seq[i - 1] or i == Balance.SEGMENT_SCRIPT.size(), "연속 %s" % seq[i])
			for i in range(1, roofs.size()):
				var roof := roofs[i]
				assert_true(roof.top >= Balance.ROOF_TOP_MIN and roof.top <= Balance.ROOF_TOP_MAX, "옥상 높이 %.0f" % roof.top)
				assert_true(absf(roof.top - roofs[i - 1].top) <= Balance.ROOF_TOP_STEP + 0.001, "높이 차")
				if roof.has("obs"):
					for o in roof.obs:
						if o.kind == "tank":
							assert_true(roof.top <= Balance.SEGMENT_TANK_TOP_MAX, "물탱크 구간 높이")


func test_섞임_표대로_어려운_구간이_늘고_특수_틈이_쉼_자리에서_나온다() -> void:
	var hard_low := 0
	var hard_high := 0
	var special := 0
	for seed_value in 6:
		for id in _sequence(_course(seed_value, 3, 200)):
			hard_low += 1 if CourseData.SEGMENTS[id].level == 2 else 0
		var high := _course(seed_value, 10, 200)
		for id in _sequence(high):
			hard_high += 1 if CourseData.SEGMENTS[id].level == 2 else 0
		for roof in high:
			if roof.has("tramp") or roof.get("platform", false):
				assert_false(roof.has("segment"), "특수 틈은 쉼 자리에서만")
				special += 1
	assert_eq(hard_low, 0, "단계 3에는 어려움 없음")
	assert_true(hard_high > 100, "단계 10은 어려움이 많음 (%d)" % hard_high)
	assert_true(special > 20, "쉼 자리에 특수 틈이 나옴 (%d)" % special)


func test_밀도는_입구_여유를_줄이지_않고_뒤만_줄인다() -> void:
	var loose := CoursePlacer.build("N3", 950.0, 1.0, 0.0, 200.0)[0]
	var tight := CoursePlacer.build("N3", 950.0, 0.65, 0.0, 200.0)[0]
	assert_eq(loose.obs[0].x, tight.obs[0].x, "첫 장애물 자리는 그대로")
	assert_true(tight.right < loose.right, "그 뒤 길이는 줄어듦")


func test_비둘기는_고양이_x의_함수라_어떤_속도로_와도_정한_자리에서_만난다() -> void:
	var o: Dictionary = CoursePlacer.build("E4", 500.0, 1.0, 0.0, 200.0)[0].obs[0]
	assert_eq(RunnerSim.obstacle_left(o, o.x), o.x, "고양이가 o.x에 오면 그 자리")
	assert_true(RunnerSim.obstacle_left(o, o.x - 500.0) > o.x, "오기 전에는 앞쪽")
	assert_true(absf(RunnerSim.obstacle_left(o, o.x - 500.0) - (o.x + Balance.FLOCK_SPEED)) < 0.001, "1초(500픽셀) 전이면 초당 120만큼 앞")
	assert_true(RunnerSim.flock_eta(o, o.x - 3000.0, 500.0, 940.0) > 1.0, "멀면 아직")
	assert_true(RunnerSim.flock_eta(o, o.x - 500.0, 500.0, 940.0) < 0.0, "이미 화면 안")


func test_판정_상자는_설계_수치() -> void:
	assert_eq(Balance.OBSTACLES.pot.w, 48.0)
	assert_eq(Balance.OBSTACLES.pot.y1, 38.0)
	assert_eq(Balance.OBSTACLES.ac.w, 110.0)
	assert_eq(Balance.OBSTACLES.ac.y1, 88.0)
	assert_eq(Balance.OBSTACLES.tank.w, 84.0)
	assert_eq(Balance.OBSTACLES.tank.y1, 285.0)
	assert_eq(Balance.OBSTACLES.flock.w, 150.0)
	assert_eq(Balance.OBSTACLES.flock.y0, 240.0)
	assert_eq(Balance.OBSTACLES.flock.y1, 310.0)
	var o := {"x": 0.0, "w": 150.0, "y0": 240.0, "y1": 310.0, "k": 0.1}
	assert_false(RunnerSim.body_hits(o, 0.0, 0.0), "달리기만 하면 비둘기에 안 맞음")
	assert_false(RunnerSim.body_hits(o, 0.0, 137.0), "톡(100ms) 꼭대기에서도 안 맞음")
	assert_true(RunnerSim.body_hits(o, 0.0, 250.0), "크게 뛰면 맞음")


## 고양이 앞에 장애물 하나를 둔 sim
func _sim_with(kind: String, at: float) -> RunnerSim:
	var sim := RunnerSim.new(1, Balance.RUN_SPEED, false)
	sim.accelerate = false
	sim.roofs[0].right = 90000.0
	var info: Dictionary = Balance.OBSTACLES[kind]
	var top: float = sim.roofs[0].top
	sim.obstacles = [{"id": 0, "kind": kind, "x": at, "w": info.w, "y0": top + info.y0, "y1": top + info.y1, "base": top}] as Array[Dictionary]
	return sim


func test_부딪히면_하트가_줄고_무적이_되며_속도는_그대로() -> void:
	var sim := _sim_with("ac", 200.0)
	var v := sim.vx()
	while sim.hearts == Balance.HEARTS_MAX and sim.x < 400.0:
		sim.step(1.0 / 120.0, false)
	assert_eq(sim.hearts, 2, "하트 -1")
	assert_eq(sim.hit_obstacle.kind, "ac", "이번 step에 맞은 것")
	assert_true(sim.obstacles.is_empty(), "맞은 장애물은 사라짐")
	assert_true(absf(sim.invuln_time - Balance.INVULN_TIME) < 0.02, "무적 1.5초")
	assert_eq(sim.ghost_time, 0.0, "투명화와 따로")
	assert_eq(sim.vx(), v, "속도 그대로")
	sim.step(1.0 / 120.0, true)
	assert_true(sim.jumped, "무적 중에도 점프")
	for i in 15:
		sim.step(1.0 / 120.0, false)
	sim.step(1.0 / 120.0, true)
	assert_true(sim.double_jumped, "무적 중에도 더블점프 (ghost_time이면 막혔을 것)")


func test_무적이나_투명화나_구제_중에는_맞지_않는다() -> void:
	for state in ["invuln", "ghost", "rescue"]:
		var sim := _sim_with("ac", 200.0)
		if state == "invuln":
			sim.invuln_time = 5.0
		elif state == "ghost":
			sim.ghost_time = 5.0
		else:
			sim.rescuing = true
		sim.x = 200.0
		sim.step(1.0 / 120.0, false)
		assert_eq(sim.hearts, Balance.HEARTS_MAX, state)


func test_하트_0이면_끝_떨어지면_하트와_상관없이_끝() -> void:
	var sim := _sim_with("ac", 200.0)
	sim.hearts = 1
	sim.x = 200.0
	sim.step(1.0 / 120.0, false)
	assert_true(sim.game_over, "하트 0")
	assert_eq(sim.end_reason, "hearts")
	assert_false(sim.fell, "떨어진 것이 아님")
	var falling := _sim_with("pot", 80000.0)
	falling.roofs[0].right = 10.0
	falling.roofs.resize(1)
	falling.roofs.append({"left": 90000.0, "right": 99000.0, "top": 200.0})
	for i in 2000:
		falling.step(1.0 / 120.0, false)
	assert_true(falling.game_over, "떨어져서 끝")
	assert_eq(falling.end_reason, "fall")
	assert_eq(falling.hearts, Balance.HEARTS_MAX, "하트는 그대로")


func test_벽_투명화는_하트를_잃지_않는다() -> void:
	var sim := RunnerSim.new(1, Balance.RUN_SPEED, false)
	sim.accelerate = false
	var top: float = sim.roofs[0].top
	sim.roofs.resize(1)
	sim.roofs[0].right = 300.0
	sim.roofs.append({"left": 300.0, "right": 90000.0, "top": top + 60.0})
	var ghosted := false
	for i in 200:
		sim.step(1.0 / 120.0, false)
		ghosted = ghosted or sim.ghosted
	assert_true(ghosted, "벽에 닿아 투명화")
	assert_eq(sim.hearts, Balance.HEARTS_MAX)


func test_하트_그림과_소품_규칙과_안내() -> void:
	var view: GDScript = load("res://scripts/world_view.gd")
	assert_eq(view.heart_frame(0, 3, 99.0), "full")
	assert_eq(view.heart_frame(2, 2, 0.1), "crack", "오른쪽부터 금 감")
	assert_eq(view.heart_frame(2, 2, 0.5), "empty", "0.35초 뒤 빈 하트")
	assert_eq(view.heart_frame(1, 2, 0.1), "full")
	assert_eq(view.heart_frame(2, 0, 0.1), "empty", "마지막으로 잃은 자리만 금 감")
	assert_eq(view.heart_frame(0, 0, 0.1), "crack")
	for kind in ["plants", "aircon", "tank"]:
		assert_false(BuildingLayout.PROP_WEIGHTS.has(kind), kind + " 소품은 옥상 위에 안 나옴")
	assert_eq(BuildingArt.PROP_SCALE, 0.8)
	assert_eq(BuildingArt.PROP_ALPHA, 0.6)
	assert_eq(view.OBSTACLE_HINTS, {"pot": "뛰어!", "ac": "길게!", "tank": "두 번!", "flock": "그대로!"})


func test_화면은_장애물을_알리고_처음_만날_때만_안내한다() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://test_course_scene.cfg"
	add_child(main)
	var world: Node2D = main.get_node("World")
	await wait_frames(1)
	world.set_process(false)
	var sim: RunnerSim = world.sim
	var pot: Dictionary = {"id": 900, "kind": "pot", "x": sim.x + 400.0, "w": 48.0, "y0": 0.0, "y1": 38.0, "base": 0.0}
	sim.obstacles = [pot, pot.duplicate()] as Array[Dictionary]
	sim.obstacles[1].id = 901
	world._update_obstacle_signs(0.01)
	assert_true(world._alerts.has(900) and world._alerts.has(901), "화면에 들어오면 !")
	assert_eq(world._hint.text, "뛰어!", "처음 만난 종류 안내")
	world._hint = {}
	sim.obstacles[0].id = 902
	world._update_obstacle_signs(0.01)
	assert_true(world._hint.is_empty(), "같은 종류는 이번 판에 다시 안내하지 않음")
	var flock: Dictionary = {"id": 903, "kind": "flock", "x": sim.x + 1000.0, "w": 150.0, "y0": 240.0, "y1": 310.0, "base": 0.0, "k": 0.25}
	sim.obstacles = [flock] as Array[Dictionary]
	world._update_obstacle_signs(0.01)
	assert_true(world._cooed.has(903), "1초 전 구구 소리")
	world.restart()
	assert_true(world._alerts.is_empty() and world._hinted.is_empty() and world._cooed.is_empty(), "새 판은 처음부터")
	assert_eq(world.sim.hearts, Balance.HEARTS_MAX, "새 판 하트 3개")
	main.queue_free()
	await wait_frames(1)
	DirAccess.remove_absolute("user://test_course_scene.cfg")


func test_검사기_자체_검사() -> void:
	var human := Human.new()
	var plain := func(left: float, right: float) -> Dictionary: return {"left": left, "right": right, "top": 200.0}
	var far: float = 2.4 * JumpModel.max_reach(430.0, 0.0)
	human.setup_world([plain.call(0.0, 860.0), plain.call(860.0 + far, 12000.0)] as Array[Dictionary], [] as Array[Dictionary], 430.0)
	assert_false(human.walk(0.6), "더블로도 못 건너는 틈은 못 건넌다고 답해야 함")
	var near: float = 1.2 * JumpModel.max_reach(430.0, 0.0)
	human.setup_world([plain.call(0.0, 860.0), plain.call(860.0 + near, 12000.0)] as Array[Dictionary], [] as Array[Dictionary], 430.0)
	assert_true(human.walk(0.6), "더블로 건너는 틈은 통과: " + human.why)
	assert_eq(human.actions, ["더블"] as Array[String], "한 번 점프로는 못 건넘")
	var tank := {"id": 0, "kind": "tank", "x": 1140.0, "w": 84.0, "y0": 200.0, "y1": 485.0, "base": 200.0}
	human.setup_world([plain.call(0.0, 2200.0), plain.call(2300.0, 12000.0)] as Array[Dictionary], [tank] as Array[Dictionary], 570.0)
	assert_true(human.walk(0.6), "물탱크 통과: " + human.why)
	assert_eq(human.actions[0], "더블", "물탱크 정답은 더블")


func test_구간은_모든_단계에서_사람이_통과한다() -> void:
	var human := Human.new()
	var fails: Array[String] = []
	var used := {}
	for id: String in CourseData.SEGMENTS:
		var seg: Dictionary = CourseData.SEGMENTS[id]
		for stage in range(seg.min_stage, Balance.SPEED_STAGES.size() + 1):
			var row: Array = Balance.SPEED_STAGES[stage - 1]
			for depth in [0.3, 0.6, 0.87]:
				human.setup_segment(id, row[1], row[2], "plain")
				if not human.walk(depth):
					fails.append("%s 단계 %d 깊이 %.2f: %s" % [id, stage, depth, human.why])
				for action in human.actions:
					used[action] = true
			# 쉼 자리의 트램펄린·전봇대가 구간 바로 뒤에 나온 경우
			for tail in ["tramp", "pole"]:
				human.setup_segment(id, row[1], row[2], tail)
				if not human.walk(0.6):
					fails.append("%s + %s 단계 %d: %s" % [id, tail, stage, human.why])
				for action in human.actions:
					used[action] = true
			# 만든 뒤 단계가 오른 경우: 다음 단계 속도로 달린다
			if stage < 12 and Balance.SPEED_STAGES[stage][1] > row[1]:
				human.setup_segment(id, row[1], row[2], "plain", Balance.SPEED_STAGES[stage][1])
				if not human.walk(0.6):
					fails.append("%s 만든 단계 %d, 달리는 단계 %d: %s" % [id, stage, stage + 1, human.why])
	for fail in fails:
		print("    막힘: ", fail)
	assert_eq(fails.size(), 0, "막힌 조합")
	for action in ["톡", "더블", "트램펄린"]:
		assert_true(used.has(action), "%s 경로를 실제로 검사함" % action)
