extends TestCase
## 고양이 그림자: 발밑 옥상 위에, 높이 뜰수록 작고 옅게, 틈 위에서는 없음.

const ROOFS := [{"left": 0.0, "right": 500.0, "top": 200.0}, {"left": 600.0, "right": 900.0, "top": 300.0},
		{"left": 700.0, "right": 820.0, "top": 260.0, "platform": true}]


func test_옥상에_서_있으면_가장_크고_진하다() -> void:
	var s := CatShadow.under(ROOFS, 100.0, 200.0)
	assert_eq(s.top, 200.0)
	assert_eq(s.scale, 1.0)
	assert_eq(s.alpha, CatShadow.ALPHA)


func test_높이_뜰수록_작고_옅어진다() -> void:
	var low := CatShadow.under(ROOFS, 100.0, 260.0)
	var high := CatShadow.under(ROOFS, 100.0, 450.0)
	var top := CatShadow.under(ROOFS, 100.0, 2000.0)
	assert_eq(high.top, 200.0, "공중에서도 아래 옥상 위에")
	assert_true(low.scale > high.scale and low.alpha > high.alpha)
	assert_true(is_equal_approx(top.scale, CatShadow.MIN_SCALE) and is_equal_approx(top.alpha, CatShadow.MIN_ALPHA), "가장 높으면 가장 작고 옅음")


func test_틈_위와_벽_속에서는_그림자가_없다() -> void:
	assert_true(CatShadow.under(ROOFS, 550.0, 400.0).is_empty(), "틈 위")
	assert_true(CatShadow.under(ROOFS, 650.0, 280.0).is_empty(), "발보다 높은 옥상만 있음(투명화 중)")


func test_여러_옥상이_겹치면_발_아래_가장_높은_윗면() -> void:
	assert_eq(CatShadow.under(ROOFS, 750.0, 400.0).top, 300.0)
	assert_eq(CatShadow.under(ROOFS, 750.0, 280.0).top, 260.0, "판보다 위, 옥상보다 아래면 판 위")


func test_그림자_모양은_자세와_몸_배율을_따른다() -> void:
	var gather := CatShadow.shape("run_0", Vector2.ONE, 0.0)
	var stretch := CatShadow.shape("run_1", Vector2.ONE, 0.0)
	assert_true(stretch.radius > gather.radius * 1.5, "뻗으면 넓어짐 %.0f / %.0f" % [stretch.radius, gather.radius])
	assert_true(stretch.center_x < gather.center_x, "가운데도 자세 따라 이동")
	var squashed := CatShadow.shape("run_0", Vector2(1.2, 0.8), 0.0)
	assert_true(squashed.radius > gather.radius, "눌리면 넓게")
	assert_true(squashed.flat < gather.flat and squashed.alpha > gather.alpha, "눌리면 납작하고 진하게")
	var upright := CatShadow.shape("flip_open", Vector2.ONE, 0.0)
	var sideways := CatShadow.shape("flip_open", Vector2.ONE, PI * 0.5)
	assert_true(sideways.radius < upright.radius, "세로로 선 몸은 폭이 좁음")
	assert_true(absf(sideways.center_x) < 0.01, "세로로 서면 가운데")


func test_자세별_아랫몸_수치가_그림과_맞다() -> void:
	for frame in CatPose.ALL_FRAMES:
		assert_true(CatShadow.FRAME_BODY.has(frame), frame)
		var image: Image = load(CatView.FRAME_DIR + frame + ".png").get_image()
		var used := image.get_used_rect()
		var lo := 99999
		var hi := -1
		for y in range(used.end.y - int(used.size.y * 0.3), used.end.y, 3):
			for x in used.size.x:
				if image.get_pixel(x + used.position.x, y).a > 0.5:
					lo = mini(lo, x + used.position.x)
					hi = maxi(hi, x + used.position.x)
		var width := (hi - lo) * CatView.art_scale()
		assert_true(absf(width - CatShadow.FRAME_BODY[frame][1]) < 8.0, "%s 너비 %.0f" % [frame, width])

