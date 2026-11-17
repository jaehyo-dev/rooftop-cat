extends SceneTree
## 액션 시험판 밸런스 표 (보고용 도구, 자동 테스트 아님): 같은 시드·실력에서 "피하기 봇" / "밟기 봇"의 판 길이·점수·밟은 수.
## 실행: godot --headless --path . -s res://review/cat-parade/action/action_report.gd [-- --seeds=20]
## 아기 무리는 둘 다 켬. 차이는 봇이 화분·실외기를 넘느냐 밟느냐에서만 온다.

const BalanceBot := preload("res://tests/balance_bot.gd")
const MAX_TIME := 600.0


func _initialize() -> void:
	var seeds := 20
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = int(arg.get_slice("=", 1))
	print("시드 1~%d, 한 판 최대 %d초, 봇 = tests/balance_bot.gd\n" % [seeds, MAX_TIME])
	print("| 실력 | 봇 | 판 길이 평균(초) | 가운데값(초) | 점수 평균 | 밟기 점수 평균 | 판당 밟은 수 | 판당 하트 잃음 | 하트 0으로 끝 |")
	print("|---|---|---|---|---|---|---|---|---|")
	for skill_name in BalanceBot.SKILLS:
		var base := {}
		for mode in ["피하기", "밟기"]:
			var times: Array[float] = []
			var score := 0.0
			var stomp_pts := 0.0
			var stomps := 0
			var hits := 0
			var hearts := 0
			for s in seeds:
				var st: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS[skill_name], s + 1, MAX_TIME, Balance.RUN_SPEED, true, [], [], null, true, mode == "밟기")
				times.append(st.time)
				score += st.score
				stomp_pts += st.stomp_points
				stomps += st.stomps
				for k in st.hits:
					hits += st.hits[k]
				hearts += 1 if st.end == "hearts" else 0
			times.sort()
			var mean: float = times.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / seeds
			if base.is_empty():
				base = {"time": mean, "score": score / seeds}
			var change := "" if mode == "피하기" else " (%+.0f%%)" % ((mean / base.time - 1.0) * 100.0)
			var score_change := "" if mode == "피하기" else " (%+.0f%%)" % ((score / seeds / base.score - 1.0) * 100.0)
			print("| %s | %s | %.0f%s | %.0f | %.0f%s | %.0f | %.1f | %.1f | %d/%d |" % [skill_name, mode, mean, change, times[seeds / 2],
					score / seeds, score_change, stomp_pts / seeds, float(stomps) / seeds, float(hits) / seeds, hearts, seeds])
	quit()
