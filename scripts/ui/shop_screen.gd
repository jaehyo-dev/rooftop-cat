class_name ShopScreen
extends MenuScreen
## 상점 (v0.7.0 2c, 시안 05 "샵 B"): 위에 [강화] [부스터] 탭, 왼쪽 목록(강화 6개 + 단계 점 10개 / 부스터 3개 + 가진 개수),
## 오른쪽 설명 패널(큰 아이콘, 설명, "지금 → 다음", 가격·사기 버튼). 돈이 모자라면 버튼이 흐리고 누르면 "뿌뿌" + 흔들림.
## 사고팔기 판단은 SaveData.buy_upgrade·buy_booster가 한다 (화면은 부르기만).
## 연출: 사면 새 단계 점이 톡 채워지고 "지금" 값이 바뀌며 튐.

const UPGRADE_INFO := {
	"dash": ["질주 시간", "츄르를 먹고 무적으로 달리는 시간이 길어져요.", "snack"],
	"yarn": ["털실 자석", "털실이 생선을 끌어오는 시간과 범위가 늘어요.", "yarn"],
	"combo": ["콤보 가속", "콤보 배수가 더 적은 생선으로 올라가요.", "combo"],
	"gold": ["황금 생선", "황금 생선 한 마리 점수가 올라가요.", "gold"],
	"cookie": ["하트 쿠키", "하트를 채워 주는 쿠키가 더 자주 나와요.", "cookie_clock"],
	"fish": ["생선 점수", "생선 한 마리 점수가 올라요.\n3, 6, 10단계에 생선이 바뀌어요!", "fish"],
}
const BOOSTER_INFO := {
	"dash_start": ["질주로 출발", "시작하자마자 질주로 앞부분을 슝 지나가요.", "dash_start"],
	"bell_start": ["방울 달고 시작", "처음부터 한 번 막아 주는 방울을 달고 달려요.", "bell_start"],
	"fish_bonus": ["생선 +50%", "이번 판에 버는 생선이 1.5배! 멀리 갈 자신 있을 때.", "fish_bonus"],
}
const WORLD := preload("res://scripts/world_view.gd")  # 생선 그림 4단계 (FISH_LOOKS)
const ROW_H := 90.0
const DESC_W := 470.0  # 설명 글 폭 (패널 손그림 테두리 안)
const DOT_R := 9.0
const DOT_ON := Color("#f0a04b")         # 채운 단계 점
const DOT_ON_PICKED := Color("#9a4a1c")  # 고른 줄(주황 버튼) 위에서는 주황 점이 안 보여 진하게 (2c-juice 눈 검수)

var tab := "upgrades"
var selected := "dash"
var _tabs := {}
var _list := VBoxContainer.new()
var _rows := {}
var _dots := {}  # 강화 종류 → 단계 점 Control
var _art := UiKit.icon(null, 180)
var _title := UiKit.label("", 48, UiKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER)
var _desc := UiKit.label("", 30, UiKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER)
var _now := UiKit.label("", 38, UiKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER)
var _next := UiKit.label("", 38, Color("#4b7a36"), HORIZONTAL_ALIGNMENT_CENTER)  # 크림 위에서 읽히게 막대 초록보다 진하게
var _buy := UiKit.button("", "orange", UiKit.ICONS.fish, 46)
var _pop_dot := {"kind": "", "t": 99.0}  # 방금 채운 단계 점 (톡 튀기)
var _hold := {}    # 생선이 날아오는 동안 단계 점을 산 전 단계로 그림 (종류 → 단계)
var _counts := {}  # 부스터 종류 → 가진 개수 글자


func _init(main_node: Node) -> void:
	super(main_node, "Shop")
	# 탭
	for pair in [["upgrades", "강화", "star"], ["boosters", "부스터", "dash_start"]]:
		var b := UiKit.button(pair[1], "cream", UiKit.ICONS[pair[2]], 40)
		b.name = "Tab_" + pair[0]
		b.position = Vector2(140 + 270 * _tabs.size(), 14)
		b.size = Vector2(250, UiKit.MIN_BUTTON)
		b.pressed.connect(show_tab.bind(pair[0]))
		box.add_child(b)
		_tabs[pair[0]] = b
	# 왼쪽 목록
	_list.name = "List"
	_list.position = Vector2(24, 122)
	_list.size = Vector2(640, 6 * ROW_H + 5 * 6)
	_list.add_theme_constant_override("separation", 6)
	box.add_child(_list)
	# 오른쪽 설명 패널
	var panel := UiKit.paper("panel")
	panel.name = "Detail"
	panel.position = Vector2(688, 116)
	panel.size = Vector2(568, 588)
	box.add_child(panel)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 30)
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_art)
	col.add_child(_title)
	_desc.custom_minimum_size = Vector2(DESC_W, 80)
	col.add_child(_desc)
	var change := HBoxContainer.new()
	change.alignment = BoxContainer.ALIGNMENT_CENTER
	change.add_theme_constant_override("separation", 12)
	var arrow := UiKit.icon(UiKit.ICONS.back, 52)  # 글꼴에 "→"가 없어 색연필 화살표 그림을 뒤집어 씀
	arrow.flip_h = true
	for c: Control in [_now, arrow, _next]:
		change.add_child(c)
	_now.custom_minimum_size.x = 190
	_next.custom_minimum_size.x = 190
	col.add_child(change)
	_buy.name = "Buy"
	_buy.custom_minimum_size = Vector2(0, 104)
	_buy.add_theme_constant_override("icon_max_width", 76)
	_buy.pressed.connect(buy)
	col.add_child(_buy)


func refresh() -> void:
	for t: String in _tabs:
		var on := t == tab
		_tabs[t].add_theme_stylebox_override("normal", UiKit._box("orange" if on else "cream"))
	_fill_list()
	_show_detail()


func show_tab(t: String) -> void:
	finish_fx()
	if t != tab:
		main.play_ui("page")
	tab = t
	selected = "dash" if t == "upgrades" else "dash_start"
	refresh()


func _info() -> Dictionary:
	return UPGRADE_INFO if tab == "upgrades" else BOOSTER_INFO


func _fill_list() -> void:
	for child in _list.get_children():
		child.queue_free()
		_list.remove_child(child)
	_rows.clear()
	_dots.clear()
	_counts.clear()
	for kind: String in _info():
		var b := UiKit.button("", "orange" if kind == selected else "cream")
		b.name = kind
		b.custom_minimum_size = Vector2(0, ROW_H)
		b.pressed.connect(func() -> void:
			finish_fx()
			if selected != kind:
				main.play_ui("booster_on")
			selected = kind
			refresh())
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		row.offset_left = 26 + (14 if kind == selected else 0)  # 고른 줄은 튀어나온 듯 오른쪽으로
		row.offset_right = -26  # 오른쪽 손그림 테두리 안
		row.add_theme_constant_override("separation", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(UiKit.icon(_icon(kind), 66))
		var name_label := UiKit.label(_info()[kind][0], 36)
		name_label.custom_minimum_size.x = 210
		row.add_child(name_label)
		if tab == "upgrades":
			var dots := Control.new()
			dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dots.draw.connect(_draw_dots.bind(dots, kind))
			row.add_child(dots)
			_dots[kind] = dots
		else:
			var owned := UiKit.label("x%d" % main.save.booster_count(kind), 36, UiKit.BROWN, HORIZONTAL_ALIGNMENT_RIGHT)  # 가진 개수
			owned.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			owned.custom_minimum_size.x = 60
			row.add_child(owned)
			_counts[kind] = owned
		b.add_child(row)
		_list.add_child(b)
		_rows[kind] = b


func _icon(kind: String) -> Texture2D:
	if kind == "fish":
		return WORLD.FISH_LOOKS[_fish_look(main.save.upgrade_level("fish"))]
	return UiKit.ICONS[_info()[kind][2]]


static func _fish_look(level: int) -> int:
	return Perks.new({"fish": level}).fish_look()


## 단계 점 10개 (채운 점 = 산 단계). 방금 산 점은 커졌다 돌아옴
func _draw_dots(dots: Control, kind: String) -> void:
	var lv: int = _hold.get(kind, main.save.upgrade_level(kind))
	var y := dots.size.y * 0.5
	for i in Balance.UPGRADE_MAX:
		var at := dot_at(dots, i)
		var r := DOT_R
		if _pop_dot.kind == kind and i == lv - 1:
			r *= 1.0 + 0.8 * maxf(0.0, 1.0 - _pop_dot.t / 0.35)
		dots.draw_circle(at, r + 2.0, UiKit.BROWN)
		dots.draw_circle(at, r, (DOT_ON_PICKED if kind == selected else DOT_ON) if i < lv else UiKit.CREAM)


func _process(delta: float) -> void:
	if _pop_dot.t < 1.0:
		_pop_dot.t += delta
		if _dots.has(_pop_dot.kind):
			_dots[_pop_dot.kind].queue_redraw()


## 단계 점 i번 자리 (점 Control 좌표)
static func dot_at(dots: Control, i: int) -> Vector2:
	return Vector2(DOT_R + 4.0 + i * (DOT_R * 2.0 + 6.0), dots.size.y * 0.5)


## 오른쪽 패널: 고른 것의 설명, 지금 → 다음, 사기 버튼 (최대·돈 부족 표시)
func _show_detail() -> void:
	var info: Array = _info()[selected]
	_art.texture = _icon(selected)
	_title.text = info[0]
	_desc.text = UiKit.wrap(info[1], 30, DESC_W)
	var price: int
	if tab == "upgrades":
		var lv: int = main.save.upgrade_level(selected)
		price = main.save.upgrade_price(selected)
		_now.text = value_text(selected, lv)
		_next.text = value_text(selected, lv + 1) if price >= 0 else "최대!"
		_title.text = "%s  %d단계" % [info[0], lv]
	else:
		var n: int = main.save.booster_count(selected)
		price = Balance.BOOSTER_PRICES[selected] if n < Balance.BOOSTER_MAX else -1
		_now.text = "%d개" % n
		_next.text = "%d개" % (n + 1) if price >= 0 else "최대!"
	if price < 0:
		_buy.text = "최대 단계"
		_buy.icon = null
		_buy.disabled = true
	else:
		_buy.text = UiKit.comma(price)
		_buy.icon = UiKit.ICONS.fish
		_buy.disabled = false
		_buy.modulate = Color(1, 1, 1, 1.0 if price <= main.save.fish() else 0.6)  # 모자라면 흐리게 (눌러 보면 뿌뿌)


## 단계 값 글자 (지금·다음)
static func value_text(kind: String, level: int) -> String:
	var v := Perks.new({kind: level}).value(kind)
	match kind:
		"dash":
			return "%.1f초" % v
		"yarn":
			return "+%d%%" % roundi((v - 1.0) * 100.0)
		"combo":
			return "%d개마다" % roundi(v)
		"cookie":
			return "%d초마다" % roundi(v)
	return "%d점" % roundi(v)


## 사기 (돈이 모자라면 뿌뿌 + 버튼 흔들림, 최대면 아무것도 안 함). 연출 (2c 피드백):
## 강화 = 버튼 찌그러짐 → 지갑 생선 3마리가 새 단계 점으로 날아감 → 점이 톡 채워지며 별 + "지금" 값 튐 (소리는 단계마다 한 음씩 높게, 10단계는 팡파르·별 더)
## 부스터 = 부스터 그림이 목록의 개수 칸으로 쏙 → "+1" + 개수 튐
func buy() -> void:
	finish_fx()
	var kind := selected
	var upgrade := tab == "upgrades"
	var result: String = main.save.buy_upgrade(kind) if upgrade else main.save.buy_booster(kind)
	if result == "money":
		main.play_ui("no_money")
		_shake(_buy)
		return
	if result != "":
		return
	main.play_ui("booster_on")
	track(UiKit.squash(_buy))
	set_wallet(main.save.fish())
	UiKit.pop(wallet, 0.08)
	if upgrade:
		var lv: int = main.save.upgrade_level(kind)
		_hold[kind] = lv - 1
		var spot := to_box(_dots[kind], dot_at(_dots[kind], lv - 1))
		track(UiKit.fly(box, wallet_spot(), spot, 3, func(i: int) -> void:
			if i == 2:
				_upgrade_landed(kind, lv, spot), UiKit.ICONS.fish, 40.0, 0.36))
	else:
		var owned: Label = _counts[kind]
		var spot := to_box(owned, owned.size * 0.5)
		track(UiKit.fly(box, to_box(_art, _art.size * 0.5), spot, 1, func(_i: int) -> void: _booster_landed(kind, spot),
				_icon(kind), 96.0, 0.4))


func _upgrade_landed(kind: String, level: int, spot: Vector2) -> void:
	_hold.erase(kind)
	_pop_dot = {"kind": kind, "t": 0.0}
	refresh()
	var top := level >= Balance.UPGRADE_MAX
	main.play_ui("fanfare" if top else "buy", 1.0 if top else pow(2.0, (level - 1) / 12.0))  # 한 단계 = 반음
	track(UiKit.burst(box, spot, 14 if top else 5, "star", 150.0 if top else 56.0))
	if top:
		track(UiKit.burst(box, to_box(_art, _art.size * 0.5), 12, "star", 200.0))
	UiKit.pop(_now, 0.45 if top else 0.3)
	UiKit.pop(_art, 0.3 if top else 0.15)


func _booster_landed(kind: String, spot: Vector2) -> void:
	refresh()
	main.play_ui("pop_in")
	track(UiKit.float_text(box, spot + Vector2(0, -36), "+1"))
	if _counts.has(kind):
		UiKit.pop(_counts[kind], 0.5)
	UiKit.pop(_now, 0.3)


func _shake(control: Control) -> void:
	var x := control.position.x
	var tween := control.create_tween()
	for d in [-10.0, 10.0, -6.0, 6.0, 0.0]:
		tween.tween_property(control, "position:x", x + d, 0.04)
