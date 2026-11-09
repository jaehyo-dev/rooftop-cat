extends TestCase
## 아이템 6종: 질주(전용 분기·착지 옥상), 털실, 황금 생선, 쿠키, 통조림, 방울, 아이템 자리 고르기, 화면 연출 (PLAN 3번·12번).

const DT := 1.0 / 120.0


## 고양이 바로 앞에 아이템을 놓은 sim
func _sim(kind: String, seed_value: int = 1, v: float = Balance.RUN_SPEED, use_course: bool = false) -> RunnerSim:
	var sim := RunnerSim.new(seed_value, v, use_course)
	sim.accelerate = false
	sim.items.clear()
	if not kind.is_empty():
		sim.items.append({"kind": kind, "x": sim.x + 80.0, "y": sim.y + Balance.ITEM_LIFT})
	return sim


func _pot(sim: RunnerSim, at: float, id: int = 0) -> Dictionary:
	var top: float = sim.roofs[0].top
	var o := {"id": id, "kind": "pot", "x": at, "w": 48.0, "y0": top, "y1": top + 38.0, "base": top}
	sim.obstacles.append(o)
	return o


## 질주가 끝날 때까지 돌린다. 끝난 step에서 멈춤. 이상한 일은 check가 잡는다
func _run_dash(sim: RunnerSim, check: Callable = func() -> void: pass) -> float:
	var t := 0.0
	while not sim.dash_started and t < 2.0:
		sim.step(DT, false)
		t += DT
	assert_true(sim.dashing, "질주 시작")
	var begun := sim.elapsed
	while sim.dashing and t < 30.0:
		sim.step(DT, int(t * 7.0) % 2 == 0)  # 눌러도 상관없어야 함
		t += DT
		check.call()
	assert_true(sim.dash_ended, "질주가 끝남")
	return sim.elapsed - begun


func test_질주_끝에_빈_곳에_내려놓는_일이_없다() -> void:
	var count := 0
	for seed_value in 40:
		for v in [430.0, 640.0, 850.0, 950.0]:
			var sim := _sim("dash", seed_value + 1, v, true)
			sim.x = 300.0  # 구간이 만들어진 뒤
			sim.items[0].x = 380.0
			sim.items[0].y = sim.y + Balance.ITEM_LIFT
			var seconds := _run_dash(sim, func() -> void:
				# 발밑에 옥상이 있으면 그 위 (벽 속에 묻히지 않음)
				var under := sim.roof_at(sim.x)
				if not under.is_empty() and not under.get("platform", false):
					assert_true(sim.y >= under.top - 0.01, "시드 %d 속도 %d: 옥상 속에 묻힘 (%.1f < %.1f)" % [seed_value, v, sim.y, under.top]))
			var roof: Dictionary = sim.get("_ground_roof")
			assert_true(sim.on_ground and sim.landed and is_equal_approx(sim.y, roof.top), "옥상 위에 내려섬")
			assert_true(sim.x + Balance.CAT_FOOT_HALF >= roof.left and sim.x - Balance.CAT_FOOT_HALF <= roof.right, "발이 옥상 위")
			assert_true(roof.right - sim.x >= v * 0.5, "남은 옥상이 충분히 넓음 (%.0f)" % (roof.right - sim.x))
			assert_true(seconds >= Balance.DASH_TIME, "4초는 달림 (%.1f)" % seconds)
			for o in sim.obstacles:
				assert_false(o.x >= roof.left and o.x <= roof.right, "착지 옥상에는 장애물 없음")
			assert_true(absf(sim.invuln_time - Balance.DASH_END_INVULN) < 0.02, "끝나면 1초 무적")
			count += 1
			# 그대로 달려 무적이 끝날 때까지 떨어지지 않고 속도가 돌아온다
			var dash_vx := sim.vx()
			for i in 121:
				sim.step(DT, false)
			assert_false(sim.game_over, "내려선 뒤 1초 안전")
			assert_eq(sim.hearts, Balance.HEARTS_MAX)
			assert_true(sim.vx() <= v + 0.01 and sim.vx() < dash_vx, "속도가 돌아옴")
	assert_eq(count, 160)


func test_질주_중에도_점프와_더블점프가_되고_발판_아래로_안_떨어진다() -> void:
	var sim := _sim("dash", 2, 640.0, true)
	while not sim.dashing:
		sim.step(DT, false)
	sim.step(DT, false)
	var y0 := sim.y
	sim.step(DT, true)
	assert_true(sim.jumped, "점프")
	assert_false(sim.on_ground, "공중")
	for i in 3:
		sim.step(DT, true)
	assert_true(sim.y > y0, "올라감")
	for i in 30:
		sim.step(DT, false)
	sim.step(DT, true)
	assert_true(sim.double_jumped, "더블점프")
	sim.step(DT, false)
	sim.step(DT, true)
	assert_false(sim.double_jumped or sim.jumped, "세 번째는 안 됨")
	while not sim.on_ground:
		sim.step(DT, false)
	assert_true(sim.landed and sim.dashing, "보이지 않는 발판에 내려섬")
	sim.step(DT, true)
	assert_true(sim.jumped, "내려서면 다시 점프")
	assert_true(sim.vx() > 640.0, "질주 속도 유지")


func test_질주_중_마구_뛰어도_착지_옥상_위에서_끝나고_안_떨어지며_공중_생선을_먹을_수_있다() -> void:
	var ate_high := 0
	for seed_value in 30:
		for v in [430.0, 710.0, 950.0]:
			var sim := _sim("dash", seed_value + 1, v, true)
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var press := false
			var t := 0.0
			while not sim.dash_started:
				sim.step(DT, false)
			while sim.dashing and t < 30.0:
				if rng.randf() < 0.05:
					press = not press
				sim.step(DT, press)
				t += DT
				for item in sim.picked:
					ate_high += 1 if item.kind == "fish" and item.y > sim.get("_dash_base") + 150.0 else 0
				assert_false(sim.game_over, "떨어지지 않음")
			assert_true(sim.dash_ended and sim.on_ground and sim.landed, "시드 %d 속도 %d: 땅에서 끝남" % [seed_value, v])
			var roof: Dictionary = sim.get("_ground_roof")
			assert_true(is_equal_approx(sim.y, roof.top), "순간이동 없이 옥상 높이")
			assert_true(sim.x - Balance.CAT_FOOT_HALF <= roof.right and sim.x + Balance.CAT_FOOT_HALF >= roof.left, "시드 %d 속도 %d: 옥상 위" % [seed_value, v])
			assert_true(roof.right - sim.x > 0.0, "지나치지 않음")
	assert_true(ate_high > 100, "뛰면 공중 생선을 먹음 (%d)" % ate_high)


func test_질주_착지_옥상_위에서는_새로_못_뛴다() -> void:
	var sim := _sim("dash", 4, 640.0, true)
	while not sim.dashing:
		sim.step(DT, false)
	sim.dash_time = 0.0
	sim.set("_dash_landing", {"left": sim.x - 500.0, "right": sim.x + 5000.0, "top": sim.y})
	sim.step(DT, false)
	sim.step(DT, true)
	assert_false(sim.jumped, "착지 옥상 위")


func test_질주는_트램펄린_전봇대_판_no_ghost_벽을_무시하고_지나간다() -> void:
	var sim := _sim("dash", 3, 570.0)
	sim.set("_generator", RoofGenerator.new(3))
	sim.get("_generator").special_chance = 1.0
	var seen := {"tramp": 0, "plate": 0, "no_ghost": 0}
	var last_x := {}
	for round_i in 30:
		sim.items.append({"kind": "dash", "x": sim.x + 80.0, "y": sim.y + Balance.ITEM_LIFT})
		_run_dash(sim, func() -> void:
			assert_false(sim.ghosted or sim.bounced or sim.is_riding() or sim.rescued or sim.is_doomed(), "일반 코드가 끼어들지 않음")
			assert_true(sim.line_touch_eta(1.0).is_empty(), "눌러! 안내 없음")
			assert_eq(sim.vx(), 855.0, "속도 그대로")
			for s in sim.structures:
				if s.kind == "tramp" and sim.x > s.left and sim.x < s.right and not last_x.has(s.left):
					last_x[s.left] = true
					seen.tramp += 1
			for r in sim.roofs:
				if sim.x > r.left and sim.x < r.right and not last_x.has(r.left):
					last_x[r.left] = true
					seen.plate += 1 if r.get("platform", false) else 0
					seen.no_ghost += 1 if r.get("no_ghost", false) else 0)
		assert_false(sim.game_over, "떨어지지 않음")
	for key in seen:
		assert_true(seen[key] > 3, "%s를 실제로 지나감 (%d)" % [key, seen[key]])


func test_질주_시작은_다른_상태를_지운다() -> void:
	var sim := _sim("")
	sim.set("_launch_vx", 2000.0)
	sim.set("_buffer", 0.1)
	sim.set("_held_top", 100.0)
	sim.set("_ride_line", {"left": 0.0})
	sim.ghost_time = 1.0
	sim.invuln_time = 1.0
	sim.on_ground = false
	sim._start_dash()
	assert_eq(sim.get("_launch_vx"), 0.0)
	assert_eq(sim.get("_buffer"), 0.0)
	assert_true(is_nan(sim.get("_held_top")))
	assert_true(sim.get("_ride_line").is_empty())
	assert_eq(sim.ghost_time, 0.0)
	assert_eq(sim.invuln_time, 0.0)
	assert_eq(sim.vx(), Balance.RUN_SPEED * Balance.DASH_MULT, "1.5배")
	sim.speed = 950.0
	assert_eq(sim.vx(), Balance.DASH_MAX_SPEED, "상한 1250")


func test_질주는_장애물을_높이와_상관없이_부수고_하트를_잃지_않으며_화면_밖에_부술_것을_더_놓는다() -> void:
	var sim := _sim("dash", 1, 640.0, true)
	sim.items[0].x = sim.x + 80.0
	var flock := {"id": 7, "kind": "flock", "x": sim.x + 600.0, "w": 150.0, "y0": sim.y + 240.0, "y1": sim.y + 310.0, "base": sim.y, "k": 0.1}
	sim.obstacles.append(flock)
	var broken: Array = []
	var all_seen := {}
	_run_dash(sim, func() -> void:
		for o in sim.obstacles:
			if o.id < 0 and not all_seen.has(o.id):
				all_seen[o.id] = true
				assert_true(RunnerSim.obstacle_left(o, sim.x) > sim.x + sim.view_ahead, "부술 것은 화면 밖에서 생김")
		for o in sim.smashed:
			broken.append(o.id))
	assert_true(broken.has(7), "하늘의 비둘기도 부숨")
	assert_true(broken.size() >= 3, "3개 이상 부숨 (%d)" % broken.size())
	assert_eq(sim.hearts, Balance.HEARTS_MAX)
	for o in sim.obstacles:
		assert_true(o.id >= 0 or o.x > sim.x, "놓은 부술 것은 질주 안에 다 부숨")


func test_상자_구제_중에는_아이템을_먹지_않는다() -> void:
	for kind in ["fish", "gold", "dash", "yarn", "cookie", "can", "bell", "box"]:
		var sim := _sim(kind)
		sim.hearts = 2
		sim.rescuing = true
		sim.items[0].x = sim.x
		sim.step(DT, false)
		assert_eq(sim.items.size(), 1, kind + "는 남아 있음")
		assert_true(sim.picked.is_empty(), kind)
		assert_false(sim.dashing, kind)


func test_방울이_먼저_막고_그다음_하트가_준다() -> void:
	var sim := _sim("bell")
	sim.items.append({"kind": "bell", "x": sim.x + 200.0, "y": sim.y + Balance.ITEM_LIFT})
	for i in 30:
		sim.step(DT, false)
	assert_true(sim.has_bell, "방울을 가짐")
	assert_eq(sim.items.size(), 1, "이미 있으면 다음 방울은 그대로 (하나만)")
	sim.items.clear()
	_pot(sim, sim.x + 80.0, 1)
	var blocked := false
	for i in 40:
		sim.step(DT, false)
		blocked = blocked or sim.bell_blocked
	assert_true(blocked, "막음 신호")
	assert_false(sim.has_bell, "방울이 깨짐")
	assert_eq(sim.hearts, Balance.HEARTS_MAX, "하트 그대로")
	assert_true(sim.obstacles.is_empty(), "막은 장애물은 튕겨 나감")
	assert_true(sim.invuln_time > 0.0, "막은 뒤에도 무적")
	sim.invuln_time = 0.0
	_pot(sim, sim.x + 80.0, 2)
	for i in 40:
		sim.step(DT, false)
	assert_eq(sim.hearts, Balance.HEARTS_MAX - 1, "방울이 없으면 하트가 줄어듦")


func test_통조림은_화면_안_장애물만_생선으로_바꾼다() -> void:
	var sim := _sim("can")
	sim.view_ahead = 940.0
	var inside := _pot(sim, sim.x + 700.0, 1)
	var behind := _pot(sim, sim.x - 200.0, 2)
	var outside := _pot(sim, sim.x + 1200.0, 3)
	var fish_before := sim.items.size() - 1
	var converted: Array = []
	for i in 30:
		sim.step(DT, false)
		converted.append_array(sim.canned)
	var ids := converted.map(func(o: Dictionary) -> int: return o.id)
	ids.sort()
	assert_eq(ids, [1, 2], "화면 안(뒤쪽 포함)만")
	assert_eq(sim.obstacles.size(), 1)
	assert_eq(sim.obstacles[0].id, outside.id, "화면 밖은 그대로")
	assert_eq(sim.items.size() + sim.fish, fish_before + 2 * Balance.CAN_FISH, "생선으로 바뀜")
	assert_eq(sim.hearts, Balance.HEARTS_MAX)
	assert_true(inside.x > behind.x)


func test_쿠키는_하트를_1개_채우고_가득_차면_먹지_않는다() -> void:
	var sim := _sim("cookie")
	for i in 30:
		sim.step(DT, false)
	assert_eq(sim.items.size(), 1, "하트 3개면 그대로")
	sim.hearts = 2
	sim.step(DT, false)
	assert_eq(sim.hearts, 3)
	assert_true(sim.items.is_empty())


func test_황금은_생선_20이고_거리_점수에는_안_더한다() -> void:
	var sim := _sim("gold")
	var other := _sim("")
	for i in 30:
		sim.step(DT, false)
		other.step(DT, false)
	assert_eq(sim.fish, Balance.GOLD_FISH)
	assert_eq(sim.distance(), other.distance())


func test_털실은_반경_안_생선만_끌어오고_8초_뒤_끝난다() -> void:
	var sim := _sim("yarn")
	for i in 30:
		sim.step(DT, false)
	assert_true(absf(sim.magnet_time - Balance.MAGNET_TIME) < 0.3, "8초 시작")
	sim.items.append({"kind": "fish", "x": sim.x + 40.0, "y": sim.y + 200.0})  # 달리기로는 못 먹는 높이, 반경 안
	sim.items.append({"kind": "fish", "x": sim.x, "y": sim.y + 1000.0})        # 반경 밖
	for i in 30:
		sim.step(DT, false)
	assert_eq(sim.fish, 1, "반경 안 생선이 날아와 먹힘")
	assert_eq(sim.items.size(), 1, "반경 밖은 그대로")
	sim.magnet_time = 0.0
	sim.items[0] = {"kind": "fish", "x": sim.x + 200.0, "y": sim.y + 200.0}
	var y0: float = sim.items[0].y
	sim.step(DT, false)
	assert_eq(sim.items[0].y, y0, "끝나면 끌어오지 않음")


func test_아이템_자리는_우선순위와_간격대로_고른다() -> void:
	var slots := ItemSlots.new(1)
	assert_eq(slots.choose(0.0, 3, false), "fish", "처음에는 생선")
	assert_eq(slots.choose(8.0, 3, false), "yarn", "털실이 먼저 나옴")
	assert_eq(slots.choose(90.0, 3, false), "bell")
	assert_true(slots.choose(90.0, 3, true) != "bell", "방울을 가지면 안 나옴")
	assert_eq(slots.choose(120.0, 3, false), "can", "통조림이 방울보다 먼저")
	assert_eq(slots.choose(90.0, 2, false), "cookie", "하트가 2개면 쿠키가 가장 먼저")
	assert_true(slots.choose(120.0, 3, false) != "cookie", "하트 3개면 안 나옴")
	slots.fill({"x": 0.0, "y": 0.0}, 90.0, 2, false)
	assert_true(slots.choose(179.0, 2, false) != "cookie", "90초에 최대 1개")
	assert_eq(slots.choose(180.0, 2, false), "cookie")
	assert_true(slots.choose(9000.0, 3, false) != "dash", "질주는 대본 전에는 안 나옴")
	var first := slots.fill({"x": 5.0, "y": 6.0, "forced": "dash"}, 24.0, 3, false)
	assert_eq(first, [{"kind": "dash", "x": 5.0, "y": 6.0}] as Array[Dictionary], "대본의 첫 질주")
	assert_true(slots.choose(24.0 + 89.0, 3, true) != "dash", "다음 질주는 90초 뒤부터")
	assert_eq(slots.choose(24.0 + 130.0, 3, false), "dash", "늦어도 130초 뒤")
	var row := ItemSlots.new(2).fill({"x": 0.0, "y": 6.0}, 0.0, 3, false)
	assert_eq(row.size(), 1, "시간이 된 것이 없으면 생선 한 마리 (생선 길의 빈자리)")


func test_꺼진_아이템은_대본의_첫_질주도_나오지_않는다() -> void:
	var slots := ItemSlots.new(1)
	slots.off = ["dash"]
	assert_eq(slots.fill({"x": 0.0, "y": 0.0, "forced": "dash"}, 0.0, 3, false)[0].kind, "fish")


func test_대본_마지막_구간의_자리는_질주이고_구간_옥상에_황금이_있다() -> void:
	var gen := RoofGenerator.new(4)
	var course := CoursePlacer.new(gen, 4)
	var roofs: Array[Dictionary] = [RoofGenerator.first_roof(0.0)]
	var forced := 0
	var script_left := Balance.SEGMENT_SCRIPT.size()
	while script_left > 0 or course.get("_queue").size() > 0:
		var roof := course.next_roof(roofs[-1], Balance.RUN_SPEED, 1)
		roofs.append(roof)
		if roof.has("segment") and course.get("_queue").is_empty():
			script_left -= 1
		for slot: Dictionary in roof.get("slots", []):
			forced += 1 if slot.get("forced", "") == "dash" else 0
	assert_eq(forced, 1, "첫 질주 하나")
	var gold: Array = FishRoad.new().extend({"left": -3000.0, "right": -200.0, "top": 200.0}, CoursePlacer.build("N3", 570.0, 1.0, 0.0, 200.0)[0], [570.0])
	assert_eq(gold.filter(func(it: Dictionary) -> bool: return it.kind == "gold").size(), 1)


func _world() -> Node2D:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://test_power_items.cfg"
	add_child(main)
	return main.get_node("World")


func test_화면은_부술_때_잠깐_멈추고_0점25초_안에_다시_멈추지_않으며_질주_중_멀어졌다_돌아온다() -> void:
	var world := _world()
	await wait_frames(1)
	world.set_process(false)
	var sim: RunnerSim = world.sim
	sim.accelerate = false
	sim._start_dash()
	world._process(0.3)
	assert_true(world.scale.x < 1.0, "멀어짐")
	world._process(0.3)
	assert_true(absf(world.scale.x - world.DASH_ZOOM) < 0.001, "8%")
	assert_true(world._view_size().x > world.get_viewport_rect().size.x, "더 넓게 그림")
	assert_true(world.position.y > 0.0, "아래 끝 기준")
	# 눈앞 장애물을 부순다
	sim.obstacles.clear()
	sim.obstacles.append({"id": 50, "kind": "pot", "x": sim.x + 80.0, "w": 48.0, "y0": sim.y, "y1": sim.y + 38.0, "base": sim.y})
	world._process(0.05)
	assert_true(world._hitstop > 0.0, "멈춤")
	assert_true(world._shards.size() >= 5 and not world._pop_texts.is_empty() and not world._knocked.is_empty(), "조각·글자·날아감")
	var stopped_x := sim.x
	world._process(0.02)
	assert_eq(sim.x, stopped_x, "멈춘 동안 진행 안 함")
	world._process(0.02)
	world._process(0.02)
	assert_true(sim.x > stopped_x, "멈춤이 끝나면 진행")
	sim.obstacles.append({"id": 51, "kind": "pot", "x": sim.x + 50.0, "w": 48.0, "y0": sim.y, "y1": sim.y + 38.0, "base": sim.y})
	world._process(0.02)
	assert_eq(world._hitstop, 0.0, "0.25초 안에 다시 멈추지 않음")
	world.queue_redraw()
	world.restart()
	assert_eq(world.scale.x, 1.0, "새 판은 원래 크기")
	assert_true(world._shards.is_empty())
	world.get_parent().queue_free()
	await wait_frames(1)
	DirAccess.remove_absolute("user://test_power_items.cfg")
