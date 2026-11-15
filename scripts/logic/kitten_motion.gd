class_name KittenMotion
extends RefCounted
## 아기 고양이 움직임 (cat-parade 1단계 A·B 비교, 화면과 분리된 계산. 그리기는 kitten_view.gd).
## 아기는 주인공이 지난 길(위치)만 따라가고 자세는 아기 자신의 상태로 고른다:
## 땅 = 아기 달리기, 오를 때·내릴 때 = 속도 방향으로 기울인 공중 자세, 닿는 순간 = 착지 눌림 + 작은 먼지.
## 달리기는 시간·주인공 프레임이 아니라 아기가 달린 거리로 넘긴다 (빨라져도 발이 미끄러지지 않게).
## A = 8장 프레임: 장마다 KittenMotionData.A_ADVANCE만큼 달리면 다음 장 (tools/cut_kitten_motion.py가 잼).
## B = 조각 인형: 다리 4개가 걸음 박자에 따라 디디고(디딘 발의 세계 x 고정) 들려 앞으로 감. 다리는 축 → 발 방향으로 돌리고 늘인다.
## 땅 위에서는 몸 전체를 들어 올리지 않는다. 통통 튐은 발끝을 축으로 세로로만 살짝 눌리는 것 (발 x·높이 그대로).

const LAND_TIME := 0.2       # 닿은 뒤 착지 눌림 시간 (초). 0.14는 처음 보는 눈 1차에 "착지 웅크림이 없다"
const LAND_SQUASH := 0.25    # 닿는 순간 세로 눌림 (곧게 풀림: 제곱으로 풀면 너무 빨리 펴져 안 보임, 2차 검토)
const TAKEOFF_TIME := 0.1    # 뜬 뒤 도약 자세 시간 (초)
const DUST_TIME := 0.3       # 착지 먼지가 퍼졌다 사라지는 시간
const MAX_TILT := 0.35       # 공중 기울기 한계 (라디안)
const TILT_PER_SLOPE := 0.5  # 길 기울기(dy/dx)를 몸 기울기로 바꾸는 비율
const STEP_SQUASH := Vector2(0.015, 0.035)  # 걸음마다 세로 눌림 (아이마다 이 사이, 개성)

## B 걸음새: 네 발이 차례로 디딤 (뒤 가까운 → 앞 가까운 → 뒤 먼 → 앞 먼), 한 발이 한 바퀴의 B_DUTY만큼 디딤.
## 0.4 x 4 = 1.6이라 늘 한 발 이상이 바닥에 있다 (0.3은 발이 공중에 오래 있어 제자리걸음처럼 보임, 3차 검토)
const B_DUTY := 0.4
const B_PHASE := {"hind_near": 0.0, "front_near": 0.25, "hind_far": 0.5, "front_far": 0.75}
const B_REACH_DEG := 42.0    # 디딘 다리가 앞뒤로 기우는 최대 각도 (45는 뒷다리가 빠진 것처럼 꺾임 1차, 38은 꼼지락거림 2차)
const B_STRETCH := 1.12      # 디딘 다리가 늘어날 수 있는 만큼 (몸이 덜 출렁이게)
const B_LIFT := 0.35         # 들린 발 높이 = 다리 길이 x
const B_LEGS := ["hind_far", "front_far", "hind_near", "front_near"]
## 공중 자세: 발 자리 = 축 + (다리 길이 x 이 값). [앞다리, 뒷다리]
const B_AIR := {
	"takeoff": [Vector2(0.45, 0.8), Vector2(-0.75, 0.7)],
	"rise": [Vector2(0.6, 0.65), Vector2(-0.6, 0.7)],
	"fall": [Vector2(0.35, 0.95), Vector2(-0.25, 0.9)],
}

## 공중 몸 늘임 (발끝 축 가로·세로 배율): 오를 때 앞뒤로 길게, 내릴 때 살짝 세로로
const AIR_STRETCH := {"takeoff": Vector2(1.08, 0.95), "rise": Vector2(1.06, 0.96), "fall": Vector2(0.97, 1.04)}

## 도망: "!" 멈칫(달리던 속도를 줄이며 끼익 멈춤 + 작게 펄쩍) → 몸 돌림 → 바닥을 디디며 뒤로 달림 (가속 RUNAWAY_ACCEL초).
## 멈칫 동안 바로 세우면 화면에서 0.15초 만에 왼쪽 밖으로 사라져(1차 검토) 줄 속도에서 서서히 멈춘다
const STARTLE := 0.2
const STARTLE_CROUCH := 0.05 # 멈칫 처음: 움츠렸다가 펄쩍 (2차 검토: 갑자기 붕 뜸)
const TURN := 0.1
const FLEE_LEAN := 0.15      # 도망 달리기: 몸을 앞으로 숙임 (라디안, 2차 검토: 꼿꼿이 서서 미끄러져 감)
const STARTLE_HOP := 12.0    # 놀라 펄쩍 (게임 픽셀)
const TURN_POP := 0.82       # 몸을 돌릴 때: 반에서 휙 뒤집으며 가로로 이만큼 좁아졌다 펴짐 (0까지 줄이면 사라짐 1차, 얇게 도는 건 종잇장 같음 2차)
const RUNAWAY_SPEED := 260.0
const RUNAWAY_ACCEL := 0.12
const RUNAWAY_GRAVITY := 2600.0


## 아기 그림 캔버스 픽셀 → 게임 픽셀 (예전 아기와 같은 크기: cat_view.gd KITTEN_ART x 주인공 배율 x 아기 크기)
static func px() -> float:
	return CatView.KITTEN_ART * CatView.art_scale() * Balance.PARADE_SIZE


## 기록 sample(+ 붙는 중 덮어쓴 "kind") + 길 기울기(dy/dx, 위가 +) → {"kind", "tilt", "land_k"(0~1, 1 = 착지 끝)}
static func state(sample: Dictionary, slope: float) -> Dictionary:
	if sample.has("kind"):
		var tilt := 0.0 if sample.kind == "crouch" else clampf(-atan(slope) * TILT_PER_SLOPE, -MAX_TILT, MAX_TILT)
		return {"kind": sample.kind, "tilt": tilt, "land_k": 1.0}
	if sample.get("ground", true):
		var land: float = sample.get("since_land", 9.0)
		return {"kind": "run", "tilt": 0.0, "land_k": clampf(land / LAND_TIME, 0.0, 1.0)}
	var jump: float = sample.get("since_jump", 9.0)
	var kind := "takeoff" if jump < TAKEOFF_TIME else ("rise" if slope > 0.0 else "fall")
	return {"kind": kind, "tilt": clampf(-atan(slope) * TILT_PER_SLOPE, -MAX_TILT, MAX_TILT), "land_k": 1.0}


## 세로 배율 (발끝 축): 착지 눌림 + 걸음마다 작은 눌림 (q = 아이 개성 0~1, phase = 걸음 0~1)
static func squash(land_k: float, phase: float, q: float) -> float:
	var step := lerpf(STEP_SQUASH.x, STEP_SQUASH.y, q) * (0.5 + 0.5 * cos(TAU * 2.0 * phase))
	return 1.0 - step - LAND_SQUASH * (1.0 - land_k)


# --- A: 프레임 ---

## 한 바퀴 거리 (게임 픽셀)
static func a_stride() -> float:
	var total := 0.0
	for a in KittenMotionData.A_ADVANCE:
		total += a
	return total * px()


## 달린 거리 → 달리기 장 번호와 바퀴 안 위치 0~1
static func a_frame(dist: float) -> int:
	var d := fposmod(dist / px(), a_stride() / px())
	for k in KittenMotionData.A_ADVANCE.size():
		d -= KittenMotionData.A_ADVANCE[k]
		if d < 0.0:
			return k
	return KittenMotionData.A_ADVANCE.size() - 1


# --- B: 조각 인형 (부품 그림 픽셀. 게임 픽셀 = 이 값 x b_scale()) ---

static func b_scale() -> float:
	return KittenMotionData.B_ART * px()


## 다리 길이 (축 → 발바닥)
static func b_len(leg: String) -> float:
	return KittenMotionData.B_SIZE[leg][1] - 4.0 - KittenMotionData.B_PIVOT[leg][1]


## 서 있을 때 축 자리 (발끝 원점, 몸통 그림 좌표를 앞·뒤 축 가운데 / 가장 긴 다리 발바닥에 맞춰 옮김)
static func b_hip(leg: String) -> Vector2:
	var at: Array = KittenMotionData.B_PLACE["front" if leg.begins_with("front") else "hind"]
	var shift: float = KittenMotionData.B_FAR_SHIFT if leg.ends_with("far") else 0.0
	return Vector2(at[0] + shift, at[1]) - b_torso_origin()


## 몸통 그림 좌상단 → 발끝 원점까지 (몸통 좌표에서 원점이 있는 자리)
static func b_torso_origin() -> Vector2:
	var pl: Dictionary = KittenMotionData.B_PLACE
	var ground := 0.0
	for leg in B_LEGS:
		var at: Array = pl["front" if leg.begins_with("front") else "hind"]
		ground = maxf(ground, at[1] + b_len(leg))
	return Vector2((pl.front[0] + pl.hind[0]) * 0.5, ground)


static func b_reach() -> float:
	var shortest := INF
	for leg in B_LEGS:
		shortest = minf(shortest, b_len(leg))
	return shortest * sin(deg_to_rad(B_REACH_DEG))


## 한 바퀴 거리 (게임 픽셀)
static func b_stride() -> float:
	return 2.0 * b_reach() / B_DUTY * b_scale()


## 달리기: 다리 이름 → {"hip", "foot"} (부품 픽셀, 발끝 원점, y 아래 +), "drop" = 몸이 내려앉은 만큼.
## 디딘 발은 바퀴 안에서 +reach → -reach로 축 뒤로 가고 몸이 그만큼 앞으로 가 세계에서 제자리. 들린 발은 -reach → +reach로 넘어감
static func b_run(dist: float) -> Dictionary:
	var r := b_reach()
	var phase := dist / b_stride()
	var feet := {}
	var drop := 0.0
	for leg in B_LEGS:
		var p := fposmod(phase + B_PHASE[leg], 1.0)
		if p < B_DUTY:
			var fx := r - 2.0 * r * p / B_DUTY
			feet[leg] = Vector2(fx, 0.0)
			var hip := b_hip(leg)
			var reach_y := sqrt(maxf(0.0, pow(b_len(leg) * B_STRETCH, 2.0) - fx * fx))
			drop = maxf(drop, -hip.y - reach_y)  # 디딘 다리가 닿도록 몸을 내림
		else:
			var u := (p - B_DUTY) / (1.0 - B_DUTY)
			var e := u * u * (3.0 - 2.0 * u)
			feet[leg] = Vector2(-r + 2.0 * r * e, -B_LIFT * b_len(leg) * sin(PI * u))
	return _b_pose(feet, drop, true)


## 공중·웅크림 자세 (발 자리가 축 기준으로 정해짐)
static func b_air(kind: String) -> Dictionary:
	var feet := {}
	for leg in B_LEGS:
		var k: Vector2 = B_AIR[kind][0 if leg.begins_with("front") else 1]
		feet[leg] = k * b_len(leg)
	return _b_pose(feet, 6.0 if kind == "crouch" else 0.0, false)


## 네 발로 서 있음 (멈칫): 발이 축 바로 아래 바닥
static func b_stand(lower: float = 0.0) -> Dictionary:
	var feet := {}
	var drop := lower
	for leg in B_LEGS:
		feet[leg] = Vector2(0.0, 0.0)
		drop = maxf(drop, -b_hip(leg).y - b_len(leg) * B_STRETCH)
	return _b_pose(feet, drop, true)


## grounded = 발 자리가 바닥 기준(x는 축 기준), 아니면 축 기준
static func _b_pose(feet: Dictionary, drop: float, grounded: bool) -> Dictionary:
	var legs := {}
	for leg in B_LEGS:
		var hip := b_hip(leg) + Vector2(0.0, drop)
		var f: Vector2 = feet[leg]
		legs[leg] = {"hip": hip, "foot": Vector2(hip.x + f.x, f.y) if grounded else hip + f}
	return {"legs": legs, "drop": drop}


## 다리 그림 돌림·늘임: 축에서 발로 (그림은 축 아래로 곧게 서 있음)
static func b_leg(hip: Vector2, foot: Vector2, length: float) -> Vector2:
	var v := foot - hip
	return Vector2(atan2(-v.x, v.y), v.length() / length)  # (돌림 라디안, 세로 배율)


# --- 도망 ---

## t초 뒤 도망 {"kind": "startle"/"turn"/"run", "facing"(1 → -1), "dx"(놀란 자리에서 세계 x 이동, 게임 픽셀),
## "back"(뒤로 달린 거리 = 다리 박자용), "lift"(펄쩍 높이)}. vx0 = 놀란 순간 줄 속도
static func runaway(t: float, vx0: float) -> Dictionary:
	var stop := STARTLE + TURN
	var u := minf(t, stop)
	var carried := vx0 * (u - u * u / (2.0 * stop))  # 줄 속도에서 고르게 줄여 멈춤
	if t < STARTLE_CROUCH:
		return {"kind": "crouch", "facing": 1.0, "dx": carried, "back": 0.0, "lift": 0.0}
	if t < STARTLE:
		var k := (t - STARTLE_CROUCH) / (STARTLE - STARTLE_CROUCH)
		return {"kind": "startle", "facing": 1.0, "dx": carried, "back": 0.0, "lift": STARTLE_HOP * sin(PI * k)}
	if t < stop:
		var k := (t - STARTLE) / TURN
		var w := lerpf(TURN_POP, 1.0, absf(2.0 * k - 1.0))
		return {"kind": "turn", "facing": w if k < 0.5 else -w, "dx": carried, "back": 0.0, "lift": 0.0}
	var r := t - stop
	var back := RUNAWAY_SPEED * (r * r / (2.0 * RUNAWAY_ACCEL) if r < RUNAWAY_ACCEL else r - RUNAWAY_ACCEL * 0.5)
	return {"kind": "run", "facing": -1.0, "dx": carried - back, "back": back, "lift": 0.0}


## 도망이 시작된 높이 y0에서 아래 옥상 top까지 떨어진 높이 (공중에서 놀랐으면 먼저 내려앉음)
static func runaway_y(y0: float, top: float, t: float) -> float:
	return maxf(top, y0 - 0.5 * RUNAWAY_GRAVITY * t * t)
