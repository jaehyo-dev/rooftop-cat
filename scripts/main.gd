extends Control
## 시작 화면: 게임 화면(World)과 버전 표시.


func _ready() -> void:
	# 버전은 project.godot 한 곳에서 읽는다.
	$VersionLabel.text = "v" + str(ProjectSettings.get_setting("application/config/version"))
