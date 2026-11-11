class_name TestCase
extends Node
## 자동 테스트의 기본 클래스.
## tests/test_*.gd 파일에서 이 클래스를 상속하고 test_ 로 시작하는 함수를 만들면
## tests/run_tests.gd가 찾아서 실행한다. 함수 안에서 await를 써도 된다.

## 현재 실행 중인 테스트 함수의 실패 메시지 목록
var failures: PackedStringArray = []
## 이 글이 든 엔진 오류는 테스트가 일부러 낸 것이라 실패로 치지 않는다 (예: 깨진 저장 파일 읽기)
var expected_errors: PackedStringArray = []


## 속도 단계 표의 서로 다른 속도들 (옥상·구조물 테스트가 단계마다 확인한다)
static func stage_speeds() -> Array:
	var speeds := []
	for stage in Balance.SPEED_STAGES:
		if not speeds.has(stage[1]):
			speeds.append(stage[1])
	return speeds


## 조건이 참이어야 한다.
func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_fail("참이어야 함", message)


## 조건이 거짓이어야 한다.
func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		_fail("거짓이어야 함", message)


## 두 값이 같아야 한다.
func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		_fail("기대값 %s, 실제값 %s" % [var_to_str(expected), var_to_str(actual)], message)


## 값이 null이 아니어야 한다.
func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		_fail("null이 아니어야 함", message)


## 다음 프레임까지 기다린다 (씬 테스트용).
func wait_frames(count: int = 1) -> void:
	for i in count:
		await get_tree().process_frame


func _fail(reason: String, message: String) -> void:
	failures.append(reason if message.is_empty() else "%s - %s" % [message, reason])
