class_name DevPanel
extends VBoxContainer
## 임시 시험 패널 (v0.7.0 2a, review/v0.7.0/PLAN.md 13번 "임시"). **배포 전 제거**: v0.7.0을 main에 올리기 전에 이 파일과 main.gd의 DevPanel.attach 한 줄을 지운다.
## 2c: 사용자가 로컬에서 해 볼 수 있게 남겨 둠. 상점·미션 화면에서는 숨는다(main.show_screen).
## github.io가 아닌 웹 주소(tools/play_local.sh)에서만 왼쪽 아래 "시험" 버튼이 보인다. 바꾼 강화·부스터는 다음 판부터.
## 패널 자리 터치는 World.touch_blockers로 점프·다시 시작이 되지 않는다.

const NAMES := {"dash": "질주", "yarn": "털실", "combo": "콤보", "gold": "황금", "cookie": "쿠키", "fish": "생선점수"}
const BOOSTER_NAMES := {"dash_start": "질주출발", "bell_start": "방울", "fish_bonus": "생선+50%"}
const FONT_SIZE := 26  # 휴대폰(화면 0.54배)에서도 누를 수 있게

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
	# 눈 검수 캡처: tools/는 보통 웹 빌드에서 빠지므로 검수용 빌드(review/v0.7.0/2c-juice/export_qa.sh)에서만 있음
	if not _qa and ResourceLoader.exists(QA) and "qa=" in str(JavaScriptBridge.eval("location.search")):
		_qa = true
		main.get_tree().root.add_child.call_deferred(load(QA).new())
	var panel := DevPanel.new()
	panel._main = main
	main.add_child(panel)
	_add_look_toggle(main)


## 임시 (PLAN 18 "임시", 사용자가 고르면 지움): 메뉴 그림 A(깔끔한 종이) ↔ B(거의 평면) 바꾸기. 위 가운데에서 오른쪽으로 조금
## (상점 탭과 지갑 사이 빈 곳), 모든 화면에서 보임.
## 누르면 장면을 다시 불러 모든 메뉴를 새 그림으로 만들고, 상점·미션에 있었으면 다시 연다
static var _reopen := ""
static var _qa := false
const QA := "res://tools/qa_web.gd"


static func _add_look_toggle(main: Node) -> void:
	var b := Button.new()
	b.name = "LookToggle"
	b.text = "UI " + UiKit.look.to_upper()
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 6)
	b.custom_minimum_size = Vector2(110, 50)
	b.grow_horizontal = Control.GROW_DIRECTION_BOTH
	b.offset_left += 200.0
	b.offset_right += 200.0
	b.pressed.connect(func() -> void:
		UiKit.look = "b" if UiKit.look == "a" else "a"
		_reopen = main.screen
		main.get_tree().reload_current_scene())
	main.add_child(b)
	main.get_node("World").touch_blockers.append(b)
	if _reopen == "shop":
		main.open_shop.call_deferred("upgrades")
	elif _reopen == "missions":
		main.open_missions.call_deferred()
	_reopen = ""


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
	var toggle := _button("시험", func() -> void: _frame.visible = not _frame.visible)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # 접었을 때는 작은 버튼 하나만
	add_child(toggle)  # 펼친 내용은 버튼 위로
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
	# 미션 시험 (2b): 날짜 넘기기, 미션 즉시 완료, 등급 경험치
	var mission_row := HBoxContainer.new()
	mission_row.add_child(_button("+1일", func() -> void: _shift_days(1)))
	mission_row.add_child(_button("+7일", func() -> void: _shift_days(7)))
	mission_row.add_child(_button("미션 완료", _complete_missions))
	mission_row.add_child(_button("경험치 +100", func() -> void: _rank_xp(100)))
	_body.add_child(mission_row)
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


## 기기 시간에 날을 더해 미션 날짜를 넘긴다 (저장하지 않는 시험용 시계, 새로 켜면 0)
func _shift_days(days: int) -> void:
	_main.clock.offset_days += days
	Missions.start_run(_main.save, _main.clock.now())
	_refresh()


## 남은 일일·주간 미션을 다 깬다 (보상·등급도 실제처럼 들어옴)
func _complete_missions() -> void:
	var run := {"daily_done": 1 << 30, "full_day": 1 << 30}
	for table: Dictionary in [MissionTable.DAILY, MissionTable.WEEKLY]:
		for id: String in table:
			run[table[id].stat] = 1 << 30
	Missions.count(_main.save.data, run)
	_main.save.save()
	_refresh()


func _rank_xp(xp: int) -> void:
	CatRank.add_xp(_main.save.data, xp)
	_main.save.save()
	_refresh()


func _wipe() -> void:
	var path: String = _main.save.path
	for file in [path, path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	_main.save = SaveData.open(path)
	Missions.start_run(_main.save, _main.clock.now())
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
	var missions: Array[String] = []  # 일일 한 줄, 주간 한 줄
	for list: Array in [save.data.missions.daily, save.data.missions.weekly]:
		missions.append("  ".join(list.map(func(e: Dictionary) -> String: return "%s %d/%d%s" % [e.id, e.progress, e.target, " 깸" if e.done else ""])))
	var rank: Dictionary = save.data.rank
	_status.text = "생선 %d (다음 판부터)\n%s\n%s\n%s  %s %d등급 %d/%d\n%s" % [save.fish(), "  ".join(parts), "  ".join(boosts),
			save.data.missions.day, CatRank.rank_name(rank.level), rank.level, rank.xp, CatRank.next_xp(rank.level), "\n".join(missions)]
