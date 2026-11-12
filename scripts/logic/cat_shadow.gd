class_name CatShadow
extends RefCounted
## 고양이 발밑 그림자: 발 아래 가장 높은 옥상(판 포함) 윗면에 놓고, 높이 뜰수록 작고 옅게.
## 화면과 분리해 테스트한다 (그림만 바꾸고 판정에는 쓰지 않음).

const ALPHA := 0.30          # 서 있을 때 진하기
const MIN_SCALE := 0.45      # 가장 높이 떴을 때 크기 비율
const MIN_ALPHA := 0.08
const FADE_HEIGHT := 320.0   # 이 높이 이상 뜨면 가장 작고 옅음
const RADIUS_PER_WIDTH := 0.55  # 그림자 반지름 = 아랫몸 너비 x 이 값 (몸보다 살짝 넓게)
const FLAT := 0.18              # 세로/가로 비율 (납작한 타원)
const PRESS_FULL := 0.2         # 세로 배율이 1에서 이만큼 줄면 가장 납작·진함
const PRESS_FLAT := 0.75
const PRESS_ALPHA := 1.4
## 자세별 아랫몸(그림 아래 30%) [가운데 x, 너비], 게임 픽셀, 발끝 기준. 프레임 그림에서 잰 값 (test_shadow.gd가 그림과 대조)
const FRAME_BODY := {
	"run_0": [-10.5, 104.6], "run_1": [-29.1, 190.7], "run_2": [-31.0, 166.7], "run_3": [-16.2, 117.7],
	"crouch": [-29.3, 148.9], "takeoff": [-23.6, 163.7], "rise": [-17.7, 117.3], "fall": [-17.3, 130.0],
	"land": [-20.3, 150.2], "flail": [-13.1, 143.5],
	"flip_tuck": [-19.4, 102.1], "flip_curl": [-14.3, 121.5], "flip_ball": [-12.9, 95.8], "flip_open": [-25.5, 182.7],
	"sit_0": [-26.8, 103.4], "sit_1": [-17.5, 84.8], "sit_2": [-26.4, 101.7], "sit_blink": [-26.8, 103.4], "sit_up": [-19.0, 114.8],
}


## 고양이 발(x, y) 아래 그림자: {"top": 옥상 높이, "scale", "alpha"}. 아래에 옥상이 없으면(틈 위) 빈 Dictionary
static func under(roofs: Array, x: float, y: float) -> Dictionary:
	var best := {}
	for roof in roofs:
		# 발보다 높은 옥상(벽 속을 투명화로 지나는 중)에는 그리지 않는다
		if x >= roof.left and x <= roof.right and roof.top <= y + 0.5 and (best.is_empty() or roof.top > best.top):
			best = roof
	if best.is_empty():
		return {}
	var k := clampf((y - best.top) / FADE_HEIGHT, 0.0, 1.0)
	return {"top": best.top, "scale": lerpf(1.0, MIN_SCALE, k), "alpha": lerpf(ALPHA, MIN_ALPHA, k)}


## 자세에 따른 그림자 모양 {"center_x", "radius", "flat", "alpha"(진하기 배율)}.
## body: 몸 배율, spin: 공중제비 회전(라디안, 돌면 가로 폭이 몸 길이 ↔ 몸 높이 사이로 바뀜). 눌릴수록 납작하고 진하다
static func shape(frame: String, body: Vector2, spin: float) -> Dictionary:
	var part: Array = FRAME_BODY[frame]
	var width: float = part[1] * absf(cos(spin)) + Balance.CAT_BODY_SIZE.y * absf(sin(spin))
	var press := clampf((1.0 - body.y) / PRESS_FULL, 0.0, 1.0)
	return {"center_x": part[0] * cos(spin) * body.x, "radius": width * body.x * RADIUS_PER_WIDTH,
			"flat": FLAT * lerpf(1.0, PRESS_FLAT, press), "alpha": lerpf(1.0, PRESS_ALPHA, press)}
