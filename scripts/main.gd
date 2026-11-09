extends Control
## 시작 화면: 게임 화면(World), 거리·최고 점수·생선 수·종이상자, 오른쪽 위 점수·콤보, 결과 화면, 버전 표시.
## 글꼴은 Gaegu Bold(main.tscn 테마, 한글 포함). 갈색 글자 + 얇은 밝은 테두리.

## 최고 기록·생선 저장 위치 (테스트에서 바꿔 실제 기록을 건드리지 않는다)
var record_path := BestRecord.DEFAULT_PATH

## 배경 음악 "찹쌀떡 산책" (tools/make_music.py로 합성한 루프)
const MUSIC := preload("res://assets/audio/mochi_walk.ogg")
const MUSIC_VOLUME_DB := -5.0  # 곡 자체가 -21.4 LUFS라 -26.4 (효과음 world_view.gd SFX_VOLUME_DB와 맞춤)

## 웹(샘플 재생)은 곡이 한 바퀴 돌거나 멈췄다 이어질 때 새 재생 소스를 만들며 빠르기를 1.0으로 되돌리고 게임에 알려 주지 않는다.
## 그래서 바뀔 때만 넘기지 않고 이 간격(초)마다 다시 넘긴다 (tools/web_music_check.mjs로 실제 브라우저에서 확인)
const MUSIC_PITCH_RESEND := 0.1

var _best := 0
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


func _process(delta: float) -> void:
	$DistanceLabel.text = "%d m" % _world.sim.distance()
	$FishLabel.text = str(_world.sim.fish)
	$BoxIcon.visible = _world.sim.has_box
	$ScoreLabel.text = str(_world.sim.score())
	var combo: FishCombo = _world.sim.combo
	$ComboLabel.text = "콤보 %d  x%d" % [combo.count, combo.multiplier()] if combo.count > 0 else ""
	if $GameOver.visible:
		$GameOver/Retry.modulate.a = 1.0 if _world.can_restart() else 0.5  # 누를 수 있게 되면 진해진다
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
	$GameOver/Label.text = "거리  %d m\n먹은 생선  %d  (모은 생선 %d)\n최고 콤보  %d\n\n점수  %d\n%s" % [
		meters, sim.fish, total, sim.combo.best, score, "새 기록!" if new_best else "최고 점수  %d" % _best]
	$GameOver.visible = true
	$BestLabel.text = "BEST %d" % _best


func _on_restarted() -> void:
	$GameOver.visible = false
	$BestLabel.text = "BEST %d" % _best
