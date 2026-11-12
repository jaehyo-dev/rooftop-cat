extends TestCase
## 구조물(넓은 틈): 빨래줄 누름 판정(창·높이·더블점프 충전·느슨해짐·실림, 은퇴했지만 트램펄린이 같은 판정을 씀),
## 전봇대 판(착지·몸통 판정 없음·투명화 제외·다시 점프), 특수 틈은 점프 + 더블점프로도 못 건너고 판을 거쳐야만 건너는지, 배치.
## 트램펄린(옥상 끝 발사대): 판정 창·높이·발사·생성 수치는 맨 아래 "트램펄린" 부분.

const DT := 1.0 / 120.0
var SPEEDS := stage_speeds()


## 시드를 돌려 kind("tramp"/"pole")인 특수 틈을 처음 찾는다. {"prev": 앞 옥상, "roofs": [다음 옥상] 또는 [판, 다음 옥상]}
func _find(kind: String, speed: float, from_seed: int = 1) -> Dictionary:
	for seed_value in range(from_seed, from_seed + 400):
		var gen := RoofGenerator.new(seed_value)
		var prev := RoofGenerator.first_roof(0.0)
		for i in 80:
			var roof := gen.next_roof(prev, speed)
			if kind == "tramp" and roof.has("tramp"):
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
		if with_structure and roof.has("tramp"):
			sim.structures.append(roof.tramp)
	sim.roofs[-1].right = 100000.0
	sim.set("_ground_roof", prev)
	sim.x = prev.right - 600.0
	sim.y = prev.top
	sim.vy = 0.0
	sim.on_ground = true
	return sim


## sim에서 press_x에 닿으면 hold초 누르고, dj_delay >= 0이면 점프 뒤 dj_delay초에 더블점프(dj_hold초 누름),
## retap이면 줄에 닿기 직전마다 새로 한 번 누른다. 건너거나 떨어지면 일찍 끝낸다.
## 돌려주는 값: fell, bounced(줄 밟음), result(처음 튕긴 판정), ghosted, plate(판에 내려앉음), doubled, crossed(마지막 옥상에 서 있음)
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
		if sim.bounced and not out.has("result"):
			out.result = sim.bounce_result  # 처음 튕긴 판정
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
		dj_delays = pick(dj_delays, 3)  # 평소엔 3개마다 하나 (FULL_TESTS=1이면 19개 전부)
	for off in pick(range(-420, 110, 15), 3):  # 평소엔 45px 간격 (양 끝 포함)
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
		_assert_pole_crossing(found, speed)


func test_속도_단계가_오른_뒤_도착한_전봇대_틈도_판을_거쳐야만_건넌다() -> void:
	for speed in SPEEDS:
		_assert_pole_crossing(_find("pole", speed), RoofGenerator.arrival_speed(speed))


## speed로 달릴 때: 판 없이는 못 건너고, 판을 거쳐야만 건너며, 판 어디서나 다시 뛰어 건널 수 있다
func _assert_pole_crossing(found: Dictionary, speed: float) -> void:
	var plate: Dictionary = found.roofs[0]
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
			assert_true(not (roof.has("tramp") and prev.get("platform", false)), "한 틈에 트램펄린과 판이 같이 없음")
			assert_true(not roof.has("line"), "빨래줄은 은퇴 (생성 안 됨)")
			if i <= Balance.SPECIAL_GAP_AFTER:
				assert_true(not roof.has("tramp") and not roof.get("platform", false), "처음 옥상은 일반 틈 (%d)" % i)


func test_속도별로_특수_틈이_눈에_띌_만큼_나온다() -> void:
	for speed in SPEEDS:
		var tramps := 0
		var poles := 0
		var total := 0
		for seed_value in 10:
			for roof in _gen_roofs(seed_value + 1, speed, 100):
				total += 1
				if roof.has("tramp"):
					tramps += 1
				if roof.get("platform", false):
					poles += 1
		print("    속도 %d: 옥상 %d개 중 트램펄린 %d (%.0f%%), 전봇대 %d (%.0f%%)" % [speed, total, tramps, 100.0 * tramps / total, poles, 100.0 * poles / total])
		assert_true(tramps * 100 >= total * 5, "속도 %d: 트램펄린 %d/%d" % [speed, tramps, total])
		assert_true(poles * 100 >= total * 5, "속도 %d: 전봇대 %d/%d" % [speed, poles, total])


# --- 트램펄린 (옥상 끝 발사대, v0.5.0 2a-2) ---

## 트램펄린 하나만 있는 코스: 앞 옥상(길게) 끝에 트램펄린, 가장 좁은 틈, 다음 옥상(끝없이 길게). 속도 고정
func _tramp_course(speed: float) -> RunnerSim:
	var gen := RoofGenerator.new(1)
	var prev := {"left": -4000.0, "right": 0.0, "top": 150.0}
	var roof: Dictionary = gen.call("_tramp_roof", prev, {"left": 0.0, "right": 500.0, "top": 150.0}, speed, 0.0)
	var found := {"prev": prev, "roofs": [roof]}
	var sim := _sim(found, speed)
	sim.x = roof.tramp.left - 400.0
	return sim


## 달려 들어가며 닿는 순간 기준 offset초에 새로 누른다 (null = 안 누름). dj_after >= 0이면 튕긴 뒤 그만큼 지나 더블점프(최대).
## 돌려주는 값: result, apex(그물 위로), crossed, fell, doubled, jumped(옥상에서 보통 점프를 했는지), fish(먹은 생선 수), sim
func _tramp_run(sim: RunnerSim, offset, dt: float = DT, dj_after: float = -1.0) -> Dictionary:
	var tramp: Dictionary = sim.structures[0]
	var last: Dictionary = sim.roofs[-1]
	var out := {"result": "", "apex": 0.0, "crossed": false, "fell": false, "doubled": false, "jumped": false, "fish": 0, "sim": sim}
	var touch_at: float = sim.elapsed + (RunnerSim.run_in_x(tramp) - sim.x) / sim.speed  # 몸 가운데가 닿는 자리에 오는 시각
	var press_step := -1 if offset == null else roundi((touch_at + offset) / dt)
	var bounced_at := -1.0
	var dj_left := 0
	for i in int(5.0 / dt):
		var pressed := i == press_step
		if bounced_at >= 0.0 and dj_after >= 0.0 and dj_left == 0 and sim.elapsed - bounced_at >= dj_after:
			dj_left = ceili(JumpModel.double_max_hold() / dt) + 1
		if dj_left > 0:
			pressed = true
			dj_left -= 1
			if dj_left == 0:
				dj_left = -1
		sim.step(dt, pressed)
		out.jumped = out.jumped or sim.jumped
		out.doubled = out.doubled or sim.double_jumped
		out.fish = sim.fish
		if sim.bounced and out.result == "":
			out.result = sim.bounce_result
			bounced_at = sim.elapsed
		if bounced_at >= 0.0:
			out.apex = maxf(out.apex, sim.y - tramp.top)
		if sim.game_over:
			out.fell = true
			break
		if sim.on_ground and is_same(sim.get("_ground_roof"), last):
			out.crossed = true
			break
	return out


func test_트램펄린_누름_판정_창은_빨래줄과_같다() -> void:
	# 달려 들어가며 닿는 순간 기준 offset초에 누름 → 판정 (창 경계에서 0.02초 이상 떨어진 값으로)
	var late_good := Balance.LINE_RIDE_TIME - 0.03
	var cases := [[-0.25, "early"], [-0.12, "good"], [-0.02, "perfect"], [0.02, "perfect"], [0.07, "good"], [late_good, "good"], [Balance.LINE_RIDE_TIME + 0.03, "miss"], [null, "miss"]]
	for dt in [1.0 / 60.0, 1.0 / 120.0, 1.0 / 240.0]:
		for c in cases:
			var r := _tramp_run(_tramp_course(600.0), c[0], dt)
			assert_eq(r.result, c[1], "닿기 %s초, 간격 1/%d" % [str(c[0]), roundi(1.0 / dt)])
			if c[1] != "miss":
				assert_true(not r.jumped and not r.doubled, "창 안의 누름은 옥상 점프·더블점프로 새지 않음 (%s)" % str(c[0]))


func test_트램펄린_닿기_전_창보다_이른_누름은_보통_점프() -> void:
	var r := _tramp_run(_tramp_course(600.0), -0.34)
	assert_true(r.jumped, "닿기 0.28초보다 전이면 옥상에서 점프")


func test_트램펄린_튕김_높이는_안누름_누름_퍼펙트() -> void:
	for c in [[null, Balance.TRAMP_MISS_HEIGHT], [-0.12, Balance.TRAMP_GOOD_HEIGHT], [0.0, Balance.TRAMP_PERFECT_HEIGHT]]:
		var r := _tramp_run(_tramp_course(600.0), c[0])
		assert_true(absf(r.apex - c[1]) < 4.0, "%s 튕김 높이 %.1f (기대 %.0f)" % [r.result, r.apex, c[1]])


func test_트램펄린_누름_퍼펙트는_앞으로_발사하고_더블점프를_다시_준다() -> void:
	for c in [[-0.12, "good_vx"], [0.0, "perfect_vx"]]:
		var sim := _tramp_course(600.0)
		sim.set("_double_used", true)
		var tramp: Dictionary = sim.structures[0]
		var r := _tramp_run(sim, c[0])
		assert_true(r.crossed, "%s: 건넘" % r.result)
		assert_true(tramp[c[1]] > 600.0 * 1.5, "발사 속도 %.0f가 달리는 속도보다 빠름" % tramp[c[1]])
		assert_eq(sim.vx(), 600.0, "내려서면 달리는 속도로")
		assert_true(not sim.get("_double_used"), "더블점프 다시 생김")


func test_트램펄린_안누름과_이른_누름은_제자리에서_낮게_튀고_더블점프를_써도_못_건넌다() -> void:
	for speed in SPEEDS:
		for offset in [null, -0.24]:
			for dj in [-1.0, 0.0, 0.1, 0.2, 0.3, 0.4, 0.5]:
				var sim := _tramp_course(speed)
				var tramp: Dictionary = sim.structures[0]
				sim.set("_double_used", false)
				var r := _tramp_run(sim, offset, DT, dj)
				assert_true(r.result == "miss" or r.result == "early", "결과 %s" % r.result)
				assert_true(r.fell and not r.crossed, "속도 %d, %s, 더블점프 %.1f초: 떨어짐" % [speed, r.result, dj])
				assert_true(sim.is_slack(tramp), "다시 받아 주지 않음")


func test_트램펄린_틈은_트램펄린_없이_더블점프까지_다_써도_못_건너고_뛰어넘으면_떨어진다() -> void:
	for speed in SPEEDS:
		var found := _find("tramp", speed)
		assert_true(not found.is_empty(), "속도 %d: 트램펄린 틈이 나옴" % speed)
		var prev: Dictionary = found.prev
		var roof: Dictionary = found.roofs[0]
		assert_eq(roof.top, prev.top, "두 옥상 높이가 같음")
		assert_true(roof.no_ghost, "투명화 구제 없음")
		assert_eq(roof.tramp.right, prev.right - Balance.TRAMP_INSET, "옥상 끝에 놓임")
		assert_eq(roof.tramp.top, prev.top + Balance.TRAMP_LIFT, "그물 높이")
		assert_true(roof.left - prev.right >= RoofGenerator.clear_gap(speed, 0.0), "속도 %d: 못 건너는 넓이" % speed)
		_assert_tramp_needed(found, speed)


func test_속도_단계가_오른_뒤_도착한_트램펄린_틈도_트램펄린을_밟아야만_건넌다() -> void:
	for speed in SPEEDS:
		var found := _find("tramp", speed)
		var v := RoofGenerator.arrival_speed(speed)
		_assert_tramp_needed(found, v)
		_assert_tramp_crossing(found, v)


## speed로 달릴 때: 트램펄린 없이, 또는 뛰어넘어서는 못 건넌다
func _assert_tramp_needed(found: Dictionary, speed: float) -> void:
	var crossed_without := 0
	for r in _sweep(found, speed, false, false, true):
		crossed_without += 1 if r.crossed else 0
	assert_eq(crossed_without, 0, "속도 %d: 트램펄린 없이 건너는 조합" % speed)
	# 트램펄린이 있어도 밟지 않고(뛰어넘음) 건너는 조합은 없다
	var skipped := 0
	for r in _sweep(found, speed, true, false, true):
		skipped += 1 if r.crossed and not r.bounced else 0
	assert_eq(skipped, 0, "속도 %d: 트램펄린을 뛰어넘고 건넌 조합" % speed)


func test_트램펄린을_누르며_밟으면_달려_들어가도_뛰어서_떨어져도_반드시_건넌다() -> void:
	for speed in SPEEDS:
		_assert_tramp_crossing(_find("tramp", speed), speed)


## speed로 달릴 때: 누르며 밟으면 달려 들어가도 뛰어서 떨어져도, 가장 일찍 튕겨도 건넌다
func _assert_tramp_crossing(found: Dictionary, speed: float) -> void:
	# 옥상 끝 근처 여러 자리에서 여러 높이로 뛰어 위에 떨어지거나 달려 들어가며, 닿기 바로 전에 누름
	# (트램펄린 바로 앞에서 길게 누른 손이 닿을 때까지 이어지면 새 누름이 아니라 "early"라 뺀다)
	var stepped := 0
	var failed := 0
	for r in _sweep(found, speed, true, true):
		if r.get("result", "") in ["good", "perfect"]:
			stepped += 1
			failed += 0 if r.crossed else 1
	assert_true(stepped > 20, "속도 %d: 밟은 조합 %d" % [speed, stepped])
	assert_eq(failed, 0, "속도 %d: 누르며 밟고도 못 건넌 조합 (밟은 %d)" % [speed, failed])
	# 가장 일찍 튕기는 자리(위에서 내려와 뒷발 끝만 걸침)에서 누름(퍼펙트 아님)으로 튕겨도 건넌다
	var sim := _sim(found, speed)
	var tramp: Dictionary = sim.structures[0]
	var fall := sqrt(2.0 * 60.0 / Balance.GRAVITY)
	sim.on_ground = false
	sim.set("_jumped", true)
	sim.x = tramp.left - Balance.CAT_FOOT_HALF + 2.0 - speed * fall
	sim.y = tramp.top + 60.0
	var press_step := roundi((fall - 0.1) / DT)
	var result := ""
	for i in int(4.0 / DT):
		sim.step(DT, i == press_step)
		if sim.bounced and result == "":
			result = sim.bounce_result
		if sim.on_ground or sim.game_over:
			break
	assert_eq(result, "good", "속도 %d: 누름" % speed)
	assert_true(sim.on_ground and is_same(sim.get("_ground_roof"), sim.roofs[-1]), "속도 %d: 가장 일찍 튕겨도 건넘 (x %.0f)" % [speed, sim.x])


func test_트램펄린_다음_옥상은_가장_늦게_튕기고_더블점프를_가장_멀리_써도_안_지나친다() -> void:
	for speed in SPEEDS:
		for seed_value in 10:
			for roof in _gen_roofs(seed_value + 1, speed, 120):
				if roof.has("tramp"):
					assert_true(roof.tramp.base <= Balance.TRAMP_TOP_MAX, "트램펄린 옥상 높이 %.0f" % roof.tramp.base)
					assert_true(roof.right >= RoofGenerator.tramp_landing_right(roof.tramp, RoofGenerator.arrival_speed(speed)) - 0.01, "다음 옥상 너비")
		var found := _find("tramp", speed)
		var roof: Dictionary = found.roofs[0]
		var v := RoofGenerator.arrival_speed(speed)
		# 앞발 끝만 걸쳐 내려와 퍼펙트(닿기 바로 전 누름) / 끝까지 실려 있다 누름(늦은 good)
		for c in [["perfect", -1, Balance.TRAMP_PERFECT_HEIGHT], ["good", roundi((Balance.LINE_RIDE_TIME - 0.01) / DT), Balance.TRAMP_GOOD_HEIGHT]]:
			var sim := _sim(found, v)
			sim.roofs[-1].right = roof.right  # 끝없이 늘인 것을 원래 너비로
			var last: Dictionary = sim.roofs[-1]
			sim.on_ground = false
			sim.set("_jumped", true)
			sim.x = roof.tramp.right + Balance.CAT_FOOT_HALF - 1.0 - 2.0 * v * DT  # 첫 step에 앞으로 간 뒤에도 앞발 끝이 걸침
			sim.y = roof.tramp.top + 1.0
			sim.vy = -200.0
			var best := JumpModel.best_double(RoofGenerator.line_bounce_speed(c[2]), 0.0, -Balance.TRAMP_LIFT)
			var ride := -1
			var bounced_at := -1.0
			var dj_left := 0
			for i in int(5.0 / DT):
				var pressed: bool = i == 0 and c[1] < 0
				if sim.is_riding():
					ride += 1
					pressed = ride == c[1]
				if bounced_at >= 0.0 and dj_left == 0 and sim.elapsed - bounced_at >= best.y:
					dj_left = ceili(JumpModel.double_max_hold() / DT) + 1
				if dj_left > 0:
					pressed = true
					dj_left -= 1
					if dj_left == 0:
						dj_left = -1
				sim.step(DT, pressed)
				if sim.bounced:
					assert_eq(sim.bounce_result, c[0], "속도 %d" % speed)
					bounced_at = sim.elapsed
				if sim.landed or sim.game_over:
					break
			assert_true(dj_left != 0 and sim.on_ground and is_same(sim.get("_ground_roof"), last), "속도 %d %s: 다음 옥상 안에 착지 (x=%.0f, 끝 %.0f, 더블점프 %d)" % [speed, c[0], sim.x, last.right, dj_left])


func test_트램펄린_틈은_낮은_옥상에서만_나오고_빨래줄은_안_나온다() -> void:
	for speed in SPEEDS:
		for seed_value in 10:
			for roof in _gen_roofs(seed_value + 1, speed, 120):
				assert_true(not roof.has("line"), "빨래줄 생성 꺼짐")
				if roof.has("tramp"):
					assert_true(roof.top <= Balance.TRAMP_TOP_MAX, "옥상 높이 %.0f" % roof.top)


func test_트램펄린_퍼펙트는_높은_생선_길을_지나고_누름은_못_먹는다() -> void:
	for speed in SPEEDS:
		for c in [[0.0, true], [-0.12, false]]:
			var sim := _tramp_course(speed)
			var fish := ItemPlacer.tramp_fish(sim.structures[0])
			assert_true(fish.size() >= 3, "속도 %d: 생선 길 %d마리" % [speed, fish.size()])
			sim.items.append_array(fish)
			var r := _tramp_run(sim, c[0])
			if c[1]:
				assert_eq(r.fish, fish.size(), "속도 %d 퍼펙트: 생선 길을 다 먹음" % speed)
			else:
				assert_eq(r.fish, 0, "속도 %d 누름: 생선 길은 못 먹음" % speed)


func test_트램펄린_그림은_닿는_순간_밟음_발을_떼면_튕김_그다음_평소로() -> void:
	var world_script := load("res://scripts/world_view.gd")
	for c in [[0.0, "perfect"], [0.07, "good"], [null, "miss"]]:
		var sim := _tramp_course(600.0)
		var tramp: Dictionary = sim.structures[0]
		var touch_at: float = (RunnerSim.run_in_x(tramp) - sim.x) / sim.speed
		var press_step := -1 if c[0] == null else roundi((touch_at + c[0]) / DT)
		var frames: Array[String] = []
		var touched_step := -1
		var bounce_step := -1
		for i in int((touch_at + 1.0) / DT):
			sim.step(DT, i == press_step)
			var look: Dictionary = world_script.tramp_look(sim, tramp)
			frames.append(look.frame)
			if touched_step < 0 and (sim.is_riding() or sim.bounced):
				touched_step = i
			if sim.bounced:
				bounce_step = i
		assert_eq(frames[touched_step - 1], "rest", "%s: 닿기 전 step은 평소" % c[1])
		assert_eq(frames[touched_step], "pressed", "%s: 닿는 step에 밟음" % c[1])
		for i in range(touched_step, bounce_step + 1):
			assert_eq(frames[i], "pressed", "%s: 실려 있는 동안과 튕기는 step은 밟음" % c[1])
		assert_true(frames.slice(bounce_step + 1, bounce_step + 1 + roundi(0.1 / DT)).has("launch"), "%s: 튕긴 뒤 튕김 그림" % c[1])
		assert_eq(frames[-1], "rest", "%s: 출렁인 뒤 평소" % c[1])
	# 퍼펙트는 누름보다 깊게 눌렸다 크게 솟는다
	assert_true(world_script.TRAMP_PRESS_SY.perfect < world_script.TRAMP_PRESS_SY.good, "퍼펙트가 더 깊게 눌림")
	assert_true(world_script.TRAMP_POP_SY.perfect > world_script.TRAMP_POP_SY.good, "퍼펙트가 더 크게 솟음")


func test_트램펄린_밟음_그림의_그물_바닥이_밟은_발_높이() -> void:
	# 밟음 그림에서 가운데 세로줄의 가장 아래 불투명 픽셀(꺼진 그물 바닥)이 다리 끝보다 TRAMP_LIFT(게임 픽셀)만큼 위
	var world_script := load("res://scripts/world_view.gd")
	var img: Image = world_script.TRAMP_TEXTURES.pressed.get_image()
	var cx := int(world_script.TRAMP_SRC_LEFT + world_script.TRAMP_SRC_WIDTH * 0.5)
	var bottom := 0
	for y in img.get_height():
		if img.get_pixel(cx, y).a > 0.5:
			bottom = y
	assert_true(absf(bottom + 1 - world_script.TRAMP_SRC_NET.pressed) <= 2.0, "그물 바닥 줄 %d" % (bottom + 1))
	var net: float = world_script.tramp_height(world_script.TRAMP_SRC_NET.pressed, 1.0)
	var rest: float = world_script.tramp_height(world_script.TRAMP_SRC_NET.rest, 1.0)
	assert_true(net > Balance.TRAMP_LIFT and net < rest * 0.5, "꺼진 그물 %.0f, 평소 그물 %.0f" % [net, rest])
	assert_true(world_script.tramp_height(0.0, 1.0) > Balance.CAT_BODY_SIZE.y, "다리를 늘여 몸보다 큼")


func test_트램펄린_고양이_그림은_폴짝_올라타_그물_깊이를_따라가고_튀어_나간다() -> void:
	var world_script := load("res://scripts/world_view.gd")
	var rest: float = world_script.tramp_height(world_script.TRAMP_SRC_NET.rest, 1.0)
	var sim := _tramp_course(600.0)
	var tramp: Dictionary = sim.structures[0]
	var touch_at: float = (RunnerSim.run_in_x(tramp) - sim.x) / sim.speed
	var press_step := roundi((touch_at + 0.08) / DT)  # 닿고 0.08초 뒤 누름
	var y_before := sim.y
	assert_eq(world_script.tramp_cat_lift(sim), 0.0, "멀리서는 그대로")
	var best := 0.0
	while not sim.is_riding():
		sim.step(DT, false)
		best = maxf(best, world_script.tramp_cat_lift(sim) if sim.on_ground else 0.0)
	assert_true(best > rest * 0.85, "달려 들어가며 그물 위로 폴짝 %.0f (평소 그물 %.0f)" % [best, rest])
	var riding: float = world_script.tramp_cat_lift(sim)
	var expect: float = y_before + world_script.tramp_height(world_script.TRAMP_SRC_NET.pressed, world_script.TRAMP_PRESS_SY.good) - sim.y
	assert_true(absf(riding - expect) < 0.01, "실린 동안 꺼진 그물 깊이 (%.1f)" % riding)
	assert_eq(sim.y, tramp.top, "판정 높이는 그대로")
	var i := int(touch_at / DT)
	while not sim.bounced:
		sim.step(DT, i >= press_step)
		i += 1
	var drawn: float = sim.y + world_script.tramp_cat_lift(sim)
	assert_true(absf(drawn - y_before - world_script.tramp_height(world_script.TRAMP_SRC_NET.pressed, world_script.TRAMP_PRESS_SY[sim.bounce_result])) < 0.01, "튕긴 직후 그림은 그물에")
	for n in int((Balance.TRAMP_PUSH + world_script.TRAMP_RELEASE) / DT) + 2:
		sim.step(DT, false)
	assert_eq(world_script.tramp_cat_lift(sim), 0.0, "튀어 나간 뒤 실제 높이")


func test_효과음은_일어난_일에_맞게_난다() -> void:
	var sim := RunnerSim.new(1)
	assert_eq(SfxEvents.sounds(sim, false), [] as Array[String], "아무 일 없음")
	sim.jumped = true
	assert_eq(SfxEvents.sounds(sim, false), ["jump"] as Array[String])
	sim.jumped = false
	sim.double_jumped = true
	assert_eq(SfxEvents.sounds(sim, false), ["double_jump"] as Array[String])
	sim.double_jumped = false
	sim.landed = true
	assert_eq(SfxEvents.sounds(sim, true), ["land", "fall"] as Array[String])
	sim.landed = false
	sim.bounced = true
	sim.bounce_result = "good"
	assert_eq(SfxEvents.sounds(sim, false), ["boing"] as Array[String])
	sim.bounce_result = "perfect"
	assert_eq(SfxEvents.sounds(sim, false), ["boing", "perfect"] as Array[String])
	sim.bounced = false
	sim.picked.assign([{"kind": "fish"}, {"kind": "fish"}])
	assert_eq(SfxEvents.sounds(sim, false), ["fish"] as Array[String], "한 번만")
	sim.picked.assign([{"kind": "bell"}])
	assert_true(SfxEvents.sounds(sim, false).has("bell"), "방울을 먹으면 딸랑")
	sim.picked.assign([{"kind": "box"}])
	assert_eq(SfxEvents.sounds(sim, false), [] as Array[String], "상자는 소리 없음")


func test_효과음_파일을_모두_불러온다() -> void:
	for sound in SfxEvents.ALL:
		assert_not_null(load("res://assets/audio/sfx/%s.wav" % sound), sound)
