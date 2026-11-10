class_name SfxEvents
## RunnerSim의 이번 step 결과 → 낼 효과음 이름 (화면·소리와 분리된 순수 계산).

const FISH_GAP := 0.07  # 생선 소리가 이 시간 안에 다시 나면 하나로 친다 (초)

const ALL := ["jump", "double_jump", "land", "fish", "pickup", "boing", "perfect", "fall", "stage_up", "coo", "pang", "bell",
		"combo_up", "combo_break", "hit", "heartbeat", "dash"]
## 콤보 음계: 생선을 연달아 먹을수록 도레미파솔라시도로 한 칸씩 오르고, 8칸 뒤 처음 칸으로 돈다 (반음 수)
const FISH_SCALE := [0, 2, 4, 5, 7, 9, 11, 12]
## 음계 첫 칸을 원래 생선 소리보다 이만큼(반음) 낮춘다: 맨 위 칸이 원래 소리의 1.5배를 넘지 않아 귀가 아프지 않게
const FISH_SCALE_BASE := -5
## 이 콤보 아래에서 끊기면 "툭"을 내지 않는다 (한두 개 놓칠 때마다 나면 잔소리처럼 들림)
const COMBO_BREAK_MIN := 5


## fall_start: 끝날 떨어짐이 이번에 처음 확정됐는지 (부르는 쪽이 한 번만 true로)
static func sounds(sim: RunnerSim, fall_start: bool) -> Array[String]:
	var out: Array[String] = []
	if sim.jumped:
		out.append("jump")
	if sim.double_jumped:
		out.append("double_jump")
	if sim.landed:
		out.append("land")
	if sim.bounced:
		out.append("boing")
		if sim.bounce_result == "perfect":
			out.append("perfect")
	var bite := ""  # 한 step에 여러 개여도 한 번. 생선과 같이 먹으면 아이템 소리
	for item in sim.picked:
		if item.kind == "bell":
			bite = "bell"
		elif item.kind == "fish":
			bite = "fish" if bite.is_empty() else bite
		elif item.kind != "box" and bite != "bell":
			bite = "pickup"
	if not bite.is_empty():
		out.append(bite)
	if not sim.smashed.is_empty() or not sim.canned.is_empty():
		out.append("pang")
	if sim.bell_blocked:
		out.append("bell")
	elif not sim.hit_obstacle.is_empty():
		out.append("hit")
	if sim.stage_rose:
		out.append("stage_up")
	if sim.dash_started:
		out.append("dash")  # 슝 (2b 수정: 단계 오름 소리 대신)
	if fall_start:
		out.append("fall")
	return out


## 생선 소리를 새로 틀지 (now·last = 판 안 시각. 새 판이면 시각이 되돌아간다)
static func fish_due(now: float, last: float) -> bool:
	return now - last >= FISH_GAP or now < last


## 콤보 count번째 생선 소리의 재생 배율 (count = 먹은 뒤 콤보, 1부터)
static func fish_pitch(count: int) -> float:
	var note: int = FISH_SCALE[posmod(count - 1, FISH_SCALE.size())]
	return pow(2.0, (FISH_SCALE_BASE + note) / 12.0)


## 이번 step의 콤보 변화로 낼 소리: 배수가 오르면 "띵", 끊기면 "툭" (부딪힘은 "퉁"이 따로 나서 뺀다)
## before_count·before_mult = step 전 콤보와 배수
static func combo_sounds(before_count: int, before_mult: int, combo: FishCombo, hit: bool) -> Array[String]:
	var out: Array[String] = []
	if combo.count < before_count and before_count >= COMBO_BREAK_MIN and not hit:
		out.append("combo_break")
	if combo.multiplier() > before_mult:
		out.append("combo_up")
	return out
