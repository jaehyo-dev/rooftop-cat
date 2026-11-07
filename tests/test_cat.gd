extends TestCase
## 고양이 프레임 애니메이션: 상태별 프레임 고르기, 떨어짐 판정, 그림 크기·기준점, 프레임 정렬(떨림 없음).

const DT := 1.0 / 120.0


func _sim_on_roofs(list: Array) -> RunnerSim:
	var sim := RunnerSim.new(1)
	sim.accelerate = false
	sim.roofs.clear()
	for roof in list:
		sim.roofs.append(roof)
	sim.x = list[0].left + 100.0
	sim.y = list[0].top
	sim.on_ground = true
	sim.set("_ground_roof", sim.roofs[0])
	return sim


func test_달리기는_달린_거리로_4프레임을_차례로_돈다() -> void:
	var sim := RunnerSim.new(1)
	var seen: Array[String] = []
	for i in 8:
		sim.x = Balance.CAT_STRIDE * (i + 0.5) / 4.0
		seen.append(CatPose.pose(sim).frame)
	assert_eq(seen, ["run_0", "run_1", "run_2", "run_3", "run_0", "run_1", "run_2", "run_3"] as Array[String])
	sim.x = -Balance.CAT_STRIDE * 0.1
	assert_eq(CatPose.pose(sim).frame, "run_3", "음수 거리도 순서대로")
	for i in 4:
		sim.x = Balance.CAT_STRIDE * (i + 0.5) / 4.0
		assert_eq(CatPose.pose(sim).tilt, 0.0, "달릴 때 기울지 않음")


func test_점프는_웅크림_도약_올라감_내려옴_착지_순서() -> void:
	var sim := RunnerSim.new(1)
	var order: Array[String] = []
	var hold := JumpModel.max_hold_time() * 0.6
	var t := 0.0
	for i in 240:
		sim.step(DT, t < hold)
		t += DT
		var frame: String = CatPose.pose(sim).frame
		if order.is_empty() or order[-1] != frame:
			order.append(frame)
		if sim.on_ground and sim.time_since_land > Balance.CAT_LAND_TIME and t > 0.2:
			break
	assert_eq(order.slice(0, 5), ["crouch", "takeoff", "rise", "fall", "land"] as Array[String])
	assert_true(order.size() > 5 and order[5].begins_with("run_"), "착지 뒤 달리기로 %s" % str(order))


func test_길게_누를수록_도약할_때_몸이_더_늘어난다() -> void:
	var stretch := []
	for hold in [0.3, 1.0]:
		var sim := RunnerSim.new(1)
		var max_x := 0.0
		for i in 120:
			sim.step(DT, i * DT < JumpModel.max_hold_time() * hold)
			var pose := CatPose.pose(sim)
			if pose.frame == "takeoff":
				max_x = maxf(max_x, pose.scale.x)
		stretch.append(max_x)
	assert_true(stretch[1] > stretch[0] and stretch[0] > 1.0, "가로 늘어남 %s" % str(stretch))


func test_올라갈_때는_기울지_않고_내려올_때는_코가_아래로() -> void:
	var sim := RunnerSim.new(1)
	sim.on_ground = false
	sim.time_since_jump = 1.0
	sim.vy = JumpModel.jump_speed()
	assert_eq(CatPose.pose(sim).tilt, 0.0, "올라갈 때 코를 쳐들지 않음")
	sim.vy = -JumpModel.jump_speed()
	sim.y = 1000.0  # 높은 곳: 아직 떨어지는 중이 아님
	var pose := CatPose.pose(sim)
	assert_eq(pose.frame, "fall")
	assert_true(pose.tilt > 0.0)


func test_더는_올라설_수_없으면_허우적거린다() -> void:
	var roofs := [{"left": -500.0, "right": 0.0, "top": 200.0}, {"left": 300.0, "right": 5000.0, "top": 250.0}]
	var sim := _sim_on_roofs(roofs)
	sim.on_ground = false
	sim.x = 100.0  # 틈 위
	sim.vy = -100.0
	sim.y = 260.0
	assert_false(sim.is_doomed(), "앞 옥상보다 높으면 아직 내려앉을 수 있음")
	sim.y = 249.0
	assert_true(sim.is_doomed(), "점프 없이 앞 옥상 높이보다 낮아지면 벽에 막혀 끝")
	assert_eq(CatPose.pose(sim).frame, "flail")
	sim.set("_jumped", true)
	sim.y = 250.0 - Balance.CAT_BODY_SIZE.y + 1.0
	assert_false(sim.is_doomed(), "점프했고 몸 높이 안쪽이면 투명화로 오를 수 있음")
	sim.y = 250.0 - Balance.CAT_BODY_SIZE.y - 1.0
	assert_true(sim.is_doomed(), "몸 높이보다 더 낮으면 끝")
	sim.vy = 10.0
	assert_false(sim.is_doomed(), "올라가는 중이면 아님")
	sim.vy = -10.0
	sim.x = 2000.0
	sim.y = 240.0
	assert_true(sim.is_doomed(), "발이 옥상 위인데 옥상보다 아래면 끝")
	sim.y = 260.0
	assert_false(sim.is_doomed(), "옥상보다 위면 내려앉음")


func test_실제로_틈에_떨어지면_허우적거리고_그전에는_아니다() -> void:
	var sim := RunnerSim.new(1)
	var flailed_at := -1.0
	var t := 0.0
	while not sim.game_over and t < 10.0:
		sim.step(DT, false)
		t += DT
		if CatPose.pose(sim).frame == "flail" and flailed_at < 0.0:
			flailed_at = t
			assert_false(sim.on_ground)
	assert_true(sim.game_over)
	assert_true(flailed_at > 0.0, "떨어지는 동안 허우적거림")
	# 허우적거림: 시간에 따라 몸이 앞뒤로 흔들린다
	var tilts := {}
	for i in 12:
		sim.elapsed = i * 0.03
		tilts[snappedf(CatPose.pose(sim).tilt, 1.0)] = true
	assert_true(tilts.size() >= 5, "흔들림 %s" % str(tilts.keys()))


func test_고양이_그림은_충돌_판정_크기에_맞고_기준점이_발끝() -> void:
	var cat := CatView.new()
	add_child(cat)
	await wait_frames(1)
	var sprite: Sprite2D = cat.get_node("Sprite")
	assert_eq(sprite.offset, -CatView.ANCHOR, "그림의 기준점이 노드 원점(발끝)")
	for frame in CatPose.ALL_FRAMES:
		var texture: Texture2D = load(CatView.FRAME_DIR + frame + ".png")
		assert_not_null(texture, frame)
		if texture == null:
			continue
		var used := texture.get_image().get_used_rect()
		# 모든 프레임의 가장 아랫줄(발끝)이 기준점 높이에 있다 (정렬 도구가 맞춤, 반투명 가장자리 1~2픽셀 허용)
		assert_true(absf(used.end.y - CatView.ANCHOR.y) <= 3.0, "%s 발끝 %d" % [frame, used.end.y])
	cat.queue_free()


func test_달리기_프레임은_몸_중심이_흔들리지_않는다() -> void:
	# 꼬리 쪽(왼쪽 30%)을 뺀 불투명 픽셀의 가로 무게중심이 프레임마다 거의 같아야 화면이 떨리지 않는다
	for frame in CatPose.ALL_FRAMES:
		var image: Image = load(CatView.FRAME_DIR + frame + ".png").get_image()
		var used := image.get_used_rect()
		var left := used.position.x + used.size.x * 0.3
		var sum := 0.0
		var count := 0
		for y in range(used.position.y, used.end.y, 2):
			for x in range(int(left), used.end.x, 2):
				if image.get_pixel(x, y).a > 0.5:
					sum += x
					count += 1
		var center := sum / maxf(count, 1.0)
		assert_true(absf(center - CatView.ANCHOR.x) <= 3.0, "%s 몸 중심 %.1f" % [frame, center])


func test_상태에_맞는_그림과_투명화() -> void:
	var cat := CatView.new()
	add_child(cat)
	await wait_frames(1)
	var sim := RunnerSim.new(3)
	var frames := {}
	for i in 120:
		sim.step(DT, false)
		cat.show_state(sim, DT)
		frames[cat.frame_name] = true
	assert_eq(frames.size(), 4, "달리며 4프레임을 모두 씀")
	assert_eq(cat.modulate.a, 1.0)
	sim.ghost_time = 1.0
	cat.show_state(sim, DT)
	assert_true(cat.modulate.a < 0.6, "투명화 중 반투명")
	cat.queue_free()
