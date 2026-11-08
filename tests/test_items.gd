extends TestCase
## 아이템: 생선·종이상자 배치, 먹기, 종이상자 구제(1회만, 가까운 앞 옥상으로), 생선 저장.

const DT := 1.0 / 120.0
const PATH := "user://test_items_save.cfg"


## 시드로 옥상 count개와 그 사이 아이템을 만든다
func _make(seed_value: int, count: int) -> Dictionary:
	var gen := RoofGenerator.new(seed_value)
	var placer := ItemPlacer.new(seed_value)
	var roofs: Array[Dictionary] = [RoofGenerator.first_roof(0.0)]
	var per_roof: Array = [[]]
	for i in count:
		var roof := gen.next_roof(roofs[-1], Balance.RUN_SPEED)
		per_roof.append(placer.items_for(roofs[-1], roof))
		roofs.append(roof)
	return {"roofs": roofs, "items": per_roof}


func test_같은_시드면_같은_아이템() -> void:
	assert_eq(_make(5, 50).items, _make(5, 50).items)
	assert_true(_make(5, 50).items != _make(6, 50).items, "다른 시드면 다름")


func test_아이템이_생겨도_같은_시드의_옥상은_그대로() -> void:
	var sim := RunnerSim.new(3)
	var gen := RoofGenerator.new(3)
	assert_true(sim.items.size() > 0, "아이템이 있음")
	for i in range(1, sim.roofs.size()):
		assert_eq(sim.roofs[i], gen.next_roof(sim.roofs[i - 1], Balance.RUN_SPEED), "옥상 %d" % i)


func test_생선과_상자는_옥상_위나_틈_위_닿을_수_있는_곳에_있다() -> void:
	var made := _make(11, 300)
	var fish := 0
	var box_roofs: Array[int] = []
	for i in range(1, made.roofs.size()):
		var prev: Dictionary = made.roofs[i - 1]
		var roof: Dictionary = made.roofs[i]
		for item in made.items[i]:
			assert_true(item.x >= prev.right - Balance.FISH_SPACING - 0.01 and item.x <= roof.right, "옥상 %d: 앞 옥상 끝 ~ 이 옥상 사이" % i)
			# 옥상 위면 그 옥상, 틈 위면 낮은 쪽 옥상보다 높아야 묻히지 않는다
			var floor_top := minf(prev.top, roof.top)
			if item.x <= prev.right:
				floor_top = prev.top
			elif item.x >= roof.left:
				floor_top = roof.top
			assert_true(item.y - floor_top >= Balance.ITEM_LIFT - 0.01, "옥상 %d: 옥상에 묻히지 않음 (%.0f)" % [i, item.y - floor_top])
			# 높은 쪽 옥상에서 최대로 뛰면 몸 가운데가 닿는 높이 안
			var above: float = item.y - maxf(prev.top, roof.top)
			# (빨래줄 틈 위 생선 줄은 퍼펙트 튕김 + 더블점프로 닿는 높이)
			var reach := Balance.JUMP_MAX_HEIGHT
			if roof.has("line"):
				reach = Balance.LINE_HEIGHT + Balance.LINE_PERFECT_HEIGHT + Balance.DOUBLE_JUMP_MAX_HEIGHT
			assert_true(above <= reach + Balance.ITEM_LIFT, "옥상 %d: 뛰면 닿는 높이 (%.0f)" % [i, above])
			if item.kind == "fish":
				fish += 1
			else:
				box_roofs.append(i)
				assert_true(item.x > roof.left and item.x < roof.right, "상자는 옥상 위")
	assert_true(fish > 300, "생선이 넉넉함 (%d)" % fish)
	assert_true(box_roofs.size() >= 300 / Balance.BOX_EVERY_MAX, "상자 %d개" % box_roofs.size())
	for k in range(1, box_roofs.size()):
		# 전봇대 판은 상자 간격(옥상 수)에 세지 않는다
		var gap := 0
		for j in range(box_roofs[k - 1] + 1, box_roofs[k] + 1):
			if not made.roofs[j].get("platform", false):
				gap += 1
		assert_true(gap >= Balance.BOX_EVERY_MIN and gap <= Balance.BOX_EVERY_MAX, "상자 간격 %d" % gap)


## 시작 옥상 위 앞쪽에 아이템 하나만 둔 sim
func _sim_with(kind: String, ahead: float, lift: float = Balance.ITEM_LIFT) -> RunnerSim:
	var sim := RunnerSim.new(1)
	sim.accelerate = false
	sim.items.clear()
	sim.items.append({"kind": kind, "x": sim.x + ahead, "y": sim.y + lift})
	return sim


func test_달리다_몸에_닿은_생선을_먹는다() -> void:
	var sim := _sim_with("fish", 200.0)
	var picked := 0
	for i in 120:
		sim.step(DT, false)
		picked += sim.picked.size()
	assert_eq(sim.fish, 1)
	assert_eq(picked, 1, "먹은 신호 한 번")
	assert_true(sim.items.is_empty(), "먹은 생선은 사라짐")


func test_높이_있는_생선은_달리기만_해서는_못_먹는다() -> void:
	var sim := _sim_with("fish", 200.0, Balance.ITEM_LIFT + Balance.FISH_ARC_HEIGHT)
	for i in 120:
		sim.step(DT, false)
	assert_eq(sim.fish, 0)


func test_상자는_하나만_가진다() -> void:
	var sim := _sim_with("box", 200.0)
	sim.items.append({"kind": "box", "x": sim.x + 500.0, "y": sim.y + Balance.ITEM_LIFT})
	for i in 60:
		sim.step(DT, false)
	assert_true(sim.has_box, "첫 상자를 가짐")
	for i in 60:
		sim.step(DT, false)
	assert_eq(sim.items.size(), 1, "이미 가지고 있으면 두 번째 상자는 그대로 남음")


## 안 뛰고 달려 떨어지게 한다 (게임 끝, 또는 stop_after_rescue면 구제가 끝나 옥상에 서면 멈춤). 구제·게임 끝 기록을 돌려준다
func _run_with_box(sim: RunnerSim, seconds: float, stop_after_rescue: bool = false) -> Dictionary:
	var log := {"rescues": 0, "fell": false, "rescue_x": 0.0, "landed_roof": {}, "expected_roof": {}}
	for i in int(seconds * 120.0):
		var was_rescuing := sim.rescuing
		sim.step(DT, false)
		if sim.rescued:
			log.rescues += 1
			log.rescue_x = sim.x
			for roof in sim.roofs:
				if roof.right >= sim.x + Balance.CAT_FOOT_HALF:
					log.expected_roof = roof
					break
		if was_rescuing and not sim.rescuing:
			log.landed_roof = sim.roof_at(sim.x)
			assert_true(sim.on_ground, "구제 뒤 옥상 위에 섬")
			assert_eq(sim.y, float(sim.roof_at(sim.x).top), "옥상 높이")
			if stop_after_rescue:
				break
		if sim.fell:
			log.fell = true
			break
	return log


func test_상자가_있으면_떨어질_때_한_번_구제되어_가까운_앞_옥상에_선다() -> void:
	var sim := RunnerSim.new(1)
	sim.items.clear()
	sim.has_box = true
	var log := _run_with_box(sim, 30.0, true)
	assert_eq(log.rescues, 1, "구제 한 번")
	assert_false(sim.has_box, "상자를 씀")
	assert_false(log.landed_roof.is_empty(), "옥상에 내려섬")
	assert_true(is_same(log.landed_roof, log.expected_roof), "구제가 시작된 곳 바로 앞 옥상")
	assert_false(sim.game_over, "게임 계속")
	# 상자 없이 또 떨어지면 게임 끝
	sim.items.clear()
	log = _run_with_box(sim, 10.0)
	assert_eq(log.rescues, 0, "두 번째는 구제 없음")
	assert_true(log.fell, "게임 끝")


func test_벽에_막혀_떨어지는_중에도_구제된다() -> void:
	# 다음 옥상이 더 높고 틈이 넓어 점프 없이 틈으로 떨어지다 벽에 막히는 시드를 찾는다
	for seed_value in range(1, 500):
		var sim := RunnerSim.new(seed_value)
		var wall: Dictionary = sim.roofs[1]
		if wall.top <= sim.roofs[0].top or wall.left - sim.roofs[0].right < Balance.CAT_BODY_SIZE.x * 0.5 + Balance.CAT_FOOT_HALF + 10.0:
			continue
		sim.items.clear()
		sim.has_box = true
		var blocked := false
		for i in 120 * 6:
			sim.step(DT, false)
			blocked = blocked or (not sim.rescuing and sim.front() == wall.left and sim.ghost_time == 0.0)
			if sim.landed:
				break
		assert_true(blocked, "시드 %d: 벽에 막혀 떨어짐" % seed_value)
		assert_true(sim.on_ground and is_same(sim.roof_at(sim.x), wall), "막힌 벽의 옥상 위로 구제됨")
		assert_false(sim.game_over)
		return
	assert_true(false, "조건에 맞는 시드를 못 찾음")


func test_구제_중에는_허우적거리지_않고_올라가는_자세() -> void:
	var sim := RunnerSim.new(1)
	sim.items.clear()
	sim.has_box = true
	for i in 120 * 30:
		sim.step(DT, false)
		if sim.rescuing:
			assert_false(sim.is_doomed())
			assert_eq(CatPose.pose(sim).frame, "rise")
			return
	assert_true(false, "구제가 시작되지 않음")


func test_생선은_판마다_더해서_저장하고_다른_기록은_지우지_않는다() -> void:
	DirAccess.remove_absolute(PATH)
	assert_eq(BestRecord.load_fish(PATH), 0, "처음은 0")
	BestRecord.submit(77, PATH)
	assert_eq(BestRecord.add_fish(12, PATH), 12)
	assert_eq(BestRecord.add_fish(0, PATH), 12, "0개면 그대로")
	assert_eq(BestRecord.add_fish(5, PATH), 17)
	assert_eq(BestRecord.load_fish(PATH), 17)
	assert_eq(BestRecord.load_best(PATH), 77, "최고 기록 유지")
	BestRecord.submit(90, PATH)
	assert_eq(BestRecord.load_fish(PATH), 17, "최고 기록을 저장해도 생선 유지")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[wallet]\nfish=\"많이\"\n")
	file.close()
	assert_eq(BestRecord.load_fish(PATH), 0, "깨진 값은 0")
	DirAccess.remove_absolute(PATH)


func test_구제_직전에_누른_입력으로_복귀_뒤_점프하지_않는다() -> void:
	var sim := RunnerSim.new(1)
	sim.items.clear()
	sim.has_box = true
	# 구제가 시작되기 직전까지 안 누르고 떨어진다
	var guard := 0
	while not (not sim.on_ground and sim.vy < 0.0 and sim.y < Balance.RESCUE_HEIGHT + 30.0) and guard < 120 * 30:
		sim.step(DT, false)
		guard += 1
	# 구제 시작 즈음 톡 누르고 뗀다
	sim.step(DT, true)
	sim.step(DT, true)
	var jumped_after := false
	for i in 120 * 2:
		var was_rescuing := sim.rescuing
		sim.step(DT, false)
		if was_rescuing and not sim.rescuing:
			sim.step(DT, false)
			jumped_after = sim.jumped or not sim.on_ground
			break
	assert_false(jumped_after, "복귀하자마자 저절로 점프하지 않음")
