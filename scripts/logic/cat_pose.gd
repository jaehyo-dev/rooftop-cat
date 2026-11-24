class_name CatPose
## 고양이 동작에 맞는 그림(프레임)과 그 위에 얹을 몸 전체의 목표 배율·기울기·들썩임 (화면과 분리된 순수 계산).
## 그림은 자세별 통그림이고(다리를 따로 움직이지 않음), 프레임 사이는 몸 배율 스프링(Spring, cat_view.gd)으로 출렁이며 잇는다.
## 앞구르기 공중제비(spin)는 기울기 금지의 예외: 몸을 말아 가는 그림 4장을 바꾸며 몸 가운데 기준으로 한 바퀴 돈다.
## 배율은 발끝을 기준으로 적용하므로 발이 옥상에서 뜨지 않는다. 기울기는 도 단위, 양수 = 시계 방향(코가 아래로).

## 달리기 한 바퀴의 프레임 (고양이 갤럽 8장: 쭉 뻗기 → 공중 → 앞발 착지 → 앞발로 받치기 → 모으기 → 뒷발 착지 → 뒷발 박차기 → 늘어남).
## 몸은 늘 낮고 머리 높이는 그림에서 거의 같다 (모으는 장은 run_4 하나, 몸을 세운 장 없음)
const RUN_FRAMES := ["run_0", "run_1", "run_2", "run_3", "run_4", "run_5", "run_6", "run_7"]
## 프레임마다 몸 전체 배율 (가로, 세로): 뻗을 때 길고 낮게, 모을 때 짧게 (세로는 살짝만: 몸을 세워 보이지 않게)
const RUN_SCALE := [Vector2(1.04, 0.97), Vector2(1.03, 0.98), Vector2(1.01, 0.99), Vector2(0.99, 1.0),
		Vector2(0.97, 1.02), Vector2(0.99, 1.01), Vector2(1.01, 0.99), Vector2(1.03, 0.98)]
## 장마다 끝나는 위치 (한 바퀴 0~1). 다리를 몸 아래에 둔 run_3·run_4는 짧게(각 0.08), 뻗기·공중은 길게:
## 같은 길이면 두 장이 이어서 약 5게임프레임 보여 잠깐 서 있는 것처럼 보였다 (2026-11-24 0.25배 영상)
const RUN_UNTIL := [0.15, 0.31, 0.44, 0.52, 0.60, 0.73, 0.86, 1.0]
const RUN_BOB_PEAK := 0.23  # 공중 장(run_1) 가운데
## 앞구르기 프레임 (숙이기, C자, 공, 펴기)과 각 그림으로 바뀌는 회전 각도 (도)
const FLIP_FRAMES := ["flip_tuck", "flip_curl", "flip_ball", "flip_open"]
const FLIP_FROM_DEG := [0.0, 25.0, 60.0, 300.0]
const ALL_FRAMES := ["run_0", "run_1", "run_2", "run_3", "run_4", "run_5", "run_6", "run_7", "crouch", "takeoff", "rise", "fall", "land", "flail",
		"flip_tuck", "flip_curl", "flip_ball", "flip_open", "sit_body", "sit_body_blink", "sit_up",
		"slide_down", "slide_a", "slide_b", "slide_up1", "slide_up2", "dive", "slide_squash",
		"hit", "hit_fly", "hit_wobble"]
## 슬라이딩 (카툰 2단계): 땅 = 몸 낮추기(SLIDE_DOWN_TIME) → 미끄러지기 a·b를 달린 거리로 반복 → 떼면 일어나기 1·2(SLIDE_UP_TIME을 반씩).
## 공중 = 내리꽂기(dive) → 누른 채 땅에 닿으면 눌림(SLIDE_SQUASH_TIME) → 미끄러지기
const SLIDE_FRAMES := ["slide_a", "slide_b"]
const SLIDE_STRIDE := 100.0  # 미끄러지기 a·b 한 바퀴의 거리 (목도리 끝·먼지 펄럭임)
const SLIDE_DOWN_TIME := 0.06
const SLIDE_SQUASH_TIME := 0.1
const SLIDE_UP_TIME := 0.16
## 피격 (카툰 2단계): 맞는 순간 → 튕겨 뜸 → 네 발로 휘청 → 달리기. 각 그림이 끝나는 시간 (부딪힌 뒤 초). 판정·무적은 그대로
const HIT_FRAMES := ["hit", "hit_fly", "hit_wobble"]
const HIT_UNTIL := [0.08, 0.26, 0.48]
## 시작 화면 (2c-polish): 몸 그림 한 장(바닥 고정) 뒤에 꼬리 그림 8장(tools/make_sit_tail.py)을 오가며 흔들고,
## 몸은 바닥을 축으로 아주 살짝 숨쉬고, 가끔 눈을 깜빡인다. 예전 sit_0·1·2는 몸 바닥이 달라 위아래로 흔들렸다
const SIT_TAILS := 8
const SIT_WAG := 2.4         # 꼬리 아래 → 위 → 아래 한 번 (초). 양 끝에서 느리고 가운데서 빠름
const SIT_BLINK_EVERY := 4.2 # 깜빡임 간격 (초)
const SIT_BLINK_AT := 3.0    # 간격 안에서 깜빡이는 때
const SIT_BLINK_TIME := 0.16
const SIT_BREATH := 0.012    # 숨쉬기 세로 늘어남 (가로는 절반만큼 줄어듦)
const SIT_BREATH_TIME := 2.0
const STAND_TIME := 0.15     # [시작]을 누르면 이만큼 "일어남" 그림을 보이고 달리기로
const NO_FLIP := 99.0


## 시작 화면에서 t초 동안 앉아 있을 때의 몸 그림 (눈 뜸 / 감음)
static func sit_frame(t: float) -> String:
	var u := fmod(maxf(t, 0.0), SIT_BLINK_EVERY) - SIT_BLINK_AT
	return "sit_body_blink" if u >= 0.0 and u < SIT_BLINK_TIME else "sit_body"


## 꼬리 그림 번호 (0 = 바닥, SIT_TAILS - 1 = 위). 코사인으로 오가 양 끝에서 머무는 듯 부드럽게
static func sit_tail(t: float, count: int = SIT_TAILS) -> int:
	var p := 0.5 - 0.5 * cos(TAU * maxf(t, 0.0) / SIT_WAG)
	return roundi(p * (count - 1))


## 숨쉬기 배율 (바닥 = 발끝 원점을 기준으로 곱함)
static func sit_breath(t: float) -> Vector2:
	var b := sin(TAU * maxf(t, 0.0) / SIT_BREATH_TIME)
	return Vector2(1.0 - SIT_BREATH * 0.5 * b, 1.0 + SIT_BREATH * b)


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
	# 피격은 슬라이딩보다 먼저 (슬라이딩 중 화분에 맞아도 맞은 그림을 보이고, 끝나면 미끄러지기로 돌아감)
	var hit := hit_frame(sim)
	if hit != "":
		return {"frame": hit, "scale": Vector2.ONE, "tilt": 0.0}
	if sim.on_ground and sim.sliding:
		return {"frame": slide_frame(sim), "scale": Vector2.ONE, "tilt": 0.0}
	if sim.on_ground and sim.time_since_stand < SLIDE_UP_TIME:
		return {"frame": "slide_up1" if sim.time_since_stand < SLIDE_UP_TIME * 0.5 else "slide_up2", "scale": Vector2.ONE, "tilt": 0.0}
	if sim.diving:
		return {"frame": "dive", "scale": Vector2.ONE, "tilt": 0.0}
	if sim.on_ground:
		if sim.time_since_land < Balance.CAT_LAND_TIME:
			# 착지: 앞발부터 닿는 그림 (눌림은 스프링 충격 KICK_LAND)
			var k := sim.time_since_land / Balance.CAT_LAND_TIME
			return {"frame": "land", "scale": Vector2.ONE, "tilt": lerpf(6.0, 0.0, k)}
		# 달리기: 달린 거리로 프레임을 정해 빨라지면 다리도 그만큼 빨리 움직인다 (발이 미끄러져 보이지 않음)
		var phase := fposmod(sim.x / Balance.CAT_STRIDE, 1.0)
		var step := RUN_UNTIL.bsearch(phase, false)  # phase보다 큰 첫 끝 위치 = 지금 장
		step = mini(step, RUN_FRAMES.size() - 1)
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


## 땅에서 슬라이딩 중 그림: 누른 채 착지해 막 시작했으면 눌림, 달리다 시작했으면 몸 낮추기, 그 뒤 미끄러지기 a·b
static func slide_frame(sim: RunnerSim) -> String:
	if sim.time_since_slide < SLIDE_SQUASH_TIME and sim.time_since_land <= sim.time_since_slide + 0.02:
		return "slide_squash"
	if sim.time_since_slide < SLIDE_DOWN_TIME:
		return "slide_down"
	var k := mini(int(fposmod(sim.x / SLIDE_STRIDE, 1.0) * SLIDE_FRAMES.size()), SLIDE_FRAMES.size() - 1)
	return SLIDE_FRAMES[k]


## 부딪힌 뒤 그림 ("" = 피격 그림 아님). 휘청은 땅에서만 (공중이면 그대로 내려옴 그림)
static func hit_frame(sim: RunnerSim) -> String:
	for i in HIT_FRAMES.size():
		if sim.time_since_hit < HIT_UNTIL[i]:
			return "" if HIT_FRAMES[i] == "hit_wobble" and not sim.on_ground else HIT_FRAMES[i]
	return ""


## 달리기 몸 들썩임 (게임 픽셀, phase = 달리기 한 바퀴 안 위치 0~1): 한 바퀴에 1번, 작게.
## 공중 장(run_1) 가운데에서 가장 높고 반대편(뒷발 착지 → 박차기 사이)에서 가장 낮다. 머리 높이는 그림에서 이미 거의 같다
static func run_bob(phase: float) -> float:
	return Balance.CAT_RUN_BOB * 0.5 * (1.0 + cos(TAU * (phase - RUN_BOB_PEAK)))


## 트램펄린에서 안 눌러 맥없이 튀어 오르는 중 (내려설 때까지)
static func _tramp_flop(sim: RunnerSim) -> bool:
	return not sim.on_ground and sim.bounce_result == "miss" and sim.bounced_line.get("kind", "") == "tramp" \
			and sim.time_since_bounce >= Balance.TRAMP_PUSH and sim.time_since_bounce < sim.time_since_land \
			and sim.time_since_bounce < sim.time_since_double_jump
