extends Node2D
## 게임 화면: 입력을 모아 RunnerSim을 고정 간격으로 진행시키고, 옥상(임시 그림)·아이템을 그리고 고양이(CatView)를 움직인다.
## 충돌 판정은 로직(RunnerSim)이 Balance.CAT_BODY_SIZE·CAT_FOOT_HALF로 하고, 고양이 그림은 같은 크기로 그리기만 한다.
## 떨어지면 game_over를 알리고, 잠시(Balance.RESTART_DELAY) 뒤 새로 누르면 새 판을 시작한다.
## 세로 카메라(CameraFollow): 고양이가 높이 오르면 화면 전체를 아래로 내려 그린다(그림만, 판정과 무관). 하늘·구름·안개는 시차만큼만.
## 빨래줄 안내: 매 판 처음 GUIDE_LINES개 줄 틈에서 닿을 자리에 줄어드는 동그라미와 "눌러!" 말풍선, 줄 판정 결과 글자는 늘.

## 떨어져서 게임이 끝남 (meters = 이번 거리 점수)
signal game_over(meters: int)
## 새 판을 시작함
signal restarted

## 로직을 진행시키는 고정 간격 (화면 주사율과 상관없이 같은 손맛)
const STEP := 1.0 / 120.0
const MAX_STEPS_PER_FRAME := 12

const SKY_TOP := Color("#cfe6f2")
const SKY_BOTTOM := Color("#fbe9d4")
## 먼 배경 그림 (assets/sprites/backdrop/)
const TOWN_TEXTURE := preload("res://assets/sprites/backdrop/far_town.png")
const CLOUD_TEXTURES := [
	preload("res://assets/sprites/backdrop/cloud1.png"), preload("res://assets/sprites/backdrop/cloud2.png"),
	preload("res://assets/sprites/backdrop/cloud3.png"), preload("res://assets/sprites/backdrop/cloud4.png")]
const TOWN_BOTTOM := 0.66       # 먼 동네 띠 아래 끝 (화면 높이 비율). 아랫부분은 먼 안개에 묻힘
## 안개 띠 그림 (Backdrop.MISTS 이름별)과 띠 아래를 이어 채우는 색 (그림 맨 아랫줄 색)
const MIST_TEXTURES := {"far": preload("res://assets/sprites/backdrop/mist_far.png"),
		"town": preload("res://assets/sprites/backdrop/mist_town.png"),
		"mid": preload("res://assets/sprites/backdrop/mist_mid.png"), "near": preload("res://assets/sprites/backdrop/mist_near.png")}
const MIST_FILLS := {"far": Color("#fdd0a3"), "mid": Color("#fec4bd"), "near": Color("#cebbdf")}
## 건물 몸통이 안개에 묻히는 구간: 옥상 윗면에서 이만큼 아래부터 묻히기 시작해 BODY_MIST_TO에서 다 묻힘
const BODY_MIST_FROM := 70.0
const BODY_MIST_TO := 330.0
const BODY_MIST_MAX := 0.95
const SHADOW_COLOR := Color("#5a4636")
const SHADOW_WIDTH := 0.42   # 그림자 반지름 = 고양이 몸 너비 x 이 값
const SHADOW_FLAT := 0.18    # 세로/가로 비율 (납작한 타원)
const BELOW_DARKEN := 0.1  # 그림 아래 벽 색이 화면 바닥에서 이만큼 어두워짐
const WALL_LINE := 0.72  # 건물 옆 테두리: 채움 색을 이만큼 어둡게
## 아이템 그림 (assets/sprites/items/, 화면에 그릴 너비)
const FISH_TEXTURE := preload("res://assets/sprites/items/fish.png")
const BOX_TEXTURE := preload("res://assets/sprites/items/box.png")
## 구조물 그림 (assets/sprites/structures/, 화면에 그릴 크기)
const LINE_TEXTURE := preload("res://assets/sprites/structures/clothesline.png")
const POLE_TEXTURE := preload("res://assets/sprites/structures/pole.png")
## 빨래줄 그림(500x191)에서: 양쪽 기둥 조각(너비 40)과 가운데(줄과 빨래) 조각. 가운데는 틈 너비에 맞춰 몇 번 늘려 이어 붙인다
const LINE_POST_SRC := 40.0
const LINE_ROPE_Y := 38.0     # 그림 안에서 줄의 높이 (위에서부터 픽셀)
const LINE_TILE_STRETCH := 1.3  # 줄과 빨래 조각을 가로로 이만큼 넓게 펴서 이어 붙임
const LINE_POST_BOTTOM := 187.0  # 그림 안에서 기둥 아래 끝
## 전봇대 그림(267x767)에서: 위 조각(판~가로대, 0~209줄)과 기둥 몸통 조각(가로 105~161). 판 너비(187)에 맞춰 크기를 정하고 기둥은 아래로 늘린다
const POLE_PLATE_WIDTH := 187.0
const POLE_PLATE_TOP := 7.0
const POLE_HEAD_ROWS := 209.0
const POLE_TOP_ROWS := 92.0   # 위 조각(판+받침) 줄 수
const POLE_BAR_ROW := 125.0   # 아래 조각(애자+가로대) 시작 줄
const POLE_BAR_GAP := 8.0     # 받침 버팀대 끝과 가로대 사이 (그림 픽셀). 가로대를 위로 붙여 아래 안개에 묻히지 않게
const POLE_TRUNK_X := 105.0
const POLE_TRUNK_W := 56.0
const POLE_PLATE_ROWS := 42.0  # 위 조각 중 판 부분 (그 아래는 받침 버팀대)
const POLE_SLIM := 0.7         # 판 아래 그림(버팀대·가로대·기둥)만 이 배율로 가늘게. 판 너비(판정)는 그대로
const LINE_BOUNCE_ANIM := 0.16   # 밟았을 때 줄이 출렁이는 시간 (초)
const FISH_WIDTH := 56.0
const BOX_WIDTH := 60.0
const RESCUE_BOX_WIDTH := 120.0  # 구제할 때 고양이를 받치는 상자
const POP_TIME := 0.3            # 먹은 아이템이 떠오르며 사라지는 시간
## 빨래줄 "눌러!" 안내: 닿기 GUIDE_TIME초 전부터 줄어드는 동그라미가 닿는 순간 발 크기(GUIDE_PAW)에 딱 맞음
const GUIDE_LINES := 2
const GUIDE_TIME := 0.5
const GUIDE_PAW := 22.0
const GUIDE_START := 110.0
const HUD_BROWN := Color(0.353, 0.275, 0.212)
const HUD_CREAM := Color(1, 0.97, 0.9)
const HUD_FONT := preload("res://assets/fonts/gaegu/Gaegu-Bold.ttf")
## 줄 판정 결과 글자 (0.4초 떠올랐다 사라짐). miss(안 누름)는 글자 없이 줄이 처지는 것으로 보여 줌
const RESULT_TEXT := {"perfect": "퍼펙트!", "good": "좋아!", "early": "빨랐어!"}
const RESULT_TIME := 0.4
const LINE_SAG := 0.82  # 실린 줄·느슨해진 줄은 이만큼 아래로 처져 보임

var sim := RunnerSim.new(randi())
var cat := CatView.new()
var _touches := {}
var _accumulator := 0.0
var _over_time := 0.0        # 게임 끝 뒤 지난 시간
var _was_pressed := false
var _wait_release := false  # 다시 시작한 손가락을 뗄 때까지 점프로 치지 않음
## 누른 신호를 로직이 한 번 볼 때까지 남겨 둔다: 한 프레임 안에 누르고 뗀 짧은 탭(느린 휴대폰)도 놓치지 않게
var _tap_pending := false
var _pops: Array[Dictionary] = []  # 먹은 아이템 연출 {"kind", "x", "y", "t"}
var _was_rescuing := false
var _roof_looks := {}  # 옥상 왼쪽 x → {"plan": 건물 계획, "props": 소품} (같은 옥상은 항상 같은 모습)
var _front_mist := Node2D.new()  # 가장 가까운 안개: 고양이보다 앞에 그려 떨어지면 안개 속으로 사라짐
var _overlay := Node2D.new()     # 맨 앞: 빨래줄 안내·결과 글자
var _cam_lift := 0.0             # 세로 카메라: 화면을 아래로 내려 그리는 픽셀 (CameraFollow)
var _guided: Array[float] = []   # 이번 판에 안내를 보여 준 줄 (왼쪽 x)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # 아이템 그림을 크게 줄여 그려도 거칠지 않게
	cat.name = "Cat"
	add_child(cat)
	_front_mist.name = "FrontMist"
	_front_mist.draw.connect(func() -> void: _draw_mist(_front_mist, Backdrop.MISTS[-1], get_viewport_rect().size))
	add_child(_front_mist)
	_overlay.name = "Overlay"
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_place_cat(0.0)


func _process(delta: float) -> void:
	var pressed := is_pressed()
	var press_started := pressed and not _was_pressed
	_was_pressed = pressed
	if sim.game_over:
		_over_time += delta
		_tap_pending = false
		if press_started and _over_time >= Balance.RESTART_DELAY:
			restart()
		return
	_wait_release = _wait_release and pressed
	_accumulator = minf(_accumulator + delta, STEP * MAX_STEPS_PER_FRAME)
	while _accumulator >= STEP:
		sim.step(STEP, pressed and not _wait_release)
		for item in sim.picked:
			_pops.append({"kind": item.kind, "x": item.x, "y": item.y, "t": 0.0})
		if _was_rescuing and not sim.rescuing:
			# 구제 끝: 받쳐 준 상자가 고양이 발밑에서 사라진다
			_pops.append({"kind": "box", "x": sim.x, "y": sim.y, "t": 0.0})
		_was_rescuing = sim.rescuing
		_tap_pending = false
		pressed = is_pressed()
		_accumulator -= STEP
		if sim.game_over:
			_over_time = 0.0
			game_over.emit(sim.distance())
			break
	for pop in _pops:
		pop.t += delta
	_pops = _pops.filter(func(pop: Dictionary) -> bool: return pop.t < POP_TIME)
	# 이번 판 처음 GUIDE_LINES개 줄 틈에만 안내 (닿을 것으로 보이는 순간 그 줄을 셈)
	var touch := sim.line_touch_eta(GUIDE_TIME)
	if not touch.is_empty() and not _guided.has(touch.line.left) and _guided.size() < GUIDE_LINES:
		_guided.append(touch.line.left)
	_cam_lift = CameraFollow.follow(_cam_lift, CameraFollow.target(sim.y, sim.landing_top(), get_viewport_rect().size.y), delta)
	_place_cat(delta)
	queue_redraw()
	_front_mist.queue_redraw()
	_overlay.queue_redraw()


## 고양이를 로직 위치(발끝)에 놓고 자세를 맞춘다
func _place_cat(delta: float) -> void:
	cat.position = Vector2(Balance.CAT_SCREEN_X, _ground_y() - sim.y)
	cat.show_state(sim, delta)


## 새 판: 새 옥상(새 시드)에서 처음 속도로 다시 달린다
func restart() -> void:
	sim = RunnerSim.new(randi())
	_accumulator = 0.0
	_pops.clear()
	_was_rescuing = false
	_wait_release = true
	_cam_lift = 0.0
	_guided.clear()
	_place_cat(0.0)
	restarted.emit()
	queue_redraw()


func _input(event: InputEvent) -> void:
	# 휴대폰 터치와 PC 마우스 클릭(터치로 흉내 냄)을 손가락별로 기억한다
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
			_tap_pending = true
		else:
			_touches.erase(event.index)
	elif event is InputEventKey and event.physical_keycode == KEY_SPACE and event.pressed and not event.echo:
		_tap_pending = true


func _notification(what: int) -> void:
	# 다른 앱·탭으로 넘어가면 뗀 신호를 못 받을 수 있으니 누름 상태를 지운다
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_touches.clear()


## 지금 누르고 있는지 (화면 어디든 터치, 마우스 클릭, 스페이스바)
func is_pressed() -> bool:
	return _tap_pending or not _touches.is_empty() or Input.is_physical_key_pressed(KEY_SPACE)


## 로직 높이 0이 그려지는 화면 y (화면 맨 아래 + 세로 카메라)
func _ground_y() -> float:
	return get_viewport_rect().size.y + _cam_lift


func _draw() -> void:
	var size := get_viewport_rect().size
	var ground := _ground_y()  # 로직 높이 0 = 화면 맨 아래 (+ 세로 카메라)
	var offset := Balance.CAT_SCREEN_X - sim.x  # 로직 x → 화면 x

	# 하늘 (위아래 두 색)
	draw_polygon([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)],
			[SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM])

	_draw_backdrop(size)

	for roof in sim.roofs:
		if roof.get("platform", false):
			_draw_pole(roof, offset, ground)  # 전봇대 판은 건물이 아니라 기둥 그림으로
			continue
		var left: float = roof.left + offset
		var right: float = roof.right + offset
		if right < 0.0 or left > size.x:
			continue
		_draw_building(roof, offset, ground)

	for line in sim.structures:
		_draw_line(line, offset, ground)

	var shadow := CatShadow.under(sim.roofs, sim.x, sim.y)
	if not shadow.is_empty() and not sim.rescuing:
		_draw_shadow(Vector2(Balance.CAT_SCREEN_X, ground - shadow.top), shadow)

	for item in sim.items:
		# 살짝 위아래로 떠 있어 눈에 띄게 (자리마다 박자를 다르게)
		var bob := 4.0 * sin(sim.elapsed * 4.0 + item.x * 0.01)
		_draw_item(item.kind, Vector2(item.x + offset, ground - item.y + bob), 1.0, 1.0)
	for pop in _pops:
		var k: float = pop.t / POP_TIME
		_draw_item(pop.kind, Vector2(pop.x + offset, ground - pop.y - 40.0 * k), 1.0 + 0.5 * k, 1.0 - k)
	if sim.rescuing:
		# 고양이 발밑에서 상자가 받쳐 올린다 (고양이는 자식 노드라 상자 위에 그려짐)
		var h := RESCUE_BOX_WIDTH * BOX_TEXTURE.get_height() / BOX_TEXTURE.get_width()
		draw_texture_rect(BOX_TEXTURE, Rect2(Balance.CAT_SCREEN_X - RESCUE_BOX_WIDTH * 0.5, ground - sim.y - h * 0.35,
				RESCUE_BOX_WIDTH, h), false)


## 먼 배경: 구름(가장 멀리) → 멀리 보이는 동네 띠 → 안개 겹들(건물 뒤). 모두 옥상보다 느리게 지나간다.
func _draw_backdrop(size: Vector2) -> void:
	for cloud in Backdrop.CLOUDS:
		var tex: Texture2D = CLOUD_TEXTURES[cloud[0]]
		var x := Backdrop.cloud_x(cloud[1], sim.x, sim.elapsed, tex.get_width())
		draw_texture(tex, Vector2(x, size.y * cloud[2] + _cam_lift * Backdrop.CLOUD_PARALLAX))
	var top := size.y * TOWN_BOTTOM - TOWN_TEXTURE.get_height() + _cam_lift * Backdrop.TOWN_PARALLAX
	_draw_strip(self, TOWN_TEXTURE, top, Backdrop.TOWN_PARALLAX, size.x, Color.WHITE)
	for mist in Backdrop.MISTS.slice(0, -1):
		_draw_mist(self, mist, size)


## 띠 그림을 가로로 이어 붙여 그린다 (이웃 조각은 번갈아 뒤집음)
func _draw_strip(canvas: CanvasItem, tex: Texture2D, top: float, parallax: float, view_w: float, tint: Color) -> void:
	var tile_w := float(tex.get_width())
	for tile in Backdrop.town_tiles(sim.x, tile_w, view_w, parallax):
		# 뒤집은 조각은 가로 배율 -1로 그린다 (v0.4.0의 음수 너비 사각형은 화면에 안 그려져 띠가 중간에 끊겼음)
		var flip := tile.flip as bool
		canvas.draw_set_transform(Vector2(roundf(tile.x) + (tile_w if flip else 0.0), top), 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
		canvas.draw_texture(tex, Vector2.ZERO, tint)
	canvas.draw_set_transform(Vector2.ZERO)


## 안개 한 겹: 띠 그림 + 띠 아래는 같은 색으로 화면 바닥까지 채움 (틈 아래가 안개 속 낭떠러지로 보이게)
func _draw_mist(canvas: CanvasItem, mist: Array, size: Vector2) -> void:
	var tex: Texture2D = MIST_TEXTURES[mist[0]]
	var top: float = size.y * mist[2] + _cam_lift * minf(1.0, mist[1])  # 세로 카메라도 시차만큼 (가까운 안개는 건물과 같이)
	var tint := Color(1, 1, 1, mist[3])
	_draw_strip(canvas, tex, top, mist[1], size.x, tint)
	var bottom := top + tex.get_height() - 1.0
	if MIST_FILLS.has(mist[0]) and bottom < size.y:
		canvas.draw_rect(Rect2(0.0, bottom, size.x, size.y - bottom), Color(MIST_FILLS[mist[0]], mist[3]))


## 건물·기둥 몸통을 아래로 갈수록 안개 색으로 덮는다 (옥상 윗면 기준이라 고양이가 서는 곳은 늘 또렷함)
func _draw_body_mist(left: float, right: float, top: float, ground: float) -> void:
	var from := top + BODY_MIST_FROM
	if from >= ground:
		return
	var to := minf(top + BODY_MIST_TO, ground)
	var mist: Color = MIST_FILLS.mid
	var end := Color(mist, BODY_MIST_MAX * (to - from) / (BODY_MIST_TO - BODY_MIST_FROM))
	draw_polygon([Vector2(left, from), Vector2(right, from), Vector2(right, to), Vector2(left, to)],
			[Color(mist, 0.0), Color(mist, 0.0), end, end])
	if to < ground:
		draw_rect(Rect2(left, to, right - left, ground - to), end)


## 고양이 그림자: 가운데가 진한 납작한 타원 (원 3개를 겹쳐 가장자리를 부드럽게)
func _draw_shadow(pos: Vector2, shadow: Dictionary) -> void:
	var r: float = Balance.CAT_BODY_SIZE.x * SHADOW_WIDTH * shadow.scale
	draw_set_transform(pos, 0.0, Vector2(1.0, SHADOW_FLAT))
	for k in [1.0, 0.8, 0.6]:
		draw_circle(Vector2.ZERO, r * k, Color(SHADOW_COLOR, shadow.alpha / 3.0))
	draw_set_transform(Vector2.ZERO)


## 옥상의 건물: 왼쪽 캡 + 가운데 조각들(옥상 폭에 맞춰 늘임) + 오른쪽 캡, 그림 아래는 벽 색으로 화면 바닥까지 채움, 그 위에 소품.
## 그림의 맨 윗줄 = 옥상 충돌선(화면 y = ground - roof.top)이라 고양이 발이 지붕 턱 윗면에 닿는다.
func _draw_building(roof: Dictionary, offset: float, ground: float) -> void:
	var look := _look_of(roof)
	var style: Dictionary = BuildingArt.style_textures(look.plan.style)
	var fill: Color = BuildingArt.FILL_COLORS[look.plan.style]
	var left: float = roof.left + offset
	var right: float = roof.right + offset
	var top: float = ground - roof.top
	var art_h: float = style.left.get_height()
	# 그림이 끝난 아래부터 화면 바닥까지: 벽 색 + 옆 테두리, 그림 아랫부분은 부드럽게 이어짐
	var below := top + art_h
	if below < ground:
		var deep := fill.darkened(BELOW_DARKEN)  # 아래로 갈수록 살짝 어두워져 땅 쪽이 묵직해 보임
		draw_polygon([Vector2(left, below), Vector2(right, below), Vector2(right, ground), Vector2(left, ground)], [fill, fill, deep, deep])
	var fade := Color(fill, 0.0)
	draw_polygon([Vector2(left, below - BuildingArt.FADE), Vector2(right, below - BuildingArt.FADE), Vector2(right, below), Vector2(left, below)],
			[fade, fade, fill, fill])
	var line := fill * WALL_LINE
	line.a = 1.0
	draw_line(Vector2(left, below), Vector2(left, ground), line, 2.0)
	draw_line(Vector2(right, below), Vector2(right, ground), line, 2.0)
	# 건물 그림 (캡 → 가운데 → 캡). 조각 경계를 정수 픽셀에 맞춰 이음매에 선이 비치지 않게 함
	var x := left - BuildingLayout.OVERHANG
	draw_texture(style.left, Vector2(roundf(x), top))
	x += style.left.get_width()
	for index in look.plan.mids:
		var tex: Texture2D = style.mids[index]
		var next_x: float = x + tex.get_width() * look.plan.stretch
		draw_texture_rect(tex, Rect2(roundf(x), top, roundf(next_x) - roundf(x), art_h), false)
		x = next_x
	draw_texture(style.right, Vector2(roundf(x), top))
	for prop in look.props:
		var tex := BuildingArt.prop_texture(prop.kind)
		draw_texture(tex, Vector2(prop.x + offset - tex.get_width() * 0.5, top + BuildingArt.PROP_SINK - tex.get_height()))
	_draw_body_mist(left, right, top, ground)  # 벽 너비만 (지붕 턱은 BODY_MIST_FROM보다 위라 상관없음)


func _look_of(roof: Dictionary) -> Dictionary:
	if not _roof_looks.has(roof.left):
		if _roof_looks.size() > 80:
			_roof_looks.clear()
		_roof_looks[roof.left] = {"plan": BuildingLayout.plan(roof.left, roof.right, BuildingArt.widths()),
				"props": BuildingLayout.props(roof.left, roof.right)}
	return _roof_looks[roof.left]


## 전봇대: 판 옥상(platform) 위에 판이 오게 그리고 기둥은 화면 아래까지 늘린다 (기둥은 그림일 뿐 판정 없음)
## 판+받침(위 조각)과 가로대+애자(아래 조각)를 떼어, 가로대를 기둥 중간쯤에 둬서 판 아래로 기둥 몸통이 길게 보이게 한다
func _draw_pole(plate: Dictionary, offset: float, ground: float) -> void:
	var cx: float = (plate.left + plate.right) * 0.5 + offset
	if cx < -300.0 or cx > get_viewport_rect().size.x + 300.0:
		return
	var k: float = (plate.right - plate.left) / POLE_PLATE_WIDTH
	var top_y: float = ground - plate.top - POLE_PLATE_TOP * k
	var w := POLE_TEXTURE.get_width() * k
	var slim := w * POLE_SLIM
	# 기둥 몸통: 판 아래부터 화면 바닥까지 (먼저 그려 위 조각이 덮음)
	var trunk_w := POLE_TRUNK_W * k * POLE_SLIM
	draw_texture_rect_region(POLE_TEXTURE, Rect2(cx - trunk_w * 0.5, top_y + 14.0 * k, trunk_w, ground - top_y + 4.0),
			Rect2(POLE_TRUNK_X, POLE_HEAD_ROWS, POLE_TRUNK_W, 200.0))
	# 가로대: 받침 버팀대 바로 아래
	var bar_h := (POLE_HEAD_ROWS - POLE_BAR_ROW) * k * POLE_SLIM
	var bar_y := top_y + (POLE_TOP_ROWS + POLE_BAR_GAP) * k
	draw_texture_rect_region(POLE_TEXTURE, Rect2(cx - slim * 0.5, bar_y, slim, bar_h),
			Rect2(0, POLE_BAR_ROW, POLE_TEXTURE.get_width(), POLE_HEAD_ROWS - POLE_BAR_ROW))
	# 받침 버팀대(가늘게) → 판(원래 너비)
	draw_texture_rect_region(POLE_TEXTURE, Rect2(cx - slim * 0.5, top_y + POLE_PLATE_ROWS * k, slim, (POLE_TOP_ROWS - POLE_PLATE_ROWS) * k),
			Rect2(0, POLE_PLATE_ROWS, POLE_TEXTURE.get_width(), POLE_TOP_ROWS - POLE_PLATE_ROWS))
	draw_texture_rect_region(POLE_TEXTURE, Rect2(cx - w * 0.5, top_y, w, POLE_PLATE_ROWS * k),
			Rect2(0, 0, POLE_TEXTURE.get_width(), POLE_PLATE_ROWS))
	# 기둥은 가로대 아래부터 안개에 묻힘 (가로대가 보이게)
	_draw_body_mist(cx - trunk_w * 0.5, cx + trunk_w * 0.5, bar_y + bar_h - BODY_MIST_FROM, ground)


## 빨래줄: 틈 양쪽 옥상 끝에 기둥, 그 사이에 줄과 빨래를 틈 너비만큼 이어 붙인다 (줄이 발판 높이에 오게)
func _draw_line(line: Dictionary, offset: float, ground: float) -> void:
	var left: float = line.left + offset
	var right: float = line.right + offset
	if right < -100.0 or left > get_viewport_rect().size.x + 100.0:
		return
	var k := (Balance.LINE_HEIGHT + 6.0) / (LINE_POST_BOTTOM - LINE_ROPE_Y)  # 기둥이 옥상에 6픽셀 묻히게
	var h := LINE_TEXTURE.get_height() * k
	var top_y: float = ground - line.top - LINE_ROPE_Y * k
	# 밟은 직후에는 줄이 아래로 눌렸다 돌아온다 (기둥은 그대로, 줄과 빨래만 세로로 줄였다 늘림)
	var squash := 1.0
	if line == sim.bounced_line and sim.time_since_bounce < LINE_BOUNCE_ANIM:
		squash = 1.0 - 0.18 * sin(PI * sim.time_since_bounce / LINE_BOUNCE_ANIM)
	if sim.is_slack(line) or (sim.is_riding() and is_same(sim.line_touch_eta(0.0).line, line)):
		squash = minf(squash, LINE_SAG)  # 실린 동안·느슨해진 뒤에는 처져 있음 (그림만)
	var mid_src_w: float = LINE_TEXTURE.get_width() - 2.0 * LINE_POST_SRC
	var length: float = right - left
	var count := maxi(1, roundi(length / (mid_src_w * k * LINE_TILE_STRETCH)))  # 빨래가 너무 촘촘해지지 않게 조금 넓게 편다
	var tile_w := length / count
	for i in count:
		draw_texture_rect_region(LINE_TEXTURE, Rect2(left + i * tile_w, top_y + h * (1.0 - squash), tile_w, h * squash),
				Rect2(LINE_POST_SRC, 0, mid_src_w, LINE_TEXTURE.get_height()))
	var post_w := LINE_POST_SRC * k
	draw_texture_rect_region(LINE_TEXTURE, Rect2(left - post_w * 0.5, top_y, post_w, h), Rect2(0, 0, LINE_POST_SRC, LINE_TEXTURE.get_height()))
	draw_texture_rect_region(LINE_TEXTURE, Rect2(right - post_w * 0.5, top_y, post_w, h),
			Rect2(LINE_TEXTURE.get_width() - LINE_POST_SRC, 0, LINE_POST_SRC, LINE_TEXTURE.get_height()))


## 아이템 그림을 가운데 pos에 그린다 (zoom 배율, alpha 투명도)
func _draw_item(kind: String, pos: Vector2, zoom: float, alpha: float) -> void:
	if pos.x < -100.0 or pos.x > get_viewport_rect().size.x + 100.0:
		return
	var texture: Texture2D = FISH_TEXTURE if kind == "fish" else BOX_TEXTURE
	var w := (FISH_WIDTH if kind == "fish" else BOX_WIDTH) * zoom
	var h := w * texture.get_height() / texture.get_width()
	draw_texture_rect(texture, Rect2(pos - Vector2(w, h) * 0.5, Vector2(w, h)), false, Color(1, 1, 1, alpha))


## 맨 앞 안내: 처음 GUIDE_LINES개 줄 틈의 줄어드는 동그라미와 "눌러!" 말풍선, 줄 판정 결과 글자
func _draw_overlay() -> void:
	var ground := _ground_y()
	var offset := Balance.CAT_SCREEN_X - sim.x
	var touch := sim.line_touch_eta(GUIDE_TIME)
	if not touch.is_empty() and not sim.game_over:
		# 첫 점프를 누르고 있는 동안은 그리지 않는다 (누름이 끝난 뒤부터)
		if _guided.has(touch.line.left) and not sim.is_holding():
			var at := Vector2(touch.x + offset, ground - touch.line.top)
			var r := lerpf(GUIDE_PAW, GUIDE_START, touch.t / GUIDE_TIME)
			_overlay.draw_arc(at, GUIDE_PAW, 0.0, TAU, 32, Color(HUD_BROWN, 0.45), 3.0)
			_overlay.draw_arc(at, r, 0.0, TAU, 48, HUD_CREAM, 9.0)
			_overlay.draw_arc(at, r, 0.0, TAU, 48, HUD_BROWN, 5.0)
			_draw_bubble(Vector2(Balance.CAT_SCREEN_X, ground - sim.y - Balance.CAT_BODY_SIZE.y - 46.0), "눌러!")
	if RESULT_TEXT.has(sim.bounce_result) and sim.time_since_bounce < RESULT_TIME:
		var k := sim.time_since_bounce / RESULT_TIME
		var line_top: float = sim.bounced_line.top
		var at := Vector2(Balance.CAT_SCREEN_X - sim.speed * sim.time_since_bounce, ground - line_top - 150.0 - 50.0 * k)
		_draw_text(at, RESULT_TEXT[sim.bounce_result], 44, 1.0 - k * k)


## 말풍선 (HUD와 같은 갈색 글자·밝은 테두리, 크림색 바탕)
func _draw_bubble(center: Vector2, text: String) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = HUD_CREAM
	box.border_color = HUD_BROWN
	box.set_border_width_all(3)
	box.set_corner_radius_all(16)
	var w := 118.0
	var h := 50.0
	_overlay.draw_style_box(box, Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h)))
	_draw_text(center + Vector2(0.0, 2.0), text, 34, 1.0)


## 가운데 정렬 글자 (center = 글자 가운데)
func _draw_text(center: Vector2, text: String, size: int, alpha: float) -> void:
	var width := HUD_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := center + Vector2(-width * 0.5, size * 0.35)
	_overlay.draw_string_outline(HUD_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(HUD_CREAM, alpha))
	_overlay.draw_string(HUD_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(HUD_BROWN, alpha))
