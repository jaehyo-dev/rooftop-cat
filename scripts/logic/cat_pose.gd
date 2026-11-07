class_name CatPose
## 고양이 동작(달리기·점프·착지)에 맞는 부품 각도 (화면과 분리된 순수 계산).
## 각도는 도 단위, 양수 = 화면에서 시계 방향. 다리는 아래를 향해 있으므로 음수면 발이 앞(오른쪽)으로 간다.
## 달리기 박자는 달린 거리(x)로 정한다: 빨라지면 다리도 그만큼 빨리 움직여 발이 미끄러져 보이지 않는다.

const LEGS := ["front", "front_back", "back", "back_back"]


## on_ground: 옥상 위인지, vy: 세로 속도(위로 +), x: 달린 거리, since_land: 착지 뒤 지난 시간
## 돌려주는 값: 다리 4개·머리·꼬리 각도, body_bob(몸이 위로 뜨는 높이, 게임 픽셀)
static func target(on_ground: bool, vy: float, x: float, since_land: float) -> Dictionary:
	var pose := {"head": 0.0, "tail": 0.0, "body_bob": 0.0}
	if on_ground:
		var phase := x / Balance.CAT_STRIDE * TAU
		var swing := Balance.CAT_LEG_SWING
		# 앞다리 두 개는 서로 반대로, 뒷다리는 앞다리와 반 박자 엇갈려 움직인다
		pose.front = -sin(phase) * swing
		pose.front_back = sin(phase) * swing
		pose.back = sin(phase) * swing
		pose.back_back = -sin(phase) * swing
		pose.body_bob = absf(sin(phase)) * Balance.CAT_RUN_BOB
		pose.head = sin(phase * 2.0) * 3.0
		pose.tail = sin(phase) * 8.0
		if since_land < Balance.SQUASH_TIME:
			# 착지 순간: 다리를 앞뒤로 살짝 벌려 버틴다
			var k := 1.0 - since_land / Balance.SQUASH_TIME
			for leg in LEGS:
				pose[leg] = lerpf(pose[leg], -18.0 if leg.begins_with("front") else 18.0, k)
		return pose
	# 공중: 올라갈 때는 앞다리를 앞으로 뻗고 뒷다리를 뒤로, 내려올 때는 착지하려고 다리를 아래로 모은다
	var rising := clampf(vy / JumpModel.jump_speed(), -1.0, 1.0)
	if rising > 0.0:
		pose.front = -45.0 * rising
		pose.front_back = -35.0 * rising
		pose.back = 40.0 * rising
		pose.back_back = 30.0 * rising
		pose.head = -6.0 * rising
		pose.tail = -10.0 * rising
	else:
		var falling := -rising
		pose.front = -15.0 * falling
		pose.front_back = -10.0 * falling
		pose.back = -8.0 * falling
		pose.back_back = -4.0 * falling
		pose.head = 4.0 * falling
		pose.tail = 12.0 * falling
	return pose
