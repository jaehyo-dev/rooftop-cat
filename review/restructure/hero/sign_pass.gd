extends SceneTree
## 낮은 간판 통과율 (봇): 실력 3가지 x 시드 30판, 판마다 최대 120초. 통과 = 맞지 않고 다 지남
## 사용: godot --headless --path . -s res://review/restructure/hero/sign_pass.gd
const BalanceBot := preload("res://tests/balance_bot.gd")


func _init() -> void:
	print("SLIDE_BODY %.2f (판정 타원 위 끝 %.1f px, 간판 아래 끝 %.0f px)" % [Balance.SLIDE_BODY,
			Balance.CAT_BODY_SIZE.y * Balance.SLIDE_BODY * 0.5 * (1.0 + Balance.OBSTACLE_HIT_SCALE), Balance.OBSTACLES.sign.y0])
	for skill_name in BalanceBot.SKILLS:
		var ok := 0
		var hit := 0
		for seed_value in 30:
			var s: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS[skill_name], seed_value + 1, 120.0)
			ok += s.get("signs_ok", 0)
			hit += s.hits.get("sign", 0)
		print("%s: 간판 %d개 중 통과 %d (%.1f%%), 맞음 %d" % [skill_name, ok + hit, ok, 100.0 * ok / maxf(ok + hit, 1), hit])
	quit()
