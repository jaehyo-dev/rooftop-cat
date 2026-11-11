extends TestCase
## 속도 곡선, 최고 기록 저장·불러오기.



func test_속도는_단계_표를_따르고_최대에서_멈춘다() -> void:
	assert_eq(SpeedCurve.speed_at(0.0), 430.0, "처음 속도")
	assert_eq(SpeedCurve.speed_at(-5.0), 430.0, "음수 시간은 처음 속도")
	assert_eq(SpeedCurve.speed_at(13.9), 430.0, "단계 2 전")
	assert_eq(SpeedCurve.speed_at(60.0), 640.0, "1분 뒤")
	assert_eq(SpeedCurve.speed_at(100000.0), 950.0, "최대 속도에서 멈춤")
	assert_eq(Balance.SPEED_STAGES.size(), 12, "단계 12개")
	assert_eq(Balance.SPEED_STAGES[8][0], 200.0, "단계 9는 200초에 최고 속도")
	var prev := 0.0
	var prev_start := -1.0
	for stage in Balance.SPEED_STAGES:
		assert_true(stage[0] > prev_start and stage[1] >= prev, "단계 표는 시각·속도가 줄지 않음")
		prev_start = stage[0]
		prev = stage[1]
		assert_eq(SpeedCurve.speed_at(stage[0] + Balance.SPEED_RAMP_TIME), stage[1], "%.0f초 단계: 오름이 끝나면 표의 속도" % stage[0])


func test_단계가_오르면_정해진_시간에_걸쳐_끊김_없이_빨라진다() -> void:
	assert_eq(SpeedCurve.speed_at(14.0), 430.0, "오르는 순간은 앞 단계 속도")
	assert_true(absf(SpeedCurve.speed_at(14.0 + Balance.SPEED_RAMP_TIME * 0.5) - 465.0) < 0.001, "가운데는 앞뒤 단계의 중간")
	assert_eq(SpeedCurve.speed_at(14.0 + Balance.SPEED_RAMP_TIME), 500.0, "끝나면 다음 단계 속도")
	var prev := Balance.RUN_SPEED
	for i in 660 * 120:
		var v := SpeedCurve.speed_at(i / 120.0)
		assert_true(v >= prev and v - prev < 1.0, "%.2f초: 줄지 않고 한 칸에 1 미만으로 오름 (%.3f → %.3f)" % [i / 120.0, prev, v])
		prev = v


func test_단계_번호와_다음_단계_속도() -> void:
	assert_eq(SpeedCurve.stage_at(0.0), 1)
	assert_eq(SpeedCurve.stage_at(13.99), 1)
	assert_eq(SpeedCurve.stage_at(14.0), 2)
	assert_eq(SpeedCurve.stage_at(100000.0), 12)
	assert_eq(RoofGenerator.arrival_speed(430.0), 500.0, "단계 1 → 2")
	assert_eq(RoofGenerator.arrival_speed(460.0), 500.0, "오르는 중에는 오르는 단계의 속도")
	assert_eq(RoofGenerator.arrival_speed(910.0), 950.0, "단계 8 → 9")
	assert_eq(RoofGenerator.arrival_speed(950.0), 950.0, "최고 속도에서는 그대로")


func test_옥상에_도착하기_전에_단계가_많아야_하나_오른다() -> void:
	# arrival_speed가 다음 단계만 보는 근거: 앞을 만드는 거리를 달리는 시간이 가장 짧은 단계보다 짧다
	for i in range(1, Balance.SPEED_STAGES.size() - 1):
		var length: float = Balance.SPEED_STAGES[i + 1][0] - Balance.SPEED_STAGES[i][0]
		assert_true(Balance.ROOF_LOOKAHEAD / Balance.SPEED_STAGES[i - 1][1] < length, "단계 %d 길이 %.0f초" % [i + 1, length])


func test_속도_단계_신호_값() -> void:
	assert_false(SpeedCurve.rises(1), "단계 1은 오름이 아님")
	for i in range(2, 10):
		assert_true(SpeedCurve.rises(i), "단계 %d는 빨라짐" % i)
	assert_false(SpeedCurve.rises(10), "단계 10은 밀도만")
	assert_false(SpeedCurve.rises(11), "단계 11은 밀도만")
	assert_false(SpeedCurve.rises(12), "단계 12는 밀도만")
	assert_eq(SpeedCurve.music_pitch(1), 1.0, "단계 1은 원래 곡")
	assert_true(absf(SpeedCurve.music_pitch(4) - 1.039) < 0.0001, "단계마다 +1.3%")
	assert_eq(SpeedCurve.music_pitch(12), Balance.MUSIC_PITCH_MAX, "최대")
	assert_true(SpeedCurve.music_pitch(10) <= Balance.MUSIC_PITCH_MAX, "단계 10도 최대 안")
	assert_eq(SpeedCurve.line_strength(2, 99.0), 0.0, "단계 2까지 평소에는 없음")
	assert_eq(SpeedCurve.line_strength(2, 0.0), 1.0, "오른 직후에는 진함")
	assert_eq(SpeedCurve.line_strength(3, 99.0), Balance.SPEED_LINE_REST_MIN, "단계 3부터 옅게 남음")
	assert_eq(SpeedCurve.line_strength(10, 99.0), Balance.SPEED_LINE_REST_MAX, "단계에 비례")
	assert_eq(SpeedCurve.line_strength(12, 99.0), Balance.SPEED_LINE_REST_MAX, "단계 10 뒤로는 그대로")
	assert_eq(SpeedCurve.line_strength(3, Balance.SPEED_RAMP_TIME - Balance.SPEED_LINE_FADE), 1.0, "끝나기 전까지 진함")
	assert_eq(SpeedCurve.line_strength(3, Balance.SPEED_RAMP_TIME), Balance.SPEED_LINE_REST_MIN, "1.2초 뒤에는 옅은 선으로")


func test_콤보는_연속으로_먹으면_배수가_오르고_x5에서_멈춘다() -> void:
	var combo := FishCombo.new()
	assert_eq(combo.multiplier(), 1)
	for i in Balance.COMBO_STEP - 1:
		combo.eat(10)
	assert_eq(combo.points, 10 * (Balance.COMBO_STEP - 1), "x1")
	combo.eat(10)
	assert_eq(combo.multiplier(), 2, "COMBO_STEP개째부터 x2")
	assert_eq(combo.points, 10 * (Balance.COMBO_STEP - 1) + 20, "오른 배수로 더함")
	for i in Balance.COMBO_STEP * 10:
		combo.eat(10)
	assert_eq(combo.multiplier(), Balance.COMBO_MAX, "최대 x5")
	var best := combo.count
	combo.cut()
	assert_eq(combo.count, 0)
	assert_eq(combo.best, best, "최고 콤보는 남음")
	assert_eq(combo.multiplier(), 1)


func test_콤보는_일정_시간_못_먹으면_끊기고_먹으면_시간이_다시_시작된다() -> void:
	var combo := FishCombo.new()
	combo.eat(10)
	combo.tick(Balance.COMBO_TIMEOUT - 0.1)
	combo.eat(10)
	combo.tick(Balance.COMBO_TIMEOUT - 0.1)
	assert_eq(combo.count, 2, "먹으면 다시 셈")
	combo.tick(0.2)
	assert_eq(combo.count, 0, "시간 초과")


## 생선 하나를 앞에 둔 sim
func _fish_sim(bonus: bool) -> RunnerSim:
	var sim := RunnerSim.new(1, Balance.RUN_SPEED, false)
	sim.accelerate = false
	sim.roofs[0].right = 90000.0
	sim.items.clear()
	sim.combo.count = 5
	var fish := {"kind": "fish", "x": sim.x + 200.0, "y": sim.y + 400.0}
	if bonus:
		fish.bonus = true
	sim.items.append(fish)
	return sim


func test_필수_생선을_놓치면_끊기고_보너스와_질주_털실은_안_끊긴다() -> void:
	var cases := {"필수": [false, ""], "보너스": [true, ""], "질주": [false, "dash"], "털실은 끌어오지 못해도": [false, "yarn"], "투명화": [false, "ghost"]}
	for name: String in cases:
		var sim := _fish_sim(cases[name][0])
		match cases[name][1]:
			"dash":
				var missed := sim.items[0]
				sim._start_dash()
				sim.items.assign([missed])  # 질주가 앞쪽 생선을 바꿔 까므로 놓칠 생선만 다시 놓는다
			"yarn":
				sim.magnet_time = 99.0
				sim.items[0].y = sim.y + 3000.0
			"ghost":
				sim.ghost_time = 99.0
		for i in 100:
			sim.step(1.0 / 120.0, false)
		assert_true(sim.x > sim.items[0].x + 150.0, name + ": 지나감")
		assert_eq(sim.combo.count, 0 if name == "필수" else 5, name)


func test_같은_step에_놓치고_먹으면_끊긴_뒤_먹은_것으로_친다() -> void:
	var sim := RunnerSim.new(1, Balance.RUN_SPEED, false)
	sim.accelerate = false
	sim.roofs[0].right = 90000.0
	sim.items.clear()
	sim.combo.count = Balance.COMBO_STEP - 1
	# 배열 앞 = 지금 놓치는 생선, 뒤 = 지금 먹는 생선 (역순으로 돌아 먹는 쪽을 먼저 본다)
	sim.items.append({"kind": "fish", "x": sim.x - 120.0, "y": sim.y + 400.0})
	sim.items.append({"kind": "fish", "x": sim.x + 10.0, "y": sim.y + Balance.ITEM_LIFT})
	sim.step(1.0 / 120.0, false)
	assert_eq(sim.combo.count, 1, "끊긴 뒤 하나")
	assert_eq(sim.combo.points, Balance.FISH_POINTS, "x1 점수")


func test_부딪히면_콤보가_끊기고_방울이_막으면_안_끊긴다() -> void:
	for bell in [false, true]:
		var sim := _fish_sim(true)
		sim.has_bell = bell
		sim.obstacles = [{"id": 0, "kind": "ac", "x": sim.x + 100.0, "w": 110.0, "y0": sim.y, "y1": sim.y + 88.0, "base": sim.y}] as Array[Dictionary]
		for i in 40:
			sim.step(1.0 / 120.0, false)
		assert_true(sim.obstacles.is_empty(), "부딪힘")
		assert_eq(sim.combo.count, 5 if bell else 0)


func test_점수는_거리와_생선_점수의_합이고_황금은_크다() -> void:
	var sim := RunnerSim.new(1, Balance.RUN_SPEED, false)
	sim.accelerate = false
	sim.items.clear()
	sim.items.append({"kind": "fish", "x": sim.x + 80.0, "y": sim.y + Balance.ITEM_LIFT})
	sim.items.append({"kind": "gold", "x": sim.x + 150.0, "y": sim.y + Balance.ITEM_LIFT})
	for i in 60:
		sim.step(1.0 / 120.0, false)
	assert_eq(sim.combo.points, Balance.FISH_POINTS + Balance.GOLD_POINTS)
	assert_eq(sim.fish, 1 + Balance.GOLD_FISH)
	assert_eq(sim.score(), sim.distance() + sim.combo.points)
