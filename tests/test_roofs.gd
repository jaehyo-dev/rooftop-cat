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
				assert_true(gap <= JumpModel.max_reach(speed, rise) * Balance.ROOF_GAP_SAFETY + 0.001, where + " 최대 점프로 닿음")
				assert_true(absf(rise) <= Balance.ROOF_TOP_STEP + 0.001, where + " 높이 차")
				assert_true(roof.top >= Balance.ROOF_TOP_MIN and roof.top <= Balance.ROOF_TOP_MAX, where + " 높이")
				var width: float = roof.right - roof.left
				assert_true(width >= RoofGenerator.min_width(speed), where + " 짧은 점프로도 내려앉을 너비")
				assert_true(width <= maxf(Balance.ROOF_WIDTH_MAX, RoofGenerator.min_width(speed) * 1.5), where + " 최대 너비")
				if not failures.is_empty():
					return


func test_가장_높이_올라가는_간격도_최소_간격보다_넓게_닿음() -> void:
	# 최대 거리 x 여유가 최소 간격보다 작으면 max_gap이 최소 간격으로 올려져 못 넘는 간격이 생길 수 있다
	for speed in SPEEDS:
		assert_true(JumpModel.max_reach(speed, Balance.ROOF_TOP_STEP) * Balance.ROOF_GAP_SAFETY > Balance.ROOF_GAP_MIN, "속도 %d" % speed)


func test_잘하는_플레이어면_속도별로_한_번도_안_떨어짐() -> void:
	# 옥상 끝에서 다음 옥상 가운데에 내려앉을 만큼 누르는 봇으로 실제 물리 진행을 60초씩 돌린다
	for speed in SPEEDS:
		var sim := RunnerSim.new(7, speed)
		var falls := 0
		var hold_left := 0.0
		for i in 120 * 60:
			var roof := sim.roof_at(sim.x)
			if sim.on_ground and not roof.is_empty() and roof.right - sim.x <= speed / 120.0 * 1.5:
				hold_left = _hold_to_land_middle(sim, roof) + 1.0 / 120.0
			sim.step(1.0 / 120.0, hold_left > 0.0)
			hold_left -= 1.0 / 120.0
			if sim.fell:
				falls += 1
		assert_eq(falls, 0, "속도 %d에서 떨어진 횟수" % speed)


## 다음 옥상 가운데에 내려앉으려면 누를 시간 (이분 탐색)
func _hold_to_land_middle(sim: RunnerSim, roof: Dictionary) -> float:
	var next: Dictionary = sim.roofs[sim.roofs.find(roof) + 1]
	var target: float = (next.left + next.right) * 0.5 - sim.x
	var rise: float = next.top - roof.top
	var low := 0.0
	var high := JumpModel.max_hold_time()
	for i in 30:
		var mid := (low + high) * 0.5
		var t := JumpModel.air_time(mid, rise)
		if t < 0.0 or sim.speed * t < target:
			low = mid
		else:
			high = mid
	return high


func _roofs(seed_value: int, speed: float, count: int) -> Array:
	var generator := RoofGenerator.new(seed_value)
	var roofs := [RoofGenerator.first_roof(0.0)]
	for i in count:
		roofs.append(generator.next_roof(roofs[-1], speed))
	return roofs
