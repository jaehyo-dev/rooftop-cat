extends SceneTree
## v0.7.0 2c-fix 눈 검수 캡처 (자동 테스트 아님, QUALITY_BAR 4-1 넷째 항목).
## 화면·상태마다 PNG 한 장 + 글자가 있는 칸(쪽지·패널·버튼·띠)을 2배로 키운 조각 zoom/<화면>_<번호>.png.
## 사용 (맥, 창이 잠깐 뜸):
##   godot --path . --resolution 1280x720 -s res://review/v0.7.0/2c-fix/capture_fix.gd -- shots <폴더> pc
##   godot --path . --resolution 844x390  -s res://review/v0.7.0/2c-fix/capture_fix.gd -- shots <폴더> phone
##   godot --path . --resolution 1280x720 -s res://review/v0.7.0/2c-fix/capture_fix.gd -- sit <폴더>   (시작 고양이 GIF 프레임 f000.png...)

const PATH := "user://capture_fix.cfg"
const Q := preload("res://tools/qa_web.gd")  # 2c-juice: 칸 찾기 함수가 tools/qa_web.gd로 옮겨짐
var main: Control
var out := ""
var size_name := ""
var frame := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[1]
	DirAccess.make_dir_recursive_absolute(out + "/zoom")
	AudioServer.set_bus_mute(0, true)
	await process_frame
	if args[0] == "shots":
		size_name = args[2]
		await _shots()
	else:
		await _sit()
	quit(0)


## kind: empty(처음) / normal(보통) / longest(가장 긴 값) / max(강화 다 삼) / poor(돈 부족)
func _make(kind: String) -> void:
	if main:
		main.queue_free()
		await process_frame
	for file in [PATH, PATH + ".tmp"]:
		DirAccess.remove_absolute(file)
	var save := SaveData.open(PATH)
	save.data.record.best_score2 = 0
	match kind:
		"normal":
			save.data.wallet.fish = 3450
			save.data.record.best_score2 = 48210
			save.data.upgrades = {"dash": 3, "yarn": 2, "combo": 1, "gold": 0, "cookie": 0, "fish": 3}
			save.data.boosters = {"dash_start": 2, "bell_start": 1, "fish_bonus": 0}
			save.data.rank = {"level": 3, "xp": 95}
		"longest", "max":
			save.data.wallet.fish = 9999999
			save.data.record.best_score2 = 9999999
			for k: String in save.data.upgrades:
				save.data.upgrades[k] = Balance.UPGRADE_MAX if kind == "max" else 0
			for k: String in save.data.boosters:
				save.data.boosters[k] = Balance.BOOSTER_MAX
			save.data.rank = {"level": MissionTable.RANK_NAMES.size(), "xp": MissionTable.RANK_AFTER_MAX_XP - 1}
		"poor":
			save.data.wallet.fish = 50
			save.data.upgrades = {"dash": 9, "yarn": 0, "combo": 0, "gold": 0, "cookie": 0, "fish": 0}
	save.save()
	main = load("res://scenes/main.tscn").instantiate()
	main.record_path = PATH
	main.clock.fixed = {"year": 2026, "month": 11, "day": 16 if kind == "longest" else 12, "hour": 0 if kind == "longest" else 18,
			"minute": 0 if kind == "longest" else 48, "second": 1}
	root.add_child(main)
	await _wait(0.8)
	var data: Dictionary = main.save.data
	if kind == "normal":
		# 깸(받기 전) 1, 받음(도장) 1, 진행 중 1. 주간도 깸 1
		data.missions.daily = Missions._entries(["d_dist_2", "d_fish_c1", "d_double"], MissionTable.DAILY)
		data.missions.weekly = Missions._entries(["w_daily_10", "w_fish_10k", "w_double"], MissionTable.WEEKLY)
		Missions.count(data, {"meters": 520, "fish": 640, "double": 4})
		Missions.claim(data, false, 1)
		data.missions.weekly[1].progress = 7400
	elif kind == "longest":
		Q.fill_longest(data)
	main.save.save()
	main.refresh_menus()


func _wait(seconds: float, record: bool = false) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	var n := 0
	while Time.get_ticks_msec() < end:
		await process_frame
		n += 1
		if record and n % 4 == 0:  # 약 15fps
			var img := root.get_texture().get_image()
			img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
			img.save_png("%s/f%03d.png" % [out, frame])
			frame += 1


## 전체 화면 + 글자가 든 칸마다 2배 조각
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	var file := "%s_%s" % [name, size_name]
	img.save_png("%s/%s.png" % [out, file])
	var to_px := root.get_final_transform()  # 게임 화면 좌표 → 창 픽셀
	var cells := []
	for node in main.find_children("*", "Label", true, false):
		var l: Label = node
		if not (l.is_visible_in_tree() and Q.in_menu(l) and l.text.strip_edges() != ""):
			continue
		var cell := Q.cell_of(l)
		if cell.name == "Box" or cell.size.x * cell.size.y > 1280 * 720 * 0.4:  # 화면 전체 같은 큰 칸이면 글자 칸만
			cell = l
		var rect := to_px * Q.moved(cell.get_global_transform(), Rect2(Vector2.ZERO, cell.size)).grow(12.0)
		rect = rect.intersection(Rect2(Vector2.ZERO, img.get_size()))
		if rect.size.x < 4 or cells.any(func(r: Rect2) -> bool: return r.encloses(rect)):
			continue
		cells = cells.filter(func(r: Rect2) -> bool: return not rect.encloses(r))
		cells.append(rect)
	for i in cells.size():
		var piece := img.get_region(Rect2i(cells[i]))
		piece.resize(piece.get_width() * 2, piece.get_height() * 2, Image.INTERPOLATE_LANCZOS)
		piece.save_png("%s/zoom/%s_%02d.png" % [out, file, i])


func _shop(kind: String, tab: String, pick: Array) -> void:
	main.open_shop(tab)
	await _wait(0.4)
	for p: String in pick:
		main.shop.selected = p
		main.shop.refresh()
		await _wait(0.1)
		await _shot("shop_%s_%s_%s" % [kind, tab, p])
	main.go_back()
	await _wait(0.4)


func _shots() -> void:
	# 시작 화면
	for kind in ["empty", "normal", "longest"]:
		await _make(kind)
		if kind == "normal":
			main.boosters_on = ["dash_start"]
			main.refresh_menus()
		await _wait(0.4)
		await _shot("start_" + kind)
	# 상점: 보통(생선 단계), 가장 긴 값(모든 줄), 최대 단계, 돈 부족
	await _make("normal")
	await _shop("normal", "upgrades", ["fish"])
	await _shop("normal", "boosters", ["fish_bonus"])
	await _make("longest")
	await _shop("longest", "upgrades", ShopScreen.UPGRADE_INFO.keys())
	await _shop("longest", "boosters", ShopScreen.BOOSTER_INFO.keys())
	await _make("max")
	await _shop("max", "upgrades", ["fish"])
	await _make("poor")
	await _shop("poor", "upgrades", ["dash"])
	main.open_shop("upgrades")
	await _wait(0.3)
	main.shop.buy()  # 돈 부족: 뿌뿌 + 흔들림
	await _wait(0.05)
	await _shot("shop_poor_shake")
	main.go_back()
	await _wait(0.4)
	# 미션: 처음(빈 값), 보통(깸·받음·진행), 가장 긴 값, 바꾸기 "정말?", 받기 순간(도장 쾅)
	for kind in ["empty", "normal", "longest"]:
		await _make(kind)
		main.open_missions()
		await _wait(0.5)
		await _shot("missions_" + kind)
		if kind == "normal":
			main.board.swap_pressed(false, 2)
			await _wait(0.2)
			await _shot("missions_confirm")
			main.board.claim(false, 0)
			await _wait(1.4)
			await _shot("missions_claimed")
		main.go_back()
		await _wait(0.4)
	# 결과 카드: 보통(미션 2개 깸 + 등급 오름), 가장 긴 값
	await _make("normal")
	var data: Dictionary = main.save.data
	data.missions.daily = Missions._entries(["d_runs", "d_dist_1", "d_double"], MissionTable.DAILY)
	data.missions.daily[0].progress = 1
	data.rank.xp = CatRank.next_xp(data.rank.level) - 5
	main.begin_run()
	await _wait(2.0)
	var world: Node2D = main.get_node("World")
	world.sim.x += Balance.PX_PER_METER * 320.0
	_fall(world)
	await _wait(Juice.COUNT_UP_EACH * 4.0 + 2.0)
	await _shot("result_rankup")
	await _make("longest")
	main.begin_run()
	await _wait(0.3)
	_fall(main.get_node("World"))
	await _wait(0.3)
	main._result.values = [99999, 99999, 9999, 9999999]
	main._result.bonus = true
	main._result.t = 999.0
	main._count_result(0.0)
	var done := []
	for id in Q.longest_missions(MissionTable.DAILY, 2) + Q.longest_missions(MissionTable.WEEKLY, 2):
		done.append({"id": id, "fish": 99999})
	main._extras.play({"done": done, "ranks": [{"level": 9, "fish": 99999, "boosters": ["dash_start"]},
			{"level": 10, "fish": 99999, "boosters": ["bell_start", "fish_bonus"]}]}, main.get_node("GameOver/Card").get_global_rect())
	await _wait(ResultExtras.NOTE_GAP * 4.0 + 1.0)
	await _shot("result_longest")


func _fall(world: Node2D) -> void:
	world.sim.on_ground = false
	world.sim.y = Balance.FALL_LIMIT + 1.0
	world.sim.vy = -1000.0


## 시작 화면 고양이: 앉아서 꼬리 흔들기·깜빡임 6초 → [시작] → 일어나 달리기 1.2초 (GIF용 프레임)
func _sit() -> void:
	await _make("normal")
	await _wait(6.0, true)
	main.begin_run()
	await _wait(1.2, true)
