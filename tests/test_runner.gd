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


func test_공중에서_벽에_부딪히면_투명해져_통과하고_옥상_위로_올라선다() -> void:
	var sim := _custom_roofs([{"left": -500.0, "right": -100.0, "top": 100.0}, {"left": 150.0, "right": 5000.0, "top": 300.0}])
	sim.x = 70.0  # 발은 어느 옥상에도 안 걸치고, 몸 앞쪽(145)은 벽(150) 바로 앞
	sim.y = 260.0  # 옥상 높이(300)보다 40 낮음: 몸이 모서리에 걸린 상태
	sim.vy = -10.0
	sim.on_ground = false
	sim.set("_jumped", true)  # 점프했는데 살짝 모자란 경우
	var ghosted := false
	var landed := false
	for i in 120:
		sim.step(DT, false)
		ghosted = ghosted or sim.ghosted
		landed = landed or sim.landed
		assert_false(sim.fell, "떨어지면 안 됨")
	assert_true(ghosted, "부딪히면 투명화 시작")
	assert_true(landed and sim.on_ground, "높은 옥상 위에 올라섬")
	assert_eq(sim.y, 300.0)
	assert_true(sim.front() > 150.0, "벽을 통과함")


func test_점프_없이_틈으로_떨어지다_벽에_닿으면_막혀서_떨어진다() -> void:
	var sim := _custom_roofs([{"left": -500.0, "right": -100.0, "top": 100.0}, {"left": 150.0, "right": 5000.0, "top": 300.0}])
	sim.x = 70.0
	sim.y = 280.0  # 몸이 모서리에 걸릴 높이지만 점프하지 않고 떨어지는 중
	sim.vy = -10.0
	sim.on_ground = false
	var fell := false
	for i in 120:
		sim.step(DT, false)
		assert_false(sim.ghosted, "투명화하지 않음")
		if sim.fell:
			fell = true
			break
		assert_true(sim.front() <= 150.0 + 0.001, "벽을 뚫지 않음")
	assert_true(fell, "떨어짐")


func test_너무_낮게_부딪히면_막혀서_떨어진다() -> void:
	var sim := _custom_roofs([{"left": -500.0, "right": -100.0, "top": 100.0}, {"left": 150.0, "right": 5000.0, "top": 300.0}])
	sim.x = 70.0
	sim.y = 300.0 - Balance.CAT_BODY_SIZE.y - 20.0  # 몸 전체가 옥상 높이보다 아래
	sim.vy = -10.0
	sim.on_ground = false
	sim.set("_jumped", true)
	var fell := false
	for i in 120:
		sim.step(DT, false)
		assert_false(sim.ghosted, "투명화하지 않음")
		if sim.fell:
			fell = true
			break
	assert_true(fell, "떨어짐")


func test_옥상_위에서_높은_벽에_부딪혀도_멈추지_않고_넘어간다() -> void:
	var sim := _custom_roofs([{"left": -500.0, "right": 300.0, "top": 100.0}, {"left": 300.0, "right": 5000.0, "top": 200.0}])
	var start_x := sim.x
	for i in 240:
		sim.step(DT, false)
	assert_true(absf(sim.x - start_x - Balance.RUN_SPEED * 2.0) < 0.01, "속도 그대로 달림")
	assert_true(sim.on_ground)
	assert_eq(sim.y, 200.0, "높은 옥상 위")


func test_투명화는_정해진_시간_뒤에_끝나고_그동안_다시_시작되지_않는다() -> void:
	var sim := _custom_roofs([{"left": -500.0, "right": 300.0, "top": 100.0}, {"left": 300.0, "right": 340.0, "top": 200.0}, {"left": 345.0, "right": 5000.0, "top": 290.0}])
	var starts := 0
	var steps := 0
	while sim.ghost_time == 0.0 and steps < 600:
		sim.step(DT, false)
		steps += 1
	starts = 1
	var ghost_steps := 0
	while sim.ghost_time > 0.0 and ghost_steps < 600:
		sim.step(DT, false)
		ghost_steps += 1
		if sim.ghosted:
			starts += 1
	assert_eq(starts, 1, "투명화 중에 다른 벽에 닿아도 다시 시작하지 않음")
	assert_true(absf(ghost_steps * DT - Balance.GHOST_TIME) <= DT * 1.5, "%.3f초 동안 투명" % (ghost_steps * DT))
	assert_eq(sim.y, 290.0, "두 벽을 다 넘어 가장 높은 옥상 위")


func test_발_범위가_걸치면_옥상에_서_있다() -> void:
	var sim := _custom_roofs([{"left": -500.0, "right": 100.0, "top": 100.0}, {"left": 2000.0, "right": 5000.0, "top": 100.0}])
	sim.x = 100.0 + Balance.CAT_FOOT_HALF - 1.0  # 몸 가운데는 옥상 밖, 뒷발은 아직 위
	sim.step(0.0001, false)
	assert_true(sim.on_ground, "뒷발이 걸쳐 있으면 서 있음")
	sim.x = 100.0 + Balance.CAT_FOOT_HALF + 1.0
	sim.step(0.0001, false)
	assert_false(sim.on_ground, "발 범위가 다 지나면 떨어지기 시작")


func test_몸_가운데가_못_미쳐도_앞발이_걸치면_착지() -> void:
	var sim := _custom_roofs([{"left": -500.0, "right": 0.0, "top": 100.0}, {"left": 400.0, "right": 5000.0, "top": 100.0}])
	sim.x = 400.0 - Balance.CAT_FOOT_HALF + 5.0  # 가운데는 옥상 왼쪽 끝보다 앞쪽(왼쪽)
	sim.y = 100.5  # 다음 진행에서 옥상 높이(100)를 지나 내려옴
	sim.vy = -100.0
	sim.on_ground = false
	sim.speed = 0.0
	sim.step(DT, false)
	assert_true(sim.landed, "앞발이 옥상 위면 착지")
	assert_true(sim.x < 400.0, "가운데는 옥상 밖")


## 정해 둔 옥상만 있는 시뮬레이션 (새 옥상이 생기지 않게 마지막 옥상을 아주 길게 둔다)
func _custom_roofs(list: Array) -> RunnerSim:
	var sim := RunnerSim.new(1)
	sim.roofs.clear()
	for roof in list:
		sim.roofs.append(roof)
	sim.roofs[-1].right = 100000.0
	sim.x = -300.0 if list[0].left < -300.0 else list[0].left + 50.0
	sim.y = list[0].top
	sim.vy = 0.0
	sim.on_ground = true
	sim.set("_ground_roof", sim.roofs[0])
	return sim


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
