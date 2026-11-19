extends RefCounted
## 아기 고양이 무리 + 액션 시험판 캡처 (자동 테스트 아님, review/cat-parade/action/). 검수용 웹 빌드 주소 ?qa=parade_action(영상 프레임)
## / parade_still(정지 화면, PC·폰) / parade_size(아기 크기 비교) / parade_form-<chain|fairy>(아기 배치 영상) / parade_formstill(배치 정지 화면)이면 tools/qa_web.gd가 이것을 부른다. 창 없이 헤드리스 Chromium(review/cat-parade/qa_web.mjs)이 qaShot 이름마다 찍는다.
## 판은 120Hz 한 step씩 직접 돌려 같은 시드면 같은 장면. 장면마다 긴 평지 옥상을 찾아 그 앞에 장애물을 놓고 자동 조종(pilot)으로 넘는다.
## 영상 프레임 이름: act_<장면>_<real|slow>_f000… (review/cat-parade/action/make_videos.py가 mp4로 묶음)

const STEP := 1.0 / 120.0
const SPEED := 600.0  # 장면 속도 (고정, 단계 3쯤)
var qa: Node
var main: Control
var world: Node2D
var sim: RunnerSim
var _pilot := Callable()   # step마다 [점프 누름, 슬라이딩 누름]
var _memo := {}            # 자동 조종 상태


func run(q: Node, mode: String) -> void:
	qa = q
	if mode == "parade_still":
		await _stills()
		return
	if mode == "parade_size":
		await _sizes()
		return
	if mode.begins_with("parade_form"):
		await _formation(mode)
		return
	await _action(mode.split("-").slice(1))  # parade_action-stomp-slide = 그 장면만


## 판 시작: 시드 고정, 아기 cats마리, 길고양이 안 나옴
func _start(seed_value: int, cats: int) -> void:
	await qa._make("normal")
	main = qa.main
	world = main.get_node("World")
	main.begin_run()
	var dev: Node = main.get_node_or_null("ParadeDev")
	if dev:
		dev.visible = false  # 로컬 시험 단추가 아기를 가리지 않게
	await qa._wait(0.2)
	world.set_process(false)
	main.set_process(false)
	world.restart(seed_value)
	sim = world.sim
	sim.parade.fill(cats)
	sim.parade.set("_next_meet", INF)
	_pilot = func() -> Array: return [_road(), _road_slide()]  # 장면 자리를 찾는 동안은 생선 길대로 뛰고 간판은 슬라이딩
	_memo = {"next": 0, "from": -INF, "flight": {}}


## 생선 길 자동 조종 (예전 tools/capture_fun.gd와 같음): 호대로 누르고, 트램펄린은 닿을 때 톡. 간판 밑은 슬라이딩 (_road_slide)
func _road() -> bool:
	if sim.dashing:
		return fmod(sim.elapsed * 1.6, 2.0) < 0.45
	var flights: Array[Dictionary] = sim.road.flights
	while _memo.next < flights.size() and flights[_memo.next].press_x < sim.x - 40.0:
		_memo.next += 1
	if _memo.next < flights.size() and sim.x >= flights[_memo.next].press_x - sim.speed / 120.0 and sim.on_ground:
		_memo.flight = flights[_memo.next]
		_memo.next += 1
		_memo.from = sim.elapsed
	var touch := sim.line_touch_eta(0.03)
	if not touch.is_empty() and not sim.is_riding():
		return true
	var f: Dictionary = _memo.flight
	if f.is_empty():
		return false
	var d: float = f.double_at
	var t: float = sim.elapsed - _memo.from  # 판 시간 기준 (화면 멈칫 동안은 판도 멈춤)
	return t < f.hold or (d >= 0.0 and t >= d and t < d + JumpModel.double_max_hold())


func _road_slide() -> bool:
	return sim.obstacles.any(func(o: Dictionary) -> bool:
		return o.kind == "sign" and sim.front() >= o.x - 0.25 * sim.vx() and sim.x - Balance.CAT_BODY_SIZE.x * 0.5 <= o.x + o.w)


func _advance() -> void:
	var input: Array = _pilot.call()
	var touches := {}
	if input[0]:
		touches[0] = "jump"
	if input[1]:
		touches[1] = "slide"
	world.set("_touches", touches)
	world._process(STEP)


## until가 참이 될 때까지 (최대 limit초) 진행
func _run_until(until: Callable, limit: float = 60.0) -> bool:
	var end := sim.elapsed + limit
	while not until.call() and sim.elapsed < end and not sim.game_over:
		_advance()
	return until.call()


## seconds 동안 every step마다 한 장 (4 = 30장/초 실제 속도, 2 = 묶어서 4배 느리게)
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


## 장면 자리: 땅 위(앞 300px에 장애물 없음)에 서면 지금 옥상을 앞으로 ahead + 600 늘이고 뒤 옥상·장애물·아이템을 치움
## (긴 빈 옥상은 드물어 기다리면 판이 끝남. 다음 옥상은 생성기가 늘인 옥상 뒤에 이어 만든다)
func _run_flat(ahead: float) -> void:
	await _run_until(func() -> bool:
		var here := sim.roof_at(sim.x)
		return sim.elapsed > 3.0 and sim.on_ground and not sim.dashing and sim.invuln_time <= 0.0 and not here.is_empty() and not here.has("tramp") \
				and not here.get("platform", false) and here.left < sim.x - 300.0 \
				and sim.obstacles.all(func(o: Dictionary) -> bool: return o.x > sim.x + 300.0 or o.x + o.w < sim.x - 300.0), 200.0)
	var here := sim.roof_at(sim.x)
	sim.roofs.resize(sim.roofs.find(here) + 1)
	here.right = sim.x + ahead + 600.0
	sim.obstacles = sim.obstacles.filter(func(o: Dictionary) -> bool: return o.x + o.w < sim.x - 300.0)
	sim.structures = sim.structures.filter(func(st: Dictionary) -> bool: return st.right < sim.x - 300.0)
	sim.items = sim.items.filter(func(item: Dictionary) -> bool: return item.x < sim.x)
	world.set("_roof_looks", {})  # 늘인 옥상 그림을 다시 그리게


## 장애물 하나를 몸 가운데 앞 ahead의 옥상 위에 놓음
func _put(kind: String, ahead: float, id: int) -> Dictionary:
	var info: Dictionary = Balance.OBSTACLES[kind]
	var top: float = sim.roof_at(sim.x + ahead).top  # 옥상 높이 (주인공이 뛰는 중이어도)
	var o := {"id": id, "kind": kind, "x": sim.x + ahead, "w": info.w, "y0": top + info.y0, "y1": top + info.y1, "base": top}
	if kind == "flock":
		o.k = Balance.FLOCK_SPEED / sim.vx()
	sim.obstacles.append(o)
	return o


## 밟기: tools/qa_stomp_plan.gd가 같은 속도·같은 상대 자리로 찾은 입력을 step마다 그대로 재생
func _stomp_scene(layout: Array) -> void:
	for i in layout.size():
		_put(layout[i][0], layout[i][1], 800 + i)
	var inputs: Array = load("res://tools/qa_stomp_plan.gd").plan(layout, SPEED)
	var from := sim.elapsed
	_pilot = func() -> Array:
		var i := roundi((sim.elapsed - from) / STEP)  # 판 step 수 (화면 멈칫 동안은 판도 멈춤)
		return inputs[i] if i < inputs.size() else [false, false]


## 영상: 떠다니는 6마리(평지·점프·더블점프·비둘기 밑), 연속 밟기, 세 능력, 피격, 만남, 슬라이딩 3장면
## 실제 속도(4 step마다 = 30장/초)와 4배 느리게(2 step마다, 15장/초로 묶음)
func _action(only: Array) -> void:
	var clips := [["float_flat", 1.4], ["float_jump", 1.6], ["float_double", 1.8], ["float_flock", 2.0], ["stomp", 4.6],
			["punch", 1.6], ["fetch", 1.6], ["sparkle", 1.8], ["hit", 2.0], ["meet", 2.2],
			["slide_sign", 2.2], ["dive_stomp", 2.6], ["dive_slide", 2.0]]
	for clip in clips:
		if not only.is_empty() and clip[0] not in only:
			continue
		for speed in [["real", 4], ["slow", 2]]:
			await _scene(clip[0])
			if sim.game_over:
				push_error("장면 %s: 찍기 전에 판이 끝남" % clip[0])  # 콘솔 오류로 남아 qa_web이 실패
			await _clip("act_%s_%s" % [clip[0], speed[0]], clip[1], speed[1])


func _scene(scene: String) -> void:
	var cats := 6
	if scene in ["punch", "fetch", "sparkle", "meet"]:
		cats = 0
	await _start(5, cats)
	await _run_flat(2600.0)
	sim.accelerate = false
	sim.speed = SPEED
	for cat in sim.parade.cats:
		cat.cool = INF  # 능력 장면 말고는 능력을 쓰지 않게 (놓은 장애물을 냥펀치가 부수지 않게)
	_pilot = func() -> Array: return [false, false]
	var t0 := sim.elapsed
	match scene:
		"float_flat":
			pass
		"float_jump":
			_pilot = func() -> Array: return [sim.elapsed - t0 > 0.15 and sim.elapsed - t0 < 0.4, false]
		"float_double":
			_pilot = func() -> Array:
				var t := sim.elapsed - t0
				return [(t > 0.15 and t < 0.35) or (t > 0.6 and t < 0.8), false]
		"float_flock":
			_put("flock", 900.0, 900)
		"stomp":
			await _stomp_scene([["pot", 450.0], ["tank", 1000.0], ["flock", 1600.0]])
		"punch", "fetch", "sparkle":
			var look: String = {"punch": "tuxedo", "fetch": "cheese", "sparkle": "calico"}[scene]
			sim.parade.cats.append({"look": look, "quirk": 0.5, "cool": 0.35})  # 0.35초 뒤 준비 (자리 잡은 모습부터)
			if scene == "punch":
				_put("ac", 900.0, 904)
			elif scene == "fetch":
				# 높이 떠 있는 필수 생선 (안 뛰어서 놓침 → 물어 옴)
				sim.items.append({"kind": "fish", "x": sim.x + 450.0, "y": sim.y + 230.0})
			else:
				for k in 5:
					sim.items.append({"kind": "fish", "x": sim.x + 450.0 + 70.0 * k, "y": sim.y + Balance.ITEM_LIFT})
		"hit":
			_put("pot", 420.0, 905)
		"meet":
			sim.parade.fill(3)
			sim.parade.call_now()
			sim.parade.set("_next_meet", -INF)
			sim.parade.update(sim, 0.0)
			await _run_until(func() -> bool: return not sim.parade.strays.is_empty() and sim.parade.strays[0].x - sim.x < 700.0, 20.0)
		"slide_sign":
			_put("sign", 650.0, 906)
			_pilot = func() -> Array:
				var o: Dictionary = sim.obstacles.filter(func(x: Dictionary) -> bool: return x.id == 906).front() if sim.obstacles.any(func(x: Dictionary) -> bool: return x.id == 906) else {}
				return [false, not o.is_empty() and sim.front() > o.x - sim.vx() * 0.3 and sim.x - 75.0 < o.x + o.w]
		"dive_stomp":
			await _stomp_scene([["ac", 700.0]])
		"dive_slide":
			_put("sign", 1000.0, 908)
			_pilot = func() -> Array:
				var t := sim.elapsed - t0
				var o: Array = sim.obstacles.filter(func(x: Dictionary) -> bool: return x.id == 908)
				var under: bool = not o.is_empty() and sim.x - 75.0 < o[0].x + o[0].w
				# 점프 → 꼭대기 지나 내려찍기 → 누른 채 닿아 슬라이딩 → 간판 밑을 지나 뗌
				return [t > 0.1 and t < 0.35, t > 0.55 and under]


## 아기 크기 비교 (2026-11-19): 같은 시드·같은 장면을 크기마다 한 장씩 size_<번호> (review/cat-parade/action/size_compare.py가 나란히 붙임)
func _sizes() -> void:
	for pick in Balance.KITTEN_SIZES.size():
		CatParade.size_pick = pick
		await _start(5, 6)
		await _run_flat(2600.0)
		for i in 120:
			_advance()
		await _still("size_%d" % pick)
	CatParade.size_pick = Balance.KITTEN_SIZE_PICK


## 정지 화면 (PC·폰): 떠다니는 6마리 평지, 능력 준비 HUD, 슬라이딩 첫 안내와 간판, 결과
func _stills() -> void:
	await _start(5, 6)
	await _run_flat(2600.0)
	for i in 120:
		_advance()
	await _still("float6")
	sim.parade.refill()
	for i in 2:
		_advance()
	await _still("hud_ready")
	for cat in sim.parade.cats:
		cat.cool = INF  # 냥펀치가 간판을 부수지 않게
	world.get_script().slide_taught = false
	var sign := _put("sign", 1000.0, 909)
	_pilot = func() -> Array: return [false, false]
	await _run_until(func() -> bool: return sign.x - sim.front() < sim.vx() * 1.2, 5.0)
	await _still("sign_teach")
	world.set_process(true)
	main.set_process(true)
	qa._fall()
	await qa._wait(Balance.RESTART_DELAY + Juice.COUNT_UP_EACH * 4.0 + 1.5)
	await qa._shot("result6")


## 아기 배치 (2026-11-19, review/cat-parade/action/formation/): 줄줄이(chain)·요정 무리(fairy)마다 평지·점프·더블점프·슬라이딩·피격·새 아기 합류 영상
## form_<방식>_<장면>_<real|slow>_f000… (parade_form-chain-slide = 그 장면만), parade_formstill = 방식마다 6마리 정지 화면 form_<방식>_still
const FORM_MODES := ["chain", "fairy"]  # KittenFlock.MODES 차례


func _formation(mode: String) -> void:
	if mode == "parade_formstill":
		for m in FORM_MODES.size():
			KittenFlock.mode_pick = m
			await _start(5, 6)
			await _run_flat(2600.0)
			sim.accelerate = false
			sim.speed = SPEED
			_pilot = func() -> Array: return [false, false]  # 줄이 출렁이다 멈춘 모습 (생선 길 자동 점프 끔)
			for i in 240:
				_advance()
			await _still("form_%s_still" % FORM_MODES[m])
		KittenFlock.mode_pick = 0
		return
	var m := FORM_MODES.find(mode.split("-")[1])
	KittenFlock.mode_pick = m
	var clips := [["flat", 1.4], ["jump", 1.8], ["double", 2.2], ["slide", 1.8], ["hit", 2.0], ["meet", 2.6]]
	var only := mode.split("-").slice(2)  # parade_form-chain-slide = 그 장면만
	for clip in clips:
		if not only.is_empty() and clip[0] not in only:
			continue
		for speed in [["real", 4], ["slow", 2]]:
			await _form_scene(clip[0])
			if sim.game_over:
				push_error("장면 %s: 찍기 전에 판이 끝남" % clip[0])
			await _clip("form_%s_%s_%s" % [FORM_MODES[m], clip[0], speed[0]], clip[1], speed[1])
	KittenFlock.mode_pick = 0


func _form_scene(scene: String) -> void:
	await _start(5, 5 if scene == "meet" else 6)
	await _run_flat(2600.0)
	sim.accelerate = false
	sim.speed = SPEED
	for cat in sim.parade.cats:
		cat.cool = INF  # 능력을 쓰지 않게
	for i in 60:  # 0.5초 자리 잡기
		_advance()
	var t0 := sim.elapsed
	_pilot = func() -> Array: return [false, false]
	match scene:
		"jump":
			_pilot = func() -> Array: return [sim.elapsed - t0 > 0.15 and sim.elapsed - t0 < 0.4, false]
		"double":
			_pilot = func() -> Array:
				var t := sim.elapsed - t0
				return [(t > 0.15 and t < 0.35) or (t > 0.6 and t < 0.8), false]
		"slide":
			_pilot = func() -> Array: return [false, sim.elapsed - t0 > 0.2 and sim.elapsed - t0 < 1.2]
		"hit":
			_put("pot", 420.0, 905)
		"meet":
			sim.parade.call_now()
			sim.parade.set("_next_meet", -INF)
			sim.parade.update(sim, 0.0)
			await _run_until(func() -> bool: return not sim.parade.strays.is_empty() and sim.parade.strays[0].x - sim.x < 500.0, 20.0)
