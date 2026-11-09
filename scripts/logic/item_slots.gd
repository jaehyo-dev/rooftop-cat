class_name ItemSlots
extends RefCounted
## 아이템 자리(손으로 짠 구간의 "slot")에 무엇을 놓을지 고른다 (화면과 분리된 로직, PLAN 3번).
## 우선순위와 간격은 Balance.SLOT_ITEMS. 시간이 된 것 중 앞선 것을 놓고, 없으면 생선 한 마리 (생선 길의 빈자리를 메움).

var _rng := RandomNumberGenerator.new()
var _next := {}  # 종류 → 이 시각부터 나올 수 있음
## 지금까지 놓은 수 (보고용)
var made := {}
## 켜지 않을 종류 (밸런스 봇이 효과를 비교할 때만)
var off: Array = []


func _init(seed_value: int) -> void:
	_rng.seed = hash(seed_value) ^ 0x1b873593
	for row: Array in Balance.SLOT_ITEMS:
		_next[row[0]] = row[1]


## 자리 하나에 놓을 아이템들. slot.forced가 있으면 그 종류 (대본의 첫 질주)
func fill(slot: Dictionary, now: float, hearts: int, has_bell: bool) -> Array[Dictionary]:
	var kind: String = choose(now, hearts, has_bell)
	if slot.has("forced") and not off.has(slot.forced):
		kind = slot.forced
	if kind == "fish":
		made.fish = made.get("fish", 0) + 1
		return [{"kind": "fish", "x": slot.x, "y": slot.y, "bonus": true}] as Array[Dictionary]
	_mark(kind, now)
	return [{"kind": kind, "x": slot.x, "y": slot.y}] as Array[Dictionary]


## 시간이 된 아이템 중 우선순위가 가장 높은 종류. 없으면 "fish"
func choose(now: float, hearts: int, has_bell: bool) -> String:
	for row: Array in Balance.SLOT_ITEMS:
		var kind: String = row[0]
		if now < _next[kind] or off.has(kind):
			continue
		if (kind == "cookie" and hearts >= Balance.HEARTS_MAX) or (kind == "bell" and has_bell):
			continue
		return kind
	return "fish"


func _mark(kind: String, now: float) -> void:
	made[kind] = made.get(kind, 0) + 1
	for row: Array in Balance.SLOT_ITEMS:
		if row[0] == kind:
			_next[kind] = now + _rng.randf_range(row[2], row[3]) * (Balance.ITEM_LATE_MULT if now >= Balance.ITEM_LATE_TIME else 1.0)
