extends TestCase
## 고양이 프레임 애니메이션: 상태별 프레임 고르기, 떨어짐 판정, 그림 크기·기준점, 프레임 정렬(떨림 없음).

const DT := 1.0 / 120.0


func _sim_on_roofs(list: Array) -> RunnerSim:
	var sim := RunnerSim.new(1)
	sim.accelerate = false
	sim.roofs.clear()
	for roof in list:
		sim.roofs.append(roof)
	sim.x = list[0].left + 100.0
	sim.y = list[0].top
	sim.on_ground = true
	sim.set("_ground_roof", sim.roofs[0])
	return sim


func test_달리기는_달린_거리로_6프레임을_차례로_돈다() -> void:
	var sim := RunnerSim.new(1)
	var n := CatPose.RUN_FRAMES.size()
	var seen: Array[String] = []
	for i in n * 2:
		sim.x = Balance.CAT_STRIDE * (i + 0.5) / n
		seen.append(CatPose.pose(sim).frame)
	assert_eq(seen, CatPose.RUN_FRAMES + CatPose.RUN_FRAMES)
	sim.x = -Balance.CAT_STRIDE * 0.05
	assert_eq(CatPose.pose(sim).frame, CatPose.RUN_FRAMES[-1], "음수 거리도 순서대로")
	for i in n:
		sim.x = Balance.CAT_STRIDE * (i + 0.5) / n
		assert_eq(CatPose.pose(sim).tilt, 0.0, "달릴 때 기울지 않음")


func test_점프는_웅크림_도약_올라감_내려옴_착지_순서() -> void:
	var sim := RunnerSim.new(1)
	var order: Array[String] = []
	var hold := JumpModel.max_hold_time() * 0.6
	var t := 0.0
	for i in 240:
		sim.step(DT, t < hold)
		t += DT
		var frame: String = CatPose.pose(sim).frame
		if order.is_empty() or order[-1] != frame:
			order.append(frame)
		if sim.on_ground and sim.time_since_land > Balance.CAT_LAND_TIME and t > 0.2:
			break
	assert_eq(order.slice(0, 5), ["crouch", "takeoff", "rise", "fall", "land"] as Array[String])
	assert_true(order.size() > 5 and order[5].begins_with("run_"), "착지 뒤 달리기로 %s" % str(order))


func test_길게_누를수록_도약할_때_몸이_더_늘어난다() -> void:
	var stretch := []
	for hold in [0.3, 1.0]:
		var sim := RunnerSim.new(1)
		var max_x := 0.0
		for i in 120:
			sim.step(DT, i * DT < JumpModel.max_hold_time() * hold)
			var pose := CatPose.pose(sim)
			if pose.frame == "takeoff":
				max_x = maxf(max_x, pose.scale.x)
		stretch.append(max_x)
	assert_true(stretch[1] > stretch[0] and stretch[0] > 1.0, "가로 늘어남 %s" % str(stretch))


func test_뛰어서_올라갈_때도_내려올_때도_기울지_않는다() -> void:
	# 낮게 뛴 경우(0.05초)와 가장 높게 뛴 경우(끝까지 누름) 모두, 공중에서 내내 tilt 0
	for hold in [0.05, 5.0]:
		var sim := _sim_on_roofs([{"left": 0.0, "right": 100000.0, "top": 200.0}])
		sim.accelerate = false
		var t := 0.0
		var seen := {}
		var peak := 0.0
		while t < 3.0:
			sim.step(DT, t < hold and t >= 0.0)
			t += DT
			if not sim.on_ground and sim.time_since_jump >= Balance.CAT_CROUCH_TIME:
				var pose := CatPose.pose(sim)
				seen[pose.frame] = true
				peak = maxf(peak, sim.y - 200.0)
				assert_eq(pose.tilt, 0.0, "공중 기울기 0 (%s, 누름 %s)" % [pose.frame, hold])
		assert_true(seen.has("rise") and seen.has("fall"), "올라감·내려옴 모두 확인 %s" % str(seen.keys()))
		if hold > 1.0:
			assert_true(peak > Balance.JUMP_MAX_HEIGHT * 0.95, "가장 높게 뜀 %s" % peak)


func test_더는_올라설_수_없으면_허우적거린다() -> void:
	var roofs := [{"left": -500.0, "right": 0.0, "top": 200.0}, {"left": 300.0, "right": 5000.0, "top": 250.0}]
	var sim := _sim_on_roofs(roofs)
	sim.on_ground = false
	sim.x = 100.0  # 틈 위
	sim.vy = -100.0
	sim.y = 249.0 - Balance.DOUBLE_JUMP_MAX_HEIGHT + 1.0
	assert_false(sim.is_doomed(), "더블점프가 남아 있으면 그만큼 아래여도 아직 오를 수 있음")
	sim.set("_double_used", true)  # 아래부터는 더블점프를 이미 쓴 경우
	sim.y = 260.0
	assert_false(sim.is_doomed(), "앞 옥상보다 높으면 아직 내려앉을 수 있음")
	sim.y = 249.0
	assert_true(sim.is_doomed(), "점프 없이 앞 옥상 높이보다 낮아지면 벽에 막혀 끝")
	assert_eq(CatPose.pose(sim).frame, "flail")
	sim.set("_jumped", true)
	sim.y = 250.0 - Balance.CAT_BODY_SIZE.y + 1.0
	assert_false(sim.is_doomed(), "점프했고 몸 높이 안쪽이면 투명화로 오를 수 있음")
	sim.y = 250.0 - Balance.CAT_BODY_SIZE.y - 1.0
	assert_true(sim.is_doomed(), "몸 높이보다 더 낮으면 끝")
	sim.vy = 10.0
	assert_false(sim.is_doomed(), "올라가는 중이면 아님")
	sim.vy = -10.0
	sim.x = 2000.0
	sim.y = 240.0
	assert_true(sim.is_doomed(), "발이 옥상 위인데 옥상보다 아래면 끝")
	sim.y = 260.0
	assert_false(sim.is_doomed(), "옥상보다 위면 내려앉음")


func test_실제로_틈에_떨어지면_허우적거리고_그전에는_아니다() -> void:
	var sim := RunnerSim.new(1)
	var flailed_at := -1.0
	var t := 0.0
	while not sim.game_over and t < 10.0:
		sim.step(DT, false)
		t += DT
		if CatPose.pose(sim).frame == "flail" and flailed_at < 0.0:
			flailed_at = t
			assert_false(sim.on_ground)
	assert_true(sim.game_over)
	assert_true(flailed_at > 0.0, "떨어지는 동안 허우적거림")
	# 허우적거림: 시간에 따라 몸이 앞뒤로 흔들린다
	var tilts := {}
	for i in 12:
		sim.elapsed = i * 0.03
		tilts[snappedf(CatPose.pose(sim).tilt, 1.0)] = true
	assert_true(tilts.size() >= 5, "흔들림 %s" % str(tilts.keys()))


func test_고양이_그림은_충돌_판정_크기에_맞고_기준점이_발끝() -> void:
	var cat := CatView.new()
	add_child(cat)
	await wait_frames(1)
	var sprite: Sprite2D = cat.get_node("Sprite")
	assert_eq(sprite.position + sprite.offset, -CatView.ANCHOR, "그림의 기준점이 노드 원점(발끝) (공중제비 축으로 옮긴 만큼 offset을 되돌림)")
	for frame in CatPose.ALL_FRAMES:
		var texture: Texture2D = load(CatView.FRAME_DIR + frame + ".png")
		assert_not_null(texture, frame)
		if texture == null:
			continue
		var used := texture.get_image().get_used_rect()
		# 모든 프레임의 가장 아랫줄(발끝)이 기준점 높이에 있다 (정렬 도구가 맞춤, 반투명 가장자리 1~2픽셀 허용).
		# 튕겨 뜬 장(hit_fly)만 시트에서 떠 있던 높이만큼 위 (tools/make_hero_frames.py LIFTED)
		var lift := 0.0 if frame != "hit_fly" else 14.0
		assert_true(absf(used.end.y + lift - CatView.ANCHOR.y) <= 3.0, "%s 발끝 %d" % [frame, used.end.y])
	cat.queue_free()


func test_달리기_프레임은_몸_중심이_흔들리지_않는다() -> void:
	# 꼬리 쪽(왼쪽 30%)을 뺀 불투명 픽셀의 가로 무게중심이 프레임마다 거의 같아야 화면이 떨리지 않는다.
	# 앉은 그림은 꼬리만 달라 무게중심 대신 오른쪽 끝(얼굴·가슴)을 맞춤 (review/v0.7.0/2c-fix/cut_sit.py): 모두 같은 오른쪽 끝
	for frame in CatPose.ALL_FRAMES:
		if frame.begins_with("sit_body"):
			continue  # 앉은 몸은 한 장이라 떨릴 수 없음 (test_앉은_고양이는_바닥이_0px도_움직이지_않는다)
		var image: Image = load(CatView.FRAME_DIR + frame + ".png").get_image()
		var used := image.get_used_rect()
		var left := used.position.x + used.size.x * 0.3
		var sum := 0.0
		var count := 0
		for y in range(used.position.y, used.end.y, 2):
			for x in range(int(left), used.end.x, 2):
				if image.get_pixel(x, y).a > 0.5:
					sum += x
					count += 1
		var center := sum / maxf(count, 1.0)
		assert_true(absf(center - CatView.ANCHOR.x) <= 3.0, "%s 몸 중심 %.1f" % [frame, center])


func test_상태에_맞는_그림과_투명화() -> void:
	var cat := CatView.new()
	add_child(cat)
	await wait_frames(1)
	var sim := RunnerSim.new(3)
	var frames := {}
	for i in 120:
		sim.step(DT, false)
		cat.show_state(sim, DT)
		frames[cat.frame_name] = true
	assert_eq(frames.size(), CatPose.RUN_FRAMES.size(), "달리며 달리기 프레임을 모두 씀")
	assert_eq(cat.modulate.a, 1.0)
	sim.ghost_time = 1.0
	cat.show_state(sim, DT)
	assert_true(cat.modulate.a < 0.6, "투명화 중 반투명")
	cat.queue_free()


## 높은 곳 공중(아래 옥상 없음)에 띄운 sim
func _sim_in_air() -> RunnerSim:
	var sim := _sim_on_roofs([{"left": -2000.0, "right": 0.0, "top": 200.0}, {"left": 100000.0, "right": 200000.0, "top": 0.0}])
	sim.x = -10.0
	sim.on_ground = false
	sim.set("_jumped", true)
	sim.y = 600.0
	sim.vy = 0.0
	return sim


func test_더블점프는_몸을_말아_앞구르기_한_바퀴를_돌고_착지하면_끊긴다() -> void:
	var sim := _sim_in_air()
	sim.step(DT, true)  # 더블점프 (평소 점프는 회전 없음: 위 test_뛰어서_올라갈_때도_내려올_때도_기울지_않는다)
	assert_true(sim.double_jumped)
	var order: Array[String] = [CatPose.pose(sim).frame]
	var last_spin: float = CatPose.pose(sim).spin
	assert_true(last_spin < 0.2, "막 돌기 시작")
	while sim.time_since_double_jump < Balance.CAT_FLIP_TIME - DT:
		sim.y = 600.0
		sim.step(DT, true)
		var p: Dictionary = CatPose.pose(sim)
		assert_true(p.spin >= last_spin, "한 방향으로 돎")
		last_spin = p.spin
		if order[-1] != p.frame:
			order.append(p.frame)
	assert_eq(order, ["flip_tuck", "flip_curl", "flip_ball", "flip_open"] as Array[String], "숙이기 → C자 → 공 → 펴기")
	assert_true(last_spin > TAU * 0.97, "한 바퀴 (%.2f)" % last_spin)
	sim.step(DT * 2.0, true)
	assert_eq(CatPose.pose(sim).spin, 0.0, "끝나면 회전 없음")
	assert_eq(CatPose.pose(sim).frame, "fall", "끝나면 누르고 있어도 내려옴 그림으로 이어짐")
	# 도는 중에 착지하면 바로 끊김
	sim.time_since_double_jump = 0.1
	sim.on_ground = true
	assert_eq(CatPose.pose(sim).spin, 0.0, "착지하면 끊김")
	sim.on_ground = false
	sim.ghost_time = 0.5
	assert_eq(CatPose.pose(sim).spin, 0.0, "투명화면 끊김")


func test_앞구르기_회전은_공일_때_가장_빠르다() -> void:
	var speed := func(k: float) -> float: return CatPose.flip_angle(k + 0.01) - CatPose.flip_angle(k)
	assert_true(speed.call(0.5) > speed.call(0.1) * 2.0, "공 > 말기")
	assert_true(speed.call(0.5) > speed.call(0.9) * 2.0, "공 > 펴기")
	assert_eq(CatPose.flip_angle(0.0), 0.0)
	assert_true(absf(CatPose.flip_angle(1.0) - TAU) < 0.001, "딱 한 바퀴")
	var curl_end := CatPose.flip_angle(0.25)
	var open_start := CatPose.flip_angle(0.75)
	assert_true(absf(rad_to_deg(curl_end) - 60.0) < 8.0, "말기 끝 약 60도 (%.0f)" % rad_to_deg(curl_end))
	assert_true(absf(rad_to_deg(open_start) - 300.0) < 8.0, "펴기 시작 약 300도 (%.0f)" % rad_to_deg(open_start))


func test_트램펄린_결과별_자세() -> void:
	var tramp := {"kind": "tramp", "left": 0.0, "right": 210.0, "top": 210.0, "base": 200.0}
	var sim := _sim_in_air()
	sim.bounced_line = tramp
	sim.time_since_bounce = 0.0
	sim.vy = 500.0
	sim.time_since_jump = 5.0
	sim.bounce_result = "perfect"
	assert_eq(CatPose.pose(sim).frame, "crouch", "튕긴 직후는 아직 그물에 눌린 웅크림")
	sim.time_since_bounce = Balance.TRAMP_PUSH
	assert_eq(CatPose.pose(sim).frame, "takeoff", "퍼펙트: 도약 그림으로 늘어나며 발사")
	var launch_end := Balance.TRAMP_PUSH + Balance.CAT_LAUNCH_TIME
	sim.time_since_bounce = launch_end + 0.2
	assert_true(CatPose.pose(sim).frame.begins_with("flip_"), "그 뒤 앞구르기 자동 1회")
	sim.time_since_bounce = launch_end + Balance.CAT_FLIP_TIME + 0.01
	assert_eq(CatPose.pose(sim).spin, 0.0, "한 번만")
	sim.time_since_bounce = launch_end + 0.1
	sim.bounce_result = "good"
	assert_eq(CatPose.pose(sim).spin, 0.0, "그냥 누름은 앞구르기 없음")
	sim.time_since_bounce = Balance.TRAMP_PUSH + 0.01
	assert_eq(CatPose.pose(sim).frame, "takeoff", "누름도 도약 그림으로 발사")
	sim.bounce_result = "miss"
	assert_eq(CatPose.pose(sim).frame, "flail", "안 누르면 허우적")
	sim.rescuing = true
	assert_eq(CatPose.pose(sim).frame, "rise", "떨어지다 상자에 구제되면 허우적이 아니라 올라가는 자세")
	sim.rescuing = false
	sim.time_since_land = 0.0
	sim.on_ground = true
	assert_true(CatPose.pose(sim).frame != "flail", "내려서면 끝")


func test_공중제비_회전축은_몸_가운데() -> void:
	var cat := CatView.new()
	add_child(cat)
	await wait_frames()
	var sprite: Sprite2D = cat.get_node("Sprite")
	# 회전 0이면 그림 자리가 예전과 같다 (기준점이 발끝)
	assert_eq(sprite.position + sprite.offset, -CatView.ANCHOR)
	# 축은 발끝 위 몸 높이의 절반 (게임 픽셀)
	assert_true(absf(sprite.position.y * CatView.art_scale() + Balance.CAT_BODY_SIZE.y * 0.5) < 0.01)
	cat.queue_free()


func test_시작_화면은_앉아서_꼬리를_천천히_흔들고_가끔_눈을_깜빡인다() -> void:
	var tails := []
	var blinks := 0
	var t := 0.0
	while t < CatPose.SIT_WAG:
		var tail := CatPose.sit_tail(t)
		if tails.is_empty() or tails[-1] != tail:
			tails.append(tail)
		t += 0.01
	assert_eq(tails, [0, 1, 2, 3, 4, 5, 6, 7, 6, 5, 4, 3, 2, 1, 0], "꼬리 8장을 한 칸씩 오감 (건너뛰지 않음)")
	var blink_frames := 0
	t = 0.0
	while t < CatPose.SIT_BLINK_EVERY * 3.0:
		blink_frames += int(CatPose.sit_frame(t) == "sit_body_blink")
		blinks += int(CatPose.sit_frame(t) == "sit_body_blink" and CatPose.sit_frame(t - 0.01) == "sit_body")
		t += 0.01
	assert_eq(blinks, 3, "간격마다 한 번 깜빡")
	assert_true(blink_frames * 0.01 <= 3.0 * (CatPose.SIT_BLINK_TIME + 0.011), "깜빡임은 짧게")


func test_앉은_고양이는_바닥이_0px도_움직이지_않는다() -> void:
	# 몸 그림(눈 뜸·감음)의 아랫줄 모양이 같고, 꼬리는 바닥선 아래로 내려가지 않는다 (사용자 피드백: 위아래로 흔들림)
	var body: Image = load(CatView.FRAME_DIR + "sit_body.png").get_image()
	var blink: Image = load(CatView.FRAME_DIR + "sit_body_blink.png").get_image()
	var ground := body.get_used_rect().end.y
	assert_eq(blink.get_used_rect().end.y, ground)
	var checked := 0
	for x in range(0, body.get_width(), 2):  # 바닥에 닿는 열(엉덩이·앞발)마다 가장 아래 불투명 픽셀이 같다 (위치 차이 0px)
		if _bottom(body, x) >= ground - 12:
			assert_eq(_bottom(blink, x), _bottom(body, x), "열 %d" % x)
			checked += 1
	assert_true(checked > 40, "바닥 닿는 열 %d" % checked)
	for i in CatPose.SIT_TAILS:
		var tail: Image = load(CatView.FRAME_DIR + "sit_tail_%d.png" % i).get_image()
		assert_true(tail.get_used_rect().end.y <= ground, "꼬리 %d 바닥 아래로 안 감" % i)
	# 숨쉬기는 노드 원점(발끝)을 기준으로 곱해 바닥이 그대로
	var cat := CatView.new()
	add_child(cat)
	await wait_frames()
	for t in [0.0, 0.5, 1.0, 1.5]:
		cat.position = Vector2(100, 200)
		cat.show_sit(t)
		var sprite: Sprite2D = cat.get_node("Sprite")
		assert_true((sprite.global_transform * (CatView.ANCHOR + sprite.offset)).distance_to(cat.global_position) < 0.01, "발끝 %s" % t)
		assert_true(cat.get_node("Tail").visible, "앉으면 꼬리")
	cat.queue_free()


static func _bottom(img: Image, x: int) -> int:
	for y in range(img.get_height() - 1, -1, -1):
		if img.get_pixel(x, y).a > 0.08:
			return y
	return -1


func test_시작을_누르면_일어나는_그림을_잠깐_보이고_달린다() -> void:
	var cat := CatView.new()
	add_child(cat)
	await wait_frames()
	var sim := _sim_on_roofs([{"left": 0.0, "right": 4000.0, "top": 0.0}])
	cat.show_sit(0.0)
	assert_eq(cat.frame_name, "sit_body")
	cat.show_state(sim, 0.0)  # 시작 화면은 dt 0으로 자리만 맞춤: 일어나지 않음
	cat.show_sit(0.5)
	assert_eq(cat.frame_name, "sit_body")
	sim.step(DT, false)
	cat.show_state(sim, DT)
	assert_eq(cat.frame_name, "sit_up", "시작 첫 순간")
	for n in int(CatPose.STAND_TIME / DT) + 2:
		sim.step(DT, false)
		cat.show_state(sim, DT)
	assert_true(cat.frame_name.begins_with("run_"), "그다음 달리기 %s" % cat.frame_name)
	cat.queue_free()


func test_땅_슬라이딩은_낮추기_미끄러지기_일어나기_1_2_순서() -> void:
	var sim := _sim_on_roofs([{"left": 0.0, "right": 100000.0, "top": 200.0}])
	var order: Array[String] = []
	for f in 150:  # 0.2초 달리기 → 0.6초 슬라이딩 → 떼고 0.45초
		sim.step(DT, false, f >= 24 and f < 96)
		var frame: String = CatPose.pose(sim).frame
		if order.is_empty() or order[-1] != frame:
			order.append(frame)
	var slide := order.slice(order.find("slide_down"))
	assert_true(order[0].begins_with("run_") and not slide.is_empty(), str(order))
	assert_true(slide.slice(1, 3).has("slide_a") and slide.slice(1, 3).has("slide_b"), "낮추기 뒤 미끄러지기 a·b %s" % str(order))
	var up := order.find("slide_up1")
	assert_true(up > 0 and order[up + 1] == "slide_up2" and order[up + 2].begins_with("run_"), "일어나기 1 → 2 → 달리기 %s" % str(order))
	assert_false(order.has("slide_squash"), "달리다 슬라이딩하면 눌림 없음")


func test_공중_슬라이딩은_내리꽂기_눌림_미끄러지기_순서() -> void:
	var sim := _sim_on_roofs([{"left": 0.0, "right": 100000.0, "top": 200.0}])
	var order: Array[String] = []
	for f in 140:  # 점프(꾹) → 0.3초에 슬라이딩 누름(내리꽂기) → 누른 채 착지
		sim.step(DT, f < 12, f >= 36)
		var frame: String = CatPose.pose(sim).frame
		if order.is_empty() or order[-1] != frame:
			order.append(frame)
	var dive := order.find("dive")
	assert_true(dive > 0, str(order))
	assert_eq(order.slice(dive, dive + 3), ["dive", "slide_squash", "slide_a"] as Array[String], "내리꽂기 → 눌림 → 미끄러지기 %s" % str(order))


func test_피격은_맞는_순간_튕김_휘청_달리기_그림만_밀렸다_돌아옴() -> void:
	var sim := _sim_on_roofs([{"left": 0.0, "right": 100000.0, "top": 200.0}])
	sim.step(DT, false)
	sim.time_since_hit = 0.0
	var order: Array[String] = []
	var pushes := []
	for f in 80:
		var frame: String = CatPose.pose(sim).frame
		if order.is_empty() or order[-1] != frame:
			order.append(frame)
		pushes.append(CatView.hit_push(sim.time_since_hit))
		sim.step(DT, false)
	assert_eq(order.slice(0, 3), CatPose.HIT_FRAMES, str(order))
	assert_true(order[3].begins_with("run_"), "휘청 뒤 달리기 %s" % str(order))
	assert_true(pushes[0] == 0.0 and pushes.max() > CatView.HIT_PUSH * 0.95 and pushes[-1] == 0.0, "0 → 뒤로 → 제자리")
	for i in pushes.size() - 1:
		assert_true(absf(pushes[i + 1] - pushes[i]) < 6.0, "한 프레임에 6px 넘게 튀지 않음 %d" % i)
	sim.time_since_hit = 0.0
	for f in 70:  # 슬라이딩 중 맞아도(화분) 맞은 그림 → 끝나면 미끄러지기
		sim.step(DT, false, true)
		if f == 1:
			assert_eq(CatPose.pose(sim).frame, "hit", "슬라이딩 중 맞으면 맞은 그림")
	assert_true(CatPose.pose(sim).frame in CatPose.SLIDE_FRAMES, "피격 뒤 계속 누르면 미끄러지기 %s" % CatPose.pose(sim).frame)
	sim.time_since_hit = 0.3
	sim.on_ground = false
	assert_true(CatPose.pose(sim).frame != "hit_wobble", "공중에서는 휘청 대신 공중 그림")


func test_예전_화풍_그림이_모두_있다() -> void:
	# 시험 단추 "주인공 화풍: 예전" (로컬 빌드): 카툰에만 있는 그림은 비슷한 예전 그림으로 바꿔 읽는다
	for frame in CatPose.ALL_FRAMES:
		var name: String = CatView.PENCIL_SWAP.get(frame, frame)
		assert_true(ResourceLoader.exists(CatView.PENCIL_DIR + name + ".png"), name)
	CatView.pencil = true
	var cat := CatView.new()
	add_child(cat)
	await wait_frames(1)
	assert_eq(cat.frame_texture("slide_a").resource_path, CatView.PENCIL_DIR + "slide_0.png")
	CatView.pencil = false
	cat.show_state(_sim_on_roofs([{"left": 0.0, "right": 4000.0, "top": 0.0}]), 0.0)
	assert_eq(cat.frame_texture("slide_a").resource_path, CatView.FRAME_DIR + "slide_a.png", "단추를 다시 누르면 카툰")
	cat.queue_free()
