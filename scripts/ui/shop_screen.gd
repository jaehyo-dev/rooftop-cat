class_name ShopScreen
extends MenuScreen
## 상점 (v0.7.0 2c-polish, 디렉터 디자인 PLAN 19번): 위에 [강화] [부스터] 탭, 왼쪽 목록, 오른쪽 설명 판.
## 목록 한 줄: 둥근 받침 위 아이콘 → 이름 + "Lv.3" 알약 → 단계 게이지(알약 홈 안 10칸) → 오른쪽 끝 가격표(못 사면 흐림), 10단계면 주황 "MAX" 알약.
## 부스터 줄: 아이콘 받침 → 이름 + 가진 개수 알약 "x2" → 짧은 설명 → 가격표.
## 고른 줄: 주황 테두리 + 떠오름 + 설명 판 쪽으로 작은 꼬리 (UiButton.picked, STATE_TIME 동안 바뀜).
## 설명 판: 이름 리본, 빛 원 위 큰 아이콘, 설명, "지금"·"다음" 카드 + 화살표, 사기 버튼(살 수 있으면 빛이 지나감, 못 사면 흐림 + 모자란 수).
## 사고팔기 판단은 SaveData.buy_upgrade·buy_booster가 한다 (화면은 부르기만).

const UPGRADE_INFO := {
	"dash": ["질주 시간", "츄르를 먹고 무적으로 달리는 시간이 길어져요.", "snack"],
	"yarn": ["털실 자석", "털실이 생선을 끌어오는 시간과 범위가 늘어요.", "yarn"],
	"combo": ["콤보 가속", "콤보 배수가 더 적은 생선으로 올라가요.", "combo"],
	"gold": ["황금 생선", "황금 생선 한 마리 점수가 올라가요.", "gold"],
	"cookie": ["하트 쿠키", "하트를 채워 주는 쿠키가 더 자주 나와요.", "cookie_clock"],
	"fish": ["생선 점수", "생선 한 마리 점수가 올라요.\n3, 6, 10단계에 생선이 바뀌어요!", "fish"],
}
## 부스터: 이름, 설명, 아이콘, 목록 줄의 짧은 설명
const BOOSTER_INFO := {
	"dash_start": ["질주로 출발", "시작하자마자 질주로 앞부분을 슝 지나가요.", "dash_start", "시작하자마자 질주"],
	"bell_start": ["방울 달고 시작", "처음부터 한 번 막아 주는 방울을 달고 달려요.", "bell_start", "한 번 막아 주는 방울"],
	"fish_bonus": ["생선 +50%", "이번 판에 버는 생선이 1.5배! 멀리 갈 자신 있을 때.", "fish_bonus", "버는 생선 1.5배"],
}
const WORLD := preload("res://scripts/world_view.gd")  # 생선 그림 4단계 (FISH_LOOKS)

# 자리 (상자 좌표, 모두 8의 배수)
const LIST := Vector2(24, 128)
const ROW := Vector2(624, 88)       # 줄 크기 (그림자 포함)
const ROW_GAP := 8.0
const NAME_X := 96.0                # 이름·게이지 왼쪽 (받침 오른쪽)
const TAG := Vector2(160, 56)       # 가격표
const GAUGE := Vector2(336, 26)
const DETAIL := Rect2(672, 128, 584, 568)
const DESC_W := 520.0               # 설명 글 폭
const CARD := Vector2(216, 96)
const BUY := Vector2(400, 96)
const BUY_Y := 456.0
const HINT := "부스터는 시작 화면이나 결과 카드의 부스터 칸을 눌러 켜요. 켠 부스터는 다음 판이 시작될 때 하나씩 써요."
const PULSE_TIME := 1.4             # 다음 칸 깜빡임 한 번 (초)

var tab := "upgrades"
var selected := "dash"
var _tabs := {}
var _list := Control.new()
var _rows := {}
var _gauges := {}  # 강화 종류 → 게이지 Control
var _counts := {}  # 부스터 종류 → 개수 배지 글자 (목록)
var _ribbon := Control.new()
var _title := UiKit.on_orange(UiKit.label("", UiKit.TITLE, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
var _glow := UiKit.glow(256)  # 큰 아이콘 뒤 빛 원 (그림이 아니라 배경)
var _base := UiKit.icon_base(null, UiKit.BASE_L)
var _art: TextureRect = _base.get_meta("art")
var _lv := Control.new()
var _lv_label := UiKit.on_orange(UiKit.label("", UiKit.SUB, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
var _desc := UiKit.label("", UiKit.BODY, UiKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER)
var _cards := Control.new()
var _now_card := UiKit.panel("note")
var _next_card := UiKit.panel("note")
var _max_card := UiKit.panel("note")
var _now_head := UiKit.label("지금", UiKit.SUB, UiKit.SUB_BROWN, HORIZONTAL_ALIGNMENT_CENTER)
var _next_head := UiKit.label("다음", UiKit.SUB, UiKit.SUB_BROWN, HORIZONTAL_ALIGNMENT_CENTER)
var _max_head := UiKit.label("", UiKit.SUB, UiKit.SUB_BROWN, HORIZONTAL_ALIGNMENT_CENTER)
var _now := UiKit.label("", UiKit.NUM, UiKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER)
var _next := UiKit.label("", UiKit.NUM, UiKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER)
var _max_value := UiKit.label("", UiKit.NUM, UiKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER)
var _buy := UiKit.button("", "orange", UiKit.ICONS.fish, UiKit.NUM)
var _max_ribbon := Control.new()
var _max_text := UiKit.label("", UiKit.BODY, UiKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER)
var _lack := UiKit.label("", UiKit.SUB, UiKit.RED, HORIZONTAL_ALIGNMENT_CENTER)
var _detail := UiKit.panel("panel")
var _hint := UiKit.panel("note")  # 부스터 탭: 줄 3개 아래 빈 곳에 쓰는 법 쪽지 (2c-polish 아트 검토: 아래 절반이 비어 미완성처럼 보임)
var _pop_cell := {"kind": "", "t": 99.0}  # 방금 채운 칸 (톡 튀기)
var _hold := {}    # 생선이 날아오는 동안 게이지를 산 전 단계로 그림 (종류 → 단계)
var _pulse := 0.0


func _init(main_node: Node) -> void:
	super(main_node, "Shop")
	# 탭: 알약 두 개 (고른 탭 주황)
	for pair in [["upgrades", "강화", "star"], ["boosters", "부스터", "dash_start"]]:
		var b := UiKit.button(pair[1], "cream", UiKit.ICONS[pair[2]])
		b.name = "Tab_" + pair[0]
		b.plate.radius = UiKit.R_PILL
		b.position = Vector2(EDGE + TOP_H + UiKit.GAP * 3.0 + (216.0 + UiKit.GAP) * _tabs.size(), EDGE)
		b.size = Vector2(216, TOP_H)
		b.pressed.connect(show_tab.bind(pair[0]))
		box.add_child(b)
		_tabs[pair[0]] = b
	_list.name = "List"
	_list.position = LIST
	_list.size = Vector2(ROW.x, 6 * ROW.y + 5 * ROW_GAP)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_list)
	_hint.name = "BoosterHint"
	_hint.position = LIST + Vector2(0, 3 * (ROW.y + ROW_GAP) + UiKit.PAD)
	_hint.size = Vector2(ROW.x, 160)  # 글 세 줄에 맞춤
	var hint_art := UiKit.icon_base(UiKit.ICONS.note_check, UiKit.BASE_S)
	hint_art.position = Vector2(UiKit.PAD, UiKit.PAD)
	_hint.add_child(hint_art)
	var hint_text := UiKit.label(UiKit.wrap(HINT, UiKit.BODY, ROW.x - UiKit.BASE_S - UiKit.PAD * 4.0), UiKit.BODY, UiKit.SUB_BROWN)
	hint_text.position = Vector2(UiKit.BASE_S + UiKit.PAD * 2.0, UiKit.PAD)
	hint_text.size = Vector2(ROW.x - UiKit.BASE_S - UiKit.PAD * 4.0, _hint.size.y - UiKit.PAD * 2.0 - UiKit.SHADOW_Y)
	hint_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_hint.add_child(hint_text)
	box.add_child(_hint)
	_build_detail()


func _build_detail() -> void:
	_detail.name = "Detail"
	_detail.position = DETAIL.position
	_detail.size = DETAIL.size
	box.add_child(_detail)
	var mid := DETAIL.size.x * 0.5
	# 이름 리본 (판 위로 살짝 걸침)
	_ribbon.name = "Ribbon"
	_ribbon.position = Vector2(mid - 184, -UiKit.PAD)
	_ribbon.size = Vector2(368, 64)
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.draw.connect(func() -> void: UiKit.draw_ribbon(_ribbon, Rect2(Vector2.ZERO, _ribbon.size)))
	_title.position = Vector2(UiKit.PAD, 0)
	_title.size = Vector2(_ribbon.size.x - UiKit.PAD * 2.0, _ribbon.size.y)
	_ribbon.add_child(_title)
	# 빛 원 + 큰 아이콘 받침 + Lv 알약
	var icon_y := 56.0
	_glow.position = Vector2(mid - 128, icon_y + UiKit.BASE_L * 0.5 - 128)
	_detail.add_child(_glow)
	_base.position = Vector2(mid - UiKit.BASE_L * 0.5, icon_y)
	_detail.add_child(_base)
	_lv.name = "Lv"
	_lv.size = Vector2(104, 40)
	_lv.position = Vector2(mid - 52, icon_y + UiKit.BASE_L - 16)  # 받침 아래에 살짝 걸침 (그림과는 안 겹침)
	_lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lv.draw.connect(_draw_pill.bind(_lv))
	_lv_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lv.add_child(_lv_label)
	_detail.add_child(_lv)
	_detail.add_child(_ribbon)  # 리본은 빛 원보다 위
	_desc.position = Vector2(mid - DESC_W * 0.5, 232)
	_desc.size = Vector2(DESC_W, 80)
	_detail.add_child(_desc)
	# 지금 → 다음 카드
	_cards.name = "Cards"
	_cards.position = Vector2(0, 316)
	_cards.size = Vector2(DETAIL.size.x, CARD.y)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.draw.connect(func() -> void:
		if _now_card.visible:
			UiKit.draw_arrow(_cards, Vector2(mid, (CARD.y - UiKit.SHADOW_Y) * 0.5), 48.0))
	_detail.add_child(_cards)
	for trio: Array in [[_now_card, _now_head, _now, mid - 40 - CARD.x], [_next_card, _next_head, _next, mid + 40]]:
		_card(trio[0], trio[1], trio[2], Vector2(trio[3], 0), CARD.x)
	_card(_max_card, _max_head, _max_value, Vector2(mid - 160, 0), 320.0)
	for side in [-1.0, 1.0]:
		var star := UiKit.icon(UiKit.ICONS.star, 40)
		star.position = Vector2(160 + side * 116 - 20, 26)
		_max_card.add_child(star)
	# 사기 버튼 / MAX 리본 / 모자란 수
	_buy.name = "Buy"
	_buy.position = Vector2(mid - BUY.x * 0.5, BUY_Y)
	_buy.size = BUY
	_buy.add_theme_constant_override("icon_max_width", 64)
	_buy.pressed.connect(buy)
	_detail.add_child(_buy)
	_max_ribbon.name = "MaxPlate"  # 최대: 사기 버튼 자리에 같은 크기의 누를 수 없는 홈 색 판 (별 + 글)
	_max_ribbon.position = _buy.position
	_max_ribbon.size = BUY
	var max_plate := UiKit.panel("chip")
	(max_plate.get_theme_stylebox("panel") as Plate).fill = UiKit.TROUGH
	(max_plate.get_theme_stylebox("panel") as Plate).radius = UiKit.R_BUTTON
	max_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_max_ribbon.add_child(max_plate)
	for side: float in [-1.0, 1.0]:
		var star := UiKit.icon(UiKit.ICONS.star, 48)
		star.position = Vector2(BUY.x * 0.5 + side * (BUY.x * 0.5 - 48) - 24, (BUY.y - UiKit.SHADOW_Y - 48) * 0.5)
		_max_ribbon.add_child(star)
	_max_text.position = Vector2(80, 0)
	_max_text.size = Vector2(BUY.x - 160, BUY.y - UiKit.SHADOW_Y)
	_max_ribbon.add_child(_max_text)
	_detail.add_child(_max_ribbon)
	_lack.position = Vector2(mid - DESC_W * 0.5, BUY_Y - 36)  # 사기 버튼 바로 위
	_lack.size = Vector2(DESC_W, 32)
	_detail.add_child(_lack)


func _card(card: Panel, head: Label, value: Label, at: Vector2, width: float) -> void:
	card.position = at
	card.size = Vector2(width, CARD.y)
	head.position = Vector2(UiKit.GAP, UiKit.GAP)
	head.size = Vector2(width - UiKit.PAD, 32)
	value.position = Vector2(UiKit.GAP, 40)
	value.size = Vector2(width - UiKit.PAD, 44)
	card.add_child(head)
	card.add_child(value)
	_cards.add_child(card)


## Lv 알약 (주황 어두움 + 갈색 테두리)
func _draw_pill(pill: Control) -> void:
	var p := Plate.new()
	p.fill = UiKit.ORANGE_DARK
	p.radius = UiKit.R_PILL
	p.shadow = false
	p.draw(pill.get_canvas_item(), Rect2(Vector2.ZERO, pill.size))


func enter_order() -> Array:
	var out: Array = box.get_children().filter(func(c: Node) -> bool: return c != _list)
	out.append_array(_list.get_children())
	return out


func refresh() -> void:
	for t: String in _tabs:
		(_tabs[t] as UiButton).set_fill(UiKit.ORANGE if t == tab else UiKit.PAPER)
		UiKit.tone_text(_tabs[t], "orange" if t == tab else "cream")
	_fill_list()
	_show_detail()
	_hint.visible = tab == "boosters"


func show_tab(t: String) -> void:
	finish_fx()
	if t != tab:
		main.play_ui("page")
	tab = t
	selected = "dash" if t == "upgrades" else "dash_start"
	refresh()
	UiKit.enter(_list.get_children(), Vector2(-24, 0))


func _info() -> Dictionary:
	return UPGRADE_INFO if tab == "upgrades" else BOOSTER_INFO


## 목록 줄을 다시 만든다 (같은 탭이면 고름만 바꿈: 0.15초 전환이 보이게)
func _fill_list() -> void:
	var kinds: Array = _info().keys()
	if _rows.keys() == kinds:
		for kind: String in kinds:
			_update_row(kind)
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	_gauges.clear()
	_counts.clear()
	for i in kinds.size():
		var kind: String = kinds[i]
		var b := UiKit.button("", "cream")
		b.name = kind
		b.position = Vector2(0, i * (ROW.y + ROW_GAP))
		b.size = ROW
		b.pressed.connect(pick.bind(kind))
		b.draw.connect(_draw_tail.bind(b))
		var body_h := ROW.y - UiKit.SHADOW_Y
		var base := UiKit.icon_base(_icon(kind), UiKit.BASE_S)
		base.name = "Base"
		base.position = Vector2(UiKit.GAP + UiKit.LINE, ((body_h - UiKit.BASE_S) * 0.5)).round()
		b.add_child(base)
		var name_label := UiKit.label(_info()[kind][0], UiKit.BODY)
		name_label.name = "Name"
		name_label.position = Vector2(NAME_X, UiKit.GAP + 2)
		name_label.size = Vector2(UiKit.FONT.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.BODY).x, 40)
		b.add_child(name_label)
		var tag_x := ROW.x - UiKit.PAD - TAG.x
		# 이름 옆 알약: 강화 = "Lv.3", 부스터 = 가진 개수 "x2"
		var lv := Control.new()
		lv.name = "Lv"
		lv.size = Vector2(80, 32)
		lv.position = Vector2(NAME_X + name_label.size.x + UiKit.GAP, 14)
		lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lv.draw.connect(_draw_pill.bind(lv))
		var lv_text := UiKit.on_orange(UiKit.label("", UiKit.SUB, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
		lv_text.name = "Text"
		lv_text.set_anchors_preset(Control.PRESET_FULL_RECT)
		lv.add_child(lv_text)
		b.add_child(lv)
		if tab == "upgrades":
			var gauge := Control.new()
			gauge.name = "Gauge"
			gauge.position = Vector2(NAME_X, 52)
			gauge.size = GAUGE
			gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gauge.draw.connect(_draw_gauge.bind(gauge, kind))
			b.add_child(gauge)
			_gauges[kind] = gauge
		else:
			var short := UiKit.label(_info()[kind][3], UiKit.SUB, UiKit.SUB_BROWN)
			short.name = "Short"
			short.position = Vector2(NAME_X, 48)
			short.size = Vector2(tag_x - NAME_X - UiKit.GAP, 28)
			b.add_child(short)
			_counts[kind] = lv_text
		# 가격표 (생선 + 가격) / 최대면 MAX 리본
		var tag := UiKit.panel("chip", false)
		tag.name = "Tag"
		tag.position = Vector2(tag_x, (body_h - TAG.y) * 0.5).round()
		tag.size = TAG
		var fish := UiKit.icon(UiKit.ICONS.fish, 36)
		fish.name = "Fish"
		fish.position = Vector2(UiKit.PAD, (TAG.y - 36) * 0.5)
		tag.add_child(fish)
		var price := UiKit.label("", UiKit.BODY)
		price.name = "Price"
		price.position = Vector2(UiKit.PAD + 36 + UiKit.GAP * 0.5, 0)
		price.size = Vector2(TAG.x - price.position.x - UiKit.PAD - 4, TAG.y)
		tag.add_child(price)
		b.add_child(tag)
		var max_tag := UiKit.panel("chip", false)  # 최대: 가격표 자리에 누를 수 없는 홈 색 알약 (별 + MAX)
		max_tag.name = "Max"
		(max_tag.get_theme_stylebox("panel") as Plate).fill = UiKit.TROUGH
		max_tag.position = tag.position
		max_tag.size = TAG
		var star := UiKit.icon(UiKit.ICONS.star, 36)
		star.position = Vector2(UiKit.PAD, (TAG.y - 36) * 0.5)
		max_tag.add_child(star)
		var max_text := UiKit.label("MAX", UiKit.BODY, UiKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER)
		max_text.position = Vector2(UiKit.PAD + 36, 0)
		max_text.size = Vector2(TAG.x - max_text.position.x - UiKit.PAD, TAG.y)
		max_tag.add_child(max_text)
		b.add_child(max_tag)
		_list.add_child(b)
		_rows[kind] = b
		_update_row(kind)
		b.settle()


## 줄 값 다시 쓰기: Lv, 개수, 가격(못 사면 흐림), MAX, 고름
func _update_row(kind: String) -> void:
	var b: UiButton = _rows[kind]
	b.picked = kind == selected
	var price := _price(kind)
	var tag: Control = b.get_node("Tag")
	tag.visible = price >= 0
	b.get_node("Max").visible = price < 0
	var label: Label = tag.get_node("Price")
	label.text = UiKit.comma(maxi(price, 0))
	UiKit.fit(label, TAG.x - UiKit.PAD * 2.0 - 40, UiKit.BODY)
	# 생선 + 숫자를 한 묶음으로 가운데 (짧은 값에서 가운데가 휑하지 않게)
	var text_w := ceilf(UiKit.FONT.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x)
	var x0 := roundf((TAG.x - (36 + 4 + text_w)) * 0.5)
	(tag.get_node("Fish") as Control).position.x = x0
	label.position.x = x0 + 40
	label.size.x = text_w + 2
	label.add_theme_color_override("font_color", UiKit.BROWN if price <= main.save.fish() else UiKit.RED)  # 모자라면 숫자만 빨강
	if tab == "upgrades":
		(b.get_node("Lv/Text") as Label).text = "Lv.%d" % _hold.get(kind, main.save.upgrade_level(kind))
		_gauges[kind].queue_redraw()
	else:
		_counts[kind].text = "x%d" % main.save.booster_count(kind)
	var lv_label: Label = b.get_node("Lv/Text")
	UiKit.fit(lv_label, b.get_node("Lv").size.x - UiKit.PAD, UiKit.SUB)
	(b.get_node("Base").get_meta("art") as TextureRect).texture = _icon(kind)
	b.queue_redraw()


## 다음 단계 가격 (최대면 -1)
func _price(kind: String) -> int:
	if tab == "upgrades":
		return main.save.upgrade_price(kind)
	return Balance.BOOSTER_PRICES[kind] if main.save.booster_count(kind) < Balance.BOOSTER_MAX else -1


## 줄 고르기
func pick(kind: String) -> void:
	finish_fx()
	if selected != kind:
		main.play_ui("booster_on")
	selected = kind
	refresh()


## 고른 줄의 꼬리: 몸 오른쪽에서 설명 판 쪽으로 (고름 정도만큼 자람)
func _draw_tail(b: UiButton) -> void:
	var k := b._pick
	if k <= 0.01:
		return
	var body := b.body()
	var cy := body.get_center().y
	var x := body.end.x - UiKit.LINE * 0.5
	var reach := (ROW_GAP + UiKit.PAD) * k
	var points := PackedVector2Array([Vector2(x, cy - 14), Vector2(x + reach, cy), Vector2(x, cy + 14)])
	b.draw_colored_polygon(points, UiKit.PAPER)
	b.draw_polyline(points, UiKit.ORANGE_DARK, UiKit.LINE, true)


func _icon(kind: String) -> Texture2D:
	if kind == "fish":
		return WORLD.FISH_LOOKS[_fish_look(main.save.upgrade_level("fish"))]
	return UiKit.ICONS[_info()[kind][2]]


static func _fish_look(level: int) -> int:
	return Perks.new({"fish": level}).fish_look()


func _draw_gauge(gauge: Control, kind: String) -> void:
	var lv: int = _hold.get(kind, main.save.upgrade_level(kind))
	var pop := maxf(0.0, 1.0 - _pop_cell.t / 0.35) if _pop_cell.kind == kind else 0.0
	var pulse := 0.5 - 0.5 * cos(TAU * _pulse / PULSE_TIME) if main.save.upgrade_price(kind) >= 0 else 0.0
	UiKit.draw_gauge(gauge, Rect2(Vector2.ZERO, gauge.size), lv, Balance.UPGRADE_MAX, pulse, lv - 1, pop)


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse = fmod(_pulse + delta, PULSE_TIME)
	if _pop_cell.t < 1.0:
		_pop_cell.t += delta
	for g: Control in _gauges.values():
		g.queue_redraw()


## 게이지 칸 i번 가운데 (게이지 Control 좌표)
static func cell_center(gauge: Control, i: int) -> Vector2:
	return UiKit.gauge_cells(Rect2(Vector2.ZERO, gauge.size), Balance.UPGRADE_MAX)[i].get_center()


## 오른쪽 판: 고른 것의 설명, 지금 → 다음, 사기 버튼 (최대·돈 부족 표시)
func _show_detail() -> void:
	var info: Array = _info()[selected]
	_art.texture = _icon(selected)
	_title.text = info[0]
	UiKit.fit(_title, _title.size.x, UiKit.TITLE)
	_desc.text = UiKit.wrap(info[1], UiKit.BODY, DESC_W)
	var price := _price(selected)
	if tab == "upgrades":
		var lv: int = main.save.upgrade_level(selected)
		_lv_label.text = "Lv.%d" % lv
		_now.text = value_text(selected, lv)
		_next.text = value_text(selected, lv + 1) if price >= 0 else ""
		_max_value.text = value_text(selected, lv)
		_max_head.text = "최대 단계"
		_max_text.text = "최대 단계예요"
	else:
		var n: int = main.save.booster_count(selected)
		_lv_label.text = "x%d" % n
		_now.text = "%d개" % n
		_next.text = "%d개" % (n + 1)
		_max_value.text = "%d개" % n
		_max_head.text = "최대 보유"  # 부스터는 단계가 아니라 개수
		_max_text.text = "가득 찼어요"
	for l: Label in [_now, _next, _max_value]:
		UiKit.fit(l, l.size.x, UiKit.NUM)
	var top := price < 0
	_now_card.visible = not top
	_next_card.visible = not top
	_max_card.visible = top
	_cards.queue_redraw()
	_buy.visible = not top
	_buy.disabled = top  # 최대면 눌리지 않음 (MAX 리본이 대신 보임)
	_max_ribbon.visible = top
	UiKit.fit(_max_text, _max_text.size.x, UiKit.BODY)
	_buy.text = UiKit.comma(maxi(price, 0))
	var short: int = price - main.save.fish()
	# 모자라면 투명하게 흐리는 대신 홈 색 판 + 갈색 글자 (흐리면 고장 난 것처럼 보임, 아트 검토 2차). 눌러 보면 뿌뿌
	_buy.set_fill(UiKit.TROUGH if short > 0 else UiKit.ORANGE)
	UiKit.tone_text(_buy, "cream" if short > 0 else "orange")
	_buy.hot = not top and short <= 0
	_lack.text = "생선 %s마리 모자라요" % UiKit.comma(short) if not top and short > 0 else ""


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
## 강화 = 버튼 찌그러짐 → 지갑 생선 3마리가 새 게이지 칸으로 날아감 → 칸이 톡 채워지며 별 + "지금" 값 튐 (소리는 단계마다 한 음씩 높게, 10단계는 팡파르·별 더)
## 부스터 = 부스터 그림이 목록의 개수 배지로 쏙 → "+1" + 개수 튐
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
		_update_row(kind)
		var spot := to_box(_gauges[kind], cell_center(_gauges[kind], lv - 1))
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
	_pop_cell = {"kind": kind, "t": 0.0}
	refresh()
	var top := level >= Balance.UPGRADE_MAX
	main.play_ui("fanfare" if top else "buy", 1.0 if top else pow(2.0, (level - 1) / 12.0))  # 한 단계 = 반음
	track(UiKit.burst(box, spot, 14 if top else 5, "star", 150.0 if top else 56.0))
	if top:
		track(UiKit.burst(box, to_box(_art, _art.size * 0.5), 12, "star", 200.0))
	UiKit.pop(_max_card if top else _now, 0.3)
	UiKit.pop(_base, 0.3 if top else 0.15)


func _booster_landed(kind: String, spot: Vector2) -> void:
	refresh()
	main.play_ui("pop_in")
	track(UiKit.float_text(box, spot + Vector2(0, -40), "+1"))
	if _counts.has(kind):
		UiKit.pop(_counts[kind].get_parent(), 0.5)
	UiKit.pop(_now, 0.3)


func _shake(control: Control) -> void:
	var x := control.position.x
	var tween := control.create_tween()
	for d in [-10.0, 10.0, -6.0, 6.0, 0.0]:
		tween.tween_property(control, "position:x", x + d, 0.04)


## 지금 살 수 있는 강화 종류 (생선이 다음 단계 값 이상, 최대 아님). [상점] 새 표시 점이 씀
static func affordable(save: SaveData) -> Array:
	return UPGRADE_INFO.keys().filter(func(kind: String) -> bool:
		var price := save.upgrade_price(kind)
		return price >= 0 and price <= save.fish())
