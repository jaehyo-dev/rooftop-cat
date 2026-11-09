extends SceneTree
## 밸런스 비교표 출력 (자동 테스트가 아니라 보고용 도구).
## 실행: godot --headless --path . -s res://tests/balance_report.gd
## 시드 1~30, 실력별로 한 판(최대 900초)을 돌려 한 판 길이 가운데값, 끝난 단계, 특수 틈 성공률, 아이템 효과를 찍는다.

const BalanceBot := preload("res://tests/balance_bot.gd")
const SEEDS := 30
const MAX_TIME := 900.0


func _initialize() -> void:
	print("| 실력 | 가운데값(초) | 하위25% | 상위25% | 끝난 단계 | 첫 30초 안에 끝 | 떨어짐/하트 0 | 하트 잃은 곳 | 트램펄린 틈 성공 | 판 틈 성공 | 떨어진 곳 |")
	print("|---|---|---|---|---|---|---|---|---|---|---|")
	var rates := ""
	var items := "\n| 실력 | 질주 (판당) | 질주당 부순 수 | 질주 길이 평균/최대 | 끝난 뒤 3초 안 떨어짐 | 첫 질주 시각 (먹은 판) | 털실 중 생선 증가 | 쿠키 먹음 판당 (3개에서) | 방울 먹음/막음 | 통조림 먹음/바뀐 장애물 | 황금 |\n|---|---|---|---|---|---|---|---|---|---|---|\n"
	var freq := "\n| 실력 | 분당 놓임: 쿠키 | 질주 | 통조림 | 방울 | 털실 | 생선 줄 |\n|---|---|---|---|---|---|---|\n"
	for skill_name in BalanceBot.SKILLS:
		var times: Array[float] = []
		var total := {}
		var deaths := {}
		var hits := {}
		var tries := {}
		var oks := {}
		var eaten := {}
		var made := {}
		var dash_len: Array[float] = []
		var firsts: Array[float] = []
		var ends := {"fall": 0, "hearts": 0}
		var early := 0
		for seed_value in SEEDS:
			var s: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS[skill_name], seed_value + 1, MAX_TIME)
			times.append(s.time)
			early += 1 if s.time < 30.0 else 0
			for key in s:
				if s[key] is int or s[key] is float:
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
			for kind in s.eaten:
				eaten[kind] = eaten.get(kind, 0) + s.eaten[kind]
			for kind in s.made:
				made[kind] = made.get(kind, 0) + s.made[kind]
			dash_len.append_array(s.dash_seconds)
			if s.first_dash >= 0.0:
				firsts.append(s.first_dash)
		times.sort()
		firsts.sort()
		print("| %s | %.0f | %.0f | %.0f | %d | %d/%d | %d/%d | %s | %s | %s | %s |" % [skill_name, times[SEEDS / 2], times[SEEDS / 4], times[SEEDS * 3 / 4],
				SpeedCurve.stage_at(times[SEEDS / 2]), early, SEEDS, ends.fall, ends.hearts, _shares(hits),
				_rate(total.tramp_ok, total.tramp_try), _rate(total.pole_ok, total.pole_try), str(deaths)])
		rates += "\n%s 단계별 구간 옥상 통과율: " % skill_name
		var stages: Array = tries.keys()
		stages.sort()
		for stage in stages:
			rates += "%d단계 %.0f%%(%d)  " % [stage, 100.0 * oks[stage] / tries[stage], tries[stage]]
		var longest := 0.0
		var length_sum := 0.0
		for v in dash_len:
			longest = maxf(longest, v)
			length_sum += v
		var yarn_rate: float = total.yarn_fish / maxf(total.yarn_time, 0.01)
		var plain_rate: float = total.plain_fish / maxf(total.plain_time, 0.01)
		items += "| %s | %.1f | %.1f | %.1f / %.1f초 | %d/%d | %.1f~%.1f초 (%d/%d) | %+.0f%% (%.2f→%.2f개/초) | %.1f (%d) | %d/%d | %d/%d | %d |\n" % [skill_name, float(total.dash_count) / SEEDS,
				float(total.dash_smashed) / maxi(total.dash_count, 1), length_sum / maxi(dash_len.size(), 1), longest, total.dash_fall, total.dash_count,
				firsts[0] if not firsts.is_empty() else 0.0, firsts[-1] if not firsts.is_empty() else 0.0, firsts.size(), SEEDS, (yarn_rate / maxf(plain_rate, 0.001) - 1.0) * 100.0, plain_rate, yarn_rate,
				float(eaten.get("cookie", 0)) / SEEDS, total.cookie_full, eaten.get("bell", 0), total.blocks, eaten.get("can", 0), total.canned, eaten.get("gold", 0)]
		var minutes: float = total.time / 60.0
		freq += "| %s | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |\n" % [skill_name, made.get("cookie", 0) / minutes, made.get("dash", 0) / minutes, made.get("can", 0) / minutes,
				made.get("bell", 0) / minutes, made.get("yarn", 0) / minutes, made.get("fish", 0) / minutes]
	print(rates)
	print(items)
	print(freq)
	if OS.get_cmdline_user_args().has("--effects"):
		_effects()
	quit(0)


## 아이템 하나씩 끈 판과 비교: 가운데값 (초)
func _effects() -> void:
	print("| 끈 것 | 초보 | 익숙함 | 숙련 |\n|---|---|---|---|")
	for off: Array in [[], ["cookie"], ["bell"], ["dash"], ["can"], ["yarn"], ["cookie", "bell", "dash", "can", "yarn"]]:
		var row: Array[String] = []
		for skill_name in BalanceBot.SKILLS:
			var times: Array[float] = []
			for seed_value in SEEDS:
				times.append(BalanceBot.play_stats(BalanceBot.SKILLS[skill_name], seed_value + 1, MAX_TIME, Balance.RUN_SPEED, true, [], off).time)
			times.sort()
			row.append("%.0f" % times[SEEDS / 2])
		print("| %s | %s |" % [", ".join(off) if not off.is_empty() else "없음", " | ".join(row)])


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
