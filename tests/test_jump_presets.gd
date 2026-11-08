extends TestCase
## 점프 무게 설정 A·B·C: 실제 수치, 높이는 그대로·체공은 목표대로, 포물선과 손 뗌, 프레임 간격 무관,
## 넓은 틈·전봇대 판·트램펄린 발사·생선 위치가 설정마다 맞게 계산되는지.

const BalanceBot := preload("res://tests/balance_bot.gd")
const STRUCTURES := preload("res://tests/test_structures.gd")
## 넓은 틈·판·트램펄린 테스트: 설정마다 기존 test_structures 테스트를 그대로 돌린다
const GAP_TESTS := [
	&"test_트램펄린_틈은_트램펄린_없이_더블점프까지_다_써도_못_건너고_뛰어넘으면_떨어진다",
	&"test_트램펄린을_누르며_밟으면_달려_들어가도_뛰어서_떨어져도_반드시_건넌다",
	&"test_트램펄린_다음_옥상은_가장_늦게_튕기고_더블점프를_가장_멀리_써도_안_지나친다",
	&"test_트램펄린_누름_퍼펙트는_앞으로_발사하고_더블점프를_다시_준다",
	&"test_트램펄린_퍼펙트는_높은_생선_길을_지나고_누름은_못_먹는다",
	&"test_전봇대_틈은_더블점프까지_써도_판_없이_못_건너고_판을_거쳐_갈_수_있다",
	&"test_판_앞뒤_틈은_화면에_보이는_거리_이하",
	&"test_판에서_다음_옥상까지는_판_끝에서_늦게_뛰어도_코요테로_닿는다",
]


## 설정마다 body를 부르고 A로 되돌린다 (정적 값이라 다른 테스트에 번지지 않게)
func _each(body: Callable) -> void:
	for preset_name in Balance.JUMP_PRESETS:
		JumpModel.use_preset(preset_name)
		body.call(preset_name)
	JumpModel.use_preset("A")


## 끝없는 평지 옥상에 선 고양이 (제자리, 속도 0)
func _flat() -> RunnerSim:
	var sim := RunnerSim.new(1)
	sim.accelerate = false
	sim.speed = 0.0
	sim.items.clear()
	sim.structures.clear()
	sim.roofs.clear()
	var roof := {"left": -100000.0, "right": 100000.0, "top": 0.0}
	sim.roofs.append(roof)
	sim.set("_ground_roof", roof)
	sim.x = 0.0
	sim.y = 0.0
	return sim


## t초에 누르고 있는지를 press(t)로 받아 dt 간격으로 착지까지 돌린다. {"peak", "land", "at": 샘플 시각(1/60초 단위)의 높이}
func _run(press: Callable, dt: float) -> Dictionary:
	var sim := _flat()
	var out := {"peak": 0.0, "land": -1.0, "at": []}
	var per_tick := roundi((1.0 / 60.0) / dt)
	for i in int(3.0 / dt):
		sim.step(dt, press.call(i * dt + 1e-6))
		out.peak = maxf(out.peak, sim.y)
		if (i + 1) % per_tick == 0:
			out.at.append(sim.y)
		if sim.landed:
			out.land = (i + 1) * dt
			break
	return out


func test_A는_지금_값_그대로() -> void:
	assert_near(JumpModel.gravity(), 3200.0, 0.001)
	assert_near(JumpModel.hold_gravity(), 0.0, 0.001)
	assert_near(JumpModel.jump_speed(), sqrt(2.0 * 3200.0 * 70.0), 0.001)
	assert_near(JumpModel.max_hold_time(), 180.0 / sqrt(2.0 * 3200.0 * 70.0), 0.0001)
	assert_near(JumpModel.float_gravity(), 0.5, 0.001)


func test_설정별_중력과_체공은_목표대로() -> void:
	_each(func(p: String) -> void:
		var target: Dictionary = Balance.JUMP_PRESETS[p]
		print("    설정 %s: 올라갈 때 중력 %.0f, 떨어질 때 %.0f, 출발 속도 %.0f (더블 %.0f), 최대 누름 %.3f초, 톡 점프 체공 %.3f초, 최대 체공 %.3f초" % [
				p, JumpModel.hold_gravity(), JumpModel.gravity(), JumpModel.jump_speed(), JumpModel.double_speed(), JumpModel.max_hold_time(), JumpModel.air_time(0.0, 0.0), JumpModel.max_air_time(0.0)])
		if target.has("max_air"):
			assert_near(JumpModel.gravity() / JumpModel.hold_gravity(), target.fall_ratio, 0.0001, p)
			assert_near(JumpModel.max_air_time(0.0), target.max_air, 0.0001, p)
		assert_near(JumpModel.float_gravity(), target.float_gravity, 0.0001, p)
	)


func test_최소_최대_높이는_어느_설정이든_같다() -> void:
	_each(func(p: String) -> void:
		assert_near(JumpModel.height_for_hold(0.0), Balance.JUMP_MIN_HEIGHT, 0.001, p + " 톡")
		assert_near(JumpModel.height_for_hold(JumpModel.max_hold_time()), Balance.JUMP_MAX_HEIGHT, 0.001, p + " 최대")
		assert_near(JumpModel.height_for_hold(5.0), Balance.JUMP_MAX_HEIGHT, 0.001, p + " 더 눌러도 최대")
		var dv := JumpModel.double_speed()
		var top := JumpModel.released_state(dv, JumpModel.double_max_hold())
		assert_near(top.x + top.y * top.y / (2.0 * JumpModel.gravity()), Balance.DOUBLE_JUMP_MAX_HEIGHT, 0.001, p + " 더블 최대")
		var tap := JumpModel.released_state(dv, 0.0)
		assert_near(tap.y * tap.y / (2.0 * JumpModel.gravity()), Balance.JUMP_MIN_HEIGHT, 0.001, p + " 더블 톡")
		# 실제 시뮬레이션: 끝까지 누른 높이
		var peak: float = _run(func(_t: float) -> bool: return true, 1.0 / 240.0).peak
		assert_near(peak, Balance.JUMP_MAX_HEIGHT, 0.5, p + " 시뮬레이션 최대")
	)


func test_누른_시간이_길수록_높이가_줄지_않는다() -> void:
	_each(func(p: String) -> void:
		var prev := 0.0
		for i in 101:
			var h := JumpModel.height_for_hold(JumpModel.max_hold_time() * i / 100.0)
			assert_true(h >= prev - 0.0001, "%s %d" % [p, i])
			prev = h
	)


func test_BC는_올라갈_때_처음이_가장_빠르고_꼭대기에서_느려진다() -> void:
	for p in ["B", "C"]:
		JumpModel.use_preset(p)
		var sim := _flat()
		var dt := 1.0 / 120.0
		sim.step(dt, true)
		var prev_vy := sim.vy
		assert_true(prev_vy > JumpModel.jump_speed() * 0.9, p + " 첫 step이 거의 출발 속도")
		while sim.vy > 0.0:
			sim.step(dt, true)
			assert_true(sim.vy < prev_vy, p + " 계속 느려짐")
			prev_vy = sim.vy
	JumpModel.use_preset("A")


func test_BC는_손을_떼면_바로_꺾이고_톡은_최소_높이() -> void:
	for p in ["B", "C"]:
		JumpModel.use_preset(p)
		for hold in [0.10, 0.15, 0.2]:
			var sim := _flat()
			var dt := 1.0 / 240.0
			for i in int(hold / dt):
				sim.step(dt, true)
			var at_release := sim.y
			var turned := 0.0
			while sim.vy > 0.0 or turned == 0.0:
				sim.step(dt, false)
				turned += dt
			assert_true(sim.y - maxf(at_release, 0.0) <= maxf(Balance.JUMP_CUT_RISE, Balance.JUMP_MIN_HEIGHT - at_release) + 0.5, "%s 누름 %.2f: %.0f에서 뗐는데 %.0f까지" % [p, hold, at_release, sim.y])
			assert_true(turned < 0.17, "%s 누름 %.2f: 꺾일 때까지 %.3f초" % [p, hold, turned])
		# 착지 직전에 톡 눌러 남겨 둔 입력 = 뗀 채로 뛰는 점프 → 최소 높이
		var sim := _flat()
		sim.call("_start_jump", false)
		var peak := 0.0
		for i in 200:
			sim.step(1.0 / 240.0, false)
			peak = maxf(peak, sim.y)
		assert_near(peak, Balance.JUMP_MIN_HEIGHT, 0.5, p + " 버퍼 톡")
	JumpModel.use_preset("A")


func test_더블점프_떠_있음은_A_0_5배_B_0_75배_C_없음() -> void:
	_each(func(p: String) -> void:
		# 더블점프 궤적으로 떠 있는 구간을 지나는 시간
		var y := 500.0
		var vy := Balance.DOUBLE_FLOAT_SPEED - 0.001
		var t := 0.0
		while vy > -Balance.DOUBLE_FLOAT_SPEED:
			var s := JumpModel.integrate(y, vy, 1.0 / 240.0, true)
			y = s.x
			vy = s.y
			t += 1.0 / 240.0
		var expected: float = 2.0 * Balance.DOUBLE_FLOAT_SPEED / (JumpModel.gravity() * Balance.JUMP_PRESETS[p].float_gravity)
		assert_near(t, expected, 1.0 / 120.0, p)
	)


func test_프레임_간격이_달라도_궤적이_같다() -> void:
	var cases := {
		"최대": func(t: float) -> bool: return t < 0.5,
		"짧게": func(t: float) -> bool: return t < 3.0 / 60.0,
		"중간": func(t: float) -> bool: return t < 10.0 / 60.0,
		"더블": func(t: float) -> bool: return t < 12.0 / 60.0 or (t >= 24.0 / 60.0 and t < 30.0 / 60.0),
	}
	_each(func(p: String) -> void:
		for case_name in cases:
			var base := _run(cases[case_name], 1.0 / 240.0)
			for dt in [1.0 / 60.0, 1.0 / 120.0]:
				var run := _run(cases[case_name], dt)
				var label := "%s %s 1/%d" % [p, case_name, roundi(1.0 / dt)]
				assert_near(run.land, base.land, 1.0 / 60.0, label + " 착지 시각")
				for i in mini(run.at.size(), base.at.size()) - 1:
					# 착지 전 샘플끼리 비교 (첫 샘플은 누르는 step 순서가 같아 그대로 비교 가능)
					assert_near(run.at[i], base.at[i], 0.01, "%s 샘플 %d" % [label, i])
	)


func test_체공_계산은_시뮬레이션과_같다() -> void:
	_each(func(p: String) -> void:
		for hold in [0.0, 0.1, 0.25, JumpModel.max_hold_time()]:
			var ticks := roundi(hold * 240.0)
			var run := _run(func(t: float) -> bool: return t < ticks / 240.0, 1.0 / 240.0)
			if ticks == 0:
				continue  # 시뮬레이션의 누름은 최소 한 step
			assert_near(run.land, JumpModel.air_time(ticks / 240.0, 0.0), 2.0 / 240.0, "%s 누름 %.3f" % [p, hold])
		var hold_max := JumpModel.max_hold_time()
		var double_hold := JumpModel.double_max_hold()
		var press_at := JumpModel.apex_time(hold_max) + 0.05  # 꼭대기를 살짝 지나 더블점프 (평지라 더 늦으면 내려앉음)
		var run2 := _run(func(t: float) -> bool: return t < hold_max or (t >= press_at and t < press_at + double_hold), 1.0 / 240.0)
		assert_near(run2.land, JumpModel.double_total_time(JumpModel.jump_speed(), hold_max, press_at, 0.0), 3.0 / 240.0, p + " 더블점프 체공")
		assert_true(JumpModel.best_double(JumpModel.jump_speed(), hold_max, 0.0).x > JumpModel.max_air_time(0.0) * 1.3, p + " 더블점프가 더 멀리 감")
	)


func test_넓은_틈_판_트램펄린_생선은_설정마다_맞다() -> void:
	var base: TestCase = STRUCTURES.new()
	add_child(base)
	_each(func(p: String) -> void:
		for test_name in GAP_TESTS:
			base.failures.clear()
			base.call(test_name)
			for failure in base.failures:
				_fail(failure, "%s %s" % [p, test_name])
	)
	base.queue_free()


func test_설정이_바뀌면_틈과_발사_속도가_체공에_맞춰_바뀐다() -> void:
	var values := {}
	_each(func(p: String) -> void:
		values[p] = {"gap": RoofGenerator.clear_gap(430.0, 0.0), "flight": RoofGenerator.tramp_flight(Balance.TRAMP_GOOD_HEIGHT)}
		var expected := 2.0 * sqrt(2.0 * Balance.TRAMP_GOOD_HEIGHT / JumpModel.gravity())
		assert_near(RoofGenerator.tramp_flight(Balance.TRAMP_GOOD_HEIGHT), expected, 0.02, p + " 튕김 체공은 지금 중력으로")
	)
	assert_true(values.B.gap < values.A.gap and values.C.gap < values.B.gap, "체공이 짧을수록 넓은 틈도 좁아짐 %s" % values)
	assert_true(values.B.flight < values.A.flight and values.C.flight < values.B.flight, "튕김 체공도 짧아짐")


func test_틈_위_생선_무지개는_설정마다_최대_점프로_닿는다() -> void:
	_each(func(p: String) -> void:
		# 무지개 꼭대기(옥상 위 ITEM_LIFT + FISH_ARC_HEIGHT)가 최대 점프 때 몸이 닿는 높이 안
		var body_top := JumpModel.height_for_hold(5.0) + Balance.CAT_BODY_SIZE.y + Balance.ITEM_RADIUS
		assert_true(Balance.ITEM_LIFT + Balance.FISH_ARC_HEIGHT < body_top, p)
	)


func test_실수_없는_봇은_설정마다_거의_다_버틴다() -> void:
	# 다 버티지는 못함: 착지 직전에 누른 손이 바로 앞 트램펄린의 "이른 누름"이 되는 드문 경우가 있음 (C 시드 2, 설정과 상관없는 규칙)
	_each(func(p: String) -> void:
		var duration := 180.0
		var survived := 0
		for seed_value in range(1, 11):
			if BalanceBot.play({"timing": 0.0, "short_hold": 0.0}, seed_value, duration) == duration:
				survived += 1
		assert_true(survived >= 9, "%s %d/10" % [p, survived])
	)


func assert_near(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("기대값 %s ± %s, 실제값 %s" % [expected, tolerance, actual], message)
