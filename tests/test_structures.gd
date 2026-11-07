extends TestCase
## 구조물: 빨래줄(밟으면 튕김, 밟기 직전 새로 누르면 더 높이), 전봇대(꼭대기 착지), 배치(같은 시드 고정, 안전한 자리만).

const DT := 1.0 / 120.0


## 구조물 하나만 있는 판. 고양이는 x=0, 옥상 높이 roof_top
func _sim_with(kind: String) -> RunnerSim:
	var sim := RunnerSim.new(1)
	sim.accelerate = false
	sim.items.clear()
	sim.structures.clear()
	var base: float = sim.y
	var height := Balance.LINE_HEIGHT if kind == "line" else Balance.POLE_HEIGHT
	var width := Balance.LINE_WIDTH if kind == "line" else Balance.POLE_WIDTH
	# 속도가 0이면 가만히 서서 떨어지는 것만 볼 수 있어 위치 x를 구조물 가운데에 맞춘다
	sim.structures.append({"kind": kind, "left": -width * 0.5, "right": width * 0.5, "top": base + height, "base": base})
	sim.speed = 0.0
	sim.x = 0.0
	return sim


## 구조물 위 gap 높이에서 가만히 떨어뜨린다
func _drop(sim: RunnerSim, gap: float) -> void:
	sim.on_ground = false
	sim.vy = 0.0
	sim.y = sim.structures[0].top + gap


func test_빨래줄을_위에서_밟으면_튕겨_오른다() -> void:
	var sim := _sim_with("line")
	_drop(sim, 30.0)
	var apex := 0.0
	var bounced := false
	for i in 240:
		sim.step(DT, false)
		bounced = bounced or sim.bounced
		apex = maxf(apex, sim.y)
	assert_true(bounced, "튕김 신호")
	assert_true(absf(apex - (sim.structures[0].top + Balance.LINE_BOUNCE_HEIGHT)) < 3.0, "기본 튕김 높이 (%.1f)" % (apex - sim.structures[0].top))
	assert_true(not sim.boosted, "누르지 않았으니 기본 튕김")


func test_밟기_직전에_새로_누르면_더_높이_튕긴다() -> void:
	var sim := _sim_with("line")
	_drop(sim, 8.0)
	sim.step(DT, true)  # 새로 누름 (아직 공중)
	var apex := 0.0
	var boosted := false
	var seen := false
	for i in 240:
		sim.step(DT, true)
		apex = maxf(apex, sim.y)
		if sim.bounced and not seen:
			seen = true
			boosted = sim.boosted  # 첫 튕김만 본다 (뒤에 줄에 다시 내려앉으면 기본 튕김)
	assert_true(boosted, "더 높이 튕김")
	assert_true(absf(apex - (sim.structures[0].top + Balance.LINE_BOOST_HEIGHT)) < 3.0, "더 높이 튕김 높이 (%.1f)" % (apex - sim.structures[0].top))
	assert_true(Balance.LINE_BOOST_HEIGHT > Balance.JUMP_MAX_HEIGHT, "더 높이는 최대 점프보다 높음")


func test_오래_전에_누른_손가락은_더_높이_안_됨() -> void:
	var sim := _sim_with("line")
	_drop(sim, 300.0)  # 높은 데서 떨어지는 동안 계속 누르고 있음
	var boosted := false
	for i in 240:
		sim.step(DT, true)
		boosted = boosted or sim.boosted
		if sim.bounced:
			break
	assert_true(sim.bounced and not boosted, "처음부터 쭉 누르고 있었으면 기본 튕김")


func test_달리며_줄_아래를_지나가도_막히지_않는다() -> void:
	var sim := RunnerSim.new(1)
	sim.items.clear()
	sim.structures.clear()
	sim.structures.append({"kind": "line", "left": 300.0, "right": 440.0, "top": sim.y + Balance.LINE_HEIGHT, "base": sim.y})
	var base: float = sim.y
	var bounced := false
	for i in 120 * 2:
		sim.step(DT, false)
		bounced = bounced or sim.bounced
	assert_true(sim.x > 600.0 and sim.on_ground and sim.y == base and not bounced, "그냥 달려 지나감")


func test_전봇대_꼭대기에_내려앉으면_서고_끝에서_떨어진다() -> void:
	var sim := RunnerSim.new(1)
	sim.items.clear()
	sim.structures.clear()
	var base: float = sim.y
	var top := base + Balance.POLE_HEIGHT
	sim.structures.append({"kind": "pole", "left": 200.0, "right": 200.0 + Balance.POLE_WIDTH, "top": top, "base": base})
	# 꼭대기 위에서 내려오는 고양이: 발 범위가 꼭대기에 걸치도록 x를 맞춤
	sim.x = 200.0
	sim.y = top + 20.0
	sim.vy = 0.0
	sim.on_ground = false
	var stood := false
	for i in 20:
		sim.step(DT, false)
		stood = stood or (sim.on_ground and sim.y == top)
	assert_true(stood, "꼭대기에 섬")
	for i in int(120 * 1.2):
		sim.step(DT, false)
	assert_true(sim.on_ground and sim.y == base, "꼭대기를 지나면 떨어져 옥상에 내려앉음 (y=%.1f)" % sim.y)


func test_최대로_눌러야_전봇대_꼭대기에_닿는다() -> void:
	# 톡 점프로는 못 닿고(최대 점프 높이보다 낮고 JUMP_MIN_HEIGHT보다 높음), 길게 누르면 닿는다
	assert_true(Balance.POLE_HEIGHT > Balance.JUMP_MIN_HEIGHT and Balance.POLE_HEIGHT < Balance.JUMP_MAX_HEIGHT, "꼭대기는 톡과 최대 사이")


func test_구조물_배치는_같은_시드면_같다() -> void:
	assert_eq(_placed(5, 600.0), _placed(5, 600.0))
	assert_true(_placed(5, 600.0) != _placed(6, 600.0), "다른 시드면 다름")


func test_구조물이_생겨도_같은_시드의_옥상과_아이템은_그대로() -> void:
	var sim := RunnerSim.new(3)
	var gen := RoofGenerator.new(3)
	var placer := ItemPlacer.new(3)
	var items: Array[Dictionary] = []
	for i in range(1, sim.roofs.size()):
		assert_eq(sim.roofs[i], gen.next_roof(sim.roofs[i - 1], Balance.RUN_SPEED), "옥상 %d" % i)
		items.append_array(placer.items_for(sim.roofs[i - 1], sim.roofs[i]))
	assert_eq(sim.items, items)


func test_구조물은_속도와_상관없이_옥상_위에_안전한_자리에만_놓인다() -> void:
	for speed in [Balance.RUN_SPEED, 700.0, Balance.SPEED_MAX]:
		var lines := 0
		var poles := 0
		var total := 0
		for seed_value in 8:
			var gen := RoofGenerator.new(seed_value + 1)
			var placer := StructurePlacer.new(seed_value + 1)
			var roof := gen.next_roof(RoofGenerator.first_roof(0.0), speed)
			for i in 100:
				var next := gen.next_roof(roof, speed)
				var s := placer.structure_for(roof, next, speed)
				total += 1
				if not s.is_empty():
					assert_true(s.left >= roof.left and s.right <= roof.right, "옥상 안")
					assert_eq(s.base, roof.top, "옥상 위")
					assert_true(StructurePlacer.is_safe(s, roof, next, speed), "안전한 자리")
					if s.kind == "line":
						lines += 1
					else:
						poles += 1
				roof = next
		# 속도마다 빨래줄과 전봇대가 눈에 띌 만큼 나온다 (옥상 100개에 하나는 있다는 최소 기준)
		assert_true(lines * 50 >= total and poles * 50 >= total, "속도 %d: 빨래줄 %d, 전봇대 %d (옥상 %d)" % [speed, lines, poles, total])


func test_튕김_뒤에_안전하다고_본_자리는_실제로_안전하다() -> void:
	# 놓인 빨래줄의 왼쪽 끝·오른쪽 끝(발이 막 걸치는 자리)에서 밟고 기본으로 튕긴 뒤 떨어지지 않는다
	var checked := 0
	for seed_value in 6:
		var sim := RunnerSim.new(seed_value + 1, Balance.SPEED_MAX)
		sim.accelerate = false
		sim.x = 20000.0
		sim._fill_roofs()  # 옥상과 구조물을 그 앞까지 만든다
		for line in sim.structures:
			if line.kind != "line":
				continue
			for side in [-1.0, 1.0]:
				checked += 1
				assert_true(_bounce_survives(seed_value + 1, line, side), "시드 %d 줄 %.0f %s" % [seed_value + 1, line.left, "왼쪽" if side < 0 else "오른쪽"])
	assert_true(checked > 0, "검사한 줄이 있음")


## 시드 seed의 옥상에서 line을 side(-1 왼쪽 끝 / 1 오른쪽 끝)에서 밟아 튕긴 뒤 살아남는지 (첫 착지까지)
func _bounce_survives(seed_value: int, line: Dictionary, side: float) -> bool:
	var sim := RunnerSim.new(seed_value, Balance.SPEED_MAX)
	sim.accelerate = false
	sim.items.clear()
	# 줄에 닿기까지 몇 칸 앞으로 가니, 그동안에도 발이 줄에 걸쳐 있게 가장자리에서 조금 안쪽에 둔다
	sim.x = (line.left - Balance.CAT_FOOT_HALF + 1.0) if side < 0.0 else (line.right + Balance.CAT_FOOT_HALF - 30.0)
	sim.y = line.top + 0.5
	sim.vy = 0.0
	sim.on_ground = false
	sim.structures = [line]
	sim._fill_roofs()
	for i in 120 * 3:
		sim.step(DT, false)
		if sim.game_over:
			return false
		if sim.landed:
			return true  # 튕긴 뒤 옥상이나 전봇대에 내려앉음
	return false


## 시드 seed로 거리 dist까지 만든 구조물 목록
func _placed(seed_value: int, dist: float) -> Array:
	var sim := RunnerSim.new(seed_value)
	sim.x = dist
	sim._fill_roofs()
	return sim.structures
