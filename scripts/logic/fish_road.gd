class_name FishRoad
extends RefCounted
## 생선 길 (PLAN 16번): 옥상이 생길 때마다 땅 줄과 점프 호를 깐다. 호는 JumpModel 궤적 그대로라 정답대로 뛰면 몸이 지나간다.
## 호는 앞 착지가 아니라 위험(장애물·틈)에 고정한다. 앞 호에서 어디에 내려왔든 다음 호 자리는 그대로다.
## 사람의 흔들림(누름 ±PRESS_SHIFT초, 누름 길이 양 끝, 달리는 속도들)이 모두 먹는 생선만 필수이고 나머지는 "bonus"(놓쳐도 콤보가 안 끊김).

const PRESS_SHIFT := 0.05   # 사람 기준 누름 흔들림 (초)
const EAT_SHRINK := 0.92    # 필수를 정할 때 먹는 타원을 이만큼 좁혀 본다 (프레임 간격 여유)
const SCAN_STEP := 8.0      # 틈 누름 자리를 훑는 간격 (픽셀)
const RESERVED_GAP := 50.0  # 아이템 자리 둘레에는 땅 생선을 놓지 않는다
const TAIL_SECONDS := 0.8   # 옥상 끝 이만큼은 다음 옥상이 나올 때까지 비워 둔다 (틈 호 자리를 아직 모름)
const AUTO_ACTIONS := ["tok", "mid", "long", "double"]

static var _lead_cache := {}

## 지금까지 깐 호의 누름 계획 {"press_x", "name", "hold", "double_at", "rise", "top"} (테스트·캡처가 따라 달리는 데 씀)
var flights: Array[Dictionary] = []
var _x := INF               # 다음 땅 생선 자리
var _last := {}             # 마지막 호 (흔들림 경로 포함)
var _late_land := -INF      # 늦게 눌러도 여기까지는 날아서 지나갈 수 있음 (그 앞 땅 생선은 보너스)
var _reserved: Array[float] = []


## 동작의 흔들림들: [[누름 길이, 더블 누르는 시각(없으면 -1)], ...]. 자리 계산은 가운데 값을 쓴다
static func variants(action: String) -> Array:
	var hold := JumpModel.max_hold_time()
	var apex := hold + JumpModel.jump_speed() / Balance.GRAVITY
	match action:
		"tok":
			return [[0.05, -1.0], [0.10, -1.0]]
		"mid":
			return [[0.13, -1.0], [0.18, -1.0]]
		"long":
			return [[hold, -1.0]]
	return [[hold, apex - PRESS_SHIFT], [hold, apex + PRESS_SHIFT]]


static func center_variant(action: String) -> Array:
	var v := variants(action)
	return [(v[0][0] + v[-1][0]) * 0.5, (v[0][1] + v[-1][1]) * 0.5]


## 누른 순간부터 내려앉을 때까지 [Vector2(시각, 출발 기준 높이), ...]. double_at >= 0이면 그때 더블점프(최대). rise = 내려앉을 높이 차
static func path(hold: float, double_at: float, rise: float = 0.0) -> Array[Vector2]:
	# RunnerSim과 같은 적분: 누르는 시간이 다 차면 그 칸의 나머지는 중력으로
	var v := JumpModel.jump_speed()
	var out: Array[Vector2] = []
	var y := 0.0
	var vy := v
	var t := 0.0
	var dt := 1.0 / 60.0
	var left := hold         # 지금 점프에서 남은 누름 시간
	var used := false        # 더블점프를 썼는지
	while t < 4.0:
		if double_at >= 0.0 and not used and t >= double_at:
			used = true
			vy = v
			left = JumpModel.double_max_hold()
		var rest := dt
		if left > 0.0:
			var held := minf(rest, left)
			vy = v
			y += v * held
			left -= held
			rest -= held
		if rest > 0.0:
			var moved := JumpModel.integrate(y, vy, rest, used)
			y = moved.x
			vy = moved.y
		t += dt
		out.append(Vector2(t, y))
		if vy < 0.0 and y <= rise:
			break
	return out


## 장애물(kind)을 action으로 넘을 때 왼쪽 끝 얼마나 앞(초)에서 누를지: 맞지 않는 창의 가운데 (같은 계산을 되풀이하지 않게 기억)
static func press_lead(kind: String, action: String, speed: float) -> float:
	var key := "%s %s %d" % [kind, action, roundi(speed)]
	if _lead_cache.has(key):
		return _lead_cache[key]
	var info: Dictionary = Balance.OBSTACLES[kind]
	var o := {"x": 0.0, "w": info.w, "y0": info.y0, "y1": info.y1}
	var center := center_variant(action)
	var route := path(center[0], center[1])
	var run := 0
	var best_run := 0
	var best := 0.0
	for i in 150:
		var lead := i / 60.0
		var safe: bool = (route[-1].x - lead) * speed > info.w + Balance.CAT_BODY_SIZE.x * 0.4
		for p in route:
			safe = safe and not RunnerSim.body_hits(o, (p.x - lead) * speed, p.y)
		run = run + 1 if safe else 0
		if run > best_run:
			best_run = run
			best = (i - (run - 1) * 0.5) / 60.0
	_lead_cache[key] = best
	return best


## 이 자리 둘레에는 땅 생선을 놓지 않는다 (아이템 자리·상자)
func reserve(at: float) -> void:
	_reserved.append(at)


## 이 자리에 땅 생선을 놓아도 되는지 (아이템 자리 둘레는 안 됨)
func is_free(at: float) -> bool:
	for spot in _reserved:
		if absf(at - spot) < RESERVED_GAP:
			return false
	return true


## 다음 땅 생선 자리 (질주용 줄이 여기까지 이어 준다)
func next_ground_x() -> float:
	return _x


static func is_fish(item: Dictionary) -> bool:
	return item.kind == "fish" or item.kind == "gold"


## 어느 x 자리든 생선 줄은 한 줄만: 먼저 놓인 생선과 x 간격이 FISH_SPACING 절반보다 가까우면 나중 것을 뺀다 (가파른 호도 듬성해질 뿐 한 줄)
static func add_one_line(items: Array[Dictionary], added: Array[Dictionary]) -> void:
	var near := Balance.FISH_SPACING * 0.5
	for item in added:
		var free := true
		if is_fish(item):
			for other in items:
				if is_fish(other) and absf(other.x - item.x) < near:
					free = false
					break
		if free:
			items.append(item)


## prev 다음에 roof가 생겼을 때 깔 생선들. speeds[0] = 고양이가 도착할 속도, 뒤는 지나는 동안 바뀔 속도
func extend(prev: Dictionary, roof: Dictionary, speeds: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_reserved = _reserved.filter(func(at: float) -> bool: return at >= prev.left)  # 지나간 자리는 잊는다 (긴 판에서 느려지지 않게)
	var special: bool = roof.get("no_ghost", false) or roof.get("platform", false) or prev.get("platform", false)
	if _x == INF:
		_x = prev.left + 400.0
	if roof.has("tramp") or roof.has("line"):
		# 트램펄린 앞까지 땅 줄. 호는 ItemPlacer가 놓는다 (결과에 따라 길이 갈려 전부 보너스)
		_ground(out, roof.tramp.left if roof.has("tramp") else prev.right, prev.top, {})
		_x = roof.left + Balance.TRAMP_LAND_IN + Balance.TRAMP_PERFECT_EXTRA + Balance.FISH_SPACING
		_last = {}
	else:
		var flight := _gap_flight(prev, roof, speeds)
		if prev.get("platform", false):
			_x = INF  # 전봇대 판은 작아서 땅 줄을 놓지 않는다
		if flight.is_empty():
			_x = roof.left + Balance.FISH_SPACING
			_last = {}
		else:
			_ground(out, flight.press_x, prev.top, flight)
			_air(out, flight, special, false)
			_late_land = flight.late_land
	if not roof.get("platform", false):
		for o: Dictionary in _sorted_obstacles(roof):
			var lead := press_lead(o.kind, o.action, speeds[0])
			var flight := _flight(o.action, o.x - lead * speeds[0], roof.top, 0.0, speeds)
			_ground(out, flight.press_x, roof.top, flight)
			_air(out, flight, false, o.get("gold", false))
		_ground(out, roof.right - TAIL_SECONDS * speeds[0], roof.top, {})
	return out


static func _sorted_obstacles(roof: Dictionary) -> Array:
	var list: Array = []
	for o: Dictionary in roof.get("obs", []):
		if o.has("action"):
			list.append(o)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.x < b.x)
	return list


## 땅 줄: 다음 땅 자리부터 end 앞까지. 앞뒤 호의 흔들림 경로가 날아 넘는 자리는 보너스
func _ground(out: Array[Dictionary], end: float, top: float, next_flight: Dictionary) -> void:
	while _x < end:
		if is_free(_x):
			var fish := {"kind": "fish", "x": _x, "y": top + Balance.ITEM_LIFT}
			var sure: bool = _x >= _late_land and _ground_sure(fish, _last) and _ground_sure(fish, next_flight)
			if not sure:
				fish.bonus = true
			out.append(fish)
		_x += Balance.FISH_SPACING


func _ground_sure(fish: Dictionary, flight: Dictionary) -> bool:
	for run: Dictionary in flight.get("runs", []):
		if fish.x >= run.press_x and fish.x <= run.land_x and not _run_eats(run, fish):
			return false
	return true


static func _run_eats(run: Dictionary, fish: Dictionary) -> bool:
	var reach := (Balance.CAT_BODY_SIZE * 0.5 + Vector2.ONE * Balance.ITEM_RADIUS) * EAT_SHRINK
	var at := Vector2(fish.x, fish.y)
	for p: Vector2 in run.points:
		if ((p - at) / reach).length_squared() <= 1.0:
			return true
	return false


## 호: 궤적을 호 길이 FISH_SPACING 간격으로 (더블은 기둥처럼 선다). gold면 꼭대기가 황금 생선
func _air(out: Array[Dictionary], flight: Dictionary, all_bonus: bool, gold: bool) -> void:
	var made: Array[Dictionary] = []
	var pts: PackedVector2Array = flight.points
	var walked := Balance.FISH_SPACING * 0.5
	for i in range(1, pts.size()):
		var seg := pts[i].distance_to(pts[i - 1])
		walked += seg
		if walked < Balance.FISH_SPACING:
			continue
		walked -= Balance.FISH_SPACING
		var fish := {"kind": "fish", "x": pts[i].x, "y": pts[i].y}
		var sure := not all_bonus
		for run: Dictionary in flight.runs:
			sure = sure and _run_eats(run, fish)
		if not sure:
			fish.bonus = true
		made.append(fish)
	if gold and not made.is_empty():
		var top := 0
		for i in made.size():
			top = i if made[i].y > made[top].y else top
		made[top].kind = "gold"
		made[top].bonus = true
	out.append_array(made)
	_last = flight
	_x = flight.land_x + Balance.FISH_SPACING * 0.5


## 틈을 건너는 호. roof.jump가 있으면 그 동작("none"이면 호 없음), 없으면 사람 흔들림(±PRESS_SHIFT)을 받아 주는 가장 쉬운 동작. 못 건너면 빈 Dictionary
func _gap_flight(prev: Dictionary, roof: Dictionary, speeds: Array) -> Dictionary:
	var v: float = speeds[0]
	var written: String = roof.get("jump", "")
	if written == "none":
		return {}
	var rise: float = roof.top - prev.top
	var latest: float = prev.right + Balance.CAT_FOOT_HALF - 10.0
	var names: Array = [written] if written != "" else AUTO_ACTIONS
	for action: String in names:
		var routes: Array = []
		var reach := INF
		for variant: Array in variants(action):
			routes.append(path(variant[0], variant[1], rise))
			reach = minf(reach, routes[-1][-1].x * v)
		if latest + reach + Balance.CAT_FOOT_HALF < roof.left + 15.0:
			continue  # 가장 늦게 뛰어도 안 닿음
		var hi := -INF
		var lo := INF
		var at := latest
		while at > maxf(maxf(_x, prev.left), latest - reach):
			if _clears_gap(routes, at, v, rise, roof):
				hi = maxf(hi, at)
				lo = at
			elif hi > -INF:
				break
			at -= SCAN_STEP
		if hi > -INF and (written != "" or hi - lo >= 2.0 * PRESS_SHIFT * v):
			var flight := _flight(action, (hi + lo) * 0.5, prev.top, rise, speeds)
			var center := center_variant(action)
			flight.late_land = latest + path(center[0], center[1], rise)[-1].x * v
			return flight
	return {}


## press_x에서 뛰면 흔들린 경로들(routes) 모두 벽에 안 닿고 roof에 내려서는지
static func _clears_gap(routes: Array, press_x: float, v: float, rise: float, roof: Dictionary) -> bool:
	for route: Array[Vector2] in routes:
		var land: float = press_x + route[-1].x * v
		if land + Balance.CAT_FOOT_HALF < roof.left + 15.0 or land - Balance.CAT_FOOT_HALF > roof.right or route[-1].y < rise - 40.0:
			return false
		for p in route:
			# 몸 앞이 벽 자리를 지나는 순간 발이 옥상보다 높아야 한다 (RunnerSim._move_forward)
			if press_x + p.x * v + Balance.CAT_BODY_SIZE.x * 0.5 >= roof.left:
				if p.y < rise:
					return false
				break
	return true


## 호 하나: 가운데 경로(points, 몸 가운데 좌표)와 사람 흔들림 경로들(runs)
func _flight(action: String, press_x: float, top: float, rise: float, speeds: Array) -> Dictionary:
	var center := center_variant(action)
	var route := path(center[0], center[1], rise)
	var v: float = speeds[0]
	var flight := {"press_x": press_x, "land_x": press_x + route[-1].x * v, "late_land": -INF, "points": _points(route, press_x, top, v), "runs": []}
	for variant: Array in variants(action):
		var shaken := path(variant[0], variant[1], rise)
		for speed: float in speeds:
			for shift in [-PRESS_SHIFT, 0.0, PRESS_SHIFT]:
				var start: float = press_x + shift * speed
				flight.runs.append({"press_x": start, "land_x": start + shaken[-1].x * speed, "points": _points(shaken, start, top, speed)})
	flights.append({"press_x": press_x, "name": action, "hold": center[0], "double_at": center[1], "rise": rise, "top": top})
	return flight


## 궤적을 몸 가운데 좌표로
static func _points(route: Array[Vector2], press_x: float, top: float, v: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in route:
		out.append(Vector2(press_x + p.x * v, top + p.y + Balance.ITEM_LIFT))
	return out
