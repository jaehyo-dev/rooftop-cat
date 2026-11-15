extends RefCounted
## 줄줄이 고양이 시험판 캡처 (자동 테스트 아님). 검수용 웹 빌드 주소 ?qa=parade(PC 장면·GIF 프레임) / parade_phone(스틸만) / parade_hit(부딪힘만)
## 이면 tools/qa_web.gd가 이것을 부른다. 창 없이 헤드리스 Chromium(qa_web.mjs)이 qaShot 이름마다 찍는다.
## 판은 자동 조종(생선 길 호대로 누르고, 트램펄린은 닿을 때 톡)으로 120Hz 한 step씩 직접 돌려 같은 시드면 같은 장면.
## GIF 프레임 이름: <장면>_f000… (review/cat-parade/make_gifs.py가 묶음)

const STEP := 1.0 / 120.0
var qa: Node
var main: Control
var world: Node2D
var sim: RunnerSim
var _next := 0
var _flight := {}
var _since := INF
var _manual := Callable()  # 정해진 누르기 (공중제비 장면): 있으면 자동 조종 대신


func run(q: Node, mode: String) -> void:
	qa = q
	if mode == "parade_bare":  # 아기 고양이 시안 합성용 배경: 6마리 줄이 한 옥상 위에 있을 때, 보이게 / 숨겨서 / 주인공까지 숨겨서 세 장
		await _bare()
		return
	if mode == "parade_flip":  # 공중제비만 다시 찍기
		await _flip()
		return
	if mode == "parade_motion":  # 아기 움직임 A·B 비교 (review/cat-parade/motion): 치즈 아기 한 마리
		for m in ["a", "b"]:
			await _motion(m)
		return
	if mode == "parade_hit":  # 부딪힘만 다시 찍기
		await _hit("hit_a")
		return
	if mode == "parade":
		await _meet()
		await _gap("gap6", 8)    # 실제 속도 (15장/초)
		await _gap("gap6_slow", 2)  # 4배 느리게
		await _tramp()
		await _dash()
		await _flip()
		await _hit("hit_a")
	await _flat()
	await _fever()
	await _result()


## 판 시작: 시드 고정, 줄 cats마리
func _start(seed_value: int, cats: int) -> void:
	await qa._make("normal")
	main = qa.main
	world = main.get_node("World")
	main.begin_run()
	await qa._wait(0.2)
	world.set_process(false)
	main.set_process(false)
	world.restart(seed_value)
	sim = world.sim
	sim.parade.fill(cats)
	_next = 0
	_flight = {}
	_since = INF
	_manual = Callable()


## 자동 조종 (tools/capture_fun.gd와 같음): 호대로 누르고, 트램펄린은 닿을 때 톡, 질주 중에는 주기적으로 뛴다
func _pressed() -> bool:
	if _manual.is_valid():
		return _manual.call()
	if sim.dashing:
		return int(sim.elapsed * 1.6) % 2 == 0 and fmod(sim.elapsed * 1.6, 1.0) < 0.45
	var flights: Array[Dictionary] = sim.road.flights
	while _next < flights.size() and flights[_next].press_x < sim.x - 40.0:
		_next += 1
	if _next < flights.size() and sim.x >= flights[_next].press_x - sim.speed / 120.0 and sim.on_ground:
		_flight = flights[_next]
		_next += 1
		_since = 0.0
	var touch := sim.line_touch_eta(0.03)
	if not touch.is_empty() and not sim.is_riding():
		return true
	if _flight.is_empty():
		return false
	var d: float = _flight.double_at
	return _since < _flight.hold or (d >= 0.0 and _since >= d and _since < d + JumpModel.double_max_hold())


func _advance() -> void:
	world.set("_touches", {0: true} if _pressed() else {})
	_since += STEP
	world._process(STEP)


## until가 참이 될 때까지 (최대 limit초) 진행
func _run_until(until: Callable, limit: float = 60.0) -> bool:
	var end := sim.elapsed + limit
	while not until.call() and sim.elapsed < end and not sim.game_over:
		_advance()
	return until.call()


## seconds 동안 every step마다 한 장 (every 8 = 실제 속도 15장/초, 2 = 4배 느리게)
func _clip(name: String, seconds: float, every: int) -> void:
	var steps := int(seconds / STEP)
	var n := 0
	for i in steps:
		_advance()
		if i % every == 0:
			main._process(STEP * every)
			await qa._shot("%s_f%03d" % [name, n])
			n += 1


func _still(name: String) -> void:
	main._process(STEP)
	await qa._shot(name)


func _meet() -> void:
	await _start(3, 2)
	await _run_until(func() -> bool: return sim.elapsed > 3.0)
	sim.parade.call_now()
	await _run_until(func() -> bool: return not sim.parade.strays.is_empty() and sim.parade.strays[0].x - sim.x < 760.0)
	await _clip("meet", 2.2, 8)


## 틈 앞: 서 있는 옥상 끝까지 150~260px, 다음 옥상이 보통 틈(판·트램펄린 아님)
func _gap(name: String, every: int) -> void:
	await _start(5, 6)
	await _run_until(func() -> bool:
		if sim.elapsed < 5.0 or not sim.on_ground:
			return false
		var here := sim.roof_at(sim.x)
		var i := sim.roofs.find(here)
		if here.is_empty() or i + 1 >= sim.roofs.size() or here.has("tramp"):
			return false
		var next: Dictionary = sim.roofs[i + 1]
		return here.right - sim.x < 260.0 and here.right - sim.x > 150.0 and next.left - here.right > 160.0 \
				and not next.get("platform", false) and sim.obstacles.all(func(o: Dictionary) -> bool: return o.x > here.right or o.x + o.w < sim.x - 700.0))
	await _clip(name, 2.6, every)


func _tramp() -> void:
	await _start(12, 6)  # 시드 12: 33초쯤 첫 트램펄린을 자동 조종이 건넘
	await _run_until(func() -> bool:
		return sim.elapsed > 5.0 and sim.structures.any(func(s: Dictionary) -> bool: return s.kind == "tramp" and s.left - sim.x < 380.0 and s.left - sim.x > 200.0), 120.0)
	await _clip("tramp6", 3.0, 8)


func _dash() -> void:
	await _start(5, 6)
	await _run_until(func() -> bool: return sim.elapsed > 5.0 and sim.on_ground)
	sim.items.append({"kind": "dash", "x": sim.x + 40.0, "y": sim.y + 40.0})
	var top := sim.y
	sim.obstacles.append({"id": 990, "kind": "pot", "x": sim.x + 700.0, "w": 60.0, "y0": top, "y1": top + 70.0, "base": top})
	await _clip("dash6", 3.0, 8)


## 6마리가 모두 같은 옥상 땅 위를 달릴 때까지 (맨 뒤 아기까지 같은 옥상, 줄 앞 장애물 없음)
func _run_flat(ahead: float = 500.0) -> void:
	await _run_until(func() -> bool:
		var here := sim.roof_at(sim.x)
		var back := CatParade.slot_x(Balance.PARADE_MAX - 1, sim.x) - 60.0
		return sim.elapsed > 5.0 and sim.on_ground and not sim.dashing and sim.invuln_time <= 0.0 and not here.is_empty() and here.left < back and here.right - sim.x > ahead \
				and sim.obstacles.all(func(o: Dictionary) -> bool: return o.x > sim.x + ahead or o.x + o.w < back - 100.0) \
				and range(Balance.PARADE_MAX).all(func(i: int) -> bool: return absf(sim.parade.follower(i, sim.x).y - sim.y) < 1.0), 120.0)


## 평지 6마리 줄 (PC·폰 스틸)
func _flat() -> void:
	await _start(5, 6)
	await _run_flat()
	await _still("flat6")


## 공중제비: 긴 옥상 위에서 한 번 뛰고 꼭대기 전에 다시 눌러 더블점프(앞구르기). 줄이 차례로 따라 구름
func _flip() -> void:
	await _start(5, 6)
	await _run_flat(1000.0)  # 앞구르기 뒤 착지까지 같은 옥상 (틈에 빠지지 않게)
	var t0 := sim.elapsed
	_manual = func() -> bool:
		var t := sim.elapsed - t0
		return t < 0.12 or (t > 0.4 and t < 0.55)
	await _clip("flip6", 1.5, 8)
	_manual = Callable()


## 합성 배경: 보이게 / 아기 숨김 / 주인공까지 숨김
func _bare() -> void:
	await _start(5, 6)
	await _run_flat()
	await _still("bare_with")
	for i in Balance.PARADE_MAX:
		world.get_node("Parade%d" % i).visible = false
	world.queue_redraw()
	await qa._wait(0.1)
	await _still("bare")
	world.cat.visible = false  # 주인공까지 숨긴 배경 (합성 때 주인공을 아기 고양이 위에 다시 얹으려고)
	world.queue_redraw()
	await qa._wait(0.1)
	await _still("bare_none")


## 부딪힘: 앞으로 누를 호가 한동안 없을 때 바로 앞에 화분을 놓아 맞게 한다
func _hit(name: String) -> void:
	await _start(5, 6)
	await _run_until(func() -> bool:
		var flights: Array[Dictionary] = sim.road.flights
		var here := sim.roof_at(sim.x)
		return sim.elapsed > 5.0 and sim.on_ground and not here.is_empty() and here.right - sim.x > 700.0 \
				and (_next >= flights.size() or flights[_next].press_x - sim.x > 700.0), 120.0)
	sim.obstacles.append({"id": 991, "kind": "pot", "x": sim.x + 380.0, "w": 60.0, "y0": sim.y, "y1": sim.y + 70.0, "base": sim.y})
	await _clip(name, 2.0, 8)


## 피버 + HUD 6마리 (긴 콤보·점수)
func _fever() -> void:
	await _start(5, 6)
	await _run_until(func() -> bool: return sim.elapsed > 6.0 and sim.on_ground)
	for i in 40:
		sim.combo.eat(Balance.FISH_POINTS)
	for i in 30:
		_advance()
	await _still("fever_hud6")


func _result() -> void:
	await _start(5, 6)
	await _run_until(func() -> bool: return sim.elapsed > 4.0)
	world.set_process(true)
	main.set_process(true)
	qa._fall()
	await qa._wait(Balance.RESTART_DELAY + Juice.COUNT_UP_EACH * 4.0 + 1.5)
	await qa._shot("result6")


## 아기 움직임 비교: 평지·틈 점프·착지·도망을 실제 속도(4 step마다 = 30장/초)와 4배 느리게(2 step마다, 15장/초로 묶음), 만남은 실제 속도만
## 프레임 이름: motion_<a|b>_<장면>_<real|slow>_f000…
func _motion(m: String) -> void:
	for clip in [["flat", 2.0], ["gap", 2.6], ["flee", 1.8]]:
		for speed in [["real", 4], ["slow", 2]]:
			await _motion_start(m)
			match clip[0]:
				"flat": await _motion_flat()
				"gap": await _motion_gap()
				_: await _motion_flee()
			await _clip("motion_%s_%s_%s" % [m, clip[0], speed[0]], clip[1], speed[1])
	await _motion_start(m)
	await _run_until(func() -> bool: return sim.elapsed > 3.0 and sim.on_ground)
	sim.parade.cats.clear()
	await _run_until(func() -> bool: return _plain())
	sim.parade.call_now()
	await _run_until(func() -> bool: return not sim.parade.strays.is_empty() and sim.parade.strays[0].x - sim.x < 700.0)
	sim.parade.strays[0].look = "cheese"
	await _clip("motion_%s_meet_real" % m, 2.4, 4)


func _motion_start(m: String) -> void:
	await _start(5, 1)
	world.kitten_motion = m
	sim.parade.set("_next_meet", INF)  # 다른 길고양이가 붙지 않게 (치즈 아기 한 마리만)


## 장면 조건 공통: 주인공이 투명화·무적·질주가 아님 (흐리거나 번쩍이지 않게)
func _plain() -> bool:
	return sim.ghost_time <= 0.0 and sim.invuln_time <= 0.0 and not sim.dashing


## 주인공과 아기가 같은 긴 옥상 땅 위, 앞에 장애물 없음
func _motion_flat() -> void:
	await _run_until(func() -> bool:
		var here := sim.roof_at(sim.x)
		var back := CatParade.slot_x(0, sim.x) - 80.0
		return sim.elapsed > 5.0 and sim.on_ground and _plain() and not here.is_empty() and here.left < back and here.right - sim.x > 900.0 \
				and sim.obstacles.all(func(o: Dictionary) -> bool: return o.x > sim.x + 900.0 or o.x + o.w < back - 100.0) \
				and absf(sim.parade.follower(0, sim.x).y - sim.y) < 1.0, 120.0)


## 틈 앞 (_gap과 같은 조건)
func _motion_gap() -> void:
	await _run_until(func() -> bool:
		if sim.elapsed < 5.0 or not sim.on_ground or not _plain():
			return false
		var here := sim.roof_at(sim.x)
		var i := sim.roofs.find(here)
		if here.is_empty() or i + 1 >= sim.roofs.size() or here.has("tramp"):
			return false
		var next: Dictionary = sim.roofs[i + 1]
		return here.right - sim.x < 260.0 and here.right - sim.x > 150.0 and next.left - here.right > 160.0 \
				and not next.get("platform", false) and sim.obstacles.all(func(o: Dictionary) -> bool: return o.x > here.right or o.x + o.w < sim.x - 700.0))


## 부딪힘 직전: 앞 옥상이 길 때 바로 앞에 화분 (아기가 놀라 도망)
func _motion_flee() -> void:
	await _run_until(func() -> bool:
		var flights: Array[Dictionary] = sim.road.flights
		var here := sim.roof_at(sim.x)
		return sim.elapsed > 5.0 and sim.on_ground and _plain() and not here.is_empty() and here.right - sim.x > 700.0 and here.left < CatParade.slot_x(0, sim.x) - 300.0 \
				and (_next >= flights.size() or flights[_next].press_x - sim.x > 700.0), 120.0)
	sim.obstacles.append({"id": 991, "kind": "pot", "x": sim.x + 200.0, "w": 60.0, "y0": sim.y, "y1": sim.y + 70.0, "base": sim.y})
