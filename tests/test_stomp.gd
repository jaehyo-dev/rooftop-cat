extends TestCase
## 밟기 (2026-11-17 액션 시험판): 내려오며 장애물 윗면을 밟으면 부수고 튕김·더블점프 다시·연속 점수, 옆·아래에서 닿으면 피격.
## 사람 기준: 평지에서 장애물 앞 누르는 때·길이를 훑어 모든 경우가 "통과·밟기·피격" 중 하나이고,
## 피격은 언제나 옆·아래에서 닿은 것(직전 발이 윗면보다 충분히 아래)이어야 한다 (억울한 피격 없음).

const DT := 1.0 / 60.0


## 끝없는 평지 (높이 0), 속도 고정, 장애물 하나 (몸 가운데에서 ahead 앞)
func _flat(kind: String, ahead: float, speed: float = 600.0) -> RunnerSim:
	var sim := RunnerSim.new(1, speed, false)
	sim.accelerate = false
	sim.items.clear()
	sim.structures.clear()
	sim.roofs.clear()
	sim.roofs.append({"left": -1000.0, "right": 1.0e7, "top": 0.0})
	sim.set("_ground_roof", sim.roofs[0])
	sim.y = 0.0
	var o: Dictionary = Balance.OBSTACLES[kind]
	sim.obstacles.append({"id": 1, "kind": kind, "x": sim.x + ahead, "w": o.w, "y0": o.y0, "y1": o.y1, "base": 0.0, "k": Balance.FLOCK_SPEED / speed if kind == "flock" and speed > 0.0 else 0.0})
	return sim


## 위에서 떨어뜨림: 장애물 바로 위 높이 drop에서 아래로
func test_위에서_내려오면_밟는다() -> void:
	for kind in Balance.STOMPABLE:
		var sim := _flat(kind, 0.0, 0.0)
		var o: Dictionary = sim.obstacles[0]
		sim.x = o.x + o.w * 0.5
		sim.on_ground = false
		sim.set("_double_used", true)
		sim.y = o.y1 + 60.0
		sim.vy = -100.0
		var stomped := false
		for i in 60:
			sim.step(DT, false)
			stomped = stomped or not sim.stomped.is_empty()
			if stomped:
				break
		assert_true(stomped, "%s 밟음" % kind)
		assert_eq(sim.hearts, Balance.HEARTS_MAX, "%s 하트 그대로" % kind)
		assert_true(sim.vy > 0.0, "%s 튕겨 오름" % kind)
		assert_false(sim.get("_double_used"), "%s 더블점프 다시" % kind)
		assert_eq(sim.obstacles.size(), 0, "%s 부서짐" % kind)
		assert_eq(sim.stomp_points, Balance.STOMP_POINTS, "%s 점수" % kind)


func test_옆에서_닿으면_피격() -> void:
	for kind in ["pot", "ac", "tank"]:
		var sim := _flat(kind, 200.0)
		for i in 60:
			sim.step(DT, false)
		assert_eq(sim.hearts, Balance.HEARTS_MAX - 1, "%s 달려서 부딪힘" % kind)
		assert_eq(sim.stomp_points, 0)


## 비둘기 아래에서 뛰어오르면 머리를 박음 (밟기 아님)
func test_비둘기는_아래에서_뛰면_피격_안_뛰면_통과() -> void:
	var sim := _flat("flock", 500.0)
	for i in 120:
		sim.step(DT, false)
	assert_eq(sim.hearts, Balance.HEARTS_MAX, "안 뛰면 통과")
	sim = _flat("flock", 500.0)
	var hit := false
	for i in 120:
		sim.step(DT, i >= 25 and i < 45)  # 비둘기 바로 밑에서 길게 뜀
		hit = hit or not sim.hit_obstacle.is_empty()
	assert_true(hit, "아래에서 머리 박음")
	assert_eq(sim.stomp_points, 0)


func test_연속_밟기는_땅에_닿으면_처음부터() -> void:
	var sim := _flat("pot", 0.0, 0.0)
	for n in [1, 2, 3]:
		var o: Dictionary = Balance.OBSTACLES.pot
		sim.obstacles.append({"id": 10 + n, "kind": "pot", "x": sim.x - o.w * 0.5, "w": o.w, "y0": 0.0, "y1": o.y1, "base": 0.0})
		sim.on_ground = false
		sim.vy = -300.0
		sim.y = o.y1 + 10.0
		for i in 30:
			sim.step(DT, false)
			if not sim.stomped.is_empty():
				break
		assert_eq(sim.stomp_chain, n, "%d연속" % n)
	assert_eq(sim.stomp_points, Balance.STOMP_POINTS * (1 + 2 + 3), "x1 + x2 + x3 (콤보 x1, 아기 없음)")
	for i in 120:
		sim.step(DT, false)
	assert_true(sim.on_ground, "내려섬")
	assert_eq(sim.stomp_chain, 0, "땅에 닿으면 처음부터")


## 사람 기준: 누르는 때(1/30초 간격)·길이(톡·중간·길게·더블)를 훑어 모든 판에서 피격은 옆·아래에서 닿았을 때뿐
func test_억울한_피격_없음_위에서는_밟기_옆은_피격() -> void:
	for kind in ["pot", "ac", "tank", "flock"]:
		for speed in [600.0, 900.0]:
			var stomps := 0
			for press in range(0, 45):
				for hold in [0.0, 0.1, 0.2, 0.3]:
					for double_at in [-1.0, 0.25, 0.45]:
						var sim := _flat(kind, 700.0, speed)
						var hit_from := INF
						var t := 0.0
						for i in 240:
							var p := float(press) / 30.0
							var held := t >= p and t < p + maxf(hold, DT)
							held = held or (double_at > 0.0 and t >= p + double_at and t < p + double_at + 0.1)
							var feet_before := sim.y
							sim.step(DT, held)
							t += DT
							if not sim.hit_obstacle.is_empty():
								hit_from = feet_before
							stomps += sim.stomped.size()
						var o: Dictionary = Balance.OBSTACLES[kind]
						if hit_from != INF:
							# 피격 직전 발이 윗면 근처 위였다면 억울한 피격
							assert_true(hit_from < o.y1 - Balance.STOMP_TOL,
									"%s 속도 %d 누름 %.2f 길이 %.1f 더블 %.2f: 위에서 왔는데 피격 (발 %.0f)" % [kind, speed, float(press) / 30.0, hold, double_at, hit_from])
			assert_true(stomps > 0, "%s 속도 %d: 밟는 누름이 있음" % [kind, speed])


## 슬라이딩·내려찍기 (2026-11-17)
func test_간판은_서면_맞고_슬라이딩하면_지난다() -> void:
	var sim := _flat("sign", 400.0)
	for i in 90:
		sim.step(DT, false)
	assert_eq(sim.hearts, Balance.HEARTS_MAX - 1, "서서 달리면 맞음")
	sim = _flat("sign", 400.0)
	for i in 90:
		sim.step(DT, false, true)
		assert_true(sim.sliding, "누르는 동안 슬라이딩")
	assert_eq(sim.hearts, Balance.HEARTS_MAX, "슬라이딩은 지남")
	sim.step(DT, false, false)
	assert_false(sim.sliding, "떼면 바로 일어남")
	assert_true(absf(sim.vx() - 600.0) < 0.01, "속도 그대로")


func test_슬라이딩_중_점프() -> void:
	var sim := _flat("pot", 5000.0)
	sim.step(DT, false, true)
	assert_true(sim.sliding)
	sim.step(DT, true, true)
	assert_true(sim.jumped and not sim.sliding, "누르면 바로 점프")


func test_공중_내려찍기는_빨리_내려와_밟고_착지하면_슬라이딩() -> void:
	var sim := _flat("pot", 5000.0)
	sim.step(DT, true)
	for i in 10:
		sim.step(DT, true)
	var plain := sim.y
	sim.step(DT, false, true)
	assert_true(sim.dived and sim.diving, "공중에서 누르면 내려찍기")
	assert_true(sim.vy <= -Balance.DIVE_SPEED + 0.01, "빠르게 아래로")
	for i in 60:
		sim.step(DT, false, true)
		if sim.on_ground:
			break
	assert_true(sim.on_ground and sim.sliding, "누른 채 닿으면 슬라이딩으로 이어짐")
	assert_true(plain > 0.0)
	# 내려찍기로 밟기
	sim = _flat("ac", 0.0, 0.0)
	var o: Dictionary = sim.obstacles[0]
	sim.x = o.x + o.w * 0.5
	sim.on_ground = false
	sim.y = o.y1 + 200.0
	sim.vy = 300.0
	var stomped := false
	sim.step(DT, false, true)
	for i in 30:
		sim.step(DT, false, true)
		stomped = stomped or not sim.stomped.is_empty()
	assert_true(stomped, "내려찍기로 밟음")
	assert_eq(sim.hearts, Balance.HEARTS_MAX)


func test_비둘기는_슬라이딩으로도_지난다() -> void:
	var sim := _flat("flock", 500.0)
	for i in 120:
		sim.step(DT, false, true)
	assert_eq(sim.hearts, Balance.HEARTS_MAX)


## 간판은 단계 4(45초)부터: 처음 30초에는 안 나옴
func test_간판은_처음_30초_뒤에만() -> void:
	var found := 0
	for id: String in CourseData.SEGMENTS:
		var seg: Dictionary = CourseData.SEGMENTS[id]
		for r: Dictionary in seg.roofs:
			for o: Array in r.get("obs", []):
				if o[0] == "sign":
					found += 1
					assert_true(Balance.SPEED_STAGES[seg.min_stage - 1][0] >= 30.0, "%s는 30초 뒤" % id)
					assert_eq(o[2], "slide")
	assert_true(found >= 3 and found <= 4, "간판 구간 3~4개 (%d)" % found)


## 내려찍기 뒤 더블점프·줄 튕김은 위로 간다 (내려찍기가 속도를 덮어쓰지 않음, Codex 리뷰)
func test_내려찍기_뒤_더블점프는_올라간다() -> void:
	var sim := _flat("pot", 5000.0)
	sim.on_ground = false
	sim.set("_jumped", true)
	sim.y = 800.0  # 높이 (착지 직전 누름으로 남지 않게)
	sim.step(DT, false, true)
	assert_true(sim.diving)
	sim.step(DT, true, false)
	assert_true(sim.double_jumped and not sim.diving, "더블점프가 내려찍기를 끝냄")
	sim.step(DT, true, false)
	assert_true(sim.vy > 0.0, "올라감")
