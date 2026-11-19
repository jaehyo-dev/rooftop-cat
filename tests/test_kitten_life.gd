extends TestCase
## 떠다니는 아기 살아 움직이기 (KittenLife, 2026-11-19): 반응 차례·우선, 가끔 하는 행동 간격·한 마리만·연속 안 함,
## 슬라이딩 엎드림, 깜빡임·숨·꼬리 박자가 아기마다 다름, 시드 고정, 모든 프레임 그림이 있음

const DT := 1.0 / 60.0


func _run(life: KittenLife, seconds: float, count: int = 6, sliding: bool = false) -> void:
	for n in roundi(seconds / DT):
		life.step(DT, sliding, count)


func test_만세는_앞_아기부터_차례로() -> void:
	var life := KittenLife.new(1)
	life.react("cheer")
	var started := []
	for n in 120:
		life.step(DT, false, 6)
		for i in 6:
			if started.size() == i and life.act(i) == "cheer":
				started.append(n * DT)
	assert_true(started.size() == 6, "6마리 모두 만세: %s" % [started])
	for i in started.size():
		assert_true(absf(started[i] - i * Balance.KITTEN_CHAIN_DELAY) <= DT * 1.5, "아기 %d는 %.2f초 늦게 (%.3f)" % [i, i * Balance.KITTEN_CHAIN_DELAY, started[i]])


func test_반응은_가끔_하는_행동을_끊는다() -> void:
	var life := KittenLife.new(2)
	for n in 2000:
		life.step(DT, false, 1)
		if life.act(0) in KittenLife.IDLE_ACTS:
			break
	assert_true(life.act(0) in KittenLife.IDLE_ACTS, "1마리면 언젠가 가끔 하는 행동")
	life.react("cheer")
	_run(life, DT * 2, 1)
	assert_true(life.act(0) == "cheer" and life.frame(0).begins_with("cheer"), "하품 등 하던 중에 점프하면 바로 만세: %s" % life.frame(0))


func test_가끔_하는_행동은_한_마리씩_간격_있게_연속_안_함() -> void:
	var life := KittenLife.new(3)
	var last := ["", "", "", "", "", ""]
	var ends := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var gaps := []
	var total := 0
	for n in roundi(120.0 / DT):
		life.step(DT, false, 6)
		var doing := 0
		for i in 6:
			var a := life.act(i)
			if a in KittenLife.IDLE_ACTS:
				doing += 1
				if a != last[i]:
					if ends[i] > 0.0:
						gaps.append(n * DT - ends[i])
					total += 1
			elif last[i] in KittenLife.IDLE_ACTS:
				ends[i] = n * DT
			last[i] = a if a in KittenLife.IDLE_ACTS else ""
		assert_true(doing <= 1, "화면 전체에서 한 번에 한 마리만")
	assert_true(total >= 8, "2분에 가끔 하는 행동이 여러 번 (%d)" % total)
	for g in gaps:
		assert_true(g >= KittenLife.IDLE_GAP.x - DT, "같은 아기는 6초 이상 쉬고 다음 행동 (%.2f)" % g)


func test_같은_행동을_연속으로_안_한다() -> void:
	var life := KittenLife.new(4)
	var seen := []
	var prev := ""
	for n in roundi(200.0 / DT):
		life.step(DT, false, 1)
		var a := life.act(0)
		if a != prev and a in KittenLife.IDLE_ACTS:
			seen.append(a)
		prev = a
	assert_true(seen.size() >= 10, "혼자면 200초에 10번 이상 (%d)" % seen.size())
	for k in range(1, seen.size()):
		assert_true(seen[k] != seen[k - 1], "연속 같은 행동 없음: %s" % [seen])
	for a in KittenLife.IDLE_ACTS:
		assert_true(a in seen, "%s도 나옴" % a)


func test_슬라이딩_동안_엎드리고_끝나면_폭_앉아_돌아옴() -> void:
	var life := KittenLife.new(5)
	life.react("cheer")
	_run(life, 0.3, 6, true)
	for i in 6:
		assert_true(life.frame(i) == "lie", "슬라이딩 중 엎드림 (%s)" % life.frame(i))
	_run(life, 0.3, 6, true)
	assert_true(life.frame(5) == "lie", "슬라이딩 전에 한 점프 만세는 사라짐")
	life.step(DT, false, 6)
	assert_true(life.frame(0) == "squat", "일어나며 폭 앉기")
	_run(life, 0.3, 6)
	assert_true(life.frame(0) in ["base", "blink"] or life.act(0) in KittenLife.IDLE_ACTS, "다시 앉음 (%s)" % life.frame(0))


func test_착지_폭_앉기는_내려앉는_때() -> void:
	var life := KittenLife.new(8)
	life.react("squat", 1)
	var started := []
	for n in 120:
		life.step(DT, false, 6)
		for i in 6:
			if started.size() == i and life.act(i) == "squat":
				started.append(n * DT)
	assert_true(started.size() == 6, "6마리 모두 폭 앉기")
	for i in started.size():
		assert_true(absf(started[i] - (i + 1) * Balance.KITTEN_CHAIN_DELAY) <= DT * 1.5, "아기 %d는 줄 출렁처럼 %.2f초 늦게 (%.3f)" % [i, (i + 1) * Balance.KITTEN_CHAIN_DELAY, started[i]])


func test_놀람은_모두_바로() -> void:
	var life := KittenLife.new(6)
	life.react("surprised", -1)
	life.step(DT, false, 6)
	for i in 6:
		assert_true(life.act(i) == "surprised", "아기 %d 놀람" % i)


func test_깜빡임_숨_꼬리는_아기마다_다르고_시드로_고정() -> void:
	var a := KittenLife.new(7)
	var b := KittenLife.new(7)
	var blinks := [[], [], []]
	for n in roundi(20.0 / DT):
		a.step(DT, false, 0)
		b.step(DT, false, 0)
		for i in 3:
			assert_true(a.frame(i) == b.frame(i) and a.tail(i, 5) == b.tail(i, 5), "같은 시드 = 같은 움직임")
			if a.frame(i) == "blink" and (blinks[i].is_empty() or n * DT - blinks[i][-1] > 0.5):
				blinks[i].append(n * DT)
	for i in 3:
		assert_true(blinks[i].size() >= 3, "20초에 3번 이상 깜빡 (%d)" % blinks[i].size())
		for k in range(1, blinks[i].size()):
			var gap: float = blinks[i][k] - blinks[i][k - 1]
			assert_true(gap >= KittenLife.BLINK_GAP.x - 0.05 and gap <= KittenLife.BLINK_GAP.y + 0.2, "깜빡 간격 2~5초 (%.2f)" % gap)
	assert_true(blinks[0] != blinks[1], "아기마다 깜빡이는 때가 다름")
	assert_true(a.breath(0) != a.breath(1) and a.kittens[0].wag_time != a.kittens[1].wag_time, "숨·꼬리 박자가 아기마다 다름")
	var high := 0.0
	for n in 200:
		a.step(DT, false, 0)
		high = maxf(high, a.breath(0).y)
	assert_true(high > 1.01 and high <= 1.0 + KittenLife.BREATH + 0.0001, "몸 1~2%% 부풂 (%.4f)" % high)


func test_모든_프레임_그림이_같은_캔버스() -> void:
	var base: Texture2D = load("res://assets/sprites/kittens/cheese/wait.png")
	for f in KittenLife.FRAMES:
		var tex: Texture2D = load("res://assets/sprites/kittens/cheese/alive_%s.png" % f)
		assert_true(tex != null and tex.get_size() == base.get_size(), "alive_%s.png 크기 = wait.png" % f)
	for act in KittenLife.ACTS:
		for step in KittenLife.ACTS[act]:
			assert_true(step[0] in KittenLife.FRAMES, "%s의 %s 그림 있음" % [act, step[0]])
