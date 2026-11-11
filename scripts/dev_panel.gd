class_name DevPanel
extends VBoxContainer
## 임시 시험 패널 (v0.7.0 2a, review/v0.7.0/PLAN.md 13번 "임시"): 2c에서 진짜 상점·시작 화면이 생기면 이 파일과 main.gd의 DevPanel.attach 한 줄을 지운다.
## github.io가 아닌 웹 주소(tools/play_local.sh)에서만 왼쪽 아래 "시험" 버튼이 보인다. 바꾼 강화·부스터는 다음 판부터.
## 패널 자리 터치는 World.touch_blockers로 점프·다시 시작이 되지 않는다.

const NAMES := {"dash": "질주", "yarn": "털실", "combo": "콤보", "gold": "황금", "cookie": "쿠키", "fish": "생선점수"}
const BOOSTER_NAMES := {"dash_start": "질주출발", "bell_start": "방울", "fish_bonus": "생선+50%"}
const FONT_SIZE := 20

var _main: Node
var _frame := PanelContainer.new()  # 펼친 내용 (밝은 바탕)
var _body := VBoxContainer.new()
var _status := Label.new()
var _booster_buttons := {}


## 로컬 웹 빌드면 main에 패널을 붙인다
static func attach(main: Node) -> void:
	if not OS.has_feature("web"):
		return
	var host := str(JavaScriptBridge.eval("location.hostname"))
	if host.ends_with("github.io"):
		return
	var panel := DevPanel.new()
	panel._main = main
	main.add_child(panel)


func _ready() -> void:
	name = "DevPanel"
	grow_vertical = Control.GROW_DIRECTION_BEGIN  # 펼치면 위로 자람
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(1, 0.97, 0.9, 0.9)
	paper.set_content_margin_all(8.0)
	_frame.add_theme_stylebox_override("panel", paper)
	_frame.visible = false
	_frame.add_child(_body)
	add_child(_frame)
	add_child(_button("시험", func() -> void: _frame.visible = not _frame.visible))  # 펼친 내용은 버튼 위로
	_status.add_theme_font_size_override("font_size", FONT_SIZE)
	_body.add_child(_status)
	_body.add_child(_button("생선 +10,000", func() -> void: _change("wallet", "fish", 10000)))
	var grid := GridContainer.new()
	grid.columns = 6
	for kind: String in NAMES:
		var label := Label.new()
		label.text = NAMES[kind]
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		grid.add_child(label)
		grid.add_child(_button("-", func() -> void: _change("upgrades", kind, -1)))
		grid.add_child(_button("+", func() -> void: _change("upgrades", kind, 1)))
	_body.add_child(grid)
	var row := HBoxContainer.new()
	for kind: String in BOOSTER_NAMES:
		var button := _button(BOOSTER_NAMES[kind], func() -> void: _toggle_booster(kind))
		button.toggle_mode = true
		_booster_buttons[kind] = button
		row.add_child(button)
	_body.add_child(row)
	_body.add_child(_button("저장 지우기", _wipe))
	_main.get_node("World").touch_blockers.append(self)
	_refresh()


func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE  # 스페이스(점프)가 버튼을 누르지 않게
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.pressed.connect(on_press)
	return button


func _change(section: String, key: String, amount: int) -> void:
	var save: SaveData = _main.save
	save.data[section][key] = SaveData._clean(section, key, int(save.data[section][key]) + amount)
	save.save()
	_refresh()


## 다음 판에 켜기/끄기. 가진 게 없으면 1개 넣어 준다
func _toggle_booster(kind: String) -> void:
	var on: Array = _main.boosters_on
	if on.has(kind):
		on.erase(kind)
	else:
		on.append(kind)
		if _main.save.booster_count(kind) == 0:
			_change("boosters", kind, 1)
	_refresh()


func _wipe() -> void:
	var path: String = _main.save.path
	for file in [path, path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	_main.save = SaveData.open(path)
	_main.set("_best", 0)
	_main.boosters_on.clear()
	_refresh()


func _process(_delta: float) -> void:
	# 판이 시작되면 켠 부스터가 꺼지므로 버튼도 따라간다
	for kind: String in _booster_buttons:
		_booster_buttons[kind].set_pressed_no_signal(_main.boosters_on.has(kind))


func _refresh() -> void:
	var save: SaveData = _main.save
	var parts: Array[String] = []
	for kind: String in NAMES:
		parts.append("%s %d" % [NAMES[kind], save.upgrade_level(kind)])
	var boosts: Array[String] = []
	for kind: String in BOOSTER_NAMES:
		boosts.append("%s %d" % [BOOSTER_NAMES[kind], save.booster_count(kind)])
	_status.text = "생선 %d (다음 판부터)\n%s\n%s" % [save.fish(), "  ".join(parts), "  ".join(boosts)]
