extends SceneTree
## v0.7.0 2b 측정 (자동 테스트 아님): 밸런스 봇의 실제 판 기록(MissionTracker)으로 미션이 얼마나 깨지는지 잰다.
## 실행: nice -n 10 godot --headless --path . -s res://review/v0.7.0/2b/missions.gd > review/v0.7.0/2b/missions_raw.md
## 1) 실력별 판 POOL개(시드 1~POOL, 강화 0단계, 최대 MAX_TIME초)를 한 번 돌려 둔다.
## 2) 미션 하나씩: 판 n개를 무작위로 골라(시드 고정) 그 미션이 깨지는 비율 (TRIALS번).
## 3) 날짜별 플레이어: 매일 미션을 새로 뽑고(실제 Missions.refresh, 2026-11-16 월요일부터 WEEKS주), 일일 3개를 다 깰 때까지
##    (하루 최대 DAY_CAP판) 판을 고른다. 판이 끝날 때마다 가장 싼 강화를 사고(w_shop),
##    강화를 다 샀으면 하루에 부스터 하나(400)를 산다(늦은 주에 생선 쓸 곳). 바꾸기는 쓰지 않는다.
##    → 일일 3개를 깨는 데 든 판 수, 주간 3개를 다 깬 날(1~7, 못 깨면 8).

const BalanceBot := preload("res://tests/balance_bot.gd")
const POOL := 150
const MAX_TIME := 900.0
const TRIALS := 2000
const PLAYERS := 20
const WEEKS := 8
const DAY_CAP := 6


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var pools := {}
	for skill: String in ["초보", "익숙함"]:
		pools[skill] = []
		for seed_value in POOL:
			pools[skill].append(BalanceBot.play_stats(BalanceBot.SKILLS[skill], seed_value + 1, MAX_TIME).missions)
	print("# v0.7.0 2b 미션 측정 원본\n\n판: 실력별 %d판, 강화 0단계, 최대 %d초. 걸린 시간 %d초\n" % [POOL, MAX_TIME, (Time.get_ticks_msec() - t0) / 1000])
	_one_run_values(pools)
	_each_mission(pools)
	for skill: String in pools:
		_players(skill, pools[skill])
	quit(0)


static func _pct(list: Array, q: float) -> float:
	var sorted := list.duplicate()
	sorted.sort()
	return sorted[mini(int(sorted.size() * q), sorted.size() - 1)]


## 한 판 값의 하위 25% / 가운데 / 평균
func _one_run_values(pools: Dictionary) -> void:
	var keys := ["meters", "fish", "combo", "stage", "mult", "stage_ups", "double", "tramp", "perfect", "pole", "dash", "smash", "smash_one",
			"gold", "yarn", "can", "bell", "pass_flock", "pass_pot", "pass_tank", "pass_ac"]
	print("## 한 판 값 (하위25% / 가운데 / 평균)\n")
	print("| 값 | 초보 | 익숙함 |\n|---|---|---|")
	for key: String in keys:
		var cells := []
		for skill: String in pools:
			var list: Array = pools[skill].map(func(run: Dictionary) -> float: return float(run.get(key, 0)))
			var total := 0.0
			for v: float in list:
				total += v
			cells.append("%d / %d / %.1f" % [_pct(list, 0.25), _pct(list, 0.5), total / list.size()])
		print("| %s | %s |" % [key, " | ".join(cells)])
	print("")


## 미션 하나가 판 n개 안에 깨지는 비율
func _each_mission(pools: Dictionary) -> void:
	print("## 일일 미션 하나씩: n판 안에 깨지는 비율 (%d번 뽑기)\n" % TRIALS)
	print("| id | 내용 | 초보 2판 | 초보 4판 | 익숙함 1판 | 익숙함 2판 |\n|---|---|---|---|---|---|")
	for id: String in MissionTable.DAILY:
		var row: Dictionary = MissionTable.DAILY[id]
		var cells := []
		for pair in [["초보", 2], ["초보", 4], ["익숙함", 1], ["익숙함", 2]]:
			var pool: Array = pools[pair[0]]
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(id) + pair[1]
			var ok := 0
			for t in TRIALS:
				var entry := {"id": id, "target": row.target, "progress": 0, "done": false}
				for n in pair[1]:
					Missions._advance(entry, row, pool[rng.randi_range(0, pool.size() - 1)])
				ok += 1 if entry.done else 0
			cells.append("%d%%" % roundi(100.0 * ok / TRIALS))
		print("| %s | %s | %s |" % [id, Missions.text(id), " | ".join(cells)])
	print("")


## 날짜별 플레이어 PLAYERS명 x WEEKS주
func _players(skill: String, pool: Array) -> void:
	var day_runs := []      # 그날 일일 3개를 다 깨는 데 든 판 수 (못 깨면 DAY_CAP + 1)
	var day_skilled := []   # 그날 "익숙함 이상"이었는지 (최고 거리 SKILLED_DISTANCE 넘음)
	var week_days := []     # 주간 3개를 다 깬 날 (1~7, 못 깨면 8)
	var weekly_fail := {}   # 그 주에 못 깬 주간 id → 횟수
	var weekly_seen := {}
	var daily_fail := {}    # 하루 DAY_CAP판으로 못 깬 일일 id → 횟수
	for p in PLAYERS:
		var data := SaveData.open("user://__bot_none__.cfg").data  # 파일 없음, 저장하지 않음
		var rng := RandomNumberGenerator.new()
		rng.seed = 7000 + p
		var done_day := 8
		for d in WEEKS * 7:
			var now := DayClock.shift({"year": 2026, "month": 11, "day": 16, "hour": 12, "minute": 0, "second": 0}, d + p * 7 * WEEKS)  # 사람마다 다른 주 (월요일 시작 유지)
			if d % 7 == 0:
				done_day = 8
			Missions.refresh(data, now)
			day_skilled.append(data.record.best_distance >= MissionTable.SKILLED_DISTANCE)
			var runs := 0
			while not Missions._all_done(data.missions.daily) and runs < DAY_CAP:
				var run: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
				runs += 1
				data.record.best_distance = maxi(data.record.best_distance, run.meters)
				data.wallet.fish += run.fish
				Missions.count(data, run)
				_buy(data)
			if data.upgrades.values().all(func(lv: int) -> bool: return lv >= Balance.UPGRADE_MAX) and data.wallet.fish >= 400:
				data.wallet.fish -= 400  # 강화를 다 샀으면 하루에 부스터 하나
				Missions.on_shop(data)
			day_runs.append(runs if Missions._all_done(data.missions.daily) else DAY_CAP + 1)
			for e: Dictionary in data.missions.daily:
				if not e.done:
					daily_fail[e.id] = daily_fail.get(e.id, 0) + 1
			if done_day == 8 and Missions._all_done(data.missions.weekly):
				done_day = d % 7 + 1
			if d % 7 == 6:
				week_days.append(done_day)
				for e: Dictionary in data.missions.weekly:
					weekly_seen[e.id] = weekly_seen.get(e.id, 0) + 1
					if not e.done:
						weekly_fail[e.id] = weekly_fail.get(e.id, 0) + 1
	print("## %s 플레이어 %d명 x %d주 (하루 최대 %d판, 일일만 함)\n" % [skill, PLAYERS, WEEKS, DAY_CAP])
	var long_runs := pool.filter(func(run: Dictionary) -> bool: return run.meters >= MissionTable.SKILLED_DISTANCE).size()
	print("- 한 판에 %dm 넘는 비율: %d%% (넘으면 그다음 날부터 \"익숙함 이상\" 미션이 나옴)" % [MissionTable.SKILLED_DISTANCE, roundi(100.0 * long_runs / pool.size())])
	for part in [["전체", -1], ["익숙함 이상 전", 0], ["익숙함 이상 뒤", 1]]:
		var runs_of := []
		for i in day_runs.size():
			if part[1] < 0 or int(day_skilled[i]) == part[1]:
				runs_of.append(day_runs[i])
		if runs_of.is_empty():
			continue
		var line := []
		for k in [1, 2, 3, 4, DAY_CAP]:
			line.append("%d판 %d%%" % [k, roundi(100.0 * runs_of.filter(func(r: int) -> bool: return r <= k).size() / float(runs_of.size()))])
		print("- 일일 3개 다 깸, %s (%d일): %s" % [part[0], runs_of.size(), ", ".join(line)])
	print("- 하루 %d판으로 못 깬 일일: %s" % [DAY_CAP, daily_fail])
	var w := float(week_days.size())
	var wline := []
	for k in [3, 4, 5, 6, 7]:
		wline.append("%d일 %d%%" % [k, roundi(100.0 * week_days.filter(func(r: int) -> bool: return r <= k).size() / w)])
	print("- 주간 3개 다 깸 (%d주): %s" % [w, ", ".join(wline)])
	print("- 주간 미션별 못 깬 주 / 나온 주: %s" % ", ".join(weekly_seen.keys().map(func(id: String) -> String: return "%s %d/%d" % [id, weekly_fail.get(id, 0), weekly_seen[id]])))
	print("")


## 살 수 있는 가장 싼 강화를 산다 (w_shop)
static func _buy(data: Dictionary) -> void:
	while true:
		var best := ""
		for kind: String in data.upgrades:
			if data.upgrades[kind] < Balance.UPGRADE_MAX and (best == "" or data.upgrades[kind] < data.upgrades[best]):
				best = kind
		if best == "" or Balance.UPGRADE_PRICES[data.upgrades[best]] > data.wallet.fish:
			return
		data.wallet.fish -= Balance.UPGRADE_PRICES[data.upgrades[best]]
		data.upgrades[best] += 1
		Missions.on_shop(data)
