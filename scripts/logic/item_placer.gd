class_name ItemPlacer
extends RefCounted
## 새 옥상이 생길 때마다 그 옥상과 앞 틈에 생선·종이상자를 놓는다 (화면과 분리된 로직).
## 아이템 하나 = {"kind": "fish" 또는 "box", "x": 가로 위치, "y": 아이템 가운데 높이(아래에서 위로)}
## 옥상과 다른 난수를 써서, 아이템이 생겨도 같은 시드의 옥상 모양은 그대로다. 같은 시드면 항상 같은 아이템이 나온다.

var _rng := RandomNumberGenerator.new()
var _roofs_until_box := 0  # 이만큼 옥상을 더 지나면 종이상자를 놓는다


func _init(seed_value: int) -> void:
	_rng.seed = hash(seed_value) ^ 0x5f3759df
	_roofs_until_box = _rng.randi_range(Balance.BOX_EVERY_MIN, Balance.BOX_EVERY_MAX)


## prev 다음에 roof가 생겼을 때 놓을 아이템들 (가로 위치 순서)
func items_for(prev: Dictionary, roof: Dictionary) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if _rng.randf() < Balance.FISH_ARC_CHANCE and not roof.has("line") and not roof.has("tramp"):
		items.append_array(_fish_arc(prev, roof))
	if roof.has("line"):
		# 빨래줄 틈: 줄 위 높은 곳에 생선 줄 (더 높이 튕겨야 먹음)
		items.append_array(_line_fish(roof.line))
	if roof.has("tramp"):
		items.append_array(tramp_fish(roof.tramp))
	if roof.get("platform", false):
		return items  # 전봇대 판: 작아서 생선 줄·상자는 놓지 않음
	_roofs_until_box -= 1
	if _roofs_until_box <= 0:
		_roofs_until_box = _rng.randi_range(Balance.BOX_EVERY_MIN, Balance.BOX_EVERY_MAX)
		# 상자는 옥상 가운데, 달리다 몸에 닿는 높이 (상자가 있는 옥상에는 생선 줄을 놓지 않아 겹치지 않음)
		items.append({"kind": "box", "x": (roof.left + roof.right) * 0.5, "y": roof.top + Balance.ITEM_LIFT})
	elif _rng.randf() < Balance.FISH_ROW_CHANCE:
		items.append_array(_fish_row(roof))
	return items


## 틈 위 생선 무지개: 앞 옥상 끝에서 다음 옥상 시작까지 포물선으로, 점프하면 먹는다
func _fish_arc(prev: Dictionary, roof: Dictionary) -> Array[Dictionary]:
	var start: float = prev.right - Balance.FISH_SPACING
	var end: float = roof.left + Balance.FISH_SPACING
	var count := maxi(3, int((end - start) / Balance.FISH_SPACING) + 1)
	var items: Array[Dictionary] = []
	for i in count:
		var t := float(i) / float(count - 1)
		var base := lerpf(prev.top, roof.top, t) + Balance.ITEM_LIFT
		items.append({"kind": "fish", "x": lerpf(start, end, t), "y": base + Balance.FISH_ARC_HEIGHT * 4.0 * t * (1.0 - t)})
	return items


## 옥상 위 생선 줄: 달리기만 해도 먹는 높이에 나란히
func _fish_row(roof: Dictionary) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var count := _rng.randi_range(Balance.FISH_ROW_MIN, Balance.FISH_ROW_MAX)
	var x: float = roof.left + Balance.FISH_SPACING * 2.0
	for i in count:
		if x > roof.right - Balance.FISH_SPACING:
			break
		items.append({"kind": "fish", "x": x, "y": roof.top + Balance.ITEM_LIFT})
		x += Balance.FISH_SPACING
	return items


## 트램펄린 퍼펙트 생선 길: 달려 들어가 닿는 순간(몸 가운데 = RunnerSim.run_in_x) 퍼펙트로 튕긴 궤적을 따라 FISH_SPACING 간격으로,
## 누름 꼭대기보다 TRAMP_FISH_ABOVE_GOOD 이상 높은 구간에만 (누름으로는 못 먹음)
static func tramp_fish(tramp: Dictionary) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var vy := RoofGenerator.line_bounce_speed(Balance.TRAMP_PERFECT_HEIGHT)
	var vx: float = tramp.perfect_vx
	var t := 0.0
	while t <= 2.0 * vy / Balance.GRAVITY:
		var h := vy * t - 0.5 * Balance.GRAVITY * t * t
		if h >= Balance.TRAMP_GOOD_HEIGHT + Balance.TRAMP_FISH_ABOVE_GOOD:
			items.append({"kind": "fish", "x": RunnerSim.run_in_x(tramp) + vx * t, "y": tramp.top + h + Balance.ITEM_LIFT})
		t += Balance.FISH_SPACING / vx
	return items


## 빨래줄 위 높은 곳 생선 줄: 줄 양 끝에서 조금 안쪽부터 일정 간격으로
func _line_fish(line: Dictionary) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var x: float = line.left + Balance.FISH_SPACING * 1.5
	while x <= line.right - Balance.FISH_SPACING * 1.5:
		items.append({"kind": "fish", "x": x, "y": line.top + Balance.LINE_FISH_HEIGHT})
		x += Balance.FISH_SPACING
	return items
