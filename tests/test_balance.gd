extends TestCase
## 밸런스 봇으로 실력별 한 판 길이를 잰다 (목표는 review/v0.6.0/PLAN.md 8번, 장애물이 들어오는 2a-2에서 다시 맞춘다).
## 봇과 실력 수치는 tests/balance_bot.gd. 시드를 고정해 결과가 항상 같다.

const BalanceBot := preload("res://tests/balance_bot.gd")
const SEEDS := 30
const MAX_TIME := 900.0  # 15분 버티면 그만 잰다


func test_실력별_한_판_길이() -> void:
	var medians := {}
	for skill_name in BalanceBot.SKILLS:
		var times: Array[float] = []
		for seed_value in SEEDS:
			times.append(BalanceBot.play(BalanceBot.SKILLS[skill_name], seed_value + 1, MAX_TIME))
		times.sort()
		medians[skill_name] = times[SEEDS / 2]
		print("    밸런스 봇 %s: 가운데값 %.0f초 (하위 25%% %.0f초, 상위 25%% %.0f초)" % [
			skill_name, times[SEEDS / 2], times[SEEDS / 4], times[SEEDS * 3 / 4]])
	assert_true(medians["초보"] >= 40.0 and medians["초보"] <= 150.0, "초보는 1분 안팎 (%.0f초)" % medians["초보"])
	assert_true(medians["익숙함"] >= 180.0, "익숙해지면 3분 이상 (%.0f초)" % medians["익숙함"])
	assert_true(medians["숙련"] >= medians["익숙함"], "잘할수록 오래 버팀")


func test_같은_시드면_같은_결과() -> void:
	var skill: Dictionary = BalanceBot.SKILLS["익숙함"]
	assert_eq(BalanceBot.play(skill, 5, 120.0), BalanceBot.play(skill, 5, 120.0))


func test_실수하지_않는_봇은_최대_속도까지_버틴다() -> void:
	# 옥상이 실제로 넘을 수 있게 만들어지는지: 실수 없는 봇은 최대 속도에 닿은 뒤에도 떨어지지 않는다
	var reach_max: float = Balance.SPEED_STAGES[9][0] + 60.0  # 단계 10(최고 속도)에 닿고 1분 더
	for seed_value in 3:
		assert_eq(BalanceBot.play({"timing": 0.0, "short_hold": 0.0}, seed_value + 1, reach_max), reach_max, "시드 %d" % (seed_value + 1))
