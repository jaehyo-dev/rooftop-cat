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
