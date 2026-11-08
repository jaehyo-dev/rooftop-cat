extends TestCase
## 세로 카메라 계산: 머리가 화면 위로 가까워질 때만 따라가고, 내려앉을 옥상이 화면 아래 80px 위에 남는 데까지만.

const H := 720.0


func test_낮으면_움직이지_않는다() -> void:
	assert_eq(CameraFollow.target(200.0, 200.0, H), 0.0)
	assert_eq(CameraFollow.target(500.0, 200.0, H), 0.0, "머리(592)가 화면 위 110보다 아래")


func test_머리가_화면_위_110보다_올라가면_따라간다() -> void:
	var lift := CameraFollow.target(600.0, 240.0, H)
	assert_true(lift > 0.0, "따라감 %.0f" % lift)
	var head_screen := H - (600.0 + Balance.CAT_BODY_SIZE.y) + lift
	assert_true(absf(head_screen - CameraFollow.HEAD_MARGIN) < 0.01, "머리가 화면 위 110에")


func test_내려앉을_옥상이_화면_아래_80_위에_남는_데까지만() -> void:
	assert_eq(CameraFollow.target(2000.0, 240.0, H), 160.0, "줄 틈 옥상 240이면 최대 160")
	assert_eq(CameraFollow.target(2000.0, 60.0, H), 0.0, "옥상이 아주 낮으면 안 움직임")


func test_올라갈_때는_부드럽게_내려올_때는_빠르게() -> void:
	var up := CameraFollow.follow(0.0, 100.0, 1.0 / 60.0)
	var down := 100.0 - CameraFollow.follow(100.0, 0.0, 1.0 / 60.0)
	assert_true(up > 0.0 and up < 100.0, "한 프레임에 다 가지 않음")
	assert_true(down > up, "내려올 때 더 빠름 (%.1f > %.1f)" % [down, up])
	var lift := 0.0
	for i in 120:
		lift = CameraFollow.follow(lift, 100.0, 1.0 / 60.0)
	assert_true(absf(lift - 100.0) < 0.5, "2초 뒤에는 거의 도착")


func test_카메라는_판정에_영향이_없다() -> void:
	# 같은 시드·같은 입력이면 카메라 계산을 하든 안 하든 로직 결과가 같다 (카메라는 sim을 읽기만 함)
	var a := RunnerSim.new(3)
	var b := RunnerSim.new(3)
	var lift := 0.0
	for i in 600:
		var pressed := i % 50 < 10
		a.step(1.0 / 120.0, pressed)
		b.step(1.0 / 120.0, pressed)
		lift = CameraFollow.follow(lift, CameraFollow.target(b.y, b.landing_top(), H), 1.0 / 120.0)
	assert_eq(a.x, b.x)
	assert_eq(a.y, b.y)
