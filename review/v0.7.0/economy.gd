extends SceneTree
## v0.7.0 설계용 측정 (자동 테스트 아님): 실력별 한 판 생선 수입과 미션 후보 행동 횟수.
## 실행: godot --headless --path . -s res://review/v0.7.0/economy.gd [-- --seeds=30]

const BalanceBot := preload("res://tests/balance_bot.gd")
const MAX_TIME := 900.0
const KEYS := ["time", "fish", "dash_fish", "score", "meters", "combo_best", "doubles", "perfects", "dash_smashed", "dash_count", "gold", "cookie", "hits"]


func _initialize() -> void:
	var seeds := 30
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = int(arg.get_slice("=", 1))
	print("| 실력 | 값 | " + " | ".join(KEYS) + " |")
	print("|---|---|" + "---|".repeat(KEYS.size()))
	for skill_name in BalanceBot.SKILLS:
		var lists := {}
		for key in KEYS:
			lists[key] = []
		for seed_value in seeds:
			var s: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS[skill_name], seed_value + 1, MAX_TIME)
			s.gold = s.eaten.get("gold", 0)
			s.cookie = s.eaten.get("cookie", 0)
			var hit_sum := 0
			for kind in s.hits:
				hit_sum += s.hits[kind]
			s.hits = hit_sum
			for key in KEYS:
				lists[key].append(float(s.get(key, 0)))
		for label in ["평균", "가운데", "하위25%", "상위25%"]:
			var row: Array[String] = []
			for key in KEYS:
				var list: Array = lists[key]
				list.sort()
				var v := 0.0
				match label:
					"평균":
						for x in list:
							v += x
						v /= list.size()
					"가운데":
						v = list[list.size() / 2]
					"하위25%":
						v = list[list.size() / 4]
					"상위25%":
						v = list[list.size() * 3 / 4]
				row.append("%.0f" % v)
			print("| %s | %s | %s |" % [skill_name, label, " | ".join(row)])
	quit(0)
