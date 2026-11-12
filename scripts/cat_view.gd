class_name CatView
extends Node2D
## 고양이 그림: 자세별 통그림(assets/sprites/cat_frames/)을 바꿔 보여 주는 프레임 애니메이션.
## 이 노드의 원점 = 고양이 발끝 가운데 (로직의 x, y와 같은 점). 프레임 고르기는 CatPose, 여기서는 그리기만 한다.
## 프레임 그림은 tools/align_frames.py로 같은 크기·같은 기준점(발끝, 몸 중심)에 맞춰 두어 바꿔도 떨리지 않는다.
## 몸 배율은 스프링(Spring)으로 목표를 따라가고, 착지·이륙·트램펄린 같은 순간에는 스프링에 충격을 넣어 말랑하게 출렁인다.

const FRAME_DIR := "res://assets/sprites/cat_frames/"
## 프레임 그림 안의 기준점 (tools/align_frames.py의 ANCHOR_X, BASELINE과 같아야 함)
const ANCHOR := Vector2(360, 450)
## 프레임은 기준 그림(cat_base_run.png)의 절반 크기(align_frames.py OUT_SCALE)로 저장되어 있다.
## 기준 그림에서 꼬리를 뺀 몸 너비는 711픽셀(balance.gd 주석)이므로, 그 너비가 충돌 판정 너비가 되게 줄인다.
const BASE_BODY_WIDTH := 711.0
const FRAME_SCALE := 0.5
## 기울기가 목표로 다가가는 빠르기 (클수록 빨리 바뀜)
const TILT_SMOOTH := 22.0
## 부딪힌 뒤 비틀거림 (그림만, 속도·판정은 그대로): 최대 각도, 시간(초), 빠르기
const STAGGER_DEG := 14.0
const STAGGER_TIME := 0.6
const STAGGER_RATE := 20.0
const INVULN_BLINK := 0.08  # 무적 깜빡임 간격 (초)
const DASH_TINT := Color(1.0, 0.86, 0.5)
## 부딪힌 직후 빨갛게 깜빡임 (그 뒤는 무적 깜빡임)
const HIT_FLASH_TIME := 0.3
const HIT_FLASH_COLOR := Color(1.0, 0.62, 0.56)  # 곱하는 색이라 너무 진하면 고양이가 빨간 덩어리로 보임

var frame_name := "run_0"
var _textures := {}
var _sprite := Sprite2D.new()
var _spring := Spring.new(Balance.CAT_SPRING_HZ, Balance.CAT_SPRING_DAMPING)
var _tilt := 0.0
var _last := {}  # 지난 프레임의 sim 타이머·상태 (줄어들었으면 그 일이 새로 일어난 것)
var _stand := 0.0  # 앉아 있다 달리기 시작한 뒤 "일어남" 그림을 보일 남은 시간


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # 크게 줄여 그려도 거칠지 않게
	for frame in CatPose.ALL_FRAMES:
		_textures[frame] = load(FRAME_DIR + frame + ".png")
	_sprite.name = "Sprite"
	_sprite.centered = false
	# 그림을 몸 가운데(발끝 위 몸 높이의 절반)에 두고 그 점을 축으로 돌린다 (공중제비). 회전이 0이면 전과 같은 자리
	_sprite.position = spin_center()
	_sprite.offset = -ANCHOR - spin_center()
	_sprite.texture = _textures[frame_name]
	add_child(_sprite)
	scale = Vector2.ONE * art_scale()


## 이름의 프레임 그림 (질주 잔상용)
func frame_texture(frame: String) -> Texture2D:
	return _textures[frame]


## 공중제비 회전축: 발끝(원점)에서 몸 높이의 절반 위 (프레임 픽셀)
static func spin_center() -> Vector2:
	return Vector2(0.0, -Balance.CAT_BODY_SIZE.y * 0.5 / art_scale())


## 프레임 픽셀 → 게임 픽셀 배율
static func art_scale() -> float:
	return Balance.CAT_BODY_SIZE.x / (BASE_BODY_WIDTH * FRAME_SCALE)


## 지금 몸 배율 (스프링 값, 테스트·캡처용)
func body_scale() -> Vector2:
	return _spring.value


## 지금 공중제비 회전 (라디안, 그림자 폭 계산용)
func spin() -> float:
	return _sprite.rotation


## 로직 상태에 맞춰 그림·늘어남·기울기·투명도를 바꾼다. dt = 지난 프레임 시간 (0이면 바로 목표로).
## 노드 위치(발끝)는 부르기 전에 world_view.gd가 정하고, 여기서는 달리기 들썩임만큼 그림을 올린다.
func show_state(sim: RunnerSim, dt: float) -> void:
	var pose := CatPose.pose(sim)
	frame_name = pose.frame
	_sprite.texture = _textures[frame_name]
	if dt <= 0.0:
		_spring = Spring.new(Balance.CAT_SPRING_HZ, Balance.CAT_SPRING_DAMPING, pose.scale)
		_tilt = pose.tilt
	else:
		_kick_events(sim)
		_spring.step(pose.scale, dt)
		_tilt = lerpf(_tilt, pose.tilt, 1.0 - exp(-TILT_SMOOTH * dt))
	_remember(sim)
	if _stand > 0.0 and dt > 0.0:
		_stand -= dt
		frame_name = "sit_up"  # 앉아 있다가 일어나며 달리기로
		_sprite.texture = _textures[frame_name]
	# 발끝(원점)을 기준으로 늘이고 줄이고 기울여서 옥상에 붙어 있게 한다 (스프링이 넘쳐도 뒤집히지 않게 하한)
	scale = _spring.value.max(Vector2(0.5, 0.5)) * art_scale()
	rotation_degrees = _tilt + stagger(sim.time_since_hit)
	_sprite.rotation = pose.spin
	position.y -= pose.bob
	# 투명화 중에는 반투명하게, 0.1초마다 깜빡인다
	modulate = Color.WHITE
	if sim.dashing:
		modulate = DASH_TINT.lerp(Color.WHITE, 0.5 + 0.5 * sin(sim.elapsed * 18.0))  # 금빛으로 번쩍임
	elif sim.time_since_hit < HIT_FLASH_TIME:
		modulate = HIT_FLASH_COLOR if int(sim.time_since_hit / INVULN_BLINK) % 2 == 0 else Color.WHITE
	elif sim.ghost_time > 0.0:
		modulate.a = 0.2 if int(sim.ghost_time * 10.0) % 2 == 0 else 0.55
	elif sim.invuln_time > 0.0:
		modulate.a = 0.3 if int(sim.invuln_time / INVULN_BLINK) % 2 == 0 else 0.9


## 시작 화면: 앉아서 꼬리를 흔든다 (t = 앉아 있은 시간). 다음 달리기 첫 순간에 "일어남"을 보이게 해 둔다
func show_sit(t: float) -> void:
	frame_name = CatPose.sit_frame(t)
	_sprite.texture = _textures[frame_name]
	_sprite.rotation = 0.0
	rotation = 0.0
	scale = Vector2.ONE * art_scale()
	modulate = Color.WHITE
	_stand = CatPose.STAND_TIME


## 부딪힌 뒤 since초일 때 몸 기울기 (도). 차츰 잦아든다
static func stagger(since: float) -> float:
	if since >= STAGGER_TIME:
		return 0.0
	return STAGGER_DEG * sin(since * STAGGER_RATE) * (1.0 - since / STAGGER_TIME)


## 지난 프레임 뒤에 새로 일어난 일(착지, 점프, 웅크림 끝, 더블점프, 그물 실림, 튕김)마다 스프링에 충격을 넣는다
func _kick_events(sim: RunnerSim) -> void:
	if _last.is_empty():
		return
	if sim.time_since_land < _last.land:
		_spring.kick(Balance.KICK_LAND)
	if sim.time_since_jump < _last.jump:
		_spring.kick(Balance.KICK_CROUCH)
	# 경계를 넘었거나, 느린 프레임이라 새로 뛴 프레임에 이미 경계를 지났을 때도 (아래 그물을 떠나는 순간도 같음)
	if sim.time_since_jump >= Balance.CAT_CROUCH_TIME and not sim.on_ground \
			and (_last.jump < Balance.CAT_CROUCH_TIME or sim.time_since_jump < _last.jump):
		_spring.kick(Balance.KICK_TAKEOFF)
	if sim.time_since_double_jump < _last.double:
		_spring.kick(Balance.KICK_DOUBLE)
	if sim.time_since_stage_rise < _last.stage:
		_spring.kick(Balance.KICK_TAKEOFF)  # 빨라지는 순간 몸이 앞으로 쭉 (속도 단계 신호)
	# 그물에 실림 (닿자마자 튕긴 퍼펙트는 실린 프레임이 없으니 튕긴 순간에)
	if (sim.is_riding() and not _last.riding) or (sim.time_since_bounce < _last.bounce and not _last.riding):
		_spring.kick(Balance.KICK_TRAMP_RIDE)
	# 그림이 그물을 떠나는 순간 세로로 늘어나며 발사
	if sim.time_since_bounce >= Balance.TRAMP_PUSH and (_last.bounce < Balance.TRAMP_PUSH or sim.time_since_bounce < _last.bounce):
		_spring.kick(Balance.KICK_TRAMP_LAUNCH[sim.bounce_result])


func _remember(sim: RunnerSim) -> void:
	_last = {"land": sim.time_since_land, "jump": sim.time_since_jump, "double": sim.time_since_double_jump,
			"bounce": sim.time_since_bounce, "riding": sim.is_riding(),
			"stage": sim.time_since_stage_rise}
