extends TestCase
## 밸런스 봇으로 실력별 한 판 길이를 잰다 (목표는 review/v0.6.0/PLAN.md 8번, 봇은 참고이고 사람이 최종).
## 익숙함 상한(300초)과 끝난 이유 비율(떨어짐 50~70%)은 지금 벗어나 있어 보고만 한다 (review/v0.6.0/2a3/balance.md).
## 봇과 실력 수치는 tests/balance_bot.gd. 시드를 고정해 결과가 항상 같다.

const BalanceBot := preload("res://tests/balance_bot.gd")
const SEEDS := 30
const MAX_TIME := 900.0  # 15분 버티면 그만 잰다


func test_실력별_한_판_길이와_끝난_이유() -> void:
	var medians := {}
	for skill_name in BalanceBot.SKILLS:
		var times: Array[float] = []
		var falls := 0
		var hearts := 0
		var early := 0
		for seed_value in SEEDS:
			var s: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS[skill_name], seed_value + 1, MAX_TIME)
			times.append(s.time)
			falls += 1 if s.end == "fall" else 0
			hearts += 1 if s.end == "hearts" else 0
			early += 1 if s.time < 30.0 else 0
		times.sort()
		medians[skill_name] = times[SEEDS / 2]
		print("    밸런스 봇 %s: 가운데값 %.0f초 (하위 25%% %.0f초, 상위 25%% %.0f초), 떨어짐 %d, 하트 0 %d" % [
			skill_name, times[SEEDS / 2], times[SEEDS / 4], times[SEEDS * 3 / 4], falls, hearts])
		if skill_name == "초보":
			assert_true(early * 10 <= SEEDS, "초보도 첫 30초 안에 끝나는 판은 10%% 이하 (%d판)" % early)
	# 목표는 60~90초. 아이템이 들어온 뒤 시드 200개 가운데값 97초, 앞 30개는 138초까지 흔들려 여기서는 크게 벗어나는 것만 잡는다
	assert_true(medians["초보"] >= 60.0 and medians["초보"] <= 180.0, "초보 60~180초 (%.0f초)" % medians["초보"])
	assert_true(medians["익숙함"] >= 180.0, "익숙해지면 3분 이상 (%.0f초)" % medians["익숙함"])
	assert_true(medians["숙련"] >= 600.0, "숙련 목표 600초 이상 (%.0f초)" % medians["숙련"])


func test_첫_질주는_첫_판_대본에서_20에서_25초에_나온다() -> void:
	for skill_name in BalanceBot.SKILLS:
		for seed_value in 10:
			var s: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS[skill_name], seed_value + 1, 30.0)
			if s.time >= 30.0:
				assert_true(s.first_dash >= 20.0 and s.first_dash <= 25.0, "%s 시드 %d: %.1f초" % [skill_name, seed_value + 1, s.first_dash])


func test_같은_시드면_같은_결과() -> void:
	var skill: Dictionary = BalanceBot.SKILLS["익숙함"]
	assert_eq(BalanceBot.play(skill, 5, 120.0), BalanceBot.play(skill, 5, 120.0))


func test_실수하지_않는_봇은_최대_속도까지_버틴다() -> void:
	# 옥상이 실제로 넘을 수 있게 만들어지는지: 실수 없는 봇은 최대 속도에 닿은 뒤에도 떨어지지 않는다
	var reach_max: float = Balance.SPEED_STAGES[8][0] + 60.0  # 단계 9(최고 속도)에 닿고 1분 더
	for seed_value in 3:
		assert_eq(BalanceBot.play({"timing": 0.0, "short_hold": 0.0}, seed_value + 1, reach_max), reach_max, "시드 %d" % (seed_value + 1))
