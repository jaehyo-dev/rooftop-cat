class_name ResultExtras
extends Control
## 결과 카드 둘레 (v0.7.0 2c): 이번 판에 깬 미션 쪽지가 카드 왼쪽에 핀으로 꽂히듯 하나씩 붙고,
## 등급이 오르면 카드 오른쪽에 배지가 도장처럼 쾅 찍힌다(보너스 생선·부스터 글자와 함께).
## 쪽지·배지는 버튼이 아니라 눌러도 지금처럼 "빈 곳 = 다시 하기"다.

const NOTE := Vector2(330, 128)
const MAX_NOTES := 3
const NOTE_GAP := 0.35   # 쪽지가 붙는 사이 (초)
const BOOSTER_NAMES := {"dash_start": "질주로 출발", "bell_start": "방울", "fish_bonus": "생선 +50%"}

var main: Node
var _notes := VBoxContainer.new()
var _rank := Control.new()
var _rank_level := 1


func _init(main_node: Node) -> void:
	main = main_node
	name = "ResultExtras"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notes.name = "Notes"
	_notes.add_theme_constant_override("separation", 14)
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notes)
	_rank.name = "RankUp"
	_rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rank.size = Vector2(250, 350)
	_rank.draw.connect(func() -> void: UiKit.draw_rank_ring(_rank, Vector2(125, 92), 78.0, _rank_level))
	add_child(_rank)


func clear() -> void:
	for child in _notes.get_children():
		_notes.remove_child(child)
		child.queue_free()
	for child in _rank.get_children():
		_rank.remove_child(child)
		child.queue_free()
	_rank.visible = false


## 결과 숫자가 다 차오른 뒤 부름: 깬 미션 쪽지와 등급 오름을 차례로 보여 준다
func play(result: Dictionary, card: Rect2) -> void:
	clear()
	var done: Array = result.get("done", [])
	_notes.position = Vector2(maxf(16.0, card.position.x - NOTE.x - 36.0), card.position.y + 110.0)  # 왼쪽 위 거리·BEST 글자 아래
	var shown := done.slice(0, MAX_NOTES)
	for i in shown.size():
		var note := _note(shown[i], i, done.size() - MAX_NOTES if i == MAX_NOTES - 1 and done.size() > MAX_NOTES else 0)
		_notes.add_child(note)
		_pin_in(note, NOTE_GAP * i)
	var ranks: Array = result.get("ranks", [])
	if not ranks.is_empty():
		_show_rank(ranks, card, NOTE_GAP * shown.size() + 0.2)


## 깬 미션 쪽지: 아이콘 + 문구 + "+400" (more > 0이면 "외 n개")
func _note(done: Dictionary, index: int, more: int) -> Control:
	var note := Control.new()
	note.custom_minimum_size = NOTE
	var paper := UiKit.paper("note")
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	note.add_child(paper)
	var pin := UiKit.icon(UiKit.PIN_RED if index % 2 == 0 else UiKit.PIN_YELLOW, 34)
	pin.position = Vector2(NOTE.x * 0.5 - 17, -18)
	note.add_child(pin)
	var stat: String = Missions.info(done.id).stat
	var art := UiKit.icon(UiKit.ICONS[MissionBoard.STAT_ICONS.get(stat, "note_check")], 46)
	art.position = Vector2(14, 20)
	note.add_child(art)
	var text := UiKit.label(UiKit.wrap(Missions.text(done.id), 24, NOTE.x - 78), 24)  # 띄어쓰기에서만 줄바꿈
	text.position = Vector2(66, 18)  # 위 가운데 핀 아래
	text.size = Vector2(NOTE.x - 78, 62)
	note.add_child(text)
	var reward := UiKit.label("미션 완료!  생선 %s%s" % [UiKit.comma(done.fish), "  외 %d개" % more if more > 0 else ""], 24, UiKit.RED)
	reward.position = Vector2(20, NOTE.y - 44)
	reward.size = Vector2(NOTE.x - 30, 34)
	UiKit.fit(reward, reward.size.x, 24)
	note.add_child(reward)
	return note


## 핀으로 꽂히듯: 위에서 살짝 기울어진 채 내려와 콕 박히며 흔들림이 멈춤
func _pin_in(note: Control, delay: float) -> void:
	note.modulate.a = 0.0
	note.pivot_offset = Vector2(NOTE.x * 0.5, 0.0)
	note.rotation = 0.25
	note.scale = Vector2.ONE * 1.15
	var tween := note.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: main.play_ui("booster_on"))
	tween.set_parallel()
	tween.tween_property(note, "modulate:a", 1.0, 0.12)
	tween.tween_property(note, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(note, "rotation", -0.04, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## 등급 오름 배지 (여러 등급이 한 번에 오르면 마지막 등급, 보너스는 합쳐서)
func _show_rank(ranks: Array, card: Rect2, delay: float) -> void:
	var last: Dictionary = ranks[-1]
	_rank_level = last.level
	var fish := 0
	var boosters := []
	for up: Dictionary in ranks:
		fish += up.fish
		boosters.append_array(up.boosters)
	var view_w := get_viewport_rect().size.x
	_rank.position = Vector2(minf(card.end.x + 24.0, view_w - _rank.size.x - 8.0), card.position.y + 20.0)
	var face := UiKit.icon(UiKit.ICONS.rank_face, 150)
	face.position = Vector2(50, 10)
	face.size = Vector2(150, 150)
	_rank.add_child(face)
	# 글자는 종이 위에 (배경의 생선·건물 위에서도 읽히게, 2c-fix)
	var paper := UiKit.paper("note")
	paper.position = Vector2(0, 158)
	paper.size = Vector2(_rank.size.x, _rank.size.y - 158)
	_rank.add_child(paper)
	var inner_w := paper.size.x - 28.0
	var title := UiKit.label("등급이 올랐어요!", 30, UiKit.RED, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.fit(title, inner_w, 30)
	var name_label := UiKit.label(CatRank.rank_name(last.level), 34, UiKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.fit(name_label, inner_w, 34)
	var names := boosters.map(func(k: String) -> String: return BOOSTER_NAMES.get(k, k))
	var bonus := UiKit.label(UiKit.wrap("생선 +%s%s" % [UiKit.comma(fish), "\n+ " + ", ".join(names) if not names.is_empty() else ""], 24, inner_w), 24, UiKit.BROWN, HORIZONTAL_ALIGNMENT_CENTER)
	for row: Array in [[title, 10.0, 38.0], [name_label, 46.0, 42.0], [bonus, 88.0, 92.0]]:
		var l: Label = row[0]
		l.position = Vector2(14, row[1])
		l.size = Vector2(inner_w, row[2])
		paper.add_child(l)
	_rank.visible = false
	var tween := _rank.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		_rank.visible = true
		_rank.queue_redraw()
		main.play_ui("whoosh")
		UiKit.stamp(_rank, -0.08, func() -> void:  # 미션 받기 도장과 같은 쿵 (2c 피드백)
			main.play_ui("thud")
			main.play_ui("rank_up")
			UiKit.shake(get_parent())
			UiKit.burst(self, _rank.position + Vector2(125, 92), 10, "ink", 120.0)
			UiKit.burst(self, _rank.position + Vector2(125, 92), 8, "star", 150.0)))
