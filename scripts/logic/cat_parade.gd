class_name CatParade
extends RefCounted
## 줄줄이 고양이 행렬 시험판 (GAME_SPEC "2026-11-13 게임 정체성", 화면과 분리된 로직). RunnerSim.parade_on일 때 sim.step이 부른다.
## - 길고양이(strays): 옥상 위 웅크린 고양이. 처음 STRAY_FIRST초, 그 뒤 STRAY_EVERY초마다 화면 오른쪽 밖 옥상에 놓는다.
##   장애물·트램펄린·아이템 둘레(STRAY_CLEAR)는 피하고, 그 자리 땅 생선은 치운다. 주인공 x가 그 자리를 지나면(점프 중이어도) 만남.
## - 무리(cats): 만난 아기는 주인공 뒤쪽 위 정해진 자리(Balance.KITTEN_SLOTS[i], i = 만난 차례) 하나를 잡고 구름 방석에 앉아 떠다닌다
##   (2026-11-17 사용자 결정: 줄은 평지에서 빽빽하고 도망이 화면 끝에서 끝나 거슬림). 떠다니는 움직임은 화면(world_view)이 스프링으로,
##   자리·둥실 박자는 여기 static 함수. 아기는 충돌 판정이 없다.
## - 능력 (2026-11-17 액션 시험판, 자동 발동): 턱시도 냥펀치(앞 장애물 하나 부숨)·치즈 물어 오기(놓친 필수 생선을 물어 와 콤보 유지)·
##   삼색 반짝 코(앞 생선 3마리를 황금으로). 나머지 품종은 능력 없음. 아기마다 "cool"(남은 충전 초), 쓰면 skill_used에 알림.
## - 부딪힘(scare): 하트도 잃고 가장 나중에 온 아기가 날아가 사라진다 (A 규칙, RunnerSim._hit_obstacles).

## 아기 고양이 품종 (assets/sprites/kittens/<품종>/, GAME_SPEC "줄줄이" 시안 2 확정): 치즈(방울)·고등어(접힌 귀)·턱시도(나비넥타이)·삼색(꽃핀)·젖소(방울 꼬리)·회색(삐친 털)
const LOOKS := ["cheese", "mackerel", "tuxedo", "calico", "cow", "gray"]

## 무리: {"look", "quirk"(0~1, 개성: 둥실 박자·울음 높이)}. 자리 = 배열 순서
var cats: Array[Dictionary] = []
## 옥상 위에서 기다리는 길고양이: {"x", "y"(옥상 높이), "look", "quirk"}
var strays: Array[Dictionary] = []
## 이번 step에 만난 고양이, 도망간 고양이 (연출용, step마다 지움)
var met: Array[Dictionary] = []
var fled: Array[Dictionary] = []
## 이번 step에 쓴 능력 (연출용, step마다 지움): {"skill", "look", "x", "y"(대상 로직 자리), "target"(부순 장애물·바뀐 생선들)}
var skill_used: Array[Dictionary] = []
## 이번 판에 만난 수, 가장 길었던 줄
var met_total := 0
var best := 0

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


## 아기 i(0부터)가 떠 있을 자리: 주인공 발끝 화면 자리에서 (가로, 세로) 픽셀 (세로는 위가 -)
static func slot(i: int) -> Vector2:
	return Balance.KITTEN_SLOTS[i]


## 아기마다 박자가 조금 다른 둥실둥실 (자리에 더하는 화면 픽셀). quirk 0~1
static func bob(t: float, quirk: float) -> Vector2:
	var hz := Balance.KITTEN_BOB_HZ * (0.8 + 0.4 * quirk)
	var phase := TAU * (hz * t + quirk)
	return Vector2(0.35 * sin(phase * 0.5), sin(phase)) * Balance.KITTEN_BOB


## sim.step이 이동·아이템·장애물 뒤에 부른다: 만남, 다음 길고양이 놓기
func update(sim: RunnerSim, dt: float) -> void:
	_skills(sim, dt)
	for i in range(strays.size() - 1, -1, -1):
		var s := strays[i]
		if sim.x < s.x:
			continue
		strays.remove_at(i)
		if cats.size() >= Balance.PARADE_MAX:
			continue  # 그 사이 시험 단추로 줄이 꽉 참
		var cat := {"look": s.look, "quirk": s.quirk, "from": Vector2(s.x, s.y), "cool": cooldown(s.look)}
		cats.append(cat)
		met.append(cat)
		met_total += 1
		best = maxi(best, cats.size())
	if strays.is_empty() and cats.size() < Balance.PARADE_MAX:
		var from_x := sim.x + sim.view_ahead + 60.0  # 화면 오른쪽 밖에서 나타나게
		if sim.elapsed + (from_x - sim.x) / maxf(sim.vx(), 1.0) >= _next_meet:
			_place(sim, from_x)


## 가장 나중에 온 아기가 놀라 날아간다. 무리가 비었으면 false
func scare() -> bool:
	if cats.is_empty():
		return false
	fled.append(cats.pop_back())
	return true


## 시험 단추: 길고양이가 바로 나오게 (화면 오른쪽 밖 가장 가까운 자리)
func call_now() -> void:
	_next_meet = -INF


## 시험 단추: 무리를 count마리로 (이미 자리에 있는 상태로)
func fill(count: int) -> void:
	while cats.size() < mini(count, Balance.PARADE_MAX):
		var look := _new_look()
		cats.append({"look": look, "quirk": _rng.randf(), "cool": cooldown(look)})
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
	strays.append({"x": at, "y": roof.top, "look": _new_look(), "quirk": _rng.randf()})
	var arrive := sim.elapsed + (at - sim.x) / maxf(sim.vx(), 1.0)
	_next_meet = arrive + _rng.randf_range(Balance.STRAY_EVERY.x, Balance.STRAY_EVERY.y)


## 품종의 능력 충전 시간 (초). 능력 없으면 INF
static func cooldown(look: String) -> float:
	return Balance.KITTEN_SKILLS[look].every if Balance.KITTEN_SKILLS.has(look) else INF


## 능력 충전 비율 (0 = 막 씀, 1 = 준비). 능력 없으면 -1 (HUD 고리용)
static func charge(cat: Dictionary) -> float:
	if not Balance.KITTEN_SKILLS.has(cat.look):
		return -1.0
	return 1.0 - cat.cool / cooldown(cat.look)


## 시험 단추: 모든 능력 다시 채우기
func refill() -> void:
	for cat in cats:
		if Balance.KITTEN_SKILLS.has(cat.look):
			cat.cool = 0.0


## 충전하고, 준비된 냥펀치·반짝 코는 대상이 있으면 바로 쓴다 (물어 오기는 놓칠 때 RunnerSim이 fetch로 부름)
func _skills(sim: RunnerSim, dt: float) -> void:
	# 냥펀치가 날아가는 중인 장애물: 아기가 닿으면 부서짐 (그동안 그대로 보이고 부딪히지 않음)
	for i in range(sim.obstacles.size() - 1, -1, -1):
		var o: Dictionary = sim.obstacles[i]
		if not o.has("punch"):
			continue
		o.punch -= dt
		if o.punch <= 0.0:
			var was := o.duplicate()
			was.x = RunnerSim.obstacle_left(o, sim.x)
			sim.obstacles.remove_at(i)
			skill_used.append({"skill": "punch_hit", "look": "tuxedo", "x": was.x + was.w * 0.5, "y": (was.y0 + minf(was.y1, was.y0 + 200.0)) * 0.5, "target": was})
	for cat in cats:
		if not Balance.KITTEN_SKILLS.has(cat.look):
			continue
		cat.cool = maxf(0.0, cat.cool - dt)
		if cat.cool > 0.0 or sim.dashing:
			continue
		match Balance.KITTEN_SKILLS[cat.look].skill:
			"punch":
				_punch(sim, cat)
			"sparkle":
				_sparkle(sim, cat)


## 냥펀치: 앞쪽(화면 안) 가장 가까운 장애물 하나로 날아감 (SKILL_PUNCH_TRAVEL초 뒤 부서짐, punch_hit)
func _punch(sim: RunnerSim, cat: Dictionary) -> void:
	var best := {}
	var best_left := INF
	for o in sim.obstacles:
		var left := RunnerSim.obstacle_left(o, sim.x)
		if not o.has("punch") and left > sim.x + Balance.SKILL_AHEAD.x and left < sim.x + Balance.SKILL_AHEAD.y and left < best_left:
			best = o
			best_left = left
	if best.is_empty():
		return
	best.punch = Balance.SKILL_PUNCH_TRAVEL
	cat.cool = cooldown(cat.look)
	skill_used.append({"skill": "punch", "look": cat.look, "x": best_left + best.w * 0.5, "y": (best.y0 + minf(best.y1, best.y0 + 200.0)) * 0.5, "target": best})


## 반짝 코: 앞쪽 생선 SKILL_GOLD_COUNT마리를 황금으로 (가까운 것부터)
func _sparkle(sim: RunnerSim, cat: Dictionary) -> void:
	var ahead := sim.items.filter(func(item: Dictionary) -> bool:
		return item.kind == "fish" and item.x > sim.x + Balance.SKILL_AHEAD.x and item.x < sim.x + Balance.SKILL_AHEAD.y)
	if ahead.is_empty():
		return
	ahead.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.x < b.x)
	ahead = ahead.slice(0, Balance.SKILL_GOLD_COUNT)
	for item in ahead:
		item.kind = "gold"
		item.erase("bonus")
	cat.cool = cooldown(cat.look)
	skill_used.append({"skill": "sparkle", "look": cat.look, "x": ahead[0].x, "y": ahead[0].y, "target": ahead})


## 물어 오기: 필수 생선을 놓친 순간 RunnerSim이 부름. 준비된 치즈가 있으면 쓰고 true (생선은 먹은 것으로)
func fetch(item: Dictionary) -> bool:
	for cat in cats:
		if Balance.KITTEN_SKILLS.get(cat.look, {}).get("skill", "") == "fetch" and cat.cool <= 0.0:
			cat.cool = cooldown(cat.look)
			skill_used.append({"skill": "fetch", "look": cat.look, "x": item.x, "y": item.y, "target": item})
			return true
	return false


## 무리에 아직 없는 품종 하나 (같은 아이가 둘 보이지 않게, 무리는 최대 6 = 품종 수)
func _new_look() -> String:
	var free := LOOKS.filter(func(look: String) -> bool: return not cats.any(func(c: Dictionary) -> bool: return c.look == look))
	return free[_rng.randi() % free.size()] if not free.is_empty() else LOOKS[_rng.randi() % LOOKS.size()]
