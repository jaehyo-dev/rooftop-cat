class_name EnemyAnim
extends RefCounted
## 적 그림 고르기 (화면과 분리해 테스트). 그림: assets/sprites/enemies/<적>/ (tools/make_bg_art.py, 게임 크기의 2배).
## v0.8.0 1부: 움직임·판정 없이 반복 동작만 (시험 단추 "적 미리보기"로 옥상에 세워 둠). 2부에서 실제 적 로직이 이것을 쓴다.

## 반복 장 이름과 1초에 넘기는 장 수
const LOOPS := {"crow": ["fly_0", "fly_1", "fly_2", "fly_3"], "rat": ["run_0", "run_1", "run_2", "run_3"]}
const FPS := {"crow": 10.0, "rat": 12.0}
## 그림 안 발 기준점 (파일 px, tools/make_bg_art.py가 출력한 값). 게임은 FILE_SCALE로 나눠 그린다
const FOOT := {"crow": Vector2(105, 215), "rat": Vector2(99, 236)}
const FILE_SCALE := 2.0
## 쥐 무리 세 마리가 같은 박자로 움직이지 않게 시작 장을 어긋나게 (장 번호)
const PACK_OFFSETS := [0, 2, 1]


## t초에 보여 줄 반복 장 (offset = 시작 장을 몇 장 밀지)
static func loop_frame(kind: String, t: float, offset: int = 0) -> String:
	var frames: Array = LOOPS[kind]
	return frames[(int(floorf(t * FPS[kind])) + offset) % frames.size()]


## 무리의 i번째 쥐 시작 장
static func pack_offset(i: int) -> int:
	return PACK_OFFSETS[i % PACK_OFFSETS.size()]
