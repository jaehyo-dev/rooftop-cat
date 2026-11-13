extends TestCase
## 화면(UI) 검수 자동 검사 (QUALITY_BAR 4-1, v0.7.0 2c 사용자 지적 뒤 추가)
## 1) 글자 모양: 화면에 나올 수 있는 모든 글자가 글꼴(주아, 한글 2,367자만 있음)에 있는지 (없으면 네모 □로 나옴)
## 2) 가장 긴 값: 숫자·이름이 가장 길 때 글자가 칸 안에 있고 다른 글자·그림과 겹치지 않는지 (PC 1280x720·폰 844x390)
## 3) 그림 가장자리: 잘라 쓴 그림의 가장자리 1px에 불투명 픽셀이 없는지 (있으면 시트에서 자를 때 몸이 잘린 것)

## 칸 찾기·가장 긴 값 채우기는 눈 검수 캡처(tools/qa_web.gd)와 같은 것을 씀 (검사하는 칸 = 확대해 보는 칸)
const QA := preload("res://tools/qa_web.gd")
const PATH := "user://test_ui_quality.cfg"
## 글자 검사에서 빼는 파일: course_data.gd의 구간 이름("화분·실외기 박자")은 검토용 내보내기(tests/export_segments.gd)에만 쓰고 화면에 안 나옴
const GLYPH_SKIP := ["res://scripts/logic/course_data.gd"]
## 가장자리 검사 예외 (이유별). 여기 없는 그림은 가장자리 불투명 픽셀이 0이어야 한다
const EDGE_TILES := ["res://assets/sprites/backdrop/"]  # 옆으로 이어 붙이는 띠: 가장자리가 닿아야 이음매가 안 보임
const EDGE_TILE_NAMES := ["brick_", "tile_", "villa_"]   # 건물 벽 조각 (위와 같은 이유)
## v0.2~v0.6 그림: 실루엣 끝에 꼭 맞춰 자름 (2026-11-12 눈으로 확인, 잘린 곳 없음). 숫자는 지금 가장자리 픽셀 수 = 더 늘면 실패
const EDGE_TIGHT := {
	"buildings/prop_aircon.png": 214, "buildings/prop_antenna.png": 32, "buildings/prop_chimney.png": 140,
	"buildings/prop_plants.png": 74, "buildings/prop_railing.png": 179, "buildings/prop_soft_antenna.png": 32,
	"buildings/prop_soft_chimney.png": 140, "buildings/prop_soft_railing.png": 179, "buildings/prop_tank.png": 51,
	"hud/heart_crack.png": 67, "hud/heart_empty.png": 66, "hud/heart_full.png": 72,
	"items/bell.png": 59, "items/can.png": 98, "items/cookie.png": 79, "items/gold.png": 44, "items/snack.png": 43,
	"items/yarn.png": 91, "obstacles/ac.png": 278, "obstacles/flock.png": 79, "obstacles/pot.png": 99, "obstacles/tank.png": 126,
}


# --- 1) 글자 모양 ---

## .gd 파일의 문자열 글자만 모은다 (주석 빼고). 화면 글자는 모두 코드나 표(mission_table.gd 등)에 문자열로 있음
static func _literals(source: String) -> PackedStringArray:
	var out := PackedStringArray()
	var i := 0
	var n := source.length()
	while i < n:
		var c := source[i]
		if c == "#":
			while i < n and source[i] != "\n":
				i += 1
		elif c == "\"" or c == "'":
			var quote := c
			var s := ""
			i += 1
			while i < n and source[i] != quote:
				if source[i] == "\\":
					i += 1  # \n \" 같은 이스케이프는 글자로 치지 않음
				else:
					s += source[i]
				i += 1
			out.append(s)
		i += 1
	return out


static func _files(dir: String, ext: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(d), ext))
	return out


## 화면에 나올 수 있는 모든 글 → 나온 곳 (파일 또는 데이터 이름)
static func screen_texts() -> Dictionary:
	var texts := {}  # 글 → 나온 곳
	for path in _files("res://scripts", ".gd"):
		if path in GLYPH_SKIP:
			continue
		for s in _literals(FileAccess.get_file_as_string(path)):
			texts[s] = path.get_file()
	for line in FileAccess.get_file_as_string("res://scenes/main.tscn").split("\n"):
		if line.begins_with("text = "):
			texts[line.trim_prefix("text = ")] = "main.tscn"
	# 코드가 만들어 내는 글 (표 값을 끼워 넣은 것)
	for id: String in MissionTable.DAILY.keys() + MissionTable.WEEKLY.keys():
		texts[Missions.text(id)] = "미션 " + id
	for kind: String in ShopScreen.UPGRADE_INFO:
		for lv in Balance.UPGRADE_MAX + 1:
			texts[ShopScreen.value_text(kind, lv)] = "강화 값 " + kind
	for s in [86399, 3599, 7 * 86400 - 1]:
		texts[DayClock.left_text(s)] = "남은 시간"
	return texts


## 글꼴에 없는 글자 → 그 글자가 나온 곳
static func missing_glyphs(font: Font) -> Dictionary:
	var texts := screen_texts()
	var missing := {}
	for s: String in texts:
		for ch in s:
			var code := ch.unicode_at(0)
			if code in [10, 9, 32] or font.has_char(code):
				continue
			if not missing.has(ch):
				missing[ch] = PackedStringArray()
			missing[ch].append("%s \"%s\"" % [texts[s], s.left(30)])
	return missing


func test_화면_글자는_모두_글꼴에_있다() -> void:
	var missing := missing_glyphs(UiKit.FONT)
	for ch: String in missing:
		_fail("글꼴에 없는 글자 '%s' (U+%04X)" % [ch, ch.unicode_at(0)], ", ".join(missing[ch]))
	assert_true(UiKit.FONT.has_char("가".unicode_at(0)) and not UiKit.FONT.has_char("→".unicode_at(0)), "검사 자체 확인: 한글은 있고 →는 없음")



## 게임 글자에 실제 상품·상표·다른 게임 이름을 쓰지 않는다 (CLAUDE.md 오픈소스 규칙, v0.7.0 디렉터 검수에서 "츄르" 발견)
const BANNED_WORDS := ["츄르", "챠오", "이나바", "쿠키런", "마리오", "포켓몬", "냥코", "고양이 대전쟁"]


func test_화면_글에_상품_이름_같은_금지어가_없다() -> void:
	var texts := screen_texts()
	assert_true(texts.size() > 100, "검사 자체 확인: 화면 글을 모았음 (%d개)" % texts.size())
	for s: String in texts:
		for word: String in BANNED_WORDS:
			if word in s:
				_fail("화면 글에 금지어 '%s'" % word, "%s \"%s\"" % [texts[s], s.left(30)])

# --- 3) 그림 가장자리 ---

static func edge_count(img: Image) -> int:
	var n := 0
	var w := img.get_width()
	var h := img.get_height()
	for x in w:
		n += int(img.get_pixel(x, 0).a > 8.0 / 255.0) + int(img.get_pixel(x, h - 1).a > 8.0 / 255.0)
	for y in range(1, h - 1):
		n += int(img.get_pixel(0, y).a > 8.0 / 255.0) + int(img.get_pixel(w - 1, y).a > 8.0 / 255.0)
	return n


func test_잘라_쓴_그림은_가장자리가_잘리지_않았다() -> void:
	var checked := 0
	for path in _files("res://assets/sprites", ".png"):
		if EDGE_TILES.any(func(p: String) -> bool: return path.begins_with(p)) \
				or ("/buildings/" in path and EDGE_TILE_NAMES.any(func(p: String) -> bool: return path.get_file().begins_with(p))):
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		var n := edge_count(img)
		var allowed: int = EDGE_TIGHT.get(path.trim_prefix("res://assets/sprites/"), 0)
		assert_true(n <= allowed, "%s 가장자리 불투명 %d (허용 %d)" % [path, n, allowed])
		checked += 1
	assert_true(checked > 50, "검사한 그림 수 %d" % checked)


# --- 2) 가장 긴 값 ---

func _clear() -> void:
	for file in [PATH, PATH + ".tmp", PATH + ".broken"]:
		DirAccess.remove_absolute(file)


## 화면 글자 폭 (한 줄)
static func text_width(label: Label) -> float:
	return label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x


## 저장을 가장 긴 값으로 채움: 생선 9,999,999, 최고 9,999,999, 전설 등급, 부스터 99개, 강화 level
func _seed_longest(level: int) -> void:
	_clear()
	var save := SaveData.open(PATH)
	save.data.wallet.fish = 9999999
	save.data.record.best_score2 = 9999999
	for kind: String in save.data.upgrades:
		save.data.upgrades[kind] = level
	for kind: String in save.data.boosters:
		save.data.boosters[kind] = Balance.BOOSTER_MAX
	save.data.rank = {"level": MissionTable.RANK_NAMES.size(), "xp": MissionTable.RANK_AFTER_MAX_XP - 1}
	save.save()


func _main() -> Control:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.record_path = PATH
	main.clock.fixed = {"year": 2026, "month": 11, "day": 16, "hour": 0, "minute": 0, "second": 1}  # 월요일 0시: 남은 시간이 가장 긺
	add_child(main)
	return main


## 글자가 실제로 그려지는 자리 (글 칸 자기 좌표). 줄바꿈 없는 글은 가로·세로 맞춤까지 계산
static func ink_local(l: Label) -> Rect2:
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF or "\n" in l.text:
		return Rect2(Vector2.ZERO, l.size)
	var w := text_width(l)
	var h := float(l.get_line_height())
	var x := 0.0
	var y := 0.0
	if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x = (l.size.x - w) * 0.5
	elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x = l.size.x - w
	if l.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		y = (l.size.y - h) * 0.5
	elif l.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		y = l.size.y - h
	return Rect2(x, y, w, h)


static func ink_rect(l: Label) -> Rect2:
	return QA.moved(l.get_global_transform(), ink_local(l))


## 그림이 실제로 그려지는 자리 (그림 자기 좌표, 비율 유지 가운데 맞춤)
static func art_local(t: TextureRect) -> Rect2:
	if t.texture and t.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		var tex := t.texture.get_size()
		var drawn := tex * minf(t.size.x / tex.x, t.size.y / tex.y)
		return Rect2((t.size - drawn) * 0.5, drawn)
	return Rect2(Vector2.ZERO, t.size)


## 칸에서 글자가 들어갈 수 있는 안쪽 (칸 좌표). 종이·버튼은 손그림 테두리 두께만큼 안쪽 (2c-fix 눈 검수: 바깥 사각형만 보면
## 숫자 끝이 테두리 선에 닿아도 통과했음). 둥근 끝(높이의 절반)이 있는 띠·버튼은 양 끝을 더 들임
const PAPER_EDGE := 8.0
static func inner(cell: Control) -> Rect2:
	var r := Rect2(Vector2.ZERO, cell.size)
	if cell is Panel or cell is Button:
		var round_end := minf(cell.size.y * 0.25, 22.0) if cell.size.x > cell.size.y * 1.5 else PAPER_EDGE
		return r.grow_individual(-maxf(PAPER_EDGE, round_end), -PAPER_EDGE, -maxf(PAPER_EDGE, round_end), -PAPER_EDGE)
	return r.grow(1.0)


## 줄바꿈 글이 낱말 중간에서 끊기면 그 줄들을 "/"로 이어 돌려줌 (없으면 ""). Godot은 한글을 글자 사이에서도 끊어
## "길어져 / 요."처럼 끝 글자가 혼자 남음 (2c-fix 눈 검수). Label과 같은 폭·글꼴로 줄을 나눠 보고, 띄어쓰기·줄바꿈 뒤에서만 끊겼는지 본다
static func word_break(l: Label) -> String:
	if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		return ""
	var para := TextParagraph.new()
	para.width = l.size.x
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	para.add_string(l.text, l.get_theme_font("font"), l.get_theme_font_size("font_size"))
	var lines := PackedStringArray()
	var bad := false
	for i in para.get_line_count():
		var r := para.get_line_range(i)
		lines.append(l.text.substr(r.x, r.y - r.x).strip_edges())
		if i > 0 and r.x > 0 and not l.text[r.x - 1] in [" ", "\n"] and not l.text[r.x] in [" ", "\n"]:
			bad = true
	return " / ".join(lines) if bad else ""


## 보이는 메뉴 글자마다: 칸 안, 화면 안, 줄인 글자 크기 UiKit.FONT_MIN 이상, 다른 글자·그림과 안 겹침. 문제 목록을 돌려줌
static func layout_problems(main: Control, what: String) -> PackedStringArray:
	var out := PackedStringArray()
	var view := main.get_viewport_rect().grow(1.0)
	var labels: Array[Label] = []
	var arts: Array[TextureRect] = []
	for node in main.find_children("*", "Label", true, false):
		var l: Label = node
		if l.is_visible_in_tree() and QA.in_menu(l) and l.text.strip_edges() != "" and l.modulate.a > 0.01:
			labels.append(l)
	for node in main.find_children("*", "TextureRect", true, false):
		var t: TextureRect = node
		if t.is_visible_in_tree() and QA.in_menu(t) and t.texture:
			arts.append(t)
	for l in labels:
		var ink := ink_rect(l)
		var cell := QA.cell_of(l)
		var in_cell := QA.moved(cell.get_global_transform().affine_inverse() * l.get_global_transform(), ink_local(l))  # 칸 좌표 (칸이 기울어도)
		if not inner(cell).encloses(in_cell):
			out.append("%s \"%s\" 칸(%s) 밖 %s ⊄ %s" % [what, l.text, cell.name, in_cell, cell.size])
		if not view.encloses(ink):
			out.append("%s \"%s\" 화면 밖 %s" % [what, l.text, ink])
		if l.get_theme_font_size("font_size") < UiKit.FONT_MIN:
			out.append("%s \"%s\" 글자 크기 %d < %d" % [what, l.text, l.get_theme_font_size("font_size"), UiKit.FONT_MIN])
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.get_line_count() > l.get_visible_line_count():
			out.append("%s \"%s\" 줄이 넘침" % [what, l.text])
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and "\n" in l.text:  # 직접 나눈 줄도 줄마다 칸 폭 안
			for line in l.text.split("\n"):
				var w := l.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
				if w > l.size.x + 1.0:
					out.append("%s \"%s\" 줄 폭 %.0f > %.0f" % [what, line, w, l.size.x])
		var broken := word_break(l)
		if broken != "":
			out.append("%s 낱말 중간 줄바꿈 \"%s\"" % [what, broken])
		# 겹침은 이 글자 좌표에서 비교 (같이 기울어진 쪽지·배지 안에서도 정확하게)
		var mine := ink_local(l).grow(-2.0)
		var to_mine := l.get_global_transform().affine_inverse()
		for other in labels:
			if other.get_instance_id() < l.get_instance_id() \
					and mine.intersects(QA.moved(to_mine * other.get_global_transform(), ink_local(other)).grow(-2.0)):
				out.append("%s 글자 겹침 \"%s\" / \"%s\"" % [what, l.text, other.text])
		for t in arts:
			# 그림 위에 글자를 올리지 않는다 (핀·집게·도장·아이콘)
			if mine.intersects(QA.moved(to_mine * t.get_global_transform(), art_local(t)).grow(-2.0)):
				out.append("%s 글자 \"%s\" 와 그림 %s 겹침" % [what, l.text, t.texture.resource_path.get_file()])
	return out


func _expect_clean(main: Control, what: String) -> void:
	for p in layout_problems(main, what):
		_fail(p, "")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func test_가장_긴_값으로_채워도_글자가_칸_안에_있고_겹치지_않는다() -> void:
	var window := get_window()
	var keep := window.size
	for size in [Vector2i(1280, 720), Vector2i(844, 390)]:
		window.size = size
		for level in [0, Balance.UPGRADE_MAX]:
			_seed_longest(level)
			var main := _main()
			QA.fill_longest(main.save.data)
			await wait_frames(30)
			main.start_menu.refresh()
			main.boosters_on = ["dash_start", "bell_start", "fish_bonus"]
			main.start_menu.boosters.refresh()
			await wait_frames(2)
			_expect_clean(main, "시작 %s 강화%d" % [size, level])
			for tab in ["upgrades", "boosters"]:
				main.open_shop(tab)
				await wait_frames(2)
				for kind: String in main.shop._info():
					main.shop.selected = kind
					main.shop.refresh()
					await wait_frames(2)
					_expect_clean(main, "상점 %s %s 강화%d" % [size, kind, level])
				main.go_back()
				await _wait(MenuScreen.OPEN_TIME + 0.1)
			main.open_missions()
			await wait_frames(5)
			_expect_clean(main, "미션 %s" % size)
			main.board.swap_pressed(false, 2)  # "정말?" 상태
			await wait_frames(2)
			_expect_clean(main, "미션 정말 %s" % size)
			main.go_back()
			await _wait(MenuScreen.OPEN_TIME + 0.1)
			if level == 0:
				main.queue_free()
				await wait_frames(2)
				continue
			# 결과 카드: 숫자 최대 + 깬 미션 4개(가장 긴 문구) + 여러 등급 오름(부스터 3개 보너스)
			main.begin_run()
			await wait_frames(2)
			var world: Node2D = main.get_node("World")
			world.sim.parade.fill(Balance.PARADE_MAX)  # 줄줄이 시험판: "데려온 고양이 6마리" + 얼굴 6개
			world.sim.on_ground = false
			world.sim.y = Balance.FALL_LIMIT + 1.0
			world.sim.vy = -1000.0
			await wait_frames(3)
			main._result.values = [99999, 99999, 9999, 9999999]
			main._result.bonus = true
			main._result.t = 999.0
			main._count_result(0.0)
			var done := []
			for id in QA.longest_missions(MissionTable.DAILY, 2) + QA.longest_missions(MissionTable.WEEKLY, 2):
				done.append({"id": id, "fish": 99999})
			main._extras.play({"done": done, "ranks": [{"level": 9, "fish": 99999, "boosters": ["dash_start"]},
					{"level": 10, "fish": 99999, "boosters": ["bell_start", "fish_bonus"]}]}, main.get_node("GameOver/Card").get_global_rect())
			await _wait(ResultExtras.NOTE_GAP * 4.0 + 0.8)
			_expect_clean(main, "결과 %s" % size)
			main.queue_free()
			await wait_frames(2)
	window.size = keep
	_clear()


## 줄줄이 시험판 HUD: 콤보 아래 배수 + 얼굴 6개가 화면 안이고 콤보·점수·질주 배율 글자와 겹치지 않는다 (콤보 9999, 점수 9,999,999)
func test_줄줄이_HUD_6마리_가장_긴_값() -> void:
	var window := get_window()
	var keep := window.size
	for size in [Vector2i(1280, 720), Vector2i(844, 390)]:
		window.size = size
		_seed_longest(0)
		var main := _main()
		await wait_frames(5)
		main.begin_run()
		await wait_frames(2)
		var sim: RunnerSim = main.get_node("World").sim
		sim.parade.fill(Balance.PARADE_MAX)
		sim.combo.count = 9999
		sim.combo.points = 9999999
		sim.dashing = true  # 질주 배율 "x2"도 보이게
		await wait_frames(3)
		var view := main.get_viewport_rect().grow(1.0)
		var hud: Control = main.get_node("ParadeHud")
		var mult: Label = hud.get_node("Mult")
		assert_eq(mult.text, "x2.2", "6마리 배수")
		var rects := {"배수": ink_rect(mult)}
		for face: TextureRect in hud.get_node("Faces").get_children():
			assert_true(face.visible, "얼굴 6개")
			rects[face.name] = face.get_global_rect()
		for key: String in rects:
			assert_true(view.encloses(rects[key]), "%s %s 화면 안 %s" % [size, key, rects[key]])
			for other: Label in [main.get_node("ComboLabel"), main.get_node("ScoreLabel"), main.get_node("DashBonus")]:
				assert_false(rects[key].grow(-1.0).intersects(ink_rect(other)), "%s %s / \"%s\" 겹침" % [size, key, other.text])
		main.queue_free()
		await wait_frames(2)
	window.size = keep
	_clear()


func test_화면_글은_띄어쓰기에서만_줄을_바꾼다() -> void:
	var text := "츄르를 먹고 무적으로 달리는 시간이 길어져요."
	var out := UiKit.wrap(text, 30, 300)
	assert_eq(out.replace("\n", " "), text, "낱말은 그대로, 줄바꿈은 띄어쓰기 자리에만")
	assert_true(out.count("\n") >= 1, "좁으면 줄이 나뉨")
	for line in out.split("\n"):
		assert_true(UiKit.FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x <= 300.0, "줄 폭 \"%s\"" % line)
	assert_eq(UiKit.wrap("가\n나 다", 30, 999), "가\n나 다", "원래 줄바꿈 유지")
	# 화면 글에 Godot 자동 줄바꿈(한글을 글자 사이에서 끊음)을 쓰지 않는다
	for path in _files("res://scripts", ".gd"):
		assert_false("autowrap_mode = TextServer.AUTOWRAP_WORD" in FileAccess.get_file_as_string(path), "%s: UiKit.wrap을 쓸 것" % path)
