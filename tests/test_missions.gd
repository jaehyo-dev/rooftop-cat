extends TestCase
## 미션·날짜·등급 (review/v0.7.0/PLAN.md 5·6·7번): DayClock, Missions, MissionTracker, CatRank.

const PATH := "user://test_missions.cfg"
const BalanceBot := preload("res://tests/balance_bot.gd")


func _at(y: int, mo: int, d: int, h: int = 12, mi: int = 0) -> Dictionary:
	return {"year": y, "month": mo, "day": d, "hour": h, "minute": mi, "second": 0}


func _clear() -> void:
	for file in [PATH, PATH + ".tmp", PATH + ".broken"]:
		DirAccess.remove_absolute(file)


## 빈 저장 데이터 (파일 없이). recent_meters > 0이면 최근 10판이 모두 그 거리 ("익숙함 이상" 판단)
func _data(recent_meters: int = 0) -> Dictionary:
	_clear()
	var data := SaveData.open(PATH).data
	if recent_meters > 0:
		for n in MissionTable.RECENT_RUNS:
			SaveData.push_recent(data, recent_meters)
	return data


# --- 날짜 ---

func test_일일_키는_자정에_바뀐다() -> void:
	assert_eq(DayClock.day_key(_at(2026, 11, 12, 23, 59)), "2026-11-12")
	assert_eq(DayClock.day_key(_at(2026, 11, 13, 0, 0)), "2026-11-13")
	assert_eq(DayClock.day_key(DayClock.shift(_at(2026, 11, 12, 23, 59), 1)), "2026-11-13")


func test_주간_키는_그_주_월요일이고_일요일에서_월요일로_넘어갈_때_바뀐다() -> void:
	# 2026-11-16은 월요일
	assert_eq(DayClock.week_key(_at(2026, 11, 16, 0, 0)), "2026-11-16")
	assert_eq(DayClock.week_key(_at(2026, 11, 18)), "2026-11-16", "수요일")
	assert_eq(DayClock.week_key(_at(2026, 11, 22, 23, 59)), "2026-11-16", "일요일 23:59")
	assert_eq(DayClock.week_key(_at(2026, 11, 23, 0, 0)), "2026-11-23", "월요일 0:00")


func test_연말과_윤년_2월_29일() -> void:
	assert_eq(DayClock.day_key(DayClock.shift(_at(2026, 12, 31, 23, 59), 1)), "2027-01-01")
	# 2027-01-01은 금요일: 그 주 월요일은 지난해 2026-12-28
	assert_eq(DayClock.week_key(_at(2027, 1, 1)), "2026-12-28", "주가 해를 넘김")
	assert_eq(DayClock.day_key(DayClock.shift(_at(2028, 2, 28), 1)), "2028-02-29", "윤년")
	assert_eq(DayClock.day_key(DayClock.shift(_at(2028, 2, 29), 1)), "2028-03-01")
	assert_eq(DayClock.day_key(DayClock.shift(_at(2027, 2, 28), 1)), "2027-03-01", "평년")
	assert_eq(DayClock.week_key(_at(2028, 2, 29)), "2028-02-28", "2028-02-29는 화요일")


func test_시계는_고정_시각과_날_넘기기를_받는다() -> void:
	var clock := DayClock.new()
	clock.fixed = _at(2026, 11, 12, 23, 30)
	assert_eq(DayClock.day_key(clock.now()), "2026-11-12")
	clock.offset_days = 7
	assert_eq(DayClock.day_key(clock.now()), "2026-11-19")
	assert_eq(clock.now().hour, 23, "시각은 그대로")
	var real := DayClock.new()
	assert_eq(DayClock.day_key(real.now()), DayClock.day_key(Time.get_datetime_dict_from_system()), "기본은 기기 시간")


# --- 표 ---

func test_후보는_일일_32개_주간_12개이고_칸이_다_있다() -> void:
	assert_eq(MissionTable.DAILY.size(), 32)
	assert_eq(MissionTable.WEEKLY.size(), 12)
	for table: Dictionary in [MissionTable.DAILY, MissionTable.WEEKLY]:
		for id: String in table:
			var row: Dictionary = table[id]
			for key in ["kind", "topic", "stat", "target", "tier", "text"]:
				assert_true(row.has(key), "%s.%s" % [id, key])
			assert_true(row.tier >= 1 and row.tier <= 3, id)
			assert_true(row.text.contains("%s"), id)
	assert_eq(Missions.text("w_fish_10k"), "이번 주 생선 10,000마리")
	assert_eq(Missions.reward("d_dist_1"), {"fish": 400, "xp": 10})
	assert_eq(Missions.reward("w_alldays"), {"fish": 3500, "xp": 70})


func test_남은_시간은_자정과_다음_월요일까지() -> void:
	assert_eq(DayClock.seconds_to_next_day(_at(2026, 11, 12, 23, 59)), 60)
	assert_eq(DayClock.seconds_to_next_day(_at(2026, 12, 31, 0, 0)), 86400, "연말")
	assert_eq(DayClock.seconds_to_next_week(_at(2026, 11, 22, 23, 59)), 60, "일요일 23:59")
	assert_eq(DayClock.seconds_to_next_week(_at(2026, 11, 16, 0, 0)), 7 * 86400, "월요일 0시")
	assert_eq(DayClock.left_text(60), "1분")
	assert_eq(DayClock.left_text(5 * 3600 + 12 * 60 + 30), "5시간 12분")
	assert_eq(DayClock.left_text(3 * 86400 + 4 * 3600), "3일 4시간")


# --- 뽑기 ---

func test_일일은_365일_내내_기록_누적_행동_하나씩_주제_다르고_쉬움_보통_어제_것_없음() -> void:
	var prev := []
	var day := _at(2026, 1, 1)
	var seen := {}
	for n in 365:
		var key := DayClock.day_key(DayClock.shift(day, n))
		var ids := Missions.roll_daily(key, prev, n % 2 == 0)
		assert_eq(ids.size(), 3, key)
		assert_eq(ids.map(func(id: String) -> String: return MissionTable.DAILY[id].kind), ["record", "sum", "action"], key)
		var topics := {}
		var tiers := []
		for id: String in ids:
			topics[MissionTable.DAILY[id].topic] = true
			tiers.append(MissionTable.DAILY[id].tier)
			assert_false(prev.has(id), "%s 어제 것 %s" % [key, id])
			if n % 2 == 1:
				assert_false(Missions._skilled_only(MissionTable.DAILY, id), "%s 초보에게 %s" % [key, id])
			seen[id] = true
		assert_true(Missions._skilled_count(ids) <= 1, "%s 익숙함 이상은 하루 1개까지 %s" % [key, ids])
		assert_eq(topics.size(), 3, key)
		assert_true(tiers.has(1) and tiers.has(2), "%s 쉬움·보통 %s" % [key, tiers])
		prev = ids
	assert_eq(seen.size(), 32, "1년이면 모든 후보가 한 번 이상 나옴")
	assert_eq(Missions._pool(MissionTable.DAILY, "record", false).size(), 9, "초보: 기록형 어려움 2개 빠짐")
	assert_eq(Missions.roll_daily("2026-11-12", [], true), Missions.roll_daily("2026-11-12", [], true), "같은 날 같은 미션")
	assert_true(Missions.roll_daily("2026-11-12", [], true) != Missions.roll_daily("2026-11-13", [], true), "다른 날")


func test_주간은_일일_미션_축_하나_필수_주제_다르고_지난주_것_없음() -> void:
	var prev := []
	for n in 104:
		var key := DayClock.week_key(DayClock.shift(_at(2026, 1, 5), n * 7))
		var ids := Missions.roll_weekly(key, prev)
		assert_eq(ids.size(), 3)
		assert_eq(MissionTable.WEEKLY[ids[0]].kind, "daily", key)
		var topics := {}
		for id: String in ids:
			topics[MissionTable.WEEKLY[id].topic] = true
			assert_false(prev.has(id), "%s 지난주 것 %s" % [key, id])
		assert_eq(topics.size(), 3, key)
		prev = ids


func test_날이_바뀌면_새로_뽑고_어제_목록을_남기며_바꾼_횟수가_0이_된다() -> void:
	var data := _data()
	assert_true(Missions.refresh(data, _at(2026, 11, 12)))
	var m: Dictionary = data.missions
	assert_eq([m.day, m.week], ["2026-11-12", "2026-11-09"])
	var first: Array = m.daily.map(func(e: Dictionary) -> String: return e.id)
	assert_eq(m.daily[0].progress, 0)
	m.swaps_today = 2
	assert_false(Missions.refresh(data, _at(2026, 11, 12, 23, 59)), "같은 날은 그대로")
	assert_true(Missions.refresh(data, _at(2026, 11, 13, 0, 1)))
	assert_eq(m.prev_daily, first)
	assert_eq(m.swaps_today, 0)
	assert_eq(m.prev_weekly, [], "같은 주라 주간은 그대로")


func test_통조림_방울_어려움은_익숙함_이상만() -> void:
	var data := _data(MissionTable.SKILLED_MEDIAN - 1)
	for n in 60:
		data.missions.day = ""
		Missions.refresh(data, DayClock.shift(_at(2026, 1, 1), n))
		for e: Dictionary in data.missions.daily:
			assert_false(e.id in ["d_can", "d_bell"] or MissionTable.DAILY[e.id].tier == 3, "익숙함 전에게 " + e.id)


func test_익숙함_이상은_최근_10판_거리의_가운데_값으로_정한다() -> void:
	var data := _data()
	assert_false(Missions.skilled(data), "판이 없으면 아님")
	SaveData.push_recent(data, 5000)
	assert_true(Missions.skilled(data), "한 판뿐이면 그 판")
	for n in 9:
		SaveData.push_recent(data, 300)
	assert_false(Missions.skilled(data), "운 좋은 한 판으로는 안 됨")
	for n in 10:
		SaveData.push_recent(data, MissionTable.SKILLED_MEDIAN)
	assert_eq(data.stats.recent.size(), MissionTable.RECENT_RUNS, "최근 10판만")
	assert_true(Missions.skilled(data))
	data.stats.recent = [MissionTable.SKILLED_MEDIAN - 100, MissionTable.SKILLED_MEDIAN + 100]
	assert_true(Missions.skilled(data), "짝수면 가운데 둘의 평균")


func test_바꾸기도_익숙함_이상을_하루_1개로_지킨다() -> void:
	var data := _data(3000)
	_use(data, ["d_dist_3", "d_fish_c1", "d_double"], ["w_daily_10", "w_fish_10k", "w_dist"])
	for slot in [1, 2]:
		for id: String in Missions._swap_pool(data, false, slot):
			assert_false(Missions._skilled_only(MissionTable.DAILY, id), "이미 어려움이 있는데 " + id)
	assert_true(Missions._swap_pool(data, false, 0).any(func(id: String) -> bool: return Missions._skilled_only(MissionTable.DAILY, id)),
			"어려움 자리는 어려움으로 바꿀 수 있음")


# --- 진행과 보상 ---

## 정해 둔 일일·주간으로 바꿔 넣는다
func _use(data: Dictionary, daily: Array, weekly: Array) -> void:
	Missions.refresh(data, _at(2026, 11, 12))
	data.missions.daily = Missions._entries(daily, MissionTable.DAILY)
	data.missions.weekly = Missions._entries(weekly, MissionTable.WEEKLY)


func test_기록형은_그_판_값_누적형은_더하고_깨면_경험치는_바로_생선은_받기로() -> void:
	var data := _data()
	_use(data, ["d_dist_2", "d_fish_c1", "d_double"], ["w_daily_10", "w_fish_10k", "w_dist"])
	var r := Missions.count(data, {"meters": 400, "fish": 600, "double": 4, "runs": 1})
	assert_eq(r.done, [])
	r = Missions.count(data, {"meters": 300, "fish": 600, "double": 4, "runs": 1})
	assert_eq(data.missions.daily[0].progress, 400, "기록형은 판 최고 (더하지 않음)")
	assert_eq(r.done.map(func(d: Dictionary) -> String: return d.id), ["d_fish_c1"])
	assert_eq(data.missions.daily[1].progress, 1000, "목표에서 멈춤")
	assert_eq(data.wallet.fish, 0, "생선은 아직")
	assert_eq(data.rank.xp, 10, "경험치는 바로")
	assert_eq(Missions.pending(data), 1)
	assert_eq(Missions.claim(data, false, 0), 0, "안 깬 미션은 못 받음")
	assert_eq(Missions.claim(data, false, 1), 400)
	assert_eq(Missions.claim(data, false, 1), 0, "두 번 못 받음")
	assert_eq([data.wallet.fish, Missions.pending(data)], [400, 0])
	assert_eq(data.missions.weekly[0].progress, 1, "일일 하나 깸 → 주간 축")
	assert_eq(data.missions.weekly[1].progress, 1200)
	Missions.count(data, {"fish": 999999})
	r = Missions.count(data, {"fish": 999999})
	assert_eq(r.done, [], "깬 미션은 다시 깨지 않음")


func test_일일_3개를_다_깨는_순간_다_깬_날이_하나_오른다() -> void:
	var data := _data()
	_use(data, ["d_dist_1", "d_runs", "d_double"], ["w_alldays", "w_runs", "w_double"])
	Missions.count(data, {"meters": 300, "runs": 1, "double": 10})
	assert_eq(data.missions.weekly[0].progress, 0, "아직 2개")
	Missions.count(data, {"runs": 1})
	assert_eq(data.missions.weekly[0].progress, 1)
	Missions.count(data, {"runs": 1})
	assert_eq(data.missions.weekly[0].progress, 1, "한 번만")


func test_판_도중_자정을_넘기면_어제_미션에_넣은_뒤_새_날로_바뀐다() -> void:
	_clear()
	var save := SaveData.open(PATH)
	save.data.missions.day = ""
	Missions.start_run(save, _at(2026, 11, 12, 23, 59))
	_use(save.data, ["d_dist_1", "d_runs", "d_double"], ["w_daily_10", "w_runs", "w_double"])
	save.data.missions.day = "2026-11-12"
	var old_fish := save.fish()
	var r := Missions.end_run(save, {"meters": 350, "runs": 1}, _at(2026, 11, 13, 0, 1))
	assert_eq(r.done.map(func(d: Dictionary) -> String: return d.id), ["d_dist_1"], "어제 미션으로 깸")
	assert_eq(save.fish(), old_fish + 400, "안 받은 보상은 새 날로 넘어갈 때 자동으로 받음")
	assert_eq(save.data.missions.day, "2026-11-13", "그다음 새 날")
	assert_eq(save.data.missions.prev_daily, ["d_dist_1", "d_runs", "d_double"])
	assert_eq(save.data.missions.daily.map(func(e: Dictionary) -> int: return e.progress), [0, 0, 0])
	var again := SaveData.open(PATH)
	assert_eq(again.data.missions, save.data.missions, "저장했다 다시 읽어도 같음")
	assert_eq(again.data.missions.daily[0].done, false, "참거짓 타입 그대로")
	_clear()


func test_23시59분_결과에서_0시1분에_다시_하면_새_날_미션에_들어간다() -> void:
	_clear()
	var save := SaveData.open(PATH)
	Missions.start_run(save, _at(2026, 11, 12, 23, 50))
	Missions.end_run(save, {"runs": 1}, _at(2026, 11, 12, 23, 59))
	Missions.start_run(save, _at(2026, 11, 13, 0, 1))
	assert_eq(save.data.missions.day, "2026-11-13")
	assert_eq(SaveData.open(PATH).data.missions.day, "2026-11-13", "판 시작 때 저장")
	_clear()


func test_강화나_부스터를_사면_주간_상점_미션이_오른다() -> void:
	_clear()
	var save := SaveData.open(PATH)
	_use(save.data, ["d_dist_1", "d_runs", "d_double"], ["w_daily_10", "w_shop", "w_double"])
	save.data.wallet.fish = 300 * 2 + 400
	save.buy_upgrade("dash")
	save.buy_upgrade("yarn")
	assert_eq(save.data.missions.weekly[1].progress, 2)
	save.buy_booster("bell_start")
	assert_eq(save.data.missions.weekly[1].done, true, "3번째(부스터)에 깸")
	assert_eq(save.fish(), 0)
	assert_eq(Missions.claim(save.data, true, 1), 2500, "주간 보상 2,500")
	save.save()
	assert_eq(SaveData.open(PATH).fish(), 2500, "저장됨")
	_clear()


func test_2b_저장처럼_받기_칸이_없는_깬_미션은_이미_받은_것() -> void:
	var data := _data()
	_use(data, ["d_dist_1", "d_runs", "d_double"], ["w_daily_10", "w_runs", "w_double"])
	data.missions.daily[0].progress = 300
	data.missions.daily[0].done = true  # claimed 칸 없음
	assert_eq(Missions.pending(data), 0)
	assert_eq(Missions.claim(data, false, 0), 0)
	Missions.refresh(data, _at(2026, 11, 13))
	assert_eq(data.wallet.fish, 0, "새 날에도 다시 주지 않음")


# --- 바꾸기 ---

func test_바꾸기는_200_400_800_뒤_800이고_같은_종류로_바꾸며_진행이_사라진다() -> void:
	var data := _data(2000)
	_use(data, ["d_dist_2", "d_fish_c1", "d_double"], ["w_daily_10", "w_fish_10k", "w_dist"])
	data.wallet.fish = 10000
	Missions.count(data, {"fish": 500})
	var prices := []
	for n in 4:
		prices.append(Missions.swap_price(data, false))
		var before: int = data.wallet.fish
		assert_eq(Missions.swap(data, false, 1), "")
		assert_eq(data.wallet.fish, before - prices[n])
		var row: Dictionary = MissionTable.DAILY[data.missions.daily[1].id]
		assert_eq(row.kind, "sum", "같은 종류")
		assert_eq(data.missions.daily[1].progress, 0, "진행 사라짐")
		assert_true(row.topic != "dist" and row.topic != "jump", "다른 두 개와 주제가 다름")
	assert_eq(prices, [200, 400, 800, 800])
	assert_eq(Missions.swap_price(data, true), 1000)
	Missions.refresh(data, _at(2026, 11, 13))
	assert_eq(Missions.swap_price(data, false), 200, "날이 바뀌면 다시 200")


func test_생선이_모자라거나_깬_미션이면_바뀌지_않는다() -> void:
	var data := _data()
	_use(data, ["d_dist_1", "d_runs", "d_double"], ["w_daily_10", "w_fish_10k", "w_dist"])
	data.wallet.fish = 199
	var before: Dictionary = data.missions.duplicate(true)
	assert_eq(Missions.swap(data, false, 0), "money")
	assert_eq(Missions.swap(data, true, 0), "money")
	assert_eq(data.missions, before, "아무것도 안 바뀜")
	assert_eq(data.wallet.fish, 199)
	Missions.count(data, {"meters": 300})
	data.wallet.fish = 5000
	assert_eq(Missions.swap(data, false, 0), "done")
	assert_false(Missions.can_swap(data, false, 0))
	assert_true(Missions.can_swap(data, false, 1))


func test_주간_일일_축을_바꾸면_다시_일일_축이다() -> void:
	var data := _data()
	_use(data, ["d_dist_1", "d_runs", "d_double"], ["w_daily_10", "w_fish_10k", "w_dist"])
	data.wallet.fish = 5000
	assert_eq(Missions.swap(data, true, 0), "")
	assert_eq(MissionTable.WEEKLY[data.missions.weekly[0].id].kind, "daily")
	assert_eq(data.wallet.fish, 4000)


# --- 등급 ---

func test_한_번에_여러_등급이_올라도_보너스가_빠짐없이_들어간다() -> void:
	var data := _data()
	var ups := CatRank.add_xp(data, 100 + 150 + 200 + 30)
	assert_eq(ups.map(func(u: Dictionary) -> int: return u.level), [2, 3, 4])
	assert_eq(data.rank, {"level": 4, "xp": 30})
	assert_eq(data.wallet.fish, 1000 + 1500 + 2000)
	assert_eq(data.boosters, {"dash_start": 1, "bell_start": 1, "fish_bonus": 1})
	assert_eq(CatRank.rank_name(4), "지붕 고냥이")


func test_전설의_고냥이_뒤로는_500마다_생선_2000() -> void:
	var data := _data()
	var total := 0
	for x: int in MissionTable.RANK_NEXT_XP:
		total += x
	assert_eq(total, 2700, "PLAN 6번 누적")
	var ups := CatRank.add_xp(data, total + 1200)
	assert_eq(data.rank, {"level": 10, "xp": 200})
	assert_eq(ups.size(), 9 + 2)
	assert_eq(ups[-1], {"level": 10, "fish": 2000, "boosters": []})
	assert_eq(CatRank.rank_name(10), "전설의 고냥이")
	assert_eq(data.boosters.fish_bonus, 1 + 6, "4등급 1 + 5~10등급 1개씩")


func test_부스터_보너스는_99개를_넘지_않는다() -> void:
	var data := _data()
	data.boosters.dash_start = 99
	CatRank.add_xp(data, 100)
	assert_eq(data.boosters.dash_start, 99)


# --- 저장 ---

func test_깨진_미션_목록과_옛_저장은_새로_뽑고_다른_값은_그대로() -> void:
	_clear()
	var file := ConfigFile.new()
	file.set_value("save", "version", 1)
	file.set_value("record", "best_distance", 1500)
	file.set_value("wallet", "fish", 777)
	file.set_value("missions", "day", "2026-11-12")
	file.set_value("missions", "daily", [{"id": "없는_미션", "target": 1, "progress": 0, "done": false}, 3, "x"])
	file.set_value("missions", "weekly", "엉망")
	file.set_value("rank", "level", 99)
	file.save(PATH)
	var save := SaveData.open(PATH)
	assert_eq(save.data.rank.level, 10, "등급은 마지막 등급까지")
	assert_eq(Missions.count(save.data, {"runs": 1}), {"done": [], "ranks": []}, "이상한 목록에는 넣지 않음 (오류 없음)")
	assert_true(Missions.refresh(save.data, _at(2026, 11, 12)))
	assert_true(Missions._valid(save.data.missions.daily, MissionTable.DAILY))
	assert_true(Missions._valid(save.data.missions.weekly, MissionTable.WEEKLY))
	assert_eq(save.data.missions.prev_daily, [], "깨진 목록은 어제 목록으로 남기지 않음")
	assert_eq(save.fish(), 777)
	# v0.6.0처럼 미션 칸이 없는 저장
	_clear()
	file = ConfigFile.new()
	file.set_value("record", "best_score", 5000)
	file.save(PATH)
	save = SaveData.open(PATH)
	Missions.start_run(save, _at(2026, 11, 12))
	assert_eq(SaveData.open(PATH).data.missions.daily.size(), 3)
	_clear()


# --- 판 안 사건 ---

func test_추적기가_판_안_사건을_센다() -> void:
	# 밸런스 봇 한 판 (봇이 따로 센 값과 비교)
	var stats: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS["익숙함"], 3, 200.0)
	var run: Dictionary = stats.missions
	assert_eq(run.get("double", 0), stats.doubles)
	assert_eq(run.get("smash", 0), stats.dash_smashed)
	assert_eq(run.get("dash", 0), stats.dash_count)
	assert_eq(run.get("perfect", 0), stats.get("perfects", 0))
	for kind in ["gold", "yarn", "can"]:
		assert_eq(run.get(kind, 0), stats.eaten.get(kind, 0), kind)
	assert_eq(run.get("bell", 0), stats.blocks)
	assert_eq([run.meters, run.fish, run.combo, run.runs], [stats.meters, stats.fish, stats.combo_best, 1])
	var passes := 0
	for kind in ["flock", "pot", "tank", "ac"]:
		passes += run.get("pass_" + kind, 0)
	assert_true(passes > 20 and run.double > 0 and run.stage >= 4 and run.mult >= 2, "센 것이 있음 %s" % run)
	assert_true(run.get("smash_one", 0) <= run.get("smash", 0))


func test_질주_중_착지는_전봇대_판에_선_것으로_세지_않는다() -> void:
	var sim := RunnerSim.new(1, Balance.RUN_SPEED, false)
	var tracker := MissionTracker.new()
	sim.set("_ground_roof", {"left": 0.0, "right": 100.0, "top": 0.0, "platform": true})
	sim.landed = true
	sim.dashing = true
	tracker.observe(sim)
	assert_eq(tracker.counts.get("pole", 0), 0, "질주 중")
	sim.dashing = false
	tracker.observe(sim)
	assert_eq(tracker.counts.get("pole", 0), 1, "진짜 판 착지")


func test_장애물을_뒤로_지나가면_한_번만_피함으로_센다() -> void:
	var sim := RunnerSim.new(1, Balance.RUN_SPEED, false)
	sim.obstacles.append({"kind": "pot", "x": sim.x + 30.0, "w": 40.0, "y0": 900.0, "y1": 950.0, "base": 900.0})  # 높이 떠 있어 안 맞음
	var passed := []
	for n in 120:
		sim.step(1.0 / 120.0, false)
		passed.append_array(sim.passed)
	assert_eq(passed.size(), 1)
	assert_eq(passed[0].kind, "pot")
