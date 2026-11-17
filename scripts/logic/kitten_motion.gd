class_name KittenMotion
extends RefCounted
## 아기 고양이 움직임 (방식 A, 화면과 분리된 계산. 그리기는 kitten_view.gd). 6마리 모두 같은 방식, 그림만 품종마다.
## 아기는 주인공이 지난 길(위치·높이)을 그대로 따라가고, 공중에서는 주인공이 그 자리에서 한 자세를 아기 그림으로 따라 한다
## (motion2, 2026-11-16 사용자 결정): 주인공이 기록할 때 air_pose로 아기 자세 이름을 정해 기록에 넣고("kpose"), 아기는 그 자리에서 재생.
## 땅 = 아기 달리기, 닿는 순간 = 착지 그림·눌림 + 작은 먼지.
## 달리기는 시간·주인공 프레임이 아니라 아기가 달린 거리로 넘긴다 (빨라져도 발이 미끄러지지 않게):
## 장마다 KittenMotionData.ADVANCE[품종]만큼 달리면 다음 장 (tools/cut_kitten_motion.py가 잼).
## 땅 위에서는 몸 전체를 들어 올리지 않는다. 통통 튐은 발끝을 축으로 세로로만 살짝 눌리는 것 (발 x·높이 그대로).

const LAND_TIME := 0.15      # 닿은 뒤 착지 눌림 시간 (초). 0.14는 예전 1차에 "착지 웅크림이 없다", 0.2는 motion2 7차에 "천천히 부풀어 오름" (가로로 늘려 눌림이 잘 보이게 하고 줄임)
const LAND_WIDEN := 0.6     # 착지 때 세로로 줄어든 만큼 x 이 값만큼 가로로 ("작아짐"이 아니라 "눌림" 7차, 1.0은 얼굴이 커지며 앞으로 튐 8차 검토)
const LAND_SQUASH := 0.25    # 닿는 순간 세로 눌림 (곧게 풀림: 제곱으로 풀면 너무 빨리 펴져 안 보임, 2차 검토)
const DUST_TIME := 0.3       # 착지 먼지가 퍼졌다 사라지는 시간
const MAX_TILT := 0.35       # 공중 기울기 한계 (라디안)
const LAND_ATTACK := 0.15    # 착지 눌림이 가장 깊어지는 때 (land_k, 0.15 = 0.03초)
const LAND_ATTACK_FROM := 0.4 # 닿는 첫 장면의 눌림 = 가장 깊은 눌림 x 이 값
const TILT_PER_SLOPE := 0.5  # 길 기울기(dy/dx)를 몸 기울기로 바꾸는 비율
const STEP_SQUASH := Vector2(0.015, 0.035)  # 걸음마다 세로 눌림 (아이마다 이 사이, 개성)

## 공중 자세 (motion2): 주인공 그림 이름 → 아기 그림. rise·fall이라도 세로 속도가 APEX_SPEED 안이면 꼭대기.
## 같은 자세가 AIR_HOLD초를 넘으면 그 자세의 다음 순간 그림(_b)과 번갈아 (공중에서 한 장으로 떠 있지 않게, 요구: 0.12초 넘으면 실패)
const AIR_HOLD := 0.1
const APEX_SPEED := 280.0  # 170은 쭉 뻗은 오름 그림이 오름 내내 남음 (motion2 검토)
const PRE_CROUCH := 0.07     # 주인공이 뛴 자리 이만큼(초) 앞에서부터 웅크림
## 번갈아 쓰는 두 그림 (없으면 [자세, 자세_b]). 주인공 "오름"은 다리를 모은 그림이라 아기도 쭉 뻗은 rise 대신 모은 그림으로 (7차 검토: 반 박자 어긋남)
const AIR_PAIR_OF := {"rise": ["rise_b", "apex_b"]}
const AIR_PAIRED := ["crouch", "takeoff", "rise", "apex", "fall", "flip_ball", "flail"]

## 공중 몸 늘임 (발끝 축 가로·세로 배율): 오를 때 앞뒤로 길게, 내릴 때 살짝 세로로
const AIR_STRETCH := {"takeoff": Vector2(1.08, 0.95), "rise": Vector2(1.06, 0.96), "fall": Vector2(0.97, 1.04)}

## 도망: "!" 멈칫(달리던 속도를 줄이며 끼익 멈춤 + 작게 펄쩍) → 몸 돌림 → 바닥을 디디며 뒤로 달림 (가속 RUNAWAY_ACCEL초).
## 멈칫 동안 바로 세우면 화면에서 0.15초 만에 왼쪽 밖으로 사라져(1차 검토) 줄 속도에서 서서히 멈춘다
const STARTLE := 0.2       # 놀람 (움츠려 끼익 멈춤 + 펄쩍 0.11초). 펄쩍 0.15초는 낮고 길어 둥실 떠 보임 (motion2 4차 검토)
const STAND := 0.06          # 펄쩍 뒤 서서 놀란 채 (7차: 돌기가 너무 빨라 안 보임, 8차: 0.12는 화면 왼쪽 끝에서 돌아섬)
const SKID := 0.09           # 끼익 멈춤 시간 (0.3은 서 있는 채 얼음 위처럼 미끄러짐, motion2 3차 검토)
const STARTLE_CROUCH := 0.09 # 멈칫 처음: 움츠려 끼익 멈춘 뒤 펄쩍 (2차 검토: 갑자기 붕 뜸, 6차: 멈춤이 3장뿐) = SKID
const TURN := 0.1
const FLEE_LEAN := 0.15      # 도망 달리기: 몸을 앞으로 숙임 (라디안, 2차 검토: 꼿꼿이 서서 미끄러져 감)
const STARTLE_HOP := 22.0    # 놀라 펄쩍 (게임 픽셀, 12는 낮아 깜짝보다 둥실, 4차 검토)
const TURN_POP := 0.82       # 몸을 돌릴 때: 반에서 휙 뒤집으며 가로로 이만큼 좁아졌다 펴짐 (0까지 줄이면 사라짐 1차, 얇게 도는 건 종잇장 같음 2차)
const RUNAWAY_SPEED := 420.0  # 260은 겁먹은 아기가 느릿느릿 (motion2 6차 검토)
const RUNAWAY_ACCEL := 0.12
const RUNAWAY_GRAVITY := 2600.0


## 아기 그림 캔버스 픽셀 → 게임 픽셀 (예전 아기와 같은 크기: cat_view.gd KITTEN_ART x 주인공 배율 x 아기 크기)
static func px() -> float:
	return CatView.KITTEN_ART * CatView.art_scale() * Balance.PARADE_SIZE


## 주인공을 기록할 때마다 부름: 이번 장면의 아기 자세 이름. memo = 부르는 쪽이 들고 있는 {} (지금 자세·그 자세로 지난 시간)
## on_net = 주인공이 트램펄린·줄을 누르는 중이거나 그물에서 막 튕김 (웅크림 그대로. 땅에서 뛴 웅크림만 도약 그림으로)
static func air_pose(memo: Dictionary, hero_frame: String, ground: bool, vy: float, dt: float, on_net: bool = false) -> String:
	var base := hero_frame
	if ground:
		base = "land" if hero_frame == "land" else "run"
	elif hero_frame in ["rise", "fall"] and absf(vy) < APEX_SPEED:
		base = "apex"
	elif hero_frame == "crouch" and vy > 0.0 and not on_net:
		base = "takeoff"  # 막 뛰어오르는 첫 장면: 웅크린 그림이 떠오르지 않게 (아기는 땅에서 미리 웅크림, 3차 검토)
	elif hero_frame.begins_with("run_") or hero_frame == "land":
		base = "fall"  # 땅 그림인 채 막 떠오른 한 장면 (옥상 끝을 달려 나감)
	if base != memo.get("base", ""):
		memo.base = base
		memo.t = 0.0
	else:
		memo.t += dt
	if ground or base not in AIR_PAIRED:
		return base
	var pair: Array = AIR_PAIR_OF.get(base, [base, base + "_b"])
	return pair[int(memo.t / AIR_HOLD) % 2]


## 앞 기록 sample이 막 뛰어오른 자리인가 (옥상 끝에서 떨어지는 건 아님: 뛴 지 얼마 안 됨)
static func jumps_soon(ahead: Dictionary) -> bool:
	return not ahead.is_empty() and not ahead.get("ground", true) and ahead.get("since_jump", 9.0) <= PRE_CROUCH + 0.05


## 기록 sample(+ 붙는 중 덮어쓴 "kind") + 길 기울기(dy/dx, 위가 +) → {"kind", "tilt", "land_k"(0~1, 1 = 착지 끝)}
## 공중 기울기: 앞구르기는 주인공 회전 그대로, 허우적은 주인공 기울기, 나머지는 길 기울기를 조금
static func state(sample: Dictionary, slope: float) -> Dictionary:
	if sample.has("kind"):
		var tilt := 0.0 if sample.kind == "crouch" else clampf(-atan(slope) * TILT_PER_SLOPE, -MAX_TILT, MAX_TILT)
		return {"kind": sample.kind, "tilt": tilt, "land_k": 1.0}
	if sample.get("ground", true):
		var land: float = sample.get("since_land", 9.0)
		return {"kind": "run", "tilt": 0.0, "land_k": clampf(land / LAND_TIME, 0.0, 1.0)}
	var kind: String = sample.get("kpose", "fall")
	var tilt := clampf(-atan(slope) * TILT_PER_SLOPE, -MAX_TILT, MAX_TILT)
	if kind.begins_with("flip_"):
		tilt = sample.get("spin", 0.0)
	elif kind.begins_with("flail"):
		tilt = sample.get("rot", 0.0)
	elif kind.begins_with("crouch") or kind == "run":
		tilt = 0.0
	return {"kind": kind, "tilt": tilt, "land_k": 1.0}


## 세로 배율 (발끝 축): 착지 눌림 + 걸음마다 작은 눌림 (q = 아이 개성 0~1, phase = 걸음 0~1)
static func squash(land_k: float, phase: float, q: float) -> float:
	var step := lerpf(STEP_SQUASH.x, STEP_SQUASH.y, q) * (0.5 + 0.5 * cos(TAU * 2.0 * phase))
	# 닿는 첫 장면은 덜 눌리고 LAND_ATTACK 만에 가장 깊이 (한 장에 머리가 툭 떨어지지 않게, motion2 5차 검토)
	return 1.0 - step - LAND_SQUASH * (1.0 - land_k) * minf(1.0, LAND_ATTACK_FROM + land_k / LAND_ATTACK)


## 착지 가로 배율 (세로 착지 눌림만큼, 걸음 눌림은 넣지 않음: 발 x가 바뀌지 않게)
static func widen(land_k: float) -> float:
	return 1.0 + LAND_WIDEN * LAND_SQUASH * (1.0 - land_k) * minf(1.0, LAND_ATTACK_FROM + land_k / LAND_ATTACK)


# --- 달리기 프레임 ---

## 한 바퀴 거리 (게임 픽셀)
static func a_stride(breed: String) -> float:
	return KittenMotionData.ADVANCE[breed] * KittenMotionData.RUN_FRAMES * px()


## 달린 거리 → 달리기 장 번호
static func a_frame(dist: float, breed: String) -> int:
	return int(fposmod(dist, a_stride(breed)) / (KittenMotionData.ADVANCE[breed] * px())) % KittenMotionData.RUN_FRAMES


# --- 도망 ---

## t초 뒤 도망 {"kind": "startle"/"turn"/"run", "facing"(1 → -1), "dx"(놀란 자리에서 세계 x 이동, 게임 픽셀),
## "back"(뒤로 달린 거리 = 다리 박자용), "lift"(펄쩍 높이)}. vx0 = 놀란 순간 줄 속도
static func runaway(t: float, vx0: float) -> Dictionary:
	var stop := STARTLE + STAND + TURN
	var u := minf(t, SKID)
	var carried := vx0 * (u - u * u / (2.0 * SKID))  # 줄 속도에서 SKID초 동안 고르게 줄여 멈춤 (그 뒤는 바닥에 선 채)
	if t < STARTLE_CROUCH:
		return {"kind": "crouch", "facing": 1.0, "dx": carried, "back": 0.0, "lift": 0.0}
	if t < STARTLE:
		var k := (t - STARTLE_CROUCH) / (STARTLE - STARTLE_CROUCH)
		return {"kind": "startle", "facing": 1.0, "dx": carried, "back": 0.0, "lift": STARTLE_HOP * sin(PI * k)}
	if t < STARTLE + STAND:
		return {"kind": "startle", "facing": 1.0, "dx": carried, "back": 0.0, "lift": 0.0}
	if t < stop:
		var k := (t - STARTLE - STAND) / TURN
		var w := lerpf(TURN_POP, 1.0, absf(2.0 * k - 1.0))
		return {"kind": "turn", "facing": w if k < 0.5 else -w, "dx": carried, "back": 0.0, "lift": 0.0}
	var r := t - stop
	var back := RUNAWAY_SPEED * (r * r / (2.0 * RUNAWAY_ACCEL) if r < RUNAWAY_ACCEL else r - RUNAWAY_ACCEL * 0.5)
	return {"kind": "run", "facing": -1.0, "dx": carried - back, "back": back, "lift": 0.0}


## 도망이 시작된 높이 y0에서 아래 옥상 top까지 떨어진 높이 (공중에서 놀랐으면 먼저 내려앉음)
static func runaway_y(y0: float, top: float, t: float) -> float:
	return maxf(top, y0 - 0.5 * RUNAWAY_GRAVITY * t * t)
