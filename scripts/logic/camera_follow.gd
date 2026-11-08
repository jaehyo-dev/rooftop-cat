class_name CameraFollow
## 세로 카메라 (그림만 움직임, 판정과 무관한 순수 계산).
## 고양이 머리가 화면 위 HEAD_MARGIN보다 올라가면 화면 전체를 아래로 내려(= 카메라가 위로) 따라간다.
## 올라갈 때는 부드럽게, 내려올 때는 빠르게. 최대는 "고양이가 내려앉을 옥상 윗면이 화면 아래에서 GROUND_MARGIN 위에 남는" 값까지.
## lift = 화면을 아래로 내리는 픽셀 (0이면 지금과 같은 화면).

const HEAD_MARGIN := 110.0    # 머리가 화면 위에서 이만큼 안쪽에 있게
const GROUND_MARGIN := 80.0   # 내려앉을 옥상 윗면이 화면 아래에서 이만큼 위에 남게
const RISE_RATE := 6.0        # 따라 올라가는 빠르기 (1초에 남은 거리의 약 1 - e^-6)
const FALL_RATE := 14.0       # 따라 내려오는 빠르기 (더 빠르게)


## 지금 있어야 할 lift. feet_y = 고양이 발 높이, landing_top = 내려앉을 옥상 높이(없으면 0), view_h = 화면 높이
static func target(feet_y: float, landing_top: float, view_h: float) -> float:
	var head := feet_y + Balance.CAT_BODY_SIZE.y
	var want := head + HEAD_MARGIN - view_h  # 머리를 화면 위 HEAD_MARGIN에 두는 lift
	return clampf(want, 0.0, maxf(0.0, landing_top - GROUND_MARGIN))


## current에서 goal로 dt초 동안 다가간 lift (올라갈 때 느리게, 내려올 때 빠르게)
static func follow(current: float, goal: float, dt: float) -> float:
	var rate := RISE_RATE if goal > current else FALL_RATE
	return lerpf(current, goal, 1.0 - exp(-rate * dt))
