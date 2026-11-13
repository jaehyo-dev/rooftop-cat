class_name CatParade
extends RefCounted
## 줄줄이 고양이 행렬 시험판 (GAME_SPEC "2026-11-13 게임 정체성", 화면과 분리된 로직). RunnerSim.parade_on일 때 sim.step이 부른다.
## - 길고양이(strays): 옥상 위 웅크린 고양이. 처음 STRAY_FIRST초, 그 뒤 STRAY_EVERY초마다 화면 오른쪽 밖 옥상에 놓는다.
##   장애물·트램펄린·아이템 둘레(STRAY_CLEAR)는 피하고, 그 자리 땅 생선은 치운다. 주인공 x가 그 자리를 지나면(점프 중이어도) 만남.
## - 줄(cats): 만난 고양이는 맨 뒤에 붙는다. 따라오는 고양이 i(0부터)는 주인공보다 (i+1) x PARADE_GAP 뒤의 기록(trail)을 그대로 재생한다.
##   기록은 시간이 아니라 주인공 x 기준이라 빨라져도 간격이 같고, 주인공이 무사히 지난 길을 그대로 지난다.
## - 부딪힘(scare): 맨 뒤 고양이가 놀라 도망간다. mode "A" = 하트도 잃음, "B" = 줄이 있으면 하트 대신 (RunnerSim._hit_obstacles).

const LOOKS := ["gray", "black", "white", "tabby", "cream"]

## 부딪힘 방식 "A" / "B" (시험판 비교용)
var mode := "A"
## 줄: {"look", "quirk"(0~1, 개성), "from": 만난 자리 Vector2(x, 발 높이), "t": 붙은 뒤 지난 시간}
var cats: Array[Dictionary] = []
## 옥상 위에서 기다리는 길고양이: {"x", "y"(옥상 높이), "look", "quirk"}
var strays: Array[Dictionary] = []
## 이번 step에 만난 고양이, 도망간 고양이 (연출용, step마다 지움)
var met: Array[Dictionary] = []
var fled: Array[Dictionary] = []
## 이번 판에 만난 수, 가장 길었던 줄
var met_total := 0
var best := 0
## 주인공 기록 {"x", "y", ...} (x 오름차순). 화면이 자세까지 넣어 기록하고, 로직 테스트는 높이만 넣는다
var trail: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _next_meet := 0.0  # 다음 길고양이를 만날 시각 (이 시각에 닿도록 놓는다)


func _init(seed_value: int) -> void:
	_rng.seed = seed_value * 7919 + 17
	_next_meet = _rng.randf_range(Balance.STRAY_FIRST.x, Balance.STRAY_FIRST.y)


## 점수 배수 (1마리 1.2 … 6마리 2.2)
static func mult_for(count: int) -> float:
	return 1.0 + Balance.PARADE_MULT_STEP * count


func multiplier() -> float:
	return mult_for(cats.size())


## 골골 피버 중인지
func fever() -> bool:
	return cats.size() >= Balance.PARADE_FEVER


## 따라오는 고양이 i(0부터)가 재생할 주인공 x
static func slot_x(i: int, leader_x: float) -> float:
	return leader_x - Balance.PARADE_LEAD_GAP - Balance.PARADE_GAP * i


## 줄이 count마리일 때 주인공 화면 x: 맨 뒤 고양이까지 화면 안에 보이게 기본 자리(CAT_SCREEN_X)보다 오른쪽으로
static func screen_x(count: int) -> float:
	if count == 0:
		return Balance.CAT_SCREEN_X
	return maxf(Balance.CAT_SCREEN_X, Balance.PARADE_EDGE + Balance.CAT_SCREEN_X - slot_x(count - 1, Balance.CAT_SCREEN_X))


## sim.step이 이동·아이템·장애물 뒤에 부른다: 붙는 시간 진행, 만남, 다음 길고양이 놓기
func update(sim: RunnerSim, dt: float) -> void:
	for cat in cats:
		cat.t += dt
	for i in range(strays.size() - 1, -1, -1):
		var s := strays[i]
		if sim.x < s.x:
			continue
		strays.remove_at(i)
		if cats.size() >= Balance.PARADE_MAX:
			continue  # 그 사이 시험 단추로 줄이 꽉 참
		var cat := {"look": s.look, "quirk": s.quirk, "from": Vector2(s.x, s.y), "t": 0.0}
		cats.append(cat)
		met.append(cat)
		met_total += 1
		best = maxi(best, cats.size())
	if strays.is_empty() and cats.size() < Balance.PARADE_MAX:
		var from_x := sim.x + sim.view_ahead + 60.0  # 화면 오른쪽 밖에서 나타나게
		if sim.elapsed + (from_x - sim.x) / maxf(sim.vx(), 1.0) >= _next_meet:
			_place(sim, from_x)


## 맨 뒤 고양이가 놀라 도망간다. 줄이 비었으면 false
func scare() -> bool:
	if cats.is_empty():
		return false
	fled.append(cats.pop_back())
	return true


## 시험 단추: 길고양이가 바로 나오게 (화면 오른쪽 밖 가장 가까운 자리)
func call_now() -> void:
	_next_meet = -INF


## 시험 단추: 줄을 count마리로 (이미 붙은 상태로)
func fill(count: int) -> void:
	while cats.size() < mini(count, Balance.PARADE_MAX):
		cats.append({"look": LOOKS[cats.size() % LOOKS.size()], "quirk": _rng.randf(), "from": Vector2.ZERO, "t": 99.0})
	best = maxi(best, cats.size())


## from_x부터 앞으로 가며 처음 비어 있는 옥상 자리에 길고양이를 놓는다. 못 찾으면 다음 step에 다시
func _place(sim: RunnerSim, from_x: float) -> void:
	for roof in sim.roofs:
		if roof.get("platform", false) or roof.right - Balance.STRAY_EDGE < from_x:
			continue
		var at := maxf(roof.left + Balance.STRAY_EDGE, from_x)
		while at <= roof.right - Balance.STRAY_EDGE:
			if _free(sim, at, roof):
				_put(sim, at, roof)
				return
			at += 20.0


func _free(sim: RunnerSim, at: float, roof: Dictionary) -> bool:
	var clear := Balance.STRAY_CLEAR
	for o in sim.obstacles:
		if o.x - clear < at and o.x + o.w + clear > at:
			return false
	for s in sim.structures:
		if s.left - clear < at and s.right + clear > at:
			return false
	for item in sim.items:
		if not FishRoad.is_fish(item) and absf(item.x - at) < clear and item.y <= roof.top + Balance.CAT_BODY_SIZE.y * 2.0:
			return false
	return true


func _put(sim: RunnerSim, at: float, roof: Dictionary) -> void:
	# 그 자리 땅 생선은 치운다 (길고양이와 겹치지 않게, 공중 호 생선은 그대로)
	for i in range(sim.items.size() - 1, -1, -1):
		var item: Dictionary = sim.items[i]
		if FishRoad.is_fish(item) and absf(item.x - at) < FishRoad.RESERVED_GAP + 30.0 and item.y <= roof.top + Balance.ITEM_LIFT:
			sim.items.remove_at(i)
	strays.append({"x": at, "y": roof.top, "look": LOOKS[_rng.randi() % LOOKS.size()], "quirk": _rng.randf()})
	var arrive := sim.elapsed + (at - sim.x) / maxf(sim.vx(), 1.0)
	_next_meet = arrive + _rng.randf_range(Balance.STRAY_EVERY.x, Balance.STRAY_EVERY.y)


## 주인공 기록 하나 덧붙이기 (x가 앞으로 갔을 때만). 줄 끝보다 뒤인 기록은 지운다
func record(pose: Dictionary) -> void:
	if not trail.is_empty() and pose.x < trail[-1].x:
		return  # 뒤로 간 기록 (벽에 막힘)은 버림
	if trail.size() >= 2 and pose.x < trail[-2].x + Balance.PARADE_TRAIL_MIN:
		trail[-1] = pose  # 너무 촘촘하면 마지막 것을 바꿔 씀 (같은 자리에 선 채 바뀐 자세도 반영)
		return
	trail.append(pose)
	var keep := slot_x(Balance.PARADE_MAX, pose.x) - 200.0
	while trail.size() > 2 and trail[1].x < keep:
		trail.pop_front()


## 주인공이 x를 지날 때의 기록 (사이는 보간). 기록보다 앞(시작 전)이면 첫 기록
func sample(at: float) -> Dictionary:
	if trail.is_empty():
		return {}
	if at <= trail[0].x:
		var first := trail[0].duplicate()
		first.x = at
		return first
	for i in range(trail.size() - 1, -1, -1):
		var a := trail[i]
		if a.x > at:
			continue
		if i == trail.size() - 1:
			return a.duplicate()
		var b := trail[i + 1]
		var k: float = (at - a.x) / (b.x - a.x)
		var out := a.duplicate()
		out.x = at
		for key in a:
			if key in ["spin", "rot"]:
				out[key] = lerp_angle(a[key], b[key], k)
			elif a[key] is float or a[key] is Vector2:
				out[key] = lerp(a[key], b[key], k)
		return out
	return trail[0].duplicate()


## 따라오는 고양이 i의 지금 모습: 기록 재생. 붙는 중이면 만난 자리에서 줄 맨 뒤로 깡충 달려옴 ("joining" = 0~1)
func follower(i: int, leader_x: float) -> Dictionary:
	var cat := cats[i]
	var pose := sample(slot_x(i, leader_x))
	if pose.is_empty() or cat.t >= Balance.PARADE_JOIN_TIME:
		return pose
	var k: float = cat.t / Balance.PARADE_JOIN_TIME
	var e := k * k * (3.0 - 2.0 * k)
	var from: Vector2 = cat.from
	pose.x = lerpf(from.x, pose.x, e)
	pose.y = lerpf(from.y, pose.y, e) + 50.0 * sin(PI * k)
	pose.joining = k
	return pose
