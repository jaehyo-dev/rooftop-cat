extends TestCase
## 임시 시험 도구(dev_tune.gd, 배포 전 제거)가 로컬 빌드 밖에 영향을 주지 않는지. 첫 질주 시각 규칙은 test_balance.gd가 그대로 확인한다.


func test_로컬_빌드가_아니면_고르기_버튼도_시험_질주도_없다() -> void:
	assert_false(DevTune.local_build(), "테스트(데스크톱 실행)는 로컬 웹 빌드가 아님")
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait_frames(3)
	assert_true(main.get_node_or_null("DevTune") == null, "고르기 버튼 없음")
	var world: Node2D = main.get_node("World")
	assert_eq(world.dash_tint, DevTune.TINTS["A"], "기본 노을빛은 A")
	assert_eq(world.input_block, Rect2(), "막는 터치 자리 없음")
	main.queue_free()


func test_시험_질주는_고양이_앞_옥상_위에_놓이고_먹으면_질주() -> void:
	var sim := RunnerSim.new(7)
	for i in 60:
		sim.step(1.0 / 60.0, false)
	assert_true(DevTune.place_dash(sim, 0.5), "앞 옥상 위에 놓음")
	var dash: Dictionary = sim.items[-1]
	assert_eq(dash.kind, "dash")
	var on_roof := false
	for roof in sim.roofs:
		on_roof = on_roof or (roof.left <= dash.x and dash.x <= roof.right and is_equal_approx(dash.y, roof.top + Balance.ITEM_LIFT))
	assert_true(on_roof, "옥상 위 높이")
	for i in 120:
		sim.step(1.0 / 60.0, false)
		if sim.dashing:
			break
	assert_true(sim.dashing, "달려가서 먹으면 질주")
