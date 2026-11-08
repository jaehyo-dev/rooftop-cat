class_name CatPose
## 고양이 동작에 맞는 그림(프레임)과 그 위에 얹을 몸 전체의 목표 배율·기울기·들썩임 (화면과 분리된 순수 계산).
## 그림은 자세별 통그림이고(다리를 따로 움직이지 않음), 프레임 사이는 몸 배율 스프링(Spring, cat_view.gd)으로 출렁이며 잇는다.
## 앞구르기 공중제비(spin)는 기울기 금지의 예외: 몸을 말아 가는 그림 4장을 바꾸며 몸 가운데 기준으로 한 바퀴 돈다.
## 배율은 발끝을 기준으로 적용하므로 발이 옥상에서 뜨지 않는다. 기울기는 도 단위, 양수 = 시계 방향(코가 아래로).

## 달리기 한 바퀴의 프레임 (모으기 → 박차기 → 앞발 디딤 → 뒷발 들어옴)
const RUN_FRAMES := ["run_0", "run_1", "run_2", "run_3"]
## 프레임마다 몸 전체 배율 (가로, 세로): 모을 때 짧고 높게, 박찰 때 길고 낮게
const RUN_SCALE := [Vector2(0.97, 1.03), Vector2(1.04, 0.97), Vector2(1.02, 0.99), Vector2(0.98, 1.02)]
## 앞구르기 프레임 (숙이기, C자, 공, 펴기)과 각 그림으로 바뀌는 회전 각도 (도)
const FLIP_FRAMES := ["flip_tuck", "flip_curl", "flip_ball", "flip_open"]
const FLIP_FROM_DEG := [0.0, 25.0, 60.0, 300.0]
const ALL_FRAMES := ["run_0", "run_1", "run_2", "run_3", "crouch", "takeoff", "rise", "fall", "land", "flail",
		"flip_tuck", "flip_curl", "flip_ball", "flip_open"]
const NO_FLIP := 99.0


## sim의 상태로 자세를 정한다. 돌려주는 값: frame(그림 이름), scale(몸 전체 목표 배율), tilt(기울기),
## spin(공중제비 회전, 라디안), bob(그림만 위로 들썩이는 게임 픽셀)
static func pose(sim: RunnerSim) -> Dictionary:
	var result := _pose(sim)
	result.spin = 0.0
	result.merge({"bob": 0.0})
	var t := flip_time(sim)
	if t < Balance.CAT_FLIP_TIME:
		result.spin = flip_angle(t / Balance.CAT_FLIP_TIME)
		var i := FLIP_FROM_DEG.size() - 1
		while rad_to_deg(result.spin) < FLIP_FROM_DEG[i]:
			i -= 1
		result.frame = FLIP_FRAMES[i]
		result.scale = Vector2.ONE
		result.tilt = 0.0
	return result


## 앞구르기 회전 각도 (라디안, k = 0~1): 말기는 천천히, 공에서 가장 빠르게, 펴기는 다시 천천히 (속도가 끊기지 않는 곡선)
static func flip_angle(k: float) -> float:
	return TAU * (k - Balance.CAT_FLIP_EASE * sin(TAU * k) / TAU)


## 이번 공중에서 앞구르기가 시작된 뒤 지난 시간. 시작 = 더블점프 또는 트램펄린 퍼펙트 발사(도약 그림 CAT_LAUNCH_TIME 뒤),
## 둘 중 늦은 것. 착지·줄·그물 실림·다른 튕김·투명화·구제·끝날 떨어짐이면 NO_FLIP
static func flip_time(sim: RunnerSim) -> float:
	if sim.on_ground or sim.rescuing or sim.ghost_time > 0.0 or sim.is_riding() or sim.is_doomed():
		return NO_FLIP
	var t := sim.time_since_double_jump
	if sim.time_since_bounce < t:
		if sim.bounce_result != "perfect" or sim.bounced_line.get("kind", "") != "tramp":
			return NO_FLIP  # 더블점프 뒤 줄·그물에서 튕기면 끊김 (퍼펙트가 아닌 튕김에는 앞구르기 없음)
		t = sim.time_since_bounce - Balance.TRAMP_PUSH - Balance.CAT_LAUNCH_TIME
		if t < 0.0:
			return NO_FLIP  # 아직 도약 그림
	return t if t < sim.time_since_land else NO_FLIP


static func _pose(sim: RunnerSim) -> Dictionary:
	if sim.rescuing:
		# 종이상자에 실려 올라가는 중: 올라가는 자세로 코를 살짝 든다
		return {"frame": "rise", "scale": Vector2.ONE, "tilt": -6.0}
	if sim.is_riding():
		# 트램펄린·줄을 밟아 눌러 내려가는 중: 웅크려 힘을 모은 모습
		return {"frame": "crouch", "scale": Vector2(1.08, 0.88), "tilt": 0.0}
	if sim.is_doomed() or _tramp_flop(sim):
		# 떨어져서 끝나는 중·트램펄린에서 안 눌러 맥없이 튐: 코가 아래로 기울고, 몸 전체를 빠르게 흔들어 허우적거린다 (1초에 약 5번)
		var wobble := sin(sim.elapsed * TAU * 5.0)
		return {"frame": "flail", "scale": Vector2(1.0 + 0.04 * wobble, 1.0 - 0.04 * wobble), "tilt": 12.0 + 10.0 * wobble}
	if sim.on_ground:
		if sim.time_since_land < Balance.CAT_LAND_TIME:
			# 착지: 앞발부터 닿는 그림 (눌림은 스프링 충격 KICK_LAND)
			var k := sim.time_since_land / Balance.CAT_LAND_TIME
			return {"frame": "land", "scale": Vector2.ONE, "tilt": lerpf(6.0, 0.0, k)}
		# 달리기: 달린 거리로 프레임을 정해 빨라지면 다리도 그만큼 빨리 움직인다 (발이 미끄러져 보이지 않음)
		var phase := fposmod(sim.x / Balance.CAT_STRIDE, 1.0)
		var step := mini(int(phase * RUN_FRAMES.size()), RUN_FRAMES.size() - 1)
		return {"frame": RUN_FRAMES[step], "scale": RUN_SCALE[step], "tilt": 0.0, "bob": run_bob(phase)}
	if sim.time_since_jump < Balance.CAT_CROUCH_TIME:
		# 뛰는 순간: 아주 짧게 웅크려 땅을 박차는 모습
		return {"frame": "crouch", "scale": Vector2(1.06, 0.9), "tilt": 0.0}
	if sim.bounced_line.get("kind", "") == "tramp" and sim.time_since_bounce < sim.time_since_double_jump \
			and sim.time_since_bounce < Balance.TRAMP_PUSH + Balance.CAT_LAUNCH_TIME:
		# 트램펄린: 아직 그물에 눌린 그림 → 튕겨 나가는 도약 그림 (세로 늘어남은 스프링 충격)
		var pushed := sim.time_since_bounce < Balance.TRAMP_PUSH
		return {"frame": "crouch" if pushed else "takeoff", "scale": Vector2(1.08, 0.88) if pushed else Vector2.ONE, "tilt": 0.0}
	if sim.is_holding() and flip_time(sim) == NO_FLIP:
		# 누르고 있는 동안 박차고 오름: 길게 누를수록 몸이 앞뒤로 더 늘어난다
		# (그림이 이미 뒷발을 뒤로 뻗은 자세라 몸 전체를 위로 돌리지 않는다: 돌리면 로켓처럼 보임)
		var h := sim.hold_ratio()
		return {"frame": "takeoff", "scale": Vector2(1.0 + 0.1 * h, 1.0 - 0.05 * h), "tilt": 0.0}
	# 공중: 속도에 따라 계속 변하는 늘어남 x 꼭대기에서 둥글게 부풀기 x 작은 숨쉬기 (기울이지 않음)
	var apex := clampf(1.0 - absf(sim.vy) / Balance.CAT_APEX_SPEED, 0.0, 1.0)
	var breath := 1.0 + Balance.CAT_BREATH * sin(sim.elapsed * TAU * Balance.CAT_BREATH_HZ)
	var scale := Squash.body_scale(sim.vy) * Vector2.ONE.lerp(Balance.CAT_APEX_PUFF, apex) * breath
	# 앞구르기를 마친 뒤에는 착지까지 내려옴 그림 (펴기 → 내려옴 → 앞발부터 착지)
	var flipped := flip_time(sim) != NO_FLIP
	return {"frame": "rise" if sim.vy > 0.0 and not flipped else "fall", "scale": scale, "tilt": 0.0}


## 달리기 몸 들썩임 (게임 픽셀, phase = 달리기 한 바퀴 안 위치 0~1): 박차기·뒷발 들어옴 그림 가운데에서 가장 높고 한 바퀴에 2번
static func run_bob(phase: float) -> float:
	return Balance.CAT_RUN_BOB * 0.5 * (1.0 - cos(TAU * 2.0 * (phase - 0.125)))


## 트램펄린에서 안 눌러 맥없이 튀어 오르는 중 (내려설 때까지)
static func _tramp_flop(sim: RunnerSim) -> bool:
	return not sim.on_ground and sim.bounce_result == "miss" and sim.bounced_line.get("kind", "") == "tramp" \
			and sim.time_since_bounce >= Balance.TRAMP_PUSH and sim.time_since_bounce < sim.time_since_land \
			and sim.time_since_bounce < sim.time_since_double_jump
