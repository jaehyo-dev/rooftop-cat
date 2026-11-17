extends TestCase
## 아기 고양이 무리 시험판 (CatParade): 배수·피버, 떠다니는 자리, 길고양이 자리·만남, 부딪힘(하트 -1 + 나중 아기 날아감), 점수 배수.

const BalanceBot := preload("res://tests/balance_bot.gd")
const DT := 1.0 / 120.0
const WORLD := preload("res://scripts/world_view.gd")


## 줄을 켠 판 (옥상 생성기만, 장애물 없음)
func _sim(seed_value: int = 3, course: bool = false) -> RunnerSim:
	var sim := RunnerSim.new(seed_value, Balance.RUN_SPEED, course)
	sim.parade_on = true
	return sim


## 주인공 바로 앞 장애물 (다음 step에 몸에 닿음)
func _block(sim: RunnerSim) -> void:
	sim.obstacles.append({"id": 900, "kind": "pot", "x": sim.x + 20.0, "w": 40.0, "y0": sim.y, "y1": sim.y + 60.0, "base": sim.y})


func test_배수와_피버() -> void:
	assert_eq(CatParade.mult_for(0), 1.0)
	assert_true(is_equal_approx(CatParade.mult_for(1), 1.2), "1마리 x1.2")
	assert_true(is_equal_approx(CatParade.mult_for(6), 2.2), "6마리 x2.2")
	var parade := CatParade.new(1)
	parade.fill(4)
	assert_false(parade.fever(), "4마리는 피버 아님")
	parade.fill(5)
	assert_true(parade.fever(), "5마리부터 골골")
	parade.fill(9)
	assert_eq(parade.cats.size(), Balance.PARADE_MAX, "최대 6마리")


## 길고양이는 장애물·구조물·아이템과 떨어진 옥상 위, 그 자리 땅 생선은 치움
func test_길고양이_자리는_장애물과_생선을_피한다() -> void:
	var placed := 0
	for seed_value in range(1, 41):
		var sim := _sim(seed_value, true)
		sim.parade.call_now()
		sim.parade.update(sim, DT)
		if sim.parade.strays.is_empty():
			continue
		placed += 1
		var s: Dictionary = sim.parade.strays[0]
		assert_true(s.x >= sim.x + sim.view_ahead, "화면 밖에서 나옴 (시드 %d)" % seed_value)
		var roof := sim.roof_at(s.x)
		assert_eq(roof.top, s.y, "옥상 위 (시드 %d)" % seed_value)
		assert_false(roof.get("platform", false), "전봇대 판 아님")
		for o in sim.obstacles:
			assert_true(o.x + o.w + Balance.STRAY_CLEAR <= s.x or o.x - Balance.STRAY_CLEAR >= s.x, "장애물과 떨어짐 (시드 %d)" % seed_value)
		for st in sim.structures:
			assert_true(st.right + Balance.STRAY_CLEAR <= s.x or st.left - Balance.STRAY_CLEAR >= s.x, "트램펄린·줄과 떨어짐")
		for item in sim.items:
			if item.y <= s.y + Balance.ITEM_LIFT:
				assert_true(absf(item.x - s.x) >= FishRoad.RESERVED_GAP, "땅 아이템과 안 겹침 (시드 %d, %s)" % [seed_value, item.kind])
	assert_true(placed >= 35, "대부분 시드에서 바로 놓임 (%d/40)" % placed)


func test_지나가기만_하면_점프_중이어도_만난다() -> void:
	var sim := _sim()
	sim.parade.call_now()
	sim.parade.update(sim, DT)
	var s: Dictionary = sim.parade.strays[0]
	sim.x = s.x - 1.0
	sim.y += 200.0  # 높이 떠 있음
	sim.parade.update(sim, DT)
	assert_eq(sim.parade.cats.size(), 0, "아직 안 지남")
	sim.x = s.x
	sim.parade.update(sim, DT)
	assert_eq(sim.parade.cats.size(), 1, "지나는 순간 만남")
	assert_eq(sim.parade.met.size(), 1, "이번에 만남 알림")
	assert_eq(sim.parade.cats[0].look, s.look, "같은 무늬")
	assert_true(sim.parade.strays.is_empty() or sim.parade.strays[0].x > s.x, "그 길고양이는 줄로 옮김")


func test_줄이_꽉_차면_길고양이가_안_나온다() -> void:
	var sim := _sim()
	sim.parade.fill(Balance.PARADE_MAX)
	sim.parade.call_now()
	sim.parade.update(sim, DT)
	assert_true(sim.parade.strays.is_empty())


func test_첫_만남과_간격() -> void:
	for seed_value in TestCase.pick([1, 2, 3, 4, 5, 6], 3):
		var stats: Dictionary = BalanceBot.play_stats(BalanceBot.SKILLS["숙련"], seed_value, 80.0, Balance.RUN_SPEED, true, [], [], null, true)
		var met: Array = stats.met_at
		if stats.time < 40.0:
			continue  # 일찍 끝난 판은 간격을 볼 수 없음
		assert_true(met.size() >= 2, "만남 %d번 (시드 %d)" % [met.size(), seed_value])
		assert_true(met[0] >= 9.5 and met[0] <= 15.5, "첫 만남 %.1f초 (시드 %d)" % [met[0], seed_value])
		for i in range(1, met.size()):
			var gap: float = met[i] - met[i - 1]
			assert_true(gap >= 14.0 and gap <= 27.0, "간격 %.1f초 (시드 %d)" % [gap, seed_value])


func test_부딪힘_A는_하트도_잃고_맨_뒤가_도망() -> void:
	var sim := _sim()
	sim.parade.fill(2)
	var last: Dictionary = sim.parade.cats[1]
	_block(sim)
	sim.step(DT, false)
	assert_eq(sim.hearts, Balance.HEARTS_MAX - 1, "하트 -1")
	assert_eq(sim.parade.cats.size(), 1, "한 마리 도망")
	assert_true(sim.scared, "도망 알림")
	assert_true(is_same(sim.parade.fled[0], last), "맨 뒤 고양이")


func test_줄이_없으면_하트만_잃는다() -> void:
	var sim := _sim()
	_block(sim)
	sim.step(DT, false)
	assert_eq(sim.hearts, Balance.HEARTS_MAX - 1, "하트 -1")
	assert_false(sim.scared, "도망 없음")


func test_질주로_부순_장애물은_도망이_아니다() -> void:
	var sim := _sim()
	sim.parade.fill(3)
	sim._start_dash()
	_block(sim)
	sim.step(DT, false)
	assert_eq(sim.smashed.size(), 1, "부숨")
	assert_eq(sim.parade.cats.size(), 3, "줄 그대로")


func test_점수_배수() -> void:
	var sim := _sim()
	sim.parade.fill(6)
	var x0 := sim.x
	for i in 60:
		sim.step(DT, false)
	var meters := (sim.x - x0) / Balance.PX_PER_METER
	assert_true(absf(sim.parade_bonus - meters * 1.2) < 0.01, "거리 점수 x2.2 (%.2f / %.2f)" % [sim.parade_bonus, meters * 1.2])
	sim.items.append({"kind": "fish", "x": sim.x, "y": sim.y + 40.0})
	var before := sim.combo.points
	sim.step(DT, false)
	assert_eq(sim.combo.points - before, roundi(Balance.FISH_POINTS * 2.2), "생선 x2.2")
	var off := RunnerSim.new(3, Balance.RUN_SPEED, false)
	for i in 60:
		off.step(DT, false)
	assert_eq(off.parade_bonus, 0.0, "줄을 끄면 배수 없음")


func test_새_길고양이는_줄에_없는_품종() -> void:
	for seed_value in TestCase.pick([1, 2, 3, 4, 5, 6], 3):
		var sim := _sim(seed_value)
		sim.parade.fill(Balance.PARADE_MAX - 1)
		sim.parade.call_now()
		sim.parade.update(sim, DT)
		var looks := sim.parade.cats.map(func(c: Dictionary) -> String: return c.look)
		assert_false(sim.parade.strays.is_empty(), "길고양이가 나옴")
		assert_false(sim.parade.strays[0].look in looks, "줄에 없는 아이 (시드 %d)" % seed_value)


## 기다리는 길고양이 그림 (tools/cut_kittens.py): 품종마다 기다리기 몸·꼬리·얼굴이 있고 캔버스 크기가 같다.
## 날아가는 아기 그림 scared.png도 품종마다
func test_기다리는_아기_그림이_품종마다_다_있다() -> void:
	for look in CatParade.LOOKS:
		var names: Array = CatView.KITTEN_FRAMES.duplicate()
		for i in CatView.KITTEN_TAILS:
			names.append("wait_tail_%d" % i)
		for frame in names:
			var path: String = CatView.KITTEN_DIR + look + "/" + frame + ".png"
			assert_true(ResourceLoader.exists(path), path)
			if ResourceLoader.exists(path):
				assert_eq(load(path).get_size(), Vector2(256, 240), path)
		assert_true(ResourceLoader.exists(CatView.KITTEN_DIR + look + "/face.png"), look + " 얼굴")
		assert_true(ResourceLoader.exists(CatView.KITTEN_DIR + look + "/scared.png"), look + " 놀람")


func test_높이_뛴_아기는_HUD_밑으로_부드럽게_눌린다() -> void:
	assert_eq(WORLD.soft_top(400.0, WORLD.KITTEN_TOP), 400.0, "하한 아래는 그대로")
	assert_true(WORLD.soft_top(0.0, WORLD.KITTEN_TOP) > WORLD.soft_top(-100.0, WORLD.KITTEN_TOP), "더 높으면 조금 더 위 (멈추지 않음)")
	assert_true(WORLD.soft_top(-300.0, WORLD.KITTEN_TOP) > 150.0, "아주 높아도 HUD 아래")


## 떠다니는 자리 (2026-11-17): 6자리가 서로 안 겹치고, 모두 주인공 몸 뒤쪽(앞 길을 안 가림), 화면 안
func test_떠다니는_자리는_서로_안_겹치고_주인공_뒤() -> void:
	var body := Vector2(100.0, 75.0)  # 앉은 아기 몸 (구름 포함 대략)
	for i in Balance.PARADE_MAX:
		var a := CatParade.slot(i)
		assert_true(a.x + body.x * 0.5 <= -Balance.CAT_BODY_SIZE.x * 0.5 + 10.0, "자리 %d는 주인공 몸 뒤 (%.0f)" % [i, a.x])
		assert_true(Balance.CAT_SCREEN_X + a.x - body.x * 0.5 >= 10.0, "자리 %d 화면 왼쪽 안" % i)
		assert_true(a.y < 0.0, "자리 %d는 위" % i)
		for j in range(i + 1, Balance.PARADE_MAX):
			var d := (a - CatParade.slot(j)).abs()
			assert_true(d.x >= body.x or d.y >= body.y, "자리 %d·%d 겹침 %s" % [i, j, d])


func test_둥실_박자는_아기마다_다르다() -> void:
	var a := CatParade.bob(1.0, 0.1)
	var b := CatParade.bob(1.0, 0.7)
	assert_false(a.is_equal_approx(b), "같은 때 다른 높이")
	for t in [0.0, 0.5, 1.3, 7.0]:
		assert_true(absf(CatParade.bob(t, 0.4).y) <= Balance.KITTEN_BOB + 0.01)


## 카메라: 아기 수와 상관없이 주인공 화면 자리는 그대로 (줄 때문에 옮기던 카메라 지움, 앞 시야 v0.7.0과 같음)
func test_6마리여도_주인공_자리와_앞_시야는_그대로() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.show_start = false
	add_child(main)
	var world: Node2D = main.get_node("World")
	world.sim.parade.fill(Balance.PARADE_MAX)
	await wait_frames(40)
	assert_eq(world.cat.position.x, Balance.CAT_SCREEN_X, "주인공 화면 x")
	var last := -1
	for i in Balance.PARADE_MAX:
		var holder: Node2D = world.get_node("Kitten%d" % i)
		assert_true(holder.visible, "아기 %d 보임" % i)
		assert_eq(holder.get_node("View").breed, world.sim.parade.cats[i].look, "자리 %d 품종" % i)
		assert_true(holder.position.distance_to(world.kitten_target(i)) < 40.0, "자리 %d 근처에 떠 있음" % i)
		last = maxi(last, holder.get_index())
	assert_true(world.cat.get_index() > last, "주인공이 아기들 위")
	main.queue_free()


## 능력 (2026-11-17): 준비된 아기만, 쓰면 다시 충전
func _with(look: String) -> RunnerSim:
	var sim := _sim()
	sim.accelerate = false
	sim.items.clear()
	sim.obstacles.clear()
	sim.parade.cats.append({"look": look, "quirk": 0.5, "cool": 0.0})
	return sim


func test_냥펀치는_앞_장애물로_날아가_부순다() -> void:
	var sim := _with("tuxedo")
	sim.obstacles.append({"id": 901, "kind": "ac", "x": sim.x + 500.0, "w": 110.0, "y0": sim.y, "y1": sim.y + 88.0, "base": sim.y})
	sim.step(DT, false)
	assert_eq(sim.parade.skill_used[0].skill, "punch", "날아감")
	assert_true(sim.obstacles[0].has("punch"), "곧 부서질 장애물")
	var hit := false
	for i in int(Balance.SKILL_PUNCH_TRAVEL / DT) + 2:
		sim.step(DT, false)
		hit = hit or sim.parade.skill_used.any(func(e: Dictionary) -> bool: return e.skill == "punch_hit")
	assert_true(hit, "닿아서 부숨")
	assert_true(sim.obstacles.is_empty(), "장애물 없어짐")
	assert_eq(sim.hearts, Balance.HEARTS_MAX)
	assert_true(sim.parade.cats[0].cool > Balance.KITTEN_SKILLS.tuxedo.every - 1.0, "다시 충전")
	assert_eq(CatParade.charge({"look": "cow", "cool": INF}), -1.0, "능력 없는 아기")


func test_물어_오기는_놓친_생선을_먹은_것으로() -> void:
	var sim := _with("cheese")
	sim.combo.count = 7
	sim.items.append({"kind": "fish", "x": sim.x - 200.0, "y": sim.y + 300.0})  # 이미 지나친 필수 생선
	var fish := sim.fish
	sim.step(DT, false)
	assert_eq(sim.fish, fish + 1, "생선 수 +1")
	assert_eq(sim.combo.count, 8, "콤보 이어짐")
	assert_eq(sim.parade.skill_used[0].skill, "fetch")
	sim.items.append({"kind": "fish", "x": sim.x - 200.0, "y": sim.y + 300.0})
	sim.step(DT, false)
	assert_eq(sim.combo.count, 0, "충전 중이면 끊김")


func test_반짝_코는_앞_생선_3마리를_황금으로() -> void:
	var sim := _with("calico")
	for k in 5:
		sim.items.append({"kind": "fish", "x": sim.x + 300.0 + 60.0 * k, "y": sim.y + 40.0})
	sim.step(DT, false)
	var golds := sim.items.filter(func(item: Dictionary) -> bool: return item.kind == "gold")
	assert_eq(golds.size(), Balance.SKILL_GOLD_COUNT, "3마리")
	assert_true(sim.items.filter(func(item: Dictionary) -> bool: return item.kind == "fish").all(func(item: Dictionary) -> bool: return item.x > golds.back().x), "가까운 것부터")
	assert_eq(sim.parade.skill_used[0].skill, "sparkle")


func test_능력_없는_아기와_다시_채우기() -> void:
	var sim := _with("cow")
	sim.obstacles.append({"id": 902, "kind": "pot", "x": sim.x + 500.0, "w": 48.0, "y0": sim.y, "y1": sim.y + 38.0, "base": sim.y})
	sim.step(DT, false)
	assert_true(sim.parade.skill_used.is_empty(), "젖소는 능력 없음")
	sim.parade.cats.append({"look": "tuxedo", "quirk": 0.1, "cool": 5.0})
	sim.step(DT, false)
	assert_true(sim.parade.skill_used.is_empty(), "충전 중")
	sim.parade.refill()
	sim.step(DT, false)
	assert_eq(sim.parade.skill_used.size(), 1, "다시 채우면 바로 씀")
