class_name SpeedCurve
## 속도 단계 표(Balance.SPEED_STAGES)를 읽는 순수 계산: 지금 단계, 속도, 다음 단계 속도, 단계 신호 값.


## elapsed초 때의 단계 (1부터)
static func stage_at(elapsed: float) -> int:
	var stage := 1
	for i in Balance.SPEED_STAGES.size():
		if elapsed >= Balance.SPEED_STAGES[i][0]:
			stage = i + 1
	return stage


## 달리기 시작하고 elapsed초 뒤의 속도. 단계가 오르면 SPEED_RAMP_TIME초에 걸쳐 부드럽게 빨라진다
static func speed_at(elapsed: float) -> float:
	var i := stage_at(elapsed) - 1
	var now: float = Balance.SPEED_STAGES[i][1]
	if i == 0:
		return now
	return lerpf(Balance.SPEED_STAGES[i - 1][1], now, smoothstep(0.0, Balance.SPEED_RAMP_TIME, elapsed - Balance.SPEED_STAGES[i][0]))


## speed보다 빠른 첫 단계의 속도 (더 빠른 단계가 없으면 SPEED_MAX)
static func next_speed(speed: float) -> float:
	for stage in Balance.SPEED_STAGES:
		if stage[1] > speed:
			return stage[1]
	return Balance.SPEED_MAX


## 이 단계로 오를 때 실제로 빨라지는지 (단계 11·12는 밀도만 올라서 "빨라진다!" 신호를 내지 않는다)
static func rises(stage: int) -> bool:
	return stage > 1 and Balance.SPEED_STAGES[stage - 1][1] > Balance.SPEED_STAGES[stage - 2][1]


## 이 단계의 배경 음악 pitch_scale
static func music_pitch(stage: int) -> float:
	return minf(Balance.MUSIC_PITCH_MAX, 1.0 + Balance.MUSIC_PITCH_STEP * (stage - 1))


## 속도선 진하기 0~1. since_rise = 단계가 오른 뒤 지난 시간
static func line_strength(stage: int, since_rise: float) -> float:
	var rest := 0.0
	if stage >= Balance.SPEED_LINE_STAGE:
		rest = lerpf(Balance.SPEED_LINE_REST_MIN, Balance.SPEED_LINE_REST_MAX, clampf(inverse_lerp(float(Balance.SPEED_LINE_STAGE), 10.0, float(stage)), 0.0, 1.0))
	if since_rise >= Balance.SPEED_RAMP_TIME:
		return rest
	return lerpf(1.0, rest, smoothstep(Balance.SPEED_RAMP_TIME - Balance.SPEED_LINE_FADE, Balance.SPEED_RAMP_TIME, since_rise))
