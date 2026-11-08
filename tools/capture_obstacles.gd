extends SceneTree
## 장애물 확인용 캡처: 실제 main 씬에서 긴 옥상 하나에 장애물을 놓고 PNG를 저장한다.
## 사용 (창이 잠깐 뜸, 헤드리스 불가): godot --path . --resolution 1280x720 -s res://tools/capture_obstacles.gd -- <avoid|hit|scene> <출력>
##   avoid: 4종을 정답대로 피함 (폴더에 프레임)   hit: 부딪혀 하트를 잃음 (폴더에 프레임)   scene: 소품과 장애물 한 장 (파일)

const BalanceBot := preload("res://tests/balance_bot.gd")
const STEP := 1.0 / 120.0
const STEPS_PER_FRAME := 8  # 초당 15장
const SPEED := 570.0
const TOP := 180.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	AudioServer.set_bus_mute(0, true)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://capture_obstacles.cfg"  # 실제 최고 기록을 건드리지 않게
	root.add_child(main)
	await process_frame
	var world: Node2D = main.get_node("World")
	world.set_process(false)
	main.set_process(false)
	if args[0] == "scene":
		await _scene(main, world, args[1])
	else:
		DirAccess.make_dir_recursive_absolute(args[1])
		await _play(main, world, args[1], args[0] == "hit")
	DirAccess.remove_absolute("user://capture_obstacles.cfg")
	quit()


func _world(world: Node2D, left: float, list: Array) -> RunnerSim:
	var sim := RunnerSim.new(1, SPEED, false)
	sim.accelerate = false
	sim.stage = 3
	var roof := {"left": left, "right": left + 6900.0, "top": TOP}  # 실제 게임의 가장 긴 옥상 정도
	sim.roofs = [roof] as Array[Dictionary]
	sim.set("_ground_roof", roof)
	sim.structures.clear()
	sim.items.clear()
	sim.y = TOP
	var made: Array[Dictionary] = []
	for i in list.size():
		var info: Dictionary = Balance.OBSTACLES[list[i][0]]
		var o := {"id": i, "kind": list[i][0], "x": list[i][1], "w": info.w, "y0": TOP + info.y0, "y1": TOP + info.y1, "base": TOP}
		if list[i][0] == "flock":
			o.k = Balance.FLOCK_SPEED / SPEED
		made.append(o)
	sim.obstacles = made
	world.sim = sim
	world.set("_roof_looks", {})  # 옥상 모습은 왼쪽 x로 기억하므로, 같은 x의 시작 옥상 모습을 지운다
	world._place_cat(0.0)
	return sim


func _play(main: Control, world: Node2D, out: String, hit: bool) -> void:
	var list: Array = [["ac", 1200.0], ["flock", 2600.0], ["tank", 3800.0]] if hit else [["pot", 1200.0], ["ac", 2400.0], ["tank", 3800.0], ["flock", 5400.0]]
	var sim := _world(world, -400.0, list)
	# 각 장애물을 누를 자리 {"x", "hold", "dj"} (부딪히는 판은 비둘기에서만 크게 뜀)
	var presses: Array = []
	for item: Array in list:
		if hit:
			if item[0] == "flock":
				presses.append({"x": item[1] - 0.4 * SPEED, "hold": JumpModel.max_hold_time(), "dj": false})
		elif item[0] != "flock":
			var best: Dictionary = BalanceBot._best_jump(item[0], SPEED, false)
			presses.append({"x": item[1] - best.lead * SPEED, "hold": best.hold, "dj": best.dj})
	var end: float = list[-1][1] + 500.0
	var left := 0.0
	var double_at := INF
	var double_left := 0.0
	var index := 0
	var count := 0
	var after_over := 0
	while sim.x < end and after_over < 15:
		if not presses.is_empty() and sim.x >= presses[0].x:
			left = presses[0].hold
			if presses[0].dj:
				double_at = sim.elapsed + presses[0].hold + JumpModel.jump_speed() / Balance.GRAVITY
			presses.pop_front()
		if sim.elapsed >= double_at:
			double_at = INF
			double_left = JumpModel.double_max_hold()
		world.set("_touches", {0: true} if left > 0.0 or double_left > 0.0 else {})
		left -= STEP
		double_left -= STEP
		world._process(STEP)
		count += 1
		if count % STEPS_PER_FRAME == 0:
			main._process(STEP * STEPS_PER_FRAME)
			after_over += 1 if sim.game_over else 0
			await _save(out + "/f%04d.png" % index)
			index += 1
	print("프레임 ", index)


## 한 장: 물러난 소품 둘과 장애물 넷이 한 화면에
func _scene(main: Control, world: Node2D, path: String) -> void:
	var left := 0.0
	var props: Array[Dictionary] = []
	# 왼쪽 x가 시드라 소품이 둘 나오고 사이가 넓은 자리를 찾는다
	for i in 5000:
		left = float(i)
		props = BuildingLayout.props(left, left + 1400.0)
		if props.size() == 2 and props[0].kind != props[1].kind and props[0].x > left + 300.0 and props[0].x < left + 500.0 and props[1].x - props[0].x > 650.0 and props[1].x < left + 1150.0:
			break
	print("left ", left, " ", props)
	var mid: float = (props[0].x + props[1].x) * 0.5
	var sim := _world(world, left, [["pot", mid - 110.0], ["ac", mid + 40.0], ["tank", props[1].x + 200.0], ["flock", mid - 60.0]])
	sim.roofs[0].right = left + 1400.0
	sim.roofs.append({"left": left + 1500.0, "right": left + 3000.0, "top": TOP})
	sim.obstacles[3].k = 0.0  # 사진에 잘 보이는 자리에 멈춰 둔다
	sim.x = left + 240.0
	sim.stage = 3
	for i in 3:
		sim.time_since_land = 9.0
		world.set("_touches", {})
		world._process(STEP)
	for id in world._alerts:
		world._alerts[id] = 0.2  # 통 뜬 모습
	world._overlay.queue_redraw()
	main._process(STEP)
	await _save(path)


func _save(path: String) -> void:
	await process_frame
	# 창이 가려지면 macOS가 그리기를 건너뛰어 이전 화면이 저장될 수 있으니 직접 한 번 그린다
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)
