class_name KittenView
extends Node2D
## 아기 고양이 새 움직임 그림 (cat-parade 1단계 A·B 비교, 치즈 아기만). 계산은 KittenMotion, 여기서는 그리기만.
## 이 노드의 원점 = 아기 발끝 가운데. A = 프레임 그림 한 장, B = 부품 7개(다리 4·꼬리·몸통·머리)를 돌려 맞춤.
## 세로 눌림은 원점(발끝) 축이라 발이 바닥에서 뜨지 않는다. 공중 기울기는 몸 가운데 축.

const A_DIR := "res://assets/sprites/kitten_motion/cheese_a/"
const B_DIR := "res://assets/sprites/kitten_motion/cheese_b/"
const A_FRAMES := ["run_0", "run_1", "run_2", "run_3", "run_4", "run_5", "run_6", "run_7",
		"crouch", "takeoff", "rise", "fall", "land", "startle"]
const B_PARTS := ["hind_far", "front_far", "tail", "hind_near", "front_near", "head", "torso"]  # 그리는 순서 (뒤 → 앞). 가까운 다리도 몸통 뒤라 둥근 윗부분(관절 이음매)이 가려지고, 머리도 몸통 뒤라 몸통의 목걸이가 보임 (2차 검토)
const CENTER := 48.0     # 기울기 축: 발끝에서 이만큼 위 (게임 픽셀)
const TAIL_SWAY := 0.12  # 달릴 때 꼬리 흔들림 (라디안)
const CROUCH_DROP := 10.0 # 웅크림: 몸을 이만큼 낮춤 (부품 픽셀)
const TORSO_ROCK := 0.035 # 달릴 때 몸통 앞뒤 흔들림 (걸음마다 두 번, 라디안. 2차 검토: 몸통이 딱딱함)

var mode := ""           # "a" / "b"
var frame_name := ""     # A 지금 그림 (테스트·그림자용)
var _spin := Node2D.new()
var _art := Node2D.new()
var _a := Sprite2D.new()
var _a_tex := {}
var _b := {}             # 부품 이름 → Sprite2D
var _head_tex := {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_spin)
	_spin.add_child(_art)
	for f in A_FRAMES:
		_a_tex[f] = load(A_DIR + f + ".png")
	_a.centered = false
	_a.offset = -Vector2(KittenMotionData.A_ANCHOR[0], KittenMotionData.A_ANCHOR[1])
	_art.add_child(_a)
	for part in B_PARTS:
		var s := Sprite2D.new()
		s.name = part
		s.centered = false
		s.texture = load(B_DIR + part + ".png")
		if part == "torso":
			s.offset = -torso_center()  # 흔들림 축 = 몸통 가운데
		else:
			s.offset = -Vector2(KittenMotionData.B_PIVOT[part][0], KittenMotionData.B_PIVOT[part][1])
		_art.add_child(s)
		_b[part] = s
	_head_tex = {false: _b.head.texture, true: load(B_DIR + "head_surprised.png")}


## p: {"kind": run/land/crouch/takeoff/rise/fall/startle, "dist"(아기가 달린 거리), "tilt", "land_k", "squash", "facing"(1 = 오른쪽), "surprised"}
func show_motion(m: String, p: Dictionary) -> void:
	mode = m
	_a.visible = m == "a"
	for part in _b:
		_b[part].visible = m == "b"
	var k := KittenMotion.px() if m == "a" else KittenMotion.b_scale()
	var stretch: Vector2 = KittenMotion.AIR_STRETCH.get(p.kind, Vector2.ONE)
	scale = Vector2(p.get("facing", 1.0) * k * stretch.x, k * p.get("squash", 1.0) * stretch.y)
	_spin.position = Vector2(0.0, -CENTER / k)
	_art.position = Vector2(0.0, CENTER / k)
	_spin.rotation = p.get("tilt", 0.0)
	if m == "a":
		_show_a(p)
	else:
		_show_b(p)


static func torso_center() -> Vector2:
	return Vector2(KittenMotionData.B_SIZE.torso[0], KittenMotionData.B_SIZE.torso[1]) * 0.5


func _show_a(p: Dictionary) -> void:
	var kind: String = p.kind
	if kind == "run":
		kind = "land" if p.get("land_k", 1.0) < 0.6 else "run_%d" % KittenMotion.a_frame(p.dist)
	elif kind == "stand":
		kind = "land"  # A에는 그냥 선 그림이 따로 없어 네 발로 선 착지 그림
	frame_name = kind
	_a.texture = _a_tex[kind]


func _show_b(p: Dictionary) -> void:
	var kind: String = p.kind
	var pose: Dictionary
	if kind == "run":
		pose = KittenMotion.b_run(p.dist)
	elif kind in ["startle", "stand", "turn"]:
		pose = KittenMotion.b_stand()
	elif kind == "crouch":
		pose = KittenMotion.b_stand(CROUCH_DROP)  # 네 발은 바닥에 둔 채 몸만 낮춤
	else:
		pose = KittenMotion.b_air(kind)
	frame_name = kind
	for leg in KittenMotion.B_LEGS:
		var l: Dictionary = pose.legs[leg]
		var t := KittenMotion.b_leg(l.hip, l.foot, KittenMotion.b_len(leg))
		_b[leg].position = l.hip
		_b[leg].rotation = t.x
		_b[leg].scale = Vector2(1.0, t.y)
	var origin := KittenMotion.b_torso_origin()
	var body := Vector2(0.0, pose.drop)
	_b.torso.position = -origin + torso_center() + body
	_b.torso.rotation = TORSO_ROCK * sin(TAU * 2.0 * p.dist / KittenMotion.b_stride()) if kind == "run" else 0.0
	var pl: Dictionary = KittenMotionData.B_PLACE
	_b.head.position = Vector2(pl.neck[0], pl.neck[1]) - origin + body  # 몸과 같이 (따로 움직이면 목걸이가 깜빡임, 1차 검토)
	_b.head.texture = _head_tex[p.get("surprised", false)]
	_b.tail.position = Vector2(pl.tail[0], pl.tail[1]) - origin + body
	var phase: float = p.dist / KittenMotion.b_stride() if kind == "run" else 0.0
	_b.tail.rotation = TAIL_SWAY * sin(TAU * phase) if kind == "run" else (-0.25 if kind == "fall" else 0.1)
