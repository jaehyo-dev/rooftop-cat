class_name BestRecord
## 최고 기록(거리, 미터), 최고 점수, 모은 생선 수(강화 상점의 돈)를 기기에 저장하고 불러온다.
## 웹에서는 user://가 브라우저 저장소(IndexedDB)에 저장된다.
## 저장 파일이 없거나 깨졌으면 0으로 본다.

const DEFAULT_PATH := "user://save.cfg"
## 저장 형식 번호. 나중에 저장 내용이 바뀌면 올려서 이전 파일을 옮겨 읽는다
const SAVE_VERSION := 1


static func load_best(path: String = DEFAULT_PATH) -> int:
	return _load_int("record", "best_distance", path)


## 최고 점수 (저장 파일에 없으면 0: v0.6.0 전 저장도 그대로 읽힌다)
static func load_best_score(path: String = DEFAULT_PATH) -> int:
	return _load_int("record", "best_score", path)


## 이번 점수가 최고 점수보다 높으면 저장한다. 새 최고 점수면 true
static func submit_score(score: int, path: String = DEFAULT_PATH) -> bool:
	if score <= load_best_score(path):
		return false
	_save_int("record", "best_score", score, path)
	return true


## 지금까지 모은 생선 수
static func load_fish(path: String = DEFAULT_PATH) -> int:
	return _load_int("wallet", "fish", path)


## 이번 판에 먹은 생선을 더해 저장하고, 더한 뒤의 생선 수를 돌려준다
static func add_fish(count: int, path: String = DEFAULT_PATH) -> int:
	var total := load_fish(path) + maxi(0, count)
	if count > 0:
		_save_int("wallet", "fish", total, path)
	return total


static func _load_int(section: String, key: String, path: String) -> int:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return 0
	var value: Variant = file.get_value(section, key, 0)
	if typeof(value) != TYPE_INT or value < 0:
		return 0
	return value


static func _save_int(section: String, key: String, value: int, path: String) -> void:
	var file := ConfigFile.new()
	file.load(path)  # 다른 값이 생겨도 지우지 않게 있던 내용을 먼저 읽는다 (없으면 빈 파일)
	file.set_value("save", "version", SAVE_VERSION)
	file.set_value(section, key, value)
	if file.save(path) != OK:
		push_warning("저장하지 못했습니다: " + path)


## 이번 기록이 최고 기록보다 높으면 저장한다. 새 최고 기록이면 true
static func submit(meters: int, path: String = DEFAULT_PATH) -> bool:
	if meters <= load_best(path):
		return false
	_save_int("record", "best_distance", meters, path)
	return true
