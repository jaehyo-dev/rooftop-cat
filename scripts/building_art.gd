class_name BuildingArt
extends RefCounted
## 주택가 건물·소품 그림 (assets/sprites/buildings/, tools/cut_buildings.py로 시안에서 잘라 낸 것).
## 건물 조각과 소품은 모두 맨 윗줄이 지붕 턱 윗면(= 옥상 충돌선)이다. 그림은 이미 게임 크기라 1:1로 그린다.

## 아래로 이어지는 벽 색 (건물 그림 맨 아래 벽의 가운데값)
const STYLE_NAMES := ["brick", "villa", "tile"]
const FILL_COLORS := [Color("#fcc581"), Color("#fdecbf"), Color("#dce5d8")]
## 건물 그림이 끝나는 아래쪽을 채움 색으로 부드럽게 이어 주는 길이
const FADE := 28.0
## 소품이 지붕 턱에 살짝 박히는 깊이 (떠 보이지 않게)
const PROP_SINK := 3.0

static var _styles: Array = []   # [{"left": Texture, "right": Texture, "mids": [Texture...]}]
static var _props: Dictionary = {}  # 이름 → Texture


static func _load() -> void:
	if not _styles.is_empty():
		return
	var dir := "res://assets/sprites/buildings/"
	var mid_counts := [2, 3, 2]
	for i in STYLE_NAMES.size():
		var name: String = STYLE_NAMES[i]
		var mids: Array = []
		for m in mid_counts[i]:
			mids.append(load("%s%s_m%d.png" % [dir, name, m]))
		_styles.append({"left": load("%s%s_l.png" % [dir, name]), "right": load("%s%s_r.png" % [dir, name]), "mids": mids})
	for kind in BuildingLayout.PROP_WEIGHTS:
		_props[kind] = load("%sprop_%s.png" % [dir, kind])


## BuildingLayout.plan에 넘길 조각 폭 목록
static func widths() -> Array:
	_load()
	var result: Array = []
	for style in _styles:
		var mids: Array = []
		for tex in style.mids:
			mids.append(float(tex.get_width()))
		result.append({"left": float(style.left.get_width()), "right": float(style.right.get_width()), "mids": mids})
	return result


static func style_textures(index: int) -> Dictionary:
	_load()
	return _styles[index]


static func prop_texture(kind: String) -> Texture2D:
	_load()
	return _props[kind]
