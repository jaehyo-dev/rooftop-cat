class_name Juice
## 손맛 연출의 순수 계산 (화면과 분리, 2b): 화면 흔들림, 결과 숫자 차오름, 심장 박동 박자.

## 결과 화면에서 숫자 하나가 0에서 끝까지 차오르는 시간 (초). 앞 숫자가 다 차야 다음 숫자가 시작한다
const COUNT_UP_EACH := 0.35
## 하트 1개일 때 박동 박자: 1초에 한 번, HUD 두근거림(|sin(PI t)|)이 가장 클 때(t = n + 0.5)보다 조금 앞에서 소리
const BEAT_PHASE := 0.4


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
