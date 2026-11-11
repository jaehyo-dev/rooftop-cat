class_name MissionTracker
extends RefCounted
## 한 판 동안 미션에 쓸 사건을 센다 (화면과 분리된 로직, review/v0.7.0/PLAN.md 5-5). 게임과 밸런스 봇이 같은 것을 쓴다.
## sim.step 뒤마다 observe(sim)를 부르고, 판이 끝나면 result(sim)를 Missions.end_run에 넘긴다.
## 값 이름은 MissionTable의 stat 칸과 같다.

var counts := {}
var _smash_now := 0  # 이번 질주에서 부순 수


## step 하나에 일어난 일을 센다
func observe(sim: RunnerSim) -> void:
	for item in sim.picked:
		if item.kind in ["gold", "yarn", "can"]:
			_add(item.kind)
	if sim.dash_started:
		_add("dash")
		_smash_now = 0
	if not sim.smashed.is_empty():
		_add("smash", sim.smashed.size())
		_smash_now += sim.smashed.size()
		counts.smash_one = maxi(counts.get("smash_one", 0), _smash_now)
	if sim.double_jumped:
		_add("double")
	if sim.bounced and sim.bounced_line.kind == "tramp" and sim.bounce_result in ["perfect", "good"]:
		_add("tramp")
		if sim.bounce_result == "perfect":
			_add("perfect")
	if sim.stage_rose:
		_add("stage_ups")
	if sim.bell_blocked:
		_add("bell")
	if sim.landed and sim.get("_ground_roof").get("platform", false):
		_add("pole")
	for o in sim.passed:
		_add("pass_" + o.kind)
	counts.mult = maxi(counts.get("mult", 1), sim.combo.multiplier())


## 판이 끝났을 때 미션 기록 (한 판 기록형 값 + 센 것)
func result(sim: RunnerSim) -> Dictionary:
	var run := counts.duplicate()
	run.merge({"meters": sim.distance(), "fish": sim.fish, "combo": sim.combo.best, "stage": sim.stage, "runs": 1}, true)
	return run


func _add(key: String, amount: int = 1) -> void:
	counts[key] = counts.get(key, 0) + amount
