class_name BestRecord
## 최고 기록(거리, 미터)을 기기에 저장하고 불러온다.
## 웹에서는 user://가 브라우저 저장소(IndexedDB)에 저장된다.
## 저장 파일이 없거나 깨졌으면 0으로 본다.

const DEFAULT_PATH := "user://save.cfg"
## 저장 형식 번호. 나중에 저장 내용이 바뀌면 올려서 이전 파일을 옮겨 읽는다
const SAVE_VERSION := 1


static func load_best(path: String = DEFAULT_PATH) -> int:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return 0
	var value: Variant = file.get_value("record", "best_distance", 0)
	if typeof(value) != TYPE_INT or value < 0:
		return 0
	return value


## 이번 기록이 최고 기록보다 높으면 저장한다. 새 최고 기록이면 true
static func submit(meters: int, path: String = DEFAULT_PATH) -> bool:
	if meters <= load_best(path):
		return false
	var file := ConfigFile.new()
	file.load(path)  # 다른 값이 생겨도 지우지 않게 있던 내용을 먼저 읽는다 (없으면 빈 파일)
	file.set_value("save", "version", SAVE_VERSION)
	file.set_value("record", "best_distance", meters)
	if file.save(path) != OK:
		push_warning("최고 기록을 저장하지 못했습니다: " + path)
	return true
