extends TestCase
## 저장(SaveData): 새 키 덧붙이기, 이전 버전과 같은 파일 같이 쓰기, 깨진 파일 보존, 상점 사기 (review/v0.7.0/PLAN.md 2번).

const PATH := "user://test_save.cfg"


func _clear() -> void:
	for file in [PATH, PATH + ".tmp", PATH + ".broken"]:
		DirAccess.remove_absolute(file)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## v0.6.0 BestRecord._save_int와 똑같이 쓴다: 있던 내용을 읽고 version=1로 되돌린 뒤 키 하나를 쓴다
func _v060_write(section: String, key: String, value: int) -> void:
	var file := ConfigFile.new()
	file.load(PATH)
	file.set_value("save", "version", 1)
	file.set_value(section, key, value)
	file.save(PATH)


func test_없으면_기본값으로_시작한다() -> void:
	_clear()
	var save := SaveData.open(PATH)
	assert_eq(save.fish(), 0)
	assert_eq(save.best_score(), 0)
	assert_eq(save.upgrade_level("dash"), 0)
	assert_eq(save.booster_count("fish_bonus"), 0)
	assert_eq(save.data.rank, {"level": 1, "xp": 0})
	assert_eq(save.data.missions.daily, [])
	assert_true(save.score_reset, "최고 점수 새로 시작")
	save.data.missions.daily.append({"id": "d_x5"})  # 기본값 상수를 바꾸지 않음
	assert_eq(SaveData.open(PATH).data.missions.daily, [], "새로 읽어도 빈 목록")
	assert_false(FileAccess.file_exists(PATH), "읽기만으로는 파일을 만들지 않음")


func test_한_판_결과를_저장하고_다시_읽는다() -> void:
	_clear()
	var save := SaveData.open(PATH)
	var first := save.finish_run(120, 3000, 40)
	assert_eq(first, {"new_best": true, "earned": 40, "total": 40})
	assert_false(save.finish_run(80, 2000, 10).new_best, "낮은 점수")
	assert_false(save.finish_run(90, 3000, 0).new_best, "같은 점수도 새 기록 아님")
	var again := SaveData.open(PATH)
	assert_eq(again.best_score(), 3000)
	assert_eq(again.best_distance(), 120, "거리 기록은 큰 쪽")
	assert_eq(again.fish(), 50)
	assert_eq(again.data.stats, {"runs": 3, "fish_total": 50, "recent": [120, 80, 90]}, "최근 판 거리도 (미션 익숙함 판단)")
	assert_false(again.score_reset)
	assert_false(FileAccess.file_exists(PATH + ".tmp"), "임시 파일이 남지 않음")
	_clear()


func test_생선_50퍼센트는_지갑에만_올림해서_더한다() -> void:
	_clear()
	var save := SaveData.open(PATH)
	var run := save.finish_run(10, 100, 7, true)
	assert_eq(run.earned, 11, "7 x 1.5 = 10.5 → 11")
	assert_eq(save.fish(), 11)
	assert_eq(save.data.stats.fish_total, 7, "통계는 배수 전")
	assert_eq(save.finish_run(10, 100, 0, true).earned, 0)
	_clear()


func test_v060과_같은_파일을_같이_써도_서로_지우지_않는다() -> void:
	_clear()
	# v0.6.0으로 한 판: 거리·10점 기준 점수·생선
	_v060_write("record", "best_distance", 500)
	_v060_write("record", "best_score", 90000)
	_v060_write("wallet", "fish", 2000)
	var save := SaveData.open(PATH)
	assert_eq(save.fish(), 2000, "모은 생선은 그대로")
	assert_eq(save.best_score(), 0, "예전 점수는 읽지 않음 (5점 기준으로 새로)")
	assert_true(save.score_reset)
	assert_eq(save.best_distance(), 500)
	assert_eq(save.buy_upgrade("dash"), "")
	save.data.boosters.bell_start = 2
	save.data.missions.day = "2026-11-11"
	save.data.missions.daily = [{"id": "d_dist_1", "target": 300, "progress": 120, "done": false}]
	save.finish_run(300, 7000, 100)
	var file := ConfigFile.new()
	file.load(PATH)
	assert_eq(file.get_value("record", "best_score"), 90000, "v0.6.0 점수는 건드리지 않음")
	# 다시 v0.6.0으로 한 판 (version을 1로 되돌리고 예전 키만 씀)
	_v060_write("record", "best_score", 95000)
	_v060_write("wallet", "fish", 2000 - 300 + 100 + 80)
	var after := SaveData.open(PATH)
	assert_eq(after.upgrade_level("dash"), 1, "강화 그대로")
	assert_eq(after.booster_count("bell_start"), 2, "부스터 그대로")
	assert_eq(after.best_score(), 7000, "best_score2 그대로")
	assert_eq(after.data.missions.daily[0].progress, 120, "미션 자리 그대로")
	assert_eq(after.data.missions.day, "2026-11-11")
	assert_eq(after.fish(), 1880, "이전 버전에서 번 생선도 들어옴")
	assert_eq(after.data.stats.runs, 1)
	_clear()


func test_깨진_파일은_broken으로_남기고_tmp를_읽는다() -> void:
	_clear()
	_write(PATH, "이건 설정 파일이 아님 [[[\n")  # Godot가 오류 없이 빈 파일로 읽는 글
	assert_eq(SaveData.open(PATH).fish(), 0)
	assert_eq(FileAccess.get_file_as_string(PATH + ".broken"), "이건 설정 파일이 아님 [[[\n", "칸이 없으면 깨진 것")
	var broken := "[wallet\nfish=1\n"  # 문법 오류
	expected_errors.append("ConfigFile parse error")
	_write(PATH, broken)
	var save := SaveData.open(PATH)
	assert_eq(save.fish(), 0, "읽을 게 없으면 0")
	assert_eq(FileAccess.get_file_as_string(PATH + ".broken"), broken, "원본을 .broken으로 남김")
	assert_eq(FileAccess.get_file_as_string(PATH), broken, "읽기만으로 덮어쓰지 않음")
	_write(PATH + ".tmp", "[wallet]\nfish=12345\n[upgrades]\nfish=4\n")
	var from_tmp := SaveData.open(PATH)
	assert_eq(from_tmp.fish(), 12345, "쓰다 만 .tmp를 읽음")
	assert_eq(from_tmp.upgrade_level("fish"), 4)
	from_tmp.save()
	assert_eq(SaveData.open(PATH).fish(), 12345, "저장하면 원래 이름으로")
	assert_false(FileAccess.file_exists(PATH + ".tmp"))
	assert_eq(FileAccess.get_file_as_string(PATH + ".broken"), broken, ".broken은 그대로")
	_clear()


func test_원본이_없고_tmp만_있으면_tmp를_읽는다() -> void:
	_clear()
	_write(PATH + ".tmp", "[wallet]\nfish=77\n")
	assert_eq(SaveData.open(PATH).fish(), 77)
	_clear()


func test_이상한_값은_기본값이나_범위_안으로() -> void:
	_clear()
	_write(PATH, "[wallet]\nfish=\"많이\"\n[record]\nbest_distance=-5\n[upgrades]\ndash=15\nyarn=-1\n[boosters]\nbell_start=500\n[rank]\nlevel=0\n[missions]\ndaily=3\n")
	var save := SaveData.open(PATH)
	assert_eq(save.fish(), 0)
	assert_eq(save.best_distance(), 0)
	assert_eq(save.upgrade_level("dash"), Balance.UPGRADE_MAX)
	assert_eq(save.upgrade_level("yarn"), 0)
	assert_eq(save.booster_count("bell_start"), Balance.BOOSTER_MAX)
	assert_eq(save.data.rank.level, 1)
	assert_eq(save.data.missions.daily, [])
	_clear()


func test_강화_사기는_돈_부족과_최대_단계를_막는다() -> void:
	_clear()
	var save := SaveData.open(PATH)
	assert_eq(save.upgrade_price("combo"), 300)
	assert_eq(save.buy_upgrade("combo"), "money", "생선 0")
	save.data.wallet.fish = 33700 + 299
	for lv in Balance.UPGRADE_MAX:
		assert_eq(save.upgrade_price("combo"), Balance.UPGRADE_PRICES[lv])
		assert_eq(save.buy_upgrade("combo"), "", "%d단계 사기" % (lv + 1))
	assert_eq(save.upgrade_level("combo"), 10)
	assert_eq(save.fish(), 299, "가격 합만큼 줄어듦")
	assert_eq(save.upgrade_price("combo"), -1)
	assert_eq(save.buy_upgrade("combo"), "max")
	assert_eq(save.fish(), 299, "최대면 돈을 받지 않음")
	assert_eq(save.buy_upgrade("dash"), "money", "300에 1 모자람")
	assert_eq(save.upgrade_level("dash"), 0)
	assert_eq(SaveData.open(PATH).upgrade_level("combo"), 10, "사면 바로 저장")
	_clear()


func test_부스터는_사서_여러_개_같이_켜고_판_시작에_줄어든다() -> void:
	_clear()
	var save := SaveData.open(PATH)
	save.data.wallet.fish = 2000
	assert_eq(save.buy_booster("fish_bonus"), "")
	assert_eq(save.buy_booster("dash_start"), "")
	assert_eq(save.buy_booster("fish_bonus"), "money", "700 남아 800 못 삼")
	assert_eq(save.fish(), 700)
	save.data.boosters.bell_start = Balance.BOOSTER_MAX
	assert_eq(save.buy_booster("bell_start"), "max")
	save.data.upgrades.yarn = 3
	var perks := save.start_run(["dash_start", "fish_bonus"])
	assert_eq(perks.boosters, ["dash_start", "fish_bonus"], "켠 것 둘 다")
	assert_eq(perks.level("yarn"), 3, "강화 단계도 담김")
	assert_eq(save.booster_count("dash_start"), 0)
	assert_eq(save.booster_count("fish_bonus"), 0)
	assert_eq(SaveData.open(PATH).booster_count("fish_bonus"), 0, "판 시작에 저장 (창을 닫아도 돌아오지 않음)")
	var none := save.start_run(["dash_start", "bell_start"])
	assert_eq(none.boosters, ["bell_start"], "0개인 부스터는 빠짐")
	assert_eq(save.booster_count("bell_start"), Balance.BOOSTER_MAX - 1)
	save.data.upgrades.yarn = 5
	assert_eq(perks.level("yarn"), 3, "판 중에 사도 이번 판 값은 그대로")
	_clear()
