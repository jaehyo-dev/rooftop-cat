class_name FishCombo
extends RefCounted
## 생선 점수와 콤보 (화면과 분리된 로직, PLAN 16번).
## 끊기지 않고 먹을수록 배수가 오른다 (COMBO_STEP개마다 +1, 최대 COMBO_MAX). 부딪힘·놓침·COMBO_TIMEOUT초 동안 못 먹음이면 끊긴다 (RunnerSim이 부름).

var count := 0   # 지금 콤보
var best := 0    # 이번 판 최고 콤보
var points := 0  # 생선 점수 합
var _idle := 0.0


## 지금 배수 (x1부터)
func multiplier() -> int:
	return mini(1 + count / Balance.COMBO_STEP, Balance.COMBO_MAX)


## 하나 먹음: 콤보가 먼저 오르고 그 배수로 점수를 더한다
func eat(base_points: int) -> void:
	count += 1
	best = maxi(best, count)
	points += base_points * multiplier()
	_idle = 0.0


func cut() -> void:
	count = 0
	_idle = 0.0


## 시간이 지남: 못 먹은 채 COMBO_TIMEOUT초가 지나면 끊긴다
func tick(dt: float) -> void:
	_idle += dt
	if _idle >= Balance.COMBO_TIMEOUT:
		cut()
