extends TestCase
## v0.8.0 1부: 적 그림(까마귀 졸개·쥐 무리) 반복 동작 고르기와 그림 파일 (움직임·판정은 2부).

const DIR := "res://assets/sprites/enemies/"
const STILLS := {"crow": ["dash", "hit"], "rat": ["surprise", "hit"]}


func test_반복_장은_차례대로_돌고_한_바퀴면_처음으로() -> void:
	for kind in EnemyAnim.LOOPS:
		var frames: Array = EnemyAnim.LOOPS[kind]
		assert_eq(frames.size(), 4, "%s 반복 4장" % kind)
		var dt: float = 1.0 / EnemyAnim.FPS[kind]
		for i in frames.size() * 2:
			assert_eq(EnemyAnim.loop_frame(kind, (i + 0.5) * dt), frames[i % frames.size()])


func test_쥐_세_마리는_같은_박자로_움직이지_않는다() -> void:
	for t in [0.0, 0.13, 0.77, 5.4]:
		var seen := {}
		for i in 3:
			seen[EnemyAnim.loop_frame("rat", t, EnemyAnim.pack_offset(i))] = true
		assert_eq(seen.size(), 3, "t %.2f에 세 마리가 모두 다른 장" % t)


func test_적_그림은_같은_캔버스이고_기준점이_캔버스_안() -> void:
	for kind in EnemyAnim.LOOPS:
		var names: Array = EnemyAnim.LOOPS[kind] + STILLS[kind]
		var size := Vector2.ZERO
		for n in names:
			var tex: Texture2D = load(DIR + "%s/%s.png" % [kind, n])
			assert_true(tex != null, "%s/%s 그림" % [kind, n])
			if size == Vector2.ZERO:
				size = tex.get_size()
			assert_eq(tex.get_size(), size, "%s/%s 캔버스" % [kind, n])
		var foot: Vector2 = EnemyAnim.FOOT[kind]
		assert_true(foot.x > 0 and foot.y > 0 and foot.x < size.x and foot.y < size.y, "%s 기준점" % kind)


func test_발끝이_기준점_줄에_닿는다() -> void:
	# 쥐 달리기 4장과 졸개 첫 장: 맨 아래 불투명 줄이 발 기준점 줄 ±3px (그림을 다시 만들어 FOOT이 어긋나면 실패)
	for key in ["rat/run_0", "rat/run_1", "rat/run_2", "rat/run_3", "crow/fly_0"]:
		var kind: String = key.get_slice("/", 0)
		var img: Image = load(DIR + "%s.png" % key).get_image()
		var bottom := -1
		for y in range(img.get_height() - 1, -1, -1):
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					bottom = y
					break
			if bottom >= 0:
				break
		assert_true(absi(bottom + 1 - int(EnemyAnim.FOOT[kind].y)) <= 3, "%s 발끝 %d, 기준 %d" % [key, bottom + 1, EnemyAnim.FOOT[kind].y])


func test_쥐는_폰에서_40px_이상_졸개는_시안_크기() -> void:
	# 게임 키 = 몸 키(파일 px) / FILE_SCALE. 폰(844x390)은 화면 0.54배
	var rat: Image = load(DIR + "rat/run_0.png").get_image()
	var crow: Image = load(DIR + "crow/fly_0.png").get_image()
	var rat_h := rat.get_used_rect().size.y / EnemyAnim.FILE_SCALE
	var crow_h := crow.get_used_rect().size.y / EnemyAnim.FILE_SCALE
	assert_true(rat_h * 390.0 / 720.0 >= 40.0, "쥐 폰 키 %.1f" % (rat_h * 390.0 / 720.0))
	assert_true(crow_h >= 78.0 and crow_h <= 96.0, "졸개 게임 키 %.1f (시안 84)" % crow_h)
