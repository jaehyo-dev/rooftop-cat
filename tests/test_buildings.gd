extends TestCase
## 주택가 건물: 옥상 폭에 맞춘 조각 배치, 소품 배치(판정 없는 장식), 그림 맨 윗줄 = 옥상 충돌선.

## 시드로 옥상 count개를 만든다 (첫 옥상 포함)
func _roofs(seed_value: int, count: int) -> Array[Dictionary]:
	var gen := RoofGenerator.new(seed_value)
	var roofs: Array[Dictionary] = [RoofGenerator.first_roof(0.0)]
	for i in count:
		roofs.append(gen.next_roof(roofs[-1], Balance.RUN_SPEED))
	return roofs


func test_같은_옥상은_항상_같은_모습() -> void:
	var widths := BuildingArt.widths()
	for roof in _roofs(3, 30):
		assert_eq(BuildingLayout.plan(roof.left, roof.right, widths), BuildingLayout.plan(roof.left, roof.right, widths))
		assert_eq(BuildingLayout.props(roof.left, roof.right), BuildingLayout.props(roof.left, roof.right))


func test_조각을_이어_붙이면_옥상_폭과_캡_튀어나옴에_정확히_맞는다() -> void:
	var widths := BuildingArt.widths()
	var styles_seen := {}
	for roof in _roofs(5, 300):
		var plan := BuildingLayout.plan(roof.left, roof.right, widths)
		var style: Dictionary = widths[plan.style]
		var total: float = style.left + style.right
		for index in plan.mids:
			total += style.mids[index] * plan.stretch
		assert_true(absf(total - (roof.right - roof.left - 0.0 + 2.0 * BuildingLayout.OVERHANG)) < 0.01, "폭 %f" % (roof.right - roof.left))
		# 가운데 조각이 너무 늘거나 줄면 창문이 일그러져 보인다
		assert_true(plan.stretch >= 0.75 and plan.stretch <= 1.35, "늘임 %f (옥상 폭 %f)" % [plan.stretch, roof.right - roof.left])
		styles_seen[plan.style] = true
	assert_eq(styles_seen.size(), widths.size(), "건물 종류가 골고루 나옴")


func test_소품은_옥상_안쪽_여백을_지키고_서로_떨어져_있다() -> void:
	var kinds := {}
	var with_props := 0
	var roofs := _roofs(9, 400)
	for roof in roofs:
		var props := BuildingLayout.props(roof.left, roof.right)
		assert_true(props.size() <= 2, "소품은 한 옥상에 최대 2개")
		with_props += 1 if props.size() > 0 else 0
		for i in props.size():
			kinds[props[i].kind] = true
			assert_true(props[i].x >= roof.left + BuildingLayout.PROP_EDGE and props[i].x <= roof.right - BuildingLayout.PROP_EDGE, "양 끝 여백")
			if i > 0:
				assert_true(props[i].x - props[i - 1].x >= BuildingLayout.PROP_GAP, "소품 간격")
	assert_true(with_props > roofs.size() / 3 and with_props < roofs.size(), "소품이 있는 옥상과 없는 옥상이 섞임 (%d/%d)" % [with_props, roofs.size()])
	assert_eq(kinds.size(), BuildingLayout.PROP_WEIGHTS.size(), "소품 여섯 종류가 모두 나옴")


func test_너무_좁은_옥상에는_소품이_없다() -> void:
	assert_eq(BuildingLayout.props(0.0, 2.0 * BuildingLayout.PROP_EDGE).size(), 0)


## 그림의 맨 윗줄이 지붕 턱 윗면이어야 옥상 충돌선(그림을 놓는 높이)과 고양이 발이 맞는다
func test_건물_조각은_맨_윗줄이_불투명한_지붕_턱이다() -> void:
	for i in BuildingArt.STYLE_NAMES.size():
		var style := BuildingArt.style_textures(i)
		var pieces: Array = [style.left] + style.mids
		for tex in pieces:
			var image: Image = tex.get_image()
			assert_true(image.get_pixel(image.get_width() / 2, 0).a > 0.5, "%s 맨 윗줄이 비어 있음" % BuildingArt.STYLE_NAMES[i])
			assert_eq(image.get_height(), style.left.get_height(), "조각 높이가 모두 같음")


func test_건물_그림은_배경색_마젠타가_남지_않았다() -> void:
	for i in BuildingArt.STYLE_NAMES.size():
		var style := BuildingArt.style_textures(i)
		var pieces: Array = [style.left, style.right] + style.mids
		for tex in pieces:
			var image: Image = tex.get_image()
			var bad := 0
			for y in image.get_height():
				for x in image.get_width():
					var c := image.get_pixel(x, y)
					if c.a > 0.2 and minf(c.r, c.b) - c.g > 0.2:
						bad += 1
			assert_true(bad <= 3, "%s 조각에 마젠타 픽셀 %d개" % [BuildingArt.STYLE_NAMES[i], bad])


func test_고양이_발_내림은_건물_3종_지붕_턱_윗면_가운데() -> void:
	# 지붕 턱 윗면 = 위쪽 어두운 뒤 선 ~ 아래쪽 어두운 앞 선 (가운데 조각의 가운데 세로줄 밝기로 찾음)
	var sink: float = load("res://scripts/world_view.gd").FOOT_SINK
	for style in BuildingArt.STYLE_NAMES.size():
		for tex in BuildingArt.style_textures(style).mids:
			var img: Image = tex.get_image()
			var x := img.get_width() / 2
			var back := _darkest_row(img, x, 0, 10)
			var front := _darkest_row(img, x, 20, 40)
			var mid := (back + front) * 0.5
			assert_true(absf(sink - mid) <= 2.0, "%s: 윗면 %d~%d줄, 가운데 %.1f, 내림 %.0f" % [BuildingArt.STYLE_NAMES[style], back, front, mid, sink])


func _darkest_row(img: Image, x: int, from: int, to: int) -> int:
	var best := from
	for y in range(from, to):
		if img.get_pixel(x, y).get_luminance() < img.get_pixel(x, best).get_luminance():
			best = y
	return best


func test_고양이와_그림자는_판정선보다_발_내림만큼_아래에_그린다() -> void:
	var world: Node2D = load("res://scripts/world_view.gd").new()
	add_child(world)
	await wait_frames(2)
	var ground: float = world.call("_ground_y")
	assert_eq(world.cat.position.y, ground - world.sim.y + world.FOOT_SINK, "고양이 발끝")
	world.queue_free()
