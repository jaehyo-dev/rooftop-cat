extends Control
## 게임 화면(World), 거리·최고 점수·생선 수·종이상자, 오른쪽 위 점수·콤보, 결과 화면, 버전 표시.
## v0.7.0 2c 화면 흐름 (review/v0.7.0/PLAN.md 1번): 시작 화면 → 판 → 결과 카드, 시작 화면·결과 카드에서 상점·미션, [뒤로] = 온 곳.
## 화면마다 scripts/ui/의 Control이 그리고, 여기서는 어느 화면인지만 바꾼다 (판 중에는 상점·미션에 못 감).
## 글꼴은 Gaegu Bold(main.tscn 테마, 한글 포함). 갈색 글자 + 얇은 밝은 테두리.
## 손맛(2b): 콤보 배수가 오르면 숫자가 톡 튀고, 생선 점수가 오르면 점수가 살짝 흔들린다. 결과 숫자는 하나씩 차오르고 새 기록이면 별이 내린다.

## 켜면 시작 화면부터 (false = 바로 판, 예전 테스트·캡처 도구용)
var show_start := true
## 지금 화면: "start" / "run" / "result" / "shop" / "missions"
var screen := ""
## 저장 위치 (테스트에서 바꿔 실제 기록을 건드리지 않는다)
var record_path := SaveData.DEFAULT_PATH
## 기록·지갑·강화·부스터 (_ready에서 읽음)
var save: SaveData
## 다음 판에 켤 부스터 (판이 시작되면 쓴 만큼 줄고 다시 꺼짐, PLAN 1번). 2c에서 시작 화면·결과 카드의 부스터 칸이 바꿈
var boosters_on: Array = []
## 미션 날짜 (테스트·시험 패널이 시각을 바꿈)
var clock := DayClock.new()
## 지난 판 미션 결과 {"done", "ranks"} (Missions.count). 결과 카드 쪽지·등급 도장이 읽음
var mission_result := {}
var start_menu: StartMenu
var shop: ShopScreen
var board: MissionBoard
var result_slots: BoosterSlots
var _extras: ResultExtras
var _back_to := "start"
var _blockers: Array[Control] = []  # 지금 화면이 World.touch_blockers에 넣은 버튼 자리
var _ui_sfx := {}
var _hint := UiKit.label("", 26, UiKit.RED, HORIZONTAL_ALIGNMENT_CENTER)
var _result_dot := UiKit.badge(34.0)

## 메뉴 소리 (tools/make_sfx.py UI_SOUNDS). 생선 소리(-17dB)보다 튀지 않게 같은 크기로
const UI_SOUNDS := ["buy", "booster_buy", "booster_on", "no_money", "claim", "rank_up", "swap", "page"]
const UI_VOLUME_DB := -17.0
## HUD (판 중·결과 카드에서만 보임)
const HUD := ["DistanceLabel", "BestLabel", "FishIcon", "FishLabel", "ScoreLabel", "ComboLabel"]
const WORLD := preload("res://scripts/world_view.gd")

## 배경 음악 "찹쌀떡 산책" (tools/make_music.py로 합성한 루프)
const MUSIC := preload("res://assets/audio/mochi_walk.ogg")
const MUSIC_VOLUME_DB := -5.0  # 곡 자체가 -21.4 LUFS라 -26.4 (효과음 world_view.gd SFX_VOLUME_DB와 맞춤)
## 질주 북 층 (tools/make_music.py ... drums): 곡과 길이·박자가 같아 처음부터 같이 틀어 두고 질주 중에만 소리를 키운다.
## 빨라질 때는 같은 빠르기를 넘긴다. 웹은 반복할 때 곡과 북이 각자 새 재생 소스를 만들어 한 바퀴마다 10~20ms씩 어긋남이 쌓이고
## 재생 위치 값도 실제 소리보다 늦어 믿을 수 없다 (실제 브라우저에서 잼). 그래서 웹에서는 자동 반복을 끄고 곡이 끝나면 둘을 같이 다시 튼다
const DASH_DRUMS := preload("res://assets/audio/mochi_dash_drums.ogg")
const DRUM_VOLUME_DB := -6.0
const DRUM_IN := 0.1    # 질주 시작에 빠르게 들어옴 (초)
const DRUM_OUT := 0.5   # 끝날 때 빠지는 시간
## 질주 중 생선 점수 배율 표시 (콤보 글자 왼쪽에 작게)
const DASH_BONUS_COLOR := Color("#e8a21a")

## 웹(샘플 재생)은 곡이 한 바퀴 돌거나 멈췄다 이어질 때 새 재생 소스를 만들며 빠르기를 1.0으로 되돌리고 게임에 알려 주지 않는다.
## 그래서 바뀔 때만 넘기지 않고 이 간격(초)마다 다시 넘긴다 (tools/web_music_check.mjs로 실제 브라우저에서 확인)
const MUSIC_PITCH_RESEND := 0.1

## HUD 튀기: 콤보 배수가 오를 때 크게 찍혔다 줄어드는 시간, 점수가 오를 때 흔들리는 시간
const COMBO_POP_TIME := 0.25
const COMBO_POP := 0.45
const SCORE_POP_TIME := 0.15
const SCORE_POP := 0.08
## 새 기록 축하: 위에서 내리는 별 수와 한 번 내려오는 시간
const CELEBRATE_STARS := 26
const CELEBRATE_FALL := 2.4
const STAR_FILL := Color("#ffd166")
const STAR_LINE := Color("#a8693a")
## 결과 카드 (2b 수정): 색연필 종이 + 손으로 그은 듯 흔들리는 테두리 두 줄 + 그림자. 별은 카드 뒤로 내린다
const CARD_PAPER := Color("#fff6e6")
const CARD_HATCH := Color(0.91, 0.78, 0.6, 0.22)  # 종이 결: 옅은 빗금
const CARD_LINE := Color(0.353, 0.275, 0.212)
const CARD_SHADOW := Color(0.18, 0.12, 0.08, 0.35)
const CARD_WOBBLE := 4.0

var _best := 0
var _combo_pop := 99.0
var _score_pop := 99.0
var _last_mult := 1
var _last_points := 0
## 결과 화면: 차오르는 숫자 [거리, 먹은 생선, 최고 콤보, 점수], 모은 생선, 새 기록인지, 뜬 뒤 지난 시간
var _result := {}
var _celebrate := Node2D.new()
var _pitch_wait := 0.0
## 지금까지 곡에 빠르기를 넘긴 횟수 (테스트용: 웹에서 풀린 빠르기는 headless에서 볼 수 없다)
var pitch_sends := 0
var _music := AudioStreamPlayer.new()
var _drums := AudioStreamPlayer.new()
var _drum_gain := 0.0
var _dash_bonus := Label.new()

@onready var _world: Node2D = $World


func _ready() -> void:
	# 버전은 project.godot 한 곳에서 읽는다.
	$VersionLabel.text = "v" + str(ProjectSettings.get_setting("application/config/version"))
	save = SaveData.open(record_path)
	_best = save.best_score()
	_world.game_over.connect(_on_game_over)
	_world.restarted.connect(_on_restarted)
	_world.make_perks = _start_run
	_world.start_pressed.connect(begin_run)
	for sound: String in UI_SOUNDS:
		var player := AudioStreamPlayer.new()
		player.name = "Ui_" + sound
		player.stream = load("res://assets/audio/sfx/%s.wav" % sound)
		player.volume_db = UI_VOLUME_DB
		add_child(player)
		_ui_sfx[sound] = player
	_build_menus()
	Missions.start_run(save, clock.now())  # 날짜가 바뀌었으면 미션 새로 뽑기 (시작 화면이 미션 수를 보여 줌)
	if show_start:
		_world.prepare()  # 강화 없이 첫 옥상에서 멈춤. [시작] 때 같은 시드로 강화를 넣어 다시 만든다
		show_screen("start")
	else:
		_world.restart()
		show_screen("run")
	DevPanel.attach(self)
	# 배경 음악: 끝나면 처음부터 반복. 웹에서는 첫 터치·클릭 뒤부터 소리가 난다 (브라우저 규칙)
	var music_stream: AudioStreamOggVorbis = MUSIC.duplicate()
	music_stream.loop = not OS.has_feature("web")
	_music.name = "Music"
	_music.stream = music_stream
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	var drum_stream: AudioStreamOggVorbis = DASH_DRUMS.duplicate()
	drum_stream.loop = music_stream.loop
	_drums.name = "DashDrums"
	_drums.stream = drum_stream
	_drums.volume_db = -80.0
	add_child(_drums)
	_music.finished.connect(_loop_music)  # 웹에서만 불림 (데스크톱은 자동 반복)
	_loop_music()
	_dash_bonus.name = "DashBonus"
	_dash_bonus.text = "x%d" % Balance.DASH_FISH_MULT
	_dash_bonus.add_theme_font_size_override("font_size", 30)
	_dash_bonus.add_theme_color_override("font_color", DASH_BONUS_COLOR)
	_dash_bonus.visible = false
	add_child(_dash_bonus)
	_celebrate.name = "Celebrate"
	_celebrate.draw.connect(_draw_celebrate)
	$GameOver.add_child(_celebrate)
	$GameOver.move_child(_celebrate, 0)  # 카드보다 먼저 그려 별이 글자를 가리지 않게
	$GameOver/Card.draw.connect(_draw_card)


func _process(delta: float) -> void:
	$DistanceLabel.text = "%d m" % _world.sim.distance()
	$FishLabel.text = str(_world.sim.fish)
	$BoxIcon.visible = _world.sim.has_box
	$ScoreLabel.text = str(_world.sim.score())
	var combo: FishCombo = _world.sim.combo
	$ComboLabel.text = "콤보 %d  x%d" % [combo.count, combo.multiplier()] if combo.count > 0 else ""
	_pop_hud(combo, delta)
	_place_dash_bonus(combo)
	$BoxIcon.visible = _world.sim.has_box and screen == "run"
	$ComboLabel.visible = screen == "run"  # 결과 카드에서는 카드에 최고 콤보가 있고 등급 배지와 겹침
	if $GameOver.visible:
		_count_result(delta)
	# 단계마다 곡이 조금씩 빨라진다
	var pitch := SpeedCurve.music_pitch(_world.sim.stage)
	_pitch_wait -= delta
	if _pitch_wait <= 0.0 or not is_equal_approx(_music.pitch_scale, pitch):
		_music.pitch_scale = pitch
		_drums.pitch_scale = pitch  # 북 층도 같은 빠르기 (박자가 어긋나지 않게 함께)
		_pitch_wait = MUSIC_PITCH_RESEND
		pitch_sends += 1
	_drum_gain = Juice.fade(_drum_gain, _world.sim.dashing and not _world.sim.game_over, delta, DRUM_IN, DRUM_OUT)
	_drums.volume_db = DRUM_VOLUME_DB + linear_to_db(maxf(_drum_gain, 0.0001))


## 곡과 북을 같은 순간에 처음부터 튼다 (박자를 맞춤)
func _loop_music() -> void:
	_music.play()
	_drums.play()


## 질주 중에만 콤보 글자 바로 왼쪽에 작게 "x2" (콤보 글자는 오른쪽 정렬이라 글자 너비만큼 왼쪽)
func _place_dash_bonus(combo: FishCombo) -> void:
	var label: Label = $ComboLabel
	_dash_bonus.visible = _world.sim.dashing and combo.count > 0 and not _world.sim.game_over  # 결과 카드 위에 뜨지 않게
	if not _dash_bonus.visible:
		return
	var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	_dash_bonus.size = _dash_bonus.get_minimum_size()
	_dash_bonus.position = Vector2(label.position.x + label.size.x - width - _dash_bonus.size.x - 8.0, label.position.y + 6.0)


## 판 시작 (World.restart가 부름): 켠 부스터를 줄여 저장하고 이번 판 강화·부스터를 돌려준다
func _start_run() -> Perks:
	Missions.start_run(save, clock.now())  # 23:59 결과 카드에서 00:01에 다시 하기를 눌러도 새 날 미션에 들어감 (PLAN 7번)
	var perks := save.start_run(boosters_on)
	boosters_on = []
	return perks


func _on_game_over(meters: int) -> void:
	var sim: RunnerSim = _world.sim
	var score: int = sim.score()
	# shortcut: 게임 끝에만 저장해 판 중간에 창을 닫으면 그 판 생선은 사라짐 (PLAN 2-2에서 유지하기로 함)
	var bonus := sim.perks.has_booster("fish_bonus")
	var run := save.finish_run(meters, score, sim.fish, bonus)
	mission_result = Missions.end_run(save, _world.tracker.result(sim), clock.now())
	_best = save.best_score()
	_result = {"values": [meters, sim.fish, sim.combo.best, score], "wallet": run.total - run.earned, "earned": run.earned, "bonus": bonus,
			"new_best": run.new_best, "t": 0.0, "extras": false}
	boosters_on = []  # 결과 카드의 부스터 칸은 늘 꺼진 채로 (실수로 계속 쓰지 않게, PLAN 1번)
	# 한 줄 안내: v0.7.0 처음 켬(점수 기준이 바뀜) → 첫 판(상점 안내)
	_hint.text = "점수 계산이 바뀌어 최고 점수를 새로 시작해요" if save.score_reset else ("상점에서 강화를 살 수 있어요" if save.data.stats.runs == 1 else "")
	save.score_reset = false
	_extras.clear()
	_count_result(0.0)
	show_screen("result")
	$BestLabel.text = "BEST %d" % _best


## 결과 숫자를 하나씩 차오르게 쓴다. 다 차면 새 기록 축하 (별·소리·글자 통통)
func _count_result(delta: float) -> void:
	var was_done := Juice.count_done(_result.values, _result.t)
	_result.t += delta
	var shown := Juice.count_up(_result.values, _result.t)
	var done := Juice.count_done(_result.values, _result.t)
	var last := ""
	if done:
		last = "새 기록!" if _result.new_best else "최고 점수  %d" % _best
	$GameOver/Card/Box/Score.text = "점수  %d" % shown[3]
	$GameOver/Card/Box/Stats.text = "거리  %d m\n먹은 생선  %d%s\n최고 콤보  %d" % [shown[0], shown[1], "  +50%" if _result.bonus else "", shown[2]]
	$GameOver/Card/Box/Best.text = last if done else " "  # 빈 줄로 자리를 잡아 카드 크기가 변하지 않게
	# 다 차면 실제 지갑 (미션 받기·사기로 바뀐 값까지)
	$GameOver/Card/Box/Total.text = "모은 생선 %d" % (save.fish() if done else _result.wallet + ceili(shown[1] * (Balance.FISH_BONUS_MULT if _result.bonus else 1.0)))
	var label: Label = $GameOver/Card/Box/Score
	label.pivot_offset = label.size * 0.5
	if done and not was_done and _result.new_best:
		_world.play_sfx("perfect")
	if done and not _result.extras:
		_result.extras = true
		_extras.play(mission_result, $GameOver/Card.get_global_rect())
	var since_done: float = _result.t - Juice.COUNT_UP_EACH * _result.values.size()
	label.scale = Vector2.ONE * (1.0 + 0.08 * maxf(0.0, 1.0 - since_done / 0.3) if done and _result.new_best else 1.0)
	_celebrate.queue_redraw()


## 결과 카드: 그림자 → 종이 → 빗금 결 → 흔들리는 테두리 두 줄 (번호로 정한 흔들림이라 늘 같은 모양)
func _draw_card() -> void:
	var card: Control = $GameOver/Card
	var rect := Rect2(Vector2.ZERO, card.size)
	var paper := Juice.wobbly_rect(rect, 1, CARD_WOBBLE)
	var shadow := PackedVector2Array()
	for p in paper:
		shadow.append(p + Vector2(10.0, 12.0))
	card.draw_colored_polygon(shadow, CARD_SHADOW)
	card.draw_colored_polygon(paper, CARD_PAPER)
	for i in int((rect.size.x - 80.0) / 26.0):  # 빗금이 카드 밖으로 나가지 않게
		var x := 20.0 + i * 26.0
		card.draw_line(Vector2(x, rect.size.y - 18.0), Vector2(x + 40.0, rect.size.y - 18.0 - rect.size.y * 0.25), CARD_HATCH, 2.0, true)
		card.draw_line(Vector2(x, 18.0 + rect.size.y * 0.25), Vector2(x + 40.0, 18.0), CARD_HATCH, 2.0, true)
	for pass_seed in [2, 3]:
		var line := Juice.wobbly_rect(rect.grow(-3.0 * (pass_seed - 2)), pass_seed, CARD_WOBBLE)
		line.append(line[0])
		card.draw_polyline(line, CARD_LINE, 4.0 if pass_seed == 2 else 2.0, true)


## 새 기록이면 위에서 별이 돌며 내린다 (번호로 자리·빠르기를 정해 무작위 없음)
func _draw_celebrate() -> void:
	if _result.is_empty() or not _result.new_best or not Juice.count_done(_result.values, _result.t):
		return
	var t: float = _result.t - Juice.COUNT_UP_EACH * _result.values.size()
	var size := get_viewport_rect().size
	for i in CELEBRATE_STARS:
		var fall := CELEBRATE_FALL * (0.8 + 0.4 * fposmod(i * 0.37, 1.0))
		var u := fposmod(t / fall + fposmod(i * 0.618, 1.0), 1.0)
		var at := Vector2(size.x * fposmod(i * 0.29 + 0.05, 1.0) + 30.0 * sin(t * 2.0 + i), -30.0 + (size.y + 60.0) * u)
		var r := 10.0 + 8.0 * fposmod(i * 0.53, 1.0)
		var points := PackedVector2Array()
		for j in 10:
			var a := t * (2.0 + i % 3) + TAU * j / 10.0
			points.append(at + Vector2(cos(a), sin(a)) * (r if j % 2 == 0 else r * 0.45))
		var alpha := minf(1.0, t * 3.0)  # 처음에 스르륵 나타남
		_celebrate.draw_colored_polygon(points, Color(STAR_FILL, alpha))
		points.append(points[0])
		_celebrate.draw_polyline(points, Color(STAR_LINE, alpha), 1.5, true)


## 콤보 배수가 오르면 콤보 글자가 톡 튀고, 생선 점수가 오르면 점수 글자가 살짝 커졌다 돌아온다
func _pop_hud(combo: FishCombo, delta: float) -> void:
	_combo_pop += delta
	_score_pop += delta
	if combo.multiplier() > _last_mult:
		_combo_pop = 0.0
	if combo.points > _last_points:
		_score_pop = 0.0
	_last_mult = combo.multiplier()
	_last_points = combo.points
	var combo_k := maxf(0.0, 1.0 - _combo_pop / COMBO_POP_TIME)
	var score_k := maxf(0.0, 1.0 - _score_pop / SCORE_POP_TIME)
	for pair in [[$ComboLabel, 1.0 + COMBO_POP * combo_k * combo_k], [$ScoreLabel, 1.0 + SCORE_POP * score_k]]:
		var label: Label = pair[0]
		label.pivot_offset = Vector2(label.size.x, label.size.y * 0.5)  # 오른쪽 정렬이라 오른쪽 끝을 기준으로
		label.scale = Vector2.ONE * pair[1]
	$ScoreLabel.rotation = 0.05 * sin(_score_pop * 60.0) * score_k


func _on_restarted() -> void:
	$FishIcon.texture = WORLD.FISH_LOOKS[_world.sim.perks.fish_look()]  # HUD 생선도 지금 단계 그림
	if _world.waiting:
		return  # 시작 화면 준비 (판 시작 아님)
	if screen != "run":
		show_screen("run")
	_result = {}
	_last_mult = 1
	_last_points = 0
	$GameOver.visible = false
	$BestLabel.text = "BEST %d" % _best


# --- 화면 흐름 (v0.7.0 2c) ---

func _build_menus() -> void:
	start_menu = StartMenu.new(self)
	start_menu.start.connect(begin_run)
	start_menu.open_shop.connect(open_shop)
	start_menu.open_missions.connect(open_missions)
	add_child(start_menu)
	start_menu.visible = false
	# 결과 카드: 다시 하기(크게) · 부스터 칸 · 상점 · 미션, 한 줄 안내. 깬 미션 쪽지·등급 도장은 카드 둘레(ResultExtras)
	var box: VBoxContainer = $GameOver/Card/Box
	box.custom_minimum_size.x = 560
	var retry: Button = box.get_node("Retry")
	var orange := UiKit.button("", "orange", null, 52)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		retry.add_theme_stylebox_override(state, orange.get_theme_stylebox(state))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_outline_color"]:
		retry.add_theme_color_override(key, orange.get_theme_color(key))
	retry.add_theme_constant_override("outline_size", 4)
	retry.add_theme_font_size_override("font_size", 52)
	orange.free()
	retry.focus_mode = Control.FOCUS_NONE
	retry.custom_minimum_size = Vector2(320, 100)
	retry.pressed.connect(begin_run)
	_hint.name = "Hint"
	box.add_child(_hint)
	box.move_child(_hint, retry.get_index())
	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	result_slots = BoosterSlots.new(self)
	result_slots.want_shop.connect(open_shop.bind("boosters"))
	row.add_child(result_slots)
	for pair in [["Shop", "basket"], ["Missions", "note_check"]]:
		var b := UiKit.button("", "cream", UiKit.ICONS[pair[1]])
		b.name = pair[0]
		b.custom_minimum_size = Vector2(UiKit.MIN_BUTTON + 8, BoosterSlots.SIZE)
		b.add_theme_constant_override("icon_max_width", 62)
		row.add_child(b)
	row.get_node("Shop").pressed.connect(open_shop.bind("upgrades"))
	row.get_node("Missions").pressed.connect(open_missions)
	_result_dot.position = Vector2(-8, -10)
	row.get_node("Missions").add_child(_result_dot)
	box.add_child(row)
	_extras = ResultExtras.new(self)
	$GameOver.add_child(_extras)
	shop = ShopScreen.new(self)
	shop.back.connect(go_back)
	add_child(shop)
	board = MissionBoard.new(self)
	board.back.connect(go_back)
	add_child(board)
	for slots: BoosterSlots in [start_menu.boosters, result_slots]:
		slots.toggled_on.connect(func(_kind: String, _on: bool) -> void:
			play_ui("booster_on")
			refresh_menus())


## 화면 바꾸기: 보이는 것, World 입력, 버튼 자리(touch_blockers)를 함께 맞춘다
func show_screen(next: String) -> void:
	var was := screen
	screen = next
	var menu := next in ["shop", "missions"]
	_world.input_off = menu  # 상점·미션에서는 판이 입력을 받지 않음 (결과 카드 뒤 판이 다시 시작되지 않게)
	for node: String in HUD:
		get_node(node).visible = next in ["run", "result"]
	$GameOver.visible = next == "result"
	$VersionLabel.visible = not menu
	if next == "start" and was != "start":
		start_menu.slide_in()
	elif next != "start" and start_menu.visible and was == "start" and next == "run":
		start_menu.slide_out()
	elif next != "start":
		start_menu.visible = false
	# 버튼 자리: 지난 화면 것을 빼고 이 화면 것을 넣는다 (다른 곳이 넣은 자리는 그대로)
	for control in _blockers:
		_world.touch_blockers.erase(control)
	_blockers.clear()
	if next == "start":
		_blockers.append_array(start_menu.blockers())
	if next == "result":
		_blockers.append_array([$GameOver/Card/Box/Retry, $GameOver/Card/Box/Row])
	_world.touch_blockers.append_array(_blockers)
	if has_node("DevPanel"):  # 임시 시험 패널 (배포 전 제거): 상점·미션 화면과 겹치지 않게 숨김
		get_node("DevPanel").visible = not menu
	refresh_menus()


## [시작]·[다시 하기]·빈 곳 누름: 판 시작 (부스터는 이때 줄어듦)
func begin_run() -> void:
	match screen:
		"start":
			play_ui("page")
			_world.restart(_world.prepared_seed())  # 시작 화면과 같은 옥상
		"result":
			_world.restart()


func open_shop(tab: String = "upgrades") -> void:
	if screen not in ["start", "result"]:
		return
	_back_to = screen
	shop.tab = tab
	shop.selected = "dash" if tab == "upgrades" else "dash_start"
	play_ui("page")
	show_screen("shop")
	shop.open()


func open_missions() -> void:
	if screen not in ["start", "result"]:
		return
	_back_to = screen
	Missions.start_run(save, clock.now())  # 날이 바뀌었으면 새로 뽑음 (PLAN 7번)
	play_ui("page")
	show_screen("missions")
	board.open()


## 상점·미션의 [뒤로]: 온 곳(시작 화면 또는 결과 카드)으로
func go_back() -> void:
	if screen not in ["shop", "missions"]:
		return  # 닫히는 중에 한 번 더 눌림
	play_ui("page")
	(shop if screen == "shop" else board).close()
	show_screen(_back_to)


## 사거나 받은 뒤 다른 화면의 숫자·부스터 칸·미션 표시를 맞춘다
func refresh_menus() -> void:
	if start_menu.visible:
		start_menu.refresh()
	result_slots.refresh()
	UiKit.badge_text(_result_dot, Missions.pending(save.data))


func play_ui(sound: String) -> void:
	_ui_sfx[sound].play()
