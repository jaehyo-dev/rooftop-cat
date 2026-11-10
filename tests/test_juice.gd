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


func test_부딪힘_손맛은_중으로_고정() -> void:
	assert_eq(Balance.HIT_STOP, 0.06, "멈춤 0.06초")
	assert_eq(Balance.HIT_SHAKE, 8.0, "흔들림 8px")


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


func test_왼쪽_아래_터치도_점프다() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://test_juice_tune.cfg"
	add_child(main)
	var world: Node2D = main.get_node("World")
	await wait_frames(2)
	assert_false(main.has_node("TunePanel"), "손맛 고르기 버튼은 없음")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(60.0, 690.0)  # 예전 고르기 버튼 자리
	world._input(touch)
	assert_true(world.is_pressed(), "왼쪽 아래 터치도 점프")
	main.queue_free()
	await wait_frames(1)
	DirAccess.remove_absolute("user://test_juice_tune.cfg")


func test_부딪히면_멈칫하고_흔들리며_빨갛게_깜빡인다() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://test_juice_hit.cfg"
	add_child(main)
	var world: Node2D = main.get_node("World")
	await wait_frames(1)
	world.set_process(false)
	var sim: RunnerSim = world.sim
	sim.accelerate = false
	sim.obstacles.clear()
	sim.obstacles.append({"id": 77, "kind": "pot", "x": sim.x + 60.0, "w": 48.0, "y0": sim.y, "y1": sim.y + 38.0, "base": sim.y})
	world._process(0.05)
	assert_eq(sim.hearts, Balance.HEARTS_MAX - 1, "부딪힘")
	assert_eq(world._hitstop, Balance.HIT_STOP, "멈춤 시간")
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


func test_질주_시작_당김은_빨리_당기고_멈칫_뒤_풀린다() -> void:
	assert_eq(Juice.dash_punch(0.0), 0.0, "시작")
	assert_eq(Juice.dash_punch(Juice.PUNCH_IN), 1.0, "다 당김")
	assert_eq(Juice.dash_punch(Juice.PUNCH_HOLD - 0.001), 1.0, "멈칫 동안 유지")
	var mid := Juice.dash_punch(Juice.PUNCH_HOLD + Juice.PUNCH_OUT * 0.5)
	assert_true(mid > 0.3 and mid < 0.7, "풀리는 중 %.2f" % mid)
	assert_eq(Juice.dash_punch(Juice.PUNCH_HOLD + Juice.PUNCH_OUT), 0.0, "다 풀림")
	assert_eq(Juice.dash_punch(99.0), 0.0, "질주 아님")


func test_페이드는_켤_때와_끌_때_시간이_다르다() -> void:
	var v := 0.0
	for i in 12:
		v = Juice.fade(v, true, 0.01, 0.1, 0.5)
	assert_eq(v, 1.0, "0.1초 안에 다 켜짐")
	for i in 25:
		v = Juice.fade(v, false, 0.01, 0.1, 0.5)
	assert_true(absf(v - 0.5) < 0.001, "0.25초면 반")
	for i in 30:
		v = Juice.fade(v, false, 0.01, 0.1, 0.5)
	assert_eq(v, 0.0, "0.5초에 다 꺼짐")


func test_결과_카드_테두리는_사각형_둘레를_살짝만_벗어나고_늘_같다() -> void:
	var rect := Rect2(0.0, 0.0, 500.0, 420.0)
	var points := Juice.wobbly_rect(rect, 2, 4.0)
	assert_true(points.size() > 40, "둘레가 촘촘함 %d" % points.size())
	for p in points:
		assert_true(rect.grow(4.01).has_point(p), "흔들림 안: %s" % p)
	assert_eq(points, Juice.wobbly_rect(rect, 2, 4.0), "같은 번호면 같은 모양")
