class_name SaveData
extends RefCounted
## 기기 저장 (화면과 분리된 로직, review/v0.7.0/PLAN.md 2번). 웹에서는 user://가 브라우저 저장소(IndexedDB)에 저장된다.
## 같은 주소의 이전 버전(versions/v0.6.0 등)이 같은 save.cfg를 계속 쓰므로 예전 키는 건드리지 않고 새 키만 덧붙인다:
## [record] best_score는 v0.6.0 이전 버전 전용(10점 기준)이라 읽지도 쓰지도 않고, v0.7.0 최고 점수는 best_score2.
## shortcut: 이전 버전 탭과 v0.7.0 탭을 동시에 열면 나중에 저장한 쪽이 덮는다. 한 사람용이라 감수 (여러 기기 동기화가 생기면 다시 봄)
## 깨진 파일: 원본을 .broken으로 복사해 두고 .tmp를 읽는다. 둘 다 안 되면 0에서 시작 (0으로 원본을 덮어쓰지 않음)

const DEFAULT_PATH := "user://save.cfg"
const VERSION := 2  # 기록용. 이전 버전이 1로 되돌려도 상관없게 판단에 쓰지 않는다
## 칸 → 키 → 기본값. 읽을 때 기본값과 타입이 다르면 기본값으로 본다
const DEFAULTS := {
	"record": {"best_distance": 0, "best_score2": 0},
	"wallet": {"fish": 0},
	"upgrades": {"dash": 0, "yarn": 0, "combo": 0, "gold": 0, "cookie": 0, "fish": 0},
	"boosters": {"dash_start": 0, "bell_start": 0, "fish_bonus": 0},
	# 미션·등급 자리 (2b에서 채움)
	"missions": {"day": "", "week": "", "daily": [], "weekly": [], "prev_daily": [], "prev_weekly": [],
			"swaps_today": 0, "week_daily_done": 0, "week_full_days": 0},
	"rank": {"level": 1, "xp": 0},
	"stats": {"runs": 0, "fish_total": 0},  # fish_total = 배수 전 번 생선 합 (가격 다시 맞추기용)
}

var path: String
## 칸 → 키 → 값 (DEFAULTS와 같은 모양)
var data := {}
## 저장에 best_score2가 없었음 = v0.7.0 처음 켬, 최고 점수를 새로 시작 (2c 결과 카드 안내 한 번)
var score_reset := false
var _file := ConfigFile.new()  # 읽은 파일 그대로 (모르는 키·예전 키를 지우지 않고 다시 쓰려고)


## 저장을 읽는다. 없으면 기본값
static func open(save_path: String = DEFAULT_PATH) -> SaveData:
	var save := SaveData.new()
	save.path = save_path
	save._read()
	return save


func _read() -> void:
	var tmp := path + ".tmp"
	var loaded := false
	if FileAccess.file_exists(path):
		# 글이 엉망이어도 칸이 없으면 Godot는 OK로 읽는다: 칸이 하나도 없으면 깨진 것으로 본다 (모든 버전이 [save] 등을 씀)
		loaded = _file.load(path) == OK and not _file.get_sections().is_empty()
		if not loaded:
			# 깨진 원본은 지우지 않고 옆에 남긴다
			DirAccess.copy_absolute(path, path + ".broken")
			push_warning("저장 파일이 깨져 %s.broken으로 남겼습니다" % path)
	if not loaded and FileAccess.file_exists(tmp):
		_file = ConfigFile.new()
		loaded = _file.load(tmp) == OK  # 쓰다가 꺼졌거나 원본이 깨졌으면 새로 쓰던 것
	if not loaded:
		_file = ConfigFile.new()
	score_reset = not _file.has_section_key("record", "best_score2")
	for section: String in DEFAULTS:
		data[section] = {}
		for key: String in DEFAULTS[section]:
			data[section][key] = _clean(section, key, _file.get_value(section, key, DEFAULTS[section][key]))


## 읽은 값을 검사: 타입이 다르면 기본값, 정수는 0 이상 (강화 0~10, 부스터 0~99, 등급 1 이상)
static func _clean(section: String, key: String, value: Variant) -> Variant:
	var fallback: Variant = DEFAULTS[section][key]
	if typeof(value) != typeof(fallback):
		value = fallback
	if value is Array:
		return value.duplicate(true)  # 기본값 상수 배열은 읽기 전용이라 복사
	if value is int:
		match section:
			"upgrades":
				return clampi(value, 0, Balance.UPGRADE_MAX)
			"boosters":
				return clampi(value, 0, Balance.BOOSTER_MAX)
			"rank":
				return maxi(value, 1 if key == "level" else 0)
		return maxi(value, 0)
	return value


## 저장한다. 데스크톱은 .tmp에 쓰고 이름을 바꿔 덮는다 (쓰다가 꺼져도 이전 파일이 남음).
## 웹은 바로 쓴다: 브라우저 저장소에 옮기는 일이 파일을 닫을 때 일어나 이름 바꾸기가 옮겨지는지 보장이 없음
func save() -> bool:
	_file.set_value("save", "version", VERSION)
	for section: String in data:
		for key: String in data[section]:
			_file.set_value(section, key, data[section][key])
	if OS.has_feature("web"):
		return _check(_file.save(path))
	var tmp := path + ".tmp"
	if not _check(_file.save(tmp)):
		return false
	return _check(DirAccess.rename_absolute(tmp, path))


func _check(err: Error) -> bool:
	if err != OK:
		push_warning("저장하지 못했습니다: %s (%s)" % [path, error_string(err)])
	return err == OK


# --- 기록·지갑 ---

func fish() -> int:
	return data.wallet.fish


func best_score() -> int:
	return data.record.best_score2


func best_distance() -> int:
	return data.record.best_distance


## 한 판이 끝남: 기록·생선·통계를 반영하고 저장한다. fish_bonus = 생선 +50% 부스터를 켠 판 (지갑에만 더함)
## 돌려줌: new_best(최고 점수 갱신), earned(지갑에 더한 생선), total(더한 뒤 지갑)
func finish_run(meters: int, score: int, run_fish: int, fish_bonus: bool = false) -> Dictionary:
	var new_best: bool = score > data.record.best_score2
	data.record.best_score2 = maxi(data.record.best_score2, score)
	data.record.best_distance = maxi(data.record.best_distance, meters)
	var earned := maxi(run_fish, 0)
	if fish_bonus:
		earned = ceili(earned * Balance.FISH_BONUS_MULT)
	data.wallet.fish += earned
	data.stats.runs += 1
	data.stats.fish_total += maxi(run_fish, 0)
	save()
	return {"new_best": new_best, "earned": earned, "total": data.wallet.fish}


# --- 상점 ---

func upgrade_level(kind: String) -> int:
	return data.upgrades[kind]


## 다음 단계 값 (최대 단계면 -1)
func upgrade_price(kind: String) -> int:
	var lv := upgrade_level(kind)
	return -1 if lv >= Balance.UPGRADE_MAX else Balance.UPGRADE_PRICES[lv]


## 강화 한 단계 사기. 돌려줌: "" = 샀음, "max" = 이미 최대, "money" = 생선 부족
func buy_upgrade(kind: String) -> String:
	var price := upgrade_price(kind)
	if price < 0:
		return "max"
	if price > fish():
		return "money"
	data.wallet.fish -= price
	data.upgrades[kind] += 1
	save()
	return ""


func booster_count(kind: String) -> int:
	return data.boosters[kind]


## 부스터 하나 사기. 돌려줌: "" = 샀음, "max" = 이미 BOOSTER_MAX개, "money" = 생선 부족
func buy_booster(kind: String) -> String:
	var price: int = Balance.BOOSTER_PRICES[kind]
	if booster_count(kind) >= Balance.BOOSTER_MAX:
		return "max"
	if price > fish():
		return "money"
	data.wallet.fish -= price
	data.boosters[kind] += 1
	save()
	return ""


## 판 시작: 켠 부스터 중 가진 것을 1개씩 줄이고 저장한 뒤, 이번 판 Perks를 돌려준다 (가진 게 0개인 것은 빠짐)
## 판 중간에 창을 닫으면 부스터만 잃는다 (되돌리기 꼼수 방지, PLAN 2-2)
func start_run(selected: Array) -> Perks:
	var used: Array = []
	for kind: String in Balance.BOOSTER_PRICES:
		if selected.has(kind) and booster_count(kind) > 0:
			data.boosters[kind] -= 1
			used.append(kind)
	if not used.is_empty():
		save()
	return Perks.new(data.upgrades, used)
