extends Control
## 시작 화면 (0단계: 빈 화면 + 버전 표시).


func _ready() -> void:
	# 버전은 project.godot 한 곳에서 읽는다.
	$VersionLabel.text = "v" + str(ProjectSettings.get_setting("application/config/version"))
