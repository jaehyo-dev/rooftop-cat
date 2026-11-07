class_name BuildingLayout
extends RefCounted
## 옥상 하나에 건물을 어떻게 입히고 소품을 어디에 놓을지 정한다 (그림·화면과 분리, 옥상 왼쪽 x가 시드라 항상 같은 모습).
## 건물 = 왼쪽 캡 + 가운데 조각 여러 개(옥상 폭에 맞춰 고르고 가로로 살짝 늘임) + 오른쪽 캡.

## 지붕 턱이 옥상 양옆으로 튀어나오는 길이 (그림 픽셀)
const OVERHANG := 9.0
## 가운데 조각을 늘이는 비율 허용 범위 (이 안에서 가장 덜 늘어나는 조합을 고름)
const STRETCH_MIN := 0.85
const STRETCH_MAX := 1.2
const TRIES := 16

## 소품을 놓을 때 옥상 양 끝에서 비워 두는 거리 (빨래줄 기둥과 겹치지 않게), 소품 사이 최소 거리
const PROP_EDGE := 110.0
const PROP_GAP := 190.0
## 소품 종류와 나올 비중 (난간·화분은 장애물로 보이지 않게 드물게)
const PROP_WEIGHTS := {"chimney": 3, "tank": 2, "antenna": 3, "plants": 2, "railing": 1, "aircon": 2}


## 옥상 [left, right]의 건물 계획. styles = [{"left": 폭, "right": 폭, "mids": [폭...]}, ...] (그림 픽셀)
## 돌려주는 값: {"style": 건물 번호, "mids": 가운데 조각 번호들, "stretch": 가운데 조각에 곱할 가로 배율}
static func plan(roof_left: float, roof_right: float, styles: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(int(roof_left))
	var style_index := rng.randi_range(0, styles.size() - 1)
	var style: Dictionary = styles[style_index]
	var mids: Array = style.mids
	var avail: float = (roof_right - roof_left) + 2.0 * OVERHANG - style.left - style.right
	var best: Dictionary = {}
	for i in TRIES:
		var picks: Array[int] = []
		var total := 0.0
		# 조각을 하나씩 붙이다가 모자라지 않을 만큼 되면 멈춤 (바로 앞과 같은 조각은 피함)
		while total < avail * STRETCH_MIN or picks.is_empty():
			var pick := rng.randi_range(0, mids.size() - 1)
			if mids.size() > 1 and not picks.is_empty() and pick == picks[-1]:
				pick = (pick + 1 + rng.randi_range(0, mids.size() - 2)) % mids.size()
			picks.append(pick)
			total += mids[pick]
		var stretch: float = avail / total
		if best.is_empty() or absf(stretch - 1.0) < absf(best.stretch - 1.0):
			best = {"style": style_index, "mids": picks, "stretch": stretch}
		if stretch >= STRETCH_MIN and stretch <= STRETCH_MAX and absf(stretch - 1.0) < 0.06:
			break
	return best


## 옥상 위 소품 (판정 없는 장식). [{"kind": 이름, "x": 옥상 안 x}, ...] 왼쪽부터
static func props(roof_left: float, roof_right: float) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(int(roof_left)) ^ 0x5bd1e995
	var result: Array[Dictionary] = []
	var room := roof_right - roof_left - 2.0 * PROP_EDGE
	if room <= 0.0:
		return result
	var count := mini(rng.randi_range(0, 2), 1 + int(room / PROP_GAP))
	for i in count:
		for attempt in 8:
			var x := roof_left + PROP_EDGE + rng.randf() * room
			var free := true
			for other in result:
				free = free and absf(other.x - x) >= PROP_GAP
			if free:
				result.append({"kind": _pick_kind(rng), "x": x})
				break
	result.sort_custom(func(a, b): return a.x < b.x)
	return result


static func _pick_kind(rng: RandomNumberGenerator) -> String:
	var total := 0
	for weight in PROP_WEIGHTS.values():
		total += weight
	var roll := rng.randi_range(0, total - 1)
	for kind in PROP_WEIGHTS:
		roll -= PROP_WEIGHTS[kind]
		if roll < 0:
			return kind
	return "chimney"
