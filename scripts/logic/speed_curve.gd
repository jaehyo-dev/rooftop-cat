class_name SpeedCurve
## 시간이 갈수록 빨라지는 달리기 속도 (화면과 분리된 순수 계산).


## 달리기 시작하고 elapsed초 뒤의 속도. 일정하게 빨라지다가 SPEED_MAX에서 멈춘다
static func speed_at(elapsed: float, start_speed: float = Balance.RUN_SPEED) -> float:
	return minf(Balance.SPEED_MAX, start_speed + Balance.SPEED_GAIN * maxf(elapsed, 0.0))
