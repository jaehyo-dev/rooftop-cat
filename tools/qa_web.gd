extends Node
## v0.7.0 2c-juice 눈 검수 캡처 (자동 테스트 아님, QUALITY_BAR 4-1 넷째 항목). 창을 띄우지 않으려고 로컬 웹 빌드 안에서 돈다.
## 검수용 웹 빌드(review/v0.7.0/2c-juice/export_qa.sh: tools/를 넣어 내보냄) 주소에 ?qa=shots&look=old|a|b 또는 ?qa=gif&look=a 를 붙이면
## DevPanel.attach가 이 스크립트를 붙인다 (보통 빌드에는 tools/가 없어 안 붙음).
## 화면마다 window.qaShot = {name, cells}를 쓰고 qa_web.mjs(헤드리스 Chromium)가 찍은 뒤 window.qaTaken = name으로 답한다.
## GIF는 window.qaRec = 이름 동안 review/v0.7.0/2c-juice/qa_web.mjs가 계속 찍는다 (느리게 돌려 프레임을 넉넉히: Engine.time_scale).
## 상태 만들기는 2c-fix/capture_fix.gd와 같음 (그쪽은 Godot 창이 필요해서 웹용으로 옮김).

const PATH := "user://qa_web.cfg"
const SLOW := 0.12  # GIF 찍는 동안 게임 빠르기
var main: Control
var _look := "a"


func _ready() -> void:
	var query := str(JavaScriptBridge.eval("location.search"))
	var mode := query.get_slice("qa=", 1).get_slice("&", 0)
	if "look=" in query:
		_look = query.get_slice("look=", 1).get_slice("&", 0)
	UiKit.look = _look
	AudioServer.set_bus_mute(0, true)
	await _wait(0.5)
	if mode == "gif":
		await _gifs()
	else:
		await _shots()
	JavaScriptBridge.eval("window.qaEnd = true")


# --- 칸 찾기·가장 긴 값 (tests/test_ui_quality.gd도 이것을 씀: 검사하는 칸 = 확대해 보는 칸) ---

static func moved(xf: Transform2D, rect: Rect2) -> Rect2:
	var box := Rect2(xf * rect.position, Vector2.ZERO)
	for corner in [rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(0, rect.size.y), rect.end]:
		box = box.expand(xf * corner)
	return box


static func cell_of(node: Control) -> Control:
	var at := node.get_parent()
	while at is Container:
		at = at.get_parent()
	return at as Control


static func in_menu(node: Node) -> bool:
	var at := node.get_parent()
	while at:
		if at.name in ["StartMenu", "Shop", "Missions", "GameOver"]:
			return true
		at = at.get_parent()
	return false


static func longest_missions(table: Dictionary, count: int) -> Array:
	var ids: Array = table.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return UiKit.FONT.get_string_size(Missions.text(a), 0, -1, 29).x > UiKit.FONT.get_string_size(Missions.text(b), 0, -1, 29).x)
	return ids.slice(0, count)


static func fill_longest(data: Dictionary) -> void:
	for weekly in [false, true]:
		var table: Dictionary = MissionTable.WEEKLY if weekly else MissionTable.DAILY
		var list := Missions._entries(longest_missions(table, 3), table)
		for i in 3:
			list[i].target = 99999 if i != 1 else 10000
			list[i].progress = list[i].target if i < 2 else list[i].target - 1
			list[i].done = i < 2
			list[i].claimed = i == 0
		if weekly:
			data.missions.weekly = list
		else:
			data.missions.daily = list


# --- 상태 ---

## kind: empty / normal / longest / max / poor / claim3(일일 3장 받기 전)
func _make(kind: String) -> void:
	if main:
		main.queue_free()
		await get_tree().process_frame
	else:
		get_tree().current_scene.queue_free()  # 처음 뜬 게임
	for file in [PATH, PATH + ".tmp"]:
		DirAccess.remove_absolute(file)
	var save := SaveData.open(PATH)
	save.data.record.best_score2 = 0
	match kind:
		"normal", "claim3":
			save.data.wallet.fish = 3450
			save.data.record.best_score2 = 48210
			save.data.upgrades = {"dash": 3, "yarn": 2, "combo": 1, "gold": 0, "cookie": 0, "fish": 3}
			save.data.boosters = {"dash_start": 2, "bell_start": 1, "fish_bonus": 0}
			save.data.rank = {"level": 3, "xp": 95}
		"longest", "max":
			save.data.wallet.fish = 9999999
			save.data.record.best_score2 = 9999999
			for k: String in save.data.upgrades:
				save.data.upgrades[k] = Balance.UPGRADE_MAX if kind == "max" else 0
			for k: String in save.data.boosters:
				save.data.boosters[k] = Balance.BOOSTER_MAX
			save.data.rank = {"level": MissionTable.RANK_NAMES.size(), "xp": MissionTable.RANK_AFTER_MAX_XP - 1}
		"poor":
			save.data.wallet.fish = 50
			save.data.upgrades = {"dash": 9, "yarn": 0, "combo": 0, "gold": 0, "cookie": 0, "fish": 0}
		"rich":
			save.data.wallet.fish = 99999
			save.data.upgrades = {"dash": 3, "yarn": 0, "combo": 0, "gold": 0, "cookie": 0, "fish": 9}
	save.save()
	main = load("res://scenes/main.tscn").instantiate()
	main.record_path = PATH
	main.clock.fixed = {"year": 2026, "month": 11, "day": 16 if kind == "longest" else 12, "hour": 0 if kind == "longest" else 18,
			"minute": 0 if kind == "longest" else 48, "second": 1}
	get_tree().root.add_child(main)
	await _wait(0.8)
	for temp in ["DevPanel", "LookToggle"]:  # 시험 패널·A/B 단추는 캡처에서 뺌
		if main.has_node(temp):
			main.get_node(temp).queue_free()
	var data: Dictionary = main.save.data
	if kind == "normal":
		data.missions.daily = Missions._entries(["d_dist_2", "d_fish_c1", "d_double"], MissionTable.DAILY)
		data.missions.weekly = Missions._entries(["w_daily_10", "w_fish_10k", "w_double"], MissionTable.WEEKLY)
		Missions.count(data, {"meters": 520, "fish": 640, "double": 4})
		Missions.claim(data, false, 1)
		data.missions.weekly[1].progress = 7400
	elif kind == "claim3":
		data.missions.daily = Missions._entries(["d_dist_1", "d_fish_c1", "d_double"], MissionTable.DAILY)
		for entry: Dictionary in data.missions.daily:
			entry.progress = entry.target
			entry.done = true
			entry.claimed = false
	elif kind == "longest":
		fill_longest(data)
	main.save.save()
	main.refresh_menus()


## 게임 시간으로 기다림 (느리게 돌릴 때도 같은 장면)
func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


## 전체 화면 + 글자가 든 칸(창 픽셀 사각형) → qa_web.mjs가 찍고 2배 조각을 자름
func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var to_px := get_tree().root.get_final_transform()
	var view := Rect2(Vector2.ZERO, Vector2(get_tree().root.size))
	var cells: Array[Rect2] = []
	for node in main.find_children("*", "Label", true, false):
		var l: Label = node
		if not (l.is_visible_in_tree() and in_menu(l) and l.text.strip_edges() != ""):
			continue
		var cell := cell_of(l)
		if cell.name == "Box" or cell.size.x * cell.size.y > 1280 * 720 * 0.4:
			cell = l
		var rect := (to_px * moved(cell.get_global_transform(), Rect2(Vector2.ZERO, cell.size)).grow(12.0)).intersection(view)
		if rect.size.x < 4 or cells.any(func(r: Rect2) -> bool: return r.encloses(rect)):
			continue
		cells = cells.filter(func(r: Rect2) -> bool: return not rect.encloses(r))
		cells.append(rect)
	var list := cells.map(func(r: Rect2) -> Array: return [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)])
	var file := "%s_%s" % [name, _look]
	JavaScriptBridge.eval("window.qaShot = %s" % JSON.stringify({"name": file, "cells": list}))
	while str(JavaScriptBridge.eval("window.qaTaken || ''")) != file:
		await get_tree().process_frame


func _shop(kind: String, tab: String, pick: Array) -> void:
	main.open_shop(tab)
	await _wait(0.4)
	for p: String in pick:
		main.shop.selected = p
		main.shop.refresh()
		await _wait(0.1)
		await _shot("shop_%s_%s_%s" % [kind, tab, p])
	main.go_back()
	await _wait(0.4)


func _fall() -> void:
	var world: Node2D = main.get_node("World")
	world.sim.on_ground = false
	world.sim.y = Balance.FALL_LIMIT + 1.0
	world.sim.vy = -1000.0


## 결과 카드: 일일 "한 판" 미션을 깨고 등급이 오르게 해 두고 떨어짐
func _result_rankup() -> void:
	await _make("normal")
	var data: Dictionary = main.save.data
	data.missions.daily = Missions._entries(["d_runs", "d_dist_1", "d_double"], MissionTable.DAILY)
	data.missions.daily[0].progress = 1
	data.rank.xp = CatRank.next_xp(data.rank.level) - 5
	main.begin_run()
	await _wait(1.5)
	main.get_node("World").sim.x += Balance.PX_PER_METER * 320.0
	_fall()


func _shots() -> void:
	for kind in ["empty", "normal", "longest"]:
		await _make(kind)
		if kind == "normal":
			main.boosters_on = ["dash_start"]
			main.refresh_menus()
		await _wait(0.5)
		await _shot("start_" + kind)
	await _make("normal")
	await _shop("normal", "upgrades", ["fish"])
	await _shop("normal", "boosters", ["fish_bonus"])
	await _make("longest")
	await _shop("longest", "upgrades", ShopScreen.UPGRADE_INFO.keys())
	await _shop("longest", "boosters", ShopScreen.BOOSTER_INFO.keys())
	await _make("max")
	await _shop("max", "upgrades", ["fish"])
	await _make("poor")
	await _shop("poor", "upgrades", ["dash"])
	for kind in ["empty", "normal", "longest"]:
		await _make(kind)
		main.open_missions()
		await _wait(0.5)
		await _shot("missions_" + kind)
		if kind == "normal":
			main.board.swap_pressed(false, 2)
			await _wait(0.2)
			await _shot("missions_confirm")
			main.board.claim(false, 0)
			await _wait(1.6)
			await _shot("missions_claimed")
		main.go_back()
		await _wait(0.4)
	# 결과 카드: 미션 없음(버튼만) / 미션 깸 + 등급 오름 / 가장 긴 값
	await _make("empty")
	main.begin_run()
	await _wait(1.0)
	_fall()
	await _wait(Juice.COUNT_UP_EACH * 4.0 + 1.5)
	await _shot("result_plain")
	await _result_rankup()
	await _wait(Juice.COUNT_UP_EACH * 4.0 + 2.5)
	await _shot("result_rankup")
	await _make("longest")
	main.begin_run()
	await _wait(0.3)
	_fall()
	await _wait(0.3)
	main._result.values = [99999, 99999, 9999, 9999999]
	main._result.bonus = true
	main._result.t = 999.0
	main._count_result(0.0)
	var done := []
	for id in longest_missions(MissionTable.DAILY, 2) + longest_missions(MissionTable.WEEKLY, 2):
		done.append({"id": id, "fish": 99999})
	main._extras.play({"done": done, "ranks": [{"level": 9, "fish": 99999, "boosters": ["dash_start"]},
			{"level": 10, "fish": 99999, "boosters": ["bell_start", "fish_bonus"]}]}, main.get_node("GameOver/Card").get_global_rect())
	await _wait(ResultExtras.NOTE_GAP * 4.0 + 1.2)
	await _shot("result_longest")


# --- GIF ---

func _rec(name: String, on: bool) -> void:
	Engine.time_scale = SLOW if on else 1.0
	JavaScriptBridge.eval("window.qaRec = '%s'" % (name if on else ""))
	await _wait(0.1)


func _gifs() -> void:
	# 강화 사기 (보통 단계 3 → 4 → 5)
	await _make("normal")
	main.open_shop("upgrades")
	await _wait(0.5)
	await _rec("buy_upgrade", true)
	main.shop.buy()
	await _wait(0.9)
	main.shop.buy()
	await _wait(1.2)
	await _rec("", false)
	main.go_back()
	# 강화 10단계 (9 → 10, 생선 점수: 그림도 바뀜)
	await _make("rich")
	main.open_shop("upgrades")
	await _wait(0.4)
	main.shop.selected = "fish"
	main.shop.refresh()
	await _wait(0.3)
	await _rec("buy_upgrade_max", true)
	main.shop.buy()
	await _wait(1.8)
	await _rec("", false)
	# 부스터 사기
	await _make("normal")
	main.open_shop("boosters")
	await _wait(0.5)
	await _rec("buy_booster", true)
	main.shop.buy()
	await _wait(1.0)
	main.shop.buy()
	await _wait(1.2)
	await _rec("", false)
	# 미션 3장 연달아 받기 (쿵 쿵 쿵)
	await _make("claim3")
	main.open_missions()
	await _wait(0.6)
	await _rec("claim3", true)
	for slot in 3:
		main.board.claim(false, slot)
		await _wait(0.75)
	await _wait(1.0)
	await _rec("", false)
	# 결과 카드 등급 오름 (숫자 차오름 → 쪽지 → 배지 쿵)
	await _result_rankup()
	await _wait(Balance.RESTART_DELAY)
	await _rec("result_rankup", true)
	await _wait(Juice.COUNT_UP_EACH * 4.0 + 2.2)
	await _rec("", false)
	# 결과 카드 → [메인 화면]
	await _rec("result_home", true)
	await _wait(0.4)
	main.get_node("GameOver/Card/Box/Row/Home").pressed.emit()
	await _wait(1.0)
	await _rec("", false)
