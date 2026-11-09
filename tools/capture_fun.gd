extends SceneTree
## 2a-4 확인용 캡처: 생선 길을 따라 달리는 자동 조종으로 실제 main 씬을 돌려 PNG를 저장한다.
## 사용 (창이 잠깐 뜸, 헤드리스 불가): godot --path . --resolution 1280x720 -s res://tools/capture_fun.gd -- <shots|gif|result> <출력 폴더> [시드]

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
	main._process(STEP)
	await _save(out + "/result_new_best.png")
	world.set("_over_time", 2.0)
	main._process(STEP)
	await _save(out + "/result.png")
	print("거리 ", sim.distance(), " 점수 ", sim.score(), " 최고 콤보 ", sim.combo.best)


func _save(path: String) -> void:
	await process_frame
	# 창이 가려지면 macOS가 그리기를 건너뛰어 이전 화면이 저장될 수 있으니 직접 한 번 그린다
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)
