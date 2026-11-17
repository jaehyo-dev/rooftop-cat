extends TestCase
## 아기 움직임 (방식 A, 6마리, KittenMotion): 바닥 붙음, 달리기 장 넘김, 상태 고르기, 공중 자세, 도망 순서.
## 그림의 발 미끄러짐·머리 고정은 tools/test_kitten_motion.py (그림을 재므로 파이썬)

const WORLD := preload("res://scripts/world_view.gd")
const GROUND_TOL := 1.0   # 땅 위 발끝과 바닥 (게임 픽셀)


## 6마리 모두: 그림이 다 있고 크기가 같으며, 땅 자세 그림(달리기·웅크림·도약·착지·멈칫·움츠림·펄쩍)의 발끝이 기준선과 1px 안
func test_아기마다_그림이_다_있고_발끝이_기준선에() -> void:
	var base: int = KittenMotionData.ANCHOR[1]
	for look in CatParade.LOOKS:
		assert_true(KittenMotionData.ADVANCE.has(look), look + " 달리기 장 거리")
		var names := KittenView.frames() if look == "cheese" else TestCase.pick(KittenView.frames(), 4)  # 로컬은 대표만
		for frame in names + ["scared_upper"]:
			var path: String = KittenView.DIR + look + "/" + frame + ".png"
			assert_true(ResourceLoader.exists(path), path)
			if not ResourceLoader.exists(path):
				continue
			var img: Image = load(path).get_image()
			if img.is_compressed():
				img.decompress()
			assert_eq(img.get_size(), Vector2i(300, 260), path)
			if frame == "scared_upper" or frame.trim_suffix("_b") in ["rise", "apex", "fall", "flail"] or frame.begins_with("flip_"):
				continue
			var bottom := img.get_used_rect().end.y
			assert_true(absf(bottom - base) * KittenMotion.px() <= GROUND_TOL, "%s 발끝 %d / 기준 %d" % [path, bottom, base])


## 달린 거리로 장을 넘긴다 (한 바퀴 = a_stride, 32장 차례로)
func test_달린_거리로_장을_넘긴다() -> void:
	var n: int = KittenMotionData.RUN_FRAMES
	assert_eq(n, 32, "8장 x 사이 장 4")
	assert_eq(KittenMotionData.BOB.size(), n, "장마다 윗몸 내려앉음")
	for look in CatParade.LOOKS:
		var stride := KittenMotion.a_stride(look)
		assert_true(stride > 60.0, "%s 한 바퀴 %.1f" % [look, stride])
		var seen: Array[int] = []
		for i in n * 10:
			var k := KittenMotion.a_frame(stride * (i + 0.5) / (n * 10.0), look)
			if seen.is_empty() or seen[-1] != k:
				seen.append(k)
		assert_eq(seen, range(n), look)
		assert_eq(KittenMotion.a_frame(stride * 2.0 + 0.1, look), 0, "바퀴가 돌아옴")


## 아기 자세는 아기 자신의 상태로: 땅 = 달리기, 오를 때·내릴 때 = 속도 방향, 닿는 순간 = 착지 눌림
func test_자세는_아기_자신의_상태로() -> void:
	assert_eq(KittenMotion.state({"ground": true, "since_land": 5.0}, 0.0).kind, "run")
	var land := KittenMotion.state({"ground": true, "since_land": 0.0}, 0.0)
	assert_eq(land.land_k, 0.0, "닿은 순간")
	var first := KittenMotion.squash(land.land_k, 0.0, 0.5)
	var deepest := KittenMotion.squash(KittenMotion.LAND_ATTACK, 0.0, 0.5)
	assert_true(deepest < 0.85, "닿은 직후 크게 눌림 (%.2f)" % deepest)
	assert_true(first < 0.95 and first > deepest + 0.05, "닿는 첫 장면은 덜 눌림 (%.2f)" % first)
	var area := deepest * KittenMotion.widen(KittenMotion.LAND_ATTACK)
	assert_true(area > 0.85 and area < 1.0, "착지 눌림은 가로로 퍼져 작아 보이지 않음 (%.2f)" % area)
	assert_eq(KittenMotion.widen(1.0), 1.0, "착지가 끝나면 가로 그대로")
	assert_eq(KittenMotion.air_pose({}, "rise", false, 900.0, 0.016), "rise_b", "주인공 오름(다리 모음)은 아기도 다리 모은 그림")
	assert_true(KittenMotion.squash(1.0, 0.25, 0.5) > 0.97, "달릴 때 눌림은 아주 조금")
	var up := KittenMotion.state({"ground": false, "kpose": "rise"}, 0.8)
	var down := KittenMotion.state({"ground": false, "kpose": "fall_b"}, -0.8)
	assert_eq(up.kind, "rise", "공중 자세는 주인공이 그 자리에서 한 자세(기록)")
	assert_eq(down.kind, "fall_b")
	assert_true(up.tilt < 0.0 and down.tilt > 0.0, "오를 때 코가 위, 내릴 때 아래")
	assert_eq(KittenMotion.state({"ground": false, "kpose": "flip_ball", "spin": 2.0}, 0.3).tilt, 2.0, "앞구르기는 주인공 회전 그대로")
	assert_eq(KittenMotion.state({"ground": false, "kpose": "flail", "rot": 0.3}, 0.3).tilt, 0.3, "허우적은 주인공 기울기")
	assert_true(KittenMotion.jumps_soon({"ground": false, "since_jump": 0.05}), "앞에서 주인공이 막 뜀 → 미리 웅크림")
	assert_false(KittenMotion.jumps_soon({"ground": false, "since_jump": 2.0}), "옥상 끝에서 떨어지는 건 웅크리지 않음")
	assert_false(KittenMotion.jumps_soon({"ground": true, "since_jump": 0.0}), "땅")
	assert_eq(KittenMotion.air_pose({}, "crouch", false, 500.0, 0.016), "takeoff", "땅에서 막 뛴 웅크림은 도약 그림 (웅크린 그림이 떠오르지 않게)")
	assert_eq(KittenMotion.air_pose({}, "crouch", false, 500.0, 0.016, true), "crouch", "그물에서 튕기는 웅크림은 그대로 (6차 검토)")


## 공중 자세 따라 하기 (motion2): 주인공 자세마다 맞는 아기 그림, 공중에서 같은 그림이 0.12초를 넘지 않음 (요구)
func test_공중에서_같은_그림으로_떠_있지_않는다() -> void:
	var frames := KittenView.frames()
	var dt := 1.0 / 60.0
	for scene in _air_scenes():
		var memo := {}
		var same := 0.0
		var last := ""
		var seen := {}
		for f in scene.frames:
			var name := KittenMotion.air_pose(memo, f[0], f[1], f[2], dt)
			assert_true(name == "run" or name in frames, "%s: 아기 그림 %s 있음 (run = 달린 거리로 고르는 달리기)" % [scene.name, name])
			seen[name.trim_suffix("_b")] = true
			same = same + dt if name == last else dt
			last = name
			if not f[1]:
				assert_true(same <= 0.12 + 0.001, "%s: 공중에서 %s %.2f초" % [scene.name, name, same])
		for want in scene.want:
			assert_true(seen.has(want), "%s: %s 자세를 따라 함 (%s)" % [scene.name, want, str(seen.keys())])


## 주인공 자세 차례 [그림, 땅, 세로 속도] (60장/초). 점프는 RunnerSim + CatPose 그대로, 트램펄린·앞구르기·허우적은 자세 순서를 직접
func _air_scenes() -> Array:
	var out := []
	for hold in [0.0, 0.5, 1.0]:
		var sim := RunnerSim.new(1)
		var frames := []
		for i in 120:
			sim.step(1.0 / 60.0, i == 0 or i / 60.0 < JumpModel.max_hold_time() * hold)  # 0 = 톡 누름
			frames.append([CatPose.pose(sim).frame, sim.on_ground, sim.vy])
		out.append({"name": "점프 누름 %.1f" % hold, "frames": frames, "want": ["takeoff", "apex", "fall", "land"] if hold > 0.0 else ["apex", "fall", "land"]})  # 웅크림은 땅에서 미리 (jumps_soon)
	var flip := []
	var tramp := []
	var flop := []
	for i in 6:
		flip.append(["rise", false, 300.0 - i * 50.0])
		tramp.append(["crouch", false, 0.0])
	for i in 8:
		tramp.append(["takeoff", false, 900.0])
	for i in int(Balance.CAT_FLIP_TIME * 60.0):
		var deg := rad_to_deg(CatPose.flip_angle(i / (Balance.CAT_FLIP_TIME * 60.0)))
		var k := CatPose.FLIP_FROM_DEG.size() - 1
		while deg < CatPose.FLIP_FROM_DEG[k]:
			k -= 1
		flip.append([CatPose.FLIP_FRAMES[k], false, 100.0 - i * 20.0])
		tramp.append([CatPose.FLIP_FRAMES[k], false, 800.0 - i * 50.0])
	for i in 60:
		flip.append(["fall", false, -i * 40.0])
		tramp.append(["fall" if i > 20 else "rise", false, 300.0 - i * 40.0])
		flop.append(["flail", false, 600.0 - i * 50.0])
	out.append({"name": "더블점프 앞구르기", "frames": flip, "want": ["flip_tuck", "flip_curl", "flip_ball", "flip_open", "fall"]})
	out.append({"name": "트램펄린 퍼펙트", "frames": tramp, "want": ["crouch", "takeoff", "flip_ball", "apex", "fall"]})
	out.append({"name": "트램펄린 허우적", "frames": flop, "want": ["flail"]})
	return out


## 땅 위 눌림은 세로만 (가로 배율이 그대로라 발 x가 안 바뀜), 발끝 축이라 발 높이도 그대로
func test_눌림은_세로만() -> void:
	var view := KittenView.new()
	add_child(view)
	view.show_motion("cheese", {"kind": "run", "dist": 10.0, "squash": 0.8})
	var k := KittenMotion.px()
	assert_true(is_equal_approx(view.scale.x, k), "가로 배율 그대로")
	assert_true(is_equal_approx(view.scale.y, k * 0.8), "세로만 눌림")
	view.queue_free()


## 도망 그림: 움츠림·펄쩍·서서 놀람은 놀란 그림, 달리기는 놀란 윗몸을 덮음 (도망 때 웃는 얼굴, 2026-11-17)
func test_도망은_내내_놀란_얼굴() -> void:
	var vx := 600.0
	var hop := (KittenMotion.STARTLE_CROUCH + KittenMotion.STARTLE) * 0.5
	assert_eq(WORLD.runaway_pose(KittenMotion.runaway(0.01, vx)), "scared_crouch")
	assert_eq(WORLD.runaway_pose(KittenMotion.runaway(hop, vx)), "scared_hop", "깜짝 펄쩍은 위로 솟는 그림")
	assert_eq(WORLD.runaway_pose(KittenMotion.runaway(KittenMotion.STARTLE + 0.02, vx)), "startle")
	assert_eq(WORLD.runaway_pose(KittenMotion.runaway(0.6, vx)), "run")
	var view := KittenView.new()
	add_child(view)
	var upper: Sprite2D = view.get_child(0).get_child(0).get_child(1)
	for look in CatParade.LOOKS:
		view.show_motion(look, {"kind": "run", "dist": 50.0, "surprised": true})
		assert_true(upper.visible and upper.texture != null, look + " 도망 달리기에 놀란 윗몸")
		var f := KittenMotion.a_frame(50.0, look)
		assert_eq(upper.position.y, float(KittenMotionData.BOB[f]), look + " 윗몸은 그 장만큼 내려앉음")
		view.show_motion(look, {"kind": "run", "dist": 50.0})
		assert_false(upper.visible, look + " 줄 달리기는 웃는 얼굴 그대로")
	view.queue_free()


## 도망: 멈칫(STARTLE) → 몸 돌림 → 뒤로 달림 (뒤로 간 거리가 늘기만)
func test_도망은_멈칫_돌림_달림() -> void:
	var vx := 600.0
	var hop := (KittenMotion.STARTLE_CROUCH + KittenMotion.STARTLE) * 0.5
	assert_eq(KittenMotion.runaway(hop, vx).kind, "startle")
	assert_eq(KittenMotion.runaway(hop, vx).back, 0.0, "멈칫하는 동안 다리는 멈춤")
	assert_eq(KittenMotion.runaway(KittenMotion.SKID * 0.9, vx).kind, "crouch", "끼익 멈추는 동안 내내 움츠림 (6차 검토)")
	assert_eq(KittenMotion.runaway(KittenMotion.SKID, vx).dx, KittenMotion.runaway(KittenMotion.STARTLE + KittenMotion.STAND, vx).dx, "멈춘 뒤에는 바닥에 선 채")
	assert_eq(KittenMotion.runaway(KittenMotion.STARTLE + 0.02, vx).kind, "startle", "펄쩍 뒤 서서 놀람")
	assert_eq(KittenMotion.runaway(KittenMotion.STARTLE + KittenMotion.STAND + 0.02, vx).kind, "turn")
	assert_eq(KittenMotion.runaway(0.01, vx).kind, "crouch", "움츠렸다가")
	for i in 30:
		assert_true(absf(KittenMotion.runaway(KittenMotion.STARTLE + KittenMotion.STAND + KittenMotion.TURN * i / 30.0, vx).facing) >= KittenMotion.TURN_POP, "돌 때 얇아지지 않음")
	var run := KittenMotion.runaway(0.6, vx)
	assert_eq(run.kind, "run")
	assert_eq(run.facing, -1.0)
	var last := -INF
	var top := 0.0
	for i in 60:
		var r := KittenMotion.runaway(i * 0.02, vx)
		var speed: float = (r.dx - last) / 0.02 if i > 0 else vx
		assert_true(speed <= vx + 1.0, "놀란 뒤 빨라지지 않음 (서서히 멈춤)")
		last = r.dx
		top = maxf(top, r.dx)
	assert_true(top > 0.0 and last < 0.0, "앞으로 밀리며 멈췄다가 뒤로 달림")
	assert_true(KittenMotion.runaway_y(200.0, 100.0, 0.0) == 200.0 and KittenMotion.runaway_y(200.0, 100.0, 1.0) == 100.0, "공중에서 놀라면 아래 옥상으로")
