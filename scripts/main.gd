extends Control
## 시작 화면: 게임 화면(World), 거리·최고 기록·생선 수·종이상자 표시, 게임 끝 화면, 버전 표시.
## 글꼴은 Gaegu Bold(main.tscn 테마, 한글 포함). 갈색 글자 + 얇은 밝은 테두리.

## 최고 기록·생선 저장 위치 (테스트에서 바꿔 실제 기록을 건드리지 않는다)
var record_path := BestRecord.DEFAULT_PATH

## 주택가 배경 음악 (tools/make_music.py로 합성한 루프)
const MUSIC := preload("res://assets/audio/neighborhood.ogg")
const MUSIC_VOLUME_DB := -8.0

var _best := 0

@onready var _world: Node2D = $World


func _ready() -> void:
	# 버전은 project.godot 한 곳에서 읽는다.
	$VersionLabel.text = "v" + str(ProjectSettings.get_setting("application/config/version"))
	_best = BestRecord.load_best(record_path)
	_world.game_over.connect(_on_game_over)
	_world.restarted.connect(_on_restarted)
	_on_restarted()
	# 배경 음악: 끝나면 처음부터 반복. 웹에서는 첫 터치·클릭 뒤부터 소리가 난다 (브라우저 규칙)
	var music_stream: AudioStreamOggVorbis = MUSIC.duplicate()
	music_stream.loop = true
	var player := AudioStreamPlayer.new()
	player.name = "Music"
	player.stream = music_stream
	player.volume_db = MUSIC_VOLUME_DB
	add_child(player)
	player.play()


func _process(_delta: float) -> void:
	$DistanceLabel.text = "%d m" % _world.sim.distance()
	$FishLabel.text = str(_world.sim.fish)
	$BoxIcon.visible = _world.sim.has_box


func _on_game_over(meters: int) -> void:
	var new_best := BestRecord.submit(meters, record_path)
	_best = maxi(_best, meters)
	var fish: int = _world.sim.fish
	# shortcut: 게임 끝에만 저장해 판 중간에 창을 닫으면 그 판 생선은 사라짐, 스킨 상점(8단계) 때 판 중 저장을 검토
	var total := BestRecord.add_fish(fish, record_path)
	$GameOver/Label.text = "GAME OVER\n\n%d m\n%s\n\nFISH +%d  (TOTAL %d)\n\nTAP TO RUN AGAIN" % [
		meters, "NEW BEST!" if new_best else "BEST %d m" % _best, fish, total]
	$GameOver.visible = true
	$BestLabel.text = "BEST %d m" % _best


func _on_restarted() -> void:
	$GameOver.visible = false
	$BestLabel.text = "BEST %d m" % _best
