class_name ItemPlacer
extends RefCounted
## 새 쉼 옥상이 생길 때마다 종이상자와 트램펄린·빨래줄 생선을 놓는다 (땅 줄과 틈 호는 FishRoad, 화면과 분리된 로직).
## 아이템 하나 = {"kind": "fish", "box", 또는 ItemSlots의 종류, "x": 가로 위치, "y": 아이템 가운데 높이(아래에서 위로)}
## 옥상과 다른 난수를 써서, 아이템이 생겨도 같은 시드의 옥상 모양은 그대로다. 같은 시드면 항상 같은 아이템이 나온다.

var _rng := RandomNumberGenerator.new()
var _next_box := 0.0  # 이 시각(초) 뒤 첫 일반 옥상에 종이상자를 놓는다


func _init(seed_value: int) -> void:
	_rng.seed = hash(seed_value) ^ 0x5f3759df
	_next_box = _rng.randf_range(Balance.BOX_EVERY_MIN, Balance.BOX_EVERY_MAX)


## prev 다음에 roof가 생겼을 때 놓을 아이템들 (가로 위치 순서). now = 지금 시각 (상자 간격)
func items_for(prev: Dictionary, roof: Dictionary, now: float) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if roof.has("line"):
		# 빨래줄 틈: 줄 위 높은 곳에 생선 줄 (더 높이 튕겨야 먹음)
		items.append_array(_line_fish(roof.line))
	if roof.has("tramp"):
		items.append_array(tramp_fish(roof.tramp))
		items.append_array(tramp_good_fish(roof.tramp, roof.top))
	if roof.get("platform", false):
		return items  # 전봇대 판: 작아서 생선 줄·상자는 놓지 않음
	if now >= _next_box:
		_next_box = now + _rng.randf_range(Balance.BOX_EVERY_MIN, Balance.BOX_EVERY_MAX) * (Balance.ITEM_LATE_MULT if now >= Balance.ITEM_LATE_TIME else 1.0)
		# 상자는 옥상 가운데, 달리다 몸에 닿는 높이 (RunnerSim이 FishRoad에 이 자리를 비워 두라고 알림)
		items.append({"kind": "box", "x": (roof.left + roof.right) * 0.5, "y": roof.top + Balance.ITEM_LIFT})
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
			items.append({"kind": "fish", "x": RunnerSim.run_in_x(tramp) + vx * t, "y": tramp.top + h + Balance.ITEM_LIFT, "bonus": true})
		t += Balance.FISH_SPACING / vx
	return items


## 트램펄린 누름 생선 길: 누름 궤적을 따라 호 길이 FISH_SPACING 간격으로 높이 튀는 큰 포물선. 퍼펙트는 다른 길로 가니 전부 보너스
static func tramp_good_fish(tramp: Dictionary, land_top: float) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var vy := RoofGenerator.line_bounce_speed(Balance.TRAMP_GOOD_HEIGHT)
	var vx: float = tramp.good_vx
	var t := Balance.FISH_SPACING / vx
	var h := vy * t - 0.5 * Balance.GRAVITY * t * t
	while h + tramp.top >= land_top:
		items.append({"kind": "fish", "x": RunnerSim.run_in_x(tramp) + vx * t, "y": tramp.top + h + Balance.ITEM_LIFT, "bonus": true})
		t += Balance.FISH_SPACING / Vector2(vx, vy - Balance.GRAVITY * t).length()
		h = vy * t - 0.5 * Balance.GRAVITY * t * t
	return items


## 빨래줄 위 높은 곳 생선 줄: 줄 양 끝에서 조금 안쪽부터 일정 간격으로
func _line_fish(line: Dictionary) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var x: float = line.left + Balance.FISH_SPACING * 1.5
	while x <= line.right - Balance.FISH_SPACING * 1.5:
		items.append({"kind": "fish", "x": x, "y": line.top + Balance.LINE_FISH_HEIGHT})
		x += Balance.FISH_SPACING
	return items
