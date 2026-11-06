extends TestCase
## 옥상 생성: 간격이 항상 넘을 수 있는 범위 안인지 (속도별), 시드 고정.

const SPEEDS := [250.0, Balance.RUN_SPEED, 700.0, 1000.0]


func test_같은_시드면_같은_옥상() -> void:
	assert_eq(_roofs(42, Balance.RUN_SPEED, 50), _roofs(42, Balance.RUN_SPEED, 50))
	assert_true(_roofs(42, Balance.RUN_SPEED, 50) != _roofs(43, Balance.RUN_SPEED, 50), "다른 시드면 다름")


func test_간격과_높이와_너비가_범위_안() -> void:
	for speed in SPEEDS:
		for seed_value in 5:
			var roofs := _roofs(seed_value, speed, 300)
			for i in range(1, roofs.size()):
				var prev: Dictionary = roofs[i - 1]
				var roof: Dictionary = roofs[i]
				var gap: float = roof.left - prev.right
				var rise: float = roof.top - prev.top
				var where := "속도 %d, 시드 %d, %d번째" % [speed, seed_value, i]
				assert_true(gap >= Balance.ROOF_GAP_MIN, where + " 최소 간격")
				assert_true(gap <= JumpModel.max_reach(speed, rise) * RoofGenerator.gap_safety(speed) + 0.001, where + " 최대 점프로 닿음 (속도별 여유)")
				assert_true(absf(rise) <= Balance.ROOF_TOP_STEP + 0.001, where + " 높이 차")
				assert_true(roof.top >= Balance.ROOF_TOP_MIN and roof.top <= Balance.ROOF_TOP_MAX, where + " 높이")
				var width: float = roof.right - roof.left
				assert_true(width >= RoofGenerator.min_width(speed), where + " 짧은 점프로도 내려앉을 너비")
				assert_true(width <= maxf(Balance.ROOF_WIDTH_MAX, RoofGenerator.min_width(speed) * 1.5), where + " 최대 너비")
				if not failures.is_empty():
					return


func test_간격_여유는_처음엔_좁고_빨라질수록_넓어진다() -> void:
	assert_eq(RoofGenerator.gap_safety(Balance.RUN_SPEED), Balance.ROOF_GAP_SAFETY_START, "처음 속도")
	assert_eq(RoofGenerator.gap_safety(Balance.SPEED_MAX), Balance.ROOF_GAP_SAFETY, "최대 속도")
	assert_eq(RoofGenerator.gap_safety(Balance.SPEED_MAX + 500.0), Balance.ROOF_GAP_SAFETY, "최대 속도보다 빨라도 그대로")
	var middle := RoofGenerator.gap_safety((Balance.RUN_SPEED + Balance.SPEED_MAX) * 0.5)
	assert_true(middle > Balance.ROOF_GAP_SAFETY_START and middle < Balance.ROOF_GAP_SAFETY, "가운데 속도는 그 사이")


func test_가장_높이_올라가는_간격도_최소_간격보다_넓게_닿음() -> void:
	# 최대 거리 x 여유가 최소 간격보다 작으면 max_gap이 최소 간격으로 올려져 못 넘는 간격이 생길 수 있다
	for speed in SPEEDS:
		assert_true(JumpModel.max_reach(speed, Balance.ROOF_TOP_STEP) * RoofGenerator.gap_safety(speed) > Balance.ROOF_GAP_MIN, "속도 %d" % speed)


func test_잘하는_플레이어면_속도별로_한_번도_안_떨어짐() -> void:
	# 최대로 눌러 다음 옥상 앞쪽에 내려앉는 지점에서 뛰는 봇으로 실제 물리 진행을 60초씩 돌린다
	for speed in SPEEDS:
		var sim := RunnerSim.new(7, speed)
		sim.accelerate = false
		var falls := 0
		var hold_left := 0.0
		for i in 120 * 60:
			if sim.on_ground and _should_jump(sim):
				hold_left = JumpModel.max_hold_time() + 1.0 / 120.0
			sim.step(1.0 / 120.0, hold_left > 0.0)
			hold_left -= 1.0 / 120.0
			if sim.fell:
				falls += 1
		assert_eq(falls, 0, "속도 %d에서 떨어진 횟수" % speed)


func test_높은_옥상도_벽에_막히지_않고_넘을_수_있다() -> void:
	# 가장 높이 올라가는 옥상에서, 최대 점프가 그 높이 위에 머무는 동안 가는 거리가
	# 몸 앞쪽~발 범위 차이(벽을 넘은 뒤 내려앉을 여유)보다 넉넉해야 한다
	var v := JumpModel.jump_speed()
	var rise := Balance.ROOF_TOP_STEP
	var t_up := rise / v  # 누르고 있는 동안 같은 속도로 올라가므로 (최소 높이보다 높을 때)
	for speed in SPEEDS:
		var above: float = speed * (JumpModel.max_air_time(rise) - t_up)
		assert_true(above > Balance.CAT_BODY_SIZE.x * 0.5 - Balance.CAT_FOOT_HALF + 30.0, "속도 %d: %.0f" % [speed, above])


## 지금 최대로 뛰면 다음 옥상 앞쪽(앞발이 막 걸치는 곳보다 조금 안)에 내려앉는지
func _should_jump(sim: RunnerSim) -> bool:
	var here := sim.roofs.find(sim.get("_ground_roof"))
	if here < 0 or here + 1 >= sim.roofs.size():
		return false
	var roof: Dictionary = sim.roofs[here]
	var next: Dictionary = sim.roofs[here + 1]
	var land_x := sim.x + sim.speed * JumpModel.max_air_time(next.top - roof.top)
	# 너무 늦으면(발이 끝을 지나기 직전) 바로 뛴다
	var last_chance: bool = sim.x + Balance.CAT_FOOT_HALF - roof.right > -sim.speed / 120.0 * 2.0
	return land_x >= next.left + 20.0 or last_chance


func _roofs(seed_value: int, speed: float, count: int) -> Array:
	var generator := RoofGenerator.new(seed_value)
	var roofs := [RoofGenerator.first_roof(0.0)]
	for i in count:
		roofs.append(generator.next_roof(roofs[-1], speed))
	return roofs
