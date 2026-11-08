extends TestCase
## 옥상 생성: 간격이 항상 넘을 수 있는 범위 안인지 (속도별), 시드 고정.

const BalanceBot := preload("res://tests/balance_bot.gd")
var SPEEDS := stage_speeds()


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
				if roof.has("line") or roof.has("tramp") or roof.get("platform", false) or prev.get("platform", false):
					continue  # 특수 틈은 tests/test_structures.gd에서 확인 (일반 틈보다 넓고, 판은 너비 제한 없음)
				assert_true(gap <= JumpModel.max_reach(speed, rise) * RoofGenerator.gap_safety(speed) + 0.001, where + " 최대 점프로 닿음 (속도별 여유)")
				assert_true(absf(rise) <= Balance.ROOF_TOP_STEP + 0.001, where + " 높이 차")
				assert_true(roof.top >= Balance.ROOF_TOP_MIN and roof.top <= Balance.ROOF_TOP_MAX, where + " 높이")
				var width: float = roof.right - roof.left
				assert_true(width >= RoofGenerator.min_width(RoofGenerator.arrival_speed(speed)), where + " 다음 단계 속도로 짧게 뛰어도 내려앉을 너비")
				assert_true(width <= maxf(Balance.ROOF_WIDTH_MAX, RoofGenerator.min_width(RoofGenerator.arrival_speed(speed)) * 1.5), where + " 최대 너비")
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
	# 실수 없는 봇(특수 틈 포함)으로 실제 물리 진행을 속도를 고정해 60초씩 돌린다
	for speed in SPEEDS:
		for seed_value in 5:
			assert_eq(BalanceBot.play({"timing": 0.0, "short_hold": 0.0}, seed_value + 1, 60.0, speed, false), 60.0, "속도 %d, 시드 %d" % [speed, seed_value + 1])


func test_높은_옥상도_벽에_막히지_않고_넘을_수_있다() -> void:
	# 가장 높이 올라가는 옥상에서, 최대 점프가 그 높이 위에 머무는 동안 가는 거리가
	# 몸 앞쪽~발 범위 차이(벽을 넘은 뒤 내려앉을 여유)보다 넉넉해야 한다
	var v := JumpModel.jump_speed()
	var rise := Balance.ROOF_TOP_STEP
	var t_up := rise / v  # 누르고 있는 동안 같은 속도로 올라가므로 (최소 높이보다 높을 때)
	for speed in SPEEDS:
		var above: float = speed * (JumpModel.max_air_time(rise) - t_up)
		assert_true(above > Balance.CAT_BODY_SIZE.x * 0.5 - Balance.CAT_FOOT_HALF + 30.0, "속도 %d: %.0f" % [speed, above])


func _roofs(seed_value: int, speed: float, count: int) -> Array:
	var generator := RoofGenerator.new(seed_value)
	var roofs := [RoofGenerator.first_roof(0.0)]
	for i in count:
		roofs.append(generator.next_roof(roofs[-1], speed))
	return roofs
