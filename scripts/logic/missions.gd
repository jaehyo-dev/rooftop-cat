class_name Missions
extends RefCounted
## 일일·주간 미션 (화면과 분리된 로직, review/v0.7.0/PLAN.md 5·7번). 후보·보상 수치는 MissionTable.
## 상태는 저장의 data.missions: day·week(뽑은 날짜 키), daily·weekly([{id, target, progress, done}] x3),
## prev_daily·prev_weekly(어제·지난주 id, 뽑기에서 뺌), swaps_today(오늘 바꾼 횟수).
## 보상은 깨는 순간 자동으로 들어온다(받기 버튼 없음, PLAN 15번): 날이 바뀌어 사라지는 보상이 없다.
## 판 시작 때 날짜를 확인해 새로 뽑고, 그 판의 진행은 판 시작 때 있던 미션에 판이 끝날 때 한 번에 넣은 뒤 다시 날짜를 확인한다.

const KINDS := ["record", "sum", "action"]


## 날짜 키가 바뀌었거나 저장이 이상하면 새로 뽑는다. 돌려줌: 바뀌었는지
static func refresh(data: Dictionary, now: Dictionary) -> bool:
	var m: Dictionary = data.missions
	var changed := false
	var day := DayClock.day_key(now)
	var daily_ok := _valid(m.daily, MissionTable.DAILY)
	if m.day != day or not daily_ok:
		if m.day != day and daily_ok:
			m.prev_daily = _ids(m.daily)
		var skilled: bool = data.record.best_distance >= MissionTable.SKILLED_DISTANCE
		m.daily = _entries(roll_daily(day, m.prev_daily, skilled), MissionTable.DAILY)
		m.day = day
		m.swaps_today = 0
		changed = true
	var week := DayClock.week_key(now)
	var weekly_ok := _valid(m.weekly, MissionTable.WEEKLY)
	if m.week != week or not weekly_ok:
		if m.week != week and weekly_ok:
			m.prev_weekly = _ids(m.weekly)
		m.weekly = _entries(roll_weekly(week, m.prev_weekly), MissionTable.WEEKLY)
		m.week = week
		changed = true
	return changed


## 판 시작: 날짜를 확인하고 바뀌었으면 저장
static func start_run(save: SaveData, now: Dictionary) -> void:
	if refresh(save.data, now):
		save.save()


## 판 끝: 이번 판 기록(MissionTracker.result)을 판 시작 때 있던 미션에 넣고, 그다음 날짜를 확인한 뒤 저장.
## 돌려줌: count와 같음 (결과 화면용)
static func end_run(save: SaveData, run: Dictionary, now: Dictionary) -> Dictionary:
	var result := count(save.data, run)
	refresh(save.data, now)
	save.save()
	return result


## 기록을 미션 진행에 더한다 (저장은 부른 쪽이 함). run = 값 이름 → 수 (한 판 기록형은 그 판 값, 나머지는 더함).
## 일일을 깰 때마다 주간의 daily_done이 오르고, 일일 3개가 이번에 다 깨지면 full_day가 오른다.
## 돌려줌: {"done": 이번에 깬 미션 [{id, weekly, fish, xp}], "ranks": 오른 등급 (CatRank.add_xp)}
static func count(data: Dictionary, run: Dictionary) -> Dictionary:
	var m: Dictionary = data.missions
	var result := {"done": [], "ranks": []}
	if not _valid(m.daily, MissionTable.DAILY) or not _valid(m.weekly, MissionTable.WEEKLY):
		return result  # 아직 뽑기 전이거나 저장이 이상함 (다음 refresh가 새로 뽑음)
	var all_before := _all_done(m.daily)
	var weekly_run := run.duplicate()
	for entry: Dictionary in m.daily:
		if _advance(entry, MissionTable.DAILY[entry.id], run):
			_reward(data, entry.id, false, result)
			weekly_run.daily_done = weekly_run.get("daily_done", 0) + 1
	if not all_before and _all_done(m.daily):
		weekly_run.full_day = weekly_run.get("full_day", 0) + 1
	for entry: Dictionary in m.weekly:
		if _advance(entry, MissionTable.WEEKLY[entry.id], weekly_run):
			_reward(data, entry.id, true, result)
	return result


## 상점에서 강화·부스터를 하나 샀을 때 (w_shop은 판 밖에서 오름). 저장은 부른 쪽이 함
static func on_shop(data: Dictionary) -> Dictionary:
	return count(data, {"shop": 1})


static func info(id: String) -> Dictionary:
	return MissionTable.DAILY.get(id, MissionTable.WEEKLY.get(id, {}))


## 화면 문구 (목표 숫자는 천 단위 쉼표)
static func text(id: String) -> String:
	var row := info(id)
	return row.text % _comma(row.target)


## 깨면 받는 생선·경험치
static func reward(id: String) -> Dictionary:
	var weekly := MissionTable.WEEKLY.has(id)
	var tier: int = info(id).tier - 1
	return {"fish": (MissionTable.WEEKLY_FISH if weekly else MissionTable.DAILY_FISH)[tier],
			"xp": (MissionTable.WEEKLY_XP if weekly else MissionTable.DAILY_XP)[tier]}


# --- 뽑기 ---

## 일일 3개 = 기록 1 + 누적 1 + 행동 1, 쉬움 1·보통 1 이상, 주제가 다 다름, 어제 것 빼기. 시드 = 날짜 키.
## 안 맞으면 "어제 것 → 주제·난이도" 순서로 조건을 푼다
static func roll_daily(day: String, prev: Array, skilled: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(day)
	var pools := []
	for kind: String in KINDS:
		pools.append(_shuffled(_pool(MissionTable.DAILY, kind, skilled), rng))
	for relax in 3:
		for a: String in pools[0]:
			for b: String in pools[1]:
				for c: String in pools[2]:
					var ids := [a, b, c]
					if _fits(ids, MissionTable.DAILY, prev, relax) and (relax >= 2 or _has_tiers(ids)):
						return ids
	return [pools[0][0], pools[1][0], pools[2][0]]


## 주간 3개 = 일일 미션 축(daily) 1 + 누적 2, 주제가 다 다름, 지난주 것 빼기. 시드 = 주 월요일 키
static func roll_weekly(week: String, prev: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("w" + week)
	var axis := _shuffled(_pool(MissionTable.WEEKLY, "daily", true), rng)
	var sums := _shuffled(_pool(MissionTable.WEEKLY, "sum", true), rng)
	for relax in 3:
		for a: String in axis:
			for i in sums.size():
				for j in range(i + 1, sums.size()):
					var ids := [a, sums[i], sums[j]]
					if _fits(ids, MissionTable.WEEKLY, prev, relax):
						return ids
	return [axis[0], sums[0], sums[1]]


# --- 바꾸기 ---

## 다음 바꾸기 값
static func swap_price(data: Dictionary, weekly: bool) -> int:
	if weekly:
		return MissionTable.WEEKLY_SWAP_PRICE
	var prices := MissionTable.SWAP_PRICES
	return prices[mini(data.missions.swaps_today, prices.size() - 1)]


## 바꿀 수 있는지 (깨지 않았고 후보가 있음). 아니면 2c 화면이 바꾸기 버튼을 숨긴다
static func can_swap(data: Dictionary, weekly: bool, slot: int) -> bool:
	var list: Array = data.missions.weekly if weekly else data.missions.daily
	return not list[slot].done and not _swap_pool(data, weekly, slot).is_empty()


## 깨지 않은 미션 하나를 같은 종류의 다른 후보로 바꾼다 (생선을 내고, 진행은 사라짐). 저장은 부른 쪽이 함.
## 돌려줌: "" = 바꿈, "done" = 이미 깸, "none" = 바꿀 후보 없음, "money" = 생선 부족 (아무것도 안 바뀜)
static func swap(data: Dictionary, weekly: bool, slot: int) -> String:
	var m: Dictionary = data.missions
	var list: Array = m.weekly if weekly else m.daily
	if list[slot].done:
		return "done"
	var pool := _swap_pool(data, weekly, slot)
	if pool.is_empty():
		return "none"
	var price := swap_price(data, weekly)
	if price > data.wallet.fish:
		return "money"
	data.wallet.fish -= price
	if not weekly:
		m.swaps_today += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash((m.week if weekly else m.day) + "/" + ",".join(_ids(list)))  # 같은 상태면 같은 결과
	list[slot] = _entries([pool[rng.randi_range(0, pool.size() - 1)]], MissionTable.WEEKLY if weekly else MissionTable.DAILY)[0]
	return ""


## 바꿀 후보: 같은 종류, 지금 3개와 다름, 어제(지난주) 것과 다른 두 개의 주제를 뺀다 (모자라면 "어제 것 → 주제" 순서로 풂)
static func _swap_pool(data: Dictionary, weekly: bool, slot: int) -> Array:
	var m: Dictionary = data.missions
	var table: Dictionary = MissionTable.WEEKLY if weekly else MissionTable.DAILY
	var list: Array = m.weekly if weekly else m.daily
	var prev: Array = m.prev_weekly if weekly else m.prev_daily
	var skilled: bool = data.record.best_distance >= MissionTable.SKILLED_DISTANCE
	var topics := []
	for i in list.size():
		if i != slot:
			topics.append(table[list[i].id].topic)
	var current := _ids(list)
	for relax in 3:
		var pool := []
		for id: String in _pool(table, table[list[slot].id].kind, skilled):
			if not current.has(id) and (relax >= 1 or not prev.has(id)) and (relax >= 2 or not topics.has(table[id].topic)):
				pool.append(id)
		if not pool.is_empty():
			return pool
	return []


# --- 안쪽 ---

## 진행을 더하고 이번에 깼으면 true
static func _advance(entry: Dictionary, row: Dictionary, run: Dictionary) -> bool:
	if entry.done:
		return false
	var value: int = run.get(row.stat, 0)
	entry.progress = mini(entry.target, maxi(entry.progress, value) if row.kind == "record" else entry.progress + value)
	entry.done = entry.progress >= entry.target
	return entry.done


static func _reward(data: Dictionary, id: String, weekly: bool, result: Dictionary) -> void:
	var got := reward(id)
	data.wallet.fish += got.fish
	result.done.append({"id": id, "weekly": weekly, "fish": got.fish, "xp": got.xp})
	result.ranks.append_array(CatRank.add_xp(data, got.xp))


static func _all_done(list: Array) -> bool:
	return list.all(func(entry: Dictionary) -> bool: return entry.done)


static func _ids(list: Array) -> Array:
	return list.map(func(entry: Dictionary) -> String: return entry.id)


static func _entries(ids: Array, table: Dictionary) -> Array:
	return ids.map(func(id: String) -> Dictionary: return {"id": id, "target": table[id].target, "progress": 0, "done": false})


## 저장에서 읽은 목록이 쓸 수 있는 모양인지 (3개, 표에 있는 id, 숫자·참거짓 타입)
static func _valid(list: Array, table: Dictionary) -> bool:
	if list.size() != 3:
		return false
	for entry: Variant in list:
		if not entry is Dictionary or not table.has(entry.get("id")) or typeof(entry.get("target")) != TYPE_INT \
				or typeof(entry.get("progress")) != TYPE_INT or typeof(entry.get("done")) != TYPE_BOOL:
			return false
	return true


static func _pool(table: Dictionary, kind: String, skilled: bool) -> Array:
	var ids := []
	for id: String in table:
		if table[id].kind == kind and (skilled or not _skilled_only(table, id)):
			ids.append(id)
	return ids


## "익숙함 이상"만 받는 후보: skilled 칸, 일일 어려움(tier 3)
static func _skilled_only(table: Dictionary, id: String) -> bool:
	return table[id].get("skilled", false) or (table[id].tier == 3 and MissionTable.DAILY.has(id))


## 시드 rng로 섞기 (Array.shuffle은 전역 무작위라 쓰지 않음)
static func _shuffled(ids: Array, rng: RandomNumberGenerator) -> Array:
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var keep: Variant = ids[i]
		ids[i] = ids[j]
		ids[j] = keep
	return ids


## relax 0 = 어제 것 빼고 주제가 다 다름, 1 = 어제 것 허용, 2 = 주제도 허용
static func _fits(ids: Array, table: Dictionary, prev: Array, relax: int) -> bool:
	if relax < 1 and ids.any(func(id: String) -> bool: return prev.has(id)):
		return false
	if relax < 2:
		var topics := {}
		for id: String in ids:
			topics[table[id].topic] = true
		if topics.size() != ids.size():
			return false
	return true


## 쉬움 하나와 보통 하나가 들어 있음
static func _has_tiers(ids: Array) -> bool:
	var tiers := ids.map(func(id: String) -> int: return MissionTable.DAILY[id].tier)
	return tiers.has(1) and tiers.has(2)


static func _comma(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
