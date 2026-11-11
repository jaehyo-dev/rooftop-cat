extends SceneTree
## v0.7.0 2c 화면 캡처 (검토용, 자동 테스트 아님): 실제 main 씬에 저장 상태를 만들어 넣고 화면마다 PNG, 흐름은 GIF용 프레임.
## 사용 (WSL은 창 없이 xvfb-run):
##   xvfb-run -a -s "-screen 0 1600x1000x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -s res://review/v0.7.0/2c/capture_2c.gd -- shots <폴더> pc
##   ... --resolution 844x390 ... -- shots <폴더> phone
##   ... --resolution 1280x720 ... -- flow <폴더>   (시작 → 상점 → 사기 → 시작 → 판 → 결과 → 미션 받기, 프레임 f000.png...)

const PATH := "user://capture_2c.cfg"
var main: Control
var out := ""
var frame := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	await process_frame
	if args[0] == "shots":
		await _shots(args[2])
	else:
		await _flow()
	quit(0)


func _make_main(fish: int) -> void:
	for file in [PATH, PATH + ".tmp"]:
		DirAccess.remove_absolute(file)
	var save := SaveData.open(PATH)
	save.data.wallet.fish = fish
	save.data.record.best_score2 = 48210
	save.data.upgrades = {"dash": 3, "yarn": 2, "combo": 1, "gold": 0, "cookie": 0, "fish": 3}
	save.data.boosters = {"dash_start": 2, "bell_start": 1, "fish_bonus": 0}
	save.data.rank = {"level": 1, "xp": 95}
	for n in 3:
		SaveData.push_recent(save.data, 400)
	save.save()
	main = load("res://scenes/main.tscn").instantiate()
	main.record_path = PATH
	main.clock.fixed = {"year": 2026, "month": 11, "day": 12, "hour": 18, "minute": 48, "second": 0}
	root.add_child(main)


func _wait(seconds: float, record: bool = false) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	var n := 0
	while Time.get_ticks_msec() < end:
		await process_frame
		n += 1
		if record and n % 4 == 0:  # 약 15fps
			_save_frame()


func _shot(name: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _save_frame() -> void:
	var img := root.get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	img.save_png("%s/f%03d.png" % [out, frame])
	frame += 1


## 미션 상태: 하나는 깸(받기 전), 하나는 받음, 나머지 진행 중. 주간 하나 깸
func _missions() -> void:
	var data: Dictionary = main.save.data
	data.missions.daily = Missions._entries(["d_dist_2", "d_fish_c1", "d_double"], MissionTable.DAILY)
	data.missions.weekly = Missions._entries(["w_daily_10", "w_fish_10k", "w_double"], MissionTable.WEEKLY)
	Missions.count(data, {"meters": 520, "fish": 640, "double": 4})
	data.missions.weekly[1].progress = 7400
	main.save.save()


func _shots(size: String) -> void:
	_make_main(3450)
	_missions()
	await _wait(1.2)
	await _shot("start_" + size)
	main.open_shop("upgrades")
	main.shop.selected = "fish"
	main.shop.refresh()
	await _wait(0.6)
	await _shot("shop_upgrades_" + size)
	main.shop.show_tab("boosters")
	await _wait(0.3)
	await _shot("shop_boosters_" + size)
	main.go_back()
	main.open_missions()
	await _wait(0.6)
	await _shot("missions_" + size)
	main.go_back()
	await _wait(0.5)
	# 결과 카드: 이번 판에 미션 2개 깸 + 등급 오름 (경험치 95 → 100 넘음)
	var data: Dictionary = main.save.data
	data.missions.daily = Missions._entries(["d_runs", "d_dist_1", "d_double"], MissionTable.DAILY)
	data.missions.daily[0].progress = 1
	data.rank.xp = CatRank.next_xp(data.rank.level) - 5  # 이번 판 미션으로 등급이 오르게
	main.begin_run()
	await _wait(2.5)
	var world: Node2D = main.get_node("World")
	world.sim.x += Balance.PX_PER_METER * 320.0
	world.sim.on_ground = false
	world.sim.y = Balance.FALL_LIMIT + 1.0
	world.sim.vy = -1000.0
	await _wait(Juice.COUNT_UP_EACH * 4.0 + 2.0)
	await _shot("result_" + size)


func _flow() -> void:
	_make_main(3000)
	await _wait(1.0, true)
	main.open_shop("upgrades")
	await _wait(0.8, true)
	main.shop.selected = "fish"
	main.shop.refresh()
	await _wait(0.5, true)
	main.shop.buy()
	await _wait(1.0, true)
	main.go_back()
	await _wait(0.8, true)
	main.save.data.missions.daily = Missions._entries(["d_runs", "d_dist_1", "d_double"], MissionTable.DAILY)
	main.save.data.missions.daily[0].progress = 1
	main.begin_run()
	await _wait(3.0, true)
	var world: Node2D = main.get_node("World")
	world.sim.on_ground = false
	world.sim.y = Balance.FALL_LIMIT + 1.0
	world.sim.vy = -1000.0
	await _wait(Juice.COUNT_UP_EACH * 4.0 + 2.2, true)
	main.open_missions()
	await _wait(0.8, true)
	main.board.claim(false, 0)
	await _wait(1.6, true)
