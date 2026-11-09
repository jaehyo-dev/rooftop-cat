extends SceneTree
## 2a-4 확인용 캡처: 생선 길을 따라 달리는 자동 조종으로 실제 main 씬을 돌려 PNG를 저장한다.
## 사용 (창이 잠깐 뜸, 헤드리스 불가): godot --path . --resolution 1280x720 -s res://tools/capture_fun.gd -- <모드> <출력 폴더> [시드]
## 모드: shots, gif, result, dash (2a-4) / hit, heart1, combo, trail, perf, stage (2b 손맛)

const STEP := 1.0 / 120.0
const GIF_SECONDS := 30.0
const MAX_SECONDS := 150.0

var main: Control
var world: Node2D
var sim: RunnerSim
var _next := 0
var _flight := {}
var _since := INF


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	AudioServer.set_bus_mute(0, true)
	main = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://capture_fun.cfg"  # 실제 기록을 건드리지 않게
	root.add_child(main)
	await process_frame
	world = main.get_node("World")
	world.set_process(false)
	main.set_process(false)
	DirAccess.make_dir_recursive_absolute(args[1])
	sim = RunnerSim.new(int(args[2]) if args.size() > 2 else 3)
	world.sim = sim
	world.set("_roof_looks", {})
	match args[0]:
		"shots":
			await _shots(args[1])
		"gif":
			await _gif(args[1])
		"result":
			await _result(args[1])
		"dash":
			await _dash(args[1])
		"hit":
			await _hit(args[1])
		"heart1":
			await _heart1(args[1])
		"combo":
			await _combo(args[1])
		"trail":
			await _trail(args[1])
		"perf":
			await _perf(args[1])
		"stage":
			await _run_until(Balance.SPEED_STAGES[1][0] - 0.2)
			await _frames(args[1], 1.4, 15.0, true)
	DirAccess.remove_absolute("user://capture_fun.cfg")
	quit()


## 자동 조종: 호대로 누르고, 트램펄린은 닿을 때 톡, 질주 중에는 주기적으로 뛴다
func _pressed() -> bool:
	if sim.dashing:
		return int(sim.elapsed * 1.6) % 2 == 0 and fmod(sim.elapsed * 1.6, 1.0) < 0.45
	var flights: Array[Dictionary] = sim.road.flights
	while _next < flights.size() and flights[_next].press_x < sim.x - 40.0:
		_next += 1  # 질주로 지나친 호
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


func _shots(out: String) -> void:
	var todo := {"road_pot": true, "road_gap": true, "road_flock": true, "road_tank": true, "road_tramp": true, "dash_jump": true, "alert": true, "hud": true}
	while sim.elapsed < MAX_SECONDS and not sim.game_over and not todo.is_empty():
		_advance()
		var name := _moment(todo)
		if name != "":
			todo.erase(name)
			main._process(STEP)
			await _save(out + "/%s.png" % name)
	print("못 찍은 장면: ", todo.keys(), " 끝 시각 ", sim.elapsed, " 생선 ", sim.fish, " 콤보 ", sim.combo.best)


## 지금 찍을 만한 장면 이름
func _moment(todo: Dictionary) -> String:
	if sim.dashing and not sim.on_ground and sim.vy > 0.0 and sim.y > sim.roof_at(sim.x).get("top", sim.y) + 120.0 and todo.has("dash_jump"):
		return "dash_jump"
	if sim.dashing or not sim.on_ground:
		return ""
	if sim.combo.count >= 25 and sim.combo.multiplier() >= 2 and todo.has("hud"):
		return "hud"
	for o in sim.obstacles:
		var ahead: float = RunnerSim.obstacle_left(o, sim.x) - sim.x
		if o.kind == "pot" and ahead < 520.0 and ahead > 380.0 and todo.has("road_pot"):
			return "road_pot"
		if o.kind == "flock" and ahead < 480.0 and ahead > 150.0 and todo.has("road_flock"):
			return "road_flock"
		if o.kind == "tank" and ahead < 620.0 and ahead > 420.0 and todo.has("road_tank"):
			return "road_tank"
		if ahead < 200.0 and ahead > 90.0 and todo.has("alert") and not todo.has("road_pot"):
			return "alert"
	for s in sim.structures:
		if s.kind == "tramp" and s.left - sim.x < 420.0 and s.left - sim.x > 120.0 and todo.has("road_tramp"):
			return "road_tramp"
	var here := sim.roof_at(sim.x)
	if here.has("segment") and here.segment == "E2" and here.right - sim.x < 420.0 and here.right - sim.x > 240.0 and todo.has("road_gap"):
		return "road_gap"
	return ""


func _gif(out: String) -> void:
	var frame := 0
	var count := 0
	while sim.elapsed < GIF_SECONDS and not sim.game_over:
		_advance()
		count += 1
		if count % 10 == 0:  # 초당 12장
			main._process(STEP * 10.0)
			await _save(out + "/f%04d.png" % frame)
			frame += 1
	print("프레임 ", frame, " 시각 ", sim.elapsed, " 생선 ", sim.fish, " 콤보 ", sim.combo.best, " 점수 ", sim.score(), " 하트 ", sim.hearts)


## 질주 구간만 프레임으로 저장한다 (시작 직전부터 끝난 뒤 조금까지, 초당 12장)
func _dash(out: String) -> void:
	while not sim.dashing and sim.elapsed < MAX_SECONDS and not sim.game_over:
		_advance()
	var frame := 0
	var count := 0
	var after := 0
	while after < 120 and not sim.game_over:
		_advance()
		after += 0 if sim.dashing else 1
		count += 1
		if count % 10 == 0:
			main._process(STEP * 10.0)
			await _save(out + "/f%04d.png" % frame)
			frame += 1
	print("프레임 ", frame, " 시각 ", sim.elapsed, " 생선 ", sim.fish, " 콤보 ", sim.combo.best)


func _result(out: String) -> void:
	while sim.elapsed < 40.0 and not sim.game_over:
		_advance()
	# 손을 떼고 달리면 떨어진다
	_flight = {}
	while not sim.game_over:
		sim.has_box = false
		sim.hearts = maxi(sim.hearts, 1)
		world.set("_touches", {})
		world._process(STEP)
	# 2b: 숫자가 차오르고 새 기록 별이 내리는 동안 (초당 15장, 3초)
	for i in 45:
		main._process(1.0 / 15.0)
		world.set("_over_time", 0.1 + i / 15.0)
		await _save(out + "/f%04d.png" % i)
	await _save(out + "/result_new_best.png")
	print("거리 ", sim.distance(), " 점수 ", sim.score(), " 최고 콤보 ", sim.combo.best)


func _save(path: String) -> void:
	await process_frame
	# 창이 가려지면 macOS가 그리기를 건너뛰어 이전 화면이 저장될 수 있으니 직접 한 번 그린다
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)


## 2b: 눈앞에 화분을 놓고 일부러 부딪힌다. 직전 0.15초부터 0.9초 동안 초당 30장
func _hit(out: String) -> void:
	await _run_until(6.0)
	_flight = {}
	sim.obstacles.clear()
	sim.obstacles.append({"id": 900, "kind": "pot", "x": sim.x + 140.0, "w": 48.0, "y0": sim.y, "y1": sim.y + 38.0, "base": sim.y})
	await _frames(out, 0.9, 30.0, false)
	print("하트 ", sim.hearts)


## 2b: 하트 1개 (가장자리 붉어짐·두근거림), 초당 12장 3초 + 한 장
func _heart1(out: String) -> void:
	await _run_until(8.0)
	sim.hearts = 1
	await _frames(out, 3.0, 12.0, true)
	await _save(out + "/heart1.png")


## 2b: 콤보 배수가 오르는 순간 앞뒤 (초당 30장)
func _combo(out: String) -> void:
	while sim.combo.count < Balance.COMBO_STEP - 3 and sim.elapsed < MAX_SECONDS and not sim.game_over:
		_advance()
	await _frames(out, 0.9, 30.0, true)
	print("콤보 ", sim.combo.count, " x", sim.combo.multiplier())


## 2b: 질주 잔상. 질주를 바로 시작하고 0.6초 뒤 한 장 (1단계 시안과 나란히 비교용)
func _trail(out: String) -> void:
	await _run_until(4.0)
	sim._start_dash()
	for i in 72:  # 땅에서 달리는 모습 (시안과 같은 자세로 비교)
		world.set("_touches", {})
		world._process(STEP)
	main._process(0.6)  # HUD 튀기가 끝난 모습 (한 칸만 진행하면 콤보 글자가 커진 채 찍힘)
	await _save(out + "/trail.png")
	await _frames(out, 1.2, 15.0, true)


## 2b: 극한 상황 fps. 질주 + 털실을 계속 켜고 화면 앞에 생선 두 줄을 촘촘히 채운 채 실제 시간으로 10초 돌린다 (수직 동기 끔)
func _perf(out: String) -> void:
	await _run_until(4.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	world.set_process(true)
	main.set_process(true)
	var frames := 0
	var worst := 0.0
	var slow := 0  # 33ms(30fps)보다 긴 프레임 수 (처음 1초 준비 시간은 빼고 셈)
	var started := Time.get_ticks_usec()
	var last := started
	while Time.get_ticks_usec() - started < 10_000_000:
		if not sim.dashing:
			sim._start_dash()
		sim.magnet_time = Balance.MAGNET_TIME
		sim.hearts = Balance.HEARTS_MAX
		var fish := sim.items.filter(func(it: Dictionary) -> bool: return it.kind == "fish" and it.x > sim.x).size()
		var x := sim.x + 1400.0
		while fish < 50:
			for row in 2:
				sim.items.append({"kind": "fish", "x": x, "y": sim.y + 60.0 + 110.0 * row, "bonus": true})
			x += 35.0
			fish += 2
		await process_frame
		var now := Time.get_ticks_usec()
		if now - started > 1_000_000:
			worst = maxf(worst, (now - last) / 1000.0)
			slow += 1 if now - last > 33_333 else 0
		last = now
		frames += 1
	var seconds := (Time.get_ticks_usec() - started) / 1_000_000.0
	var report := "평균 %.0f fps, 가장 긴 프레임 %.1f ms, 33ms 넘는 프레임 %d개 (처음 1초 제외), 조각·별 상한 %d (지금 %d), 생선 %d" % [
			frames / seconds, worst, slow, world.SHARD_MAX, world._shards.size(), sim.items.size()]
	print(report)
	var file := FileAccess.open(out + "/perf.txt", FileAccess.WRITE)
	file.store_line(report)


func _run_until(seconds: float) -> void:
	while sim.elapsed < seconds and not sim.game_over:
		_advance()


## seconds초 동안 fps장/초로 저장 (autopilot이면 자동 조종, 아니면 손 떼고 달림)
func _frames(out: String, seconds: float, fps: float, autopilot: bool) -> void:
	var every := roundi(1.0 / fps / STEP)
	for i in roundi(seconds / STEP):
		if autopilot:
			_advance()
		else:
			world.set("_touches", {})
			world._process(STEP)
		if i % every == 0:
			main._process(STEP * every)
			await _save(out + "/f%04d.png" % (i / every))
