extends SceneTree
## 속도 단계 확인용 캡처: 실제 main 씬(World)을 숙련 봇의 입력으로 재생하며 PNG를 저장한다.
## 사용 (창이 잠깐 뜸, 헤드리스 불가): godot --path . --resolution 1280x720 -s res://tools/capture_speed.gd -- run <출력 폴더>
##   run:    0~70초 한 판. 평소에는 SLOW_STRIDE초마다, 단계가 오를 때는 RISE_STRIDE초마다 한 장 (빨리 감기 GIF용)
##   scenes: 같은 옥상·같은 x에서 단계 1 / 단계 4 평소 / 단계 4 오름 신호 / 단계 10 오름 신호

const BalanceBot := preload("res://tests/balance_bot.gd")
const STEP := 1.0 / 120.0
const END_TIME := 70.0
const SLOW_STRIDE := 0.6
const RISE_STRIDE := 0.1
const RISE_FRAME_TIME := 1.6  # 단계가 오른 뒤 이 시간 동안은 촘촘하게
const SCENE_SEED := 7
const SCENE_X := 250.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(args[1])
	AudioServer.set_bus_mute(0, true)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = "user://capture_speed.cfg"  # 실제 최고 기록을 건드리지 않게
	root.add_child(main)
	await process_frame
	var world: Node2D = main.get_node("World")
	world.set_process(false)
	main.set_process(false)
	if args[0] == "run":
		await _run(main, world, args[1])
	else:
		await _scenes(main, world, args[1])
	DirAccess.remove_absolute("user://capture_speed.cfg")
	quit()


func _run(main: Control, world: Node2D, out: String) -> void:
	var seed_value := 0
	var inputs: Array = []
	while inputs.size() < int(END_TIME / STEP):
		seed_value += 1
		inputs = []
		BalanceBot.play_stats(BalanceBot.SKILLS["숙련"], seed_value, END_TIME, Balance.RUN_SPEED, true, inputs)
	print("시드 ", seed_value)
	var label := Label.new()
	label.position = Vector2(500.0, 660.0)
	label.add_theme_font_size_override("font_size", 36)
	main.add_child(label)
	world.sim = RunnerSim.new(seed_value)
	var next_shot := 0.0
	var index := 0
	for input in inputs:
		world.set("_touches", {0: true} if input else {})
		world._process(STEP)  # 입력을 step마다 그대로 넣으려고 한 step씩 진행
		if world.sim.elapsed >= next_shot:
			main._process(STEP)
			label.text = "%2d s   stage %d   speed %d" % [world.sim.elapsed, world.sim.stage, world.sim.speed]
			await _save(out + "/f%04d.png" % index)
			index += 1
			var rising: bool = world.sim.time_since_stage_rise < RISE_FRAME_TIME
			next_shot = world.sim.elapsed + (RISE_STRIDE if rising else SLOW_STRIDE)
			if not rising:
				# 다음 단계 오름을 건너뛰지 않게 그 직전에 맞춘다
				var rise_at: float = Balance.SPEED_STAGES[world.sim.stage][0]
				if next_shot > rise_at and world.sim.elapsed < rise_at:
					next_shot = rise_at
	print("프레임 ", index)


## 처음 옥상 위 같은 자리: elapsed·stage에서 시작해 SCENE_X까지 달린 모습. 곧 다음 단계가 오르는 시각을 주면 오름 신호가 찍힌다
func _scene(main: Control, world: Node2D, path: String, elapsed: float, stage: int) -> void:
	var sim := RunnerSim.new(SCENE_SEED)
	sim.elapsed = elapsed
	sim.stage = stage
	world.sim = sim
	world._place_cat(0.0)
	while sim.x < SCENE_X:
		world.set("_touches", {})
		world._process(STEP)
	main._process(STEP)
	await _save(path)


func _scenes(main: Control, world: Node2D, out: String) -> void:
	await _scene(main, world, out + "/stage1.png", 0.0, 1)
	await _scene(main, world, out + "/stage4.png", 60.0, 4)
	await _scene(main, world, out + "/stage4_signal.png", 49.8, 3)
	await _scene(main, world, out + "/stage10_signal.png", 299.8, 9)


func _save(path: String) -> void:
	await process_frame
	# 창이 가려지면 macOS가 그리기를 건너뛰어 이전 화면이 저장될 수 있으니 직접 한 번 그린다
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)
