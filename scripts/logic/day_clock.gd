class_name DayClock
extends RefCounted
## 미션 날짜 (화면과 분리된 로직, review/v0.7.0/PLAN.md 7번).
## 기기 지역 시간 기준. 일일 키 = "YYYY-MM-DD", 주간 키 = 그 주 월요일의 일일 키 (0시에 바뀜).
## 한 사람용이라 시간 조작은 막지 않는다.

## 테스트·시험 패널용: 비어 있지 않으면 기기 시간 대신 이 시각 (Time의 datetime 사전 모양)
var fixed := {}
## 시험 패널의 "하루 넘기기": 기기 시간에 더할 날 수
var offset_days := 0


## 지금 시각 (지역 시간 datetime 사전)
func now() -> Dictionary:
	var at := fixed if not fixed.is_empty() else Time.get_datetime_dict_from_system()
	return shift(at, offset_days)


## at에서 days일 뒤 (지역 시간 그대로 날짜만 셈: 지역 시각을 UTC인 척 계산해 시간대·서머타임과 무관)
static func shift(at: Dictionary, days: int) -> Dictionary:
	var unix := Time.get_unix_time_from_datetime_dict(at) + days * 86400
	return Time.get_datetime_dict_from_unix_time(unix)


static func day_key(at: Dictionary) -> String:
	return "%04d-%02d-%02d" % [at.year, at.month, at.day]


## 그 주 월요일의 일일 키 (Godot weekday: 0 = 일요일)
static func week_key(at: Dictionary) -> String:
	var date := {"year": at.year, "month": at.month, "day": at.day}
	var weekday: int = Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_dict(date)).weekday
	return day_key(shift(date, -((weekday + 6) % 7)))


## 다음 자정까지 남은 초 (일일 미션 남은 시간)
static func seconds_to_next_day(at: Dictionary) -> int:
	var midnight := {"year": at.year, "month": at.month, "day": at.day, "hour": 0, "minute": 0, "second": 0}
	return int(Time.get_unix_time_from_datetime_dict(shift(midnight, 1)) - Time.get_unix_time_from_datetime_dict(at))


## 다음 월요일 0시까지 남은 초 (주간 미션 남은 시간)
static func seconds_to_next_week(at: Dictionary) -> int:
	var parts := week_key(at).split("-")
	var monday := {"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]), "hour": 0, "minute": 0, "second": 0}
	return int(Time.get_unix_time_from_datetime_dict(shift(monday, 7)) - Time.get_unix_time_from_datetime_dict(at))


## 남은 시간 글자: 하루 넘으면 "3일 4시간", 아니면 "5시간 12분", 1시간 안이면 "12분"
static func left_text(seconds: int) -> String:
	var minutes := maxi(seconds, 0) / 60
	if minutes >= 24 * 60:
		return "%d일 %d시간" % [minutes / (24 * 60), minutes / 60 % 24]
	if minutes >= 60:
		return "%d시간 %d분" % [minutes / 60, minutes % 60]
	return "%d분" % maxi(minutes, 1)
