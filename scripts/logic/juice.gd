class_name Juice
## 손맛 연출의 순수 계산 (화면과 분리, 2b): 화면 흔들림, 결과 숫자 차오름, 심장 박동 박자, 질주 시작 당김, 켜고 끄는 페이드.

## 결과 화면에서 숫자 하나가 0에서 끝까지 차오르는 시간 (초). 앞 숫자가 다 차야 다음 숫자가 시작한다
const COUNT_UP_EACH := 0.35
## 하트 1개일 때 박동 박자: 1초에 한 번, HUD 두근거림(|sin(PI t)|)이 가장 클 때(t = n + 0.5)보다 조금 앞에서 소리
const BEAT_PHASE := 0.4


## 질주 시작 순간 화면이 고양이 쪽으로 당겨지는 정도 (0~1): PUNCH_IN초에 다 당겨지고 멈칫(PUNCH_HOLD) 뒤 PUNCH_OUT초에 걸쳐 풀림
const PUNCH_IN := 0.06
const PUNCH_HOLD := 0.1
const PUNCH_OUT := 0.35


## 흔들림: since초 전에 세기 strength(픽셀)로 duration초 흔들기 시작했을 때 화면 어긋남. 갈수록 잦아든다 (무작위 없이 사인 두 개)
static func shake_offset(since: float, duration: float, strength: float) -> Vector2:
	if since >= duration or duration <= 0.0:
		return Vector2.ZERO
	var fade := 1.0 - since / duration
	return Vector2(sin(since * 97.0), cos(since * 71.0)) * strength * fade * fade


## 결과 숫자들이 하나씩 차오른 값 (t = 결과 화면이 뜬 뒤 지난 초)
static func count_up(values: Array, t: float) -> Array[int]:
	var out: Array[int] = []
	for i in values.size():
		var k := clampf(t / COUNT_UP_EACH - i, 0.0, 1.0)
		out.append(roundi(values[i] * (1.0 - (1.0 - k) * (1.0 - k))))  # 빠르게 오르다 끝에서 천천히
	return out


## 결과 숫자가 다 찼는지
static func count_done(values: Array, t: float) -> bool:
	return t >= COUNT_UP_EACH * values.size()


## before → now 사이에 박동 소리 박자를 지났는지 (판 안 시각, 새 판이면 시각이 되돌아간다)
static func beat_crossed(before: float, now: float) -> bool:
	return now > before and floorf(now - BEAT_PHASE) > floorf(before - BEAT_PHASE)


## 질주 시작 당김 (since = 질주 시작 뒤 지난 초). 빨리 당기고 부드럽게 푼다
static func dash_punch(since: float) -> float:
	if since < 0.0 or since >= PUNCH_HOLD + PUNCH_OUT:
		return 0.0
	if since < PUNCH_IN:
		return since / PUNCH_IN
	if since < PUNCH_HOLD:
		return 1.0
	var k := 1.0 - (since - PUNCH_HOLD) / PUNCH_OUT
	return k * k * (3.0 - 2.0 * k)


## 켜짐(on)이면 in_time초, 꺼짐이면 out_time초에 걸쳐 0~1 사이를 일정하게 움직인다 (질주 북 소리, 노을빛)
static func fade(value: float, on: bool, delta: float, in_time: float, out_time: float) -> float:
	return move_toward(value, 1.0 if on else 0.0, delta / (in_time if on else out_time))
