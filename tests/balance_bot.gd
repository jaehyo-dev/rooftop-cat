extends RefCounted
## 밸런스 봇: 사람처럼 타이밍이 조금씩 어긋나게 점프하며 한 판을 끝까지 플레이하고, 버틴 시간을 잰다.
##
## 봇이 노리는 점프: 옥상에 내려설 때마다 "다음 옥상까지 최대로 눌러 닿을 수 있는 구간"의 가운데에서 누르려 한다.
## 더블점프: 점프 한 번으로 못 닿는 틈(전봇대 판까지 포함)은 처음부터 "점프 + 꼭대기에서 더블점프" 거리로 계획하고,
##   실수한 점프가 다음 발판에 못 미칠 것으로 계산돼도 쓴다. 쓰는 때는 가장 멀리 가는 때가 아니라 첫 점프 꼭대기 + timing 실수
##   (사람처럼, 난이도를 낮게 재지 않게).
## 특수 틈: 트램펄린 틈은 뛰지 않고 달려 들어가, 닿는 순간 + timing 실수에 톡 누른다 (판정 창 밖이면 실패해 떨어짐.
##   실패 뒤 남은 더블점프로 살리려 하지는 않음). 빨래줄 틈(은퇴, 켜면)은 옥상 끝에서 마지막에 최대로 뛰어 줄 위에 내리고 같은 방식으로 누른다.
##   전봇대 틈은 판 가운데로 뛰어 올라선 뒤 판에서 다음 옥상으로 뛴다. 착지할 때마다 다시 계획한다.
## 장애물(v0.6.0): 서 있는 옥상의 다음 장애물을 보고 그 종류에 가장 넓은 창이 나오는 동작(톡·중간·길게, 물탱크는 더블)을 골라 창 가운데에서 누른다.
##   비둘기가 함께 있으면 낮게(톡). 비둘기만 있으면 그대로 달린다. 맞아도 계속 달린다.
## 실력(skill)은 두 가지 실수로 나타낸다 (시드로 고정된 무작위 값):
## - timing: 누르는 순간이 어긋나는 정도 (초, 표준편차). 빠를수록 같은 시간 실수가 더 먼 거리가 된다
## - short_hold: 손을 일찍 떼는 정도 (최대로 누를 시간에 대한 비율, 표준편차)
## shortcut: 사람의 반응 속도·피로는 흉내 내지 않음. 실제 플레이 기록이 생기면 그 값으로 실력 수치를 맞춘다

const DT := 1.0 / 120.0
## 줄·트램펄린에 닿는 때를 이만큼 앞에서 보고 누를 때를 정한다 (초)
const LINE_LOOK := 0.6

## 실력별 실수 크기. 초보 = 처음 해 보는 사람, 익숙함 = 몇 판 해 본 사람, 숙련 = 많이 해 본 사람
const SKILLS := {
	"초보": {"timing": 0.085, "short_hold": 0.35},
	"익숙함": {"timing": 0.05, "short_hold": 0.2},
	"숙련": {"timing": 0.035, "short_hold": 0.12},
}


## seed_value로 정해진 옥상에서 한 판 플레이하고 버틴 시간(초)을 돌려준다. max_time초를 버티면 max_time
## start_speed·accelerate: 처음 속도와 빨라지는지 (속도를 고정해 보는 테스트용)
static func play(skill: Dictionary, seed_value: int, max_time: float, start_speed: float = Balance.RUN_SPEED, accelerate: bool = true) -> float:
	return play_stats(skill, seed_value, max_time, start_speed, accelerate).time


## play와 같지만 특수 틈 성적도 돌려준다: time, tramp_try/tramp_ok(트램펄린 틈 들어감/건넘), line_try/line_ok(줄 틈), pole_try/pole_ok(전봇대 틈),
## touch_try/touch_ok(줄·트램펄린에 닿은 횟수/누름·퍼펙트로 튕긴 횟수), doubles(더블점프 쓴 횟수), death(떨어진 곳: tramp/line/pole/plain).
## inputs를 주면 step마다 누름 여부를 담는다 (캡처 도구가 같은 판을 다시 재생하는 데 씀).
## 특수 틈 하나 = 틈 시작(앞 옥상 끝)을 지나면 시도, 구제 없이 다음 옥상(no_ghost)에 내려서면 성공
## 아이템 성적: dash_count/dash_smashed/dash_seconds/dash_fall(끝난 뒤 3초 안에 떨어짐), first_dash(첫 질주 먹은 시각, 못 먹으면 -1), eaten(종류별 먹은 수),
## score(판 점수), dash_points(질주 중 생선 점수, 2배 포함), made(종류별 놓인 수), yarn_fish/yarn_time·plain_fish/plain_time(털실·평소의 생선과 시간), blocks(방울이 막은 수), canned(통조림으로 바뀐 장애물 수), cookie_full(하트 3개에서 먹은 쿠키).
## missions: 이 판의 미션 기록 (MissionTracker.result, v0.7.0 2b).
## off: 끌 아이템 종류 (효과 비교용). perks: 강화·부스터 (null = 0단계, v0.7.0). dash_at: 질주를 시작한 시각들
static func play_stats(skill: Dictionary, seed_value: int, max_time: float, start_speed: float = Balance.RUN_SPEED, accelerate: bool = true, inputs: Array = [], off: Array = [], perks: Perks = null) -> Dictionary:
	var stats := {"time": 0.0, "tramp_try": 0, "tramp_ok": 0, "line_try": 0, "line_ok": 0, "pole_try": 0, "pole_ok": 0, "touch_try": 0, "touch_ok": 0, "doubles": 0,
			"end": "", "hits": {}, "segment_try": {}, "segment_ok": {},
			"dash_count": 0, "dash_smashed": 0, "dash_seconds": [], "dash_fall": 0, "first_dash": -1.0, "dash_at": [], "eaten": {}, "made": {},
			"yarn_fish": 0, "yarn_time": 0.0, "plain_fish": 0, "plain_time": 0.0, "blocks": 0, "canned": 0, "cookie_full": 0,
			"score": 0, "dash_points": 0}
	var dash_began := 0.0
	var dash_over := -99.0
	var seg_roof := {}     # 지금 지나는 구간 옥상 (단계별 통과율)
	var seg_stage := 0
	var seg_hearts := 0
	var seen := {}         # 이미 센 특수 틈 (다음 옥상 왼쪽 x)
	var gap_roof := {}     # 지금 건너는 중인 특수 틈의 다음 옥상
	var gap_kind := ""
	var sim := RunnerSim.new(seed_value, start_speed, true, perks)
	var tracker := MissionTracker.new()  # 게임과 같은 미션 세기 (v0.7.0 2b)
	sim.accelerate = accelerate
	sim.slots.off = off
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var planned_roof := {}   # 점프를 계획한 옥상 (내려설 때마다 새로 계획)
	var press_x := INF       # 이 위치에 오면 누른다
	var hold := 0.0          # 누를 시간
	var hold_left := 0.0
	var dj_delay := INF      # 점프한 뒤 이만큼 지나 더블점프 (INF = 안 씀)
	var dj_hold := 0.0
	var dj_at := INF         # 더블점프를 누를 시각 (sim.elapsed)
	var tap_at := INF        # 줄에 닿을 때 누를 시각
	var tapped := false      # 이번 닿음에 이미 눌렀는지
	while not sim.game_over and sim.elapsed < max_time:
		var ground: Dictionary = sim.get("_ground_roof")
		if sim.dashing:
			# 질주 중에는 뛰지 않는다 (남은 계획이 끝난 뒤 입력을 막지 않게 지운다)
			press_x = INF
			hold_left = 0.0
			dj_at = INF
			tap_at = INF
			planned_roof = {}
		if sim.landed:
			planned_roof = {}  # 착지(같은 옥상에 다시 내려앉은 경우 포함)할 때마다 새로 계획
			dj_at = INF
			tap_at = INF
			tapped = false
		# 트램펄린 뒤 긴 옥상은 내려설 때 다음 옥상이 아직 안 만들어졌을 수 있다: 생길 때까지 계획을 미룬다
		var next_known := sim.roofs.find(ground) + 1 < sim.roofs.size()
		var unplanned: bool = sim.on_ground and not sim.dashing and not is_same(ground, planned_roof)
		var hop := _obstacle_plan(sim, ground) if unplanned else {}
		if unplanned and not next_known and hop.is_empty():
			press_x = INF
		if unplanned and (next_known or not hop.is_empty()):
			planned_roof = ground
			var plan: Dictionary = hop if not hop.is_empty() else _plan(sim)
			press_x = plan.x + rng.randfn(0.0, skill.timing) * sim.speed
			var max_hold := JumpModel.max_hold_time()
			# 손 떼는 때는 사람처럼 양쪽으로 흔들린다 (톡이 길어지면 비둘기에 맞는다). 최대로 누르는 틈 점프는 짧게만
			hold = clampf(plan.hold + rng.randfn(0.0, skill.short_hold) * max_hold, 0.02, max_hold) if plan.has("hold") else \
					max_hold * clampf(1.0 - absf(rng.randfn(0.0, skill.short_hold)), 0.0, 1.0)
			if hop.is_empty():
				var needed := _plate_hold(sim, press_x, plan.dj)
				if needed >= 0.0:
					hold = minf(hold, needed)  # 판으로 뛸 자리를 이미 지났으면 눌러서 뛰는 시간을 줄여 판 가운데에 맞춘다
			# 계획대로 더블점프를 쓰거나, 실수한 점프가 다음 발판에 못 미치면 첫 점프 꼭대기 + timing 실수에 더블점프
			dj_delay = INF
			if plan.dj or (hop.is_empty() and _falls_short(sim, press_x, hold)):
				dj_delay = maxf(hold + 2.0 * DT, hold + JumpModel.jump_speed() / Balance.GRAVITY + rng.randfn(0.0, skill.timing))
			dj_hold = JumpModel.double_max_hold() * clampf(1.0 - absf(rng.randfn(0.0, skill.short_hold)), 0.0, 1.0)
		if sim.x >= press_x:
			press_x = INF
			hold_left = hold + DT  # 누르는 첫 step은 점프 시작이라 한 칸 더 누른다
			dj_at = sim.elapsed + dj_delay
		if sim.elapsed >= dj_at:
			dj_at = INF
			hold_left = dj_hold + DT
		# 줄·트램펄린: 닿는 때를 보고 그 순간 + timing 실수에 톡 누른다 (튕길 때마다 다시. 땅 위에서는 달려 들어가는 트램펄린만 잡힘)
		if tap_at == INF and not tapped and hold_left <= 0.0:
			var touch := sim.line_touch_eta(LINE_LOOK)
			if not touch.is_empty() and not sim.is_riding():
				tap_at = sim.elapsed + touch.t + rng.randfn(0.0, skill.timing)
		var tap := not tapped and sim.elapsed >= tap_at
		tapped = tapped or tap  # 이번 닿음에는 한 번만 누른다 (튕기면 다시)
		var fish_before := sim.fish
		var hearts_before := sim.hearts
		var yarn_on := sim.magnet_time > 0.0
		var points_before := sim.combo.points
		var dashing_before := sim.dashing
		sim.step(DT, hold_left > 0.0 or tap)
		tracker.observe(sim)
		if dashing_before:
			stats.dash_points += sim.combo.points - points_before  # 질주 중 생선 점수 (2배 포함)
			stats.dash_fish = stats.get("dash_fish", 0) + sim.fish - fish_before
		inputs.append(hold_left > 0.0 or tap)
		hold_left -= DT
		for item in sim.picked:
			stats.eaten[item.kind] = stats.eaten.get(item.kind, 0) + 1
			if item.kind == "cookie" and hearts_before >= Balance.HEARTS_MAX:
				stats.cookie_full += 1
		# 황금과 질주 중은 빼고 생선 먹는 빠르기를 비교한다
		if not sim.dashing:
			var ate := sim.fish - fish_before
			for item in sim.picked:
				ate -= Balance.GOLD_FISH if item.kind == "gold" else 0
			stats.yarn_fish += ate if yarn_on else 0
			stats.plain_fish += 0 if yarn_on else ate
			stats.yarn_time += DT if yarn_on else 0.0
			stats.plain_time += 0.0 if yarn_on else DT
		stats.dash_smashed += sim.smashed.size()
		stats.canned += sim.canned.size()
		stats.blocks += 1 if sim.bell_blocked else 0
		if sim.dash_started:
			stats.dash_count += 1
			dash_began = sim.elapsed
			stats.dash_at.append(sim.elapsed)
			if stats.first_dash < 0.0:
				stats.first_dash = sim.elapsed
		if sim.dash_ended:
			dash_over = sim.elapsed
			stats.dash_seconds.append(sim.elapsed - dash_began)
		if sim.fell and sim.elapsed - dash_over < 3.0:
			stats.dash_fall += 1
		if sim.bounced:
			tap_at = INF
			tapped = false
			stats.touch_try += 1
			if sim.bounce_result == "perfect" or sim.bounce_result == "good":
				stats.touch_ok += 1
			stats.perfects = stats.get("perfects", 0) + (1 if sim.bounce_result == "perfect" else 0)
		if sim.double_jumped:
			stats.doubles += 1
		if not sim.hit_obstacle.is_empty() and not sim.bell_blocked:
			stats.hits[sim.hit_obstacle.kind] = stats.hits.get(sim.hit_obstacle.kind, 0) + 1
		# 구간 옥상 통과율: 옥상 끝까지 하트를 잃지 않고 살아서 지나면 통과
		if seg_roof.is_empty():
			var here := sim.roof_at(sim.x)
			if here.has("segment"):
				seg_roof = here
				seg_stage = sim.stage
				seg_hearts = sim.hearts
				stats.segment_try[seg_stage] = stats.segment_try.get(seg_stage, 0) + 1
		elif sim.game_over or sim.x > seg_roof.right:
			if not sim.game_over and sim.hearts == seg_hearts:
				stats.segment_ok[seg_stage] = stats.segment_ok.get(seg_stage, 0) + 1
			seg_roof = {}
		# 특수 틈 성적
		if gap_roof.is_empty():
			for i in sim.roofs.size():
				var r: Dictionary = sim.roofs[i]
				if not r.get("no_ghost", false) or seen.has(r.left) or (i < 2 and not r.has("tramp")) or sim.dashing:
					continue
				var start: float = r.line.left if r.has("line") else (r.tramp.left if r.has("tramp") else sim.roofs[i - 2].right)
				if sim.x > start and sim.x < r.left:
					seen[r.left] = true
					gap_roof = r
					gap_kind = "line" if r.has("line") else ("tramp" if r.has("tramp") else "pole")
					stats[gap_kind + "_try"] += 1
		elif sim.landed and is_same(sim.get("_ground_roof"), gap_roof):
			stats[gap_kind + "_ok"] += 1
			gap_roof = {}
		elif sim.rescued or sim.game_over or sim.x > gap_roof.right:
			gap_roof = {}
	stats.time = minf(sim.elapsed, max_time)
	stats.score = sim.score()
	stats.fish = sim.fish  # 이번 판에 번 생선 (v0.7.0 경제 계산)
	stats.meters = sim.distance()
	stats.combo_best = sim.combo.best
	stats.end = sim.end_reason
	stats.missions = tracker.result(sim)  # 미션 기록 (MissionTracker)
	stats.made = sim.slots.made
	if sim.game_over:
		# 어디서 떨어졌는지 (보고용): tramp / line / pole / plain
		var here := {}
		for r in sim.roofs:
			if r.right >= sim.x - Balance.CAT_FOOT_HALF:
				here = r
				break
		stats.death = "tramp" if here.has("tramp") else "line" if here.has("line") else ("pole" if here.get("no_ghost", false) or here.get("platform", false) else "plain")
	return stats


## 서 있는 옥상의 다음 장애물(비둘기 제외)을 구간에 적힌 동작으로 넘는 계획 {"x", "hold", "dj"}. 없으면 빈 Dictionary
static func _obstacle_plan(sim: RunnerSim, ground: Dictionary) -> Dictionary:
	var next := {}
	for o in sim.obstacles:
		if o.has("action") and o.x >= ground.left and o.x <= ground.right and o.x + o.w > sim.x and (next.is_empty() or o.x < next.x):
			next = o
	if next.is_empty():
		return {}
	var lead := FishRoad.press_lead(next.kind, next.action, roundf(sim.speed / 10.0) * 10.0)
	return {"x": next.x - lead * sim.speed, "hold": FishRoad.center_variant(next.action)[0], "dj": next.action == "double"}


## 최대 점프 + 첫 점프 꼭대기에서 더블점프(최대)의 체공 시간 (높이 차 rise)
static func _apex_double_time(rise: float) -> float:
	var v := JumpModel.jump_speed()
	var hold := JumpModel.max_hold_time()
	return JumpModel.double_total_time(v, hold, hold + v / Balance.GRAVITY, rise)


## 다음 발판으로 뛸 계획 {"x": 누를 위치, "dj": 더블점프를 쓸지}
static func _plan(sim: RunnerSim) -> Dictionary:
	var here := sim.roofs.find(sim.get("_ground_roof"))
	if here < 0 or here + 1 >= sim.roofs.size():
		return {"x": INF, "dj": false}
	var roof: Dictionary = sim.roofs[here]
	var next: Dictionary = sim.roofs[here + 1]
	var latest: float = roof.right + Balance.CAT_FOOT_HALF - 10.0  # 이보다 늦으면 발밑이 빔
	if next.has("tramp"):
		return {"x": INF, "dj": false}  # 트램펄린 틈: 뛰지 않고 달려 들어감
	if next.has("line"):
		# 줄 틈: 틈 시작 조금 안쪽 줄 위에 내리도록 최대로 뛴다. 일찍 뛰면 옥상에 다시 내릴 뿐이라 늦는 쪽이 위험하다
		var land_x: float = roof.right + 90.0
		return {"x": minf(land_x - sim.speed * JumpModel.max_air_time(Balance.LINE_HEIGHT), latest), "dj": false}
	var rise: float = next.top - roof.top
	if next.get("platform", false):
		# 전봇대 판: 넓은 틈이라 항상 더블점프. 최대 점프 + 꼭대기 더블점프로 판 가운데에 내려앉는 위치 (너무 앞이면 마지막 순간)
		var center: float = (next.left + next.right) * 0.5
		return {"x": minf(center - sim.speed * _apex_double_time(rise), latest), "dj": true}
	# 지금 속도로 계산 (점프 중 단계가 오르면 조금 더 멀리 가지만 무시)
	var reach := sim.speed * JumpModel.max_air_time(rise)
	var earliest: float = next.left - Balance.CAT_FOOT_HALF - reach + 10.0  # 이보다 일찍 누르면 앞발이 못 걸침
	if earliest <= latest - 20.0:
		return {"x": minf((earliest + latest) * 0.5, latest), "dj": false}
	# 점프 한 번으로는 빠듯한 틈 (판에서 다음 옥상 등): 꼭대기 더블점프 거리로 계획
	var dj_earliest: float = next.left - Balance.CAT_FOOT_HALF - sim.speed * _apex_double_time(rise) + 10.0
	return {"x": minf((dj_earliest + latest) * 0.5, latest), "dj": true}


## press_x에서 hold초 누른 점프 한 번이 다음 발판(줄·트램펄린 틈 제외)에 못 미치는지
static func _falls_short(sim: RunnerSim, press_x: float, hold: float) -> bool:
	var here := sim.roofs.find(sim.get("_ground_roof"))
	if here < 0 or here + 1 >= sim.roofs.size() or sim.roofs[here + 1].has("line") or sim.roofs[here + 1].has("tramp"):
		return false
	var next: Dictionary = sim.roofs[here + 1]
	var t := JumpModel.air_time(hold, next.top - sim.roofs[here].top)
	return t < 0.0 or press_x + sim.speed * t + Balance.CAT_FOOT_HALF < next.left + 10.0


## 다음이 전봇대 판이고 뛸 자리를 이미 지났을 때, 판 가운데에 내려앉는 누르는 시간. 해당 없으면 -1
## (더블점프를 쓸 계획이면 더블점프까지 더한 거리로 맞춘다)
static func _plate_hold(sim: RunnerSim, press_x: float, with_double: bool) -> float:
	var here := sim.roofs.find(sim.get("_ground_roof"))
	if here < 0 or here + 1 >= sim.roofs.size() or press_x >= sim.x:
		return -1.0
	var plate: Dictionary = sim.roofs[here + 1]
	if not plate.get("platform", false):
		return -1.0
	var rise: float = plate.top - sim.roofs[here].top
	var target: float = (plate.left + plate.right) * 0.5 - sim.x
	var v := JumpModel.jump_speed()
	var lo := 0.0
	var hi := JumpModel.max_hold_time()
	for i in 24:
		var mid := (lo + hi) * 0.5
		var t := JumpModel.double_total_time(v, mid, mid + v / Balance.GRAVITY, rise) if with_double else JumpModel.air_time(mid, rise)
		if t >= 0.0 and sim.speed * t < target:
			lo = mid
		else:
			hi = mid
	return lo
