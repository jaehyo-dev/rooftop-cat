extends TestCase
## 속도 곡선, 최고 기록 저장·불러오기.

const PATH := "user://test_best_record.cfg"


func test_속도는_시간에_따라_일정하게_빨라지다가_최대에서_멈춘다() -> void:
	assert_eq(SpeedCurve.speed_at(0.0), Balance.RUN_SPEED, "처음 속도")
	assert_eq(SpeedCurve.speed_at(-5.0), Balance.RUN_SPEED, "음수 시간은 0초로")
	assert_true(absf(SpeedCurve.speed_at(60.0) - (Balance.RUN_SPEED + Balance.SPEED_GAIN * 60.0)) < 0.001, "1분 뒤")
	assert_eq(SpeedCurve.speed_at(100000.0), Balance.SPEED_MAX, "최대 속도에서 멈춤")
	var prev := 0.0
	for t in range(0, 600, 5):
		var v := SpeedCurve.speed_at(float(t))
		assert_true(v >= prev, "%d초: 느려지지 않음" % t)
		prev = v


func test_옥상_생성_테스트가_최대_속도까지_덮는다() -> void:
	# 옥상 생성 테스트의 속도 목록이 최대 속도까지 덮는지 (그 테스트가 간격·너비를 확인한다)
	assert_true(Balance.SPEED_MAX <= 1000.0, "test_roofs.gd SPEEDS의 최댓값 이하")


func test_기록이_없으면_0() -> void:
	DirAccess.remove_absolute(PATH)
	assert_eq(BestRecord.load_best(PATH), 0)


func test_더_높은_기록만_저장하고_다시_불러온다() -> void:
	DirAccess.remove_absolute(PATH)
	assert_true(BestRecord.submit(120, PATH), "첫 기록은 최고 기록")
	assert_eq(BestRecord.load_best(PATH), 120)
	assert_false(BestRecord.submit(80, PATH), "낮은 기록은 최고 기록이 아님")
	assert_false(BestRecord.submit(120, PATH), "같은 기록도 최고 기록이 아님")
	assert_eq(BestRecord.load_best(PATH), 120, "낮은 기록으로 덮어쓰지 않음")
	assert_true(BestRecord.submit(300, PATH))
	assert_eq(BestRecord.load_best(PATH), 300)
	DirAccess.remove_absolute(PATH)


func test_깨진_저장_파일이면_0으로_보고_새_기록을_저장한다() -> void:
	for content in ["이건 설정 파일이 아님 [[[", "[record]\nbest_distance=\"많이\"\n", "[record]\nbest_distance=-5\n"]:
		var file := FileAccess.open(PATH, FileAccess.WRITE)
		file.store_string(content)
		file.close()
		assert_eq(BestRecord.load_best(PATH), 0, content)
	assert_true(BestRecord.submit(10, PATH))
	assert_eq(BestRecord.load_best(PATH), 10)
	DirAccess.remove_absolute(PATH)
