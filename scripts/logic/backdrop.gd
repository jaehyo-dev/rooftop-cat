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
const CLOUDS := [[0, 200.0, 0.14], [1, 900.0, 0.26], [2, 1500.0, 0.10], [3, 2050.0, 0.22]]


## 동네 띠를 이어 붙일 조각들: [{"x": 화면 왼쪽 x, "flip": 좌우 뒤집기}].
## 이웃한 조각을 번갈아 뒤집어 그리면 이음매가 항상 같은 그림끼리 맞닿아 어긋나 보이지 않는다.
static func town_tiles(scroll: float, tile_width: float, view_width: float) -> Array[Dictionary]:
	var shift := scroll * TOWN_PARALLAX
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
