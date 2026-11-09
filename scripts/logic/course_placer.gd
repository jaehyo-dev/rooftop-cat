class_name CoursePlacer
extends RefCounted
## 옥상 생성기(RoofGenerator) 위에 손으로 짠 구간을 얹는다: 구간 → 쉼 옥상 → 구간 → ... (PLAN 5번). 같은 시드면 같은 맵.
## 쉼 옥상은 생성기의 next_roof 그대로라 여기서 트램펄린·전봇대 틈이 나온다. 구간 옥상에는 "segment", "obs"(장애물), "seg_items"(생선·황금), "slots"(아이템 자리)가 붙는다.

## 밀도를 곱하지 않는 입구 길이: 첫 장애물까지(빈 옥상은 이 초까지). 줄이면 착지 뒤 판단 시간이 모자란다
const EMPTY_ROOF_LEAD := 1.4

var _generator: RoofGenerator
var _rng := RandomNumberGenerator.new()
var _script: Array = Balance.SEGMENT_SCRIPT.duplicate()
var _queue: Array[Dictionary] = []  # 지금 구간에서 아직 내놓지 않은 옥상
var _rests := 0  # 다음 구간까지 남은 쉼 옥상
var _last_id := ""
var _next_obstacle := 0


func _init(generator: RoofGenerator, seed_value: int) -> void:
	_generator = generator
	_rng.seed = hash(seed_value) ^ 0x3c6ef372


## prev 다음 옥상. speed·stage = 지금 달리는 속도와 단계
func next_roof(prev: Dictionary, speed: float, stage: int) -> Dictionary:
	if not _queue.is_empty():
		return _queue.pop_front()
	if _generator.has_pending():
		return _generator.next_roof(prev, speed)  # 전봇대 판 뒤 옥상은 끊지 않는다
	var mix: Array = mix_for(stage)
	if _rests > 0:
		_rests -= 1
		_generator.special_chance = 0.0 if not _script.is_empty() else mix[6]
		return _generator.next_roof(prev, speed)
	var scripted := not _script.is_empty()
	var id: String = _script.pop_front() if scripted else _pick(mix, stage)
	var seg: Dictionary = CourseData.SEGMENTS[id]
	_last_id = id
	# 대본 중에는 첫 구간 뒤에만 쉰다 (첫 질주가 약 20~25초에 나오게). 어려운 구간 뒤에는 반드시 쉰다
	var script_rest := 1 if _script.size() == Balance.SEGMENT_SCRIPT.size() - 1 else 0
	_rests = script_rest if scripted and not _script.is_empty() else (1 if seg.level == 2 else _rng.randi_range(mix[4], mix[5]))
	var density: float = Balance.SPEED_STAGES[stage - 1][2]
	var top := _entry_top(seg, prev)
	var gap := _rng.randf_range(Balance.ROOF_GAP_MIN, RoofGenerator.max_gap(speed, top - prev.top))
	_queue = build(id, speed, density, prev.right + gap, top, _next_obstacle)
	for roof in _queue:
		_next_obstacle += roof.obs.size()
		if scripted and _script.is_empty():
			for slot: Dictionary in roof.slots:
				slot.forced = "dash"  # 대본 마지막 구간 = 첫 질주 보장
	return _queue.pop_front()


## 질주 착지 옥상을 끼워 넣으려고 아직 내놓지 않은 구간 옥상을 버린다
func drop_queue() -> void:
	_queue.clear()


## 이 단계의 섞임 표 줄 (Balance.SEGMENT_MIX)
static func mix_for(stage: int) -> Array:
	for row in Balance.SEGMENT_MIX:
		if stage <= row[0]:
			return row
	return Balance.SEGMENT_MIX[-1]


## 구간 id를 속도 v, 밀도 density의 옥상들로 펼친다. left·top = 첫 옥상 왼쪽 끝과 높이, first_id = 첫 장애물 번호
static func build(id: String, v: float, density: float, left: float, top: float, first_id: int = 0) -> Array[Dictionary]:
	var roofs: Array[Dictionary] = []
	var x := left
	var obstacle_id := first_id
	for r: Dictionary in CourseData.SEGMENTS[id].roofs:
		var rise: float = r.get("rise", 0.0)
		x += r.get("gap", 0.0) * JumpModel.max_reach(v, rise)
		top += rise
		var lead := _lead(r)
		var roof := {"left": x, "right": x + _squeeze(r.t, lead, density) * v, "top": top, "segment": id, "obs": [] as Array[Dictionary], "seg_items": [] as Array[Dictionary], "slots": [] as Array[Dictionary]}
		for o: Array in r.get("obs", []):
			var info: Dictionary = Balance.OBSTACLES[o[0]]
			var obstacle := {"id": obstacle_id, "kind": o[0], "x": x + _squeeze(o[1], lead, density) * v, "w": info.w, "y0": top + info.y0, "y1": top + info.y1, "base": top}
			if o[0] == "flock":
				obstacle.k = Balance.FLOCK_SPEED / v
			roof.obs.append(obstacle)
			obstacle_id += 1
		for it: Array in r.get("items", []):
			var at: float = x + _squeeze(it[1], lead, density) * v
			if it[0] == "slot":
				roof.slots.append({"x": at, "y": top + it[2]})
			elif it[0] == "gold":
				roof.seg_items.append({"kind": "gold", "x": at, "y": top + it[2]})
			else:
				for n in it[3]:
					roof.seg_items.append({"kind": "fish", "x": at + n * Balance.FISH_SPACING, "y": top + it[2]})
		roofs.append(roof)
		x = roof.right
	return roofs


## 옥상의 첫 장애물까지 시간 (밀도를 곱하지 않는 입구)
static func _lead(r: Dictionary) -> float:
	var lead := EMPTY_ROOF_LEAD
	var obs: Array = r.get("obs", [])
	if not obs.is_empty():
		lead = obs[0][1]
		for o: Array in obs:
			lead = minf(lead, o[1])
	return lead


## 입구 뒤 간격에만 밀도를 곱한다
static func _squeeze(at: float, lead: float, density: float) -> float:
	return at if at <= lead else lead + (at - lead) * density


## 앞 옥상에서 건너갈 수 있으면서 구간 전체가 옥상 높이 범위(물탱크는 세로 카메라) 안에 드는 첫 옥상 높이
func _entry_top(seg: Dictionary, prev: Dictionary) -> float:
	var high := Balance.ROOF_TOP_MAX
	var rise := 0.0
	for r: Dictionary in seg.roofs:
		rise += r.get("rise", 0.0)
		for o: Array in r.get("obs", []):
			if o[0] == "tank":
				high = minf(high, Balance.SEGMENT_TANK_TOP_MAX)
	return _rng.randf_range(maxf(Balance.ROOF_TOP_MIN, prev.top - Balance.ROOF_TOP_STEP), minf(high - rise, prev.top + Balance.ROOF_TOP_STEP))


## 단계 섞임에 따라 구간을 고른다 (같은 구간 연속 금지)
func _pick(mix: Array, stage: int) -> String:
	var roll := _rng.randf()
	var level := 0 if roll < mix[1] else (1 if roll < mix[1] + mix[2] else 2)
	var choices: Array[String] = []
	# 이 단계에 나올 구간이 없는 난이도면 한 단계 쉬운 쪽에서
	while choices.is_empty():
		for id: String in CourseData.SEGMENTS:
			var seg: Dictionary = CourseData.SEGMENTS[id]
			if seg.level == level and seg.min_stage <= stage and id != _last_id:
				choices.append(id)
		level -= 1
	return choices[_rng.randi_range(0, choices.size() - 1)]
