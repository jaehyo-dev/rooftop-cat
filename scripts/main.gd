extends Control
## 게임 화면(World), 거리·최고 점수·생선 수·종이상자, 오른쪽 위 점수·콤보, 결과 화면, 버전 표시.
## v0.7.0 2c 화면 흐름 (review/v0.7.0/PLAN.md 1번): 시작 화면 → 판 → 결과 카드, 시작 화면·결과 카드에서 상점·미션, [뒤로] = 온 곳.
## 화면마다 scripts/ui/의 Control이 그리고, 여기서는 어느 화면인지만 바꾼다 (판 중에는 상점·미션에 못 감).
## 글꼴은 주아 Jua(main.tscn 테마 = scripts/ui/menu_font.tres, 한글 2,367자). 갈색 글자 + 얇은 밝은 테두리.
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
## 미션 날짜 (테스트가 시각을 고정함)
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
var _hint := UiKit.label("", UiKit.SUB, UiKit.SUB_BROWN, HORIZONTAL_ALIGNMENT_CENTER)  # 안내는 갈색 (빨강은 새 기록에만)
var _best_row := UiKit.label("", UiKit.SUB, UiKit.SUB_BROWN)  # 결과 카드 "최고 48,210" (가진 생선과 한 줄)
var _result_dot := UiKit.badge()
var _shop_seen: Array = []  # 상점을 마지막으로 열었을 때 살 수 있던 강화 (새로 살 수 있게 되면 [상점]에 점)

## 메뉴 소리 (tools/make_sfx.py UI_SOUNDS). 생선 소리(-17dB)보다 튀지 않게 같은 크기로
const UI_SOUNDS := ["buy", "booster_buy", "booster_on", "no_money", "claim", "rank_up", "swap", "page", "whoosh", "thud", "fanfare", "pop_in"]
const UI_VOLUME_DB := -17.0
## 이 소리만 더 크게 (dB, 2c-polish 사용자 "도장 소리가 너무 작다"): 쿵은 다른 효과음보다 한 단계 위, 휙은 쿵에 맞춰 조금
const UI_GAIN_DB := {"thud": 5.0, "whoosh": 3.0}
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
		player.volume_db = UI_VOLUME_DB + UI_GAIN_DB.get(sound, 0.0)
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
	_attach_qa()
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


func _process(delta: float) -> void:
	$DistanceLabel.text = "%d m" % _world.sim.distance()
	$FishLabel.text = str(_world.sim.fish)
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
	_hint.text = "점수 계산이 바뀌어 최고 점수를 새로 시작해요" if save.score_reset else ("메인 화면의 상점에서 강화를 살 수 있어요" if save.data.stats.runs == 1 else "")
	_hint.visible = _hint.text != ""  # 안내가 없으면 줄을 차지하지 않게
	save.score_reset = false
	_extras.clear()
	_count_result(0.0)
	show_screen("result")
	$BestLabel.text = "BEST %s" % UiKit.comma(_best)


## 결과 숫자를 하나씩 차오르게 쓴다. 다 차면 새 기록 축하 (별·소리·글자 통통)
func _count_result(delta: float) -> void:
	var was_done := Juice.count_done(_result.values, _result.t)
	_result.t += delta
	var shown := Juice.count_up(_result.values, _result.t)
	var done := Juice.count_done(_result.values, _result.t)
	var last := ""
	if done:
		last = "새 기록!" if _result.new_best else ""
	$GameOver/Card/Box/Score.text = UiKit.comma(shown[3])  # 다른 화면처럼 천 단위 쉼표 (2c-fix). "점수"는 위 작은 이름표
	# 기록 표: 이름은 왼쪽, 값은 오른쪽 (2c-polish 아트 검토: 가운데 맞춤이라 들쭉날쭉)
	for pair in [["Distance", "%sm" % UiKit.comma(shown[0])], ["Fish", UiKit.comma(shown[1])], ["Combo", UiKit.comma(shown[2])]]:
		(get_node("GameOver/Card/Box/Stats/%s/Value" % pair[0]) as Label).text = pair[1]
	$GameOver/Card/Box/Stats/Fish/Bonus.visible = _result.bonus
	$GameOver/Card/Box/Best.text = last
	$GameOver/Card/Box/Best.visible = _result.new_best  # 새 기록일 때만 줄을 차지 (차오르는 동안은 빈 줄로 자리를 잡음)
	_best_row.text = "최고 %s" % UiKit.comma(_best)
	$GameOver/Card/Box/Best.add_theme_color_override("font_color", UiKit.RED if done and _result.new_best else UiKit.SUB_BROWN)  # 빨강은 새 기록에만
	$GameOver/Card/Box/Best.add_theme_font_size_override("font_size", UiKit.BODY if _result.new_best else UiKit.SUB)  # 새 기록은 본문 크기 빨강
	# 다 차면 실제 지갑 (미션 받기·사기로 바뀐 값까지)
	$GameOver/Card/Box/Wallet/Total.text = "가진 생선 %s" % UiKit.comma(save.fish() if done else _result.wallet + ceili(shown[1] * (Balance.FISH_BONUS_MULT if _result.bonus else 1.0)))
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
	$BestLabel.text = "BEST %s" % UiKit.comma(_best)


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
	box.custom_minimum_size.x = 520
	# 결과 카드도 메뉴와 같은 판 (UI 스타일 표), 글자 위계: 점수(큰 숫자) → 기록(본문) → 모은 생선(보조)
	var card_box := UiKit.plate("panel")
	card_box.content_margin_left = UiKit.PAD * 3.0
	card_box.content_margin_right = UiKit.PAD * 3.0
	card_box.content_margin_top = UiKit.PAD * 3.0  # 위 테두리에 걸친 리본 아래
	card_box.content_margin_bottom = UiKit.PAD * 2.0 + UiKit.SHADOW_Y
	$GameOver/Card.add_theme_stylebox_override("panel", card_box)
	box.add_theme_constant_override("separation", int(UiKit.GAP * 0.5))
	$GameOver.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # 줄여 그린 아이콘이 계단지지 않게
	$GameOver.color = UiKit.DIM_BACK
	for pair in [["Score", UiKit.NUM_BIG, UiKit.BROWN], ["Best", UiKit.TITLE, UiKit.RED]]:
		var l: Label = box.get_node(pair[0])
		l.add_theme_font_override("font", UiKit.FONT)  # 메뉴 글꼴 (글자 사이를 다른 글과 같게)
		l.add_theme_font_size_override("font_size", pair[1])
		l.add_theme_color_override("font_color", pair[2])
		l.add_theme_constant_override("outline_size", 0)
	var ribbon := Control.new()  # 카드 제목 리본 "이번 판" (다른 화면처럼 제목이 리본 위에)
	ribbon.name = "Ribbon"
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.draw.connect(func() -> void: UiKit.draw_ribbon(ribbon, Rect2(ribbon.size.x * 0.5 - 140, 0, 280, 56)))
	var ribbon_text := UiKit.on_orange(UiKit.label("이번 판 점수", UiKit.TITLE, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	UiKit.fit(ribbon_text, 280 - UiKit.PAD * 2.0, UiKit.TITLE)
	ribbon_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	ribbon_text.offset_bottom = -8
	ribbon.add_child(ribbon_text)
	$GameOver.add_child(ribbon)  # 카드 위 테두리에 걸침 (카드 높이를 쓰지 않게 카드 밖에 두고 자리만 맞춤)
	var card: Control = $GameOver/Card
	var place := func() -> void: ribbon.position = (card.position + Vector2(card.size.x * 0.5 - 200, -36)).round()
	card.item_rect_changed.connect(place)
	ribbon.size = Vector2(400, 64)
	var line_under := ColorRect.new()  # 기록 표 아래 얇은 구분선
	line_under.name = "Divider"
	line_under.color = UiKit.TROUGH
	line_under.custom_minimum_size = Vector2(0, UiKit.LINE * 0.5)
	line_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 기록 표 (이름 왼쪽, 값 오른쪽): 예전 여러 줄 글자 Stats를 표로 바꿈
	box.get_node("Stats").free()
	var stats := VBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 0)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair in [["Distance", "거리"], ["Fish", "먹은 생선"], ["Combo", "최고 콤보"]]:
		var line := HBoxContainer.new()
		line.name = pair[0]
		line.add_theme_constant_override("separation", int(UiKit.GAP))
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key := UiKit.label(pair[1], UiKit.BODY, UiKit.SUB_BROWN)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(key)
		if pair[0] == "Fish":  # 생선 +50% 부스터: 값 옆 작은 초록 알약
			var bonus := UiKit.label("+50%", UiKit.SUB, UiKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER)
			bonus.name = "Bonus"
			line.add_child(bonus)
		var value := UiKit.label("0", UiKit.BODY, UiKit.BROWN, HORIZONTAL_ALIGNMENT_RIGHT)
		value.name = "Value"
		line.add_child(value)
		stats.add_child(line)
	box.add_child(stats)
	box.move_child(stats, box.get_node("Score").get_index() + 1)
	box.add_child(line_under)
	box.move_child(line_under, stats.get_index() + 1)
	# 가진 생선: 생선 그림 + 숫자 (이번 판 "먹은 생선"과 헷갈리지 않게 이름도 바꿈)
	var total: Label = box.get_node("Total")
	box.remove_child(total)
	var wallet_row := HBoxContainer.new()
	wallet_row.name = "Wallet"
	wallet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wallet_row.add_theme_constant_override("separation", int(UiKit.GAP))
	wallet_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 최고 점수와 가진 생선을 한 줄로 (아이콘 + 숫자), 줄 수를 줄여 위계를 또렷하게
	wallet_row.add_child(UiKit.icon(UiKit.ICONS.star, 36))
	_best_row.name = "BestRow"
	wallet_row.add_child(_best_row)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = UiKit.PAD * 2.0
	wallet_row.add_child(spacer)
	wallet_row.add_child(UiKit.icon(UiKit.ICONS.fish, 36))
	total.add_theme_font_override("font", UiKit.FONT)
	total.add_theme_font_size_override("font_size", UiKit.SUB)
	total.add_theme_color_override("font_color", UiKit.SUB_BROWN)
	total.add_theme_constant_override("outline_size", 0)
	wallet_row.add_child(total)
	box.add_child(wallet_row)
	box.move_child(wallet_row, box.get_node("Best").get_index() + 1)
	box.get_node("Retry").free()
	var retry := UiKit.button("다시 하기", "orange", null, UiKit.TITLE)
	retry.name = "Retry"
	retry.hot = true
	box.add_child(retry)
	retry.custom_minimum_size = Vector2(320, 96)
	retry.pressed.connect(begin_run)
	_hint.name = "Hint"
	box.add_child(_hint)
	box.move_child(_hint, retry.get_index())
	# 부스터 칸은 [다시 하기] 위, 아래 줄은 큰 [다시 하기] + [메인 화면] (2c 피드백: 상점·미션은 메인 화면에서 감)
	result_slots = BoosterSlots.new(self)
	result_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	result_slots.want_shop.connect(open_shop.bind("boosters"))
	box.add_child(result_slots)
	box.move_child(result_slots, retry.get_index())
	var slots_head := UiKit.label("다음 판 부스터", UiKit.SUB, UiKit.SUB_BROWN, HORIZONTAL_ALIGNMENT_CENTER)
	slots_head.name = "SlotsHead"
	box.add_child(slots_head)
	box.move_child(slots_head, result_slots.get_index())
	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(UiKit.PAD))
	box.remove_child(retry)
	row.add_child(retry)
	var home := UiKit.button("메인 화면", "cream")
	home.name = "Home"
	home.custom_minimum_size = Vector2(200, 96)
	home.pressed.connect(go_home)
	row.add_child(home)
	_result_dot.position = Vector2(home.custom_minimum_size.x - _result_dot.size.x * 0.75, -_result_dot.size.y * 0.3).round()  # 받을 미션 보상 수: 오른쪽 위 (왼쪽 위는 부스터 칸에 닿음)
	home.add_child(_result_dot)
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
		get_node(node).visible = next == "run"  # 결과 카드 뒤에서는 숨김 (카드에 같은 값이 있음, 2c 피드백)
	$GameOver.visible = next == "result"
	if next == "result" and was != "result":
		UiKit.enter([$GameOver/Card], Vector2(0, 40))  # 카드가 아래에서 톡 올라옴
	$VersionLabel.visible = not menu and next != "result"  # 결과 카드에서는 축하 별과 겹치지 않게 숨김
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
		_blockers.append_array([$GameOver/Card/Box/Row, result_slots])
	_world.touch_blockers.append_array(_blockers)
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
	_shop_seen = ShopScreen.affordable(save)
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


## 결과 카드 [메인 화면]: 새 옥상을 만들어 멈추고 시작 화면으로
func go_home() -> void:
	if screen != "result":
		return
	play_ui("page")
	_world.prepare()
	show_screen("start")


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


## [상점]의 빨간 점: 상점을 마지막으로 연 뒤에 새로 살 수 있게 된 강화가 있음
func shop_has_new() -> bool:
	return ShopScreen.affordable(save).any(func(kind: String) -> bool: return kind not in _shop_seen)


## pitch: 빠르기 (강화 사기는 단계마다 한 음씩 높게)
func play_ui(sound: String, pitch: float = 1.0) -> void:
	_ui_sfx[sound].pitch_scale = pitch
	_ui_sfx[sound].play()


## 눈 검수 캡처: 검수용 웹 빌드(review/v0.7.0/2c-juice/export_qa.sh, tools/를 넣어 내보냄) 주소에 ?qa= 가 있으면
## tools/qa_web.gd를 붙인다. 보통 빌드에는 tools/가 없어 아무것도 안 함. 캡처가 main을 다시 만들어도 한 번만
static var _qa_attached := false
func _attach_qa() -> void:
	const QA := "res://tools/qa_web.gd"
	if _qa_attached or not OS.has_feature("web") or not ResourceLoader.exists(QA):
		return
	if "qa=" in str(JavaScriptBridge.eval("location.search")):
		_qa_attached = true
		get_tree().root.add_child.call_deferred(load(QA).new())
