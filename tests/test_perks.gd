extends TestCase
## 강화 6개·부스터 3개를 판 값으로 바꾸기 (Perks, review/v0.7.0/PLAN.md 3번).

const BalanceBot := preload("res://tests/balance_bot.gd")
const DT := 1.0 / 120.0
## v0.6.0 판 지문 (생선 점수만 5점으로 바꾼 v0.6.0 코드에서 잼, 2026-11-11):
## [실력, 시드, 시간x100, 생선, 최고 콤보, 점수, 거리, 더블점프, 질주 수, 부순 수, 부딪힘, 방울로 막음]
const V060 := [
	["익숙함", 1, 15000, 1601, 359, 26349, 1099, 8, 1, 6, 2, 0],
	["익숙함", 2, 15000, 1581, 287, 26382, 1092, 10, 1, 6, 0, 1],
	["익숙함", 3, 15000, 1515, 253, 25577, 1087, 10, 2, 13, 0, 1],
	["숙련", 1, 15000, 1606, 198, 25349, 1099, 7, 1, 6, 1, 0],
	["숙련", 2, 15000, 1581, 196, 25503, 1093, 10, 1, 6, 0, 0],
	["숙련", 3, 15000, 1546, 254, 25841, 1086, 7, 2, 13, 0, 1],
]


static func _fingerprint(skill: String, seed_value: int, perks: Perks) -> Array:
	var s: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS[skill], seed_value, 150.0, Balance.RUN_SPEED, true, [], [], perks)
	var hits := 0
	for kind in s.hits:
		hits += s.hits[kind]
	return [skill, seed_value, roundi(s.time * 100.0), s.fish, s.combo_best, s.score, s.meters, s.doubles, s.dash_count, s.dash_smashed, hits, s.blocks]


func test_0단계는_생선_점수_5점_말고는_v060_판과_같다() -> void:
	for row: Array in V060:
		assert_eq(_fingerprint(row[0], row[1], null), row, "강화 없음")
		assert_eq(_fingerprint(row[0], row[1], Perks.all(0, ["fish_bonus"])), row, "0단계 + 생선 +50%(판은 그대로)")


func test_0단계_값은_기존_수치와_같고_10단계는_표_끝값() -> void:
	var zero := Perks.new()
	assert_eq(zero.dash_time(), Balance.DASH_TIME)
	assert_eq(zero.magnet_time(), Balance.MAGNET_TIME)
	assert_eq(zero.magnet_radius(), Balance.MAGNET_RADIUS)
	assert_eq(zero.combo_step(), Balance.COMBO_STEP)
	assert_eq(zero.gold_points(), Balance.GOLD_POINTS)
	assert_eq(zero.cookie_gap(), Balance.SLOT_ITEMS[0][2], "쿠키 줄 간격")
	assert_eq(zero.fish_points(), Balance.FISH_POINTS)
	assert_eq(Balance.FISH_POINTS, 5, "v0.7.0 생선 기본 5점")
	var top := Perks.all(Balance.UPGRADE_MAX)
	assert_eq(top.dash_time(), 6.0)
	assert_eq(top.magnet_time(), Balance.MAGNET_TIME * 1.5)
	assert_eq(top.magnet_radius(), Balance.MAGNET_RADIUS * 1.5)
	assert_eq(top.combo_step(), 12, "콤보 가속: 20 → 12")
	assert_eq(top.gold_points(), 500)
	assert_eq(top.cookie_gap(), 70.0)
	assert_eq(top.fish_points(), 25)
	assert_eq(Perks.all(99).fish_points(), 25, "10단계보다 높으면 10단계")


func test_단계는_직선으로_같은_만큼_오른다() -> void:
	for kind: String in Balance.UPGRADES:
		var row: Array = Balance.UPGRADES[kind]
		var step: float = (row[1] - row[0]) / Balance.UPGRADE_MAX
		for lv in Balance.UPGRADE_MAX + 1:
			assert_true(is_equal_approx(Perks.new({kind: lv}).value(kind), row[0] + step * lv), "%s %d단계" % [kind, lv])
	assert_eq(Perks.new({"dash": 1}).dash_time(), 4.2, "질주 단계당 +0.2초")
	assert_eq(Perks.new({"fish": 1}).fish_points(), 7, "생선 단계당 +2점")
	assert_eq(Perks.new({"gold": 1}).gold_points(), 230, "황금 단계당 +30점")
	assert_eq(Perks.new({"cookie": 1}).cookie_gap(), 88.0, "쿠키 단계당 -2초")
	var steps: Array[int] = []
	for lv in Balance.UPGRADE_MAX + 1:
		steps.append(Perks.new({"combo": lv}).combo_step())
	assert_eq(steps, [20, 19, 18, 18, 17, 16, 15, 14, 14, 13, 12] as Array[int], "콤보 가속 단계별 생선 수 (반올림)")


func test_생선_그림은_0_3_6_10단계에서_바뀐다() -> void:
	var looks: Array[int] = []
	for lv in Balance.UPGRADE_MAX + 1:
		looks.append(Perks.new({"fish": lv}).fish_look())
	assert_eq(looks, [0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 3] as Array[int])


func test_강화_가격은_항목_33700_전체_202200() -> void:
	var total := 0
	for price: int in Balance.UPGRADE_PRICES:
		total += price
	assert_eq(Balance.UPGRADE_PRICES.size(), Balance.UPGRADE_MAX)
	assert_eq(total, 33700)
	assert_eq(total * Balance.UPGRADES.size(), 202200)
	assert_eq(Balance.BOOSTER_PRICES, {"dash_start": 500, "bell_start": 400, "fish_bonus": 800})


func test_판에서_생선_황금_콤보_가속_값을_쓴다() -> void:
	var sim := RunnerSim.new(1, Balance.RUN_SPEED, false, Perks.all(Balance.UPGRADE_MAX))
	assert_eq(sim.combo.step, 12)
	sim.accelerate = false
	sim.items.clear()
	sim.items.append({"kind": "fish", "x": sim.x + 60.0, "y": sim.y + Balance.ITEM_LIFT})
	sim.items.append({"kind": "gold", "x": sim.x + 200.0, "y": sim.y + Balance.ITEM_LIFT})
	for i in 60:
		sim.step(DT, false)
	assert_eq(sim.combo.points, 25 + 500, "생선 25점 + 황금 500점 (x1)")
	var combo := FishCombo.new()
	combo.step = 12
	for i in 11:
		combo.eat(5)
	assert_eq(combo.multiplier(), 1)
	combo.eat(5)
	assert_eq(combo.multiplier(), 2, "12개째부터 x2")
	for i in 36:
		combo.eat(5)
	assert_eq(combo.multiplier(), Balance.COMBO_MAX, "48개째에 x5 (0단계는 80개째)")


func test_쿠키_간격_강화는_첫_쿠키와_간격을_바꾸고_무작위_순서는_같다() -> void:
	var plain := ItemSlots.new(1)
	var fast := ItemSlots.new(1, 70.0)
	assert_eq(fast.choose(69.9, 2, false), "yarn", "70초 전에는 쿠키 없음")
	assert_eq(fast.choose(70.0, 2, false), "cookie", "70초부터")
	assert_eq(plain.choose(70.0, 2, false), "yarn", "0단계는 90초")
	fast.fill({"x": 0.0, "y": 0.0}, 70.0, 2, false)
	assert_true(fast.choose(139.9, 2, false) != "cookie")
	assert_eq(fast.choose(140.0, 2, false), "cookie", "다음 쿠키도 70초 뒤")
	assert_eq(ItemSlots.new(1, 90.0).fill({"x": 0.0, "y": 0.0}, 8.0, 3, false), plain.fill({"x": 0.0, "y": 0.0}, 8.0, 3, false), "90초면 기본과 같음")


func test_방울_달고_시작() -> void:
	assert_false(RunnerSim.new(1).has_bell)
	var sim := RunnerSim.new(1, Balance.RUN_SPEED, true, Perks.new({}, ["bell_start"]))
	assert_true(sim.has_bell, "처음부터 방울")


func test_질주로_출발은_1초에_시작해_착지하고_대본의_첫_질주와_겹치지_않는다() -> void:
	for skill in ["초보", "익숙함"]:
		for seed_value in 8:
			var s: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS[skill], seed_value + 1, 30.0, Balance.RUN_SPEED, true, [], [],
					Perks.all(Balance.UPGRADE_MAX, ["dash_start"]))
			var at: Array = s.dash_at
			var label := "%s 시드 %d %s" % [skill, seed_value + 1, str(at)]
			assert_true(at.size() >= 1 and absf(at[0] - Balance.BOOSTER_DASH_AT) < 0.02, label + ": 1초에 출발 질주")
			assert_true(s.dash_seconds.size() >= 1 and s.dash_seconds[0] >= 6.0, label + ": 6초 질주가 착지까지 끝남")
			if s.time >= 30.0:
				assert_eq(at.size(), 2, label + ": 대본 첫 질주도 먹음")
				# 출발 질주로 앞을 1.5배로 지나가 대본 질주(거리 기준)가 조금 일찍 온다 (부스터 없으면 20~25초, test_balance)
				assert_true(at[1] >= 18.0 and at[1] <= 25.0, label + ": 대본 질주는 18~25초")
				assert_true(at[1] > at[0] + s.dash_seconds[0], label + ": 겹치지 않음")


func test_출발_질주도_앞쪽에_질주용_줄을_바로_깐다() -> void:
	for seed_value in 12:
		for perks: Perks in [Perks.new({}, ["dash_start"]), Perks.all(Balance.UPGRADE_MAX, ["dash_start"])]:
			var sim := RunnerSim.new(seed_value + 1, Balance.RUN_SPEED, true, perks)
			while not sim.dash_started:
				sim.step(DT, false)
			assert_true(sim.on_ground and is_equal_approx(sim.y, sim.roofs[0].top), "첫 옥상 위에서 출발")
			var ahead := sim.items.filter(func(it: Dictionary) -> bool: return FishRoad.is_fish(it) and it.x > sim.x)
			ahead.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.x < b.x)
			assert_true(ahead.size() > 15, "시드 %d: 앞쪽 줄 %d마리" % [seed_value + 1, ahead.size()])
			var last := sim.x
			var gap := 0.0
			for fish in ahead:
				if fish.x > sim.x + perks.dash_time() * sim.vx():
					break
				gap = maxf(gap, fish.x - last)
				last = fish.x
			assert_true(gap < Balance.FISH_SPACING * 4.0, "시드 %d: 질주 거리 안에서 줄이 끊기지 않음 (%.0f)" % [seed_value + 1, gap])
			while sim.dashing:
				sim.step(DT, false)
			assert_false(sim.game_over, "착지")
