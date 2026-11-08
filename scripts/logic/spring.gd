class_name Spring
extends RefCounted
## 감쇠 스프링: 고양이 몸 배율(가로, 세로)이 목표 모양을 출렁이며 따라가게 한다 (화면과 분리된 순수 계산).
## 지수 보간은 짧은 눌림을 지워 버리지만, 스프링은 "충격"(kick)을 받으면 넘쳤다가 돌아와 말랑해 보인다.
## 프레임이 바뀌어 목표 배율이 튀어도 값은 이어서 움직이므로 끊기지 않는다.

## 1/240초보다 큰 시간은 잘게 나눠 계산한다 (프레임이 늦게 와도 터지지 않게)
const MAX_SUBSTEP := 1.0 / 240.0

var value: Vector2
var velocity := Vector2.ZERO
var omega: float     # 고유 각진동수 (라디안/초)
var damping: float   # 감쇠비 (1보다 작으면 넘쳤다가 돌아옴)


func _init(frequency_hz: float, damping_ratio: float, start := Vector2.ONE) -> void:
	omega = TAU * frequency_hz
	damping = damping_ratio
	value = start


## 목표(target)를 향해 dt초 움직이고 지금 값을 돌려준다
func step(target: Vector2, dt: float) -> Vector2:
	var left := dt
	while left > 0.0:
		var h := minf(left, MAX_SUBSTEP)
		# 반암시적 오일러: 속도를 먼저 바꾸고 그 속도로 움직여 안정적
		velocity += (omega * omega * (target - value) - 2.0 * damping * omega * velocity) * h
		value += velocity * h
		left -= h
	return value


## 순간 충격: 지금 모양에서 offset만큼 (예: 착지 = (+0.2, -0.2)) 가장 크게 벗어났다가 출렁이며 돌아오게 속도를 더한다
func kick(offset: Vector2) -> void:
	velocity += offset * kick_gain()


## 정지 상태에서 속도 v를 받으면 가장 멀리 가는 거리 = v / kick_gain() (감쇠 진동의 첫 꼭대기)
func kick_gain() -> float:
	var z := clampf(damping, 0.001, 0.999)
	return omega * exp(z * omega * peak_time())


## 충격 뒤 가장 크게 벗어나는 데 걸리는 시간 (초)
func peak_time() -> float:
	var z := clampf(damping, 0.001, 0.999)
	return atan(sqrt(1.0 - z * z) / z) / (omega * sqrt(1.0 - z * z))
