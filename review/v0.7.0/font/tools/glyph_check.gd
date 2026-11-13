## 후보 글꼴 글자 검사: tests/test_ui_quality.gd의 missing_glyphs(4-1 글자 모양 검사)를 후보 글꼴 파일마다 돌린다.
## 사용: godot --headless --path . -s res://... 대신 review/는 .gdignore라서 절대 경로로: godot --headless --path . -s <이 파일 절대 경로> -- <글꼴.ttf>...
extends SceneTree

func _init() -> void:
	var q = load("res://tests/test_ui_quality.gd")
	for path in OS.get_cmdline_user_args():
		var f := FontFile.new()
		if f.load_dynamic_font(path) != OK:
			print("열기 실패 ", path)
			continue
		var missing: Dictionary = q.missing_glyphs(f)
		print("== %s : 없는 글자 %d" % [path.get_file(), missing.size()])
		for ch: String in missing:
			print("  '%s' U+%04X  %s" % [ch, ch.unicode_at(0), ", ".join(missing[ch]).left(160)])
	quit()
