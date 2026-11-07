class_name CatPose
## 고양이 동작에 맞는 그림(프레임)과 그 위에 얹을 몸 전체의 늘어남·납작해짐·기울기 (화면과 분리된 순수 계산).
## 그림은 자세별 통그림이고(다리를 따로 움직이지 않음), 프레임 사이는 몸 전체의 배율·기울기로 부드럽게 잇는다.
## 배율은 발끝을 기준으로 적용하므로 발이 옥상에서 뜨지 않는다. 기울기는 도 단위, 양수 = 시계 방향(코가 아래로).

## 달리기 한 바퀴의 프레임 (모으기 → 박차기 → 앞발 디딤 → 뒷발 들어옴)
const RUN_FRAMES := ["run_0", "run_1", "run_2", "run_3"]
## 프레임마다 몸 전체 배율 (가로, 세로): 모을 때 짧고 높게, 박찰 때 길고 낮게
const RUN_SCALE := [Vector2(0.97, 1.03), Vector2(1.04, 0.97), Vector2(1.02, 0.99), Vector2(0.98, 1.02)]
const ALL_FRAMES := ["run_0", "run_1", "run_2", "run_3", "crouch", "takeoff", "rise", "fall", "land", "flail"]


## sim의 상태로 자세를 정한다. 돌려주는 값: frame(그림 이름), scale(몸 전체 배율), tilt(기울기)
static func pose(sim: RunnerSim) -> Dictionary:
	if sim.is_doomed():
		# 떨어져서 끝나는 중: 코가 아래로 기울고, 몸 전체를 빠르게 흔들어 허우적거린다 (1초에 약 5번)
		var wobble := sin(sim.elapsed * TAU * 5.0)
		return {"frame": "flail", "scale": Vector2(1.0 + 0.04 * wobble, 1.0 - 0.04 * wobble), "tilt": 12.0 + 10.0 * wobble}
	if sim.on_ground:
		if sim.time_since_land < Balance.CAT_LAND_TIME:
			# 착지: 앞발부터 닿고 몸이 푹 눌렸다가 돌아온다 (납작함은 Squash와 같은 곡선)
			var k := sim.time_since_land / Balance.CAT_LAND_TIME
			return {"frame": "land", "scale": Squash.body_scale(true, 0.0, sim.time_since_land), "tilt": lerpf(6.0, 0.0, k)}
		# 달리기: 달린 거리로 프레임을 정해 빨라지면 다리도 그만큼 빨리 움직인다 (발이 미끄러져 보이지 않음)
		var step := posmod(int(floor(sim.x / Balance.CAT_STRIDE * RUN_FRAMES.size())), RUN_FRAMES.size())
		return {"frame": RUN_FRAMES[step], "scale": RUN_SCALE[step], "tilt": 0.0}
	if sim.time_since_jump < Balance.CAT_CROUCH_TIME:
		# 뛰는 순간: 짧게 웅크려 힘을 모은 모습
		return {"frame": "crouch", "scale": Vector2(1.06, 0.9), "tilt": 0.0}
	var jump_speed := JumpModel.jump_speed()
	if sim.is_holding():
		# 누르고 있는 동안 박차고 오름: 길게 누를수록 몸이 앞뒤로 더 늘어난다
		var h := sim.hold_ratio()
		return {"frame": "takeoff", "scale": Vector2(1.0 + 0.1 * h, 1.0 - 0.05 * h), "tilt": -10.0}
	if sim.vy > 0.0:
		var up := clampf(sim.vy / jump_speed, 0.0, 1.0)
		return {"frame": "rise", "scale": Squash.body_scale(false, sim.vy, 99.0), "tilt": -8.0 * up}
	var down := clampf(-sim.vy / jump_speed, 0.0, 1.0)
	return {"frame": "fall", "scale": Squash.body_scale(false, sim.vy, 99.0), "tilt": 8.0 * down}
