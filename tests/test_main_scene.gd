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


func test_떨어지면_게임_끝_화면과_최고_기록_그리고_다시_시작() -> void:
	const PATH := "user://test_main_best.cfg"
	DirAccess.remove_absolute(PATH)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = PATH
	add_child(main)
	var world: Node2D = main.get_node("World")
	await wait_frames(3)
	assert_false(main.get_node("GameOver").visible, "처음엔 게임 끝 화면 없음")
	assert_eq(main.get_node("BestLabel").text, "BEST 0 m")

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
	assert_true(main.get_node("GameOver/Label").text.contains("%d m" % meters), "이번 거리")
	assert_true(main.get_node("GameOver/Label").text.contains("NEW BEST"), "첫 기록은 최고 기록")
	assert_eq(BestRecord.load_best(PATH), meters, "최고 기록 저장")
	assert_eq(main.get_node("BestLabel").text, "BEST %d m" % meters)

	# 바로 누르면 다시 시작하지 않는다 (떨어지며 누르던 손가락)
	_touch(true)
	await wait_frames(2)
	_touch(false)
	await wait_frames(2)
	assert_true(world.sim.game_over, "기다리는 시간 전에는 다시 시작 안 함")

	# 기다린 뒤 누르면 새 판, 누른 손가락으로 점프하지 않음
	await get_tree().create_timer(Balance.RESTART_DELAY + 0.1).timeout
	_touch(true)
	await wait_frames(3)
	assert_false(world.sim.game_over, "새 판 시작")
	assert_false(main.get_node("GameOver").visible, "게임 끝 화면 닫힘")
	assert_true(world.sim.on_ground, "다시 시작한 누름으로는 점프하지 않음")
	assert_eq(world.sim.distance(), 0, "거리는 0부터")
	assert_eq(main.get_node("BestLabel").text, "BEST %d m" % meters, "최고 기록은 그대로 보임")
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
	BestRecord.add_fish(10, PATH)
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
	assert_eq(sim.fish, 2)
	assert_eq(main.get_node("FishLabel").text, "2", "이번 판 생선 수")
	assert_true(main.get_node("BoxIcon").visible, "상자를 가지면 상자 표시")

	# 상자를 쓰고 떨어져 게임 끝 (FALL_LIMIT 아래로 바로 보내 구제 높이를 건너뜀)
	sim.has_box = false
	sim.on_ground = false
	sim.y = Balance.FALL_LIMIT + 1.0
	sim.vy = -1000.0
	await wait_frames(3)
	assert_true(sim.game_over)
	assert_false(main.get_node("BoxIcon").visible, "상자 표시 꺼짐")
	assert_true(main.get_node("GameOver/Label").text.contains("FISH +2  (TOTAL 12)"), main.get_node("GameOver/Label").text)
	assert_eq(BestRecord.load_fish(PATH), 12, "모은 생선 저장")
	main.queue_free()
	DirAccess.remove_absolute(PATH)


func test_배경_음악이_반복_재생으로_붙어_있다() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait_frames(2)
	var music: AudioStreamPlayer = main.get_node("Music")
	assert_true(music.stream is AudioStreamOggVorbis and music.stream.loop, "반복 재생")
	assert_true(music.stream.get_length() >= 55.0 and music.stream.get_length() <= 65.0, "곡 길이 60초 안팎")
