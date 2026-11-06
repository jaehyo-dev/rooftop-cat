class_name RoofGenerator
extends RefCounted
## 옥상을 하나씩 이어서 만든다. 옥상 사이 간격은 항상 최대 점프로 넘을 수 있는 범위 안에 있다.
## 옥상 하나 = {"left": 왼쪽 x, "right": 오른쪽 x, "top": 높이(아래에서 위로)}
## 같은 시드면 항상 같은 옥상이 나온다.

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_rng.seed = seed_value


## 시작 옥상 (고양이가 서 있는 넓은 옥상)
static func first_roof(left: float) -> Dictionary:
	return {"left": left, "right": left + Balance.ROOF_FIRST_WIDTH, "top": (Balance.ROOF_TOP_MIN + Balance.ROOF_TOP_MAX) * 0.5}


## prev 다음 옥상. speed는 지금 달리는 속도 (빠를수록 간격이 넓어질 수 있음)
func next_roof(prev: Dictionary, speed: float) -> Dictionary:
	var top := clampf(prev.top + _rng.randf_range(-Balance.ROOF_TOP_STEP, Balance.ROOF_TOP_STEP),
			Balance.ROOF_TOP_MIN, Balance.ROOF_TOP_MAX)
	var gap := _rng.randf_range(Balance.ROOF_GAP_MIN, max_gap(speed, top - prev.top))
	var left: float = prev.right + gap
	return {"left": left, "right": left + _rng.randf_range(Balance.ROOF_WIDTH_MIN, Balance.ROOF_WIDTH_MAX), "top": top}


## 높이 차 rise일 때 허용하는 최대 간격 (최대 점프 거리 x 여유, 최소 간격보다 작아지지 않음)
static func max_gap(speed: float, rise: float) -> float:
	return maxf(Balance.ROOF_GAP_MIN, JumpModel.max_reach(speed, rise) * Balance.ROOF_GAP_SAFETY)
