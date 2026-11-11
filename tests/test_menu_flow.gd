extends TestCase
## v0.7.0 2c 화면 흐름 (review/v0.7.0/PLAN.md 1번): 시작 화면 → 판 → 결과 카드 → 상점·미션 → 뒤로,
## 버튼 자리 터치가 점프·다시 시작이 아님, 상점·미션에서 입력이 판에 가지 않음, 사기·받기·바꾸기, 화면 크기(버튼 높이·글자 잘림).

const PATH := "user://test_menu_flow.cfg"


func _clear() -> void:
	for file in [PATH, PATH + ".tmp", PATH + ".broken"]:
		DirAccess.remove_absolute(file)


## 저장을 미리 만들어 둔다 (생선·부스터)
func _seed_save(fish: int, boosters: Dictionary = {}) -> void:
	_clear()
	var save := SaveData.open(PATH)
	save.data.wallet.fish = fish
	save.data.record.best_score2 = 1  # 점수 새로 시작 안내가 뜨지 않게
	for kind: String in boosters:
		save.data.boosters[kind] = boosters[kind]
	save.save()


func _main() -> Control:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = PATH
	main.clock.fixed = {"year": 2026, "month": 11, "day": 12, "hour": 12, "minute": 0, "second": 0}
	add_child(main)
	return main


func _tap(main: Control, at: Vector2) -> void:
	var to_window := main.get_viewport().get_screen_transform()  # 입력은 창 좌표로 들어와 게임 화면 좌표로 바뀐다
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.pressed = down
		event.position = to_window * at
		Input.parse_input_event(event)


func _space(down: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = down
	Input.parse_input_event(key)


func _fall(world: Node2D) -> void:
	world.sim.on_ground = false
	world.sim.y = Balance.FALL_LIMIT + 1.0
	world.sim.vy = -1000.0


func test_켜면_시작_화면에서_멈추고_시작_한_번이면_같은_옥상에서_달린다() -> void:
	_seed_save(0, {"dash_start": 2})
	var main := _main()
	var world: Node2D = main.get_node("World")
	await wait_frames(10)
	assert_eq(main.screen, "start")
	assert_true(world.waiting, "판이 멈춤")
	assert_eq(world.sim.distance(), 0, "안 달림")
	assert_true(main.start_menu.visible)
	assert_false(main.get_node("DistanceLabel").visible, "HUD 숨김")
	var first_roof: Dictionary = world.sim.roofs[1].duplicate()
	main.boosters_on = ["dash_start"]
	main.start_menu.card.find_child("Start", true, false).pressed.emit()
	await wait_frames(5)
	assert_eq(main.screen, "run")
	assert_false(world.waiting)
	assert_eq(world.sim.roofs[1], first_roof, "시작 화면과 같은 옥상")
	assert_eq(main.save.booster_count("dash_start"), 1, "켠 부스터 1개 씀")
	assert_true(world.sim.perks.has_booster("dash_start"))
	assert_true(main.get_node("DistanceLabel").visible)
	main.queue_free()
	await wait_frames(1)
	_clear()


func test_시작_화면_빈_곳을_누르면_시작하고_그_누름으로는_점프하지_않는다() -> void:
	_seed_save(0)
	var main := _main()
	var world: Node2D = main.get_node("World")
	await wait_frames(5)
	_tap(main, Vector2(300, 400))  # 카드가 아닌 곳
	await wait_frames(5)
	assert_eq(main.screen, "run")
	assert_true(world.sim.on_ground, "시작한 누름은 점프 아님")
	main.queue_free()
	await wait_frames(1)
	_clear()


func test_시작_화면_카드_자리_누름은_시작이_아니다() -> void:
	_seed_save(0)
	var main := _main()
	await wait_frames(30)  # 카드가 들어온 뒤
	var card: Control = main.start_menu.card
	var inside := card.get_global_rect().position + Vector2(20, 20)  # 카드 종이 귀퉁이 (버튼 아님)
	_tap(main, inside)
	await wait_frames(5)
	assert_eq(main.screen, "start")
	main.queue_free()
	await wait_frames(1)
	_clear()


func test_결과_카드에서_상점에_가면_입력이_판에_가지_않고_뒤로는_결과_카드() -> void:
	_seed_save(5000)
	var main := _main()
	var world: Node2D = main.get_node("World")
	await wait_frames(3)
	main.begin_run()
	await wait_frames(3)
	_fall(world)
	await get_tree().create_timer(Balance.RESTART_DELAY + 0.2).timeout
	assert_eq(main.screen, "result")
	assert_eq(main.boosters_on, [], "결과 카드의 부스터 칸은 꺼진 채로")
	main.open_shop("upgrades")
	await wait_frames(3)
	assert_eq(main.screen, "shop")
	_space(true)
	await wait_frames(3)
	_space(false)
	_tap(main, Vector2(640, 400))
	await wait_frames(3)
	assert_true(world.sim.game_over, "상점 안 스페이스·터치는 다시 시작이 아님")
	main.shop.find_child("Back", true, false).pressed.emit()
	await wait_frames(3)
	assert_eq(main.screen, "result", "온 곳으로")
	assert_true(main.get_node("GameOver").visible)
	main.get_node("GameOver/Card/Box/Retry").pressed.emit()
	await wait_frames(3)
	assert_false(world.sim.game_over, "다시 하기 버튼은 바로 새 판")
	assert_eq(main.screen, "run")
	main.queue_free()
	await wait_frames(1)
	_clear()


func test_판_중에는_상점과_미션에_못_간다() -> void:
	_seed_save(0)
	var main := _main()
	await wait_frames(3)
	main.begin_run()
	await wait_frames(3)
	main.open_shop()
	main.open_missions()
	assert_eq(main.screen, "run")
	main.queue_free()
	await wait_frames(1)
	_clear()


func test_상점_사기와_돈_부족과_최대() -> void:
	_seed_save(1000)
	var main := _main()
	await wait_frames(3)
	main.open_shop("upgrades")
	var shop: ShopScreen = main.shop
	shop.selected = "fish"
	shop.refresh()
	shop.buy()
	assert_eq(main.save.upgrade_level("fish"), 1)
	assert_eq(main.save.fish(), 700)
	shop.buy()  # 800 필요
	assert_eq(main.save.upgrade_level("fish"), 1, "돈 부족이면 그대로")
	assert_eq(main.save.fish(), 700)
	assert_eq(ShopScreen.value_text("fish", 1), "7점")
	assert_eq(ShopScreen.value_text("dash", 10), "6.0초")
	assert_eq(ShopScreen.value_text("combo", 0), "20개마다")
	main.save.data.upgrades.fish = Balance.UPGRADE_MAX
	shop.refresh()
	assert_true(shop.find_child("Buy", true, false).disabled, "최대 단계")
	shop.show_tab("boosters")
	main.save.data.wallet.fish = 500
	shop.selected = "dash_start"
	shop.buy()
	assert_eq(main.save.booster_count("dash_start"), 1)
	assert_eq(main.save.fish(), 0)
	main.queue_free()
	await wait_frames(1)
	_clear()


func test_0개인_부스터_칸은_상점_부스터_탭으로() -> void:
	_seed_save(0)
	var main := _main()
	await wait_frames(3)
	main.start_menu.boosters.press("bell_start")
	await wait_frames(2)
	assert_eq(main.screen, "shop")
	assert_eq(main.shop.tab, "boosters")
	main.shop.find_child("Back", true, false).pressed.emit()
	await wait_frames(2)
	assert_eq(main.screen, "start", "시작 화면에서 왔으면 시작 화면으로")
	main.queue_free()
	await wait_frames(1)
	_clear()


func test_미션_받기는_지갑에_넣고_도장_바꾸기는_두_번_눌러야() -> void:
	_seed_save(1000)
	var main := _main()
	await wait_frames(3)
	var data: Dictionary = main.save.data
	data.missions.daily = Missions._entries(["d_dist_1", "d_fish_c1", "d_double"], MissionTable.DAILY)
	Missions.count(data, {"meters": 400})
	assert_eq(Missions.pending(data), 1)
	main.open_missions()
	await wait_frames(2)
	var board: MissionBoard = main.board
	assert_not_null(board.find_child("Claim", true, false), "받기 버튼")
	board.claim(false, 0)
	assert_eq(main.save.fish(), 1400)
	assert_eq(SaveData.open(PATH).fish(), 1400, "받으면 저장")
	assert_not_null(board.get_node("Box/Note0").find_child("Stamp", true, false), "받은 쪽지에 도장")
	var before: String = data.missions.daily[1].id
	board.swap_pressed(false, 1)
	assert_eq(data.missions.daily[1].id, before, "한 번은 묻기만")
	board.swap_pressed(false, 1)
	assert_true(data.missions.daily[1].id != before, "두 번째에 바뀜")
	assert_eq(main.save.fish(), 1400 - MissionTable.SWAP_PRICES[0])
	main.queue_free()
	await wait_frames(1)
	_clear()


func test_결과_카드에_깬_미션_쪽지와_등급_오름() -> void:
	_seed_save(0)
	var main := _main()
	var world: Node2D = main.get_node("World")
	await wait_frames(3)
	main.begin_run()
	await wait_frames(2)
	main.save.data.rank.xp = 99
	main.save.data.missions.daily = Missions._entries(["d_runs", "d_fish_c1", "d_double"], MissionTable.DAILY)
	main.save.data.missions.daily[0].progress = 1  # 이번 판으로 2판
	_fall(world)
	await get_tree().create_timer(Juice.COUNT_UP_EACH * 4.0 + 1.5).timeout
	var notes: Node = main.get_node("GameOver/ResultExtras/Notes")
	assert_eq(notes.get_child_count(), 1, "깬 미션 쪽지 하나")
	assert_true(main.get_node("GameOver/ResultExtras/RankUp").visible, "등급 오름 배지")
	assert_eq(main.save.data.rank.level, 2)
	for note: Control in notes.get_children():
		assert_true(main.get_viewport_rect().encloses(note.get_global_rect()), "쪽지가 화면 안 %s" % note.get_global_rect())
	main.queue_free()
	await wait_frames(1)
	_clear()


## 화면마다: 보이는 버튼은 높이 86.4(화면 12%) 이상, 화면 안, 서로 겹치지 않음. 한 줄 글자는 칸 안에 들어감
func _check_layout(main: Control, what: String) -> void:
	var view := main.get_viewport_rect()
	var buttons: Array[Control] = []
	for node in main.find_children("*", "Button", true, false):
		var b: Button = node
		if b.is_visible_in_tree() and _in_menu(b):
			buttons.append(b)
	for b in buttons:
		var r := b.get_global_rect()
		assert_true(r.size.y * b.get_global_transform().get_scale().y >= 86.4 - 0.5, "%s %s 높이 %.0f" % [what, b.name, r.size.y])
		assert_true(view.grow(1.0).encloses(r), "%s %s 화면 밖 %s" % [what, b.name, r])
		for other in buttons:
			if other != b and other.get_instance_id() < b.get_instance_id():
				assert_false(r.grow(-1.0).intersects(other.get_global_rect().grow(-1.0)), "%s %s 와 %s 겹침" % [what, b.name, other.name])
	for node in main.find_children("*", "Label", true, false):
		var l: Label = node
		if l.is_visible_in_tree() and l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.text != "" and not "\n" in l.text and _in_menu(l):
			var need := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
			assert_true(need <= l.size.x + 2.0, "%s 글자 잘림 \"%s\" %.0f > %.0f" % [what, l.text, need, l.size.x])


## 2c 화면 부품인지 (예전 HUD·시험 패널은 뺌)
func _in_menu(node: Node) -> bool:
	var at := node.get_parent()
	while at:
		if at.name in ["StartMenu", "Shop", "Missions", "GameOver"]:
			return true
		at = at.get_parent()
	return false


func test_화면_크기_PC와_휴대폰에서_버튼_높이_겹침_글자_잘림() -> void:
	_seed_save(3000, {"dash_start": 1})
	var window := get_window()
	var keep := window.size
	for size in [Vector2i(1280, 720), Vector2i(844, 390)]:
		window.size = size
		var main := _main()
		var data: Dictionary = main.save.data
		await wait_frames(30)
		_check_layout(main, "시작 %s" % size)
		main.open_shop("upgrades")
		await wait_frames(20)
		_check_layout(main, "상점 %s" % size)
		main.shop.show_tab("boosters")
		await wait_frames(5)
		_check_layout(main, "부스터 %s" % size)
		main.go_back()
		await get_tree().create_timer(MenuScreen.OPEN_TIME + 0.1).timeout  # 상점이 다 사라진 뒤
		data.missions.daily = Missions._entries(["d_dodge_pigeon", "d_fish_c2", "d_perfect_2"], MissionTable.DAILY)
		Missions.count(data, {"fish": 5000})
		main.open_missions()
		await wait_frames(20)
		_check_layout(main, "미션 %s" % size)
		main.go_back()
		await get_tree().create_timer(MenuScreen.OPEN_TIME + 0.1).timeout
		main.begin_run()
		await wait_frames(2)
		_fall(main.get_node("World"))
		await get_tree().create_timer(Juice.COUNT_UP_EACH * 4.0 + 0.5).timeout
		_check_layout(main, "결과 %s" % size)
		var card: Control = main.get_node("GameOver/Card")
		assert_true(main.get_viewport_rect().encloses(card.get_global_rect()), "결과 카드가 화면 안 %s" % card.get_global_rect())
		main.queue_free()
		await wait_frames(2)
	window.size = keep
	_clear()
