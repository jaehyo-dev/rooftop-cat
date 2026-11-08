class_name Backdrop
extends RefCounted
## 먼 배경(하늘의 구름, 멀리 보이는 동네 띠)의 위치 계산. 화면과 분리해 테스트한다.
## 먼 것일수록 천천히 지나가서(시차) 깊이가 느껴진다.

## 달린 거리 대비 배경이 움직이는 비율 (1 = 옥상과 같은 속도)
const TOWN_PARALLAX := 0.18
const CLOUD_PARALLAX := 0.05
## 구름이 혼자 흘러가는 속도 (초당 픽셀)
const CLOUD_DRIFT := 6.0
## 구름 자리가 되풀이되는 가로 길이
const CLOUD_PERIOD := 2400.0
## 구름 자리: [그림 번호, 가로 위치(주기 안), 높이(화면 높이 비율)]
## 빈 하늘이 줄도록 화면 가운데 높이까지 내려 둠 (v0.4.1)
const CLOUDS := [[0, 200.0, 0.30], [1, 900.0, 0.33], [2, 1500.0, 0.10], [3, 2050.0, 0.40]]
## 안개 겹 (먼 것 → 가까운 것): [이름, 시차 비율, 띠 윗끝(화면 높이 비율), 진하기]. 아래로 갈수록 진함
## 먼 안개·실루엣·가운데 안개는 건물 뒤, 가까운 안개는 건물·고양이 앞(화면 맨 아래)
const MISTS := [["far", 0.22, 0.56, 0.75], ["town", 0.30, 0.60, 0.50], ["mid", 0.40, 0.68, 0.85], ["near", 1.25, 0.90, 0.90]]


## 동네 띠를 이어 붙일 조각들: [{"x": 화면 왼쪽 x, "flip": 좌우 뒤집기}].
## 이웃한 조각을 번갈아 뒤집어 그리면 이음매가 항상 같은 그림끼리 맞닿아 어긋나 보이지 않는다.
## parallax: 시차 비율 (안개 띠도 같은 방법으로 이어 붙임)
static func town_tiles(scroll: float, tile_width: float, view_width: float, parallax: float = TOWN_PARALLAX) -> Array[Dictionary]:
	var shift := scroll * parallax
	var first := int(floorf(shift / tile_width))
	var tiles: Array[Dictionary] = []
	var x := first * tile_width - shift
	var index := first
	while x < view_width:
		tiles.append({"x": x, "flip": index % 2 != 0})
		x += tile_width
		index += 1
	return tiles


## 구름 하나의 화면 왼쪽 x: 천천히 뒤로 가며 혼자 흘러가고, 한 주기를 돌아 다시 나타남
static func cloud_x(base: float, scroll: float, elapsed: float, cloud_width: float) -> float:
	var moved := base - scroll * CLOUD_PARALLAX - elapsed * CLOUD_DRIFT
	return fposmod(moved + cloud_width, CLOUD_PERIOD) - cloud_width
