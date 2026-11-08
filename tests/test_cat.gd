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


func test_뛰어서_올라갈_때도_내려올_때도_기울지_않는다() -> void:
	# 낮게 뛴 경우(0.05초)와 가장 높게 뛴 경우(끝까지 누름) 모두, 공중에서 내내 tilt 0
	for hold in [0.05, 5.0]:
		var sim := _sim_on_roofs([{"left": 0.0, "right": 100000.0, "top": 200.0}])
		sim.accelerate = false
		var t := 0.0
		var seen := {}
		var peak := 0.0
		while t < 3.0:
			sim.step(DT, t < hold and t >= 0.0)
			t += DT
			if not sim.on_ground and sim.time_since_jump >= Balance.CAT_CROUCH_TIME:
				var pose := CatPose.pose(sim)
				seen[pose.frame] = true
				peak = maxf(peak, sim.y - 200.0)
				assert_eq(pose.tilt, 0.0, "공중 기울기 0 (%s, 누름 %s)" % [pose.frame, hold])
		assert_true(seen.has("rise") and seen.has("fall"), "올라감·내려옴 모두 확인 %s" % str(seen.keys()))
		if hold > 1.0:
			assert_true(peak > Balance.JUMP_MAX_HEIGHT * 0.95, "가장 높게 뜀 %s" % peak)


func test_더는_올라설_수_없으면_허우적거린다() -> void:
	var roofs := [{"left": -500.0, "right": 0.0, "top": 200.0}, {"left": 300.0, "right": 5000.0, "top": 250.0}]
	var sim := _sim_on_roofs(roofs)
	sim.on_ground = false
	sim.x = 100.0  # 틈 위
	sim.vy = -100.0
	sim.y = 249.0 - Balance.DOUBLE_JUMP_MAX_HEIGHT + 1.0
	assert_false(sim.is_doomed(), "더블점프가 남아 있으면 그만큼 아래여도 아직 오를 수 있음")
	sim.set("_double_used", true)  # 아래부터는 더블점프를 이미 쓴 경우
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
	assert_eq(sprite.position + sprite.offset, -CatView.ANCHOR, "그림의 기준점이 노드 원점(발끝) (공중제비 축으로 옮긴 만큼 offset을 되돌림)")
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


## 높은 곳 공중(아래 옥상 없음)에 띄운 sim
func _sim_in_air() -> RunnerSim:
	var sim := _sim_on_roofs([{"left": -2000.0, "right": 0.0, "top": 200.0}, {"left": 100000.0, "right": 200000.0, "top": 0.0}])
	sim.x = -10.0
	sim.on_ground = false
	sim.set("_jumped", true)
	sim.y = 600.0
	sim.vy = 0.0
	return sim


func test_더블점프는_몸을_말아_앞구르기_한_바퀴를_돌고_착지하면_끊긴다() -> void:
	var sim := _sim_in_air()
	sim.step(DT, true)  # 더블점프 (평소 점프는 회전 없음: 위 test_뛰어서_올라갈_때도_내려올_때도_기울지_않는다)
	assert_true(sim.double_jumped)
	var order: Array[String] = [CatPose.pose(sim).frame]
	var last_spin: float = CatPose.pose(sim).spin
	assert_true(last_spin < 0.2, "막 돌기 시작")
	while sim.time_since_double_jump < Balance.CAT_FLIP_TIME - DT:
		sim.y = 600.0
		sim.step(DT, true)
		var p: Dictionary = CatPose.pose(sim)
		assert_true(p.spin >= last_spin, "한 방향으로 돎")
		last_spin = p.spin
		if order[-1] != p.frame:
			order.append(p.frame)
	assert_eq(order, ["flip_tuck", "flip_curl", "flip_ball", "flip_open"] as Array[String], "숙이기 → C자 → 공 → 펴기")
	assert_true(last_spin > TAU * 0.97, "한 바퀴 (%.2f)" % last_spin)
	sim.step(DT * 2.0, true)
	assert_eq(CatPose.pose(sim).spin, 0.0, "끝나면 회전 없음")
	assert_eq(CatPose.pose(sim).frame, "fall", "끝나면 누르고 있어도 내려옴 그림으로 이어짐")
	# 도는 중에 착지하면 바로 끊김
	sim.time_since_double_jump = 0.1
	sim.on_ground = true
	assert_eq(CatPose.pose(sim).spin, 0.0, "착지하면 끊김")
	sim.on_ground = false
	sim.ghost_time = 0.5
	assert_eq(CatPose.pose(sim).spin, 0.0, "투명화면 끊김")


func test_앞구르기_회전은_공일_때_가장_빠르다() -> void:
	var speed := func(k: float) -> float: return CatPose.flip_angle(k + 0.01) - CatPose.flip_angle(k)
	assert_true(speed.call(0.5) > speed.call(0.1) * 2.0, "공 > 말기")
	assert_true(speed.call(0.5) > speed.call(0.9) * 2.0, "공 > 펴기")
	assert_eq(CatPose.flip_angle(0.0), 0.0)
	assert_true(absf(CatPose.flip_angle(1.0) - TAU) < 0.001, "딱 한 바퀴")
	var curl_end := CatPose.flip_angle(0.25)
	var open_start := CatPose.flip_angle(0.75)
	assert_true(absf(rad_to_deg(curl_end) - 60.0) < 8.0, "말기 끝 약 60도 (%.0f)" % rad_to_deg(curl_end))
	assert_true(absf(rad_to_deg(open_start) - 300.0) < 8.0, "펴기 시작 약 300도 (%.0f)" % rad_to_deg(open_start))


func test_트램펄린_결과별_자세() -> void:
	var tramp := {"kind": "tramp", "left": 0.0, "right": 210.0, "top": 210.0, "base": 200.0}
	var sim := _sim_in_air()
	sim.bounced_line = tramp
	sim.time_since_bounce = 0.0
	sim.vy = 500.0
	sim.time_since_jump = 5.0
	sim.bounce_result = "perfect"
	assert_eq(CatPose.pose(sim).frame, "crouch", "튕긴 직후는 아직 그물에 눌린 웅크림")
	sim.time_since_bounce = Balance.TRAMP_PUSH
	assert_eq(CatPose.pose(sim).frame, "takeoff", "퍼펙트: 도약 그림으로 늘어나며 발사")
	var launch_end := Balance.TRAMP_PUSH + Balance.CAT_LAUNCH_TIME
	sim.time_since_bounce = launch_end + 0.2
	assert_true(CatPose.pose(sim).frame.begins_with("flip_"), "그 뒤 앞구르기 자동 1회")
	sim.time_since_bounce = launch_end + Balance.CAT_FLIP_TIME + 0.01
	assert_eq(CatPose.pose(sim).spin, 0.0, "한 번만")
	sim.time_since_bounce = launch_end + 0.1
	sim.bounce_result = "good"
	assert_eq(CatPose.pose(sim).spin, 0.0, "그냥 누름은 앞구르기 없음")
	sim.time_since_bounce = Balance.TRAMP_PUSH + 0.01
	assert_eq(CatPose.pose(sim).frame, "takeoff", "누름도 도약 그림으로 발사")
	sim.bounce_result = "miss"
	assert_eq(CatPose.pose(sim).frame, "flail", "안 누르면 허우적")
	sim.rescuing = true
	assert_eq(CatPose.pose(sim).frame, "rise", "떨어지다 상자에 구제되면 허우적이 아니라 올라가는 자세")
	sim.rescuing = false
	sim.time_since_land = 0.0
	sim.on_ground = true
	assert_true(CatPose.pose(sim).frame != "flail", "내려서면 끝")


func test_공중제비_회전축은_몸_가운데() -> void:
	var cat := CatView.new()
	add_child(cat)
	await wait_frames()
	var sprite: Sprite2D = cat.get_node("Sprite")
	# 회전 0이면 그림 자리가 예전과 같다 (기준점이 발끝)
	assert_eq(sprite.position + sprite.offset, -CatView.ANCHOR)
	# 축은 발끝 위 몸 높이의 절반 (게임 픽셀)
	assert_true(absf(sprite.position.y * CatView.art_scale() + Balance.CAT_BODY_SIZE.y * 0.5) < 0.01)
	cat.queue_free()
