extends TestCase
## 더블점프: 누른 시간에 비례한 높이(최소 70·최대 130), 한 번만, 꼭대기 떠 있음, 프레임 간격 무관,
## 다시 생기는 때(옥상·판·투명화·구제 뒤 착지), 코요테 뒤 공중 누름, 착지 직전 누름 처리와 예측 빗나감, 투명화·구제 중 금지,
## 가장 멀리 가는 거리 계산이 시뮬레이션과 같은지.

const DT := 1.0 / 120.0
## 꼭대기에서 중력이 줄어 더 올라가는 높이: f^2/g - f^2/(2g)
const FLOAT_BONUS := Balance.DOUBLE_FLOAT_SPEED * Balance.DOUBLE_FLOAT_SPEED / (2.0 * Balance.GRAVITY)


## 공중(높이 y)에 떠 있는 고양이 (속도 0). roofs 뒤에 아주 먼 옥상을 하나 더 둔다
func _air(y: float, roofs: Array = [], vy: float = 0.0) -> RunnerSim:
	var sim := RunnerSim.new(1)
	sim.accelerate = false
	sim.items.clear()
	sim.structures.clear()
	sim.roofs.clear()
	for r in roofs:
		sim.roofs.append(r)
	sim.roofs.append({"left": 100000.0, "right": 200000.0, "top": 0.0})  # 아주 먼 옥상 (새 옥상 생성을 막는 용도)
	sim.speed = 0.0
	sim.x = 0.0
	sim.on_ground = false
	sim.set("_jumped", true)
	sim.y = y
	sim.vy = vy
	return sim


## 공중에서 hold초 누른 더블점프의 (최고 높이 - 누른 높이)
func _double_peak(hold: float, dt: float = DT) -> float:
	var sim := _air(2000.0)
	var start := sim.y
	var peak := start
	var t := 0.0
	var doubled := false
	while t < 1.0:
		sim.step(dt, t < hold)
		doubled = doubled or sim.double_jumped
		peak = maxf(peak, sim.y)
		t += dt
	assert_true(doubled, "더블점프 씀")
	return peak - start


func test_더블점프_높이는_누른_시간에_비례하고_최소_70_최대_130() -> void:
	assert_near(_double_peak(DT), Balance.JUMP_MIN_HEIGHT + FLOAT_BONUS, 6.0, "톡")
	assert_near(_double_peak(1.0), Balance.DOUBLE_JUMP_MAX_HEIGHT + FLOAT_BONUS, 1.0, "길게 눌러도 최대에서 멈춤")
	var half := JumpModel.double_max_hold() * 0.5
	assert_near(_double_peak(half), Balance.JUMP_MIN_HEIGHT + JumpModel.jump_speed() * half + FLOAT_BONUS, 6.0, "절반")
	assert_true(_double_peak(half) > _double_peak(DT) and _double_peak(1.0) > _double_peak(half), "누를수록 높이")


func test_떨어지던_속도를_지우고_다시_올라간다() -> void:
	var sim := _air(2000.0, [], -900.0)
	sim.step(DT, true)
	assert_true(sim.double_jumped and sim.vy > 0.0, "떨어지는 중에도 바로 위로")


func test_공중에서_한_번만() -> void:
	var sim := _air(2000.0)
	var count := 0
	for i in 120:
		sim.step(DT, i % 20 < 3)  # 여러 번 새로 누름
		if sim.double_jumped:
			count += 1
	assert_eq(count, 1)


func test_더블점프_꼭대기에서_잠깐_떠_있다() -> void:
	# |세로 속도| < 160인 시간: 보통 중력이면 0.1초, 떠 있음(0.5배)이면 0.2초
	var sim := _air(2000.0)
	var slow := 0.0
	for i in 120:
		sim.step(DT, i == 0)
		if absf(sim.vy) < Balance.DOUBLE_FLOAT_SPEED:
			slow += DT
	var expected := 2.0 * Balance.DOUBLE_FLOAT_SPEED / (Balance.GRAVITY * Balance.DOUBLE_FLOAT_GRAVITY)
	assert_near(slow, expected, DT * 1.5, "떠 있는 시간")


func test_프레임_간격이_달라도_더블점프_궤적이_같다() -> void:
	# 1/60·1/120·1/240초 간격으로 같은 입력(처음부터 길게 누름 → 0.5초에 떼었다 다시 누름은 없음)을 주면 같은 시각의 높이가 같다
	var traces := []
	for dt in [1.0 / 60.0, 1.0 / 120.0, 1.0 / 240.0]:
		var sim := _air(2000.0)
		var trace := []
		var steps_per_60 := roundi((1.0 / 60.0) / dt)
		for i in roundi(0.9 / dt):
			sim.step(dt, i * dt < 0.5)
			if (i + 1) % steps_per_60 == 0:
				trace.append(sim.y)
		traces.append(trace)
	for k in traces[0].size():
		assert_near(traces[1][k], traces[0][k], 0.01, "1/120 vs 1/60, %d번째" % k)
		assert_near(traces[2][k], traces[0][k], 0.01, "1/240 vs 1/60, %d번째" % k)


func test_옥상이나_판에_서면_다시_생긴다() -> void:
	for platform in [false, true]:
		var roof := {"left": -500.0, "right": 500.0, "top": 100.0, "platform": platform}
		var sim := _air(300.0, [roof])
		sim.step(DT, true)  # 더블점프
		assert_true(sim.double_jumped)
		var landed := false
		for i in 240:
			sim.step(DT, false)
			if sim.landed:
				landed = true
				break
		assert_true(landed and not sim.get("_double_used"), "판 %s: 서면 다시 생김" % str(platform))


func test_코요테가_지나면_공중_누름은_더블점프이고_점프한_것으로_친다() -> void:
	for wait in [0.0, Balance.COYOTE_TIME + 2.0 * DT]:
		# 옥상 끝을 달려 지나 발밑이 빈 뒤 wait초 기다렸다 누른다 (앞은 넓은 틈)
		var sim := _air(200.0, [{"left": -2000.0, "right": 0.0, "top": 200.0}])
		sim.speed = 430.0
		sim.x = -10.0
		sim.on_ground = true
		sim.set("_jumped", false)
		sim.set("_ground_roof", sim.roofs[0])
		while sim.on_ground:
			sim.step(DT, false)
		for i in roundi(wait / DT):
			sim.step(DT, false)
		sim.step(DT, true)
		if wait == 0.0:
			assert_true(sim.jumped and not sim.double_jumped, "코요테 안이면 보통 점프")
		else:
			assert_true(sim.double_jumped and sim.get("_jumped"), "코요테 뒤면 더블점프 + 점프함 (모서리 투명화 구제 받음)")


func test_착지_직전_누름은_더블점프가_아니라_착지하자마자_점프() -> void:
	var roof := {"left": -500.0, "right": 500.0, "top": 100.0}
	var sim := _air(100.0 + 40.0, [roof], -800.0)  # 약 0.05초 뒤 착지
	sim.step(DT, true)
	assert_true(not sim.double_jumped, "더블점프로 쓰지 않음")
	var jumped_after_land := false
	var landed := false
	for i in 30:
		sim.step(DT, false)
		landed = landed or sim.landed
		if landed and sim.jumped:
			jumped_after_land = true
			break
	assert_true(landed and jumped_after_land, "착지하자마자 점프")
	assert_true(not sim.get("_double_used"), "더블점프는 그대로 남음")


func test_착지_예측이_빗나가_발판_높이를_지나면_바로_더블점프() -> void:
	# 옥상 끝 근처로 내려오며 누름 → 착지로 남겨 둠. 그런데 속도가 빨라져 옥상을 지나치면 높이를 지나는 step에 더블점프
	var roof := {"left": -500.0, "right": 60.0, "top": 100.0}
	var sim := _air(100.0 + 40.0, [roof], -800.0)
	sim.speed = 100.0
	sim.step(DT, true)
	assert_true(not sim.double_jumped and not is_nan(sim.get("_held_top")), "착지로 남겨 둠")
	sim.speed = 4000.0  # 예측보다 훨씬 앞으로 감 (발이 옥상을 벗어남)
	var doubled_at_y := INF
	for i in 30:
		sim.step(DT, false)
		if sim.double_jumped:
			doubled_at_y = sim.y
			break
		assert_true(not sim.landed, "착지하지 못함")
	assert_true(doubled_at_y < 100.0 and doubled_at_y > 100.0 - 20.0, "옥상 높이를 막 지난 step에 더블점프 (y=%.1f)" % doubled_at_y)


func test_투명화로_떠오르는_중과_구제_중에는_더블점프_안_됨() -> void:
	var roof := {"left": -500.0, "right": 500.0, "top": 300.0}
	var sim := _air(200.0, [roof])
	sim.ghost_time = 1.0
	sim.set("_ghost_roof", roof)
	sim.step(DT, true)
	assert_true(not sim.double_jumped, "투명화로 떠오르는 중")
	var rescue := _air(-10.0)
	rescue.rescuing = true
	rescue.step(DT, true)
	assert_true(not rescue.double_jumped, "구제 중")


func test_투명화와_구제_뒤_착지하면_다시_생긴다() -> void:
	var roof := {"left": -500.0, "right": 500.0, "top": 300.0}
	var sim := _air(250.0, [roof])
	sim.set("_double_used", true)
	sim.ghost_time = 1.0
	sim.set("_ghost_roof", roof)
	for i in 60:
		sim.step(DT, false)
		if sim.landed:
			break
	assert_true(sim.on_ground and not sim.get("_double_used"), "투명화로 올라서면 다시 생김")
	var rescue := RunnerSim.new(1)
	rescue.accelerate = false
	rescue.items.clear()
	rescue.has_box = true
	rescue.set("_double_used", true)
	rescue.on_ground = false
	rescue.x = rescue.roofs[0].right + 300.0
	rescue.y = 1.0
	rescue.vy = -200.0
	var rescued := false
	for i in 600:
		rescue.step(DT, false)
		rescued = rescued or rescue.rescued
		if rescued and rescue.landed:
			break
	assert_true(rescued and rescue.on_ground and not rescue.get("_double_used"), "구제 뒤 착지하면 다시 생김")


func test_가장_멀리_가는_더블점프_계산과_시뮬레이션이_같다() -> void:
	var best := JumpModel.best_double(JumpModel.jump_speed(), JumpModel.max_hold_time(), 0.0)
	assert_near(best.x, 1.56, 0.02, "점프 + 더블점프 최대 체공 (PLAN 1.56초)")
	assert_true(best.x > JumpModel.max_air_time(0.0) * 1.7, "한 번 점프의 1.7배 이상")
	var v := JumpModel.jump_speed()
	var hold := JumpModel.max_hold_time()
	var apex := JumpModel.double_total_time(v, hold, hold + v / Balance.GRAVITY, 0.0)
	var ratio := apex / best.x
	assert_true(ratio > 0.85 and ratio < 0.9, "꼭대기에서 쓰면 최대의 0.86~0.88배 (%.3f)" % ratio)
	assert_true(JumpModel.max_double_reach(430.0, 0.0) > JumpModel.max_reach(430.0, 0.0))
	# 시뮬레이션: 그 시각에 더블점프하면 출발 높이로 돌아오는 시간이 계산과 같다
	# (뛰자마자 옥상을 벗어나 틈 위에서 더블점프하도록 달리게 한다. 뒤쪽 아주 먼 옥상은 새 옥상 생성을 막는 용도)
	var sim := _air(200.0, [{"left": -2000.0, "right": 0.0, "top": 200.0}])
	sim.speed = 430.0
	sim.on_ground = true
	sim.set("_ground_roof", sim.roofs[0])
	var t := 0.0
	var dj_step := roundi(best.y / DT)
	var back := -1.0
	for i in roundi(2.0 / DT):
		var pressed := i * DT <= hold + DT or (i >= dj_step and i * DT <= best.y + JumpModel.double_max_hold() + DT)
		sim.step(DT, pressed)
		t += DT
		if i > dj_step and sim.y < 200.0:
			back = t
			break
	assert_near(back, best.x, DT * 1.5, "시뮬레이션 체공")


func assert_near(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("기대값 %.3f ± %.3f, 실제값 %.3f" % [expected, tolerance, actual], message)
