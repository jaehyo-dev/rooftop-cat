extends TestCase
## 자동 달리기, 착지, 벽, 떨어짐, 입력 여유(버퍼·코요테), 늘어남·납작해짐.

const DT := 1.0 / 120.0


func test_누르지_않아도_일정한_속도로_달린다() -> void:
	var sim := RunnerSim.new(1)
	var start := sim.x
	for i in 120:
		sim.step(DT, false)
	assert_true(absf(sim.x - start - Balance.RUN_SPEED) < 0.01, "1초에 RUN_SPEED만큼")
	assert_true(sim.on_ground)


func test_점프하면_다시_옥상에_착지() -> void:
	var sim := RunnerSim.new(1)
	var roof_top := sim.y
	sim.step(DT, true)
	assert_true(sim.jumped, "누르는 순간 점프")
	assert_false(sim.on_ground)
	var landed := false
	for i in 120:
		sim.step(DT, false)
		landed = landed or sim.landed
	assert_true(landed, "착지 신호")
	assert_true(sim.on_ground)
	assert_eq(sim.y, roof_top)


func test_계속_누르고_있어도_한_번만_뛴다() -> void:
	var sim := RunnerSim.new(1)
	var jumps := 0
	for i in 120:
		sim.step(DT, true)
		if sim.jumped:
			jumps += 1
	assert_eq(jumps, 1)


func test_옥상_끝을_지나면_떨어지고_앞_옥상에서_다시_달린다() -> void:
	var sim := RunnerSim.new(1)
	var fell := false
	for i in 120 * 10:
		sim.step(DT, false)
		if sim.fell:
			fell = true
			break
	assert_true(fell, "안 뛰면 떨어짐")
	assert_true(sim.on_ground, "다시 옥상 위")
	assert_false(sim.roof_at(sim.x).is_empty(), "옥상 위에 있음")


func test_옆_벽에_부딪히면_위로_올라서지_못한다() -> void:
	var sim := RunnerSim.new(1)
	sim.roofs.clear()
	sim.roofs.append({"left": -100.0, "right": 100.0, "top": 100.0})
	sim.roofs.append({"left": 150.0, "right": 5000.0, "top": 300.0})
	sim.x = 140.0
	sim.y = 120.0  # 벽보다 낮은 곳에서 떨어지는 중
	sim.vy = -10.0
	sim.on_ground = false
	for i in 30:
		sim.step(DT, false)
		assert_false(sim.landed, "벽 안에서 옥상 위로 순간 이동하면 안 됨")


func test_착지_직전에_누른_입력은_착지하자마자_점프() -> void:
	var sim := RunnerSim.new(1)
	sim.step(DT, true)
	for i in 300:
		sim.step(DT, false)
		if sim.vy < 0.0 and sim.y - sim.roof_at(sim.x).get("top", 0.0) < 15.0:
			break
	# 땅에 닿기 조금 전에 톡 누름
	sim.step(DT, true)
	var jumped_again := false
	for i in int(Balance.JUMP_BUFFER_TIME / DT):
		sim.step(DT, false)
		jumped_again = jumped_again or sim.jumped
	assert_true(jumped_again)


func test_옥상_끝을_막_지난_뒤에도_점프를_받아준다() -> void:
	var sim := RunnerSim.new(1)
	while sim.on_ground:
		sim.step(DT, false)
	sim.step(DT, true)  # 끝을 지난 바로 다음 순간
	assert_true(sim.jumped)


func test_늘어남과_납작해짐() -> void:
	assert_eq(Squash.body_scale(true, 0.0, 99.0), Vector2.ONE, "달릴 때는 원래 모양")
	var rise := Squash.body_scale(false, JumpModel.jump_speed(), 99.0)
	assert_true(rise.y > 1.0 and rise.x < 1.0, "올라갈 때 세로로 늘어남")
	var land := Squash.body_scale(true, 0.0, 0.0)
	assert_true(land.x > 1.0 and land.y < 1.0, "착지 순간 납작")
	var later := Squash.body_scale(true, 0.0, Balance.SQUASH_TIME * 0.5)
	assert_true(later.y > land.y and later.y < 1.0, "점점 원래 모양으로")
	assert_eq(Squash.body_scale(true, 0.0, Balance.SQUASH_TIME), Vector2.ONE, "시간이 지나면 원래 모양")


func test_임시_고양이는_기준_그림과_같은_비율() -> void:
	# 기준 그림의 몸 영역 711x438 (꼬리 제외, 머리 위~발끝)
	var ratio := Balance.CAT_BODY_SIZE.x / Balance.CAT_BODY_SIZE.y
	assert_true(absf(ratio - 711.0 / 438.0) < 0.02, "비율 %.3f" % ratio)
