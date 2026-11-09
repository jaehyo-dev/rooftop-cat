extends Control
## 시작 화면: 게임 화면(World), 거리·최고 점수·생선 수·종이상자, 오른쪽 위 점수·콤보, 결과 화면, 버전 표시.
## 글꼴은 Gaegu Bold(main.tscn 테마, 한글 포함). 갈색 글자 + 얇은 밝은 테두리.
## 손맛(2b): 콤보 배수가 오르면 숫자가 톡 튀고, 생선 점수가 오르면 점수가 살짝 흔들린다. 결과 숫자는 하나씩 차오르고 새 기록이면 별이 내린다.
## 로컬 플레이 빌드(github.io가 아닌 웹 주소)에서만 왼쪽 아래에 부딪힘 손맛 고르기 버튼(약·중·강)이 보인다.

## 최고 기록·생선 저장 위치 (테스트에서 바꿔 실제 기록을 건드리지 않는다)
var record_path := BestRecord.DEFAULT_PATH

## 배경 음악 "찹쌀떡 산책" (tools/make_music.py로 합성한 루프)
const MUSIC := preload("res://assets/audio/mochi_walk.ogg")
const MUSIC_VOLUME_DB := -5.0  # 곡 자체가 -21.4 LUFS라 -26.4 (효과음 world_view.gd SFX_VOLUME_DB와 맞춤)

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

@onready var _world: Node2D = $World


func _ready() -> void:
	# 버전은 project.godot 한 곳에서 읽는다.
	$VersionLabel.text = "v" + str(ProjectSettings.get_setting("application/config/version"))
	_best = BestRecord.load_best_score(record_path)
	_world.game_over.connect(_on_game_over)
	_world.restarted.connect(_on_restarted)
	_on_restarted()
	# 배경 음악: 끝나면 처음부터 반복. 웹에서는 첫 터치·클릭 뒤부터 소리가 난다 (브라우저 규칙)
	var music_stream: AudioStreamOggVorbis = MUSIC.duplicate()
	music_stream.loop = true
	_music.name = "Music"
	_music.stream = music_stream
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	_music.play()
	_celebrate.name = "Celebrate"
	_celebrate.draw.connect(_draw_celebrate)
	$GameOver.add_child(_celebrate)
	if _local_build():
		_add_tune_panel()


func _process(delta: float) -> void:
	$DistanceLabel.text = "%d m" % _world.sim.distance()
	$FishLabel.text = str(_world.sim.fish)
	$BoxIcon.visible = _world.sim.has_box
	$ScoreLabel.text = str(_world.sim.score())
	var combo: FishCombo = _world.sim.combo
	$ComboLabel.text = "콤보 %d  x%d" % [combo.count, combo.multiplier()] if combo.count > 0 else ""
	_pop_hud(combo, delta)
	if $GameOver.visible:
		$GameOver/Retry.modulate.a = 1.0 if _world.can_restart() else 0.5  # 누를 수 있게 되면 진해진다
		_count_result(delta)
	# 단계마다 곡이 조금씩 빨라진다
	var pitch := SpeedCurve.music_pitch(_world.sim.stage)
	_pitch_wait -= delta
	if _pitch_wait <= 0.0 or not is_equal_approx(_music.pitch_scale, pitch):
		_music.pitch_scale = pitch
		_pitch_wait = MUSIC_PITCH_RESEND
		pitch_sends += 1


func _on_game_over(meters: int) -> void:
	BestRecord.submit(meters, record_path)
	var sim: RunnerSim = _world.sim
	var score: int = sim.score()
	var new_best := BestRecord.submit_score(score, record_path)
	_best = maxi(_best, score)
	# shortcut: 게임 끝에만 저장해 판 중간에 창을 닫으면 그 판 생선은 사라짐, 강화 상점(v0.7.0) 때 판 중 저장을 검토
	var total := BestRecord.add_fish(sim.fish, record_path)
	_result = {"values": [meters, sim.fish, sim.combo.best, score], "total": total, "new_best": new_best, "t": 0.0}
	_count_result(0.0)
	$GameOver.visible = true
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
	$GameOver/Label.text = "거리  %d m\n먹은 생선  %d  (모은 생선 %d)\n최고 콤보  %d\n\n점수  %d\n%s" % [
		shown[0], shown[1], _result.total - _result.values[1] + shown[1], shown[2], shown[3], last]
	var label: Label = $GameOver/Label
	label.pivot_offset = label.size * 0.5
	if done and not was_done and _result.new_best:
		_world.play_sfx("perfect")
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


## 로컬 플레이 빌드인지 (tools/play_local.sh로 띄운 웹. 배포 주소 github.io에서는 아님, 데스크톱 실행·테스트도 아님)
func _local_build() -> bool:
	if not OS.has_feature("web"):
		return false
	return not str(JavaScriptBridge.eval("location.hostname", true)).ends_with("github.io")


## 왼쪽 아래 부딪힘 손맛 고르기 (약·중·강). 이 자리의 터치는 점프로 치지 않는다
func _add_tune_panel() -> void:
	var panel := HBoxContainer.new()
	panel.name = "TunePanel"
	var title := Label.new()
	title.text = "부딪힘: " + _world.hit_feel
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)
	var group := ButtonGroup.new()
	for name: String in Balance.HIT_FEELS:
		var button := Button.new()
		button.text = name
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = name == _world.hit_feel
		button.focus_mode = Control.FOCUS_NONE  # 스페이스바 점프가 버튼을 누르지 않게
		button.add_theme_font_size_override("font_size", 28)
		button.custom_minimum_size = Vector2(56.0, 48.0)
		button.pressed.connect(func() -> void:
			_world.hit_feel = name
			title.text = "부딪힘: " + name)
		panel.add_child(button)
	# 자리·크기가 정해질 때마다 막을 자리를 고친다 (add_child 안에서 바로 정해지므로 먼저 연결)
	panel.item_rect_changed.connect(func() -> void: _world.input_block = panel.get_global_rect().grow(8.0))
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)


func _on_restarted() -> void:
	_result = {}
	_last_mult = 1
	_last_points = 0
	$GameOver.visible = false
	$BestLabel.text = "BEST %d" % _best
