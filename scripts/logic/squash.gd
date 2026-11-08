class_name Squash
## 공중에서 몸이 세로 속도에 따라 늘어나는 배율 (가로, 세로) 계산.
## 착지·이륙의 순간 눌림·늘어남은 Spring에 충격(kick)으로 넣는다 (cat_view.gd).


## vy: 세로 속도(위로 +). 빠를수록 STRETCH_RISE / STRETCH_FALL 쪽으로
static func body_scale(vy: float) -> Vector2:
	var amount := clampf(absf(vy) / JumpModel.jump_speed(), 0.0, 1.0)
	var target := Balance.STRETCH_RISE if vy > 0.0 else Balance.STRETCH_FALL
	return Vector2.ONE.lerp(target, amount)
