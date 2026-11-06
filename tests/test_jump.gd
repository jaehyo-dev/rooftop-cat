extends TestCase
## 누르는 시간 → 점프 높이 (최소, 최대, 중간). 계산식과 실제 시뮬레이션이 같은지도 확인한다.

const DT := 1.0 / 120.0


func test_계산식_최소_최대_중간_높이() -> void:
	assert_near(JumpModel.height_for_hold(0.0), Balance.JUMP_MIN_HEIGHT, 0.001, "톡 누르면 최소")
	assert_near(JumpModel.height_for_hold(JumpModel.max_hold_time()), Balance.JUMP_MAX_HEIGHT, 0.001, "최대 시간이면 최대")
	assert_near(JumpModel.height_for_hold(10.0), Balance.JUMP_MAX_HEIGHT, 0.001, "오래 눌러도 최대에서 멈춤")
	var mid := (Balance.JUMP_MIN_HEIGHT + Balance.JUMP_MAX_HEIGHT) * 0.5
	assert_near(JumpModel.height_for_hold(JumpModel.max_hold_time() * 0.5), mid, 0.001, "절반 누르면 중간")


func test_누를수록_높이_뛴다() -> void:
	var last := -1.0
	for i in 11:
		var h := JumpModel.height_for_hold(JumpModel.max_hold_time() * i / 10.0)
		assert_true(h > last, "%d/10 누름" % i)
		last = h


func test_시뮬레이션_톡_누르면_최소_높이() -> void:
	assert_near(_peak_for_hold(DT), Balance.JUMP_MIN_HEIGHT, 6.0)


func test_시뮬레이션_길게_누르면_최대_높이() -> void:
	assert_near(_peak_for_hold(1.0), Balance.JUMP_MAX_HEIGHT, 1.0)


func test_시뮬레이션_중간만큼_누르면_중간_높이() -> void:
	var hold := JumpModel.max_hold_time() * 0.5
	assert_near(_peak_for_hold(hold), JumpModel.height_for_hold(hold), 6.0)


func test_화면_주사율이_달라도_같은_높이() -> void:
	# 고정 간격이 아닌 큰 간격(30fps)으로 진행해도 최대 높이가 같아야 한다
	assert_near(_peak_for_hold(1.0, 1.0 / 30.0), Balance.JUMP_MAX_HEIGHT, 1.0)


func test_최대_점프_거리는_높은_곳일수록_짧다() -> void:
	var speed := Balance.RUN_SPEED
	assert_true(JumpModel.max_reach(speed, 100.0) < JumpModel.max_reach(speed, 0.0))
	assert_true(JumpModel.max_reach(speed, -100.0) > JumpModel.max_reach(speed, 0.0))
	assert_eq(JumpModel.max_reach(speed, Balance.JUMP_MAX_HEIGHT + 1.0), 0.0, "최대 높이보다 높으면 못 닿음")


## 넓은 시작 옥상 위에서 hold초 동안 누른 점프의 최고 높이 (출발 높이 기준)
func _peak_for_hold(hold: float, dt: float = DT) -> float:
	var sim := RunnerSim.new(1)
	var start := sim.y
	var peak := start
	var t := 0.0
	while t < 2.0:
		sim.step(dt, t < hold)
		peak = maxf(peak, sim.y)
		t += dt
		if sim.landed:
			break
	return peak - start


func assert_near(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("기대값 %.2f ± %.2f, 실제값 %.2f" % [expected, tolerance, actual], message)
