extends TestCase
## 프로젝트 기본 구조와 웹 내보내기 설정 테스트.


func test_게임_버전은_메이저_마이너_패치_형식() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var regex := RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+$")
	assert_not_null(regex.search(version), "버전 '%s'" % version)


func test_웹에서_동작하는_렌더러를_사용() -> void:
	# 웹 내보내기는 Compatibility(OpenGL) 렌더러만 지원한다.
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility")


func test_웹_내보내기는_스레드_없이_설정됨() -> void:
	# 스레드 지원을 켜면 GitHub Pages(COOP/COEP 헤더 없음)에서 실행되지 않는다.
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK, "export_presets.cfg 읽기")
	var web_section := ""
	for section in presets.get_sections():
		if presets.get_value(section, "platform", "") == "Web":
			web_section = section
	assert_eq(web_section, "preset.0", "Web 프리셋")
	assert_eq(presets.get_value(web_section, "name", ""), "Web", "프리셋 이름 (배포 워크플로가 이 이름을 씀)")
	assert_eq(presets.get_value(web_section + ".options", "variant/thread_support", true), false, "스레드 지원 끔")
	assert_eq(presets.get_value(web_section, "export_path", ""), "build/web/index.html", "내보내기 위치")
	var excluded := str(presets.get_value(web_section, "exclude_filter", ""))
	for folder in ["tests/*", "tools/*", "build/*", "_site/*", "assets/raw/*", "assets/concept/*", "assets/sprites/cat_concept_*", "assets/sprites/cat_mascot_*"]:
		assert_true(excluded.contains(folder), "내보내기 제외: " + folder)


func test_내보내기_결과물_폴더는_리소스로_가져오지_않음() -> void:
	# build/ 안의 이전 빌드(그림 등)가 다음 빌드에 섞여 들어가지 않게 한다.
	assert_true(FileAccess.file_exists("res://build/.gdignore"), "build/.gdignore")


func test_시작_씬이_존재함() -> void:
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	assert_eq(main_scene, "res://scenes/main.tscn")
	assert_true(ResourceLoader.exists(main_scene), "시작 씬 파일")



func test_모바일_가로_화면_기준() -> void:
	# 0 = 가로(landscape). 기준 해상도도 가로가 더 길어야 한다.
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 0)
	assert_true(ProjectSettings.get_setting("display/window/size/viewport_width") > ProjectSettings.get_setting("display/window/size/viewport_height"), "가로가 더 긺")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand", "화면 비율이 달라도 꽉 채움")


func test_시작_화면에_게임_버전이_보임() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait_frames()
	var version := str(ProjectSettings.get_setting("application/config/version"))
	assert_eq(main.get_node("VersionLabel").text, "v" + version)
	main.queue_free()
