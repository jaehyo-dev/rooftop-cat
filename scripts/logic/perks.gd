class_name Perks
extends RefCounted
## 강화 단계 6개 + 이번 판에 켠 부스터를 받아 판에 쓸 값을 낸다 (화면과 분리된 로직, review/v0.7.0/PLAN.md 3-1).
## Perks.new()(전부 0단계, 부스터 없음)는 v0.6.0 판과 같은 값이다 (생선 점수만 5점).

## 강화 종류 → 단계 (0~UPGRADE_MAX)
var levels := {}
## 이번 판에 켠 부스터 종류 ("dash_start", "bell_start", "fish_bonus")
var boosters: Array = []


func _init(upgrade_levels: Dictionary = {}, booster_list: Array = []) -> void:
	levels = upgrade_levels.duplicate()
	boosters = booster_list.duplicate()


## 강화 6개를 모두 같은 단계로 (봇·테스트용)
static func all(upgrade_level: int, booster_list: Array = []) -> Perks:
	var lv := {}
	for kind: String in Balance.UPGRADES:
		lv[kind] = upgrade_level
	return Perks.new(lv, booster_list)


func level(kind: String) -> int:
	return clampi(int(levels.get(kind, 0)), 0, Balance.UPGRADE_MAX)


## 단계 값: 0단계 ~ 10단계 사이를 직선으로
func value(kind: String) -> float:
	var row: Array = Balance.UPGRADES[kind]
	return lerpf(row[0], row[1], float(level(kind)) / Balance.UPGRADE_MAX)


func has_booster(kind: String) -> bool:
	return boosters.has(kind)


func dash_time() -> float:
	return value("dash")


func magnet_time() -> float:
	return Balance.MAGNET_TIME * value("yarn")


func magnet_radius() -> float:
	return Balance.MAGNET_RADIUS * value("yarn")


## 콤보 배수가 하나 오르는 생선 수
func combo_step() -> int:
	return roundi(value("combo"))


func gold_points() -> int:
	return roundi(value("gold"))


func cookie_gap() -> float:
	return value("cookie")


func fish_points() -> int:
	return roundi(value("fish"))


## 생선 그림 번호 0~3 (FISH_LOOK_LEVELS 중 이미 이른 단계 수 - 1)
func fish_look() -> int:
	var look := 0
	for i in Balance.FISH_LOOK_LEVELS.size():
		if level("fish") >= Balance.FISH_LOOK_LEVELS[i]:
			look = i
	return look
