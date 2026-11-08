extends SceneTree
## 밸런스 비교표 출력 (자동 테스트가 아니라 보고용 도구).
## 실행: godot --headless --path . -s res://tests/balance_report.gd
## 시드 1~30, 실력별로 한 판(최대 900초)을 돌려 한 판 길이 가운데값, 끝난 단계, 특수 틈 성공률을 찍는다.

const BalanceBot := preload("res://tests/balance_bot.gd")
const SEEDS := 30
const MAX_TIME := 900.0


func _initialize() -> void:
	print("| 실력 | 가운데값(초) | 하위25% | 상위25% | 끝난 단계 | 첫 30초 안에 끝 | 떨어짐/하트 0 | 하트 잃은 곳 | 트램펄린 틈 성공 | 판 틈 성공 | 떨어진 곳 |")
	print("|---|---|---|---|---|---|---|---|---|---|---|")
	var rates := ""
	for skill_name in BalanceBot.SKILLS:
		var times: Array[float] = []
		var total := {}
		var deaths := {}
		var hits := {}
		var tries := {}
		var oks := {}
		var ends := {"fall": 0, "hearts": 0}
		var early := 0
		for seed_value in SEEDS:
			var s: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS[skill_name], seed_value + 1, MAX_TIME)
			times.append(s.time)
			early += 1 if s.time < 30.0 else 0
			for key in s:
				if s[key] is int:
					total[key] = total.get(key, 0) + s[key]
			if s.has("death") and s.end == "fall":
				deaths[s.death] = deaths.get(s.death, 0) + 1
			if s.end != "":
				ends[s.end] += 1
			for kind in s.hits:
				hits[kind] = hits.get(kind, 0) + s.hits[kind]
			for stage in s.segment_try:
				tries[stage] = tries.get(stage, 0) + s.segment_try[stage]
				oks[stage] = oks.get(stage, 0) + s.segment_ok.get(stage, 0)
		times.sort()
		print("| %s | %.0f | %.0f | %.0f | %d | %d/%d | %d/%d | %s | %s | %s | %s |" % [skill_name, times[SEEDS / 2], times[SEEDS / 4], times[SEEDS * 3 / 4],
				SpeedCurve.stage_at(times[SEEDS / 2]), early, SEEDS, ends.fall, ends.hearts, _shares(hits),
				_rate(total.tramp_ok, total.tramp_try), _rate(total.pole_ok, total.pole_try), str(deaths)])
		rates += "\n%s 단계별 구간 옥상 통과율: " % skill_name
		var stages: Array = tries.keys()
		stages.sort()
		for stage in stages:
			rates += "%d단계 %.0f%%(%d)  " % [stage, 100.0 * oks[stage] / tries[stage], tries[stage]]
	print(rates)
	quit(0)


func _shares(hits: Dictionary) -> String:
	var sum := 0
	for kind in hits:
		sum += hits[kind]
	var parts: Array[String] = []
	for kind in hits:
		parts.append("%s %.0f%%" % [kind, 100.0 * hits[kind] / sum])
	return "%d회 (%s)" % [sum, ", ".join(parts)]


func _rate(ok: int, tries: int) -> String:
	return "-" if tries == 0 else "%.0f%% (%d/%d)" % [100.0 * ok / tries, ok, tries]
