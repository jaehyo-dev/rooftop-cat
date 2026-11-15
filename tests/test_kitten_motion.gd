extends TestCase
## 아기 새 움직임 (cat-parade 1단계 A·B 비교, KittenMotion): 발 미끄러짐·바닥 붙음 자동 검사, 상태 고르기, 도망 순서.
## A·주인공 프레임 그림의 발 미끄러짐은 tools/test_kitten_motion.py (그림을 재므로 파이썬)

const FPS := 60.0
const SPEEDS := [430.0, 640.0, 950.0, 1250.0]
const B_SLIP_MAX := 0.5   # B 디딘 발이 디디는 동안 세계 x가 움직여도 되는 만큼 (게임 픽셀)
const GROUND_TOL := 1.0   # 땅 위 발끝과 바닥 (게임 픽셀)


## B: 다리마다 디딘 동안 발의 세계 x (아기가 달린 거리 + 발 x x 배율) 최대 - 최소
func test_B_디딘_발은_미끄러지지_않는다() -> void:
	var bs := KittenMotion.b_scale()
	for speed in SPEEDS:
		var span := {}  # 다리 → [최소, 최대]
		var worst := 0.0
		for tick in int(3.0 * FPS):
			var dist: float = speed * tick / FPS
			var pose := KittenMotion.b_run(dist)
			for leg in KittenMotion.B_LEGS:
				var foot: Vector2 = pose.legs[leg].foot
				if foot.y < -0.01:
					if span.has(leg):
						worst = maxf(worst, span[leg][1] - span[leg][0])
					span.erase(leg)
					continue
				var x := dist + foot.x * bs
				span[leg] = [minf(span.get(leg, [x, x])[0], x), maxf(span.get(leg, [x, x])[1], x)]
		assert_true(worst <= B_SLIP_MAX, "속도 %d: B 발 미끄러짐 %.2fpx" % [speed, worst])


## B: 땅 위 모든 장면에서 한 발 이상이 바닥에 닿고(1px 안), 디딘 다리는 그림 길이 안에서 닿는다 (늘임 한계 안)
func test_B_땅_위에서는_발이_바닥에_붙는다() -> void:
	var bs := KittenMotion.b_scale()
	for tick in 600:
		var pose := KittenMotion.b_run(tick * 3.7)
		var lowest := -INF
		for leg in KittenMotion.B_LEGS:
			var l: Dictionary = pose.legs[leg]
			lowest = maxf(lowest, l.foot.y)
			if l.foot.y == 0.0:
				var t := KittenMotion.b_leg(l.hip, l.foot, KittenMotion.b_len(leg))
				assert_true(t.y <= KittenMotion.B_STRETCH + 0.001 and t.y > 0.6, "디딘 다리 늘임 %.3f" % t.y)
		assert_true(absf(lowest * bs) <= GROUND_TOL, "거리 %.1f: 가장 낮은 발 %.2fpx" % [tick * 3.7, lowest * bs])
	var stand := KittenMotion.b_stand()
	for leg in KittenMotion.B_LEGS:
		assert_eq(stand.legs[leg].foot.y, 0.0, "멈칫: 네 발 다 바닥 " + leg)


## A: 땅 자세 그림(달리기 8·웅크림·도약·착지·멈칫)의 발끝이 기준선과 1px 안, 그림 크기가 같음
func test_A_땅_자세_그림은_발끝이_기준선에() -> void:
	var base: int = KittenMotionData.A_ANCHOR[1]
	for frame in KittenView.A_FRAMES:
		var img: Image = load(KittenView.A_DIR + frame + ".png").get_image()
		if img.is_compressed():
			img.decompress()
		assert_eq(img.get_size(), Vector2i(300, 260), frame)
		if frame in ["rise", "fall"]:
			continue
		var bottom := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					bottom = y
					break
		assert_true(absf(bottom + 1 - base) * KittenMotion.px() <= GROUND_TOL, "%s 발끝 %d / 기준 %d" % [frame, bottom + 1, base])


## A: 달린 거리로 장을 넘긴다 (한 바퀴 = a_stride, 8장 차례로)
func test_A_달린_거리로_장을_넘긴다() -> void:
	var stride := KittenMotion.a_stride()
	assert_true(stride > 60.0, "한 바퀴 %.1f" % stride)
	var seen: Array[int] = []
	for i in 80:
		var k := KittenMotion.a_frame(stride * (i + 0.5) / 80.0)
		if seen.is_empty() or seen[-1] != k:
			seen.append(k)
	assert_eq(seen, [0, 1, 2, 3, 4, 5, 6, 7])
	assert_eq(KittenMotion.a_frame(stride * 2.0 + 0.1), 0, "바퀴가 돌아옴")


## 아기 자세는 아기 자신의 상태로: 땅 = 달리기, 오를 때·내릴 때 = 속도 방향, 닿는 순간 = 착지 눌림
func test_자세는_아기_자신의_상태로() -> void:
	assert_eq(KittenMotion.state({"ground": true, "since_land": 5.0}, 0.0).kind, "run")
	var land := KittenMotion.state({"ground": true, "since_land": 0.0}, 0.0)
	assert_eq(land.land_k, 0.0, "닿은 순간")
	assert_true(KittenMotion.squash(land.land_k, 0.0, 0.5) < 0.9, "닿는 순간 눌림")
	assert_true(KittenMotion.squash(1.0, 0.25, 0.5) > 0.97, "달릴 때 눌림은 아주 조금")
	var up := KittenMotion.state({"ground": false, "since_jump": 1.0}, 0.8)
	var down := KittenMotion.state({"ground": false, "since_jump": 1.0}, -0.8)
	assert_eq(up.kind, "rise")
	assert_eq(down.kind, "fall")
	assert_true(up.tilt < 0.0 and down.tilt > 0.0, "오를 때 코가 위, 내릴 때 아래")
	assert_eq(KittenMotion.state({"ground": false, "since_jump": 0.0}, 1.0).kind, "takeoff")


## 땅 위 눌림은 세로만 (가로 배율이 그대로라 발 x가 안 바뀜), 발끝 축이라 발 높이도 그대로
func test_눌림은_세로만() -> void:
	var view := KittenView.new()
	add_child(view)
	for m in ["a", "b"]:
		view.show_motion(m, {"kind": "run", "dist": 10.0, "squash": 0.8})
		var k := KittenMotion.px() if m == "a" else KittenMotion.b_scale()
		assert_true(is_equal_approx(view.scale.x, k), m + " 가로 배율 그대로")
		assert_true(is_equal_approx(view.scale.y, k * 0.8), m + " 세로만 눌림")
	view.queue_free()


## 도망: 멈칫(STARTLE) → 몸 돌림 → 뒤로 달림 (뒤로 간 거리가 늘기만)
func test_도망은_멈칫_돌림_달림() -> void:
	var vx := 600.0
	assert_eq(KittenMotion.runaway(0.05, vx).kind, "startle")
	assert_eq(KittenMotion.runaway(0.05, vx).back, 0.0, "멈칫하는 동안 다리는 멈춤")
	assert_eq(KittenMotion.runaway(KittenMotion.STARTLE + 0.02, vx).kind, "turn")
	assert_eq(KittenMotion.runaway(0.01, vx).kind, "crouch", "움츠렸다가")
	for i in 30:
		assert_true(absf(KittenMotion.runaway(KittenMotion.STARTLE + KittenMotion.TURN * i / 30.0, vx).facing) >= KittenMotion.TURN_POP, "돌 때 얇아지지 않음")
	var run := KittenMotion.runaway(0.6, vx)
	assert_eq(run.kind, "run")
	assert_eq(run.facing, -1.0)
	var last := -INF
	var top := 0.0
	for i in 60:
		var r := KittenMotion.runaway(i * 0.02, vx)
		var speed: float = (r.dx - last) / 0.02 if i > 0 else vx
		assert_true(speed <= vx + 1.0, "놀란 뒤 빨라지지 않음 (서서히 멈춤)")
		last = r.dx
		top = maxf(top, r.dx)
	assert_true(top > 0.0 and last < 0.0, "앞으로 밀리며 멈췄다가 뒤로 달림")
	assert_true(KittenMotion.runaway_y(200.0, 100.0, 0.0) == 200.0 and KittenMotion.runaway_y(200.0, 100.0, 1.0) == 100.0, "공중에서 놀라면 아래 옥상으로")
