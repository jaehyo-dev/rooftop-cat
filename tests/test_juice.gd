extends TestCase
## 2b 손맛: 콤보 음계·띵·툭, 부딪힘 소리, 흔들림, 결과 숫자 차오름, 심장 박동 박자.


func test_생선_음은_콤보마다_한_칸씩_오르고_8칸_뒤_처음으로() -> void:
	var prev := 0.0
	for count in range(1, 9):
		var p := SfxEvents.fish_pitch(count)
		assert_true(p > prev, "콤보 %d: 앞 칸보다 높음" % count)
		prev = p
	assert_true(absf(SfxEvents.fish_pitch(8) / SfxEvents.fish_pitch(1) - 2.0) < 0.001, "8칸 = 한 옥타브 (도→도)")
	assert_eq(SfxEvents.fish_pitch(9), SfxEvents.fish_pitch(1), "9번째는 다시 처음 칸")
	assert_eq(SfxEvents.fish_pitch(0), SfxEvents.fish_pitch(8), "콤보 0(끊긴 뒤 표시)도 범위 안")
	assert_true(SfxEvents.fish_pitch(8) <= 1.5, "맨 위 칸도 원래 소리의 1.5배 이하 (귀 아프지 않게)")
	assert_true(absf(SfxEvents.fish_pitch(3) / SfxEvents.fish_pitch(1) - pow(2.0, 4.0 / 12.0)) < 0.001, "미 = 도 + 장3도")


func test_배수가_오르면_띵_끊기면_툭() -> void:
	var combo := FishCombo.new()
	for i in Balance.COMBO_STEP - 1:
		combo.eat(10)
	assert_eq(SfxEvents.combo_sounds(combo.count, combo.multiplier(), combo, false), [] as Array[String], "변화 없음")
	var before := [combo.count, combo.multiplier()]
	combo.eat(10)
	assert_eq(SfxEvents.combo_sounds(before[0], before[1], combo, false), ["combo_up"] as Array[String], "x1 → x2")
	before = [combo.count, combo.multiplier()]
	combo.cut()
	assert_eq(SfxEvents.combo_sounds(before[0], before[1], combo, false), ["combo_break"] as Array[String], "끊김")
	assert_eq(SfxEvents.combo_sounds(before[0], before[1], combo, true), [] as Array[String], "부딪혀 끊기면 퉁만 (툭은 겹치지 않게)")
	combo.eat(10)
	assert_eq(SfxEvents.combo_sounds(20, 2, combo, false), ["combo_break"] as Array[String], "끊긴 뒤 같은 step에 하나 먹어도 끊긴 것")
	combo.cut()
	assert_eq(SfxEvents.combo_sounds(SfxEvents.COMBO_BREAK_MIN - 1, 1, combo, false), [] as Array[String], "짧은 콤보는 조용히 끊김")


func test_부딪히면_퉁_방울이_막으면_딸랑만() -> void:
	var sim := RunnerSim.new(1)
	sim.hit_obstacle = {"kind": "pot"}
	assert_eq(SfxEvents.sounds(sim, false), ["hit"] as Array[String])
	sim.bell_blocked = true
	assert_eq(SfxEvents.sounds(sim, false), ["bell"] as Array[String])
	for name in SfxEvents.ALL:
		assert_true(ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % name), name + " 소리 파일")


func test_흔들림은_세기_안에서_잦아들어_멈춘다() -> void:
	var prev := INF
	for i in 5:
		var since := 0.2 * i / 5.0
		var biggest := 0.0
		for j in 8:  # 구간마다 가장 큰 어긋남
			biggest = maxf(biggest, Juice.shake_offset(since + 0.005 * j, 0.2, 8.0).length())
		assert_true(biggest <= 8.0 * sqrt(2.0), "세기 안")
		assert_true(biggest <= prev + 0.001, "%.2f초: 잦아듦" % since)
		prev = biggest
	assert_eq(Juice.shake_offset(0.2, 0.2, 8.0), Vector2.ZERO, "끝나면 제자리")
	assert_eq(Juice.shake_offset(0.0, 0.0, 8.0), Vector2.ZERO, "길이 0이면 흔들지 않음")


func test_고르는_손맛은_멈춤_0_04에서_0_08초() -> void:
	assert_true(Balance.HIT_FEELS.has(Balance.HIT_FEEL_DEFAULT), "기본값이 목록에 있음")
	var prev := 0.0
	for name in ["약", "중", "강"]:
		var feel: Array = Balance.HIT_FEELS[name]
		assert_true(feel[0] >= 0.04 and feel[0] <= 0.08, name + " 멈춤 시간")
		assert_true(feel[1] > prev, name + " 흔들림이 점점 셈")
		prev = feel[1]


func test_결과_숫자는_하나씩_차오른다() -> void:
	var values := [120, 45, 30, 1500]
	assert_eq(Juice.count_up(values, 0.0), [0, 0, 0, 0] as Array[int], "처음엔 0")
	var mid := Juice.count_up(values, Juice.COUNT_UP_EACH * 0.5)
	assert_true(mid[0] > 0 and mid[0] < 120 and mid[1] == 0, "첫 숫자만 오르는 중")
	assert_eq(Juice.count_up(values, Juice.COUNT_UP_EACH * 1.5)[0], 120, "첫 숫자 다 참")
	assert_false(Juice.count_done(values, Juice.COUNT_UP_EACH * 3.9))
	assert_true(Juice.count_done(values, Juice.COUNT_UP_EACH * 4.0))
	assert_eq(Juice.count_up(values, 99.0), [120, 45, 30, 1500] as Array[int], "끝나면 실제 값")


func test_심장_박동은_1초에_한_번() -> void:
	var beats := 0
	for i in 600:
		if Juice.beat_crossed(i / 120.0, (i + 1) / 120.0):
			beats += 1
	assert_eq(beats, 5, "5초에 5번")
	assert_false(Juice.beat_crossed(90.0, 0.0), "새 판으로 시각이 되돌아가도 소리 없음")


func test_손맛_버튼_자리의_터치는_점프가_아니고_버튼은_손맛을_바꾼다() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://test_juice_tune.cfg"
	add_child(main)
	var world: Node2D = main.get_node("World")
	await wait_frames(2)
	assert_false(main.has_node("TunePanel"), "데스크톱·테스트에서는 버튼 없음 (로컬 웹에서만)")
	main._add_tune_panel()
	await wait_frames(3)
	var panel: Control = main.get_node("TunePanel")
	assert_true(world.input_block.has_point(panel.get_global_rect().get_center()), "버튼 자리를 막음: %s / %s" % [world.input_block, panel.get_global_rect()])
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = panel.get_global_rect().get_center()
	world._input(touch)
	assert_false(world.is_pressed(), "버튼 자리 터치는 점프로 치지 않음")
	touch.position = Vector2(640.0, 300.0)
	world._input(touch)
	assert_true(world.is_pressed(), "다른 자리 터치는 점프")
	var strong: Button = panel.get_child(3)
	strong.pressed.emit()
	assert_eq(world.hit_feel, "강", "강을 누르면 강")
	main.queue_free()
	await wait_frames(1)
	DirAccess.remove_absolute("user://test_juice_tune.cfg")


func test_부딪히면_고른_만큼_멈칫하고_흔들리며_빨갛게_깜빡인다() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://test_juice_hit.cfg"
	add_child(main)
	var world: Node2D = main.get_node("World")
	await wait_frames(1)
	world.set_process(false)
	world.hit_feel = "강"
	var sim: RunnerSim = world.sim
	sim.accelerate = false
	sim.obstacles.clear()
	sim.obstacles.append({"id": 77, "kind": "pot", "x": sim.x + 60.0, "w": 48.0, "y0": sim.y, "y1": sim.y + 38.0, "base": sim.y})
	world._process(0.05)
	assert_eq(sim.hearts, Balance.HEARTS_MAX - 1, "부딪힘")
	assert_eq(world._hitstop, Balance.HIT_FEELS["강"][0], "강 멈춤 시간")
	world._process(0.01)
	assert_true(world.position.length() > 0.5, "화면이 흔들림")
	assert_true(world.cat.modulate.g < 0.9, "고양이 빨간 깜빡임")
	world._process(0.5)
	assert_eq(world.position, Vector2.ZERO, "흔들림이 끝나면 제자리")
	main.queue_free()
	await wait_frames(1)
	DirAccess.remove_absolute("user://test_juice_hit.cfg")


func test_마지막_하트를_장애물에_잃어도_결과_화면이_뜬다() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://test_juice_last.cfg"
	add_child(main)
	var world: Node2D = main.get_node("World")
	await wait_frames(1)
	world.set_process(false)
	var sim: RunnerSim = world.sim
	sim.hearts = 1
	sim.obstacles.clear()
	sim.obstacles.append({"id": 78, "kind": "pot", "x": sim.x + 60.0, "w": 48.0, "y0": sim.y, "y1": sim.y + 38.0, "base": sim.y})
	world._process(0.05)
	assert_true(sim.game_over, "하트 0")
	assert_true(main.get_node("GameOver").visible, "결과 화면 (멈춤 때문에 game_over 알림을 건너뛰지 않음)")
	assert_eq(BestRecord.load_best_score("user://test_juice_last.cfg"), sim.score(), "기록 저장")
	main.queue_free()
	await wait_frames(1)
	DirAccess.remove_absolute("user://test_juice_last.cfg")
