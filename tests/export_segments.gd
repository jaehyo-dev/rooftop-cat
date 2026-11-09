extends SceneTree
## 구간 데이터와 생선 길을 design_check.py가 읽는 JSON으로 내보낸다 (자동 테스트가 아니라 설계 검사용 도구).
## 실행: godot --headless --path . -s res://tests/export_segments.gd
## review/v0.6.0/segments.json: 구간 정의와, 처음 나오는 단계·단계 9·단계 12의 호와 생선 ([x, y, 보너스면 1]).

const LEVELS := ["쉬움", "보통", "어려움"]


func _initialize() -> void:
	var segments: Array = []
	for id: String in CourseData.SEGMENTS:
		var seg: Dictionary = CourseData.SEGMENTS[id]
		var roads := {}
		for stage in [seg.min_stage, 9, 12]:
			var row: Array = Balance.SPEED_STAGES[stage - 1]
			var road := FishRoad.new()
			var roofs := CoursePlacer.build(id, row[1], row[2], 0.0, 0.0)
			var fish: Array = []
			for item in road.extend({"left": -3000.0, "right": -200.0, "top": 0.0}, roofs[0], [row[1]]):
				fish.append([snappedf(item.x, 0.1), snappedf(item.y, 0.1), 1 if item.has("bonus") else 0])
			for i in range(1, roofs.size()):
				for item in road.extend(roofs[i - 1], roofs[i], [row[1]]):
					fish.append([snappedf(item.x, 0.1), snappedf(item.y, 0.1), 1 if item.has("bonus") else 0])
			var flights: Array = []
			for f in road.flights:
				flights.append({"press_x": f.press_x, "name": f.name, "hold": f.hold, "double_at": f.double_at, "top": f.top})
			roads[str(stage)] = {"flights": flights, "fish": fish}
		var plain_roofs: Array = []
		for r: Dictionary in seg.roofs:
			var plain := r.duplicate(true)
			plain.obs = r.get("obs", []).map(func(o: Array) -> Array: return [o[0], o[1]])
			plain_roofs.append(plain)
		segments.append({"id": id, "name": seg.name, "level": LEVELS[seg.level], "min_speed": Balance.SPEED_STAGES[seg.min_stage - 1][1], "note": "", "roofs": plain_roofs, "roads": roads})
	var file := FileAccess.open("res://review/v0.6.0/segments.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"_설명": "tests/export_segments.gd로 만든다. 고치려면 scripts/logic/course_data.gd를 고치고 다시 내보낸다.", "segments": segments}))
	file.close()
	print("구간 %d개 내보냄" % segments.size())
	quit(0)
