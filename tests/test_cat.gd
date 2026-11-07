extends TestCase
## 고양이 그림과 동작: 부품 자세(달리기·점프·착지), 그림 크기·위치가 충돌 판정과 맞는지.

const DT := 1.0 / 60.0


func test_달릴_때_앞다리_두_개와_뒷다리_두_개가_서로_엇갈린다() -> void:
	for x in [37.0, 90.0, 260.0]:
		var pose := CatPose.target(true, 0.0, x, 99.0)
		assert_true(absf(pose.front + pose.front_back) < 0.001, "앞다리끼리 반대 (x=%d)" % x)
		assert_true(absf(pose.back + pose.back_back) < 0.001, "뒷다리끼리 반대")
		assert_true(absf(pose.front + pose.back) < 0.001, "같은 쪽 앞뒤 다리도 엇갈림")
		for leg in CatPose.LEGS:
			assert_true(absf(pose[leg]) <= Balance.CAT_LEG_SWING + 0.001, "%s 흔들림 범위" % leg)


func test_달리기_박자는_달린_거리로_정해져_한_박자에_CAT_STRIDE만큼_간다() -> void:
	var a := CatPose.target(true, 0.0, 40.0, 99.0)
	var b := CatPose.target(true, 0.0, 40.0 + Balance.CAT_STRIDE, 99.0)
	for key in a:
		assert_true(absf(a[key] - b[key]) < 0.001, "%s: 한 박자 뒤 같은 자세" % key)
	var half := CatPose.target(true, 0.0, 40.0 + Balance.CAT_STRIDE * 0.5, 99.0)
	assert_true(absf(a.front + half.front) < 0.001, "반 박자 뒤 다리가 반대쪽")
	assert_true(CatPose.target(true, 0.0, Balance.CAT_STRIDE * 0.25, 99.0).body_bob > 0.0, "달리며 들썩임")


func test_올라갈_때는_앞다리를_앞으로_뒷다리를_뒤로_뻗는다() -> void:
	var pose := CatPose.target(false, JumpModel.jump_speed(), 0.0, 99.0)
	assert_true(pose.front < -30.0 and pose.front_back < -20.0, "앞다리 앞으로 (음수)")
	assert_true(pose.back > 25.0 and pose.back_back > 15.0, "뒷다리 뒤로 (양수)")
	assert_eq(pose.body_bob, 0.0, "공중에서는 들썩이지 않음")


func test_내려올_때는_다리를_아래로_모은다() -> void:
	var rising := CatPose.target(false, JumpModel.jump_speed(), 0.0, 99.0)
	var falling := CatPose.target(false, -JumpModel.jump_speed(), 0.0, 99.0)
	assert_true(absf(falling.back) < absf(rising.back), "뒷다리를 뒤로 덜 뻗음")
	assert_true(falling.front < 0.0 and falling.front > rising.front, "앞다리는 착지하려고 살짝 앞 아래로")
	var top := CatPose.target(false, 0.0, 0.0, 99.0)
	for leg in CatPose.LEGS:
		assert_eq(top[leg], 0.0, "가장 높은 곳에서는 바로 선 다리 (%s)" % leg)


func test_착지_순간에는_다리를_벌려_버티고_곧_달리기로_돌아온다() -> void:
	var land := CatPose.target(true, 0.0, 0.0, 0.0)
	assert_true(land.front < -17.0 and land.back > 17.0, "착지 순간 다리를 앞뒤로 벌림")
	var later := CatPose.target(true, 0.0, 0.0, Balance.SQUASH_TIME)
	var run := CatPose.target(true, 0.0, 0.0, 99.0)
	assert_eq(later, run, "납작해짐이 끝나면 달리기 자세")


func test_고양이_그림은_충돌_판정_크기에_맞고_발끝이_원점() -> void:
	var cat := CatView.new()
	add_child(cat)
	await wait_frames(1)
	var scale_factor := CatView.art_scale()
	assert_true(absf((CatView.ART_RIGHT - CatView.ART_LEFT) * scale_factor - Balance.CAT_BODY_SIZE.x) < 0.001, "가로 = 충돌 판정 너비")
	var skeleton: Node2D = cat.get_node("Skeleton")
	# 그림 가로 가운데와 발끝이 노드 원점에 온다
	assert_true(absf(skeleton.position.x + (CatView.ART_LEFT + CatView.ART_RIGHT) * 0.5 * scale_factor) < 0.001)
	assert_true(absf(skeleton.position.y + CatView.ART_FEET * scale_factor) < 0.001)
	# 부품 그림의 실제 불투명 범위(꼬리 제외)를 재서 ART_* 범위와 충돌 판정 크기에 맞는지 확인한다
	var art := Rect2()
	for part in CatView.PARTS:
		var texture: Texture2D = load("res://assets/sprites/cat_parts/%s.png" % part.file)
		assert_not_null(texture, part.file)
		if texture == null or part.name == "tail":
			continue
		var used := texture.get_image().get_used_rect()
		var rect := Rect2(part.top_left + Vector2(used.position), Vector2(used.size))
		art = rect if art.size == Vector2.ZERO else art.merge(rect)
	assert_true(absf(art.position.x - CatView.ART_LEFT) <= 3.0, "왼쪽 끝 %.0f" % art.position.x)
	assert_true(absf(art.end.x - CatView.ART_RIGHT) <= 3.0, "오른쪽 끝 %.0f" % art.end.x)
	assert_true(absf(art.position.y - CatView.ART_TOP) <= 3.0, "머리 위 %.0f" % art.position.y)
	assert_true(absf(art.end.y - CatView.ART_FEET) <= 3.0, "발끝 %.0f" % art.end.y)
	var drawn := art.size * scale_factor
	assert_true(absf(drawn.x - Balance.CAT_BODY_SIZE.x) <= 3.0, "그림 너비 %.1f = 판정 너비" % drawn.x)
	assert_true(absf(drawn.y - Balance.CAT_BODY_SIZE.y) <= 3.0, "그림 높이 %.1f = 판정 높이" % drawn.y)
	cat.queue_free()


func test_달리면_부품이_움직이고_투명화면_반투명() -> void:
	var cat := CatView.new()
	add_child(cat)
	await wait_frames(1)
	var sim := RunnerSim.new(3)
	var seen := {}
	for i in 60:
		sim.step(DT, false)
		cat.show_state(sim, DT)
		seen[snappedf(cat.angle_of("front"), 1.0)] = true
	assert_true(seen.size() > 10, "앞다리가 계속 움직임")
	assert_eq(cat.modulate.a, 1.0)
	sim.ghost_time = 1.0
	cat.show_state(sim, DT)
	assert_true(cat.modulate.a < 0.6, "투명화 중 반투명")
	cat.queue_free()
