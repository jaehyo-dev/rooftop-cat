class_name StructurePlacer
extends RefCounted
## 옥상마다 구조물(빨래줄, 전봇대)을 놓을지 정한다 (화면과 분리된 로직).
## 구조물 하나 = {"kind": "line" 또는 "pole", "left": 밟는 곳 왼쪽 x, "right": 오른쪽 x, "top": 밟는 높이(아래에서 위로), "base": 옥상 높이}
## 옥상·아이템과 다른 난수를 써서 같은 시드의 옥상과 아이템은 그대로다. 같은 시드면 항상 같은 구조물이 나온다.
##
## 공정함: 빨래줄은 밟는 순간 튕기는 방향이 정해지고, 전봇대 꼭대기에 서면 끝에서 떨어진다.
## 그래서 "어디서 밟아도(기본 튕김 기준) 그 뒤에 옥상이나 다음 옥상에 내려앉는 자리"에만 놓는다.
## 더 높이 튕기는 건 일부러 누르는 사람의 선택이라 안전을 보장하지 않는다 (더 멀리 날아가 틈에 떨어질 수 있음).

const CANDIDATES := 8       # 옥상 위에서 살펴볼 자리 수
const TOLERANCE := 20.0     # 속도가 조금 변해도 안전하도록 남기는 여유 (픽셀)

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_rng.seed = hash(seed_value) ^ 0x2545f491


## roof 위에 놓을 구조물. next = roof 다음 옥상, speed = 달리는 속도. 없으면 빈 Dictionary.
## 놓을 수 없어도 난수는 똑같이 써서 뒤의 결과가 흔들리지 않는다
func structure_for(roof: Dictionary, next: Dictionary, speed: float) -> Dictionary:
	var place := _rng.randf() < Balance.STRUCTURE_CHANCE
	var kind := "line" if _rng.randf() < Balance.LINE_SHARE else "pole"
	var t := _rng.randf()
	if not place:
		return {}
	var width := Balance.LINE_WIDTH if kind == "line" else Balance.POLE_WIDTH
	var margin := Balance.LINE_MARGIN if kind == "line" else Balance.POLE_MARGIN
	var first: float = roof.left + margin
	var last: float = roof.right - margin - width
	if last < first:
		return {}  # 옥상이 좁아 못 놓음
	var height := Balance.LINE_HEIGHT if kind == "line" else Balance.POLE_HEIGHT
	var valid: Array[Dictionary] = []
	for i in CANDIDATES:
		var left := lerpf(first, last, float(i) / float(CANDIDATES - 1))
		var structure := {"kind": kind, "left": left, "right": left + width, "top": roof.top + height, "base": roof.top}
		if is_safe(structure, roof, next, speed):
			valid.append(structure)
	return {} if valid.is_empty() else valid[mini(int(t * valid.size()), valid.size() - 1)]


## 구조물이 roof 위에 있을 때, 거기서 떠난 몸이 옥상이나 next 옥상에 내려앉는지 (모든 밟는 자리에서)
static func is_safe(structure: Dictionary, roof: Dictionary, next: Dictionary, speed: float) -> bool:
	var foot := Balance.CAT_FOOT_HALF
	if structure.kind == "pole":
		# 꼭대기 끝에서 발이 떨어지는 순간부터 그냥 떨어진다
		var x: float = structure.right + foot
		return _lands(x, x, structure.top, 0.0, roof, next, speed)
	# 빨래줄: 발 범위가 줄에 걸치는 어느 자리(몸 가운데 x)에서 밟아도 튕겨 오른 뒤 안전해야 한다
	var lo: float = structure.left - foot
	var hi: float = structure.right + foot
	return _lands(lo, hi, structure.top, sqrt(2.0 * Balance.GRAVITY * Balance.LINE_BOUNCE_HEIGHT), roof, next, speed)


## 높이 top에서 위로 v0의 속도로 x_lo~x_hi에서 떠났을 때 내려앉는 자리가 전부 옥상(끝까지) 또는 다음 옥상 안인지
static func _lands(x_lo: float, x_hi: float, top: float, v0: float, roof: Dictionary, next: Dictionary, speed: float) -> bool:
	var foot := Balance.CAT_FOOT_HALF
	var t_roof := _fall_time(top, v0, roof.top)
	if t_roof >= 0.0 and x_hi + speed * t_roof <= roof.right + foot - TOLERANCE:
		return true
	var t_next := _fall_time(top, v0, next.top)
	return t_next >= 0.0 and x_lo + speed * t_next >= next.left - foot + TOLERANCE \
			and x_hi + speed * t_next <= next.right + foot - TOLERANCE


## 높이 top에서 위로 v0로 던져 올려 높이 level까지 내려올 때까지의 시간 (닿을 수 없으면 -1)
static func _fall_time(top: float, v0: float, level: float) -> float:
	var g := Balance.GRAVITY
	var disc := v0 * v0 + 2.0 * g * (top - level)
	return (v0 + sqrt(disc)) / g if disc >= 0.0 else -1.0
