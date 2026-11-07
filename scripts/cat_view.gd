class_name CatView
extends Node2D
## 고양이 그림: 부품(assets/sprites/cat_parts/)을 Skeleton2D 뼈대에 붙여 달리기·점프·착지 동작으로 움직인다.
## 이 노드의 원점 = 고양이 발끝 가운데 (로직의 x, y와 같은 점). 그림 크기는 충돌 판정 크기(Balance.CAT_BODY_SIZE)에 맞춘다.
## AI로 프레임을 한 장씩 만들면 장마다 모습이 달라져 떨려 보이므로, 같은 부품을 돌리고 움직여서 동작을 만든다.

## 부품 배치 (부품 시트 픽셀 단위, 몸통 그림의 왼쪽 위가 원점). 그리는 순서대로.
## top_left = 부품 그림의 왼쪽 위 위치, pivot = 부품 그림 안에서 도는 중심(어깨·엉덩이·목·꼬리 뿌리), dark = 몸 뒤쪽 부품
## 앞다리는 둘 다 몸 뒤에 그려서 목도리 매듭이 가려지지 않게 한다 (가슴 아래에서 다리가 나온 모습)
const PARTS := [
	{"name": "back_back", "file": "back_leg_back", "top_left": Vector2(95, 136), "pivot": Vector2(90, 60), "dark": true},
	{"name": "front_back", "file": "front_leg_back", "top_left": Vector2(395, 181), "pivot": Vector2(65, 45), "dark": true},
	{"name": "front", "file": "front_leg", "top_left": Vector2(455, 186), "pivot": Vector2(65, 45), "dark": false},
	{"name": "tail", "file": "tail", "top_left": Vector2(-215, -110), "pivot": Vector2(290, 250), "dark": false},
	{"name": "body", "file": "body", "top_left": Vector2(0, 0), "pivot": Vector2.ZERO, "dark": false},
	{"name": "back", "file": "back_leg", "top_left": Vector2(30, 141), "pivot": Vector2(90, 60), "dark": false},
	{"name": "head", "file": "head", "top_left": Vector2(390, -11), "pivot": Vector2(120, 260), "dark": false},
]
## 꼬리를 뺀 고양이 전체(엉덩이~얼굴 끝, 머리 위~발끝)의 범위 (부품 시트 픽셀). 이 범위가 충돌 판정 크기에 맞는다
const ART_LEFT := 6.0
const ART_RIGHT := 712.0
const ART_TOP := -5.0
const ART_FEET := 431.0
## 몸 뒤쪽 다리를 조금 어둡고 따뜻하게 칠해 앞쪽 다리와 구분한다 (털색이 회색으로 보이지 않게)
const DARK := Color(0.88, 0.8, 0.72)
## 목표 자세로 다가가는 빠르기 (클수록 빨리 바뀜)
const SMOOTH := 18.0

var _bones := {}       # 이름 → Bone2D
var _angles := {}      # 이름 → 지금 각도 (부드럽게 따라감)
var _legs := {}        # 다리 이름 → {"pivot_y": 몸통 기준 도는 중심 높이, "length": 도는 중심~발끝 길이} (부품 시트 픽셀)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # 크게 줄여 그려도 거칠지 않게
	var skeleton := Skeleton2D.new()
	skeleton.name = "Skeleton"
	var scale_factor := art_scale()
	skeleton.scale = Vector2.ONE * scale_factor
	# 발끝 가운데가 이 노드의 원점에 오게 옮긴다
	skeleton.position = Vector2(-(ART_LEFT + ART_RIGHT) * 0.5, -ART_FEET) * scale_factor
	add_child(skeleton)
	var body := Bone2D.new()
	body.name = "body"
	body.set_autocalculate_length_and_angle(false)  # 부품을 붙이는 뼈대라 길이·각도 자동 계산이 필요 없음
	skeleton.add_child(body)
	for part in PARTS:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/sprites/cat_parts/%s.png" % part.file)
		sprite.centered = false
		sprite.offset = -part.pivot
		if part.dark:
			sprite.modulate = DARK
		if part.name == "body":
			sprite.position = part.top_left
			body.add_child(sprite)
			continue
		var bone := Bone2D.new()
		bone.name = part.name
		bone.position = part.top_left + part.pivot
		bone.set_autocalculate_length_and_angle(false)
		bone.rest = bone.transform
		bone.add_child(sprite)
		body.add_child(bone)
		_bones[part.name] = bone
		_angles[part.name] = 0.0
		if part.name in CatPose.LEGS:
			var used := sprite.texture.get_image().get_used_rect()
			_legs[part.name] = {"pivot_y": bone.position.y, "length": used.end.y - part.pivot.y}
	body.rest = body.transform
	_bones["body"] = body


## 부품 시트 픽셀 → 게임 픽셀 배율: 그림의 가로 길이를 충돌 판정 너비에 맞춘다
static func art_scale() -> float:
	return Balance.CAT_BODY_SIZE.x / (ART_RIGHT - ART_LEFT)


## 로직 상태에 맞춰 자세·늘어남·투명도를 바꾼다. dt = 지난 프레임 시간
func show_state(sim: RunnerSim, dt: float) -> void:
	var target := CatPose.target(sim.on_ground, sim.vy, sim.x, sim.time_since_land)
	var k := 1.0 - exp(-SMOOTH * dt)
	for part_name in _angles:
		_angles[part_name] = lerpf(_angles[part_name], target[part_name], k)
		_bones[part_name].rotation_degrees = _angles[part_name]
	# 다리가 기울면 발이 올라가므로, 가장 낮은 발이 발끝 높이(ART_FEET)에 닿도록 몸 전체를 내린다
	var lowest := -INF
	for leg in _legs:
		lowest = maxf(lowest, _legs[leg].pivot_y + _legs[leg].length * cos(deg_to_rad(_angles[leg])))
	_bones["body"].position.y = ART_FEET - lowest
	# 발끝을 기준으로 늘이고 줄여서 착지할 때 옥상에 붙어 있게 한다
	scale = Squash.body_scale(sim.on_ground, sim.vy, sim.time_since_land)
	# 투명화 중에는 반투명하게, 0.1초마다 깜빡인다
	modulate.a = 1.0
	if sim.ghost_time > 0.0:
		modulate.a = 0.2 if int(sim.ghost_time * 10.0) % 2 == 0 else 0.55


## 부품 각도 (테스트용)
func angle_of(part_name: String) -> float:
	return _angles.get(part_name, 0.0)
