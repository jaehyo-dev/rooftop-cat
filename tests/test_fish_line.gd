extends TestCase
## 생선 줄 규칙 (PLAN 17번): 어느 x 자리든 생선 줄은 한 줄만 보인다. 질주가 닿는 구간은 질주용 줄 하나로 바뀐다.

const DT := 1.0 / 60.0


## 긴 판을 자동으로 달린다. 떨어져도 상자로 살리고, 질주·통조림을 주기적으로 앞에 놓는다. 일정 간격마다 check를 부른다
func _long_run(seed_value: int, seconds: float, check: Callable, perks: Perks = null) -> RunnerSim:
	var sim := RunnerSim.new(seed_value, Balance.RUN_SPEED, true, perks)
	var next_flight := 0
	var hold_left := 0.0
	var next_power := 20.0
	var kinds := ["dash", "can"]
	var check_at := 0.0
	while sim.elapsed < seconds and not sim.game_over:
		sim.has_box = true
		sim.hearts = Balance.HEARTS_MAX
		var flights: Array[Dictionary] = sim.road.flights
		while next_flight < flights.size() and flights[next_flight].press_x < sim.x - 40.0:
			next_flight += 1
		if next_flight < flights.size() and sim.x >= flights[next_flight].press_x and sim.on_ground:
			hold_left = flights[next_flight].hold
			next_flight += 1
		if sim.elapsed >= next_power and sim.on_ground:
			next_power += 15.0
			sim.items.append({"kind": kinds[int(next_power / 15.0) % 2], "x": sim.x + 80.0, "y": sim.y + Balance.ITEM_LIFT})
		sim.step(DT, hold_left > 0.0 or (sim.dashing and fmod(sim.elapsed, 1.3) < 0.3))
		hold_left -= DT
		if sim.elapsed >= check_at:
			check_at += 0.25
			check.call(sim)
	return sim


## 화면에 있는 생선(먹는 범위 앞~화면 오른쪽 끝) 중, x 간격이 FISH_SPACING 절반보다 가깝고 높이가 다른 쌍들
static func _crossed_pairs(sim: RunnerSim) -> Array:
	var fish: Array = sim.items.filter(func(it: Dictionary) -> bool:
		return (it.kind == "fish" or it.kind == "gold") and it.x > sim.x + 100.0 and it.x < sim.x + sim.view_ahead)
	fish.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.x < b.x)
	var out := []
	for i in fish.size():
		for j in range(i + 1, fish.size()):
			if fish[j].x - fish[i].x >= Balance.FISH_SPACING * 0.5:
				break
			if not is_equal_approx(fish[i].y, fish[j].y):
				out.append([fish[i], fish[j]])
	return out


func test_긴_판에서_생선_줄이_겹치지_않는다() -> void:
	# 0단계, 강화 전부 10단계(질주 6초·털실 +50%) + 질주로 출발
	for case in 16:
		var seed_value := case % 8 + 1
		var perks := Perks.new() if case < 8 else Perks.all(Balance.UPGRADE_MAX, ["dash_start"])
		var pairs := []
		var dashes := [0]
		var checked := [0]
		var sim := _long_run(seed_value, 120.0, func(s: RunnerSim) -> void:
			dashes[0] += 1 if s.dash_started or s.dashing else 0
			if s.magnet_time > 0.0:
				return  # 털실은 생선을 끌어당겨 일부러 모은다
			checked[0] += 1
			pairs.append_array(_crossed_pairs(s)), perks)
		assert_true(dashes[0] > 0, "시드 %d: 질주가 나옴" % seed_value)
		assert_true(checked[0] > 100, "시드 %d: 충분히 검사함 (%d)" % [seed_value, checked[0]])
		assert_eq(pairs.size(), 0, "시드 %d (%.0f초): 겹친 쌍 %s" % [seed_value, sim.elapsed, str(pairs.slice(0, 2))])


func test_질주가_시작되면_앞쪽_생선이_한_줄의_질주용_줄로_바뀐다() -> void:
	for seed_value in 12:
		var sim := RunnerSim.new(seed_value + 1, 640.0)
		sim.accelerate = false
		sim.x = 300.0
		sim.y = sim.roof_at(sim.x).get("top", sim.y)
		sim.step(DT, false)
		sim.items.append({"kind": "dash", "x": sim.x + 40.0, "y": sim.y + Balance.ITEM_LIFT})
		while not sim.dash_started:
			sim.step(DT, false)
		var before: float = sim.x
		var low := 0
		var high := 0
		var gaps: Array[float] = []
		var last := before
		var ahead := sim.items.filter(func(it: Dictionary) -> bool: return FishRoad.is_fish(it) and it.x > before)
		ahead.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.x < b.x)
		assert_true(ahead.size() > 15, "시드 %d: 앞쪽에 질주용 줄이 바로 깔림 (%d)" % [seed_value, ahead.size()])
		for fish in ahead:
			assert_true(fish.kind == "fish" and fish.has("bonus"), "시드 %d: 원래 생선(필수·황금)이 남지 않음" % seed_value)
			var over: float = fish.y - sim.y - Balance.ITEM_LIFT
			high += 1 if over > 100.0 else 0
			low += 1 if absf(over) < 1.0 else 0
			gaps.append(fish.x - last)
			last = fish.x
		assert_true(low >= 3 and high >= 3, "시드 %d: 땅 줄과 공중 호가 이어짐 (%d, %d)" % [seed_value, low, high])
		assert_true(gaps.max() < Balance.FISH_SPACING * 4.0, "시드 %d: 줄이 끊기지 않음 (%.0f)" % [seed_value, gaps.max()])
		while sim.dashing:
			sim.step(DT, false)
		assert_eq(sim.items.filter(func(it: Dictionary) -> bool: return it.x > sim.x and it.x < sim.x + 200.0 and FishRoad.is_fish(it)).is_empty(), false, "시드 %d: 착지 옥상에도 줄이 이어짐" % seed_value)


func test_겹치는_생선은_나중_것을_뺀다() -> void:
	var items: Array[Dictionary] = [{"kind": "fish", "x": 100.0, "y": 50.0}, {"kind": "box", "x": 300.0, "y": 50.0}]
	FishRoad.add_one_line(items, [
		{"kind": "fish", "x": 130.0, "y": 200.0}, {"kind": "gold", "x": 80.0, "y": 50.0},
		{"kind": "fish", "x": 135.0, "y": 200.0}, {"kind": "fish", "x": 300.0, "y": 90.0}, {"kind": "yarn", "x": 100.0, "y": 90.0}] as Array[Dictionary])
	assert_eq(items.map(func(it: Dictionary) -> float: return it.x), [100.0, 300.0, 135.0, 300.0, 100.0], "가까운 생선만 빠지고 아이템은 그대로")


func test_생선_소리만_작고_겹치지_않으며_황금과_아이템은_그대로() -> void:
	var sim := RunnerSim.new(1)
	sim.picked.assign([{"kind": "fish"}, {"kind": "fish"}])
	assert_eq(SfxEvents.sounds(sim, false), ["fish"] as Array[String], "생선 여러 마리도 한 번")
	for kind in ["gold", "yarn", "cookie", "can", "dash"]:
		sim.picked.assign([{"kind": "fish"}, {"kind": kind}, {"kind": "fish"}])
		assert_eq(SfxEvents.sounds(sim, false), ["pickup"] as Array[String], kind + "은 예전 소리")
	sim.picked.assign([{"kind": "gold"}, {"kind": "bell"}, {"kind": "fish"}])
	assert_eq(SfxEvents.sounds(sim, false), ["bell"] as Array[String], "방울이 먼저")
	assert_false(SfxEvents.fish_due(1.05, 1.0), "0.07초 안이면 하나로")
	assert_true(SfxEvents.fish_due(1.07, 1.0), "0.07초 지나면 새로")
	assert_true(SfxEvents.fish_due(0.0, 90.0), "새 판이면 새로")
	var view: Node = load("res://scripts/world_view.gd").new()
	add_child(view)
	await wait_frames(1)
	var sfx: Dictionary = view.get("_sfx")
	assert_eq(sfx.fish.volume_db, sfx.pickup.volume_db - 12.0, "생선만 12dB 작게 (2b: 음이 오르면 더 크게 들려서)")
	assert_eq(sfx.pickup.volume_db, sfx.bell.volume_db, "아이템은 다른 효과음과 같은 크기")
	assert_eq(sfx.fish.max_polyphony, 2, "동시에 2개까지")
	view.queue_free()
