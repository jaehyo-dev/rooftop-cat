extends SceneTree
## 아이템 확인용 캡처: 실제 main 씬에서 PNG 프레임을 저장한다.
## 사용 (헤드리스 불가. 맥은 창이 잠깐 뜸, WSL은 창 없이 앞에 "xvfb-run -a"): godot --path . --resolution 1280x720 -s res://tools/capture_items.gd -- <dash|yarn|can|bell|tank> <출력 폴더>

const STEP := 1.0 / 120.0
const STEPS_PER_FRAME := 8  # 초당 15장
const SPEED := 570.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	AudioServer.set_bus_mute(0, true)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.show_start = false  # 시작 화면 없이 바로 판 (v0.7.0 2c)
	main.record_path = "user://capture_items.cfg"  # 실제 최고 기록을 건드리지 않게
	root.add_child(main)
	await process_frame
	var world: Node2D = main.get_node("World")
	world.set_process(false)
	main.set_process(false)
	DirAccess.make_dir_recursive_absolute(args[1])
	var sim := RunnerSim.new(4, SPEED)
	sim.accelerate = false
	sim.stage = 3
	sim.x = 300.0
	sim.items.clear()
	sim.obstacles.clear()
	var top: float = sim.roofs[0].top
	world.sim = sim
	world.set("_roof_looks", {})
	var seconds := 3.0
	match args[0]:
		"dash":
			# 첫 옥상 끝쪽에 간식을 놓고 앞 구간째 달린다 (시작 → 부수기 → 착지 옥상)
			sim.items.append({"kind": "dash", "x": sim.x + 200.0, "y": top + Balance.ITEM_LIFT})
			_pot(sim, "pot", sim.x + 900.0, top)
			seconds = 8.0
		"yarn":
			sim.items.append({"kind": "yarn", "x": sim.x + 200.0, "y": top + Balance.ITEM_LIFT})
			for i in 14:
				sim.items.append({"kind": "fish", "x": sim.x + 520.0 + i * 55.0, "y": top + 46.0 + (140.0 if i % 2 == 0 else 200.0)})
			seconds = 3.2
		"can":
			sim.items.append({"kind": "can", "x": sim.x + 200.0, "y": top + Balance.ITEM_LIFT})
			_pot(sim, "pot", sim.x + 720.0, top)
			_pot(sim, "ac", sim.x + 930.0, top)
			seconds = 2.6
		"bell":
			sim.items.append({"kind": "bell", "x": sim.x + 160.0, "y": top + Balance.ITEM_LIFT})
			_pot(sim, "ac", sim.x + 640.0, top)
			seconds = 2.6
		"tank":
			_pot(sim, "tank", sim.x + 260.0, top)
			world._process(STEP)
			main._process(STEP)
			await _save(args[1] + "/tank.png")
			DirAccess.remove_absolute("user://capture_items.cfg")
			quit()
			return
	var index := 0
	var after_dash := 0.0
	for count in int(seconds / STEP):
		world.set("_touches", {})
		world._process(STEP)
		after_dash += STEP if args[0] == "dash" and not sim.dashing and sim.elapsed > 1.0 else 0.0
		if after_dash > 0.9:
			break  # 착지 옥상에 내려선 모습까지만
		if count % STEPS_PER_FRAME == 0:
			main._process(STEP * STEPS_PER_FRAME)
			await _save(args[1] + "/f%04d.png" % index)
			index += 1
	print("프레임 ", index, " 끝 위치 ", sim.x, " 질주 끝남 ", not sim.dashing, " 하트 ", sim.hearts, " 생선 ", sim.fish)
	DirAccess.remove_absolute("user://capture_items.cfg")
	quit()


func _pot(sim: RunnerSim, kind: String, at: float, top: float) -> void:
	var info: Dictionary = Balance.OBSTACLES[kind]
	sim.obstacles.append({"id": sim.obstacles.size() + 1000, "kind": kind, "x": at, "w": info.w, "y0": top + info.y0, "y1": top + info.y1, "base": top})


func _save(path: String) -> void:
	await process_frame
	# 창이 가려지면 macOS가 그리기를 건너뛰어 이전 화면이 저장될 수 있으니 직접 한 번 그린다
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)
