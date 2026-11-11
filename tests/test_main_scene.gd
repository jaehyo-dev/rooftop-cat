extends TestCase
## 게임 화면이 실제로 돌아가고, 화면 터치로 점프하는지.


func test_게임_화면이_달리고_터치하면_점프() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var world: Node2D = main.get_node("World")
	await wait_frames(5)
	var start_x: float = world.sim.x
	assert_true(world.sim.on_ground, "시작은 옥상 위")

	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	Input.parse_input_event(touch)
	await wait_frames(3)
	assert_true(world.is_pressed(), "터치를 누름으로 인식")
	assert_false(world.sim.on_ground, "점프 중")

	touch = InputEventScreenTouch.new()
	touch.pressed = false
	Input.parse_input_event(touch)
	await wait_frames(3)
	assert_false(world.is_pressed(), "뗌")
	assert_true(world.sim.x > start_x, "앞으로 달림")
	main.queue_free()


func test_단계가_오르면_음악이_빨라지고_새_판에서_돌아온다() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var world: Node2D = main.get_node("World")
	await wait_frames(2)
	assert_eq(main.get_node("Music").pitch_scale, 1.0, "단계 1")
	world.sim.elapsed = 31.0
	# 빠른 CI는 한 프레임이 STEP보다 짧아 로직이 몇 프레임 늦게 돌 수 있다. 단계가 바뀐 뒤 한 프레임 더:
	# 부모 Main이 자식 World보다 먼저 _process를 돌아 바뀐 단계를 다음 프레임에 읽는다
	for i in 60:
		if world.sim.stage == 3:
			break
		await wait_frames(1)
	await wait_frames(1)
	assert_eq(world.sim.stage, 3)
	assert_true(is_equal_approx(main.get_node("Music").pitch_scale, SpeedCurve.music_pitch(3)), "단계 3")
	world.restart()
	await wait_frames(2)
	assert_eq(main.get_node("Music").pitch_scale, 1.0, "새 판은 원래 곡으로")
	main.queue_free()


func test_판_안에서는_같은_단계여도_곡_빠르기를_계속_다시_넘긴다() -> void:
	# 웹은 곡이 한 바퀴 돌면 빠르기가 1.0으로 풀린다 (재현: tools/web_music_check.mjs). 게임은 그걸 알 수 없으니 계속 다시 넘겨야 곧 돌아온다
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var world: Node2D = main.get_node("World")
	world.set_process(false)
	main.set_process(false)
	await wait_frames(1)
	for stage in [3, 9, 11, 12]:  # 단계 10~12는 단계가 올라도 신호가 없어 "바뀔 때만"이면 다시는 안 넘어간다
		world.sim.stage = stage
		main._process(main.MUSIC_PITCH_RESEND)
		var sends: int = main.pitch_sends
		for i in 5:
			main._process(main.MUSIC_PITCH_RESEND)
		assert_eq(main.pitch_sends - sends, 5, "단계 %d: 간격마다 다시 넘김" % stage)
		assert_true(is_equal_approx(main.get_node("Music").pitch_scale, SpeedCurve.music_pitch(stage)), "단계 %d 빠르기" % stage)
	main.queue_free()


func test_떨어지면_게임_끝_화면과_최고_기록_그리고_다시_시작() -> void:
	const PATH := "user://test_main_best.cfg"
	DirAccess.remove_absolute(PATH)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = PATH
	add_child(main)
	var world: Node2D = main.get_node("World")
	await wait_frames(3)
	assert_false(main.get_node("GameOver").visible, "처음엔 게임 끝 화면 없음")
	assert_eq(main.get_node("BestLabel").text, "BEST 0")

	# 앞으로 조금 간 뒤 화면 아래로 떨어뜨린다
	world.sim.x += Balance.PX_PER_METER * 42.0
	world.sim.on_ground = false
	world.sim.y = Balance.FALL_LIMIT + 1.0
	world.sim.vy = -1000.0
	await wait_frames(3)
	assert_true(world.sim.game_over, "게임 끝")
	var meters: int = world.sim.distance()
	assert_true(meters >= 42, "거리 점수 %d m" % meters)
	assert_true(main.get_node("GameOver").visible, "게임 끝 화면")
	var score: int = world.sim.score()
	assert_false(main.get_node("GameOver/Card/Box/Score").text.contains("점수  %d" % score) and score > 0, "숫자는 처음부터 다 보이지 않고 차오름")
	assert_eq(SaveData.open(PATH).best_distance(), meters, "최고 거리 저장")
	assert_eq(SaveData.open(PATH).best_score(), score, "최고 점수 저장")
	assert_eq(main.get_node("BestLabel").text, "BEST %d" % score)
	assert_true(main.get_node("GameOver/Card/Box/Retry").visible and main.get_node("GameOver/Card/Box/Retry").text == "다시 하기", "카드 안 다시 하기 버튼")

	# 바로 누르면 다시 시작하지 않는다 (떨어지며 누르던 손가락)
	_touch(true)
	await wait_frames(2)
	_touch(false)
	await wait_frames(2)
	assert_true(world.sim.game_over, "기다리는 시간 전에는 다시 시작 안 함")

	# 숫자가 다 차오르면 실제 값과 새 기록
	await get_tree().create_timer(Juice.COUNT_UP_EACH * 4.0 + 0.1).timeout
	var result: String = main.get_node("GameOver/Card/Box/Stats").text
	assert_true(result.contains("%d m" % meters), "이번 거리")
	assert_true(result.contains("먹은 생선") and result.contains("최고 콤보"), result)
	assert_eq(main.get_node("GameOver/Card/Box/Score").text, "점수  %d" % score, "맨 위 점수")
	assert_eq(main.get_node("GameOver/Card/Box/Best").text, "새 기록!", "첫 기록은 새 기록")
	assert_eq(main.get_node("GameOver").get_child(0).name, &"Celebrate", "축하 별은 카드 뒤 (먼저 그림)")
	var card: Control = main.get_node("GameOver/Card")
	assert_true(main.get_viewport_rect().encloses(card.get_global_rect()), "카드가 화면 안: %s" % card.get_global_rect())

	# 기다린 뒤 누르면 새 판, 누른 손가락으로 점프하지 않음
	_touch(true)
	await wait_frames(3)
	assert_false(world.sim.game_over, "새 판 시작")
	assert_false(main.get_node("GameOver").visible, "게임 끝 화면 닫힘")
	assert_true(world.sim.on_ground, "다시 시작한 누름으로는 점프하지 않음")
	assert_eq(world.sim.distance(), 0, "거리는 0부터")
	assert_eq(main.get_node("BestLabel").text, "BEST %d" % score, "최고 점수는 그대로 보임")
	_touch(false)
	await wait_frames(2)
	_touch(true)
	await wait_frames(3)
	assert_false(world.sim.on_ground, "손을 뗐다가 다시 누르면 점프")
	_touch(false)
	main.queue_free()
	DirAccess.remove_absolute(PATH)


func _touch(pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = pressed
	Input.parse_input_event(touch)


func test_한_프레임_안에_누르고_뗀_짧은_탭도_점프와_다시_시작으로_받는다() -> void:
	const PATH := "user://test_main_tap.cfg"
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = PATH
	add_child(main)
	var world: Node2D = main.get_node("World")
	await wait_frames(3)
	# 느린 휴대폰: 누름과 뗌이 다음 프레임 전에 함께 들어옴
	_touch(true)
	_touch(false)
	await wait_frames(3)
	assert_false(world.sim.on_ground, "짧은 탭으로 점프")

	world.sim.on_ground = false
	world.sim.y = Balance.FALL_LIMIT + 1.0
	world.sim.vy = -1000.0
	await wait_frames(3)
	assert_true(world.sim.game_over)
	await get_tree().create_timer(Balance.RESTART_DELAY + 0.1).timeout
	_touch(true)
	_touch(false)
	await wait_frames(3)
	assert_false(world.sim.game_over, "짧은 탭으로 다시 시작")
	assert_true(world.sim.on_ground, "다시 시작한 탭으로는 점프하지 않음")
	main.queue_free()
	DirAccess.remove_absolute(PATH)


func test_생선_수와_상자를_보여_주고_게임_끝에_생선을_저장한다() -> void:
	const PATH := "user://test_main_fish.cfg"
	DirAccess.remove_absolute(PATH)
	var before := SaveData.open(PATH)
	before.data.wallet.fish = 10
	before.save()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = PATH
	add_child(main)
	var world: Node2D = main.get_node("World")
	await wait_frames(3)
	assert_false(main.get_node("BoxIcon").visible, "처음엔 상자 없음")
	# 고양이 몸 앞에 생선 2마리와 상자를 놓는다
	var sim: RunnerSim = world.sim
	sim.items.clear()
	for dx in [100.0, 170.0]:
		sim.items.append({"kind": "fish", "x": sim.x + dx, "y": sim.y + Balance.ITEM_LIFT})
	sim.items.append({"kind": "box", "x": sim.x + 240.0, "y": sim.y + Balance.ITEM_LIFT})
	await get_tree().create_timer(0.8).timeout
	assert_true(sim.fish >= 2, "앞에 놓은 생선을 먹음")
	assert_eq(main.get_node("FishLabel").text, str(sim.fish), "이번 판 생선 수")
	assert_eq(main.get_node("ComboLabel").text, "콤보 %d  x%d" % [sim.combo.count, sim.combo.multiplier()], "콤보 숫자와 배수")
	assert_true(main.get_node("BoxIcon").visible, "상자를 가지면 상자 표시")

	# 상자를 쓰고 떨어져 게임 끝 (FALL_LIMIT 아래로 바로 보내 구제 높이를 건너뜀)
	sim.has_box = false
	sim.on_ground = false
	sim.y = Balance.FALL_LIMIT + 1.0
	sim.vy = -1000.0
	await wait_frames(3)
	assert_true(sim.game_over)
	assert_false(main.get_node("BoxIcon").visible, "상자 표시 꺼짐")
	await get_tree().create_timer(Juice.COUNT_UP_EACH * 4.0 + 0.1).timeout  # 결과 숫자가 다 차오를 때까지
	assert_true(main.get_node("GameOver/Card/Box/Stats").text.contains("먹은 생선  %d" % sim.fish), main.get_node("GameOver/Card/Box/Stats").text)
	assert_eq(main.get_node("GameOver/Card/Box/Total").text, "모은 생선 %d" % (10 + sim.fish), "모은 생선은 작게 따로")
	assert_true(main.get_node("ScoreLabel").text == str(sim.score()), "오른쪽 위 점수")
	assert_eq(SaveData.open(PATH).fish(), 10 + sim.fish, "모은 생선 저장")
	main.queue_free()
	DirAccess.remove_absolute(PATH)


func test_배경_음악이_반복_재생으로_붙어_있다() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait_frames(2)
	var music: AudioStreamPlayer = main.get_node("Music")
	assert_true(music.stream is AudioStreamOggVorbis and music.stream.loop, "반복 재생")
	assert_true(music.stream.get_length() >= 55.0 and music.stream.get_length() <= 65.0, "곡 길이 60초 안팎")
	main.queue_free()


func test_질주_북_층은_곡과_길이·빠르기가_같고_질주_중에만_들린다() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://test_main_drums.cfg"
	add_child(main)
	var world: Node2D = main.get_node("World")
	world.set_process(false)
	main.set_process(false)
	await wait_frames(1)
	var music: AudioStreamPlayer = main.get_node("Music")
	var drums: AudioStreamPlayer = main.get_node("DashDrums")
	assert_true(drums.stream.loop == music.stream.loop and drums.playing and music.playing, "같이 재생, 반복 설정도 같음")
	assert_true(absf(drums.stream.get_length() - music.stream.get_length()) < 0.01, "곡과 길이가 같음: %.3f / %.3f" % [drums.stream.get_length(), music.stream.get_length()])
	world.sim.stage = 9
	main._process(0.05)
	assert_eq(drums.pitch_scale, music.pitch_scale, "같은 빠르기")
	assert_true(drums.volume_db < -60.0, "평소에는 안 들림")
	assert_false(main.get_node("DashBonus").visible, "평소 x2 없음")
	world.sim.dashing = true
	world.sim.combo.eat(10)
	main._process(main.DRUM_IN)
	assert_true(absf(drums.volume_db - main.DRUM_VOLUME_DB) < 0.01, "질주 시작 0.1초에 다 들어옴")
	assert_true(main.get_node("DashBonus").visible, "질주 중 콤보 옆 x2")
	world.sim.dashing = false
	main._process(main.DRUM_OUT * 0.5)
	assert_true(drums.volume_db < main.DRUM_VOLUME_DB - 3.0 and drums.volume_db > -60.0, "빠지는 중")
	main._process(main.DRUM_OUT * 0.5)
	assert_true(drums.volume_db < -60.0, "0.5초에 다 빠짐")
	# 웹에서 곡이 끝나면 곡과 북을 같이 처음부터 (데스크톱은 자동 반복)
	music.play(1.0)
	drums.play(3.0)
	music.finished.emit()
	assert_true(music.get_playback_position() < 0.1 and drums.get_playback_position() < 0.1, "같이 처음부터")
	main.queue_free()
	await wait_frames(1)
	DirAccess.remove_absolute("user://test_main_drums.cfg")


func test_버튼_자리_터치는_점프도_다시_시작도_아니다() -> void:
	const PATH := "user://test_main_block.cfg"
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = PATH
	add_child(main)
	var world: Node2D = main.get_node("World")
	var button := Button.new()  # 2a 시험 패널·2c 버튼 자리
	button.position = Vector2(10.0, 600.0)
	button.size = Vector2(100.0, 60.0)
	main.add_child(button)
	world.touch_blockers.append(button)
	await wait_frames(3)
	var to_window := main.get_viewport().get_screen_transform()  # 입력은 창 좌표로 들어와 게임 화면 좌표로 바뀐다 (headless 창은 작음)
	var tap := func(at: Vector2) -> void:
		for down in [true, false]:
			var event := InputEventScreenTouch.new()
			event.pressed = down
			event.position = to_window * at
			Input.parse_input_event(event)
	tap.call(Vector2(40.0, 630.0))
	await wait_frames(3)
	assert_true(world.sim.on_ground, "버튼 자리는 점프 아님")
	tap.call(Vector2(400.0, 630.0))
	await wait_frames(3)
	assert_false(world.sim.on_ground, "다른 자리는 점프")
	world.sim.on_ground = false
	world.sim.y = Balance.FALL_LIMIT + 1.0
	world.sim.vy = -1000.0
	await get_tree().create_timer(Balance.RESTART_DELAY + 0.2).timeout
	assert_true(world.sim.game_over)
	tap.call(Vector2(40.0, 630.0))
	await wait_frames(3)
	assert_true(world.sim.game_over, "버튼 자리는 다시 시작 아님")
	button.visible = false
	tap.call(Vector2(40.0, 630.0))
	await wait_frames(3)
	assert_false(world.sim.game_over, "숨긴 버튼 자리는 다시 받음")
	main.queue_free()
	DirAccess.remove_absolute(PATH)
