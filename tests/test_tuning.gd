extends TestCase
## 로컬 빌드 설정 패널: 점프는 다음 판부터, 안개는 바로, 버튼을 눌러도 점프하지 않음, 배포 사이트에서는 숨김.
## 안개 설정 값: 덮는 높이·불투명도, 고양이보다 채도가 낮음, 채움 색이 그림 아랫줄과 이어짐.

const WORLD := preload("res://scripts/world_view.gd")


func _main() -> Control:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://test_tuning_record.json"
	add_child(main)
	await wait_frames(2)
	return main


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	get_viewport().push_input(event)


func _touch(at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = true
	get_viewport().push_input(event, true)


func test_배포_사이트에서는_패널이_없다() -> void:
	assert_false(TuningPanel.allowed("jaehyo-dev.github.io"))
	assert_true(TuningPanel.allowed("localhost"))
	assert_true(TuningPanel.allowed("192.168.0.5"))


func test_점프_설정은_다음_판부터_적용된다() -> void:
	var main: Control = await _main()
	var world: Node2D = main.get_node("World")
	_key(KEY_3)
	assert_eq(world.next_jump_preset, "C")
	assert_eq(JumpModel.preset, "A", "지금 판은 그대로")
	world.restart()
	assert_eq(JumpModel.preset, "C", "새 판부터")
	assert_true(absf(world.sim.get("_hold_max") - JumpModel.max_hold_time()) < 0.0001, "새 판 값")
	_key(KEY_1)
	world.restart()
	assert_eq(JumpModel.preset, "A")
	main.queue_free()
	await wait_frames(1)


func test_안개_설정은_바로_바뀐다() -> void:
	var main: Control = await _main()
	var world: Node2D = main.get_node("World")
	assert_eq(world.mist_preset, "M1")
	_key(KEY_5)
	assert_eq(world.mist_preset, "M2")
	_key(KEY_6)
	assert_eq(world.mist_preset, "M3")
	_key(KEY_4)
	assert_eq(world.mist_preset, "M1")
	main.queue_free()
	await wait_frames(1)


func test_버튼_터치는_점프가_아니고_다른_곳_터치는_점프() -> void:
	var main: Control = await _main()
	var world: Node2D = main.get_node("World")
	var panel: TuningPanel = main.get_node("TuningPanel")
	_touch(panel.call("_button_rect", 4).get_center())
	assert_eq(world.mist_preset, "M2", "안개 버튼")
	assert_false(world.is_pressed(), "버튼 터치는 점프로 치지 않음")
	_touch(panel.call("_button_rect", 1).get_center())
	assert_eq(world.next_jump_preset, "B", "점프 버튼")
	assert_false(world.is_pressed())
	_touch(Vector2(600.0, 400.0))
	assert_true(world.is_pressed(), "버튼 밖 터치")
	main.queue_free()
	await wait_frames(1)


func test_버튼은_겹치지_않고_화면_안에_있다() -> void:
	var main: Control = await _main()
	var panel: TuningPanel = main.get_node("TuningPanel")
	for i in 6:
		var rect: Rect2 = panel.call("_button_rect", i)
		assert_true(panel.get_viewport_rect().encloses(rect), "버튼 %d" % i)
		if i > 0:
			assert_false(rect.intersects(panel.call("_button_rect", i - 1)), "버튼 %d" % i)
	main.queue_free()
	await wait_frames(1)


func test_안개_설정_값() -> void:
	assert_true(absf(WORLD.MIST_LOOKS.M1.near_cover - 1.0) < 0.001, "M1은 지금 그대로")
	assert_true(absf(WORLD.MIST_LOOKS.M2.near_cover - 2.0 / 3.0) < 0.001)
	assert_true(absf(WORLD.MIST_LOOKS.M3.near_cover - 0.5) < 0.001)
	assert_true(absf(WORLD.MIST_LOOKS.M3.near_alpha - 0.7) < 0.001)


func test_안개는_고양이보다_채도가_낮고_채움_색이_그림_아랫줄과_이어진다() -> void:
	var cat: Image = load("res://assets/sprites/cat_base_run.png").get_image()
	var total := 0.0
	var count := 0
	for y in range(0, cat.get_height(), 8):
		for x in range(0, cat.get_width(), 8):
			var c := cat.get_pixel(x, y)
			if c.a > 0.9:
				total += c.s
				count += 1
	var cat_sat := total / count
	for preset in WORLD.MIST_LOOKS:
		var look: Dictionary = WORLD.MIST_LOOKS[preset]
		for layer in ["far", "mid", "near"]:
			var fill: Color = look[layer + "_fill"]
			assert_true(fill.s < cat_sat, "%s %s 채도 %.2f < 고양이 %.2f" % [preset, layer, fill.s, cat_sat])
			if preset == "M1":
				continue  # M1은 v0.5.0 2b 그대로
			var image: Image = look[layer].get_image()
			var bottom := image.get_pixel(image.get_width() / 2, image.get_height() - 1)
			var average := Color(0, 0, 0)
			for x in range(0, image.get_width(), 16):
				average += image.get_pixel(x, image.get_height() - 1) / (image.get_width() / 16.0)
			assert_true(absf(average.r - fill.r) + absf(average.g - fill.g) + absf(average.b - fill.b) < 0.06, "%s %s 이음 %s %s (%s)" % [preset, layer, average, fill, bottom])
