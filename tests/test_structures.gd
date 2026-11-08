extends TestCase
## 구조물(넓은 틈): 빨래줄 누름 판정(창·높이·더블점프 충전·느슨해짐·실림), 전봇대 판(착지·몸통 판정 없음·투명화 제외·다시 점프),
## 특수 틈은 점프 + 더블점프로도 못 건너고 줄·판을 거쳐야만 건너는지, 속도별로 항상 건널 수 있는 범위인지, 배치.

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


## sim에서 press_x에 닿으면 hold초 누르고, dj_delay >= 0이면 점프 뒤 dj_delay초에 더블점프(dj_hold초 누름),
## retap이면 줄에 닿기 직전마다 새로 한 번 누른다. 건너거나 떨어지면 일찍 끝낸다.
## 돌려주는 값: fell, bounced(줄 밟음), ghosted, plate(판에 내려앉음), doubled, crossed(마지막 옥상에 서 있음)
func _trial(sim: RunnerSim, press_x: float, hold: float, retap: bool, dj_delay: float = -1.0, dj_hold: float = 1.0, seconds: float = 6.0) -> Dictionary:
	var out := {"fell": false, "bounced": false, "ghosted": false, "plate": false, "doubled": false}
	var hold_left := 0.0
	var dj_left := 0.0
	var jumped_at := -1.0
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
		elif jumped_at >= 0.0 and dj_delay >= 0.0 and sim.elapsed - jumped_at >= dj_delay and dj_left >= 0.0:
			if dj_left == 0.0:
				dj_left = minf(dj_hold, JumpModel.double_max_hold()) + DT
			pressed = dj_left > 0.0
			dj_left -= DT
			if dj_left <= 0.0:
				dj_left = -1.0
		elif retap and not sim.structures.is_empty():
			var touch := sim.line_touch_eta(DT * 1.5)
			pressed = not touch.is_empty() and not sim.is_riding()  # 닿기 바로 전 step에 새로 누른다 (퍼펙트)
		sim.step(DT, pressed)
		if sim.jumped and jumped_at < 0.0:
			jumped_at = sim.elapsed - DT
		out.bounced = out.bounced or sim.bounced
		out.ghosted = out.ghosted or sim.ghosted
		out.doubled = out.doubled or sim.double_jumped
		if sim.landed and sim.get("_ground_roof").get("platform", false):
			out.plate = true
		if sim.game_over:
			out.fell = true
			break
		if sim.on_ground and is_same(sim.get("_ground_roof"), last):
			break
	out.crossed = sim.on_ground and is_same(sim.get("_ground_roof"), last)
	return out


## 앞 옥상 끝 근처에서 뛰는 (누르는 위치 x 누르는 시간) 조합을 돌린다. with_double이면 더블점프(최대) 누르는 때도 훑는다
## (점프 뒤 0.1초 ~ 1.0초, 줄·판 없이 "완벽한 입력"으로도 못 건너는지 확인용). 돌려주는 값: 각 결과의 배열
func _sweep(found: Dictionary, speed: float, with_structure: bool, retap: bool, with_double: bool = false) -> Array:
	var results: Array = []
	var edge: float = found.prev.right
	var holds := [JumpModel.max_hold_time(), JumpModel.max_hold_time() * 0.6] if with_double else [0.0, 0.06, 0.12, 0.18, 0.24, JumpModel.max_hold_time()]
	var dj_delays := [-1.0]
	if with_double:
		dj_delays = []
		for k in 19:
			dj_delays.append(0.1 + k * 0.05)
	for off in range(-420, 110, 15):
		for hold in holds:
			for dj in dj_delays:
				var sim := _sim(found, speed, with_structure)
				results.append(_trial(sim, edge + float(off), hold, retap, dj))
	return results


# --- 빨래줄: 닿을 때마다 누름 타이밍 판정 ---

const DROP := 250.0  # 줄 위 이 높이에서 가만히 떨어뜨린다 (닿기까지 약 0.40초)


## 제자리(속도 0)에서 줄 위로 떨어뜨리고, 닿는 순간 + offset초에 새로 한 번 누른다 (offset 음수 = 닿기 전).
## 돌려주는 값: result(판정), apex(줄 위로 튕긴 높이), doubled(더블점프를 썼는지), sim
## start_used: 더블점프를 이미 쓴 상태에서 시작
func _line_press(offset: float, dt: float = DT, hold_press: bool = false, start_used: bool = false) -> Dictionary:
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
	sim.set("_jumped", true)
	sim.set("_double_used", start_used)
	sim.vy = 0.0
	sim.y = line.top + DROP
	var touch_time := sqrt(2.0 * DROP / Balance.GRAVITY)
	var press_step := roundi((touch_time + offset) / dt)
	var out := {"result": "", "apex": 0.0, "doubled": false, "sim": sim}
	var seen := false
	for i in int(1.5 / dt):
		var pressed := i == press_step or (hold_press and i >= press_step)
		sim.step(dt, pressed)
		out.doubled = out.doubled or sim.double_jumped
		if sim.bounced and not seen:
			seen = true
			out.result = sim.bounce_result
		if seen:
			out.apex = maxf(out.apex, sim.y - line.top)
			if sim.vy < 0.0:
				break
	return out


func test_줄_누름_판정_창_퍼펙트_누름_이름_안누름() -> void:
	# 닿는 순간 기준 offset초에 누름 → 판정 (창 경계에서 0.02초 이상 떨어진 값으로)
	var late_good := Balance.LINE_RIDE_TIME - 0.03
	var cases := [[-0.25, "early"], [-0.12, "good"], [-0.02, "perfect"], [0.02, "perfect"], [0.07, "good"], [late_good, "good"], [Balance.LINE_RIDE_TIME + 0.03, "miss"]]
	for dt in [1.0 / 60.0, 1.0 / 120.0, 1.0 / 240.0]:
		for c in cases:
			var r := _line_press(c[0], dt)
			assert_eq(r.result, c[1], "닿기 %+.2f초, 간격 1/%d" % [c[0], roundi(1.0 / dt)])
			if c[1] != "miss":  # (miss는 튕긴 뒤에 누른 것이라 그 누름이 더블점프가 됨)
				assert_true(not r.doubled, "줄 창 안의 누름은 더블점프로 새지 않음 (%+.2f)" % c[0])


func test_줄_튕김_높이는_안누름_누름_퍼펙트() -> void:
	for c in [[9.0, Balance.LINE_MISS_HEIGHT], [-0.12, Balance.LINE_GOOD_HEIGHT], [0.0, Balance.LINE_PERFECT_HEIGHT]]:
		var r := _line_press(c[0])
		assert_true(absf(r.apex - c[1]) < 3.0, "%s 튕김 높이 %.1f (기대 %.0f)" % [r.result, r.apex, c[1]])


func test_줄_창보다_이른_누름은_더블점프가_된다() -> void:
	var r := _line_press(-0.34)
	assert_true(r.doubled, "닿기 0.28초보다 전이면 더블점프")


func test_계속_누르고_있던_손은_줄_누름으로_안_친다() -> void:
	var r := _line_press(-0.34, DT, true)  # 닿기 전부터 쭉 누르고 있음 (처음 누를 때 더블점프)
	assert_eq(r.result, "miss", "새로 누르지 않았으니 안 누름")


func test_줄_누름_퍼펙트는_더블점프를_다시_주고_실패는_안_준다() -> void:
	for c in [[0.0, false], [-0.12, false], [9.0, true], [-0.25, true]]:
		var r := _line_press(c[0], DT, false, true)
		var sim: RunnerSim = r.sim
		assert_eq(sim.get("_double_used"), c[1], "%s 뒤 더블점프 다 씀 = %s" % [r.result, str(c[1])])


func test_실패하면_줄이_느슨해져_다시_받아_주지_않는다() -> void:
	var r := _line_press(9.0)
	var sim: RunnerSim = r.sim
	assert_eq(r.result, "miss")
	assert_true(sim.is_slack(sim.structures[0]), "느슨해짐")
	var bounced_again := false
	for i in 240:
		sim.step(DT, false)
		bounced_again = bounced_again or sim.bounced
	assert_true(not bounced_again and sim.y < sim.structures[0].top, "줄을 지나 떨어짐")


func test_줄에_실린_동안_발이_다음_옥상에_걸치면_바로_착지() -> void:
	var sim := RunnerSim.new(1)
	sim.accelerate = false
	sim.items.clear()
	sim.structures.clear()
	sim.roofs.clear()
	sim.roofs.append({"left": -2000.0, "right": 0.0, "top": 100.0})
	sim.roofs.append({"left": 300.0, "right": 5000.0, "top": 100.0, "no_ghost": true})
	sim.structures.append({"kind": "line", "left": 0.0, "right": 300.0, "top": 160.0, "base": 100.0})
	sim.speed = 600.0
	sim.on_ground = false
	sim.set("_jumped", true)
	sim.x = 300.0 - Balance.CAT_FOOT_HALF - 6.0  # 닿고 나서 몇 step 뒤에 앞발이 다음 옥상에 걸침
	sim.y = 162.0
	sim.vy = -300.0
	var rode := false
	for i in 30:
		sim.step(DT, false)
		rode = rode or sim.is_riding()
		if sim.on_ground:
			break
	assert_true(rode, "줄에 실렸음")
	assert_true(sim.on_ground and sim.y == 100.0 and not sim.bounced, "다음 옥상에 바로 착지")


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
	sim.y = 90.0   # 다음 옥상보다도 아래: 구제 없이 떨어짐 (더블점프도 이미 씀)
	sim.set("_double_used", true)
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

func test_빨래줄_틈은_더블점프까지_다_써도_못_건너고_줄을_누르며_밟으면_반드시_건넌다() -> void:
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
		# 줄이 없으면 누르는 위치·시간·더블점프 때 어느 조합으로도 못 건넌다
		var crossed_without := 0
		var doubled := 0
		for r in _sweep(found, speed, false, false, true):
			if r.crossed:
				crossed_without += 1
			if r.doubled:
				doubled += 1
		assert_true(doubled > 0, "속도 %d: 더블점프를 쓴 조합이 있음" % speed)
		assert_eq(crossed_without, 0, "속도 %d: 줄 없이 건너는 조합" % speed)
		# 줄이 있으면: 줄에 닿을 때마다 눌러 튕긴 조합은 전부 건너 서 있다
		var stepped := 0
		var failed := 0
		for r in _sweep(found, speed, true, true):
			if r.bounced:
				stepped += 1
				if not r.crossed:
					failed += 1
		assert_true(stepped > 0, "속도 %d: 줄을 밟은 조합이 있음" % speed)
		assert_eq(failed, 0, "속도 %d: 줄을 누르며 밟고도 못 건넌 조합 (밟은 %d)" % [speed, stepped])


func test_줄_틈은_낮은_옥상에서만_나오고_다음_옥상은_퍼펙트와_더블점프로도_안_지나친다() -> void:
	for speed in SPEEDS:
		for seed_value in 10:
			for roof in _gen_roofs(seed_value + 1, speed, 120):
				if roof.has("line"):
					assert_true(roof.line.base <= Balance.LINE_TOP_MAX, "줄 틈 옥상 높이 %.0f" % roof.line.base)
					assert_true(roof.right - roof.left >= RoofGenerator.line_landing_width(RoofGenerator.arrival_speed(speed)) - 0.01, "다음 옥상 너비")
		# 실제로: 줄 끝에서 퍼펙트로 튕기고 가장 멀리 가는 때에 더블점프해도 다음 옥상 안에 내려앉는다
		var found := _find("line", speed)
		var roof: Dictionary = found.roofs[0]
		var sim := _sim(found, RoofGenerator.arrival_speed(speed))
		sim.roofs[-1].right = roof.right  # 끝없이 늘인 것을 원래 너비로
		var last: Dictionary = sim.roofs[-1]
		sim.on_ground = false
		sim.set("_jumped", true)
		sim.x = roof.line.right - Balance.CAT_FOOT_HALF - 1.0  # 줄 끝 (앞발이 다음 옥상에 걸치기 직전)
		sim.y = roof.line.top + 1.0
		sim.vy = -200.0
		var best := JumpModel.best_double(RoofGenerator.line_bounce_speed(Balance.LINE_PERFECT_HEIGHT), 0.0, -Balance.LINE_HEIGHT)
		var bounced_at := -1.0
		var dj_done := false
		for i in 600:
			var pressed := i == 0
			if bounced_at >= 0.0 and not dj_done and sim.elapsed - bounced_at >= best.y:
				pressed = true
				dj_done = true
			elif dj_done and sim.is_holding():
				pressed = true
			sim.step(DT, pressed)
			if sim.bounced:
				assert_eq(sim.bounce_result, "perfect", "속도 %d" % speed)
				bounced_at = sim.elapsed
			if sim.landed or sim.game_over:
				break
		assert_true(dj_done and sim.on_ground and is_same(sim.get("_ground_roof"), last), "속도 %d: 다음 옥상 안에 착지 (x=%.0f, 끝 %.0f)" % [speed, sim.x, last.right])


func test_전봇대_틈은_더블점프까지_써도_판_없이_못_건너고_판을_거쳐_갈_수_있다() -> void:
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
		assert_true(gap1 <= RoofGenerator.pole_gap_max(speed, plate.top - prev.top) + 0.01, "속도 %d: 점프 + 더블점프로 판까지 닿는 범위" % speed)
		assert_true(gap2 <= RoofGenerator.pole_gap_max(speed, after.top - plate.top) + 0.01, "속도 %d: 판에서 다음까지 닿는 범위" % speed)
		var width: float = plate.right - plate.left
		assert_true(width >= Balance.POLE_WIDTH_MIN - 0.01 and width <= Balance.POLE_WIDTH_START + 0.01, "판 너비 범위")
		assert_true(after.no_ghost, "다음 옥상은 투명화 구제 없음")
		# 판 없이는 더블점프까지 어떤 조합으로도 못 건넌다 (투명화 구제도 없음)
		var crossed_without := 0
		for r in _sweep(found, speed, false, false, true):
			if r.crossed:
				crossed_without += 1
		assert_eq(crossed_without, 0, "속도 %d: 판 없이 건너는 조합" % speed)
		# 판이 있어도 판에 내려앉지 않고 건너는 조합은 없다 (한 번에 못 건넘). 점프 + 더블점프로 판에 닿는 조합은 있다
		var crossed_skipping := 0
		var reached_plate := 0
		for r in _sweep(found, speed, true, false, true):
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
					# 판에 서면 더블점프가 다시 생김: 첫 점프 꼭대기 무렵 더블점프
					if _trial(sim, start + float(off), hold, false, hold + JumpModel.jump_speed() / Balance.GRAVITY).crossed:
						crossed_from_plate += 1
			assert_true(crossed_from_plate > 0, "속도 %d: 판 %.0f에서 다시 뛰어 건너는 조합" % [speed, start])


func test_판_앞뒤_틈은_화면에_보이는_거리_이하() -> void:
	for speed in SPEEDS + [Balance.SPEED_MAX]:
		var poles := 0
		for seed_value in 15:
			var roofs := _gen_roofs(seed_value + 1, speed, 120)
			for i in range(1, roofs.size() - 1):
				if roofs[i].get("platform", false):
					poles += 1
					assert_true(roofs[i].left - roofs[i - 1].right <= Balance.POLE_GAP_VIEW_MAX + 0.01, "속도 %d: 판 앞 틈" % speed)
					assert_true(roofs[i + 1].left - roofs[i].right <= Balance.POLE_GAP_VIEW_MAX + 0.01, "속도 %d: 판 뒤 틈" % speed)
		assert_true(poles > 0, "속도 %d: 전봇대가 나옴 (%d)" % [speed, poles])


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
			# 판 끝에서 발이 떨어진 뒤 코요테 시간 안에 누른다 (꼭대기 무렵 더블점프)
			if _trial(sim, late_x + speed * Balance.COYOTE_TIME * 0.5, hold, false, hold + JumpModel.jump_speed() / Balance.GRAVITY).crossed:
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


func test_빨래줄_틈_위에_퍼펙트와_더블점프로_닿는_생선_줄이_있다() -> void:
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
	# 퍼펙트 튕김의 꼭대기(몸 가운데)에서는 안 닿고, 퍼펙트 + 더블점프면 지나가며 닿는다
	var ellipse_y := Balance.CAT_BODY_SIZE.y * 0.5 + Balance.ITEM_RADIUS
	var perfect_top := Balance.LINE_PERFECT_HEIGHT + Balance.ITEM_LIFT
	var double_top := Balance.LINE_PERFECT_HEIGHT + Balance.DOUBLE_JUMP_MAX_HEIGHT + Balance.ITEM_LIFT
	assert_true(Balance.LINE_FISH_HEIGHT - perfect_top > ellipse_y, "퍼펙트만으로는 안 닿음")
	assert_true(Balance.LINE_FISH_HEIGHT < double_top, "퍼펙트 + 더블점프면 닿음")
