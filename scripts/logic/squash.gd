class_name Squash
## 점프할 때 몸이 늘어나고, 착지할 때 살짝 납작해지는 배율 (가로, 세로) 계산.


## on_ground: 옥상 위인지, vy: 세로 속도(위로 +), time_since_land: 착지 뒤 지난 시간
static func body_scale(on_ground: bool, vy: float, time_since_land: float) -> Vector2:
	if on_ground:
		if time_since_land >= Balance.SQUASH_TIME:
			return Vector2.ONE
		# 착지 순간 가장 납작하고, 부드럽게(ease-out) 원래 모양으로 돌아온다
		var t := time_since_land / Balance.SQUASH_TIME
		return Balance.SQUASH_LAND.lerp(Vector2.ONE, 1.0 - pow(1.0 - t, 2.0))
	var amount := clampf(absf(vy) / JumpModel.jump_speed(), 0.0, 1.0)
	var target := Balance.STRETCH_RISE if vy > 0.0 else Balance.STRETCH_FALL
	return Vector2.ONE.lerp(target, amount)
