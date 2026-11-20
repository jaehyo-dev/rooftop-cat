extends TestCase
## 구름 타기 (2026-11-20, KittenFlock.ride·KittenLife.riding): 혜성 꼬리 줄 모양, 주인공 옮기기, 늘어짐·물결, 구름 조각, 타기 그림 고르기

const DT := 1.0 / 60.0
const GROUND := 470.0


func _cats(n: int) -> Array:
	var cats := []
	for i in n:
		cats.append({"look": CatParade.LOOKS[i], "quirk": fmod(0.37 * i + 0.11, 1.0)})
	return cats


func _floor(_x: float) -> float:
	return GROUND


func _lead(n: int) -> Vector2:
	return Vector2(Balance.CAT_SCREEN_X + KittenFlock.lead_shift(n), GROUND)


## 자리를 잡고 shift까지 끝난 무리 (2초)
func _flock(n: int, seed_value: int = 1) -> KittenFlock:
	var flock := KittenFlock.new(seed_value)
	for i in n:
		flock.place(i, _lead(n) + KittenFlock.rest(i, n))
	for f in 120:
		flock.step(DT, _lead(n), _cats(n), _floor)
	return flock


## 주인공 등 높이에서 뒤로 낮고 완만하게: 한 칸마다 조금만 높아지고, 구름 뒤 끝까지 화면 안, 주인공 몸 뒤
func test_혜성_꼬리_줄은_뒤로_조금씩만_높아지고_화면_안() -> void:
	var r := KittenFlock.ratio()
	for n in range(1, Balance.PARADE_MAX + 1):
		var x0 := Balance.CAT_SCREEN_X + KittenFlock.lead_shift(n)
		for i in n:
			var a := KittenFlock.rest(i, n)
			var tag := "%d마리 자리 %d %s" % [n, i, a]
			assert_true(x0 + a.x + KittenFlock.RIDE_TAIL * r >= KittenFlock.EDGE - 0.01, tag + " 구름 뒤 끝이 화면 안")
			assert_true(a.x <= -Balance.CAT_BODY_SIZE.x * 0.5, tag + " 주인공 몸 뒤")
			assert_true(GROUND + a.y >= KittenFlock.top(), tag + " 생선 수 아래")
			if i > 0:
				var b := KittenFlock.rest(i - 1, n)
				assert_true(b.y - a.y > 0.0 and b.y - a.y <= KittenFlock.RIDE_RISE * r + 0.01, tag + " 앞 아기보다 조금만 높음")
				assert_true(b.x - a.x >= KittenFlock.RIDE_GAP * r * KittenFlock.RIDE_GAP_MIN - 0.01, tag + " 간격 하한")
		assert_true(KittenFlock.rest(0, n).y - KittenFlock.rest(n - 1, n).y <= 6.0 * KittenFlock.RIDE_RISE * r, "%d마리 전체 높이 차 작음" % n)
	assert_eq(KittenFlock.lead_shift(3), 0.0, "3마리는 안 옮김")
	assert_true(KittenFlock.lead_shift(4) < KittenFlock.lead_shift(5) and KittenFlock.lead_shift(5) <= KittenFlock.lead_shift(6), "많을수록 더 옮김")
	assert_true(KittenFlock.lead_shift(6) > 0.0 and KittenFlock.lead_shift(6) <= KittenFlock.SHIFT_MAX, "6마리는 최대 SHIFT_MAX까지 옮김")
	KittenFlock.ride = false
	assert_eq(KittenFlock.lead_shift(6), 0.0, "예전 방식은 안 옮김")
	KittenFlock.ride = true


## 시험 단추 크기(작게·중간·지금) 모두: 6마리가 쉬는 자리에 그대로 있고(밀어내기로 뭉치지 않음) 맨 뒤 구름 끝까지 화면 안
func test_모든_크기에서_6마리_줄이_화면_안에_뭉치지_않는다() -> void:
	var keep := CatParade.size_pick
	for k in Balance.KITTEN_SIZES.size():
		CatParade.size_pick = k
		var r := KittenFlock.ratio()
		var flock := _flock(6)
		for i in 6:
			var want := _lead(6) + KittenFlock.rest(i, 6)
			var tag := "%s 아기 %d" % [Balance.KITTEN_SIZES[k].name, i]
			assert_true(absf(flock.pos[i].x - want.x) < 1.0, tag + " 가로 자리 %.1f / %.1f" % [flock.pos[i].x, want.x])
			assert_true(flock.pos[i].x + KittenFlock.RIDE_TAIL * r >= KittenFlock.EDGE - 0.5, tag + " 구름 끝 화면 안")
	CatParade.size_pick = keep


## 아기가 없는 자리에는 늘어짐이 쌓이지 않음 (나중에 온 아기가 한꺼번에 튀지 않게)
func test_늘어짐은_지금_탄_아기에게만() -> void:
	var flock := _flock(2)
	for k in 5:
		flock.drag("dash")
	var cats := _cats(3)
	flock.place(2, _lead(2) + KittenFlock.rest(2, 3))
	var start: float = flock.pos[2].x
	var worst := 0.0
	for f in 60:
		flock.step(DT, Vector2(Balance.CAT_SCREEN_X + flock.shift, GROUND), cats, _floor)
		worst = maxf(worst, absf(flock.pos[2].x - start))
	assert_true(worst < 30.0, "새로 온 아기 가로 움직임 %.1f (쌓인 충격 없음)" % worst)


## 마리 수가 바뀌면 주인공 자리가 SHIFT_TIME초쯤에 걸쳐 부드럽게 (한 프레임 이동 작게)
func test_주인공_옮기기는_부드럽게() -> void:
	var flock := _flock(3)
	assert_eq(flock.shift, 0.0, "3마리 shift 0")
	var cats := _cats(6)
	for i in range(3, 6):
		flock.place(i, _lead(3) + KittenFlock.rest(i, 6))
	var biggest := 0.0
	var done := -1
	for f in 60:
		var was := flock.shift
		flock.step(DT, Vector2(Balance.CAT_SCREEN_X + flock.shift, GROUND), cats, _floor)
		biggest = maxf(biggest, absf(flock.shift - was))
		if done < 0 and is_equal_approx(flock.shift, KittenFlock.lead_shift(6)):
			done = f + 1
	assert_true(done * DT >= KittenFlock.SHIFT_TIME - 0.05 and done * DT <= KittenFlock.SHIFT_TIME + 0.05, "%.2f초에 다 옮김" % (done * DT))
	assert_true(biggest <= KittenFlock.SHIFT_MAX * 1.5 / (KittenFlock.SHIFT_TIME / DT) + 0.01, "한 프레임 가장 큰 이동 %.2f" % biggest)


## 점프 순간 뒤로 늘어졌다 따라붙음 (뒤 아기일수록 더, 앞 아기는 0.1~0.4초에 가장 멀리), 착지는 살짝 앞으로. 순간이동 없음
func test_빨라지면_뒤로_늘어졌다_따라붙는다() -> void:
	var n := 3  # 4마리부터는 맨 뒤가 화면 왼쪽 경계에서 눌림 (다음 테스트)
	var flock := _flock(n)
	var calm := _flock(n)
	var cats := _cats(n)
	flock.drag("jump")
	var most := []
	most.resize(n)
	most.fill(0.0)
	var at := 0.0
	var worst := 0.0
	for f in 120:
		var last := flock.pos.duplicate()
		flock.step(DT, _lead(n), cats, _floor)
		calm.step(DT, _lead(n), cats, _floor)
		for i in n:
			var back: float = calm.pos[i].x - flock.pos[i].x
			if back > most[i]:
				most[i] = back
				if i == 0:
					at = f * DT
			worst = maxf(worst, flock.pos[i].distance_to(last[i]))
	assert_true(most[0] > 10.0, "맨 앞도 눈에 띄게 늘어짐 %.1f" % most[0])
	for i in range(1, n):
		assert_true(most[i] > most[i - 1], "뒤 아기일수록 더 %s" % [most])
	assert_true(at > 0.1 and at < 0.4, "맨 앞이 가장 멀리 간 때 %.2f초" % at)
	assert_true(worst <= KittenFlock.MAX_SPEED * DT + 0.5, "한 프레임 가장 큰 이동 %.1f" % worst)
	for i in n:
		assert_true(absf(flock.pos[i].x - calm.pos[i].x) < 1.0, "2초 뒤 제자리 %d" % i)
	flock.drag("land")
	var fore := 0.0
	for f in 30:
		flock.step(DT, _lead(n), cats, _floor)
		calm.step(DT, _lead(n), cats, _floor)
		fore = maxf(fore, flock.pos[0].x - calm.pos[0].x)
	assert_true(fore > 2.0 and fore < most[0], "착지는 살짝 앞으로 %.1f" % fore)


## 6마리는 늘어져도 화면 왼쪽 밖으로 EDGE_OVER 넘게 안 나가고 맨 뒤가 경계에 딱 붙지 않음
func test_6마리_늘어짐은_화면_왼쪽에서_부드럽게_눌림() -> void:
	var r := KittenFlock.ratio()
	var flock := _flock(6)
	var cats := _cats(6)
	flock.drag("dash")
	var least := INF
	for f in 90:
		flock.step(DT, _lead(6), cats, _floor)
		least = minf(least, flock.pos[5].x + KittenFlock.RIDE_TAIL * r)
	assert_true(least >= KittenFlock.EDGE - KittenFlock.EDGE_OVER * r - 0.5, "맨 뒤 구름 끝 %.1f" % least)
	assert_true(least < KittenFlock.EDGE, "맨 뒤도 조금은 늘어짐 %.1f" % least)


## 평소 물결: 세로 폭 WAVE x 2 안팎, 앞에서 뒤로 흐름 (뒤 아기일수록 꼭대기가 늦음)
func test_물결은_앞에서_뒤로_흐른다() -> void:
	var n := 4
	var flock := _flock(n)
	var cats := _cats(n)
	var top := []
	var low := []
	var peak := []
	for i in n:
		top.append(INF)
		low.append(-INF)
		peak.append(0.0)
	for f in 110:  # 한 박자(1/WAVE_HZ = 1.8초)쯤
		flock.step(DT, _lead(n), cats, _floor)
		for i in n:
			if flock.pos[i].y < top[i]:
				top[i] = flock.pos[i].y
				peak[i] = f * DT
			low[i] = maxf(low[i], flock.pos[i].y)
	for i in n:
		var span: float = low[i] - top[i]
		assert_true(span > KittenFlock.WAVE * 1.4 and span < KittenFlock.WAVE * 2.6, "아기 %d 세로 폭 %.1f" % [i, span])
	var lag := KittenFlock.WAVE_STEP / (TAU * KittenFlock.WAVE_HZ)
	for i in range(1, n):
		var d: float = fposmod(peak[i] - peak[i - 1], 1.0 / KittenFlock.WAVE_HZ)
		assert_true(absf(d - lag) < 0.08, "아기 %d 꼭대기가 앞보다 %.2f초 늦음 (%.2f)" % [i, d, lag])


## 구름 조각: 아기마다 0.15~0.25초 간격, PUFF_LIFE초에 사라짐, 화면 전체 PUFF_MAX개 이하, 같은 시드면 같음. 예전 방식은 안 생김
func test_구름_조각은_간격과_상한을_지킨다() -> void:
	var a := _flock(6, 7)
	var b := _flock(6, 7)
	var cats := _cats(6)
	var made := 0
	var most := 0
	for f in 300:
		a.step(DT, _lead(6), cats, _floor)
		b.step(DT, _lead(6), cats, _floor)
		most = maxi(most, a.puffs.size())
		for p in a.puffs:
			assert_true(p.t < KittenFlock.PUFF_LIFE, "조각 나이 %.2f" % p.t)
			made += 1 if p.t == 0.0 else 0  # 이번 프레임에 생긴 조각
		assert_eq(a.puffs.size(), b.puffs.size(), "같은 시드 같은 수 (프레임 %d)" % f)
	var per_sec := made / (300.0 * DT) / 6.0
	assert_true(most <= KittenFlock.PUFF_MAX, "가장 많을 때 %d" % most)
	assert_true(per_sec >= 1.0 / KittenFlock.PUFF_GAP.y - 0.6 and per_sec <= 1.0 / KittenFlock.PUFF_GAP.x + 0.1, "아기 하나 초당 %.1f개" % per_sec)
	KittenFlock.ride = false
	var old := _flock(6)
	for f in 60:
		old.step(DT, _lead(6), cats, _floor)
	assert_eq(old.puffs.size(), 0, "예전 방식은 조각 없음")
	KittenFlock.ride = true


## 타기 그림: 올라가는 중 ride_up, 내려가는 중 ride_down, 그 밖 펄럭임 반복(3장 모두 나옴), 기준 사이에서 깜빡이지 않음.
## 착지 폭 앉기·슬라이딩은 ride_down, 깜빡임 없음
func test_타기_그림은_세로_속도로_고른다() -> void:
	var life := KittenLife.new(3)
	life.riding = true
	var seen := {}
	for f in 120:
		life.step(DT, false, 1, [0.0])
		seen[life.frame(0)] = true
	assert_eq(seen.keys().filter(func(k: String) -> bool: return k.begins_with("ride_")).size(), 3, "펄럭임 3장 %s" % [seen.keys()])
	assert_true(not seen.has("blink") and not seen.has("base"), "앉은 그림 안 나옴 %s" % [seen.keys()])
	life.step(DT, false, 1, [-400.0])
	assert_eq(life.frame(0), "ride_up", "올라감")
	life.step(DT, false, 1, [-100.0])
	assert_eq(life.frame(0), "ride_up", "기준 사이(되돌아가는 기준보다 빠름)면 그대로")
	life.step(DT, false, 1, [-20.0])
	assert_true(life.frame(0).begins_with("ride_") and life.frame(0) not in ["ride_up", "ride_down"], "느려지면 펄럭임")
	life.step(DT, false, 1, [400.0])
	assert_eq(life.frame(0), "ride_down", "내려감")
	life.step(DT, false, 1, [0.0])
	life.react("squat", 1)
	for f in 12:
		life.step(DT, false, 1, [0.0])
	assert_eq(life.frame(0), "ride_down", "착지 폭 앉기 대신 납작 붙기")
	life.step(DT, true, 1, [0.0])
	assert_eq(life.frame(0), "ride_down", "슬라이딩 동안 납작 붙기")
	for f in KittenLife.OWN_TAIL.filter(func(n: String) -> bool: return n.begins_with("ride_")):
		assert_true(ResourceLoader.exists("res://assets/sprites/kittens/cheese/alive_%s.png" % f), "%s 그림 있음" % f)
