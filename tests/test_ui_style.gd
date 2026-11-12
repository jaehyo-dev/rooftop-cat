extends TestCase
## 유료 게임 UI 기준 (QUALITY_BAR 4-2, v0.7.0 2c-polish):
## ① ART_BIBLE "UI 스타일" 표 = UiKit 상수, ② 메뉴 코드에 표 밖의 값(색·둥글기·테두리·글자 크기·간격 숫자)이 없음,
## ③ 같은 열·줄 요소의 위치·간격이 0px까지 같음 (상점 목록·게이지 칸·미션 쪽지·정보 띠·부스터 칸),
## ④ 날아가는 연출(강화·부스터·미션 받기)은 PC·휴대폰 모두 화면 안에 머묾.

const PATH := "user://test_ui_style.cfg"
const QA := preload("res://tools/qa_web.gd")
## 표에 없는 값을 찾는 곳: 메뉴 화면 코드 (UiKit·Plate·UiButton은 상수 정의 쪽이라 따로 검사)
const KIT := ["res://scripts/ui/ui_kit.gd", "res://scripts/ui/plate.gd", "res://scripts/ui/ui_button.gd"]
## 메뉴 코드에 있으면 안 되는 것 (정규식 → 이유)
const BANNED := {
	"Color\\(": "색은 UiKit 상수만",
	"StyleBoxFlat": "판·버튼은 UiKit.panel / UiKit.button (Plate)",
	"corner_radius|border_width|shadow_size|shadow_offset": "둥글기·테두리·그림자는 UiKit 상수만",
	"font_size\", *[0-9]": "글자 크기는 UiKit.TITLE·BODY·SUB·NUM",
	"\"separation\", *[0-9]": "간격은 UiKit.GAP 배수",
	"UiKit\\.(label|button)\\([^\\n]*, *[0-9]+ *[,)]": "글자 크기는 UiKit.TITLE·BODY·SUB·NUM",
	"UiKit\\.fit\\([^\\n]*, *[0-9]+\\)": "글자 크기는 UiKit.TITLE·BODY·SUB·NUM",
}


func _clear() -> void:
	for file in [PATH, PATH + ".tmp", PATH + ".broken"]:
		DirAccess.remove_absolute(file)


## ART_BIBLE "13. UI 스타일" 표의 (상수, 값) 목록
static func style_table() -> Array:
	var text := FileAccess.get_file_as_string("res://ART_BIBLE.md")
	var section := text.substr(text.find("## 13. UI 스타일"))
	var re := RegEx.create_from_string("\\| *`([A-Z_]+)` *\\| *`([^`]+)` *\\|")
	var out := []
	for m in re.search_all(section):
		out.append([m.get_string(1), m.get_string(2)])
	return out


func test_ART_BIBLE_표와_UiKit_상수가_같다() -> void:
	var consts: Dictionary = load("res://scripts/ui/ui_kit.gd").get_script_constant_map()
	var rows := style_table()
	assert_true(rows.size() >= 40, "표 줄 수 %d" % rows.size())
	for row: Array in rows:
		var name: String = row[0]
		assert_true(consts.has(name), "UiKit.%s 없음" % name)
		if not consts.has(name):
			continue
		var value: Variant = consts[name]
		if value is Color:
			assert_true((value as Color).is_equal_approx(Color(row[1])), "%s: 표 %s, 코드 %s" % [name, row[1], (value as Color).to_html()])
		else:
			assert_true(is_equal_approx(float(value), float(row[1])), "%s: 표 %s, 코드 %s" % [name, row[1], value])
	assert_eq(int((UiKit.FONT as FontVariation).spacing_glyph), UiKit.LETTER, "메뉴 글꼴 글자 사이 = 표")
	# 반대로: 표에 적힌 모양 상수가 빠지지 않게 (색·둥글기·글자·받침)
	var listed := rows.map(func(r: Array) -> String: return r[0])
	for name in ["PANEL", "PAPER", "ORANGE", "ORANGE_LIGHT", "ORANGE_DARK", "GREEN", "RED", "BROWN", "R_CHIP", "R_BUTTON", "R_PANEL", "R_PILL",
			"LINE", "SHADOW_Y", "PRESS_Y", "GAP", "TITLE", "BODY", "SUB", "NUM", "BASE_S", "BASE_L"]:
		assert_true(name in listed, "표에 %s" % name)


func test_메뉴_코드에_표에_없는_값이_없다() -> void:
	var files := DirAccess.get_files_at("res://scripts/ui")
	var checked := 0
	for file in files:
		var path := "res://scripts/ui/" + file
		if not file.ends_with(".gd") or path in KIT:
			continue
		checked += 1
		_scan(path, FileAccess.get_file_as_string(path))
	# 결과 카드(main.gd)는 메뉴 부분만: UiKit 부품을 부르는 줄
	var main_lines := PackedStringArray()
	for line in FileAccess.get_file_as_string("res://scripts/main.gd").split("\n"):
		if "UiKit." in line:
			main_lines.append(line)
	_scan("main.gd", "\n".join(main_lines))
	assert_true(checked >= 6, "메뉴 파일 %d개" % checked)
	# UiKit·Plate·UiButton: 새 색은 상수 줄에서만 (#값), 나머지는 상수에서 투명도만 바꿈
	var hex := RegEx.create_from_string("Color\\(\"#")
	var raw := RegEx.create_from_string("Color\\( *[0-9.]")
	for path in KIT:
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var is_const := line.begins_with("const ") or line.begins_with("\t\tColor(\"#")  # RANK_RINGS 둘째 줄
			assert_false(hex.search(line) != null and not is_const, "%s:%d 상수 밖 색 %s" % [path, n, line.strip_edges()])
			assert_false(raw.search(line) != null, "%s:%d 숫자 색 %s" % [path, n, line.strip_edges()])


func _scan(path: String, source: String) -> void:
	var n := 0
	for line in source.split("\n"):
		n += 1
		if line.strip_edges().begins_with("#"):
			continue
		for pattern: String in BANNED:
			if RegEx.create_from_string(pattern).search(line):
				_fail("%s:%d %s — %s" % [path, n, BANNED[pattern], line.strip_edges()], "")


func _main(fish: int) -> Control:
	_clear()
	var save := SaveData.open(PATH)
	save.data.wallet.fish = fish
	save.data.record.best_score2 = 48210
	save.data.upgrades = {"dash": 3, "yarn": 2, "combo": 1, "gold": 0, "cookie": 0, "fish": 10}
	save.data.boosters = {"dash_start": 2, "bell_start": 1, "fish_bonus": 0}
	save.save()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = PATH
	main.clock.fixed = {"year": 2026, "month": 11, "day": 12, "hour": 12, "minute": 0, "second": 0}
	add_child(main)
	return main


func _done(main: Control) -> void:
	main.queue_free()
	await wait_frames(1)
	_clear()


## 같은 값이어야 하는 목록 (모두 같으면 빈 문자열)
static func _same(what: String, values: Array) -> String:
	for v in values:
		if not is_equal_approx(float(v), float(values[0])):
			return "%s 다름 %s" % [what, values]
	return ""


func _expect_same(what: String, values: Array) -> void:
	var problem := _same(what, values)
	assert_eq(problem, "", what)


func test_같은_열과_줄은_0px까지_맞는다() -> void:
	var main := _main(5000)
	await get_tree().create_timer(0.6).timeout  # 들어오는 연출이 끝난 뒤
	# 정보 띠: 같은 높이·같은 y, 간격 같음
	var bands: Array = main.start_menu._bands.get_children()
	_expect_same("정보 띠 y", bands.map(func(b: Control) -> float: return b.position.y))
	_expect_same("정보 띠 높이", bands.map(func(b: Control) -> float: return b.size.y))
	_expect_same("정보 띠 간격", [bands[1].position.x - bands[0].get_rect().end.x, bands[2].position.x - bands[1].get_rect().end.x])
	# 부스터 칸: 크기·간격 같음
	var slots: Array = main.start_menu.boosters.get_children()
	_expect_same("부스터 칸 넓이", slots.map(func(b: Control) -> float: return b.size.x))
	_expect_same("부스터 칸 간격", [slots[1].position.x - slots[0].get_rect().end.x, slots[2].position.x - slots[1].get_rect().end.x])
	for tab in ["upgrades", "boosters"]:
		main.open_shop(tab)
		await wait_frames(20)
		var rows: Array = main.shop._list.get_children()
		_expect_same(tab + " 줄 x", rows.map(func(r: Control) -> float: return r.position.x))
		_expect_same(tab + " 줄 넓이", rows.map(func(r: Control) -> float: return r.size.x))
		var gaps := []
		for i in rows.size() - 1:
			gaps.append(rows[i + 1].position.y - rows[i].get_rect().end.y)
		_expect_same(tab + " 줄 간격", gaps)
		# 고르지 않은 줄끼리 받침·이름·가격표 자리가 같음 (고른 줄은 LIFT_Y만큼 떠 있음)
		var calm := rows.filter(func(r: UiButton) -> bool: return not r.picked)
		for part in ["Base", "Name", "Tag"]:
			_expect_same("%s %s x" % [tab, part], calm.map(func(r: Control) -> float: return r.get_node(part).position.x))
			_expect_same("%s %s y" % [tab, part], calm.map(func(r: Control) -> float: return r.get_node(part).position.y))
		var row: UiButton = calm[0]
		var body := row.body()
		var base: Control = row.get_node("Base")
		assert_true(absf(base.get_rect().get_center().y - body.get_center().y) <= 0.5, "%s 받침이 줄 가운데" % tab)
		var tag: Control = row.get_node("Tag")
		assert_true(absf(tag.get_rect().get_center().y - body.get_center().y) <= 0.5, "%s 가격표가 줄 가운데" % tab)
		main.go_back()
		await wait_frames(20)
	# 게이지 칸: 크기·간격 정확히 같은 정수 픽셀, 홈 안
	var cells := UiKit.gauge_cells(Rect2(Vector2.ZERO, ShopScreen.GAUGE), Balance.UPGRADE_MAX)
	_expect_same("게이지 칸 넓이", cells.map(func(c: Rect2) -> float: return c.size.x))
	_expect_same("게이지 칸 높이", cells.map(func(c: Rect2) -> float: return c.size.y))
	var cell_gaps := []
	for i in cells.size() - 1:
		cell_gaps.append(cells[i + 1].position.x - cells[i].end.x)
	_expect_same("게이지 칸 간격", cell_gaps)
	for c: Rect2 in cells:
		assert_eq(c.position, c.position.round(), "칸 정수 픽셀")
		assert_true(Rect2(Vector2.ZERO, ShopScreen.GAUGE).grow(-UiKit.LINE).encloses(c), "칸이 홈 안")
	assert_true(absf(cells[0].position.x - (ShopScreen.GAUGE.x - cells[-1].end.x)) <= 1.0, "양 끝 여백 같음")
	# 미션 쪽지: 열·줄 간격 같음
	main.open_missions()
	await wait_frames(20)
	var notes: Array = main.board._notes
	_expect_same("쪽지 열 간격", [notes[1].position.x - notes[0].position.x, notes[2].position.x - notes[1].position.x])
	_expect_same("쪽지 위 줄 y", [notes[0].position.y, notes[1].position.y, notes[2].position.y])
	_expect_same("쪽지 위·아래 x", [notes[0].position.x, notes[3].position.x])
	var cork: Control = main.board.box.get_node("Cork")
	assert_true(absf((notes[0].position.x - cork.position.x) - (cork.get_rect().end.x - notes[2].get_rect().end.x)) <= 0.5, "쪽지가 게시판 가운데")
	await _done(main)


## 날아가는 그림(Fly*)이 매 프레임 상자(= 화면 1280x720 영역) 안에 있는지. 문제를 모아 돌려줌
func _watch_fly(main: Control, screen: MenuScreen, frames: int) -> PackedStringArray:
	var out := PackedStringArray()
	var view := main.get_viewport_rect()
	var seen := 0
	for f in frames:
		await wait_frames(1)
		for node in screen.box.get_children():
			if node is Control and node.has_meta("fly") and not node.is_queued_for_deletion():
				seen += 1
				var c: Control = node
				var rect := QA.moved(c.get_global_transform(), Rect2(Vector2.ZERO, c.size))
				if not view.encloses(rect):
					out.append("%s 화면 밖 %s (화면 %s)" % [c.name, rect, view.size])
	if seen == 0:
		out.append("날아가는 그림을 못 봄")
	return out


func test_날아가는_연출은_PC와_휴대폰_모두_화면_안에_머문다() -> void:
	var window := get_window()
	var keep := window.size
	for size in [Vector2i(1280, 720), Vector2i(844, 390)]:
		window.size = size
		var main := _main(999999)
		await wait_frames(5)
		# 강화: 지갑(오른쪽 위)에서 맨 위 줄 게이지로 (예전엔 곡선 꼭대기가 화면 위로 나감)
		main.open_shop("upgrades")
		await wait_frames(20)
		for kind in ["dash", "yarn"]:
			main.shop.pick(kind)
			main.shop.buy()
			for p in await _watch_fly(main, main.shop, 40):
				_fail("강화 %s %s" % [kind, p], "")
		main.shop.show_tab("boosters")
		await wait_frames(5)
		main.shop.buy()
		for p in await _watch_fly(main, main.shop, 40):
			_fail("부스터 %s" % p, "")
		main.go_back()
		await wait_frames(20)
		# 미션 받기: 쪽지에서 지갑으로
		var data: Dictionary = main.save.data
		for entry: Dictionary in data.missions.daily:
			entry.progress = entry.target
			entry.done = true
			entry.claimed = false
		main.open_missions()
		await wait_frames(20)
		main.board.claim(false, 0)
		for p in await _watch_fly(main, main.board, 60):
			_fail("미션 받기 %s" % p, "")
		await _done(main)
	window.size = keep


func test_빨리_다시_열어도_요소가_제자리로_돌아온다() -> void:
	var main := _main(5000)
	await wait_frames(5)
	main.open_shop("upgrades")
	await get_tree().create_timer(0.8).timeout  # 첫 들어오기가 끝난 자리
	var rest := {}
	for c: Control in main.shop.enter_order():
		rest[c] = c.position
	for i in 3:  # 들어오는 연출 도중에 닫고 다시 열기, 같은 탭 다시 누르기
		main.go_back()
		await wait_frames(2)
		main.open_shop("upgrades")
		await wait_frames(2)
		main.shop.show_tab("upgrades")
		await wait_frames(2)
	await get_tree().create_timer(0.8).timeout
	for c: Control in main.shop.enter_order():
		if rest.has(c):
			assert_eq(c.position, rest[c], "%s 제자리" % c.name)
	await _done(main)


func test_날아가는_길은_꼭대기까지_상자_안이다() -> void:
	var bounds := Rect2(0, 0, 1280, 720)
	# 지갑(위 끝) → 위 줄, 아래 쪽지 → 지갑, 같은 높이끼리 등 여러 경우
	for pair in [[Vector2(1056, 52), Vector2(380, 190)], [Vector2(90, 660), Vector2(1056, 52)], [Vector2(600, 40), Vector2(700, 40)], [Vector2(20, 700), Vector2(1270, 10)]]:
		for i in 10:
			var path := UiKit.fly_path(pair[0], pair[1], i, 10, 44.0, bounds)
			for k in 21:
				var at := UiKit.fly_point(path, k / 20.0)
				assert_true(bounds.grow(-44.0 * 0.6).has_point(at), "%s → %s %d번 %.2f: %s" % [pair[0], pair[1], i, k / 20.0, at])
