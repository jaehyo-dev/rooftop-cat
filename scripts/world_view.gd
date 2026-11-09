extends Node2D
## 게임 화면: 입력을 모아 RunnerSim을 고정 간격으로 진행시키고, 옥상(임시 그림)·아이템을 그리고 고양이(CatView)를 움직인다.
## 충돌 판정은 로직(RunnerSim)이 Balance.CAT_BODY_SIZE·CAT_FOOT_HALF로 하고, 고양이 그림은 같은 크기로 그리기만 한다.
## 떨어지면 game_over를 알리고, 잠시(Balance.RESTART_DELAY) 뒤 새로 누르면 새 판을 시작한다.
## 세로 카메라(CameraFollow): 고양이가 높이 오르면 화면 전체를 아래로 내려 그린다(그림만, 판정과 무관). 하늘·구름·안개는 시차만큼만.
## 트램펄린(빨래줄) 안내: 매 판 처음 GUIDE_LINES개 트램펄린에서 닿을 자리에 줄어드는 동그라미와 "눌러!" 말풍선, 판정 결과 글자는 늘.
## 발 붙이기(v0.5.0 2a-2): 판정선은 지붕 턱 윗면 맨 뒤 선이지만, 고양이·그림자·아이템은 FOOT_SINK만큼 내려 윗면 가운데에 서 보이게 그린다.

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
const MIST_TEXTURES := {"far": preload("res://assets/sprites/backdrop/mist_far_m2.png"),
		"town": preload("res://assets/sprites/backdrop/mist_town.png"),
		"mid": preload("res://assets/sprites/backdrop/mist_mid_m2.png"), "near": preload("res://assets/sprites/backdrop/mist_near_m2.png")}
## 사용자가 직접 플레이해 고른 안개 M2 (v0.5.0): 세 겹 모두 크림색(#fff6ec) 쪽으로 75% 섞음 (그림은 tools/tint_mist.py).
## far도 옅게 한 이유: 살구색 그대로면 mid·near가 옅어진 뒤 틈 뒤의 모래 땅처럼 보임
const MIST_FILLS := {"far": Color("#feebd9"), "mid": Color("#ffebe1"), "near": Color("#f5e9e9")}
## 건물 몸통이 안개에 묻히는 구간: 옥상 윗면에서 이만큼 아래부터 묻히기 시작해 BODY_MIST_TO에서 다 묻힘
const BODY_MIST_FROM := 70.0
const BODY_MIST_TO := 330.0
const BODY_MIST_MAX := 0.95
const SHADOW_COLOR := Color("#5a4636")
const SHADOW_PEAK := 1.6     # 그라데이션이 바깥으로 옅어지는 만큼 가운데 진하기를 올림
const BELOW_DARKEN := 0.1  # 그림 아래 벽 색이 화면 바닥에서 이만큼 어두워짐
const WALL_LINE := 0.72  # 건물 옆 테두리: 채움 색을 이만큼 어둡게
## 아이템 그림 (assets/sprites/items/). 화면에 그릴 너비는 ITEM_WIDTHS
const BOX_TEXTURE := preload("res://assets/sprites/items/box.png")
const ITEM_TEXTURES := {"fish": preload("res://assets/sprites/items/fish.png"), "box": BOX_TEXTURE, "gold": preload("res://assets/sprites/items/gold.png"),
		"dash": preload("res://assets/sprites/items/snack.png"), "yarn": preload("res://assets/sprites/items/yarn.png"), "cookie": preload("res://assets/sprites/items/cookie.png"),
		"can": preload("res://assets/sprites/items/can.png"), "bell": preload("res://assets/sprites/items/bell.png")}
const ITEM_WIDTHS := {"fish": 56.0, "box": 60.0, "gold": 96.0, "dash": 62.0, "yarn": 76.0, "cookie": 72.0, "can": 76.0, "bell": 70.0}
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
const POLE_HEAD_ROWS := 209.0
const POLE_TOP_ROWS := 92.0   # 위 조각(판+받침) 줄 수
const POLE_BAR_ROW := 125.0   # 아래 조각(애자+가로대) 시작 줄
const POLE_BAR_GAP := 8.0     # 받침 버팀대 끝과 가로대 사이 (그림 픽셀). 가로대를 위로 붙여 아래 안개에 묻히지 않게
const POLE_TRUNK_X := 105.0
const POLE_TRUNK_W := 56.0
const POLE_PLATE_ROWS := 42.0  # 위 조각 중 판 부분 (그 아래는 받침 버팀대)
const POLE_SLIM := 0.7         # 판 아래 그림(버팀대·가로대·기둥)만 이 배율로 가늘게. 판 너비(판정)는 그대로
const LINE_BOUNCE_ANIM := 0.16   # 밟았을 때 줄이 출렁이는 시간 (초)
## 고양이·그림자·아이템을 판정선보다 이만큼 아래에 그린다: 건물 3종 모두 지붕 턱 윗면이 그림 4줄(뒤 선)~29줄(앞 선)이라 그 가운데(16).
## 전봇대 판·트램펄린도 서는 자리가 이 높이에 오게 그린다
const FOOT_SINK := 16.0
const POLE_FACE_MID := 10.5   # 전봇대 그림에서 판 윗면 가운데 줄 (판 윗면 7~14줄)
## 트램펄린 그림(216x100, 평소·밟음·튕김이 같은 캔버스): 테 왼쪽 끝 3, 테 너비 209, 다리 끝 97줄.
## 테 아래(TRAMP_SRC_LEG줄부터)는 세로로 TRAMP_LEG_STRETCH배 늘여 그린다: 다리가 길어져 꺼진 그물이 고양이 몸 아래로 보임
const TRAMP_TEXTURES := {"rest": preload("res://assets/sprites/structures/trampoline_rest.png"),
		"pressed": preload("res://assets/sprites/structures/trampoline_pressed.png"),
		"launch": preload("res://assets/sprites/structures/trampoline_launch.png")}
const TRAMP_SRC_LEFT := 3.0
const TRAMP_SRC_WIDTH := 209.0
const TRAMP_SRC_FEET := 97.0
const TRAMP_SRC_LEG := 60.0
const TRAMP_LEG_STRETCH := 1.7
## 그림에서 그물 가운데 줄: 평소 그물 윗면, 밟음 그림의 꺼진 바닥(82줄 아래 끝)
const TRAMP_SRC_NET := {"rest": 33.0, "pressed": 82.0}
## 달려 들어갈 때 그림만 그물 위로 폴짝: 몸 가운데가 트램펄린 왼쪽 끝 이만큼 앞에서 시작해 닿는 자리에서 평소 그물 높이에 도착
const TRAMP_HOP_FROM := 100.0
const TRAMP_HOP_ARC := 14.0
const TRAMP_RELEASE := 0.07     # 그물을 떠난 그림이 실제 높이를 따라잡는 시간 (초)
const CAT_LIFT_RATE := 60.0     # 고양이 그림 높이 보정이 목표로 다가가는 빠르기
## 트램펄린 모양 변화 (튕긴 뒤 지난 시간): 밟음 그림 Balance.TRAMP_PUSH초(고양이 그림이 눌려 있는 동안) → 튕김 그림 TRAMP_POP초 → 평소 그림이 출렁이며 TRAMP_SETTLE초
const TRAMP_POP := 0.12
const TRAMP_SETTLE := 0.5
## 세로 배율 (다리 끝 기준): 밟음 = 눌림(1보다 작음), 튕김·출렁임 = 늘어남 폭. [안 누름·이른 누름, 누름, 퍼펙트]
const TRAMP_PRESS_SY := {"miss": 0.95, "early": 0.95, "good": 0.92, "perfect": 0.84}
const TRAMP_POP_SY := {"miss": 0.05, "early": 0.05, "good": 0.14, "perfect": 0.28}
## 장애물 그림 (assets/sprites/obstacles/, 화면 너비는 Balance.OBSTACLES의 art_w)
const OBSTACLE_TEXTURES := {"pot": preload("res://assets/sprites/obstacles/pot.png"), "ac": preload("res://assets/sprites/obstacles/ac.png"),
		"tank": preload("res://assets/sprites/obstacles/tank.png"), "flock": preload("res://assets/sprites/obstacles/flock.png")}
const OBSTACLE_SHADOW_ALPHA := 0.6
const OBSTACLE_SHADOW_FLAT := 0.2
const FLOCK_SHADOW_ALPHA := 0.25  # 비둘기가 옥상에 드리우는 옅은 그림자
const PROP_CLEAR := 170.0         # 장애물 둘레 이 거리 안의 소품은 그리지 않는다 (겹치면 헷갈림)
## 장애물이 화면에 들어올 때부터 고양이가 지나갈 때까지 위에 떠 있는 "!" (살짝 위아래로 통통)
const ALERT_COLOR := Color("#e0402f")
const ALERT_POP := 0.12
const ALERT_RISE := 24.0
const ALERT_BOB := 7.0     # 위아래로 움직이는 폭 (픽셀)
const ALERT_BOB_HZ := 2.2  # 1초에 몇 번
## 매 판 처음 만나는 종류마다 고양이 위에 띄우는 안내
const OBSTACLE_HINTS := {"pot": "뛰어!", "ac": "길게!", "tank": "두 번!", "flock": "그대로!"}
const HINT_TIME := 1.1
## 비둘기가 화면에 들어오기 이만큼 전부터 소리와 오른쪽 끝 깃털 표시 (초)
const FLOCK_WARN_TIME := 1.0
## 부딪힌 장애물이 튕겨 나가 사라지는 시간과 움직임
const KNOCK_TIME := 0.45
const KNOCK_VX := 260.0
const KNOCK_VY := 420.0
const KNOCK_SPIN := 3.5
## 하트 HUD: 위 가운데 (게임 크기). 오른쪽부터 잃는다. 1개 남으면 두근거림
const HEART_TEXTURES := {"full": preload("res://assets/sprites/hud/heart_full.png"), "crack": preload("res://assets/sprites/hud/heart_crack.png"),
		"empty": preload("res://assets/sprites/hud/heart_empty.png")}
const HEART_SIZE := Vector2(54.0, 46.0)
const HEART_GAP := 8.0
const HEART_Y := 12.0
const HEART_CRACK_TIME := 0.35
const HEART_PULSE := 0.08
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
## 더블점프·트램펄린 발사 때 발밑에서 터지는 먼지 고리와 별
const BURST_TIME := 0.32
const BURST_RING := 70.0        # 먼지 고리가 퍼지는 반지름 (납작한 타원의 가로)
const BURST_FLAT := 0.3
const BURST_COLOR := Color(1.0, 0.96, 0.86)
const BURST_STAR_COLOR := Color("#ffd166")
const BURST_STAR_OUTLINE := Color("#a8693a")
const BURST_STARS := 6
const BURST_STAR_REACH := 90.0
## 효과음이 음악(-26 LUFS 안팎)보다 5dB쯤 위에 오게 (v0.5.0 2b 마무리, ffmpeg ebur128로 잼). 착지는 원래 작아서 올린다
const SFX_VOLUME_DB := -5.0
const SFX_TRIM_DB := {"land": 4.0, "fish": -8.0}
const FISH_POLYPHONY := 2  # 동시에 나는 생선 소리 수
const LINE_SAG := 0.82  # 실린 줄·느슨해진 줄은 이만큼 아래로 처져 보임
## 질주 그림: 화면이 멀어지는 배율과 시간, 빛남, 잔상 간격과 개수
const DASH_ZOOM := 0.92
const DASH_ZOOM_TIME := 0.3
const DASH_GLOW := Color("#ffd166")
const DASH_GLOW_RADIUS := 130.0
const TRAIL_GAP := 0.04
const TRAIL_COUNT := 3
## 부순·바뀐 장애물 조각 (동시 상한은 휴대폰 웹 성능, PLAN 7번)
const SHARD_MAX := 60
const SHARD_LIFE := 0.5
const SHARD_COLORS := {"pot": Color("#c9764f"), "ac": Color("#b9c3c6"), "tank": Color("#9db3c2"), "flock": Color("#d9d4cc")}
## 떠오르는 효과 글자 ("팡!", "펑!", "딸랑!")
const POP_TEXT_TIME := 0.5
## 방울 HUD: 하트 오른쪽. 막으면 두 쪽으로 깨진다. 진행 막대: 하트 아래 아이콘 + 남은 시간
const BELL_HUD_SIZE := 46.0
const BELL_BREAK_TIME := 0.45
const STATUS_Y := 64.0
const STATUS_ICON := 30.0
const STATUS_BAR := Vector2(90.0, 10.0)
## 속도 단계 신호: 위 가운데 "빨라진다!" 글자와 발바닥 도장 N개 (N = 단계)
const STAGE_SIGNAL_TIME := 0.8
const STAGE_TEXT_Y := 84.0
const STAGE_PAW_Y := 132.0
const STAGE_PAW_GAP := 40.0
## 속도선: 오른쪽에서 왼쪽으로 지나가는 뾰족한 선. 진하기(SpeedCurve.line_strength)가 개수와 불투명도를 함께 정한다
const SPEED_LINE_COUNT := 36
const SPEED_LINE_COLOR := Color(1, 0.98, 0.93)

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
var _bursts: Array[Dictionary] = []  # 발밑 터짐 {"x", "y", "t", "stars"}
var _sfx := {}                       # 효과음 이름 → AudioStreamPlayer
var _fish_sound_at := -INF           # 마지막 생선 소리 시각 (sim.elapsed)
var _fall_sounded := false           # 이번 떨어짐에 소리를 냈는지
var _roof_looks := {}  # 옥상 왼쪽 x → {"plan": 건물 계획, "props": 소품} (같은 옥상은 항상 같은 모습)
var _shadow_texture := _make_shadow_texture()
var _front_mist := Node2D.new()  # 가장 가까운 안개: 고양이보다 앞에 그려 떨어지면 안개 속으로 사라짐
var _overlay := Node2D.new()     # 맨 앞: 빨래줄 안내·결과 글자
var _cat_lift := 0.0             # 고양이 그림만 올려 그리는 픽셀 (트램펄린, tramp_cat_lift를 부드럽게 따라감)
var _cam_lift := 0.0             # 세로 카메라: 화면을 아래로 내려 그리는 픽셀 (CameraFollow)
var _guided: Array[float] = []   # 이번 판에 안내를 보여 준 줄 (왼쪽 x)
var _alerts := {}                # 장애물 번호 → 화면에 들어온 뒤 지난 시간
var _cooed := {}                 # 소리를 낸 비둘기 번호
var _hinted := {}                # 이번 판에 안내를 보여 준 장애물 종류
var _hint := {}                  # 지금 안내 {"text", "t"}
var _knocked: Array[Dictionary] = []  # 튕겨 나가는 장애물 {"kind", "x", "y", "t"} (x = 가운데, y = 아래 끝)
var _zoom := 1.0                 # 화면 배율 (질주 중 멀어짐). 왼쪽 아래 기준이라 건물을 오른쪽으로 더 그리면 된다
var _hitstop := 0.0              # 게임 진행을 멈추는 남은 시간
var _hitstop_gap := 0.0          # 다시 멈추지 않는 남은 시간
var _trail: Array[Dictionary] = []  # 잔상 {"x", "y", "frame"} (앞이 최신)
var _trail_wait := 0.0
var _shards: Array[Dictionary] = []  # 조각·별 {"x", "y", "vx", "vy", "t", "spin", "color", "star"} (로직 좌표)
var _pop_texts: Array[Dictionary] = []  # 효과 글자 {"text", "x", "y", "t"}
var _bell_break := 99.0          # 방울이 깨진 뒤 지난 시간


## 가운데가 진하고 가장자리로 사라지는 원 (흰색, 그릴 때 색을 입힘)
static func _make_shadow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _ready() -> void:
	for sound in SfxEvents.ALL:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx_" + sound
		player.stream = load("res://assets/audio/sfx/%s.wav" % sound)
		player.volume_db = SFX_VOLUME_DB + SFX_TRIM_DB.get(sound, 0.0)
		if sound == "fish":
			player.max_polyphony = FISH_POLYPHONY
		add_child(player)
		_sfx[sound] = player
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # 아이템 그림을 크게 줄여 그려도 거칠지 않게
	cat.name = "Cat"
	add_child(cat)
	_front_mist.name = "FrontMist"
	_front_mist.draw.connect(func() -> void: _draw_mist(_front_mist, Backdrop.MISTS[-1], _view_size()))
	add_child(_front_mist)
	_overlay.name = "Overlay"
	_overlay.draw.connect(_draw_overlay)
	_overlay.top_level = true  # HUD는 화면 배율을 받지 않는다 (세계에 붙은 표시만 _draw_overlay에서 배율을 건다)
	add_child(_overlay)
	_place_cat(0.0)


func _process(delta: float) -> void:
	var pressed := is_pressed()
	var press_started := pressed and not _was_pressed
	_was_pressed = pressed
	if sim.game_over:
		_over_time += delta
		_tap_pending = false
		if press_started and can_restart():
			restart()
		return
	_wait_release = _wait_release and pressed
	sim.view_ahead = _view_size().x - Balance.CAT_SCREEN_X
	_hitstop_gap = maxf(0.0, _hitstop_gap - delta)
	_hitstop = maxf(0.0, _hitstop - delta)
	# 멈춤 중에는 게임 진행 루프를 건너뛴다 (눌린 입력은 _tap_pending에 남아 멈춤 뒤에 처리됨)
	_accumulator = 0.0 if _hitstop > 0.0 else minf(_accumulator + delta, STEP * MAX_STEPS_PER_FRAME)
	while _accumulator >= STEP:
		sim.step(STEP, pressed and not _wait_release)
		_play_events()
		for item in sim.picked:
			_pops.append({"kind": item.kind, "x": item.x, "y": item.y, "t": 0.0})
		if _was_rescuing and not sim.rescuing:
			# 구제 끝: 받쳐 준 상자가 고양이 발밑에서 사라진다
			_pops.append({"kind": "box", "x": sim.x, "y": sim.y, "t": 0.0})
		_was_rescuing = sim.rescuing
		if not sim.hit_obstacle.is_empty():
			var o := sim.hit_obstacle
			_knocked.append({"kind": o.kind, "x": RunnerSim.obstacle_left(o, sim.x) + o.w * 0.5, "y": o.y0, "t": 0.0})
		_item_effects()
		_tap_pending = false
		pressed = is_pressed()
		_accumulator -= STEP
		if _hitstop > 0.0:
			_accumulator = 0.0
			break
		if sim.game_over:
			_over_time = 0.0
			game_over.emit(sim.distance())
			break
	for pop in _pops:
		pop.t += delta
	_pops = _pops.filter(func(pop: Dictionary) -> bool: return pop.t < POP_TIME)
	for burst in _bursts:
		burst.t += delta
	_bursts = _bursts.filter(func(burst: Dictionary) -> bool: return burst.t < BURST_TIME)
	_update_obstacle_signs(delta)
	_update_item_effects(delta)
	# 이번 판 처음 GUIDE_LINES개 줄 틈에만 안내 (닿을 것으로 보이는 순간 그 줄을 셈)
	var touch := sim.line_touch_eta(GUIDE_TIME)
	if not touch.is_empty() and not _guided.has(touch.line.left) and _guided.size() < GUIDE_LINES:
		_guided.append(touch.line.left)
	_cam_lift = CameraFollow.follow(_cam_lift, CameraFollow.target(sim.y, sim.landing_top(), get_viewport_rect().size.y), delta)
	_place_cat(delta)
	queue_redraw()
	_front_mist.queue_redraw()
	_overlay.queue_redraw()


## 게임이 끝나고 다시 시작할 수 있는 때인지
func can_restart() -> bool:
	return sim.game_over and _over_time >= Balance.RESTART_DELAY


## 화면에 들어오는 장애물의 "!"와 처음 만남 안내, 비둘기 소리, 튕겨 나간 장애물 시간
func _update_obstacle_signs(delta: float) -> void:
	var ahead := sim.view_ahead
	for id in _alerts:
		_alerts[id] += delta
	# 질주 중에는 피할 게 아니라 부술 것이라 알리지 않는다
	for o in [] if sim.dashing else sim.obstacles:
		if not _alerts.has(o.id) and RunnerSim.obstacle_left(o, sim.x) - sim.x <= ahead:
			_alerts[o.id] = 0.0
			if not _hinted.has(o.kind):
				_hinted[o.kind] = true
				_hint = {"text": OBSTACLE_HINTS[o.kind], "t": 0.0}
		if o.kind == "flock" and not _cooed.has(o.id) and RunnerSim.flock_eta(o, sim.x, sim.vx(), ahead) <= FLOCK_WARN_TIME:
			_cooed[o.id] = true
			_sfx.coo.play()
	if not _hint.is_empty():
		_hint.t += delta
		if _hint.t >= HINT_TIME:
			_hint = {}
	for knocked in _knocked:
		knocked.t += delta
	_knocked = _knocked.filter(func(k: Dictionary) -> bool: return k.t < KNOCK_TIME)


## 이번 step에 일어난 아이템 일의 연출: 부숨(회전하며 날아감, 조각, "팡!", 멈춤), 통조림("펑!"), 방울 깨짐
func _item_effects() -> void:
	if sim.dash_started:
		_hint = {}  # 피할 안내는 질주 중에 맞지 않는다
	for o in sim.smashed:
		_knocked.append({"kind": o.kind, "x": o.x + o.w * 0.5, "y": o.y0, "t": 0.0})
		_shatter(o, "팡!")
		if _hitstop_gap <= 0.0:
			_hitstop = Balance.HITSTOP_TIME
			_hitstop_gap = Balance.HITSTOP_GAP
	for o in sim.canned:
		_shatter(o, "펑!")
	if sim.bell_blocked:
		_bell_break = 0.0
		_pop_texts.append({"text": "딸랑!", "x": sim.x, "y": sim.y + Balance.CAT_BODY_SIZE.y + 40.0, "t": 0.0})


## 장애물 자리에서 조각 5~8개 + 별 + 글자 (번호로 정해 무작위 없이 항상 같은 모양)
func _shatter(o: Dictionary, text: String) -> void:
	var center := Vector2(o.x + o.w * 0.5, (o.y0 + minf(o.y1, o.y0 + 200.0)) * 0.5)
	var count: int = 5 + o.id % 4
	for i in count + 3:
		if _shards.size() >= SHARD_MAX:
			break
		var a: float = TAU * (i + 0.5) / (count + 3)
		var reach: float = 260.0 + 200.0 * fposmod(i * 0.618, 1.0)
		_shards.append({"x": center.x, "y": center.y, "vx": cos(a) * reach + sim.vx() * 0.5, "vy": sin(a) * reach + 240.0, "t": 0.0, "spin": 6.0 + i,
				"color": SHARD_COLORS[o.kind], "star": i >= count})
	_pop_texts.append({"text": text, "x": center.x, "y": center.y + 60.0, "t": 0.0})


## 연출 시간 진행: 조각·글자·잔상·화면 배율
func _update_item_effects(delta: float) -> void:
	for shard in _shards:
		shard.t += delta
		shard.x += shard.vx * delta
		shard.y += shard.vy * delta
		shard.vy -= Balance.GRAVITY * 0.5 * delta
	_shards = _shards.filter(func(s: Dictionary) -> bool: return s.t < SHARD_LIFE)
	for pop in _pop_texts:
		pop.t += delta
	_pop_texts = _pop_texts.filter(func(p: Dictionary) -> bool: return p.t < POP_TEXT_TIME)
	_bell_break += delta
	_trail_wait -= delta
	if not sim.dashing:
		_trail.clear()
	elif _trail_wait <= 0.0:
		_trail_wait = TRAIL_GAP
		_trail.push_front({"x": sim.x, "y": sim.y, "frame": cat.frame_name})
		_trail.resize(mini(_trail.size(), TRAIL_COUNT + 1))
	_zoom = move_toward(_zoom, DASH_ZOOM if sim.dashing else 1.0, (1.0 - DASH_ZOOM) / DASH_ZOOM_TIME * delta)
	_apply_zoom()


## 왼쪽 아래를 기준으로 세계 전체를 줄인다 (HUD는 _overlay.top_level이라 그대로)
func _apply_zoom() -> void:
	scale = Vector2.ONE * _zoom
	position.y = get_viewport_rect().size.y * (1.0 - _zoom)


## 세계 좌표에서 지금 보이는 크기 (화면이 멀어지면 오른쪽이 더 보임). 아래 끝은 그대로
func _view_size() -> Vector2:
	var size := get_viewport_rect().size
	return Vector2(size.x / _zoom, size.y)


## 이번 step에 일어난 일의 효과음과 발밑 터짐
func _play_events() -> void:
	var doomed := sim.is_doomed() and not sim.has_box  # 상자가 받아 줄 떨어짐은 끝이 아니다
	for sound in SfxEvents.sounds(sim, doomed and not _fall_sounded):
		if sound == "fish":
			if not SfxEvents.fish_due(sim.elapsed, _fish_sound_at):
				continue
			_fish_sound_at = sim.elapsed
		_sfx[sound].play()
	if doomed:
		_fall_sounded = true
	elif sim.on_ground or sim.bounced:
		_fall_sounded = false
	var bounced_good := sim.bounced and sim.bounce_result in ["good", "perfect"]
	if sim.double_jumped or bounced_good:
		_bursts.append({"x": sim.x, "y": sim.y + tramp_cat_lift(sim), "t": 0.0, "stars": sim.double_jumped or sim.bounce_result == "perfect"})


## 고양이를 로직 위치(발끝)에 놓고 자세를 맞춘다
func _place_cat(delta: float) -> void:
	var lift := tramp_cat_lift(sim)
	_cat_lift = lift if delta <= 0.0 else lerpf(_cat_lift, lift, 1.0 - exp(-CAT_LIFT_RATE * delta))
	cat.position = Vector2(Balance.CAT_SCREEN_X, _ground_y() - sim.y + FOOT_SINK - _cat_lift)
	cat.show_state(sim, delta)


## 새 판: 새 옥상(새 시드)에서 처음 속도로 다시 달린다
func restart() -> void:
	sim = RunnerSim.new(randi())
	_accumulator = 0.0
	_pops.clear()
	_bursts.clear()
	_fall_sounded = false
	_was_rescuing = false
	_wait_release = true
	_cam_lift = 0.0
	_guided.clear()
	_alerts.clear()
	_cooed.clear()
	_hinted.clear()
	_hint = {}
	_knocked.clear()
	_zoom = 1.0
	_apply_zoom()
	_hitstop = 0.0
	_hitstop_gap = 0.0
	_trail.clear()
	_shards.clear()
	_pop_texts.clear()
	_bell_break = 99.0
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
	var size := _view_size()
	var ground := _ground_y()  # 로직 높이 0 = 화면 맨 아래 (+ 세로 카메라)
	var offset := Balance.CAT_SCREEN_X - sim.x  # 로직 x → 화면 x

	# 하늘 (위아래 두 색). 화면이 멀어지면 y 0 위까지 보인다
	var sky_top := size.y * (1.0 - 1.0 / _zoom)
	draw_polygon([Vector2(0, sky_top), Vector2(size.x, sky_top), size, Vector2(0, size.y)],
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

	for structure in sim.structures:
		if structure.kind == "tramp":
			_draw_tramp(structure, offset, ground)
		else:
			_draw_line(structure, offset, ground)

	for o in sim.obstacles:
		_draw_obstacle(o, offset, ground)
	for knocked in _knocked:
		_draw_knocked(knocked, offset, ground)

	# 트램펄린을 밟고 있으면 그림자도 꺼진 그물 위에 (고양이 그림 높이 보정만큼 같이 올림)
	var riding := sim.is_riding()
	var floors: Array = sim.roofs + ([sim.line_touch_eta(0.0).line] if riding else [])
	var shadow := CatShadow.under(floors, sim.x, sim.y)
	if not shadow.is_empty() and not sim.rescuing:
		_draw_shadow(Vector2(Balance.CAT_SCREEN_X, ground - shadow.top + FOOT_SINK - (_cat_lift if riding else 0.0)), shadow)

	for burst in _bursts:
		_draw_burst(Vector2(burst.x + offset, ground - burst.y + FOOT_SINK), burst)
	if sim.dashing:
		_draw_dash_look(offset, ground)

	var view_right := _view_size().x + 100.0
	for item in sim.items:
		if item.x + offset > view_right or item.x + offset < -100.0:
			continue  # 생선 길이 촘촘해 화면 밖까지 그리면 휴대폰에서 낭비
		# 살짝 위아래로 떠 있어 눈에 띄게 (자리마다 박자를 다르게)
		var bob := 4.0 * sin(sim.elapsed * 4.0 + item.x * 0.01)
		_draw_item(item.kind, Vector2(item.x + offset, ground - item.y + FOOT_SINK + bob), 1.0, 1.0)
	for pop in _pops:
		var k: float = pop.t / POP_TIME
		_draw_item(pop.kind, Vector2(pop.x + offset, ground - pop.y + FOOT_SINK - 40.0 * k), 1.0 + 0.5 * k, 1.0 - k)
	for shard in _shards:
		_draw_shard(shard, offset, ground)
	if sim.rescuing:
		# 고양이 발밑에서 상자가 받쳐 올린다 (고양이는 자식 노드라 상자 위에 그려짐)
		var h := RESCUE_BOX_WIDTH * BOX_TEXTURE.get_height() / BOX_TEXTURE.get_width()
		draw_texture_rect(BOX_TEXTURE, Rect2(Balance.CAT_SCREEN_X - RESCUE_BOX_WIDTH * 0.5, ground - sim.y + FOOT_SINK - h * 0.35,
				RESCUE_BOX_WIDTH, h), false)


## 질주 모습: 몸 뒤 빛, 잔상 (고양이는 자식 노드라 그 위에 그려짐), 발밑 빛 줄
func _draw_dash_look(offset: float, ground: float) -> void:
	for i in range(_trail.size() - 1, 0, -1):
		var ghost: Dictionary = _trail[i]
		var tex: Texture2D = cat.frame_texture(ghost.frame)
		draw_set_transform(Vector2(ghost.x + offset, ground - ghost.y + FOOT_SINK), 0.0, cat.scale)
		draw_texture(tex, -CatView.ANCHOR, Color(1.0, 0.86, 0.5, 0.45 - 0.11 * i))
	draw_set_transform(Vector2.ZERO)
	var center := cat.position + Vector2(0.0, -Balance.CAT_BODY_SIZE.y * 0.5)
	var r := DASH_GLOW_RADIUS * (1.0 + 0.08 * sin(sim.elapsed * 18.0))
	draw_texture_rect(_shadow_texture, Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(DASH_GLOW, 0.75))
	draw_line(Vector2(Balance.CAT_SCREEN_X - 110.0, cat.position.y + 3.0), Vector2(Balance.CAT_SCREEN_X + 110.0, cat.position.y + 3.0), Color(DASH_GLOW, 0.8), 6.0, true)


## 조각 하나 (별은 _draw_star, 나머지는 작은 사각 조각)
func _draw_shard(shard: Dictionary, offset: float, ground: float) -> void:
	var k: float = shard.t / SHARD_LIFE
	var at := Vector2(shard.x + offset, ground - shard.y + FOOT_SINK)
	if shard.star:
		_draw_star(at, 13.0 * (1.0 - 0.4 * k), shard.spin * shard.t, 1.0 - k * k)
		return
	draw_set_transform(at, shard.spin * shard.t)
	draw_rect(Rect2(-8.0, -6.0, 16.0, 12.0), Color(shard.color, 1.0 - k * k))
	draw_rect(Rect2(-8.0, -6.0, 16.0, 12.0), Color(HUD_BROWN, 1.0 - k * k), false, 2.0)
	draw_set_transform(Vector2.ZERO)


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
	_draw_strip(canvas, tex, top, mist[1], size.x, Color(1, 1, 1, mist[3]))
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


## 고양이 그림자: 자세에 맞는 납작한 타원 하나 (원형 그라데이션 텍스처라 가장자리가 부드러움)
func _draw_shadow(pos: Vector2, shadow: Dictionary) -> void:
	var look := CatShadow.shape(cat.frame_name, cat.body_scale(), cat.spin())
	var r: float = look.radius * shadow.scale
	draw_set_transform(pos + Vector2(look.center_x, 0.0), 0.0, Vector2(1.0, look.flat))
	draw_texture_rect(_shadow_texture, Rect2(-r, -r, r * 2.0, r * 2.0), false, Color(SHADOW_COLOR, minf(1.0, shadow.alpha * look.alpha * SHADOW_PEAK)))
	draw_set_transform(Vector2.ZERO)


## 발밑 터짐: 납작하게 퍼지는 먼지 고리 + (더블점프·퍼펙트) 바깥으로 튀는 별
func _draw_burst(pos: Vector2, burst: Dictionary) -> void:
	var k: float = burst.t / BURST_TIME
	var out := 1.0 - (1.0 - k) * (1.0 - k)  # 빠르게 퍼졌다가 천천히
	draw_set_transform(pos, 0.0, Vector2(1.0, BURST_FLAT))
	draw_arc(Vector2.ZERO, BURST_RING * out, 0.0, TAU, 28, Color(BURST_COLOR, 0.85 * (1.0 - k)), 10.0 * (1.0 - k) + 1.0, true)
	draw_set_transform(Vector2.ZERO)
	if not burst.stars:
		return
	for i in BURST_STARS:
		# 아래쪽 반원으로 부채꼴 (발밑에서 옆·위로 튐)
		var a: float = PI + PI * (i + 0.5) / BURST_STARS
		var center: Vector2 = pos + Vector2(cos(a), sin(a) * 0.7) * BURST_STAR_REACH * out
		_draw_star(center, 11.0 * (1.0 - 0.5 * k), k * 3.0 + i, 1.0 - k * k)


## 다섯 뿔 별 (손그림 그림체에 맞게 갈색 테두리)
func _draw_star(center: Vector2, r: float, angle: float, alpha: float) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var a := angle + TAU * i / 10.0
		points.append(center + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(points, Color(BURST_STAR_COLOR, alpha))
	points.append(points[0])
	draw_polyline(points, Color(BURST_STAR_OUTLINE, alpha), 1.5, true)


## 옥상의 건물: 왼쪽 캡 + 가운데 조각들(옥상 폭에 맞춰 늘임) + 오른쪽 캡, 그림 아래는 벽 색으로 화면 바닥까지 채움, 그 위에 소품.
## 그림의 맨 윗줄 = 옥상 충돌선(화면 y = ground - roof.top). 고양이는 FOOT_SINK만큼 내려 그려 지붕 턱 윗면 가운데에 선다.
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
		if _near_obstacle(prop.x):
			continue
		var tex := BuildingArt.prop_texture(prop.kind)
		var prop_size: Vector2 = tex.get_size() * BuildingArt.PROP_SCALE
		draw_texture_rect(tex, Rect2(prop.x + offset - prop_size.x * 0.5, top + BuildingArt.PROP_SINK - prop_size.y, prop_size.x, prop_size.y), false, Color(1, 1, 1, BuildingArt.PROP_ALPHA))
	_draw_body_mist(left, right, top, ground)  # 벽 너비만 (지붕 턱은 BODY_MIST_FROM보다 위라 상관없음)


## 옥상 위 장애물(비둘기 제외) 둘레에 있는 자리인지
func _near_obstacle(at_x: float) -> bool:
	for o in sim.obstacles:
		if not o.has("k") and at_x > o.x - PROP_CLEAR and at_x < o.x + o.w + PROP_CLEAR:
			return true
	return false


func _look_of(roof: Dictionary) -> Dictionary:
	if not _roof_looks.has(roof.left):
		if _roof_looks.size() > 80:
			_roof_looks.clear()
		_roof_looks[roof.left] = {"plan": BuildingLayout.plan(roof.left, roof.right, BuildingArt.widths()),
				"props": BuildingLayout.props(roof.left, roof.right)}
	return _roof_looks[roof.left]


## 장애물 그림 크기 (너비는 Balance, 높이는 그림 비율대로)
static func _obstacle_size(kind: String) -> Vector2:
	var tex: Texture2D = OBSTACLE_TEXTURES[kind]
	var w: float = Balance.OBSTACLES[kind].art_w
	return Vector2(w, w * tex.get_height() / tex.get_width())


## 장애물: 발밑에 진한 접지 그림자, 판정 상자 가운데에 그림. 비둘기는 판정 높이 가운데에 떠 있고 옥상에 옅은 그림자
func _draw_obstacle(o: Dictionary, offset: float, ground: float) -> void:
	var center: float = RunnerSim.obstacle_left(o, sim.x) + o.w * 0.5
	var at := center + offset
	var art_size := _obstacle_size(o.kind)
	if at < -art_size.x or at > _view_size().x + art_size.x:
		return
	if o.kind == "flock":
		var below := sim.roof_at(center)
		if not below.is_empty():
			_draw_flat_shadow(Vector2(at, ground - below.top + FOOT_SINK), art_size.x, FLOCK_SHADOW_ALPHA)
		var fly_y: float = ground - (o.y0 + o.y1) * 0.5 + 4.0 * sin(sim.elapsed * 7.0 + o.x)
		draw_texture_rect(OBSTACLE_TEXTURES.flock, Rect2(at - art_size.x * 0.5, fly_y - art_size.y * 0.5, art_size.x, art_size.y), false)
		return
	var feet: float = ground - o.base + FOOT_SINK
	_draw_flat_shadow(Vector2(at, feet), art_size.x, OBSTACLE_SHADOW_ALPHA)
	draw_texture_rect(OBSTACLE_TEXTURES[o.kind], Rect2(at - art_size.x * 0.5, feet - art_size.y, art_size.x, art_size.y), false)


## 납작한 그림자 (너비 width)
func _draw_flat_shadow(pos: Vector2, width: float, alpha: float) -> void:
	draw_set_transform(pos, 0.0, Vector2(1.0, OBSTACLE_SHADOW_FLAT))
	draw_texture_rect(_shadow_texture, Rect2(-width * 0.6, -width * 0.6, width * 1.2, width * 1.2), false, Color(SHADOW_COLOR, alpha))
	draw_set_transform(Vector2.ZERO)


## 맞은 장애물: 앞·위로 튕기며 돌다 사라진다
func _draw_knocked(k: Dictionary, offset: float, ground: float) -> void:
	var u: float = k.t / KNOCK_TIME
	var art_size := _obstacle_size(k.kind)
	var pos := Vector2(k.x + offset + KNOCK_VX * k.t, ground - k.y + FOOT_SINK - art_size.y * 0.5 - KNOCK_VY * k.t + 0.5 * Balance.GRAVITY * k.t * k.t)
	draw_set_transform(pos, KNOCK_SPIN * k.t)
	draw_texture_rect(OBSTACLE_TEXTURES[k.kind], Rect2(-art_size * 0.5, art_size), false, Color(1, 1, 1, 1.0 - u * u))
	draw_set_transform(Vector2.ZERO)


## 전봇대: 판 옥상(platform) 위에 판이 오게 그리고 기둥은 화면 아래까지 늘린다 (기둥은 그림일 뿐 판정 없음)
## 판+받침(위 조각)과 가로대+애자(아래 조각)를 떼어, 가로대를 기둥 중간쯤에 둬서 판 아래로 기둥 몸통이 길게 보이게 한다
func _draw_pole(plate: Dictionary, offset: float, ground: float) -> void:
	var cx: float = (plate.left + plate.right) * 0.5 + offset
	if cx < -300.0 or cx > _view_size().x + 300.0:
		return
	var k: float = (plate.right - plate.left) / POLE_PLATE_WIDTH
	var top_y: float = ground - plate.top + FOOT_SINK - POLE_FACE_MID * k  # 판 윗면 가운데가 고양이 발 높이에
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
	if right < -100.0 or left > _view_size().x + 100.0:
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


## 트램펄린: 옥상 끝에 다리를 딛고(다리 끝 = 옥상 서는 자리) 상태마다 그림을 바꾼다.
## 평소 → 밟음(고양이가 실려 있는 동안, 튕긴 직후 TRAMP_PUSH초) → 튕김(TRAMP_POP초) → 출렁이며 평소로. 그림 사이는 세로 배율로 잇는다
func _draw_tramp(tramp: Dictionary, offset: float, ground: float) -> void:
	var left: float = tramp.left + offset
	if left > _view_size().x + 100.0 or left + Balance.TRAMP_WIDTH < -100.0:
		return
	var look := tramp_look(sim, tramp)
	var tex: Texture2D = TRAMP_TEXTURES[look.frame]
	var k := Balance.TRAMP_WIDTH / TRAMP_SRC_WIDTH
	var feet: float = ground - tramp.base + FOOT_SINK
	# 테까지와 다리를 따로 그려 다리만 길게. 다리 끝을 기준으로 세로로 늘이고 줄인다
	var w: float = tex.get_width() * k
	var x := left - TRAMP_SRC_LEFT * k
	var top_h: float = TRAMP_SRC_LEG * k * look.sy
	var leg_rows: float = tex.get_height() - TRAMP_SRC_LEG
	var leg_h: float = leg_rows * k * TRAMP_LEG_STRETCH * look.sy
	var top: float = feet - tramp_height(0.0, look.sy)
	draw_texture_rect_region(tex, Rect2(x, top, w, top_h), Rect2(0, 0, tex.get_width(), TRAMP_SRC_LEG))
	draw_texture_rect_region(tex, Rect2(x, top + top_h, w, leg_h), Rect2(0, TRAMP_SRC_LEG, tex.get_width(), leg_rows))


## 그림의 row줄이 다리 끝에서 몇 게임 픽셀 위인지 (0줄이면 트램펄린 전체 높이, 테 아래는 다리 늘임만큼 커짐)
static func tramp_height(row: float, sy: float) -> float:
	var k := Balance.TRAMP_WIDTH / TRAMP_SRC_WIDTH
	var legs := (TRAMP_SRC_FEET - TRAMP_SRC_LEG) * TRAMP_LEG_STRETCH
	var up := (TRAMP_SRC_FEET - row) * TRAMP_LEG_STRETCH if row >= TRAMP_SRC_LEG else legs + (TRAMP_SRC_LEG - row)
	return up * k * sy


## 고양이 그림을 로직 높이보다 얼마나 올려 그릴지 (그림만, 판정은 그대로): 그물로 폴짝 올라타고, 꺼진 그물을 따라 내려가고, 눌렸다 튀어 나간다
static func tramp_cat_lift(state: RunnerSim) -> float:
	if state.dashing:
		return 0.0
	var net := func(tramp: Dictionary, sy: float) -> float:
		return tramp.base + tramp_height(TRAMP_SRC_NET.pressed, sy) - state.y
	if state.is_riding():
		var riding: Dictionary = state.line_touch_eta(0.0).line
		return net.call(riding, TRAMP_PRESS_SY.good) if riding.kind == "tramp" else 0.0
	if state.bounced_line.get("kind", "") == "tramp" and state.time_since_bounce < state.time_since_land:
		var t := state.time_since_bounce
		var lift: float = net.call(state.bounced_line, TRAMP_PRESS_SY[state.bounce_result])
		if t < Balance.TRAMP_PUSH:
			return lift
		if t < Balance.TRAMP_PUSH + TRAMP_RELEASE:
			return lift * (1.0 - (t - Balance.TRAMP_PUSH) / TRAMP_RELEASE)
	if state.on_ground:
		for tramp in state.structures:
			if tramp.kind == "tramp" and tramp.base == state.y and not state.is_slack(tramp):
				var u: float = (state.x - tramp.left + TRAMP_HOP_FROM) / (Balance.TRAMP_RUN_IN + TRAMP_HOP_FROM)
				if u > 0.0 and u <= 1.0:
					return tramp_height(TRAMP_SRC_NET.rest, 1.0) * sin(u * PI * 0.5) + TRAMP_HOP_ARC * sin(u * PI)
	return 0.0


## 트램펄린의 지금 모양 {"frame": rest/pressed/launch, "sy": 세로 배율} (sim 상태만으로 정해 캡처·테스트에서 같은 값)
static func tramp_look(state: RunnerSim, tramp: Dictionary) -> Dictionary:
	if state.is_riding() and is_same(state.line_touch_eta(0.0).line, tramp):
		return {"frame": "pressed", "sy": TRAMP_PRESS_SY.good}
	if not is_same(state.bounced_line, tramp) or state.time_since_bounce >= Balance.TRAMP_PUSH + TRAMP_POP + TRAMP_SETTLE:
		return {"frame": "rest", "sy": 1.0}
	var result: String = state.bounce_result
	var t := state.time_since_bounce
	if t < Balance.TRAMP_PUSH:
		return {"frame": "pressed", "sy": TRAMP_PRESS_SY[result]}
	t -= Balance.TRAMP_PUSH
	if t < TRAMP_POP:
		return {"frame": "launch", "sy": 1.0 + TRAMP_POP_SY[result] * sin(PI * t / TRAMP_POP)}
	# 출렁이며 평소로: 줄어드는 사인 (약 3번 출렁임)
	var u := (t - TRAMP_POP) / TRAMP_SETTLE
	return {"frame": "rest", "sy": 1.0 - 0.5 * TRAMP_POP_SY[result] * sin(TAU * 3.0 * u) * (1.0 - u) * (1.0 - u)}


## 아이템 그림을 가운데 pos에 그린다 (zoom 배율, alpha 투명도)
func _draw_item(kind: String, pos: Vector2, zoom: float, alpha: float) -> void:
	if pos.x < -100.0 or pos.x > _view_size().x + 100.0:
		return
	var texture: Texture2D = ITEM_TEXTURES[kind]
	var w: float = ITEM_WIDTHS[kind] * zoom
	var h := w * texture.get_height() / texture.get_width()
	draw_texture_rect(texture, Rect2(pos - Vector2(w, h) * 0.5, Vector2(w, h)), false, Color(1, 1, 1, alpha))


## 맨 앞 안내: 처음 GUIDE_LINES개 줄 틈의 줄어드는 동그라미와 "눌러!" 말풍선, 줄 판정 결과 글자. HUD는 화면 배율 없이 뒤에 그린다
func _draw_overlay() -> void:
	var ground := _ground_y()
	var offset := Balance.CAT_SCREEN_X - sim.x
	_overlay.draw_set_transform(position, 0.0, scale)
	var touch := sim.line_touch_eta(GUIDE_TIME)
	if not touch.is_empty() and not sim.game_over:
		# 첫 점프를 누르고 있는 동안은 그리지 않는다 (누름이 끝난 뒤부터)
		if _guided.has(touch.line.left) and not sim.is_holding():
			# 트램펄린은 판정 높이가 아니라 눈에 보이는 그물 위를 가리킨다
			var aim: float = touch.line.base + tramp_height(TRAMP_SRC_NET.rest, 1.0) if touch.line.kind == "tramp" else touch.line.top
			var at := Vector2(touch.x + offset, ground - aim + FOOT_SINK)
			var r := lerpf(GUIDE_PAW, GUIDE_START, touch.t / GUIDE_TIME)
			_overlay.draw_arc(at, GUIDE_PAW, 0.0, TAU, 32, Color(HUD_BROWN, 0.45), 3.0)
			_overlay.draw_arc(at, r, 0.0, TAU, 48, HUD_CREAM, 9.0)
			_overlay.draw_arc(at, r, 0.0, TAU, 48, HUD_BROWN, 5.0)
			_draw_bubble(Vector2(Balance.CAT_SCREEN_X, ground - sim.y + FOOT_SINK - _cat_lift - Balance.CAT_BODY_SIZE.y - 46.0), "눌러!")
	_draw_obstacle_signs(ground, offset)
	if RESULT_TEXT.has(sim.bounce_result) and sim.time_since_bounce < RESULT_TIME:
		var k := sim.time_since_bounce / RESULT_TIME
		# 고양이 머리 위에서 떠올랐다 사라짐 (몸과 겹치지 않게)
		var at := Vector2(Balance.CAT_SCREEN_X, ground - sim.y + FOOT_SINK - _cat_lift - Balance.CAT_BODY_SIZE.y - 50.0 - 40.0 * k)
		_draw_text(at, RESULT_TEXT[sim.bounce_result], 44, 1.0 - k * k)
	for pop in _pop_texts:
		var k: float = pop.t / POP_TEXT_TIME
		_draw_text(Vector2(pop.x + offset, ground - pop.y + FOOT_SINK - 50.0 * k), pop.text, 54, 1.0 - k * k, ALERT_COLOR)
	_overlay.draw_set_transform(Vector2.ZERO)
	_draw_hearts()
	if not sim.game_over:
		_draw_speed_lines()
		_draw_status()
		if sim.time_since_stage_rise < STAGE_SIGNAL_TIME:
			_draw_stage_signal(sim.time_since_stage_rise / STAGE_SIGNAL_TIME)


## 장애물 위 "!", 처음 만남 안내 말풍선, 비둘기가 오기 전 오른쪽 끝 깃털 표시
func _draw_obstacle_signs(ground: float, offset: float) -> void:
	var view_w := _view_size().x
	for o in sim.obstacles:
		var left: float = RunnerSim.obstacle_left(o, sim.x)
		if o.kind == "flock" and not sim.game_over:
			var eta := RunnerSim.flock_eta(o, sim.x, sim.vx(), view_w - Balance.CAT_SCREEN_X)
			if eta > 0.0 and eta <= FLOCK_WARN_TIME:
				_draw_feather(Vector2(view_w - 34.0, ground - (o.y0 + o.y1) * 0.5))
		if alert_showing(o, sim.x, _alerts):
			var height: float = _obstacle_size(o.kind).y + (o.y0 - o.base)
			var bob: float = ALERT_BOB * absf(sin(PI * ALERT_BOB_HZ * sim.elapsed + o.id))  # 튀어 오르는 느낌: 바닥에서 위로만
			var at := Vector2(minf(left + o.w * 0.5 + offset, view_w - 40.0), maxf(44.0, ground - o.base + FOOT_SINK - height - ALERT_RISE - bob))
			var pop: float = minf(1.0, _alerts[o.id] / ALERT_POP)  # 처음에 통 뜬다
			_draw_text(at, "!", roundi(72.0 * (0.5 + 0.5 * pop)), 1.0, ALERT_COLOR)
	if not _hint.is_empty() and not sim.game_over:
		_draw_bubble(Vector2(Balance.CAT_SCREEN_X, ground - sim.y + FOOT_SINK - _cat_lift - Balance.CAT_BODY_SIZE.y - 46.0), _hint.text)


## "!"를 보여 줄 때: 화면에 들어왔고 몸 뒤쪽이 아직 장애물을 다 지나지 않았을 때 (부순 장애물은 목록에서 빠져 같이 사라짐)
static func alert_showing(o: Dictionary, cat_x: float, alerts: Dictionary) -> bool:
	return alerts.has(o.id) and RunnerSim.obstacle_left(o, cat_x) + o.w >= cat_x - Balance.CAT_BODY_SIZE.x * 0.5


## 깃털 표시: 크림색 테두리 위에 비스듬한 깃털 (코드 도형)
func _draw_feather(at: Vector2) -> void:
	var points := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		points.append(at + Vector2(cos(a) * 24.0, sin(a) * 10.0).rotated(-0.5))
	_overlay.draw_colored_polygon(points, HUD_CREAM)
	_overlay.draw_polyline(points + PackedVector2Array([points[0]]), HUD_BROWN, 3.0, true)
	_overlay.draw_line(at + Vector2(-30.0, 16.0), at + Vector2(20.0, -10.0), HUD_BROWN, 3.0, true)


## 이 자리(왼쪽부터 index, 0부터)의 하트 그림: 오른쪽부터 잃고, 잃은 직후에는 금 간 하트
static func heart_frame(index: int, hearts: int, since_hit: float) -> String:
	if index < hearts:
		return "full"
	return "crack" if index == hearts and since_hit < HEART_CRACK_TIME else "empty"


## 하트 HUD. 1개 남으면 천천히 두근거림 (1초에 1번)
func _draw_hearts() -> void:
	var total := Balance.HEARTS_MAX * HEART_SIZE.x + (Balance.HEARTS_MAX - 1) * HEART_GAP
	var x := (get_viewport_rect().size.x - total) * 0.5
	for i in Balance.HEARTS_MAX:
		var k := 1.0 + HEART_PULSE * absf(sin(PI * sim.elapsed)) if sim.hearts == 1 and i == 0 else 1.0
		var box: Vector2 = HEART_SIZE * k
		var at := Vector2(x + i * (HEART_SIZE.x + HEART_GAP), HEART_Y) - (box - HEART_SIZE) * 0.5
		_overlay.draw_texture_rect(HEART_TEXTURES[heart_frame(i, sim.hearts, sim.time_since_hit)], Rect2(at, box), false)
	_draw_bell(Vector2(x + total + HEART_GAP, HEART_Y))


## 방울 HUD: 가지고 있으면 하트 오른쪽에, 막은 직후에는 두 쪽으로 갈라져 떨어진다
func _draw_bell(at: Vector2) -> void:
	var tex: Texture2D = ITEM_TEXTURES.bell
	var box := Vector2(BELL_HUD_SIZE, BELL_HUD_SIZE)
	if sim.has_bell:
		_overlay.draw_texture_rect(tex, Rect2(at, box), false)
	elif _bell_break < BELL_BREAK_TIME:
		var k := _bell_break / BELL_BREAK_TIME
		var half := Vector2(tex.get_width() * 0.5, tex.get_height())
		for side in 2:
			var fly := Vector2((side * 2 - 1) * 30.0 * k, 50.0 * k * k)
			_overlay.draw_texture_rect_region(tex, Rect2(at + Vector2(side * box.x * 0.5, 0.0) + fly, Vector2(box.x * 0.5, box.y)),
					Rect2(Vector2(side * half.x, 0.0), half), Color(1, 1, 1, 1.0 - k * k))


## 하트 아래 진행 막대: 질주·털실의 아이콘 + 남은 시간
func _draw_status() -> void:
	var rows: Array = []
	if sim.dashing:
		rows.append(["dash", sim.dash_time / Balance.DASH_TIME])
	if sim.magnet_time > 0.0:
		rows.append(["yarn", sim.magnet_time / Balance.MAGNET_TIME])
	var row_w := STATUS_ICON + 6.0 + STATUS_BAR.x
	var x := (get_viewport_rect().size.x - rows.size() * row_w - (rows.size() - 1) * HEART_GAP * 2.0) * 0.5
	for row: Array in rows:
		_overlay.draw_texture_rect(ITEM_TEXTURES[row[0]], Rect2(x, STATUS_Y, STATUS_ICON, STATUS_ICON), false)
		var bar := Rect2(x + STATUS_ICON + 6.0, STATUS_Y + 10.0, STATUS_BAR.x, STATUS_BAR.y)
		_overlay.draw_rect(bar, HUD_CREAM)
		_overlay.draw_rect(Rect2(bar.position, Vector2(STATUS_BAR.x * row[1], STATUS_BAR.y)), DASH_GLOW)
		_overlay.draw_rect(bar, HUD_BROWN, false, 2.0)
		x += row_w + HEART_GAP * 2.0


## 속도선: 선마다 높이·길이·빠르기를 번호로 고정해 깜빡이지 않고 흘러가게 한다
func _draw_speed_lines() -> void:
	var strength := 1.0 if sim.dashing else SpeedCurve.line_strength(sim.stage, sim.time_since_stage_rise)
	if strength <= 0.0:
		return
	var size := get_viewport_rect().size
	var color := Color(SPEED_LINE_COLOR, 0.35 + 0.6 * strength)
	for i in ceili(SPEED_LINE_COUNT * strength):
		var length := 140.0 + 280.0 * fposmod(i * 0.37, 1.0)
		var flow := (1800.0 + 900.0 * fposmod(i * 0.73, 1.0)) * sim.elapsed + i * 311.0
		var x := size.x + length - fposmod(flow, size.x + 2.0 * length)
		var y := size.y * fposmod(i * 0.618, 1.0)
		var half := 2.0 + 3.0 * fposmod(i * 0.29, 1.0)
		_overlay.draw_colored_polygon([Vector2(x - length, y), Vector2(x, y - half), Vector2(x, y + half)], color)


## 위 가운데 "빨라진다!" + 발바닥 도장 (단계 수만큼). k = 0~1, 끝에서 옅어짐
func _draw_stage_signal(k: float) -> void:
	var alpha := 1.0 - smoothstep(0.7, 1.0, k)
	var center := get_viewport_rect().size.x * 0.5
	_draw_text(Vector2(center, STAGE_TEXT_Y), "빨라진다!", 52, alpha)
	for i in sim.stage:
		_draw_paw(Vector2(center + (i - (sim.stage - 1) * 0.5) * STAGE_PAW_GAP, STAGE_PAW_Y), alpha)


## 발바닥 도장: 크림색 테두리 위에 갈색 발바닥 (큰 볼록살 + 발가락 3개)
func _draw_paw(at: Vector2, alpha: float) -> void:
	var dots := [[Vector2(0, 5), 10.0], [Vector2(-11, -5), 5.0], [Vector2(0, -10), 5.0], [Vector2(11, -5), 5.0]]
	for dot in dots:
		_overlay.draw_circle(at + dot[0], dot[1] + 3.0, Color(HUD_CREAM, alpha))
	for dot in dots:
		_overlay.draw_circle(at + dot[0], dot[1], Color(HUD_BROWN, alpha))


## 말풍선 (HUD와 같은 갈색 글자·밝은 테두리, 크림색 바탕)
func _draw_bubble(center: Vector2, text: String) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = HUD_CREAM
	box.border_color = HUD_BROWN
	box.set_border_width_all(3)
	box.set_corner_radius_all(16)
	var w := maxf(118.0, HUD_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x + 36.0)
	var h := 50.0
	_overlay.draw_style_box(box, Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h)))
	_draw_text(center + Vector2(0.0, 2.0), text, 34, 1.0)


## 가운데 정렬 글자 (center = 글자 가운데)
func _draw_text(center: Vector2, text: String, size: int, alpha: float, color: Color = HUD_BROWN) -> void:
	var width := HUD_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := center + Vector2(-width * 0.5, size * 0.35)
	_overlay.draw_string_outline(HUD_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(HUD_CREAM, alpha))
	_overlay.draw_string(HUD_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, alpha))
