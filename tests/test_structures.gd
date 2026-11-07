extends TestCase
## 구조물(넓은 틈): 빨래줄 튕김(누르기 유무), 전봇대 판(착지·몸통 판정 없음·투명화 제외·다시 점프),
## 특수 틈은 점프 한 번으로 못 건너고 줄·판을 거쳐야만 건너는지, 속도별로 항상 건널 수 있는 범위인지, 배치.

const DT := 1.0 / 120.0
const SPEEDS := [430.0, 700.0, 950.0]


## 시드를 돌려 kind("line"/"pole")인 특수 틈을 처음 찾는다. {"prev": 앞 옥상, "roofs": [줄 옥상] 또는 [판, 다음 옥상]}
func _find(kind: String, speed: float, from_seed: int = 1) -> Dictionary:
	for seed_value in range(from_seed, from_seed + 400):
		var gen := RoofGenerator.new(seed_value)
		var prev := RoofGenerator.first_roof(0.0)
		for i in 80:
			var roof := gen.next_roof(prev, speed)
			if kind == "line" and roof.has("line"):
				return {"prev": prev, "roofs": [roof]}
			if kind == "pole" and roof.get("platform", false):
				return {"prev": prev, "roofs": [roof, gen.next_roof(roof, speed)]}
			prev = roof
	return {}


## 틈 하나만 있는 시뮬레이션 (속도 고정). 앞 옥상은 왼쪽으로 길게, 마지막 옥상은 끝없이 길게 둔다
func _sim(found: Dictionary, speed: float, with_structure: bool = true) -> RunnerSim:
	var sim := RunnerSim.new(1, speed)
	sim.accelerate = false
	sim.items.clear()
	sim.structures.clear()
	sim.roofs.clear()
	var prev: Dictionary = found.prev.duplicate()
	prev.left = prev.right - 4000.0
	sim.roofs.append(prev)
	for roof in found.roofs:
		if not with_structure and roof.get("platform", false):
			continue  # 판을 뺀 틈 (판 없이 건널 수 있는지 확인용)
		sim.roofs.append(roof.duplicate())
		if with_structure and roof.has("line"):
			sim.structures.append(roof.line)
	sim.roofs[-1].right = 100000.0
	sim.set("_ground_roof", prev)
	sim.x = prev.right - 600.0
	sim.y = prev.top
	sim.vy = 0.0
	sim.on_ground = true
	return sim


## sim에서 press_x에 닿으면 hold초 누르고, (retap이면 내려오며 줄 높이에 닿을 때 한 번 더 눌러) seconds초 진행한다.
## 돌려주는 값: fell, bounced(줄 밟음), ghosted, plate(판에 내려앉음), crossed(마지막 옥상에 서 있음)
func _trial(sim: RunnerSim, press_x: float, hold: float, retap: bool, seconds: float = 6.0) -> Dictionary:
	var out := {"fell": false, "bounced": false, "ghosted": false, "plate": false}
	var hold_left := 0.0
	var tapped := false
	var last: Dictionary = sim.roofs[-1]
	for i in int(seconds / DT):
		var pressed := false
		if sim.x >= press_x and hold_left == 0.0 and not tapped and (sim.on_ground or sim.get("_coyote") > 0.0):
			hold_left = hold + DT
		if hold_left > 0.0:
			pressed = true
			hold_left -= DT
			if hold_left <= 0.0:
				hold_left = -1.0  # 한 번만 누른다
		elif retap and not sim.on_ground and sim.vy < 0.0 and not sim.structures.is_empty() and sim.y - sim.structures[0].top < 14.0 and sim.y > sim.structures[0].top - 1.0:
			pressed = (i % 2 == 0)  # 내려앉기 직전에 새로 한 번 누른다 (눌렀다 뗐다 하며 줄에 닿을 때마다)
		sim.step(DT, pressed)
		out.bounced = out.bounced or sim.bounced
		out.ghosted = out.ghosted or sim.ghosted
		if sim.landed and sim.get("_ground_roof").get("platform", false):
			out.plate = true
		if sim.game_over:
			out.fell = true
			break
	out.crossed = sim.on_ground and is_same(sim.get("_ground_roof"), last)
	return out


## 앞 옥상 끝 근처에서 뛰는 모든 (누르는 위치 x 누르는 시간) 조합을 돌린다. 돌려주는 값: 각 결과의 배열
func _sweep(found: Dictionary, speed: float, with_structure: bool, retap: bool) -> Array:
	var results: Array = []
	var edge: float = found.prev.right
	for off in range(-420, 110, 15):
		for hold in [0.0, 0.06, 0.12, 0.18, 0.24, JumpModel.max_hold_time()]:
			var sim := _sim(found, speed, with_structure)
			results.append(_trial(sim, edge + float(off), hold, retap))
	return results


# --- 빨래줄: 밟으면 튕김 ---

## 줄 하나가 있는 단순 판 (속도 0이라 제자리에서 내려앉기만 봄). 줄 가운데에 고양이를 둔다
func _line_drop(gap: float, boost_tap: bool) -> Dictionary:
	var sim := RunnerSim.new(1)
	sim.accelerate = false
	sim.items.clear()
	sim.structures.clear()
	var base: float = sim.y
	var line := {"kind": "line", "left": -200.0, "right": 200.0, "top": base + Balance.LINE_HEIGHT, "base": base}
	sim.structures.append(line)
	sim.speed = 0.0
	sim.x = 0.0
	sim.on_ground = false
	sim.vy = 0.0
	sim.y = line.top + gap
	var press := boost_tap
	var apex := 0.0
	var first_boost := false
	var seen := false
	for i in 400:
		sim.step(DT, press)
		if sim.bounced and not seen:
			seen = true
			first_boost = sim.boosted
		if seen:
			apex = maxf(apex, sim.y)
	return {"apex": apex - line.top, "boosted": first_boost, "seen": seen}


func test_빨래줄을_위에서_밟으면_튕겨_오른다() -> void:
	var r := _line_drop(30.0, false)
	assert_true(r.seen, "튕김 신호")
	assert_true(absf(r.apex - Balance.LINE_BOUNCE_HEIGHT) < 3.0, "기본 튕김 높이 (%.1f)" % r.apex)
	assert_true(not r.boosted, "누르지 않았으니 기본 튕김")


func test_밟기_직전에_새로_누르면_더_높이_튕긴다() -> void:
	var sim := RunnerSim.new(1)
	sim.accelerate = false
	sim.items.clear()
	sim.structures.clear()
	var base: float = sim.y
	sim.structures.append({"kind": "line", "left": -200.0, "right": 200.0, "top": base + Balance.LINE_HEIGHT, "base": base})
	sim.speed = 0.0
	sim.x = 0.0
	sim.on_ground = false
	sim.vy = 0.0
	sim.y = sim.structures[0].top + 8.0
	sim.step(DT, true)  # 새로 누름 (아직 공중, 줄 위 8픽셀)
	var apex := 0.0
	var boosted := false
	var seen := false
	for i in 300:
		sim.step(DT, true)
		if sim.bounced and not seen:
			seen = true
			boosted = sim.boosted
		apex = maxf(apex, sim.y)
	assert_true(boosted, "더 높이 튕김")
	assert_true(absf(apex - sim.structures[0].top - Balance.LINE_BOOST_HEIGHT) < 3.0, "더 높이 튕김 높이 (%.1f)" % (apex - sim.structures[0].top))
	assert_true(Balance.LINE_BOOST_HEIGHT > Balance.JUMP_MAX_HEIGHT, "더 높이는 최대 점프보다 높음")


func test_오래_전에_누른_손가락은_더_높이_안_됨() -> void:
	var sim := RunnerSim.new(1)
	sim.accelerate = false
	sim.items.clear()
	sim.structures.clear()
	var base: float = sim.y
	sim.structures.append({"kind": "line", "left": -200.0, "right": 200.0, "top": base + Balance.LINE_HEIGHT, "base": base})
	sim.speed = 0.0
	sim.x = 0.0
	sim.on_ground = false
	sim.vy = 0.0
	sim.y = sim.structures[0].top + 300.0  # 높은 데서 떨어지는 동안 계속 누르고 있음
	for i in 300:
		sim.step(DT, true)
		if sim.bounced:
			break
	assert_true(sim.bounced and not sim.boosted, "처음부터 쭉 누르고 있었으면 기본 튕김")


func test_달리며_줄_아래를_지나가도_막히지_않는다() -> void:
	var sim := RunnerSim.new(1)
	sim.items.clear()
	sim.structures.clear()
	var base: float = sim.y
	sim.structures.append({"kind": "line", "left": 300.0, "right": 440.0, "top": base + Balance.LINE_HEIGHT, "base": base})
	var bounced := false
	for i in 120 * 2:
		sim.step(DT, false)
		bounced = bounced or sim.bounced
	assert_true(sim.x > 600.0 and sim.on_ground and sim.y == base and not bounced, "그냥 달려 지나감")


# --- 전봇대 판 ---

func test_판에_내려앉으면_서고_끝을_지나면_떨어진다() -> void:
	var found := _find("pole", 430.0)
	var plate: Dictionary = found.roofs[0]
	var sim := _sim(found, 430.0)
	sim.x = plate.left + 10.0
	sim.y = plate.top + 20.0
	sim.on_ground = false
	var stood := false
	for i in 20:
		sim.step(DT, false)
		stood = stood or (sim.on_ground and is_same(sim.get("_ground_roof"), sim.roofs[1]))
	assert_true(stood, "판에 섬")
	var fell_from := false
	for i in 120 * 2:
		sim.step(DT, false)
		fell_from = fell_from or sim.on_ground == false
	assert_true(fell_from, "판 끝을 지나면 발밑이 빔")


func test_판은_벽_판정이_없어_몸이_닿아도_막히지_않는다() -> void:
	# 달리는 옥상 위(높이 100)에 판(높이 300)이 겹쳐 있어도 몸이 그 가로 범위를 그냥 지나간다
	var sim := RunnerSim.new(1)
	sim.accelerate = false
	sim.items.clear()
	sim.structures.clear()
	sim.roofs.clear()
	sim.roofs.append({"left": 600.0, "right": 720.0, "top": 300.0, "platform": true})
	sim.roofs.append({"left": -2000.0, "right": 100000.0, "top": 100.0})
	sim.set("_ground_roof", sim.roofs[1])
	sim.x = 300.0
	sim.y = 100.0
	sim.on_ground = true
	var ghosted := false
	for i in 120 * 3:
		sim.step(DT, false)
		ghosted = ghosted or sim.ghosted
	assert_true(sim.x > 900.0 and sim.y == 100.0 and sim.on_ground and not ghosted, "막히거나 투명화 없이 지나감 (x=%.0f)" % sim.x)


func test_판_높이_아래로_내려와도_다음_옥상에_내려앉을_수_있으면_떨어지는_자세가_아니다() -> void:
	var sim := RunnerSim.new(1)
	sim.accelerate = false
	sim.items.clear()
	sim.roofs.clear()
	sim.roofs.append({"left": -2000.0, "right": 300.0, "top": 250.0})
	sim.roofs.append({"left": 450.0, "right": 570.0, "top": 250.0, "platform": true})
	sim.roofs.append({"left": 800.0, "right": 100000.0, "top": 100.0, "no_ghost": true})
	sim.set("_ground_roof", sim.roofs[0])
	sim.set("_jumped", true)
	sim.on_ground = false
	sim.x = 500.0
	sim.vy = -100.0
	sim.y = 180.0  # 판(250)보다 아래, 다음 옥상(100)보다 위: 판은 못 오르지만 다음 옥상엔 내려앉을 수 있음
	assert_true(not sim.is_doomed(), "다음 옥상에 내려앉을 수 있음")
	sim.y = 90.0   # 다음 옥상보다도 아래: 구제 없이 떨어짐
	assert_true(sim.is_doomed(), "더는 내려앉을 곳이 없음")


func test_특수_틈_다음_옥상은_벽에_닿아도_투명화_구제가_없다() -> void:
	for no_ghost in [false, true]:
		var sim := RunnerSim.new(1)
		sim.accelerate = false
		sim.items.clear()
		sim.roofs.clear()
		sim.roofs.append({"left": -2000.0, "right": 300.0, "top": 100.0})
		sim.roofs.append({"left": 500.0, "right": 100000.0, "top": 100.0, "no_ghost": no_ghost})
		sim.set("_ground_roof", sim.roofs[0])
		sim.set("_jumped", true)
		sim.on_ground = false
		sim.x = 420.0  # 몸 앞쪽(+75)이 벽(500)에 닿기 직전
		sim.y = 70.0   # 옥상 높이(100)보다 아래, 몸 높이 안쪽
		sim.vy = -100.0
		var ghosted := false
		for i in 6:
			sim.step(DT, false)
			ghosted = ghosted or sim.ghosted
		if no_ghost:
			assert_true(not ghosted and sim.ghost_time == 0.0, "no_ghost 옥상은 투명화 없음")
			assert_true(sim.front() <= 500.0 + 0.001, "벽에 막힘")
		else:
			assert_true(ghosted, "보통 옥상은 투명화로 구제됨")


# --- 특수 틈: 못 건넘 / 건널 수 있음 ---

func test_빨래줄_틈은_점프_한_번으로_못_건너고_줄을_한_번_밟으면_반드시_건넌다() -> void:
	for speed in SPEEDS:
		var found := _find("line", speed)
		assert_true(not found.is_empty(), "속도 %d: 빨래줄 틈이 나옴" % speed)
		var prev: Dictionary = found.prev
		var roof: Dictionary = found.roofs[0]
		assert_eq(roof.top, prev.top, "속도 %d: 두 옥상 높이가 같음" % speed)
		assert_eq(roof.line.left, prev.right, "줄은 틈 시작부터")
		assert_eq(roof.line.right, roof.left, "줄은 틈 끝까지")
		assert_eq(roof.line.top, prev.top + Balance.LINE_HEIGHT, "줄 높이")
		assert_true(roof.no_ghost, "투명화 구제 없음")
		assert_true(roof.left - prev.right >= RoofGenerator.clear_gap(speed, 0.0), "속도 %d: 못 건너는 넓이 (%.0f)" % [speed, roof.left - prev.right])
		# 줄이 없으면 누르는 위치·시간 어느 조합으로도 못 건넌다
		var crossed_without := 0
		for r in _sweep(found, speed, false, false):
			if r.crossed:
				crossed_without += 1
		assert_eq(crossed_without, 0, "속도 %d: 줄 없이 건너는 조합" % speed)
		# 줄이 있으면: 줄을 밟은 조합은 (누르기 유무 모두) 전부 건너 서 있다
		for retap in [false, true]:
			var stepped := 0
			var failed := 0
			for r in _sweep(found, speed, true, retap):
				if r.bounced:
					stepped += 1
					if not r.crossed:
						failed += 1
			assert_true(stepped > 0, "속도 %d: 줄을 밟은 조합이 있음" % speed)
			assert_eq(failed, 0, "속도 %d, 더 높이 %s: 줄을 밟고도 못 건넌 조합 (밟은 %d)" % [speed, str(retap), stepped])


func test_전봇대_틈은_판_없이_못_건너고_첫_점프로_판까지_판에서_다음으로_갈_수_있다() -> void:
	for speed in SPEEDS:
		var found := _find("pole", speed)
		assert_true(not found.is_empty(), "속도 %d: 전봇대 틈이 나옴" % speed)
		var prev: Dictionary = found.prev
		var plate: Dictionary = found.roofs[0]
		var after: Dictionary = found.roofs[1]
		var gap1: float = plate.left - prev.right
		var gap2: float = after.left - plate.right
		var total: float = after.left - prev.right
		assert_true(total >= RoofGenerator.clear_gap(speed, after.top - prev.top), "속도 %d: 못 건너는 넓이" % speed)
		assert_true(plate.top >= prev.top and plate.top >= after.top, "판 높이는 앞뒤 옥상 중 높은 쪽 이상")
		assert_true(gap1 >= Balance.ROOF_GAP_MIN and gap2 >= Balance.ROOF_GAP_MIN, "판 앞뒤 틈이 최소 간격 이상")
		assert_true(gap1 <= Balance.POLE_GAP_SAFETY * JumpModel.max_reach(speed, plate.top - prev.top) + 0.01, "속도 %d: 첫 점프로 판까지 닿는 범위" % speed)
		assert_true(gap2 <= Balance.POLE_GAP_SAFETY * JumpModel.max_reach(speed, after.top - plate.top) + 0.01, "속도 %d: 판에서 다음까지 닿는 범위" % speed)
		var width: float = plate.right - plate.left
		assert_true(width >= Balance.POLE_WIDTH_MIN - 0.01 and width <= Balance.POLE_WIDTH_START + 0.01, "판 너비 범위")
		assert_true(after.no_ghost, "다음 옥상은 투명화 구제 없음")
		# 판 없이는 어떤 조합으로도 못 건넌다 (투명화 구제도 없음)
		var crossed_without := 0
		for r in _sweep(found, speed, false, false):
			if r.crossed:
				crossed_without += 1
		assert_eq(crossed_without, 0, "속도 %d: 판 없이 건너는 조합" % speed)
		# 판이 있어도 판에 내려앉지 않고 건너는 조합은 없다 (한 번에 못 건넘)
		var crossed_skipping := 0
		var reached_plate := 0
		for r in _sweep(found, speed, true, false):
			if r.plate:
				reached_plate += 1
			if r.crossed and not r.plate:
				crossed_skipping += 1
		assert_eq(crossed_skipping, 0, "속도 %d: 판을 거치지 않고 건넌 조합" % speed)
		assert_true(reached_plate > 0, "속도 %d: 첫 점프로 판에 닿는 조합이 있음" % speed)
		# 판 위 어느 자리에서 시작해도(판 왼쪽 끝~오른쪽 끝), 판에서 다시 뛰어 다음 옥상에 닿는 조합이 있다
		for start in [plate.left, (plate.left + plate.right) * 0.5, plate.right]:
			var crossed_from_plate := 0
			for off in range(-30, int(Balance.CAT_FOOT_HALF + Balance.COYOTE_TIME * speed), 6):
				for hold in [0.12, 0.18, 0.24, JumpModel.max_hold_time()]:
					var sim := _sim(found, speed)
					sim.x = start
					sim.y = plate.top
					sim.set("_ground_roof", sim.roofs[1])
					if _trial(sim, start + float(off), hold, false).crossed:
						crossed_from_plate += 1
			assert_true(crossed_from_plate > 0, "속도 %d: 판 %.0f에서 다시 뛰어 건너는 조합" % [speed, start])


func test_판에서_다음_옥상까지는_판_끝에서_늦게_뛰어도_코요테로_닿는다() -> void:
	# 판 오른쪽 끝에서 발이 떨어진 직후(코요테 시간 안)에 뛰어도 다음 옥상에 닿는 조합이 있어야 한다
	for speed in SPEEDS:
		var found := _find("pole", speed)
		var plate: Dictionary = found.roofs[0]
		var late_x: float = plate.right + Balance.CAT_FOOT_HALF + 1.0  # 발이 막 떨어진 위치
		var crossed := 0
		for hold in [0.18, 0.24, JumpModel.max_hold_time()]:
			var sim := _sim(found, speed)
			sim.x = plate.right
			sim.y = plate.top
			sim.set("_ground_roof", sim.roofs[1])
			# 판 끝에서 발이 떨어진 뒤 코요테 시간 안에 누른다
			if _trial(sim, late_x + speed * Balance.COYOTE_TIME * 0.5, hold, false).crossed:
				crossed += 1
		assert_true(crossed > 0, "속도 %d: 코요테로 뛰어 건넘" % speed)


# --- 배치 ---

func _gen_roofs(seed_value: int, speed: float, count: int) -> Array:
	var gen := RoofGenerator.new(seed_value)
	var roofs := [RoofGenerator.first_roof(0.0)]
	for i in count:
		roofs.append(gen.next_roof(roofs[-1], speed))
	return roofs


func test_특수_틈은_같은_시드면_같다() -> void:
	assert_eq(_gen_roofs(5, 430.0, 200), _gen_roofs(5, 430.0, 200))
	assert_true(_gen_roofs(5, 430.0, 200) != _gen_roofs(6, 430.0, 200), "다른 시드면 다름")


func test_한_틈에_구조물은_최대_하나이고_처음_몇_옥상은_일반_틈() -> void:
	for seed_value in 20:
		var roofs := _gen_roofs(seed_value + 1, 700.0, 150)
		for i in range(1, roofs.size()):
			var roof: Dictionary = roofs[i]
			var prev: Dictionary = roofs[i - 1]
			assert_true(not (roof.get("platform", false) and prev.get("platform", false)), "판이 이어지지 않음")
			assert_true(not (roof.has("line") and prev.get("platform", false)), "한 틈에 줄과 판이 같이 없음")
			if i <= Balance.SPECIAL_GAP_AFTER:
				assert_true(not roof.has("line") and not roof.get("platform", false), "처음 옥상은 일반 틈 (%d)" % i)


func test_속도별로_특수_틈이_눈에_띌_만큼_나온다() -> void:
	for speed in SPEEDS:
		var lines := 0
		var poles := 0
		var total := 0
		for seed_value in 10:
			for roof in _gen_roofs(seed_value + 1, speed, 100):
				total += 1
				if roof.has("line"):
					lines += 1
				if roof.get("platform", false):
					poles += 1
		print("    속도 %d: 옥상 %d개 중 빨래줄 %d (%.0f%%), 전봇대 %d (%.0f%%)" % [speed, total, lines, 100.0 * lines / total, poles, 100.0 * poles / total])
		assert_true(lines * 100 >= total * 5, "속도 %d: 빨래줄 %d/%d" % [speed, lines, total])
		assert_true(poles * 100 >= total * 5, "속도 %d: 전봇대 %d/%d" % [speed, poles, total])


func test_빨래줄_틈_위에_높이_튕겨야_닿는_생선_줄이_있다() -> void:
	var found := _find("line", 700.0)
	var roof: Dictionary = found.roofs[0]
	var placer := ItemPlacer.new(1)
	var items := placer.items_for(found.prev, roof)
	var high := 0
	for item in items:
		if item.kind == "fish" and absf(item.y - (roof.line.top + Balance.LINE_FISH_HEIGHT)) < 0.01:
			high += 1
			assert_true(item.x > roof.line.left and item.x < roof.line.right, "생선은 줄 위")
	assert_true(high >= 3, "줄 위 생선 (%d)" % high)
	# 기본 튕김의 꼭대기(몸 가운데)에서는 안 닿고, 더 높이 튕기면 지나가며 닿는다
	var ellipse_y := Balance.CAT_BODY_SIZE.y * 0.5 + Balance.ITEM_RADIUS
	var normal_top := Balance.LINE_BOUNCE_HEIGHT + Balance.ITEM_LIFT
	var boost_top := Balance.LINE_BOOST_HEIGHT + Balance.ITEM_LIFT
	assert_true(Balance.LINE_FISH_HEIGHT - normal_top > ellipse_y, "기본 튕김으로는 안 닿음")
	assert_true(Balance.LINE_FISH_HEIGHT < boost_top, "더 높이 튕기면 닿음")
