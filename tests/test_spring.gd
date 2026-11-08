extends TestCase
## 몸 배율 스프링: 목표를 따라감, 충격의 크기·시간, 프레임 간격과 무관한 결과, 고양이 그림에 실제로 들어가는지.

const DT := 1.0 / 60.0


func _peak(spring: Spring, axis: int, dt: float, seconds: float) -> Dictionary:
	# 정해진 시간 동안 목표 1에서 가장 크게 벗어난 값과 그때까지 걸린 시간
	var best := {"offset": 0.0, "t": 0.0}
	var t := 0.0
	while t < seconds:
		spring.step(Vector2.ONE, dt)
		t += dt
		var off := spring.value[axis] - 1.0
		if absf(off) > absf(best.offset):
			best = {"offset": off, "t": t}
	return best


func test_목표로_출렁이며_다가가고_멈춘다() -> void:
	var s := Spring.new(5.0, 0.4)
	var overshoot := 0.0
	for i in 120:
		s.step(Vector2(1.2, 0.8), DT)
		overshoot = maxf(overshoot, s.value.x)
	assert_true(overshoot > 1.2, "넘쳤다가 돌아옴 (말랑함) %.3f" % overshoot)
	assert_true(overshoot < 1.3, "너무 크게 넘치지 않음 %.3f" % overshoot)
	assert_true(s.value.distance_to(Vector2(1.2, 0.8)) < 0.001, "2초 뒤 목표에 멈춤 %s" % str(s.value))


func test_충격은_정한_만큼_벗어났다가_빨리_돌아온다() -> void:
	var s := Spring.new(Balance.CAT_SPRING_HZ, Balance.CAT_SPRING_DAMPING)
	s.kick(Balance.KICK_LAND)
	var peak := _peak(s, 1, 1.0 / 1000.0, 0.3)
	assert_true(absf(peak.offset - Balance.KICK_LAND.y) < 0.005, "착지 눌림 세로 %.3f (목표 %.2f)" % [peak.offset, Balance.KICK_LAND.y])
	assert_true(absf(peak.t - s.peak_time()) < 0.003, "가장 눌린 때 %.3f초" % peak.t)
	assert_true(peak.t > 0.02 and peak.t < 0.08, "짧고 탄력 있게 (ART_BIBLE 0.06~0.12초대 안에서 돌아옴)")
	var s2 := Spring.new(Balance.CAT_SPRING_HZ, Balance.CAT_SPRING_DAMPING)
	s2.kick(Balance.KICK_LAND)
	for i in 30:
		s2.step(Vector2.ONE, DT)
	assert_true(s2.value.distance_to(Vector2.ONE) < 0.02, "0.5초 뒤 거의 원래 모양 %s" % str(s2.value))


func test_프레임_간격이_달라도_같은_움직임() -> void:
	var a := Spring.new(5.0, 0.4)
	var b := Spring.new(5.0, 0.4)
	a.kick(Vector2(0.2, -0.2))
	b.kick(Vector2(0.2, -0.2))
	for i in 12:
		a.step(Vector2.ONE, 1.0 / 120.0)
	for i in 2:
		b.step(Vector2.ONE, 1.0 / 20.0)  # 느린 프레임 (잘게 나눠 계산)
	assert_true(a.value.distance_to(b.value) < 0.01, "%s vs %s" % [str(a.value), str(b.value)])
	var c := Spring.new(5.0, 0.4)
	c.step(Vector2(2.0, 2.0), 0.5)  # 아주 긴 프레임에도 터지지 않음
	assert_true(c.value.x > 1.5 and c.value.x < 2.5, "안정 %s" % str(c.value))


func test_착지하면_고양이_그림이_실제로_납작해진다() -> void:
	var cat := CatView.new()
	add_child(cat)
	await wait_frames(1)
	var sim := RunnerSim.new(1)
	sim.accelerate = false
	var min_y := 9.0
	var max_y := 0.0
	var landed := false
	for i in 240:
		sim.step(DT, i < 6)
		cat.show_state(sim, DT)
		if sim.landed:
			landed = true
		if landed:
			min_y = minf(min_y, cat.body_scale().y)
		elif not sim.on_ground:
			max_y = maxf(max_y, cat.body_scale().y)
	assert_true(landed, "착지함")
	assert_true(min_y < 0.86, "착지 눌림이 보간에 먹히지 않음 (세로 %.3f, 예전 0.94)" % min_y)
	assert_true(max_y > 1.12, "뛰는 순간 세로로 늘어남 %.3f" % max_y)
	cat.queue_free()


func test_달리기_몸_들썩임은_한_바퀴에_2번() -> void:
	var peaks := 0
	var prev := CatPose.run_bob(0.0)
	var rising := false
	for i in range(1, 98):  # 97칸: 꼭대기 양옆이 똑같은 값이 되지 않게
		var b := CatPose.run_bob(i / 97.0)
		if rising and b < prev:
			peaks += 1
		rising = b > prev
		prev = b
	assert_eq(peaks, 2)
	assert_true(absf(CatPose.run_bob(0.375) - Balance.CAT_RUN_BOB) < 0.01, "박차기 가운데에서 가장 높음")
	assert_true(CatPose.run_bob(0.125) < 0.01, "모으기 가운데에서 가장 낮음")
	var sim := RunnerSim.new(1)
	sim.x = Balance.CAT_STRIDE * 0.375
	assert_true(absf(CatPose.pose(sim).bob - Balance.CAT_RUN_BOB) < 0.01, "달릴 때 자세에 들어감")


func test_공중에서는_숨쉬고_꼭대기에서_부푼다() -> void:
	var sim := RunnerSim.new(1)
	sim.on_ground = false
	sim.y = 500.0
	sim.time_since_jump = 1.0
	sim.vy = 0.0
	var sizes := {}
	for i in 8:
		sim.elapsed = i / 16.0
		var s: Vector2 = CatPose.pose(sim).scale
		sizes[snappedf(s.x, 0.005)] = true
		assert_true(s.x > 1.03, "꼭대기에서 둥글게 부풂 %s" % str(s))
	assert_true(sizes.size() >= 3, "숨쉬기로 크기가 변함 %s" % str(sizes.keys()))
	sim.vy = -JumpModel.jump_speed()
	var fast: Vector2 = CatPose.pose(sim).scale
	assert_true(fast.y > 1.05 and fast.x < 1.0, "빨리 떨어지면 세로로 늘어남 %s" % str(fast))


func test_느린_프레임에서도_뛰는_순간_늘어남_충격이_빠지지_않는다() -> void:
	# 느린 프레임: 새로 뛴 것을 처음 보는 프레임에 웅크림 시간이 이미 지나 있어도 늘어나는 충격이 들어가야 한다
	var cat := CatView.new()
	add_child(cat)
	await wait_frames(1)
	var sim := RunnerSim.new(1)
	cat.show_state(sim, DT)  # 땅 위 (지난 프레임으로 기억)
	sim.on_ground = false
	sim.y = 500.0
	sim.vy = 100.0
	sim.time_since_jump = Balance.CAT_CROUCH_TIME + 0.002
	cat.show_state(sim, 0.0001)
	var spring: Spring = cat.get("_spring")
	var expected: float = (Balance.KICK_CROUCH.y + Balance.KICK_TAKEOFF.y) * spring.kick_gain()
	assert_true(spring.velocity.y > expected * 0.9, "세로 충격 %.2f (기대 %.2f)" % [spring.velocity.y, expected])
	cat.queue_free()
