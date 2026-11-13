extends TestCase
## 줄줄이 고양이 행렬 시험판 (CatParade): 배수·피버, 기록 재생(거리 기준), 길고양이 자리·만남, 부딪힘 A/B, 점수 배수.

const BalanceBot := preload("res://tests/balance_bot.gd")
const DT := 1.0 / 120.0


## 줄을 켠 판 (옥상 생성기만, 장애물 없음)
func _sim(seed_value: int = 3, course: bool = false) -> RunnerSim:
	var sim := RunnerSim.new(seed_value, Balance.RUN_SPEED, course)
	sim.parade_on = true
	return sim


## 주인공 바로 앞 장애물 (다음 step에 몸에 닿음)
func _block(sim: RunnerSim) -> void:
	sim.obstacles.append({"id": 900, "kind": "pot", "x": sim.x + 20.0, "w": 40.0, "y0": sim.y, "y1": sim.y + 60.0, "base": sim.y})


func test_배수와_피버() -> void:
	assert_eq(CatParade.mult_for(0), 1.0)
	assert_true(is_equal_approx(CatParade.mult_for(1), 1.2), "1마리 x1.2")
	assert_true(is_equal_approx(CatParade.mult_for(6), 2.2), "6마리 x2.2")
	var parade := CatParade.new(1)
	parade.fill(4)
	assert_false(parade.fever(), "4마리는 피버 아님")
	parade.fill(5)
	assert_true(parade.fever(), "5마리부터 골골")
	parade.fill(9)
	assert_eq(parade.cats.size(), Balance.PARADE_MAX, "최대 6마리")


## 주인공이 뛴 자리에서 따라오는 고양이도 뛴다: 속도가 달라도 뛰기 시작하는 x가 같다 (시간이 아니라 거리 기준)
func test_따라오는_고양이는_주인공이_뛴_자리에서_뛴다() -> void:
	for speed in [Balance.RUN_SPEED, 900.0]:
		var sim := RunnerSim.new(3, speed, false)
		sim.accelerate = false
		var parade := CatParade.new(1)
		var takeoff := INF
		var ground := sim.y
		var follow_off := [INF, INF, INF]
		for i in 240:
			var y_before := sim.y
			sim.step(DT, i >= 5 and i < 25)
			if sim.jumped:
				takeoff = sim.x
				ground = y_before
			parade.record({"x": sim.x, "y": sim.y})
			# 줄의 각 고양이가 처음 뜨는 자리 (화면처럼 기록하면서 재생)
			for n in 3:
				if follow_off[n] == INF and parade.sample(CatParade.slot_x(n, sim.x)).y > ground + 1.0:
					follow_off[n] = CatParade.slot_x(n, sim.x)
		assert_true(takeoff < INF, "주인공이 뜀 (%d)" % speed)
		for n in 3:
			assert_true(absf(follow_off[n] - takeoff) <= speed * DT + 1.0, "%d번째가 같은 자리에서 뜀 (속도 %d, %.1f / %.1f)" % [n + 1, speed, follow_off[n], takeoff])


func test_기록은_줄_길이만큼만_남긴다() -> void:
	var parade := CatParade.new(1)
	for i in 3000:
		parade.record({"x": i * 3.0, "y": 0.0})
	assert_true(parade.trail[1].x >= CatParade.slot_x(Balance.PARADE_MAX, 2999 * 3.0) - 200.0, "오래된 기록 지움")
	assert_true(parade.trail.size() < 400, "기록 수 %d" % parade.trail.size())
	assert_eq(parade.sample(-50.0).y, 0.0, "기록 앞은 첫 기록 높이")


## 길고양이는 장애물·구조물·아이템과 떨어진 옥상 위, 그 자리 땅 생선은 치움
func test_길고양이_자리는_장애물과_생선을_피한다() -> void:
	var placed := 0
	for seed_value in range(1, 41):
		var sim := _sim(seed_value, true)
		sim.parade.call_now()
		sim.parade.update(sim, DT)
		if sim.parade.strays.is_empty():
			continue
		placed += 1
		var s: Dictionary = sim.parade.strays[0]
		assert_true(s.x >= sim.x + sim.view_ahead, "화면 밖에서 나옴 (시드 %d)" % seed_value)
		var roof := sim.roof_at(s.x)
		assert_eq(roof.top, s.y, "옥상 위 (시드 %d)" % seed_value)
		assert_false(roof.get("platform", false), "전봇대 판 아님")
		for o in sim.obstacles:
			assert_true(o.x + o.w + Balance.STRAY_CLEAR <= s.x or o.x - Balance.STRAY_CLEAR >= s.x, "장애물과 떨어짐 (시드 %d)" % seed_value)
		for st in sim.structures:
			assert_true(st.right + Balance.STRAY_CLEAR <= s.x or st.left - Balance.STRAY_CLEAR >= s.x, "트램펄린·줄과 떨어짐")
		for item in sim.items:
			if item.y <= s.y + Balance.ITEM_LIFT:
				assert_true(absf(item.x - s.x) >= FishRoad.RESERVED_GAP, "땅 아이템과 안 겹침 (시드 %d, %s)" % [seed_value, item.kind])
	assert_true(placed >= 35, "대부분 시드에서 바로 놓임 (%d/40)" % placed)


func test_지나가기만_하면_점프_중이어도_만난다() -> void:
	var sim := _sim()
	sim.parade.call_now()
	sim.parade.update(sim, DT)
	var s: Dictionary = sim.parade.strays[0]
	sim.x = s.x - 1.0
	sim.y += 200.0  # 높이 떠 있음
	sim.parade.update(sim, DT)
	assert_eq(sim.parade.cats.size(), 0, "아직 안 지남")
	sim.x = s.x
	sim.parade.update(sim, DT)
	assert_eq(sim.parade.cats.size(), 1, "지나는 순간 만남")
	assert_eq(sim.parade.met.size(), 1, "이번에 만남 알림")
	assert_eq(sim.parade.cats[0].look, s.look, "같은 무늬")
	assert_true(sim.parade.strays.is_empty() or sim.parade.strays[0].x > s.x, "그 길고양이는 줄로 옮김")


func test_줄이_꽉_차면_길고양이가_안_나온다() -> void:
	var sim := _sim()
	sim.parade.fill(Balance.PARADE_MAX)
	sim.parade.call_now()
	sim.parade.update(sim, DT)
	assert_true(sim.parade.strays.is_empty())


## 붙는 중에는 만난 자리에서 줄 맨 뒤로 옮겨 가고, 다 붙으면 기록 그대로
func test_붙는_중에는_만난_자리에서_줄_뒤로() -> void:
	var parade := CatParade.new(1)
	for i in 400:
		parade.record({"x": i * 4.0, "y": 100.0})
	parade.cats.append({"look": "gray", "quirk": 0.5, "from": Vector2(1500.0, 100.0), "t": 0.0})
	var leader := 1500.0
	assert_eq(parade.follower(0, leader).x, 1500.0, "처음엔 만난 자리")
	parade.cats[0].t = Balance.PARADE_JOIN_TIME
	assert_eq(parade.follower(0, leader).x, CatParade.slot_x(0, leader), "다 붙으면 줄 자리")
	assert_false(parade.follower(0, leader).has("joining"))


func test_첫_만남과_간격() -> void:
	for seed_value in TestCase.pick([1, 2, 3, 4, 5, 6], 3):
		var stats: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS["숙련"], seed_value, 80.0, Balance.RUN_SPEED, true, [], [], null, "B")
		var met: Array = stats.met_at
		if stats.time < 40.0:
			continue  # 일찍 끝난 판은 간격을 볼 수 없음
		assert_true(met.size() >= 2, "만남 %d번 (시드 %d)" % [met.size(), seed_value])
		assert_true(met[0] >= 9.5 and met[0] <= 15.5, "첫 만남 %.1f초 (시드 %d)" % [met[0], seed_value])
		for i in range(1, met.size()):
			var gap: float = met[i] - met[i - 1]
			assert_true(gap >= 14.0 and gap <= 27.0, "간격 %.1f초 (시드 %d)" % [gap, seed_value])


func test_부딪힘_A는_하트도_잃고_맨_뒤가_도망() -> void:
	var sim := _sim()
	sim.parade.fill(2)
	var last: Dictionary = sim.parade.cats[1]
	_block(sim)
	sim.step(DT, false)
	assert_eq(sim.hearts, Balance.HEARTS_MAX - 1, "하트 -1")
	assert_eq(sim.parade.cats.size(), 1, "한 마리 도망")
	assert_true(sim.scared, "도망 알림")
	assert_true(is_same(sim.parade.fled[0], last), "맨 뒤 고양이")


func test_부딪힘_B는_줄이_있으면_하트_대신() -> void:
	var sim := _sim()
	sim.parade.mode = "B"
	sim.parade.fill(1)
	_block(sim)
	sim.step(DT, false)
	assert_eq(sim.hearts, Balance.HEARTS_MAX, "하트 그대로")
	assert_eq(sim.parade.cats.size(), 0, "도망")
	assert_true(sim.invuln_time > 0.0, "무적은 똑같이")
	assert_eq(sim.time_since_hit, 99.0 + DT, "하트 깨짐 연출 없음")
	sim.invuln_time = 0.0
	_block(sim)
	sim.step(DT, false)
	assert_eq(sim.hearts, Balance.HEARTS_MAX - 1, "줄이 없으면 하트를 잃음")
	assert_false(sim.scared)


func test_질주로_부순_장애물은_도망이_아니다() -> void:
	var sim := _sim()
	sim.parade.fill(3)
	sim._start_dash()
	_block(sim)
	sim.step(DT, false)
	assert_eq(sim.smashed.size(), 1, "부숨")
	assert_eq(sim.parade.cats.size(), 3, "줄 그대로")


func test_점수_배수() -> void:
	var sim := _sim()
	sim.parade.fill(6)
	var x0 := sim.x
	for i in 60:
		sim.step(DT, false)
	var meters := (sim.x - x0) / Balance.PX_PER_METER
	assert_true(absf(sim.parade_bonus - meters * 1.2) < 0.01, "거리 점수 x2.2 (%.2f / %.2f)" % [sim.parade_bonus, meters * 1.2])
	sim.items.append({"kind": "fish", "x": sim.x, "y": sim.y + 40.0})
	var before := sim.combo.points
	sim.step(DT, false)
	assert_eq(sim.combo.points - before, roundi(Balance.FISH_POINTS * 2.2), "생선 x2.2")
	var off := RunnerSim.new(3, Balance.RUN_SPEED, false)
	for i in 60:
		off.step(DT, false)
	assert_eq(off.parade_bonus, 0.0, "줄을 끄면 배수 없음")
