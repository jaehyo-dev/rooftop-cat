class_name KittenView
extends Node2D
## 아기 고양이 그림 (방식 A, 6마리). 계산은 KittenMotion, 여기서는 그리기만.
## 이 노드의 원점 = 아기 발끝 가운데. 그림 한 장 + 도망 달리기 때만 놀란 윗몸을 그 위에 덮음.
## 세로 눌림은 원점(발끝) 축이라 발이 바닥에서 뜨지 않는다. 공중 기울기는 몸 가운데 축.

const DIR := "res://assets/sprites/kitten_motion/"
## 달리기 32장(장 수는 KittenMotionData.RUN_FRAMES) + 땅·공중 자세. _b = 그 자세의 다음 순간 (KittenMotion.air_pose가 번갈아 씀)
## scared_* = 도망: 놀라 움츠림·깜짝 펄쩍 (놀란 얼굴, 2026-11-17)
const POSES := ["crouch", "crouch_b", "takeoff", "takeoff_b", "rise", "rise_b", "apex", "apex_b", "fall", "fall_b",
		"flip_tuck", "flip_curl", "flip_ball", "flip_ball_b", "flip_open", "flail", "flail_b", "land", "startle",
		"scared_crouch", "scared_hop"]
const CENTER := 48.0     # 기울기 축: 발끝에서 이만큼 위 (게임 픽셀)
const LAND_FRAME := 0.25  # 착지 눌림이 이만큼 풀릴 때까지 착지 그림 (0.6 = 0.12초는 네 발 디딘 채 미끄러짐, motion2 3차 검토)
static var _cache := {}  # 품종 → {"tex": {이름: 그림}, "upper": 놀란 윗몸, "land_fix": 달리기 키 / 착지 그림 키}

var breed := ""
var frame_name := ""     # 지금 그림 (테스트·그림자용)
var _spin := Node2D.new()
var _art := Node2D.new()
var _a := Sprite2D.new()
var _upper := Sprite2D.new()  # 도망 달리기: 놀란 윗몸 (달리기 그림 위, 그 장의 BOB만큼 내림)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_spin)
	_spin.add_child(_art)
	for s in [_a, _upper]:
		s.centered = false
		s.offset = -Vector2(KittenMotionData.ANCHOR[0], KittenMotionData.ANCHOR[1])
		_art.add_child(s)


static func frames() -> Array:
	var out := []
	for k in KittenMotionData.RUN_FRAMES:
		out.append("run_%d" % k)
	return out + POSES


static func textures(look: String) -> Dictionary:
	if not _cache.has(look):
		var tex := {}
		for f in frames():
			tex[f] = load(DIR + look + "/" + f + ".png")
		# 착지 동안 키를 서서히 달리기 키로 (바꾸는 순간 툭 커지지 않게, motion2 검토)
		_cache[look] = {"tex": tex, "upper": load(DIR + look + "/scared_upper.png"), "land_fix": _height(tex.run_0) / _height(tex.land)}
	return _cache[look]


static func _height(t: Texture2D) -> float:
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	return float(img.get_used_rect().size.y)


## p: {"kind": run/land/stand/crouch/takeoff/rise/fall/startle/scared_*…, "dist"(아기가 달린 거리), "tilt", "land_k", "squash", "widen",
## "facing"(1 = 오른쪽), "surprised"(달리기 때 놀란 윗몸)}
func show_motion(look: String, p: Dictionary) -> void:
	breed = look
	var k := KittenMotion.px()
	var stretch: Vector2 = KittenMotion.AIR_STRETCH.get(p.kind.trim_suffix("_b"), Vector2.ONE)
	scale = Vector2(p.get("facing", 1.0) * k * stretch.x * p.get("widen", 1.0), k * p.get("squash", 1.0) * stretch.y)
	_spin.position = Vector2(0.0, -CENTER / k)
	_art.position = Vector2(0.0, CENTER / k)
	_spin.rotation = p.get("tilt", 0.0)
	var art := textures(look)
	var kind: String = p.kind
	_a.scale = Vector2.ONE
	_upper.visible = false
	if kind == "run":
		var land_k: float = p.get("land_k", 1.0)
		if land_k < LAND_FRAME:
			kind = "land"
			_a.scale.y = lerpf(1.0, art.land_fix, land_k / LAND_FRAME)  # 발끝 축 (스프라이트 원점 = 발끝)
		else:
			var f := KittenMotion.a_frame(p.dist, look)
			kind = "run_%d" % f
			if p.get("surprised", false):
				_upper.texture = art.upper
				_upper.position.y = KittenMotionData.BOB[f]
				_upper.visible = true
	elif kind == "stand":
		kind = "land"  # 그냥 선 그림이 따로 없어 네 발로 선 착지 그림
	frame_name = kind
	_a.texture = art.tex[kind]
