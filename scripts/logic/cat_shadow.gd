class_name CatShadow
extends RefCounted
## 고양이 발밑 그림자: 발 아래 가장 높은 옥상(판 포함) 윗면에 놓고, 높이 뜰수록 작고 옅게.
## 화면과 분리해 테스트한다 (그림만 바꾸고 판정에는 쓰지 않음).

const ALPHA := 0.30          # 서 있을 때 진하기
const MIN_SCALE := 0.45      # 가장 높이 떴을 때 크기 비율
const MIN_ALPHA := 0.08
const FADE_HEIGHT := 320.0   # 이 높이 이상 뜨면 가장 작고 옅음


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
