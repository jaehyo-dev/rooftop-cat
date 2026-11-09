extends TestCase
## 구간 배치(CoursePlacer)와 장애물·하트 판정, 사람 기준 통과 검사 (PLAN 1·2·4·5번).

const Human := preload("res://tests/human_check.gd")
const BalanceBot := preload("res://tests/balance_bot.gd")


## 시드 하나로 옥상을 count개 만든다 (단계 stage 고정)
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
	var roofs := _course(3, 1, 8)  # 대본 구간까지만 (뒤 쉼 자리부터는 특수 틈이 나올 수 있음)
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


func test_구간이_있어도_상자가_드물어지지_않는다() -> void:
	# 실수 없는 봇으로 4분 달리며 나온 상자를 센다 (상자 간격은 시간 기준)
	for seed_value in 3:
		var inputs: Array = []
		BalanceBot.play_stats({"timing": 0.0, "short_hold": 0.0}, seed_value + 1, 240.0, Balance.RUN_SPEED, true, inputs)
		var sim := RunnerSim.new(seed_value + 1)
		var boxes := {}
		for pressed in inputs:
			sim.step(1.0 / 120.0, pressed)
			for item in sim.items:
				if item.kind == "box":
					boxes[item.x] = true
		assert_true(boxes.size() >= 1, "시드 %d: 4분에 상자 1개 이상 (%d개)" % [seed_value + 1, boxes.size()])


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
	assert_eq(Balance.OBSTACLES.tank.y1, 260.0)
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
	var view: GDScript = load("res://scripts/world_view.gd")
	assert_true(view.alert_showing(pot, sim.x, world._alerts), "들어온 뒤 계속 보임")
	assert_true(view.alert_showing(pot, sim.x + 30.0, world._alerts), "시간이 지나도(달려도) 보임")
	assert_true(view.alert_showing(pot, pot.x + pot.w + 70.0, world._alerts), "몸 뒤쪽이 지나기 전까지")
	assert_false(view.alert_showing(pot, pot.x + pot.w + 80.0, world._alerts), "다 지나면 사라짐")
	assert_false(view.alert_showing({"id": 999, "kind": "pot", "x": sim.x + 400.0, "w": 48.0}, sim.x, world._alerts), "화면에 안 들어온 것은 없음")
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


func test_물탱크는_어떤_속도에서도_한_번_점프로_못_넘고_더블은_황금에_닿는다() -> void:
	var human := Human.new()
	var hold := JumpModel.max_hold_time()
	var apex := hold + JumpModel.jump_speed() / Balance.GRAVITY
	for row: Array in Balance.SPEED_STAGES:
		var v: float = row[1]
		var world: Array[Dictionary] = CoursePlacer.build("N3", v, row[2], 0.0, 200.0)
		world[0].right += 9000.0
		human.setup_world(world, world[0].obs, v)
		var left: float = human.obstacles[0].x
		var gold := 0
		for i in 240:
			var press_x := left - i / 120.0 * v
			var land := human._flight(press_x, world[0], hold, -1.0)
			assert_true(land.is_empty() or land.x < left + 40.0, "속도 %d: 한 번 점프로 넘음 (%.0f)" % [v, press_x])
			# 더블로 넘으면 위 황금 생선을 먹는 누름이 있어야 한다
			human.sim.fish = 0
			human._place(press_x, world[0])
			var road := FishRoad.new()
			human.sim.items = road.extend({"left": -3000.0, "right": -200.0, "top": 200.0}, world[0], [v])
			for k in 480:
				var t := k / 60.0
				human.sim.step(1.0 / 60.0, t < hold or (t >= apex and t < apex + JumpModel.double_max_hold()))
				if human.sim.on_ground and t > 0.1:
					break
			gold = maxi(gold, 1 if human.sim.items.filter(func(it: Dictionary) -> bool: return it.kind == "gold").is_empty() else 0)
		assert_eq(gold, 1, "속도 %d: 더블점프로 황금을 먹는 누름이 있다" % v)


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
	var tank := {"id": 0, "kind": "tank", "x": 1140.0, "w": 84.0, "y0": 200.0, "y1": 460.0, "base": 200.0}
	human.setup_world([plain.call(0.0, 2200.0), plain.call(2300.0, 12000.0)] as Array[Dictionary], [tank] as Array[Dictionary], 570.0)
	assert_true(human.walk(0.6), "물탱크 통과: " + human.why)
	assert_eq(human.actions[0], "더블", "물탱크 정답은 더블")


func test_구간은_16개_이상이고_모두_생선_길이_있다() -> void:
	assert_true(CourseData.SEGMENTS.size() >= 16, "구간 %d개" % CourseData.SEGMENTS.size())
	var human := Human.new()
	for id: String in CourseData.SEGMENTS:
		var row: Array = Balance.SPEED_STAGES[CourseData.SEGMENTS[id].min_stage - 1]
		human.setup_road(id, row[1], row[2], [row[1]])
		var fish := human.road_items.filter(func(it: Dictionary) -> bool: return it.kind == "fish")
		assert_true(fish.size() >= 8, "%s: 생선 %d마리" % [id, fish.size()])
		for i in range(1, fish.size()):
			assert_true(fish[i].x - fish[i - 1].x <= Balance.FISH_SPACING * 3.0 or fish[i].y != fish[i - 1].y, "%s: 촘촘함 (%.0f → %.0f)" % [id, fish[i - 1].x, fish[i].x])


func test_생선_길대로_뛰면_사람_흔들림에도_필수를_다_먹고_콤보가_안_끊긴다() -> void:
	var human := Human.new()
	var fails: Array[String] = []
	var total := 0
	var bonus := 0
	for id: String in CourseData.SEGMENTS:
		var seg: Dictionary = CourseData.SEGMENTS[id]
		for stage in range(seg.min_stage, Balance.SPEED_STAGES.size() + 1):
			var row: Array = Balance.SPEED_STAGES[stage - 1]
			var next: float = Balance.SPEED_STAGES[mini(stage, Balance.SPEED_STAGES.size() - 1)][1]
			# 도착 속도를 맞게 예측한 경우 (만든 단계와 달리는 단계가 다른 경우 포함)
			for run_v: float in ([row[1], next] if next != row[1] else [row[1]]):
				human.setup_road(id, row[1], row[2], [run_v])
				for fish in human.road_items:
					total += 1
					bonus += 1 if fish.has("bonus") else 0
				for c: Array in [[0.0, 0, 0.87], [-0.05, 0, 0.87], [0.05, 0, 0.87], [0.0, 1, 0.87], [0.0, 0, 0.3]]:
					var r := human.walk_road(c[0], c[1], c[2])
					if r.hit != "" or not r.missed.is_empty() or r.cut:
						fails.append("%s 단계 %d 속도 %d 어긋남 %+.0fms 변형 %d 깊이 %.2f: %s 못 먹음 %d/%d 끊김 %s" % [id, stage, run_v, c[0] * 1000.0, c[1], c[2], r.hit, r.missed.size(), r.required, r.cut])
			# 구간을 지나는 동안 단계가 올라 속도가 바뀌는 경우: 흔들림에 두 속도를 넣어 필수를 정했으니 어느 쪽으로 달려도 다 먹는다
			if next != row[1]:
				human.setup_road(id, row[1], row[2], [row[1], next])
				human.run_speed = next
				var r := human.walk_road(0.0, 0, 0.87)
				if r.hit == "" and not r.missed.is_empty():
					fails.append("%s 단계 %d 도중 빨라짐: 못 먹음 %d/%d" % [id, stage, r.missed.size(), r.required])
	for fail in fails.slice(0, 40):
		print("    ", fail)
	assert_eq(fails.size(), 0, "길대로 뛰어도 실패한 조합 (전체 %d, 보너스 비율 %.0f%%)" % [fails.size(), 100.0 * bonus / total])
	assert_true(bonus < total * 0.4, "보너스가 너무 많으면 놓침이 의미 없음 (%d/%d)" % [bonus, total])


func test_틀린_동작이면_필수를_놓친다() -> void:
	var human := Human.new()
	for id: String in CourseData.SEGMENTS:
		var seg: Dictionary = CourseData.SEGMENTS[id]
		for stage in range(seg.min_stage, Balance.SPEED_STAGES.size() + 1):
			var row: Array = Balance.SPEED_STAGES[stage - 1]
			human.setup_road(id, row[1], row[2], [row[1]])
			if human.road_flights.size() >= 2:  # 틈 호만 있는 구간도 뛰지 않으면 떨어진다
				var r := human.walk_road(0.0, 0, 0.87, false)
				assert_true(r.hit != "" or not r.missed.is_empty(), "%s 단계 %d: 안 뛰어도 다 먹음" % [id, stage])
	# 호에서 크게 어긋나게 뛰면 맞거나 생선을 놓친다
	for c: Array in [["E1", 430.0, 0.3], ["E1", 430.0, -0.3], ["N3", 570.0, 0.25], ["E3", 500.0, -0.3]]:
		human.setup_road(c[0], c[1], 1.0, [c[1]])
		var r := human.walk_road(c[2], 0, 0.3)
		assert_true(r.hit != "" or not r.missed.is_empty(), "%s %+.0fms: 다 먹음" % [c[0], c[2] * 1000.0])


func test_생선_길_궤적은_실제_점프와_같다() -> void:
	for action in FishRoad.AUTO_ACTIONS:
		for variant: Array in FishRoad.variants(action):
			var sim := RunnerSim.new(1, 430.0, false)
			sim.accelerate = false
			sim.roofs[0].right = 90000.0
			var route := FishRoad.path(variant[0], variant[1])
			var top: float = sim.roofs[0].top
			var hold_end: float = variant[1] + JumpModel.double_max_hold()
			for i in route.size() - 1:
				var t := i / 60.0
				sim.step(1.0 / 60.0, t < variant[0] or (variant[1] >= 0.0 and t >= variant[1] and t < hold_end))
				assert_true(absf(sim.y - top - route[i].y) < 12.0, "%s %.2f초: 궤적 %.1f, 실제 %.1f" % [action, t, route[i].y, sim.y - top])


func test_쉼_옥상의_생선_길도_따라_달리면_콤보가_안_끊긴다() -> void:
	for v in [430.0, 640.0, 950.0]:
		for seed_value in 3:
			var sim := RunnerSim.new(seed_value + 1, v, false)
			sim.accelerate = false
			sim.get("_generator").special_chance = 0.0
			sim.roofs.resize(1)
			sim.items.clear()
			sim.road = FishRoad.new()
			var next := 0
			var since := INF
			var f := {}
			while sim.elapsed < 40.0 and not sim.game_over:
				if next < sim.road.flights.size() and sim.x >= sim.road.flights[next].press_x:
					f = sim.road.flights[next]
					next += 1
					since = 0.0
				var pressed: bool = not f.is_empty() and (since < f.hold or (f.double_at >= 0.0 and since >= f.double_at and since < f.double_at + JumpModel.double_max_hold()))
				since += 1.0 / 60.0
				sim.step(1.0 / 60.0, pressed)
			assert_false(sim.game_over, "속도 %d 시드 %d: 길대로 뛰면 안 떨어짐" % [v, seed_value])
			assert_true(sim.combo.best >= 50 * v / 430.0, "속도 %d 시드 %d: 콤보가 쌓임 (%d, 지금 %d)" % [v, seed_value, sim.combo.best, sim.combo.count])
			assert_eq(sim.combo.count, sim.combo.best, "속도 %d 시드 %d: 안 끊김" % [v, seed_value])


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
