extends SceneTree
## 검토용 캡처: 실제 main 씬(World)에 정해진 입력을 1/60초 프레임마다 넣어 진행하며 화면을 PNG로 저장한다.
## 사용 (창이 잠깐 뜸, 헤드리스 불가): godot --path . --resolution 1280x720 -s res://tools/capture_review.gd -- <장면> <출력 폴더>
## 장면: double(넓은 틈 더블점프·공중제비), line_good(누름→퍼펙트), line_early(너무 이른 누름), line_miss(안 누름),
##       pole(판까지 점프+더블점프, 판에서 다시), camera(퍼펙트 + 더블점프로 높이 → 세로 카메라),
##       tramp_miss·tramp_good·tramp_perfect·tramp_early(트램펄린에 달려 들어가 안 누름·누름·퍼펙트·너무 이른 누름),
##       jump(달리기 → 최대 점프 → 착지 → 달리기, 전후 비교용)
## (line_*·camera 장면은 빨래줄 생성이 꺼져 있어 지금은 쓰지 않음)
## 저장: <출력 폴더>/f000.png ... (프레임마다), frames.csv(시간, 높이, 카메라, 판정)

const FPS := 60.0
const SPEED := 430.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: String = args[0]
	var out: String = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)  # 캡처 중에는 소리를 내지 않는다
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var world: Node2D = main.get_node("World")
	world.set_process(false)  # 프레임 진행은 여기서 직접
	world.sim = _course(scene)
	var sim: RunnerSim = world.sim
	# 장면별 줄 누름 계획 (닿는 순간 기준 초, 음수 = 닿기 전; null = 안 누름)
	var taps: Array = {"line_good": [-0.12, 0.0, -0.06, 0.0], "line_early": [-0.24], "line_miss": [null], "camera": [0.0],
			"tramp_good": [-0.08], "tramp_perfect": [0.0], "tramp_early": [-0.24], "tramp_miss": [null]}.get(scene, [])
	var edge: float = sim.roofs[0].right
	var press_x := edge - SPEED * JumpModel.max_air_time(Balance.LINE_HEIGHT) + 90.0 if scene.begins_with("line") or scene == "camera" else edge - 60.0
	var jump_frames := 7          # 첫 점프 누름 (최대)
	var dj_after := 0.30          # 점프(또는 줄 튕김) 뒤 더블점프까지 (초), 음수 = 안 씀
	if scene == "jump":
		press_x = -400.0
		jump_frames = 21  # 최대 점프 (0.35초 누름)
		dj_after = -1.0
	elif scene.begins_with("tramp"):
		press_x = INF  # 뛰지 않고 달려 들어감
		dj_after = -1.0
	elif scene.begins_with("line"):
		dj_after = -1.0
	elif scene == "camera":
		dj_after = 0.40  # 퍼펙트 튕김 꼭대기 무렵
	var press_left := 0
	var jumped_at := -1.0
	var bounced_at := -1.0
	var dj_done := false
	var tap_index := 0
	var on_plate := false
	var tapped := false
	var log := FileAccess.open(out + "/frames.csv", FileAccess.WRITE)
	log.store_line("i,t,y,vy,lift,frame,result,doubled,x,pressed,riding,tramp")
	var dt := 1.0 / FPS
	for i in int(4.0 * FPS):
		var pressed := false
		if sim.on_ground and sim.x >= press_x and jumped_at < 0.0:
			press_left = jump_frames
		if scene == "pole" and not on_plate and sim.on_ground and is_same(sim.get("_ground_roof"), sim.roofs[1]):
			on_plate = true
			# 판에 섬: 판 끝 무렵 다시 점프 + 더블점프
			press_x = sim.roofs[1].right - 20.0
			jumped_at = -1.0
			dj_done = false
		var since: float = sim.elapsed - (bounced_at if scene == "camera" else jumped_at)
		if press_left > 0:
			pressed = true
			press_left -= 1
		elif dj_after >= 0.0 and not dj_done and (jumped_at >= 0.0 if scene != "camera" else bounced_at >= 0.0) and since >= dj_after:
			dj_done = true
			press_left = 5
			pressed = true
		elif tap_index < taps.size() and not tapped:
			var touch := sim.line_touch_eta(0.6)
			var plan = taps[tap_index]
			if plan != null and not touch.is_empty() and not sim.is_riding() and touch.t <= -plan + dt and plan <= 0.0:
				pressed = true
				tapped = true
			elif plan != null and plan > 0.0 and sim.is_riding():
				pressed = true
				tapped = true
		# 누름을 실제 입력처럼 넣는다 (터치 한 손가락)
		if pressed:
			world.set("_touches", {0: true})
			if not world.get("_was_pressed"):
				world.set("_tap_pending", true)
		else:
			world.set("_touches", {})
		world._process(dt)
		main._process(dt)
		# 한 프레임에 로직이 두 step 돌아 step 신호(jumped·bounced)는 놓칠 수 있으니 지난 시간으로 본다
		if sim.time_since_jump < dt and jumped_at < 0.0:
			jumped_at = sim.elapsed - sim.time_since_jump
		if sim.time_since_bounce < dt:
			bounced_at = sim.elapsed - sim.time_since_bounce
			tapped = false
			tap_index += 1
		await process_frame
		# 창이 가려지면 macOS가 그리기를 건너뛰어 이전 화면이 저장될 수 있으니 직접 한 번 그린다
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(out + "/f%03d.png" % i)
		var tramp_frame := ""  # 트램펄린 그림 (그림을 바꾸는 순간이 닿는 순간과 맞는지 확인용)
		for s in sim.structures:
			if s.kind == "tramp":
				tramp_frame = world.tramp_look(sim, s).frame
		log.store_line("%d,%.3f,%.1f,%.0f,%.1f,%s,%s,%s,%s,%s,%s,%s" % [i, sim.elapsed, sim.y, sim.vy, world.get("_cam_lift"), world.cat.frame_name,
				sim.bounce_result, str(sim.time_since_double_jump < dt), "%.0f" % sim.x, str(pressed), str(sim.is_riding()), tramp_frame])
		if sim.game_over and i > 0:
			break
		if sim.on_ground and sim.time_since_land > 0.6 and (jumped_at >= 0.0 or bounced_at >= 0.0) and scene != "pole":
			break
		if scene == "pole" and sim.on_ground and is_same(sim.get("_ground_roof"), sim.roofs[2]) and sim.time_since_land > 0.5:
			break
	log.close()
	quit()


## 장면에 쓸 옥상: 앞 옥상(넓게) + 특수 틈 + 끝없이 긴 다음 옥상 (속도 SPEED 고정)
func _course(scene: String) -> RunnerSim:
	var sim := RunnerSim.new(7, SPEED)
	sim.accelerate = false
	sim.items.clear()
	sim.structures.clear()
	sim.roofs.clear()
	var prev := {"left": -3000.0, "right": 0.0, "top": 200.0}
	sim.roofs.append(prev)
	if scene == "jump":
		prev.right = 100000.0  # 틈 없이 달리다 뛰고 내려앉음
	elif scene == "double":
		sim.roofs.append({"left": 470.0, "right": 100000.0, "top": 220.0})
	else:
		var kind := "pole" if scene == "pole" else ("tramp" if scene.begins_with("tramp") else "line")
		for seed_value in range(1, 400):
			var gen := RoofGenerator.new(seed_value)
			var p := RoofGenerator.first_roof(0.0)
			p.top = 200.0
			var found := []
			for k in 60:
				var r := gen.next_roof(p, SPEED)
				if (kind == "line" and r.has("line")) or (kind == "tramp" and r.has("tramp")):
					found = [r]
				elif kind == "pole" and r.get("platform", false):
					found = [r, gen.next_roof(r, SPEED)]
				if not found.is_empty():
					# 앞 옥상 끝이 x = 0 이 되게 옮긴다
					var shift: float = -p.right
					prev.top = p.top
					for f in found:
						var c: Dictionary = f.duplicate(true)
						c.left += shift
						c.right += shift
						for key in ["line", "tramp"]:
							if c.has(key):
								c[key].left += shift
								c[key].right += shift
								sim.structures.append(c[key])
						sim.roofs.append(c)
					break
				p = r
			if not found.is_empty():
				break
		sim.roofs[-1].right = 100000.0
		if scene == "camera":
			sim.items.append_array(ItemPlacer.new(1).call("_line_fish", sim.structures[0]))
		if scene == "tramp_perfect":
			sim.items.append_array(ItemPlacer.tramp_fish(sim.structures[0]))
	sim.set("_ground_roof", prev)
	sim.x = -900.0
	sim.y = prev.top
	return sim
