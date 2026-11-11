extends SceneTree
## v0.7.0 2a 측정 (자동 테스트 아님): 실제 Perks로 봇을 돌려 강화 효과와 날짜별 경제를 잰다.
## 실행: nice -n 10 godot --headless --path . -s res://review/v0.7.0/2a/economy.gd > review/v0.7.0/2a/economy_raw.md
## 1) 실력별 0단계 / 전부 10단계 / 콤보만 10단계 / 10단계에서 콤보만 0단계 (시드 30, 최대 900초)
## 2) 날짜별: 하루 5판, 판이 끝날 때마다 가장 싼 다음 강화를 산다. 판은 그때 강화 단계로 봇이 실제로 플레이
##    미션 수입·부스터 지출은 review/v0.7.0/economy_calc.py와 같은 어림 (PLAN 5번 보상 기준)

const BalanceBot := preload("res://tests/balance_bot.gd")
const SEEDS := 30
const MAX_TIME := 900.0
const RUNS_PER_DAY := 5
const MAX_DAYS := 60
## 하루 미션 수입 (일일 3개 + 주간 3개/7 + 등급 보너스, 초보는 일일 2·주간 2만 깸)
const MISSION_DAY := {"초보": 1000 + 6000 / 7 + 300, "익숙함": 1500 + 9000 / 7 + 400, "숙련": 1500 + 9000 / 7 + 400}
const BOOSTER_DAY := 900


func _initialize() -> void:
	_effects()
	_economy()
	quit(0)


static func _pct(list: Array, q: float) -> float:
	var sorted := list.duplicate()
	sorted.sort()
	return sorted[mini(int(sorted.size() * q), sorted.size() - 1)]


static func _mean(list: Array) -> float:
	var total := 0.0
	for v in list:
		total += v
	return total / maxf(1.0, list.size())


func _effects() -> void:
	var configs := {
		"0단계": Perks.all(0),
		"전부 10단계": Perks.all(Balance.UPGRADE_MAX),
		"콤보 가속만 10단계": Perks.new({"combo": Balance.UPGRADE_MAX}),
		"10단계, 콤보만 0단계": Perks.new({"dash": 10, "yarn": 10, "gold": 10, "cookie": 10, "fish": 10}),
	}
	print("## 1. 강화 효과 (시드 %d, 최대 %d초)\n" % [SEEDS, MAX_TIME])
	print("| 실력 | 강화 | 판 길이 평균 / 가운데 / 하위25% | 생선 평균 / 가운데 | 점수 평균 / 가운데 | 최고 콤보 가운데 | 질주 뒤 3초 안 떨어짐 (질주 수) | 끝: 떨어짐 / 하트 0 |")
	print("|---|---|---|---|---|---|---|---|")
	for skill: String in BalanceBot.SKILLS:
		for label: String in configs:
			var times := []
			var fish := []
			var scores := []
			var combos := []
			var falls := 0
			var dashes := 0
			var ends := {"fall": 0, "hearts": 0}
			for seed_value in SEEDS:
				var s: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS[skill], seed_value + 1, MAX_TIME, Balance.RUN_SPEED, true, [], [], configs[label])
				times.append(s.time)
				fish.append(float(s.fish))
				scores.append(float(s.score))
				combos.append(float(s.combo_best))
				falls += s.dash_fall
				dashes += s.dash_count
				if ends.has(s.end):
					ends[s.end] += 1
			print("| %s | %s | %.0f / %.0f / %.0f초 | %.0f / %.0f | %.0f / %.0f | %.0f | %d (%d) | %d / %d |" % [skill, label,
					_mean(times), _pct(times, 0.5), _pct(times, 0.25), _mean(fish), _pct(fish, 0.5), _mean(scores), _pct(scores, 0.5),
					_pct(combos, 0.5), falls, dashes, ends.fall, ends.hearts])


## 날짜별 경제: 플레이어 모습마다 강화를 다 살 때까지 (최대 MAX_DAYS일)
func _economy() -> void:
	var players := {
		"보통 (2일 초보 → 익숙함)": func(day: int) -> String: return "초보" if day <= 2 else "익숙함",
		"초보 그대로": func(_day: int) -> String: return "초보",
	}
	var summary: Array[String] = []
	for name: String in players:
		for human: float in [1.0, 0.7]:
			summary.append(_play_days(name, players[name], human))
	print("\n## 3. 요약\n")
	print("| 플레이어 | 판 수입 | 다 산 날 | 하루 수입 평균 (판 / 미션) | 미션 비율 |")
	print("|---|---|---|---|---|")
	for row in summary:
		print(row)


func _play_days(name: String, skill_of: Callable, human: float) -> String:
	var levels := {}
	for kind: String in Balance.UPGRADES:
		levels[kind] = 0
	var wallet := 0.0
	var run_income := 0.0
	var mission_income := 0.0
	var run_no := 0
	var done_day := -1
	var detail := human == 1.0
	if detail:
		print("\n## 2. 날짜별: %s (판 수입 = 봇 그대로)\n" % name)
		print("| 날 | 실력 | 그날 판 생선 (5판) | 미션 | 산 단계 (누적) | 남은 생선 |")
		print("|---|---|---|---|---|---|")
	var day := 0
	while day < MAX_DAYS and done_day < 0:
		day += 1
		var skill: String = skill_of.call(day)
		var today := 0.0
		var bought := 0
		for i in RUNS_PER_DAY:
			run_no += 1
			var s: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS[skill], 1000 + run_no, MAX_TIME, Balance.RUN_SPEED, true, [], [], Perks.new(levels))
			var earned: float = s.fish * human
			wallet += earned
			today += earned
			bought += _buy_cheapest(levels, wallet)
			wallet -= _spent
		var mission: float = MISSION_DAY[skill]
		wallet += mission - BOOSTER_DAY
		bought += _buy_cheapest(levels, wallet)
		wallet -= _spent
		run_income += today
		mission_income += mission
		var total := 0
		for kind: String in levels:
			total += levels[kind]
		if detail:
			print("| %d | %s | %.0f | %.0f | +%d (%d/60) | %.0f |" % [day, skill, today, mission, bought, total, wallet])
		if total == Balance.UPGRADE_MAX * Balance.UPGRADES.size():
			done_day = day
	return "| %s | 봇의 %d%% | %s | %.0f (%.0f / %.0f) | %.0f%% |" % [name, roundi(human * 100), ("%d일" % done_day) if done_day > 0 else "%d일+" % MAX_DAYS,
			(run_income + mission_income) / day, run_income / day, mission_income / day, 100.0 * mission_income / (run_income + mission_income)]


var _spent := 0.0


## 살 수 있는 만큼 가장 싼 다음 단계부터 산다. 산 단계 수를 돌려주고 쓴 돈은 _spent에
func _buy_cheapest(levels: Dictionary, wallet: float) -> int:
	_spent = 0.0
	var count := 0
	while true:
		var best := ""
		for kind: String in levels:
			if levels[kind] < Balance.UPGRADE_MAX and (best.is_empty() or Balance.UPGRADE_PRICES[levels[kind]] < Balance.UPGRADE_PRICES[levels[best]]):
				best = kind
		if best.is_empty() or Balance.UPGRADE_PRICES[levels[best]] > wallet - _spent:
			return count
		_spent += Balance.UPGRADE_PRICES[levels[best]]
		levels[best] += 1
		count += 1
	return count
