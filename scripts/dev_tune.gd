class_name DevTune
extends HBoxContainer
## 임시, 배포 전 제거 (PLAN 20번): 로컬 플레이 빌드(tools/play_local.sh)에서만 붙는 시험 도구.
## 1) 왼쪽 아래 질주 노을빛 고르기 A·B·C  2) 판 시작 약 3초 뒤, 그 뒤 약 20초마다 앞 옥상 위에 질주 아이템을 놓음.
## 사용자가 노을빛을 고르면 이 파일, main.gd의 붙이는 두 줄, world_view.gd의 input_block을 함께 지운다.

## 이름 → 노을빛 섞는 비율 (world_view.dash_tint. 1.0 = 2b 수정 때 진하기)
const TINTS := {"A": 0.1, "B": 0.33, "C": 0.5}
const FIRST_DASH_AT := 3.0   # 판 시작 뒤 첫 시험 질주 (초)
const DASH_EVERY := 20.0     # 그 뒤 간격 (초)
const DASH_AHEAD := 1.5      # 고양이 앞 몇 초 거리에 놓을지 (화면 안에서 보이게)

var _world: Node2D
var _next_at := FIRST_DASH_AT
var _last_elapsed := 0.0


## 로컬 플레이 빌드인지 (웹이면서 배포 주소 github.io가 아님. 데스크톱 실행·테스트·밸런스 봇은 아님)
static func local_build() -> bool:
	if not OS.has_feature("web"):
		return false
	return not str(JavaScriptBridge.eval("location.hostname", true)).ends_with("github.io")


func _init(world: Node2D) -> void:
	_world = world
	name = "DevTune"
	var title := Label.new()
	title.text = "노을빛"
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)
	var group := ButtonGroup.new()
	for key: String in TINTS:
		var button := Button.new()
		button.text = key
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = is_equal_approx(TINTS[key], world.dash_tint)
		button.focus_mode = Control.FOCUS_NONE  # 스페이스바 점프가 버튼을 누르지 않게
		button.add_theme_font_size_override("font_size", 28)
		button.custom_minimum_size = Vector2(56.0, 48.0)
		button.pressed.connect(func() -> void: _world.dash_tint = TINTS[key])
		add_child(button)
	# 자리·크기가 정해질 때마다 막을 자리를 고친다 (add_child 안에서 바로 정해지므로 먼저 연결)
	item_rect_changed.connect(func() -> void: _world.input_block = get_global_rect().grow(8.0))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)


func _process(_delta: float) -> void:
	var sim: RunnerSim = _world.sim
	if sim.elapsed < _last_elapsed:
		_next_at = FIRST_DASH_AT  # 새 판
	_last_elapsed = sim.elapsed
	if sim.elapsed >= _next_at and not sim.dashing and not sim.game_over and place_dash(sim, DASH_AHEAD):
		_next_at = sim.elapsed + DASH_EVERY


## 고양이 앞 ahead초 거리의 옥상 위에 질주 아이템 하나. 그 자리가 틈이면 놓지 않고 false
static func place_dash(sim: RunnerSim, ahead: float) -> bool:
	var x := sim.x + sim.vx() * ahead
	for roof in sim.roofs:
		if roof.left + 40.0 <= x and x <= roof.right - 40.0:
			sim.items.append({"kind": "dash", "x": x, "y": roof.top + Balance.ITEM_LIFT})
			return true
	return false
