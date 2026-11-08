extends SceneTree
## 밸런스 비교표 출력 (자동 테스트가 아니라 보고용 도구).
## 실행: godot --headless --path . -s res://tests/balance_report.gd
## 시드 1~30, 실력별로 한 판(최대 900초)을 돌려 한 판 길이 가운데값과 특수 틈 성공률을 찍는다.

const BalanceBot := preload("res://tests/balance_bot.gd")
const SEEDS := 30
const MAX_TIME := 900.0


func _initialize() -> void:
	print("| 실력 | 가운데값(초) | 하위25% | 상위25% | 트램펄린 틈 성공 | 판 틈 성공 | 트램펄린 닿음 누름·퍼펙트/전체 | 떨어진 곳 |")
	print("|---|---|---|---|---|---|---|---|")
	for skill_name in BalanceBot.SKILLS:
		var times: Array[float] = []
		var total := {}
		var deaths := {}  # 떨어진 곳별 판 수 (tramp / line / pole / plain)
		for seed_value in SEEDS:
			var s: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS[skill_name], seed_value + 1, MAX_TIME)
			times.append(s.time)
			for key in s:
				if s[key] is int:
					total[key] = total.get(key, 0) + s[key]
			if s.has("death"):
				deaths[s.death] = deaths.get(s.death, 0) + 1
		times.sort()
		print("| %s | %.0f | %.0f | %.0f | %s | %s | %s | %s |" % [skill_name, times[SEEDS / 2], times[SEEDS / 4], times[SEEDS * 3 / 4],
				_rate(total.tramp_ok, total.tramp_try), _rate(total.pole_ok, total.pole_try),
				_rate(total.get("touch_ok", 0), total.get("touch_try", 0)), str(deaths)])
	quit(0)


func _rate(ok: int, tries: int) -> String:
	return "-" if tries == 0 else "%.0f%% (%d/%d)" % [100.0 * ok / tries, ok, tries]
