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
