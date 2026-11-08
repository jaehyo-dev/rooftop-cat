class_name CatView
extends Node2D
## 고양이 그림: 자세별 통그림(assets/sprites/cat_frames/)을 바꿔 보여 주는 프레임 애니메이션.
## 이 노드의 원점 = 고양이 발끝 가운데 (로직의 x, y와 같은 점). 프레임 고르기는 CatPose, 여기서는 그리기만 한다.
## 프레임 그림은 tools/align_frames.py로 같은 크기·같은 기준점(발끝, 몸 중심)에 맞춰 두어 바꿔도 떨리지 않는다.

const FRAME_DIR := "res://assets/sprites/cat_frames/"
## 프레임 그림 안의 기준점 (tools/align_frames.py의 ANCHOR_X, BASELINE과 같아야 함)
const ANCHOR := Vector2(360, 450)
## 프레임은 기준 그림(cat_base_run.png)의 절반 크기(align_frames.py OUT_SCALE)로 저장되어 있다.
## 기준 그림에서 꼬리를 뺀 몸 너비는 711픽셀(balance.gd 주석)이므로, 그 너비가 충돌 판정 너비가 되게 줄인다.
const BASE_BODY_WIDTH := 711.0
const FRAME_SCALE := 0.5
## 목표 배율·기울기로 다가가는 빠르기 (클수록 빨리 바뀜)
const SMOOTH := 22.0

var frame_name := "run_0"
var _textures := {}
var _sprite := Sprite2D.new()
var _scale := Vector2.ONE
var _tilt := 0.0


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


## 공중제비 회전축: 발끝(원점)에서 몸 높이의 절반 위 (프레임 픽셀)
static func spin_center() -> Vector2:
	return Vector2(0.0, -Balance.CAT_BODY_SIZE.y * 0.5 / art_scale())


## 프레임 픽셀 → 게임 픽셀 배율
static func art_scale() -> float:
	return Balance.CAT_BODY_SIZE.x / (BASE_BODY_WIDTH * FRAME_SCALE)


## 로직 상태에 맞춰 그림·늘어남·기울기·투명도를 바꾼다. dt = 지난 프레임 시간 (0이면 바로 목표로)
func show_state(sim: RunnerSim, dt: float) -> void:
	var pose := CatPose.pose(sim)
	frame_name = pose.frame
	_sprite.texture = _textures[frame_name]
	var k := 1.0 if dt <= 0.0 else 1.0 - exp(-SMOOTH * dt)
	_scale = _scale.lerp(pose.scale, k)
	_tilt = lerpf(_tilt, pose.tilt, k)
	# 발끝(원점)을 기준으로 늘이고 줄이고 기울여서 옥상에 붙어 있게 한다
	scale = _scale * art_scale()
	rotation_degrees = _tilt
	_sprite.rotation = pose.spin
	# 투명화 중에는 반투명하게, 0.1초마다 깜빡인다
	modulate.a = 1.0
	if sim.ghost_time > 0.0:
		modulate.a = 0.2 if int(sim.ghost_time * 10.0) % 2 == 0 else 0.55
