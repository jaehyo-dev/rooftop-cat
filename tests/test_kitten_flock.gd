extends TestCase
## 떠다니는 아기 배치·움직임 (KittenFlock, 2026-11-19): 줄줄이·요정 무리 쉬는 자리, 점프·더블점프·슬라이딩 동안 겹침·화면·지붕·순간이동·기울기,
## 줄이 앞에서부터 차례로 출렁, 합류·도망 때 이어서 움직임, 구름 납작

const DT := 1.0 / 60.0
const GROUND := 470.0  # 주인공 발끝 화면 y (평지)
const LEAD_X := Balance.CAT_SCREEN_X


func _cats(n: int) -> Array:
	var cats := []
	for i in n:
		cats.append({"look": CatParade.LOOKS[i], "quirk": fmod(0.37 * i + 0.11, 1.0)})
	return cats


func _floor(_x: float) -> float:
	return GROUND


## 점프(0.15초), 꼭대기 근처 더블점프: 주인공 발끝 높이 (화면 y). 착지 뒤 슬라이딩은 _sliding
func _lead_y(t: float) -> float:
	var g := 2600.0
	if t < 0.15:
		return GROUND
	var u := t - 0.15
	var y := 1100.0 * u - 0.5 * g * u * u
	if u > 0.45:
		var w := u - 0.45
		var y1 := 1100.0 * 0.45 - 0.5 * g * 0.45 * 0.45
		var v1 := 900.0
		y = y1 + v1 * w - 0.5 * g * w * w
	if y <= 0.0:
		return GROUND
	return GROUND - y


func _sliding(t: float) -> bool:
	return t > 1.6 and t < 2.2


func _flock(n: int) -> KittenFlock:
	var flock := KittenFlock.new()
	for i in n:
		flock.place(i, Vector2(LEAD_X, GROUND) + KittenFlock.rest(i, n))
	return flock


func _gap(a: Vector2, b: Vector2) -> float:
	var d := b - a
	return Vector2(d.x, d.y / KittenFlock.CLOUD_H).length()


func test_기본은_작게_줄줄이() -> void:
	assert_eq(Balance.KITTEN_SIZES[Balance.KITTEN_SIZE_PICK].name, "작게")
	assert_eq(KittenFlock.MODES[KittenFlock.mode_pick], "줄줄이")


## 쉬는 자리: 주인공 몸 뒤, 화면 왼쪽 안, 머리가 생선 수 아래, 구름끼리 안 겹침. 줄줄이는 4마리까지 한 줄, 그 뒤로 위로 굽음
func test_쉬는_자리는_주인공_뒤_화면_안에_안_겹치게() -> void:
	var keep := KittenFlock.mode_pick
	var r := KittenFlock.ratio()
	var cloud := KittenFlock.CLOUD_W * r
	for mode in KittenFlock.MODES.size():
		KittenFlock.mode_pick = mode
		for n in range(1, Balance.PARADE_MAX + 1):
			for i in n:
				var a := KittenFlock.rest(i, n)
				var name := "%s %d마리 자리 %d %s" % [KittenFlock.MODES[mode], n, i, a]
				assert_true(a.x + cloud * 0.5 <= -Balance.CAT_BODY_SIZE.x * 0.5, name + " 주인공 몸 뒤")
				assert_true(LEAD_X + a.x - cloud * 0.5 >= 0.0, name + " 화면 왼쪽 안")
				assert_true(GROUND + a.y >= KittenFlock.top(), name + " 생선 수 아래")
				assert_true(a.y <= -KittenFlock.FLOOR_LIFT * r, name + " 지붕 위")
				for j in range(i + 1, n):
					assert_true(_gap(a, KittenFlock.rest(j, n)) >= cloud, name + " 구름이 %d와 안 겹침" % j)
	KittenFlock.mode_pick = 0
	assert_eq(KittenFlock.rest(3, 4).y, KittenFlock.rest(0, 4).y, "4마리는 한 줄")
	assert_true(KittenFlock.rest(5, 6).y < KittenFlock.rest(1, 6).y, "6마리는 위로 굽음")
	KittenFlock.mode_pick = keep


## 줄 모양 (2026-11-19): 굽을 때 곧은 비탈(계단) 대신 뒤로 갈수록 덜 올라가는 활. 화면 안·안 겹침
func test_굽은_줄은_뒤로_갈수록_덜_올라간다() -> void:
	var keep := KittenFlock.mode_pick
	KittenFlock.mode_pick = 0
	var r := KittenFlock.ratio()
	for n in [5, 6]:
		var rises := []
		for i in range(1, n):
			var a := KittenFlock.rest(i - 1, n)
			var b := KittenFlock.rest(i, n)
			rises.append(a.y - b.y)
			assert_true(_gap(a, b) >= KittenFlock.CLOUD_W * r - 0.01, "%d마리 이웃 구름 안 겹침" % n)
			assert_true(LEAD_X + b.x - KittenFlock.CLOUD_W * r * 0.5 >= KittenFlock.EDGE - 0.5, "%d마리 자리 %d 화면 왼쪽 안" % [n, i])
		for k in range(1, rises.size()):
			assert_true(rises[k] < rises[k - 1] - 1.0, "%d마리 높이 차가 점점 줄어듦 %s" % [n, rises])
		assert_true(rises[-1] < rises[0] * 0.7, "%d마리 뒤쪽은 앞쪽보다 확실히 완만 %s" % [n, rises])
	KittenFlock.mode_pick = keep


## 슬라이딩 올리기 (2026-11-20, 뒤로 물리기 대신): 줄 모양(가로 자리) 그대로 SLIDE_LIFT만큼 위로, 오르내림 모두 0.15초 이상·한 프레임 이동 작게.
## 둥실거림을 빼려고 슬라이딩하지 않는 같은 무리와 프레임마다 비교
func test_슬라이딩_때_줄은_모양_그대로_천천히_올라갔다_내려온다() -> void:
	var cats := _cats(6)
	var flock := _flock(6)
	var calm := _flock(6)
	for sliding in [true, false]:
		var biggest := 0.0
		var settled := -1
		for f in 60:
			var last := flock.pos.duplicate()
			flock.step(DT, Vector2(LEAD_X, GROUND), cats, _floor, sliding)
			calm.step(DT, Vector2(LEAD_X, GROUND), cats, _floor)
			var want := -KittenFlock.SLIDE_LIFT if sliding else 0.0
			for i in 6:
				biggest = maxf(biggest, flock.pos[i].distance_to(last[i]))
				assert_true(absf(flock.pos[i].x - calm.pos[i].x) < 0.5, "프레임 %d 아기 %d 가로 자리 그대로" % [f, i])
				assert_true(flock.pos[i].y - calm.pos[i].y <= 0.5 and flock.pos[i].y - calm.pos[i].y >= -KittenFlock.SLIDE_LIFT - 0.5, "프레임 %d 아기 %d 높이 차 범위" % [f, i])
			if settled < 0 and absf(flock.pos[0].y - calm.pos[0].y - want) < 0.5:
				settled = f + 1
		var tag := "올라감" if sliding else "내려옴"
		assert_true(settled * DT >= 0.15 and settled * DT < 0.5, "%s %d프레임 만에 (0.15초 이상)" % [tag, settled])
		assert_true(biggest <= 6.0, "%s 한 프레임 가장 큰 이동 %.1f" % [tag, biggest])


## 점프·더블점프·슬라이딩 3초 동안 매 프레임: 구름 안 겹침, 지붕 아래·생선 수 위·화면 밖으로 안 감, 순간이동 없음, 기울기 10도 안·튀지 않음
func test_뛰어도_겹치거나_튀지_않는다() -> void:
	var keep := KittenFlock.mode_pick
	var r := KittenFlock.ratio()
	for mode in KittenFlock.MODES.size():
		KittenFlock.mode_pick = mode
		var flock := _flock(6)
		var cats := _cats(6)
		var last := flock.pos.duplicate()
		var last_tilt := flock.tilt.duplicate()
		var worst := {"gap": INF, "move": 0.0, "turn": 0.0}
		for f in 180:
			flock.step(DT, Vector2(LEAD_X, _lead_y(f * DT)), cats, _floor, _sliding(f * DT))
			for i in 6:
				var p: Vector2 = flock.pos[i]
				var tag := "%s 프레임 %d 아기 %d %s" % [KittenFlock.MODES[mode], f, i, p]
				assert_true(p.y <= GROUND - KittenFlock.FLOOR_LIFT * r + 0.01, tag + " 지붕 아래로")
				assert_true(p.y >= KittenFlock.top() - 20.0 * r - 0.01, tag + " 생선 수 위로")
				assert_true(p.x - KittenFlock.CLOUD_W * r * 0.5 >= KittenFlock.EDGE - 0.01, tag + " 화면 왼쪽 밖")
				assert_true(absf(flock.tilt[i]) <= KittenFlock.MAX_TILT + 0.001, tag + " 기울기")
				worst.move = maxf(worst.move, p.distance_to(last[i]))
				worst.turn = maxf(worst.turn, absf(flock.tilt[i] - last_tilt[i]))
				for j in range(i + 1, 6):
					worst.gap = minf(worst.gap, _gap(p, flock.pos[j]))
			last = flock.pos.duplicate()
			last_tilt = flock.tilt.duplicate()
		var name: String = KittenFlock.MODES[mode]
		assert_true(worst.gap >= KittenFlock.CLOUD_W * r * 0.98, "%s 구름 가장 가까움 %.1f" % [name, worst.gap])
		assert_true(worst.move <= KittenFlock.MAX_SPEED * DT + 0.5, "%s 한 프레임 가장 큰 이동 %.1f (순간이동 없음)" % [name, worst.move])
		assert_true(worst.turn <= deg_to_rad(2.0), "%s 한 프레임 가장 큰 기울기 변화 %.2f도" % [name, rad_to_deg(worst.turn)])
	KittenFlock.mode_pick = keep


## 가장 높이 올라간 때 (n마리, 처음 속도 v로 한 번 점프): 줄줄이는 앞 아기부터 약 0.12초씩 차례로, 요정 무리는 아기마다 다르게 (덩어리째 아님)
func _peaks(mode: int, n: int, v: float) -> Array:
	KittenFlock.mode_pick = mode
	var flock := _flock(n)
	var cats := _cats(n)
	var peak := []
	var at := []
	peak.resize(n)
	peak.fill(INF)
	at.resize(n)
	at.fill(0.0)
	for f in 120:
		var u := f * DT - 0.15
		flock.step(DT, Vector2(LEAD_X, GROUND - maxf(0.0, v * u - 1300.0 * u * u) if u > 0.0 else GROUND), cats, _floor)
		for i in n:
			if flock.pos[i].y - KittenFlock.rest(i, n).y < peak[i]:
				peak[i] = flock.pos[i].y - KittenFlock.rest(i, n).y
				at[i] = f * DT
	return at


func test_줄은_앞에서부터_차례로_출렁인다() -> void:
	var keep := KittenFlock.mode_pick
	for c in [[4, 900.0], [6, 500.0]]:
		var at := _peaks(0, c[0], c[1])
		for i in range(1, c[0]):
			var lag: float = at[i] - at[i - 1]
			assert_true(lag > 0.05 and lag < 0.2, "%d마리: 아기 %d는 앞 아기보다 %.3f초 늦게 꼭대기 %s" % [c[0], i, lag, at])
	var flock_at := _peaks(1, 6, 900.0)
	assert_true(flock_at.max() - flock_at.min() >= 0.08, "요정 무리는 꼭대기 때가 아기마다 다름 %s" % [flock_at])
	KittenFlock.mode_pick = keep


## 새 아기는 만난 자리에서 줄 끝으로 날아오고, 맨 끝이 날아가면 남은 줄은 이어서 움직임 (순간이동 없음)
func test_합류와_도망은_이어서_움직인다() -> void:
	var keep := KittenFlock.mode_pick
	for mode in KittenFlock.MODES.size():
		KittenFlock.mode_pick = mode
		var name: String = KittenFlock.MODES[mode]
		var flock := _flock(5)
		var cats := _cats(6)
		var from := Vector2(LEAD_X + 500.0, GROUND)  # 기다리던 자리 (주인공 앞 옥상)
		flock.place(5, from)
		var last := flock.pos.duplicate()
		var worst := 0.0
		for f in 120:
			flock.step(DT, Vector2(LEAD_X, GROUND), cats, _floor)
			for i in 6:
				worst = maxf(worst, flock.pos[i].distance_to(last[i]))
			last = flock.pos.duplicate()
		assert_true(worst <= KittenFlock.MAX_SPEED * DT + 0.5, "%s 합류 한 프레임 가장 큰 이동 %.1f" % [name, worst])
		assert_true(flock.pos[5].distance_to(Vector2(LEAD_X, GROUND) + KittenFlock.rest(5, 6)) < 30.0, "%s 2초 뒤 줄 끝 자리 근처" % name)
		cats.pop_back()  # 맨 끝이 날아감
		worst = 0.0
		for f in 120:
			flock.step(DT, Vector2(LEAD_X, GROUND), cats, _floor)
			for i in 5:
				worst = maxf(worst, flock.pos[i].distance_to(last[i]))
			last = flock.pos.duplicate()
		assert_true(worst <= 16.0, "%s 도망 뒤 한 프레임 가장 큰 이동 %.1f" % [name, worst])
		for i in 5:
			assert_true(flock.pos[i].distance_to(Vector2(LEAD_X, GROUND) + KittenFlock.rest(i, 5)) < 30.0, "%s 남은 아기 %d가 5마리 자리로" % [name, i])
	KittenFlock.mode_pick = keep


## 구름 방석: 내려올 때 납작(가로 넓게·세로 낮게), 멈춰 있으면 돌아옴. 기울기: 올라갈 때 뒤로(-), 내려올 때 앞으로(+)
func test_구름_납작과_기울기_방향() -> void:
	var flock := _flock(1)
	var cats := _cats(1)
	var flat := 1.0
	var back := 0.0
	var fore := 0.0
	for f in 120:
		flock.step(DT, Vector2(LEAD_X, _lead_y(f * DT) if f < 50 else GROUND), cats, _floor)
		flat = minf(flat, flock.cloud[0].y)
		back = minf(back, flock.tilt[0])
		fore = maxf(fore, flock.tilt[0])
	assert_true(flat < 0.93, "내려올 때 구름이 납작 %.2f" % flat)
	assert_true(back < -deg_to_rad(4.0) and fore > deg_to_rad(4.0), "뒤로 %.1f도·앞으로 %.1f도" % [rad_to_deg(back), rad_to_deg(fore)])
	for f in 240:
		flock.step(DT, Vector2(LEAD_X, GROUND), cats, _floor)
	assert_true(absf(flock.cloud[0].y - 1.0) < 0.03, "멈추면 구름이 돌아옴 %.3f" % flock.cloud[0].y)
