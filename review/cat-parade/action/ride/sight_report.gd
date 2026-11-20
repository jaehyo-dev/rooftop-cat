extends SceneTree
## 구름 타기 주인공 옮기기의 앞 시야 영향 (보고용 도구, 자동 테스트 아님): 같은 시드·실력에서 봇의 생존 거리(m) 비교.
## 실행: godot --headless --path . -s res://review/cat-parade/action/ride/sight_report.gd [-- --seeds=20]
## 시야 모델은 tests/balance_bot.gd REACT: 넘을 것이 화면 오른쪽 끝(주인공 앞 sight px)에 들어온 뒤 0.3초 지나야 누름.
## PC 1280 폭 기준 앞 시야 940에서 그때 아기 수만큼 옮긴 폭을 뺌 (옮김 최대 0 = 예전, 20·40·60). 휴대폰 가로는 화면이 더 넓어 덜 줄어듦.

const BalanceBot := preload("res://tests/balance_bot.gd")
const MAX_TIME := 600.0


func _initialize() -> void:
	var seeds := 20
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = int(arg.get_slice("=", 1))
	print("시드 1~%d, 한 판 최대 %d초, 아기 무리 켬, 봇 = tests/balance_bot.gd (시야 모델 REACT %.2f초)\n" % [seeds, MAX_TIME, BalanceBot.REACT])
	print("| 실력 | 옮김 최대(px) | 생존 거리 평균(m) | 가운데값(m) | 판 길이 평균(초) | 안 옮김 대비 |")
	print("|---|---|---|---|---|---|")
	for skill_name in BalanceBot.SKILLS:
		var base := 0.0
		for shift in [0.0, 20.0, 40.0, 60.0]:
			var dist: Array[float] = []
			var time := 0.0
			for s in seeds:
				var st: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS[skill_name], s + 1, MAX_TIME, Balance.RUN_SPEED, true, [], [], null, true, false, 940.0, shift)
				dist.append(st.meters)
				time += st.time
			dist.sort()
			var mean: float = dist.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / seeds
			if shift == 0.0:
				base = mean
			var change := "" if shift == 0.0 else "%+.1f%%" % ((mean / base - 1.0) * 100.0)
			print("| %s | %d | %.0f | %.0f | %.0f | %s |" % [skill_name, shift, mean, dist[seeds / 2], time / seeds, change])
	quit()
