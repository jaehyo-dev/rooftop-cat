extends TestCase
## 속도 곡선, 최고 기록 저장·불러오기.

const PATH := "user://test_best_record.cfg"


func test_속도는_단계_표를_따르고_최대에서_멈춘다() -> void:
	assert_eq(SpeedCurve.speed_at(0.0), 430.0, "처음 속도")
	assert_eq(SpeedCurve.speed_at(-5.0), 430.0, "음수 시간은 처음 속도")
	assert_eq(SpeedCurve.speed_at(14.9), 430.0, "단계 2 전")
	assert_eq(SpeedCurve.speed_at(60.0), 610.0, "1분 뒤")
	assert_eq(SpeedCurve.speed_at(100000.0), 950.0, "최대 속도에서 멈춤")
	assert_eq(Balance.SPEED_STAGES.size(), 12, "단계 12개")
	assert_eq(Balance.SPEED_STAGES[9][0], 300.0, "단계 10은 300초")
	var prev := 0.0
	var prev_start := -1.0
	for stage in Balance.SPEED_STAGES:
		assert_true(stage[0] > prev_start and stage[1] >= prev, "단계 표는 시각·속도가 줄지 않음")
		prev_start = stage[0]
		prev = stage[1]
		assert_eq(SpeedCurve.speed_at(stage[0] + Balance.SPEED_RAMP_TIME), stage[1], "%.0f초 단계: 오름이 끝나면 표의 속도" % stage[0])


func test_단계가_오르면_정해진_시간에_걸쳐_끊김_없이_빨라진다() -> void:
	assert_eq(SpeedCurve.speed_at(15.0), 430.0, "오르는 순간은 앞 단계 속도")
	assert_true(absf(SpeedCurve.speed_at(15.0 + Balance.SPEED_RAMP_TIME * 0.5) - 460.0) < 0.001, "가운데는 앞뒤 단계의 중간")
	assert_eq(SpeedCurve.speed_at(15.0 + Balance.SPEED_RAMP_TIME), 490.0, "끝나면 다음 단계 속도")
	var prev := Balance.RUN_SPEED
	for i in 660 * 120:
		var v := SpeedCurve.speed_at(i / 120.0)
		assert_true(v >= prev and v - prev < 1.0, "%.2f초: 줄지 않고 한 칸에 1 미만으로 오름 (%.3f → %.3f)" % [i / 120.0, prev, v])
		prev = v


func test_단계_번호와_다음_단계_속도() -> void:
	assert_eq(SpeedCurve.stage_at(0.0), 1)
	assert_eq(SpeedCurve.stage_at(14.99), 1)
	assert_eq(SpeedCurve.stage_at(15.0), 2)
	assert_eq(SpeedCurve.stage_at(100000.0), 12)
	assert_eq(RoofGenerator.arrival_speed(430.0), 490.0, "단계 1 → 2")
	assert_eq(RoofGenerator.arrival_speed(460.0), 490.0, "오르는 중에는 오르는 단계의 속도")
	assert_eq(RoofGenerator.arrival_speed(900.0), 950.0, "단계 9 → 10")
	assert_eq(RoofGenerator.arrival_speed(950.0), 950.0, "최고 속도에서는 그대로")


func test_옥상에_도착하기_전에_단계가_많아야_하나_오른다() -> void:
	# arrival_speed가 다음 단계만 보는 근거: 앞을 만드는 거리를 달리는 시간이 가장 짧은 단계보다 짧다
	for i in range(1, Balance.SPEED_STAGES.size() - 1):
		var length: float = Balance.SPEED_STAGES[i + 1][0] - Balance.SPEED_STAGES[i][0]
		assert_true(Balance.ROOF_LOOKAHEAD / Balance.SPEED_STAGES[i - 1][1] < length, "단계 %d 길이 %.0f초" % [i + 1, length])


func test_속도_단계_신호_값() -> void:
	assert_false(SpeedCurve.rises(1), "단계 1은 오름이 아님")
	for i in range(2, 11):
		assert_true(SpeedCurve.rises(i), "단계 %d는 빨라짐" % i)
	assert_false(SpeedCurve.rises(11), "단계 11은 밀도만")
	assert_false(SpeedCurve.rises(12), "단계 12는 밀도만")
	assert_eq(SpeedCurve.music_pitch(1), 1.0, "단계 1은 원래 곡")
	assert_true(absf(SpeedCurve.music_pitch(4) - 1.039) < 0.0001, "단계마다 +1.3%")
	assert_eq(SpeedCurve.music_pitch(12), Balance.MUSIC_PITCH_MAX, "최대")
	assert_true(SpeedCurve.music_pitch(10) <= Balance.MUSIC_PITCH_MAX, "단계 10도 최대 안")
	assert_eq(SpeedCurve.line_strength(2, 99.0), 0.0, "단계 2까지 평소에는 없음")
	assert_eq(SpeedCurve.line_strength(2, 0.0), 1.0, "오른 직후에는 진함")
	assert_eq(SpeedCurve.line_strength(3, 99.0), Balance.SPEED_LINE_REST_MIN, "단계 3부터 옅게 남음")
	assert_eq(SpeedCurve.line_strength(10, 99.0), Balance.SPEED_LINE_REST_MAX, "단계에 비례")
	assert_eq(SpeedCurve.line_strength(12, 99.0), Balance.SPEED_LINE_REST_MAX, "단계 10 뒤로는 그대로")
	assert_eq(SpeedCurve.line_strength(3, Balance.SPEED_RAMP_TIME - Balance.SPEED_LINE_FADE), 1.0, "끝나기 전까지 진함")
	assert_eq(SpeedCurve.line_strength(3, Balance.SPEED_RAMP_TIME), Balance.SPEED_LINE_REST_MIN, "1.2초 뒤에는 옅은 선으로")


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
