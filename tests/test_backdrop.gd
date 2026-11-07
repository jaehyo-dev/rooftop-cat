extends TestCase
## 먼 배경: 동네 띠 이어 붙이기(번갈아 뒤집기), 구름 위치와 시차.

func test_동네_띠는_화면을_빈틈없이_덮는다() -> void:
	for scroll in [0.0, 1.0, 777.7, 12345.6, 99999.9]:
		var tiles := Backdrop.town_tiles(scroll, 1536.0, 1280.0)
		assert_true(tiles[0].x <= 0.0, "첫 조각이 왼쪽 끝을 덮음 (scroll %f)" % scroll)
		assert_true(tiles[-1].x + 1536.0 >= 1280.0, "마지막 조각이 오른쪽 끝을 덮음")
		for i in range(1, tiles.size()):
			assert_true(absf(tiles[i].x - (tiles[i - 1].x + 1536.0)) < 0.001, "조각 사이 틈·겹침 없음")
			assert_true(tiles[i].flip != tiles[i - 1].flip, "이웃 조각은 번갈아 뒤집힘")


func test_동네_띠는_먼_배경이라_옥상보다_느리게_움직인다() -> void:
	var a := Backdrop.town_tiles(0.0, 1536.0, 1280.0)
	var b := Backdrop.town_tiles(100.0, 1536.0, 1280.0)
	assert_true(absf((a[0].x - b[0].x) - 100.0 * Backdrop.TOWN_PARALLAX) < 0.001)
	assert_true(Backdrop.TOWN_PARALLAX < 1.0 and Backdrop.CLOUD_PARALLAX < Backdrop.TOWN_PARALLAX, "구름이 가장 멀리")


func test_조각_뒤집힘은_같은_위치에서_항상_같다() -> void:
	assert_eq(Backdrop.town_tiles(5000.0, 1536.0, 1280.0), Backdrop.town_tiles(5000.0, 1536.0, 1280.0))


func test_구름은_주기_안에서_돌아_다시_나타난다() -> void:
	for scroll in [0.0, 500.0, 54321.0]:
		for base in [200.0, 1500.0]:
			var x := Backdrop.cloud_x(base, scroll, 3.0, 300.0)
			assert_true(x >= -300.0 and x < Backdrop.CLOUD_PERIOD - 300.0, "범위 %f" % x)
	# 한 주기만큼 더 가면 같은 자리
	var far := Backdrop.CLOUD_PERIOD / Backdrop.CLOUD_PARALLAX
	assert_true(absf(Backdrop.cloud_x(900.0, 0.0, 0.0, 300.0) - Backdrop.cloud_x(900.0, far, 0.0, 300.0)) < 0.01)


func test_구름은_시간이_가면_조금씩_흘러간다() -> void:
	var now := Backdrop.cloud_x(900.0, 0.0, 0.0, 300.0)
	var later := Backdrop.cloud_x(900.0, 0.0, 10.0, 300.0)
	assert_true(absf((now - later) - 10.0 * Backdrop.CLOUD_DRIFT) < 0.001)


func test_안개는_먼_것일수록_느리고_아래로_갈수록_진하다() -> void:
	for i in range(1, Backdrop.MISTS.size()):
		var prev: Array = Backdrop.MISTS[i - 1]
		var mist: Array = Backdrop.MISTS[i]
		assert_true(mist[1] > prev[1], "%s가 %s보다 빠름" % [mist[0], prev[0]])
		assert_true(mist[2] >= prev[2], "%s가 %s보다 아래" % [mist[0], prev[0]])
	assert_true(Backdrop.MISTS[2][3] > Backdrop.MISTS[0][3] and Backdrop.MISTS[3][3] >= Backdrop.MISTS[2][3], "안개 띠는 아래일수록 진함")
	var a := Backdrop.town_tiles(0.0, 1536.0, 1280.0, 0.4)
	var b := Backdrop.town_tiles(100.0, 1536.0, 1280.0, 0.4)
	assert_true(absf((a[0].x - b[0].x) - 40.0) < 0.001, "시차 비율대로 움직임")


func test_구름은_화면_가운데_높이까지_내려온다() -> void:
	var lowest := 0.0
	for cloud in Backdrop.CLOUDS:
		lowest = maxf(lowest, cloud[2])
	assert_true(lowest >= 0.35 and lowest < Backdrop.MISTS[0][2], "가장 낮은 구름이 가운데쯤, 안개보다 위")
