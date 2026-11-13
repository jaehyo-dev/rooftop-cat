extends SceneTree
## 줄줄이 시험판 밸런스 표 (보고용 도구, 자동 테스트 아님): 끔 / A / B 각각 실력별 판 길이·평균 줄 길이·끝날 때 남은 고양이.
## 실행: godot --headless --path . -s res://review/cat-parade/parade_report.gd [-- --seeds=20]
## 같은 시드·같은 봇이라 세 방식의 차이는 줄 규칙에서만 온다.

const BalanceBot := preload("res://tests/balance_bot.gd")
const MAX_TIME := 600.0


func _initialize() -> void:
	var seeds := 20
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = int(arg.get_slice("=", 1))
	print("시드 1~%d, 한 판 최대 %d초, 봇 = tests/balance_bot.gd\n" % [seeds, MAX_TIME])
	print("| 실력 | 방식 | 판 길이 평균(초) | 가운데값(초) | 평균 줄 길이(마리) | 끝날 때 남은 고양이 | 만난 수 | 도망 수 | 하트 0으로 끝 |")
	print("|---|---|---|---|---|---|---|---|---|")
	for skill_name in BalanceBot.SKILLS:
		var base_mean := 0.0
		for mode in ["", "A", "B"]:
			var times: Array[float] = []
			var line := 0.0
			var left := 0
			var met := 0
			var scared := 0
			var hearts := 0
			for s in seeds:
				var st: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS[skill_name], s + 1, MAX_TIME, Balance.RUN_SPEED, true, [], [], null, mode)
				times.append(st.time)
				line += st.line_sum / maxf(st.time, 0.001)
				left += st.line_end
				met += st.met_at.size()
				scared += st.scared
				hearts += 1 if st.end == "hearts" else 0
			times.sort()
			var mean: float = times.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / seeds
			if mode == "":
				base_mean = mean
			var change := "" if mode == "" else " (끔 대비 %+.0f%%)" % ((mean / base_mean - 1.0) * 100.0)
			print("| %s | %s | %.0f%s | %.0f | %.2f | %.2f | %.1f | %.1f | %d/%d |" % [skill_name, "끔" if mode == "" else mode, mean, change,
					times[seeds / 2], line / seeds, float(left) / seeds, float(met) / seeds, float(scared) / seeds, hearts, seeds])
	quit()
