class_name KittenLife
extends RefCounted
## 떠다니는 아기 "살아 움직이기" (2026-11-19, 치즈냥 먼저, 화면과 분리한 순수 계산). world_view가 프레임마다 step을 부른다.
## 0.28배로 작게 보여 실루엣이 바뀌는 큰 동작 위주 (그림을 통째로 돌리거나 흔들지 않음). 모든 동작은 구름 위 앉은 자세에서 시작·끝.
## - 늘: 꼬리 살랑·숨쉬기(몸만 1.5%)·깜빡임(2~5초 무작위). 박자·시작점은 아기마다 다름.
## - 반응: 점프·더블점프·밟기 = 만세(아기 i는 i x KITTEN_CHAIN_DELAY 늦게, 간격이 줄 출렁과 같음), 착지 = 폭 앉기((i+1) x 0.12초, 내려앉는 때),
##   슬라이딩 동안 엎드리기, 다른 아기 피격 = 놀람. 반응이 가끔 하는 행동보다 우선 (하던 것을 끊고 바로).
## - 가끔(혼자): 하품·그루밍·꾹꾹이·뒤돌아보기. 아기마다 6~12초 무작위 간격, 화면 전체에서 한 번에 한 마리, 같은 행동 연속 안 함,
##   길이도 매번 조금씩 달라 기계적으로 안 보이게.
## - 구름 타기(2026-11-20, KittenFlock.ride): 쉬는 그림이 구름에 엎드려 탄 그림 — 펄럭임 반복(ride_0~2, 귀·꼬리·털만 다름),
##   올라가는 중 ride_up, 내려가는 중 ride_down (세로 속도로 고르고 되돌아갈 때는 기준을 낮춰 깜빡이지 않게).
##   점프·더블점프 만세는 안 함(구름을 놓고 만세하면 이상하고, 올라가기 그림이 그 반응), 착지 폭 앉기·슬라이딩 엎드리기는 ride_down.
##   깜빡임은 안 함(앉은 그림이라 자세가 튐). 밟기 만세·놀람·가끔 하는 행동은 그대로 앉은 그림을 씀.
## 프레임 이름 = assets/sprites/kittens/<품종>/alive_<이름>.png (tools/cut_kitten_alive.py), 꼬리 = alive_tail_<번호>.png

## 동작마다 [프레임, 초]. 가운데(가장 긴) 칸 길이는 시작할 때 HOLD_JITTER만큼 무작위로 늘이고 줄인다
const ACTS := {
	"cheer": [["cheer_0", 0.07], ["cheer_1", 0.3], ["cheer_0", 0.07]],
	"squat": [["squat", 0.16]],
	"surprised": [["squat", 0.05], ["surprised", 0.6]],
	"yawn": [["yawn_0", 0.3], ["yawn_1", 0.9], ["yawn_0", 0.25]],
	"groom": [["groom_0", 0.25], ["groom_1", 0.3], ["groom_0", 0.15], ["groom_1", 0.35], ["groom_0", 0.2]],
	"knead": [["knead_0", 0.25], ["knead_1", 0.25], ["knead_0", 0.25], ["knead_1", 0.25]],
	"look": [["look", 1.3]],
}
const IDLE_ACTS := ["yawn", "groom", "knead", "look"]
const OWN_TAIL := ["lie", "surprised", "squat", "ride_0", "ride_1", "ride_2", "ride_up", "ride_down"]  # 자기 꼬리가 그려진 프레임 (따로 붙인 꼬리를 숨김)
const FRAMES := ["base", "blink", "cheer_0", "cheer_1", "squat", "lie", "surprised", "yawn_0", "yawn_1",
		"groom_0", "groom_1", "knead_0", "knead_1", "look", "ride_0", "ride_1", "ride_2", "ride_up", "ride_down"]
const RIDE_FLAP := [0, 1, 2, 1]         # 펄럭임 반복 차례
const RIDE_FLAP_TIME := 0.09            # 한 장 (초)
const RIDE_VY := 160.0                  # 이 세로 속도(픽셀/초)보다 빠르면 올라가기·내려가기 그림
const RIDE_VY_OFF := 70.0               # 그 그림에서 펄럭임으로 돌아오는 속도 (사이에서 깜빡이지 않게)
const IDLE_GAP := Vector2(6.0, 12.0)    # 가끔 하는 행동 간격 (초, 아기마다 무작위)
const IDLE_RETRY := Vector2(0.5, 1.5)   # 다른 아기가 하는 중이면 이만큼 뒤 다시
const HOLD_JITTER := Vector2(0.75, 1.35)
const BLINK_GAP := Vector2(2.0, 5.0)
const BLINK_TIME := 0.12
const BREATH := 0.015                   # 숨쉬기 세로 늘어남 (가로는 절반만큼 줄어듦)
const BREATH_TIME := Vector2(1.8, 2.5)  # 숨 한 번 (초, 아기마다)
const WAG_TIME := Vector2(2.0, 2.9)     # 꼬리 한 번 오감 (초, 아기마다)
const LIE_IN := 0.06                    # 슬라이딩 시작: 폭 앉기를 이만큼 거쳐 엎드림

var kittens: Array[Dictionary] = []
## 자리마다 가끔 하는 행동을 해도 되는지 (그림이 있는 품종만). shortcut: 지금은 치즈만 그림이 있어 world_view가 끔, 6마리 그림이 생기면 지움
var idle_ok: Array[bool] = []
var _rng := RandomNumberGenerator.new()
var _sliding := false
var riding := false                     # 구름 타기 (world_view가 KittenFlock.ride로 정함)
var _climb: Array[int] = []             # 아기마다 -1 올라감, 1 내려감, 0 그 밖


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value
	for i in Balance.PARADE_MAX:
		kittens.append({})
		idle_ok.append(true)
		_climb.append(0)
		reset(i)


## 자리 i에 새 아기가 옴: 박자·시작점을 새로 뽑고 하던 동작은 지움
func reset(i: int) -> void:
	kittens[i] = {"seq": [], "k": 0, "t": 0.0, "act": "", "pending": [], "last_idle": "",
			"next_idle": _pick(IDLE_GAP), "blink_in": _pick(BLINK_GAP), "blink": 0.0, "down": -1.0,
			"breath_time": _pick(BREATH_TIME), "breath_at": _rng.randf(), "wag_time": _pick(WAG_TIME), "wag_at": _rng.randf(), "age": 0.0}


## 반응: 모든 아기에게 act. 아기 i는 (i + lead) x KITTEN_CHAIN_DELAY초 늦게 (lead < 0 = 모두 바로).
## 만세는 lead 0: 맨 앞은 점프 순간, 뒤로 0.12초씩 (줄 출렁보다 한 칸 먼저 = 떠오르기 직전 앞발을 듦).
## 폭 앉기는 lead 1: 아기 i가 실제로 내려앉는 때 (줄 출렁 (i+1) x 0.12초)
func react(act: String, lead: int = 0) -> void:
	for i in kittens.size():
		kittens[i].pending.append({"act": act, "in": (i + lead) * Balance.KITTEN_CHAIN_DELAY if lead >= 0 else 0.0})


## count = 지금 떠 있는 아기 수 (이 수까지만 가끔 하는 행동을 함), vys = 아기마다 세로 속도 (구름 타기 올라가기·내려가기 그림)
func step(dt: float, sliding: bool, count: int, vys: Array = []) -> void:
	var was_sliding := _sliding
	_sliding = sliding
	for i in kittens.size():
		var c: Dictionary = kittens[i]
		c.age += dt
		var vy: float = vys[i] if i < vys.size() else 0.0
		var off := RIDE_VY_OFF if _climb[i] != 0 else RIDE_VY
		_climb[i] = -1 if vy < -off else (1 if vy > off else 0)
		if sliding:
			c.down = 0.0 if c.down < 0.0 else c.down + dt
			c.seq = []
			c.act = ""
			c.pending = []
		elif was_sliding:
			c.down = -1.0
			_start(c, "squat")  # 일어나며 폭 (엎드림 → 앉음 사이)
		for p in c.pending:
			p.in -= dt
		var due: Array = c.pending.filter(func(p: Dictionary) -> bool: return p.in <= 0.0)
		if not due.is_empty():
			c.pending = c.pending.filter(func(p: Dictionary) -> bool: return p.in > 0.0)
			_start(c, due[-1].act)
			c.next_idle = _pick(IDLE_GAP)
		_advance(c, dt)
		c.blink = maxf(0.0, c.blink - dt)
		c.blink_in -= dt
		if c.blink_in <= 0.0:
			c.blink_in = _pick(BLINK_GAP)
			if c.seq.is_empty():
				c.blink = BLINK_TIME
	_idle(dt, count)


## 아기 i의 지금 몸 프레임 이름 (FRAMES 중 하나)
func frame(i: int) -> String:
	var c: Dictionary = kittens[i]
	if c.down >= 0.0:
		return "ride_down" if riding else ("squat" if c.down < LIE_IN else "lie")
	if not c.seq.is_empty():
		return "ride_down" if riding and c.seq[c.k][0] == "squat" else c.seq[c.k][0]
	if riding:
		if _climb[i] != 0:
			return "ride_up" if _climb[i] < 0 else "ride_down"
		return "ride_%d" % RIDE_FLAP[int(c.age / RIDE_FLAP_TIME + c.wag_at * RIDE_FLAP.size()) % RIDE_FLAP.size()]
	return "blink" if c.blink > 0.0 else "base"


## 아기 i의 꼬리 그림 번호 (0 ~ count-1, 코사인으로 오가 양 끝에서 머묾)
func tail(i: int, count: int) -> int:
	var c: Dictionary = kittens[i]
	var p := 0.5 - 0.5 * cos(TAU * (c.age / c.wag_time + c.wag_at))
	return roundi(p * (count - 1))


## 아기 i의 숨쉬기 배율 (발끝을 기준으로 곱함)
func breath(i: int) -> Vector2:
	var c: Dictionary = kittens[i]
	var b := sin(TAU * (c.age / c.breath_time + c.breath_at))
	return Vector2(1.0 - BREATH * 0.5 * b, 1.0 + BREATH * b)


## 아기 i가 하는 동작 이름 ("" = 쉼, 엎드림은 "lie")
func act(i: int) -> String:
	return "lie" if kittens[i].down >= 0.0 else kittens[i].act


func _start(c: Dictionary, act_name: String) -> void:
	var seq: Array = []
	var longest := 0
	for k in ACTS[act_name].size():
		seq.append(ACTS[act_name][k].duplicate())
		if seq[k][1] > seq[longest][1]:
			longest = k
	seq[longest][1] *= _pick(HOLD_JITTER)
	c.seq = seq
	c.k = 0
	c.t = 0.0
	c.act = act_name
	c.blink = 0.0


func _advance(c: Dictionary, dt: float) -> void:
	if c.seq.is_empty():
		return
	c.t += dt
	while c.k < c.seq.size() and c.t >= c.seq[c.k][1]:
		c.t -= c.seq[c.k][1]
		c.k += 1
	if c.k >= c.seq.size():
		if c.act in IDLE_ACTS:
			c.next_idle = _pick(IDLE_GAP)
		c.seq = []
		c.k = 0
		c.act = ""


## 가끔 하는 행동: 차례가 된 아기는 아무도 안 하고 있을 때만 시작 (아니면 조금 뒤 다시)
func _idle(dt: float, count: int) -> void:
	if _sliding:
		return
	var busy := false
	for i in count:
		busy = busy or kittens[i].act in IDLE_ACTS
	for i in count:
		var c: Dictionary = kittens[i]
		if not idle_ok[i] or not c.seq.is_empty() or not c.pending.is_empty():
			continue
		c.next_idle -= dt
		if c.next_idle > 0.0:
			continue
		if busy:
			c.next_idle = _pick(IDLE_RETRY)
			continue
		var choices: Array = IDLE_ACTS.filter(func(a: String) -> bool: return a != c.last_idle)
		var pick: String = choices[_rng.randi_range(0, choices.size() - 1)]
		_start(c, pick)
		c.last_idle = pick
		busy = true


func _pick(range_: Vector2) -> float:
	return _rng.randf_range(range_.x, range_.y)
