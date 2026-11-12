extends TestCase
## 2c 피드백 연출 (review/v0.7.0/PLAN.md 18번): 사기·받기 연출이 끝 모습에서 값이 맞는지, 빨리 연달아 누르면 앞 연출을 끝내고 바로 받는지,
## 강화 소리가 단계마다 반음씩 높아지는지, 흔들림 뒤 제자리인지.

const PATH := "user://test_menu_juice.cfg"


func _clear() -> void:
	for file in [PATH, PATH + ".tmp", PATH + ".broken"]:
		DirAccess.remove_absolute(file)


func _main(fish: int) -> Control:
	_clear()
	var save := SaveData.open(PATH)
	save.data.wallet.fish = fish
	save.data.record.best_score2 = 1
	save.save()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = PATH
	main.clock.fixed = {"year": 2026, "month": 11, "day": 12, "hour": 12, "minute": 0, "second": 0}
	add_child(main)
	return main


func _done(main: Control) -> void:
	main.queue_free()
	await wait_frames(1)
	_clear()


func test_강화_사기는_생선이_닿아야_점이_차고_소리는_단계마다_반음씩_높다() -> void:
	var main := _main(999999)
	await wait_frames(3)
	main.open_shop("upgrades")
	await wait_frames(3)
	var shop: ShopScreen = main.shop
	shop.buy()
	assert_eq(main.save.upgrade_level("dash"), 1, "산 것은 바로 저장")
	assert_eq(shop._hold.get("dash", -1), 0, "날아오는 동안 점은 전 단계")
	shop.finish_fx()
	assert_true(shop._hold.is_empty(), "닿으면 점이 참")
	assert_eq(shop._now.text, ShopScreen.value_text("dash", 1))
	for i in 3:
		shop.buy()  # 연달아 눌러도 누를 때마다 앞 연출을 끝내고 바로 삼
	shop.finish_fx()
	assert_eq(main.save.upgrade_level("dash"), 4)
	assert_true(is_equal_approx(main.get_node("Ui_buy").pitch_scale, pow(2.0, 3.0 / 12.0)), "4단계 = 반음 3개 위")
	for i in 6:
		shop.buy()
	shop.finish_fx()
	assert_eq(main.save.upgrade_level("dash"), Balance.UPGRADE_MAX)
	assert_true(main.get_node("Ui_fanfare").playing, "10단계 팡파르")
	assert_eq(shop._buy.scale, Vector2.ONE, "찌그러진 버튼은 제 모양")
	await _done(main)


func test_부스터_사기는_개수_칸에_쏙_들어간_뒤_개수가_바뀐다() -> void:
	var main := _main(99999)
	await wait_frames(3)
	main.open_shop("boosters")
	await wait_frames(3)
	var shop: ShopScreen = main.shop
	shop.buy()
	assert_eq(main.save.booster_count("dash_start"), 1)
	assert_eq(shop._counts["dash_start"].text, "x0", "날아가는 동안은 그대로")
	shop.finish_fx()
	assert_eq(shop._counts["dash_start"].text, "x1")
	await _done(main)


func test_미션_세_장을_빨리_받아도_도장이_다_찍히고_지갑이_다_찬다() -> void:
	var main := _main(1000)
	await wait_frames(3)
	var data: Dictionary = main.save.data
	data.missions.daily = Missions._entries(["d_dist_1", "d_fish_c1", "d_double"], MissionTable.DAILY)
	for entry: Dictionary in data.missions.daily:
		entry.progress = entry.target
		entry.done = true
		entry.claimed = false
	main.open_missions()
	await wait_frames(20)
	var board: MissionBoard = main.board
	var total := 1000
	for slot in 3:
		total += Missions.reward(data.missions.daily[slot].id).fish
		board.claim(false, slot)
		await wait_frames(2)  # 도장이 내려오는 중에 다음 받기
	assert_eq(main.save.fish(), total)
	board.finish_fx()
	assert_eq(board._wallet_label.text, UiKit.comma(total), "지갑 숫자가 끝까지 참")
	for i in 3:
		var stamp: Control = board.get_node("Box/Note%d" % i).find_child("Stamp", true, false)
		assert_not_null(stamp, "도장 %d" % i)
		assert_eq(stamp.scale, Vector2.ONE, "도장 %d 제 모양" % i)
	assert_eq(board.position, Vector2.ZERO, "흔들린 화면은 제자리")
	await _done(main)


func test_흔들림은_겹쳐도_제자리로_돌아온다() -> void:
	var box := Control.new()
	box.position = Vector2(5, 7)
	add_child(box)
	UiKit.shake(box)
	await wait_frames(2)
	var tween := UiKit.shake(box)
	UiKit.finish([tween])
	assert_eq(box.position, Vector2(5, 7))
	box.queue_free()
