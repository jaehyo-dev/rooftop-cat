class_name Balance
## 조작감·속도·옥상 생성 같은 게임 플레이 수치를 한곳에 모은다.
## 좌표: 로직은 "옥상 바닥에서 위로 잰 높이"(y가 위로 커짐)를 쓰고, 화면은 이를 뒤집어 그린다.

# --- 고양이 몸 (충돌 판정 기준) ---
## 꼬리를 뺀 몸 전체(머리 위~발끝)를 감싸는 타원 크기.
## 기준 그림 assets/sprites/cat_base_run.png(1024x1024)에서 몸 영역은 x 185~896, y 300~738 (711x438, 비율 1.62).
## 3단계에서 진짜 그림을 이 영역이 타원과 겹치게 놓으면 발끝이 그대로 옥상에 닿는다.
const CAT_BODY_SIZE := Vector2(150.0, 92.0)
## 발 범위의 절반 (몸 가운데에서 앞뒤로). 이 범위가 옥상에 걸치면 서거나 내려앉는다.
## 기준 그림에서 뒷발~앞발이 몸 너비의 대부분을 차지하지만, 끝에 살짝 걸친 채로 서 있어 보이지 않게 몸 너비의 30%로 잡는다.
const CAT_FOOT_HALF := CAT_BODY_SIZE.x * 0.3
## 고양이가 화면 왼쪽에서 떨어진 위치 (몸 가운데, 기준 해상도 1280x720)
const CAT_SCREEN_X := 340.0

# --- 달리기 ---
const RUN_SPEED := 430.0  # 처음 속도 (초당 픽셀)
const SPEED_MAX := 950.0
## 속도 단계 표 (review/v0.6.0/PLAN.md 13·16번): [시작 시각(초), 속도, 구간 밀도]. 2a-4: 단계 10~12를 앞당기고 밀도를 올림 (숙련 봇이 끝까지 가지 않게).
## 단계 10~12는 속도가 그대로라 신호를 내지 않고 밀도만 오른다.
const SPEED_STAGES := [
	[0.0, RUN_SPEED, 1.00], [14.0, 500.0, 0.97], [28.0, 570.0, 0.94], [45.0, 640.0, 0.91],
	[68.0, 710.0, 0.88], [95.0, 780.0, 0.85], [125.0, 850.0, 0.82], [160.0, 910.0, 0.79],
	[200.0, SPEED_MAX, 0.77], [260.0, SPEED_MAX, 0.71], [320.0, SPEED_MAX, 0.65], [400.0, SPEED_MAX, 0.60],
]
const SPEED_RAMP_TIME := 1.2  # 단계가 오를 때 다음 속도까지 부드럽게 빨라지는 시간 (초)
## 단계마다 배경 음악 pitch_scale을 이만큼 올린다 (최대 MUSIC_PITCH_MAX)
const MUSIC_PITCH_STEP := 0.013
const MUSIC_PITCH_MAX := 1.12
## 속도선 진하기: 단계가 오른 직후 1. 그 뒤 SPEED_LINE_STAGE 단계부터 단계에 비례해 옅게 남는다 (단계 9에서 SPEED_LINE_REST_MAX)
const SPEED_LINE_STAGE := 3
const SPEED_LINE_REST_MIN := 0.12
const SPEED_LINE_REST_MAX := 0.3
const SPEED_LINE_FADE := 0.3  # 진한 속도선이 끝에서 옅어지는 시간 (SPEED_RAMP_TIME 안, 초)

# --- 점수 ---
const PX_PER_METER := 100.0  # 거리 점수: 100픽셀 = 1미터
## 게임 끝 뒤 이 시간이 지나야 다시 시작 (떨어지며 누르던 손가락으로 바로 다시 시작되지 않게)
const RESTART_DELAY := 0.8

# --- 점수와 콤보 (PLAN 16번): 점수 = 거리(미터) + 생선 점수 합 ---
const FISH_POINTS := 5  # v0.7.0: 생선 점수 강화 0단계 (10단계 25점, UPGRADES)
const GOLD_POINTS := 200
const COMBO_STEP := 20    # 생선이 촘촘해 예시(10개)보다 크게: x5까지 처음 속도로 약 13초
const COMBO_MAX := 5
const COMBO_TIMEOUT := 3.0  # 이 시간(초) 동안 못 먹으면 끊김 (쉼 옥상 + 트램펄린 비행도 이 안에 다음 생선이 있음)

# --- 강화 상점 (review/v0.7.0/PLAN.md 3·4·13번) ---
## 영구 강화 6개: [0단계, 10단계]. 그 사이는 단계마다 같은 만큼 (Perks.value). 0단계 = v0.6.0 판과 같은 값
const UPGRADE_MAX := 10
const UPGRADES := {
	"dash": [4.0, 6.0],        # 질주 시간 (초). 0단계는 DASH_TIME
	"yarn": [1.0, 1.5],        # 털실 시간·반경 배율 (MAGNET_TIME, MAGNET_RADIUS에 곱함)
	"combo": [20.0, 12.0],     # 콤보 가속: 배수가 오르는 생선 수 (0단계는 COMBO_STEP, 반올림)
	"gold": [200.0, 500.0],    # 황금 생선 점수. 0단계는 GOLD_POINTS
	"cookie": [90.0, 70.0],    # 하트 쿠키 간격 (첫 쿠키 시각도 같음, SLOT_ITEMS의 쿠키 줄을 바꿈)
	"fish": [5.0, 25.0],       # 생선 점수. 0단계는 FISH_POINTS
}
## 한 단계 가격 (1→10단계, 6개 공통). 항목 33,700, 전체 202,200 (PLAN 4-2 제안 가격, 2026-11-11 승인)
const UPGRADE_PRICES := [300, 800, 1500, 2200, 2900, 3600, 4400, 5200, 6000, 6800]
## 생선 점수 강화가 이 단계에 이르면 생선 그림이 바뀐다 (0·3·6·10단계 → 그림 0~3, 그림은 2c)
const FISH_LOOK_LEVELS := [0, 3, 6, 10]
## 한 판 부스터: 값, 가질 수 있는 최대 개수
const BOOSTER_PRICES := {"dash_start": 500, "bell_start": 400, "fish_bonus": 800}
const BOOSTER_MAX := 99
## 질주로 출발: 판 시작 뒤 이 시간(초)에 질주 시작 (첫 옥상 1500px 위)
const BOOSTER_DASH_AT := 1.0
## 생선 +50%: 지갑에 더하는 생선 배율 (점수·미션·통계는 그대로)
const FISH_BONUS_MULT := 1.5

# --- 점프: 누르는 시간만큼 높이 ---
## 누르고 있는 동안(최대 JUMP_MAX_HOLD) 같은 속도로 올라가고, 떼면 중력으로 떨어진다.
## 그래서 높이 = 최소 높이 + 점프 속도 x 누른 시간 (누른 시간에 비례, 최대 높이에서 멈춤).
const GRAVITY := 3200.0
const JUMP_MIN_HEIGHT := 70.0   # 짧게 톡 눌렀을 때
const JUMP_MAX_HEIGHT := 250.0  # 길게 눌렀을 때 (최대)
## 땅에 닿기 직전에 누른 입력을 기억해 착지하자마자 뛰는 시간
const JUMP_BUFFER_TIME := 0.10
## 옥상 끝을 막 지난 뒤에도 점프를 받아 주는 시간
const COYOTE_TIME := 0.08

# --- 더블점프: 공중에서 새로 누르면 1회 (옥상·판에 서거나 줄을 눌러 튕기면 다시 생김) ---
## 첫 점프와 같은 방식: 누르는 순간 JumpModel.jump_speed()로 다시 올라가고(떨어지던 속도는 지움), 누르는 동안 유지.
## 높이(누른 자리에서 위로) = JUMP_MIN_HEIGHT ~ DOUBLE_JUMP_MAX_HEIGHT
const DOUBLE_JUMP_MAX_HEIGHT := 130.0
## 더블점프 뒤 꼭대기 근처(|세로 속도| < DOUBLE_FLOAT_SPEED)에서는 중력을 DOUBLE_FLOAT_GRAVITY배로 (잠깐 떠 있는 느낌)
const DOUBLE_FLOAT_SPEED := 160.0
const DOUBLE_FLOAT_GRAVITY := 0.5

# --- 옥상 생성 ---
const ROOF_WIDTH_MIN := 300.0
const ROOF_WIDTH_MAX := 720.0
const ROOF_FIRST_WIDTH := 1500.0   # 시작 옥상은 넉넉하게
const ROOF_TOP_MIN := 120.0        # 옥상 높이 (화면 아래에서 위로)
const ROOF_TOP_MAX := 330.0
const ROOF_TOP_STEP := 110.0       # 옆 옥상과의 높이 차 최대
const ROOF_GAP_MIN := 70.0
## 최대 점프로 닿을 수 있는 거리에 곱하는 여유. 1보다 작을수록 쉬움
## 처음 속도에서는 ROOF_GAP_SAFETY_START, 최대 속도로 갈수록 ROOF_GAP_SAFETY까지 넓어진다 (처음은 쉽게)
const ROOF_GAP_SAFETY_START := 0.55
const ROOF_GAP_SAFETY := 0.85
## 옥상을 미리 만들어 두는 거리 (고양이 앞쪽)
const ROOF_LOOKAHEAD := 2200.0

# --- 떨어짐 → 게임 끝 ---
const FALL_LIMIT := -160.0  # 이 높이(화면 아래 밖)보다 아래로 떨어지면 게임 끝

# --- 부딪힘 → 투명화 ---
## 높은 옥상 벽에 부딪히면 이 시간 동안 깜빡이며 투명해지고, 벽을 통과해 그 옥상 위로 떠오른다
const GHOST_TIME := 1.2
const GHOST_RISE_SPEED := 700.0  # 투명화 중 옥상 위로 떠오르는 속도 (초당 픽셀)

# --- 아이템: 생선, 종이상자 ---
## 아이템 가운데를 옥상 위 이 높이에 둔다 (고양이 몸 가운데 높이: 달리기만 해도 몸에 닿음)
const ITEM_LIFT := CAT_BODY_SIZE.y * 0.5
## 아이템을 먹는 거리: 몸 타원을 이만큼 넓혀서 아이템 가운데가 그 안에 들어오면 먹는다
const ITEM_RADIUS := 24.0
const FISH_SPACING := 70.0      # 생선 사이 간격
## 종이상자는 이 시간(초)마다 다음 일반 옥상에 하나 (한 번에 1개만 가질 수 있음).
## 예전 "옥상 40~60개"를 v0.5.0 평균 옥상 시간 약 1.5초로 어림한 값 (구간이 들어와도 드물어지지 않게 시간으로 셈)
const BOX_EVERY_MIN := 120.0
const BOX_EVERY_MAX := 180.0
## 종이상자 구제: 발이 이 높이(화면 맨 아래)까지 떨어지면 상자가 받쳐서 가까운 앞 옥상 위로 올려 준다
const RESCUE_HEIGHT := 0.0
const RESCUE_RISE_SPEED := 900.0  # 구제될 때 올라가는 속도 (초당 픽셀)

# --- 구조물: 빨래줄, 전봇대 (넓은 틈에 놓이는 다리·디딤돌) ---
## 새 옥상을 만들 때 "특수 틈"(점프 한 번으로 못 건너는 넓은 틈)으로 만들 확률, 그중 트램펄린(빨래줄을 켜면 빨래줄)이 될 확률
## (나머지는 전봇대). 처음 SPECIAL_GAP_AFTER개 옥상은 일반 틈만 (처음엔 쉽게)
const SPECIAL_GAP_CHANCE := 0.3
const SPECIAL_GAP_AFTER := 3
const LINE_SHARE := 0.5
## 빨래줄 생성 (v0.5.0 2a-2에서 은퇴: 트램펄린이 대신함. 코드·그림·판정은 남겨 둠)
const LINE_ENABLED := false
## 못 건너는 틈의 여유: 최대 점프로 닿는 거리 + 발 범위 + 코요테에 더하는 픽셀
const SPECIAL_GAP_MARGIN := 40.0
## 빨래줄: 틈 전체를 가로지르는 줄(옥상 위 LINE_HEIGHT 높이). 위에서 내려와 닿을 때마다 누름 타이밍으로 판정해 튕긴다
## (달리다 지나가는 건 막지 않음). 닿으면 LINE_RIDE_TIME 동안 줄에 실려 있어(높이는 줄에 고정) 닿은 뒤에 눌러도 된다
const LINE_HEIGHT := 60.0
## 줄 틈은 옥상 높이가 이 값 이하일 때만 (줄 위 생선까지 세로 카메라 안에 들게)
const LINE_TOP_MAX := 240.0
## 틈 너비 범위: 못 건너는 최소 ~ 최소 + 누름 튕김 한 번의 거리 x LINE_GAP_SPAN (닿는 횟수가 2번 안팎, PLAN 0.5 → 봇 조정 0.3)
const LINE_GAP_SPAN := 0.3
## 누름 판정 창 (닿는 순간 기준, 초): 닿기 LINE_PRESS_EARLY 전 ~ 닿은 뒤 LINE_RIDE_TIME. 새로 누른 것만 친다.
## 닿은 뒤 창은 PLAN 0.08에서 밸런스 봇으로 0.15로 넓힘 (초보 실패가 거의 다 늦은 누름이었음)
const LINE_PRESS_EARLY := 0.18
const LINE_RIDE_TIME := 0.15
## 퍼펙트 창: 닿기 전후 각각 이 시간 안
const LINE_PERFECT := 0.04
## 닿기 이만큼 전부터는 공중에서 눌러도 더블점프로 쓰지 않는다. LINE_PRESS_EARLY보다 이르면 "빨랐어!" 실패
const LINE_BLOCK_EARLY := 0.28
## 튕겨 오르는 높이 (줄 위로): 안 누름·실패(줄이 느슨해져 이 틈에서는 더 받아 주지 않음) / 누름 / 퍼펙트
const LINE_MISS_HEIGHT := 80.0
const LINE_GOOD_HEIGHT := 230.0
const LINE_PERFECT_HEIGHT := 330.0
## 줄 위 생선 줄의 높이 (줄에서 위로, 생선 가운데). 퍼펙트 튕김 꼭대기(330 + 몸 절반 46)에서 먹는 거리(46 + 24)보다 멀어
## 더블점프를 더해야 닿는다 (PLAN의 420은 퍼펙트만으로 닿아서 460으로 올림)
const LINE_FISH_HEIGHT := 460.0
## 트램펄린: 넓은 틈 앞 옥상 끝 발사대. 누름 판정 창·퍼펙트 창·너무 이른 누름은 빨래줄 값(LINE_PRESS_EARLY, LINE_RIDE_TIME,
## LINE_PERFECT, LINE_BLOCK_EARLY)을 그대로 쓴다. 달려 들어가 몸 가운데가 왼쪽 끝에서 TRAMP_RUN_IN 들어가거나(그물 가운데쯤),
## 위에서 내려와 발이 걸치면 닿음.
## v0.5.0 2b: 그물 꺼짐이 몸 아래로 보이게 150 → 210 (1.4배), 닿는 자리도 같은 비율로 60 → 84
const TRAMP_WIDTH := 210.0
const TRAMP_RUN_IN := 84.0
const TRAMP_INSET := 10.0     # 옥상 끝에서 이만큼 안쪽에 놓음
## 밟은 그물의 판정 높이 (옥상 위로). 그림에서 꺼진 그물 바닥은 더 높을 수 있고, 고양이 그림만 그 깊이를 따라간다 (world_view.gd tramp_cat_lift)
const TRAMP_LIFT := 10.0
## 튕긴 직후 이 시간 동안은 그림만 그물에 눌려 있다가 튀어 나간다 (판정은 이미 튕김, 입력 지연 없음)
const TRAMP_PUSH := 0.05
## 트램펄린 틈은 옥상 높이가 이 값 이하일 때만 (퍼펙트 꼭대기와 생선 길이 세로 카메라 안에 들게)
const TRAMP_TOP_MAX := 240.0
## 튕겨 오르는 높이 (그물 위로): 안 누름·이른 누름(제자리에서 낮게, 앞으로 밀어 주지 않음) / 누름 / 퍼펙트
const TRAMP_MISS_HEIGHT := 80.0
const TRAMP_GOOD_HEIGHT := 300.0
const TRAMP_PERFECT_HEIGHT := 420.0
## 발사 가로 속도는 트램펄린마다 생성 때 계산한다(RoofGenerator.tramp_*): 누름은 가장 일찍 튕겨도 다음 옥상 끝에서
## TRAMP_LAND_IN 안쪽에, 퍼펙트는 그보다 TRAMP_PERFECT_EXTRA 더 멀리 내려앉는 속도
const TRAMP_LAND_IN := 60.0
const TRAMP_PERFECT_EXTRA := 160.0
## 틈 너비 범위: 못 건너는 최소(점프 + 더블점프로도 못 건넘) ~ 최소 + TRAMP_GAP_SPAN
const TRAMP_GAP_SPAN := 100.0
## 퍼펙트 생선 길: 퍼펙트 궤적 중 누름 꼭대기보다 이만큼 이상 높은 구간에만 (누름으로는 못 먹게: 먹는 거리 70보다 큼)
const TRAMP_FISH_ABOVE_GOOD := 80.0
## 전봇대: 틈 한가운데 판(꼭대기). 판 너비는 속도가 낮을수록 넓게 시작해 POLE_WIDTH_MIN까지 좁아진다.
## 판 높이는 앞뒤 옥상 중 높은 쪽 (판에서 벽에 막히지 않고, 판에서 다음 옥상으로는 내려감).
## v0.5.0 2a: 판 앞뒤 틈이 한 번 점프 거리만큼 넓어져 200/120 → 240/140으로 넓힘 (밸런스 봇 초보 판 성공률)
const POLE_WIDTH_START := 240.0
const POLE_WIDTH_MIN := 140.0
## 판까지·판에서 다음까지 각각 "점프 + 더블점프 최대 거리"의 이 비율 안에 둔다 (꼭대기에서 더블점프를 써도 0.86배 이상이라 넉넉)
const POLE_GAP_SAFETY := 0.75
## 판 앞뒤 틈의 상한: 뛰는 순간 판(또는 다음 옥상)이 화면 안에 보이는 거리 (고양이 앞 940 - 발 범위 - 여유)
const POLE_GAP_VIEW_MAX := 800.0
## 틈 너비 범위: 못 건너는 최소 ~ 최소 + POLE_GAP_SPAN (v0.5.0 2a: 200 → 100)
const POLE_GAP_SPAN := 100.0

# --- 장애물 (review/v0.6.0/PLAN.md 1번) ---
## w = 판정 폭, y0~y1 = 판정 높이 (옥상에서 위로), art_w = 그림 너비(높이는 그림 비율대로). 비둘기만 공중에 있어 뛰지 않으면 안 맞는다
const OBSTACLES := {
	"pot": {"w": 48.0, "y0": 0.0, "y1": 38.0, "art_w": 84.0},
	"ac": {"w": 110.0, "y0": 0.0, "y1": 88.0, "art_w": 140.0},
	"tank": {"w": 84.0, "y0": 0.0, "y1": 260.0, "art_w": 135.0},
	"flock": {"w": 150.0, "y0": 240.0, "y1": 310.0, "art_w": 218.0},
}
## 장애물에 대해서만 고양이 타원을 이만큼 작게 본다 (그림이 살짝 스쳐도 맞지 않게)
const OBSTACLE_HIT_SCALE := 0.8
const FLOCK_SPEED := 120.0  # 비둘기가 다가오는 속도 (달리는 속도에 더해짐)

# --- 하트 ---
const HEARTS_MAX := 3
const INVULN_TIME := 1.5  # 부딪힌 뒤 무적 시간 (ghost_time과 따로: 그 값은 벽 통과·더블점프 금지도 켠다)

# --- 구간 이어 붙이기 (PLAN 5번) ---
## 매 판 처음 나오는 구간 순서 (마지막 E2의 아이템 자리에 2a-3에서 첫 질주가 들어간다)
const SEGMENT_SCRIPT := ["E1", "E2", "E3", "E4", "E2"]
## 단계별 섞임: [이 단계까지, 쉬움, 보통, 어려움, 쉼 옥상 최소, 최대, 쉼 자리 특수 틈 확률]
const SEGMENT_MIX := [
	[2, 0.7, 0.3, 0.0, 1, 1, 0.3], [3, 0.4, 0.6, 0.0, 1, 1, 0.4], [4, 0.2, 0.7, 0.1, 1, 1, 0.5],
	[5, 0.1, 0.6, 0.3, 0, 1, 0.6], [6, 0.0, 0.5, 0.5, 0, 1, 0.7], [9, 0.0, 0.35, 0.65, 0, 1, 0.9],
	[12, 0.0, 0.1, 0.9, 0, 0, 1.0],
]
## 물탱크가 있는 구간의 옥상 높이 상한 (탱크 꼭대기까지 세로 카메라 안에)
const SEGMENT_TANK_TOP_MAX := 240.0

# --- 아이템 (PLAN 3번·12번) ---
## 질주: 전용 분기 (RunnerSim._dash_step). 지금 속도 x DASH_MULT (상한 DASH_MAX_SPEED)
const DASH_TIME := 4.0
const DASH_MULT := 1.5
const DASH_MAX_SPEED := 1250.0
## 보이지 않는 발판 높이가 바뀌는 속도와, 앞 옥상을 미리 보는 시간 (높이 차 110을 벽 닿기 전에 오름)
const DASH_RISE_SPEED := 1200.0
const DASH_LOOK := 0.2
## 착지 옥상을 요청하는 때: 남은 질주 거리 < 생성 범위 + 이 값 (옥상 폭만큼 늦어지는 것을 평균으로 맞춤)
const DASH_LAND_EARLY := 300.0
## 부술 것: 질주 중 화면 밖 이 거리에 이 시간(초) 간격으로 장애물을 더 놓는다 (구간 장애물만으로는 질주당 2개뿐, 목표 3~8개)
const DASH_TARGET_AHEAD := 150.0
const DASH_TARGET_GAP := 0.6
const DASH_TARGETS := ["pot", "ac", "pot", "tank"]
## 질주 중 공중 생선 호: 화면 밖에 이 시간(초) 간격으로 최대 점프 궤적을 놓는다 (뛰어야 먹음, 놓쳐도 안 끊김)
const DASH_FISH_GAP := 1.3
## 착지 옥상: 질주 속도로 이 시간 길이, 장애물 없음. 들어온 지 DASH_LAND_WAIT초 뒤 끝나고 DASH_END_INVULN초 무적, 속도는 DASH_EASE초에 걸쳐 원래대로
const DASH_LAND_SECONDS := 1.5
const DASH_LAND_WAIT := 0.3
const DASH_END_INVULN := 1.0
const DASH_EASE := 0.6
## 부순 순간 게임 진행을 멈추는 시간과, 그 뒤 다시 멈추지 않는 시간 (질주 중 무적이라 공정성 문제 없음)
const HITSTOP_TIME := 0.035
const HITSTOP_GAP := 0.25
## 질주를 먹은 순간 멈칫하는 시간 (2b 수정: 판이 바뀌는 신호)
const DASH_START_STOP := 0.1
## 장애물에 부딪힌 순간의 손맛 (2b, 약·중·강 중 "중"으로 확정): 멈춤 시간(초), 화면 흔들림 세기(픽셀)
const HIT_STOP := 0.06
const HIT_SHAKE := 8.0
const HIT_SHAKE_TIME := 0.2
## 질주로 부순 순간의 흔들림 (부딪힘보다 약하게: 무적이라 위험 신호가 아니라 손맛)
const SMASH_SHAKE := 4.0
const SMASH_SHAKE_TIME := 0.12
## 털실 자석: 이 시간 동안 반경 안 생선이 날아옴
const MAGNET_TIME := 8.0
const MAGNET_RADIUS := 260.0
const MAGNET_SPEED := 1400.0
## 질주 보상 (2b 수정): 생선·황금 점수 배율(콤보 배수와 곱함), 작은 자석 반경 (털실보다 작게. 같이 쓰면 큰 쪽)
const DASH_FISH_MULT := 2
const DASH_MAGNET_RADIUS := 150.0
const GOLD_FISH := 20  # 황금 생선 하나 = 생선 수 (거리 점수에는 안 더함)
const CAN_FISH := 3    # 통조림으로 바뀐 장애물 하나 = 생선 수
## 아이템 자리 우선순위 (앞일수록 먼저): [종류, 처음 나올 수 있는 시각(초), 다음까지 간격 최소, 최대].
## 쿠키는 하트 2개 이하, 방울은 안 가지고 있을 때만. 첫 질주는 대본(CoursePlacer)이 정한다
## 통조림·방울·첫 쿠키 시각은 밸런스 봇으로 정함 (하트 회복이 너무 흔하면 하트로 끝나는 판이 사라짐)
## 2a-4: 질주·쿠키를 크게 줄임 (아이템이 판을 살려 주느라 긴장이 없었음, PLAN 15번)
const SLOT_ITEMS := [["cookie", 90.0, 90.0, 90.0], ["dash", INF, 90.0, 130.0], ["can", 120.0, 150.0, 200.0], ["bell", 90.0, 150.0, 200.0], ["yarn", 8.0, 30.0, 45.0]]

## 이 시각(초) 뒤에는 아이템·상자 간격이 ITEM_LATE_MULT배 (오래 버티는 사람이 아이템 덕에 끝없이 가지 않게)
const ITEM_LATE_TIME := 150.0
const ITEM_LATE_MULT := 6.0

# --- 고양이 모션 ---
const CAT_STRIDE := 150.0      # 달리기 한 바퀴(프레임 4장)에 가는 거리 (게임 픽셀)
const CAT_CROUCH_TIME := 0.03  # 뛰는 순간 웅크린 그림을 보여 주는 시간 (초). v0.5.0 2b: 0.06 → 0.03 (공중에서 웅크려 보이지 않게)
const CAT_LAND_TIME := 0.12    # 착지 그림(앞발부터 닿고 몸이 눌림)을 보여 주는 시간 (초)
## 앞구르기 공중제비(더블점프, 트램펄린 퍼펙트 발사 뒤): 숙이기 → C자 → 공(가장 빠르게 회전) → 펴기, 한 바퀴. v0.5.0 2b: 0.36 → 0.42
const CAT_FLIP_TIME := 0.42
## 회전 빠르기의 출렁임: 각도 = 한 바퀴 x (k - FLIP_EASE x sin(2πk) / 2π). 0.6이면 말기 끝 약 56도, 펴기 시작 약 304도 (ART_BIBLE 8-1)
const CAT_FLIP_EASE := 0.6
## 트램펄린에서 튕길 때 도약 그림을 보여 주는 시간 (초). 퍼펙트는 이 뒤에 앞구르기
const CAT_LAUNCH_TIME := 0.12
## 달리기 몸 들썩임 (게임 픽셀, 한 바퀴에 2번). 그림만 들썩이고 판정 발끝은 그대로
const CAT_RUN_BOB := 4.0
## 공중 숨쉬기 (몸 배율 ±, 1초에 몇 번)
const CAT_BREATH := 0.02
const CAT_BREATH_HZ := 2.0
## 꼭대기 부풀기: 세로 속도가 이보다 느린 구간에서 몸이 CAT_APEX_PUFF 쪽으로 둥글게
const CAT_APEX_SPEED := 200.0
const CAT_APEX_PUFF := Vector2(1.06, 1.03)

# --- 늘어남·납작해짐 연출 (가로, 세로 배율) ---
const STRETCH_RISE := Vector2(0.84, 1.2)   # 가장 빠르게 올라갈 때
const STRETCH_FALL := Vector2(0.92, 1.1)   # 가장 빠르게 떨어질 때
## 몸 배율 스프링 (Spring): 1초에 몇 번 출렁이는지, 감쇠비 (작을수록 오래 출렁임)
const CAT_SPRING_HZ := 5.0
const CAT_SPRING_DAMPING := 0.4
## 스프링 충격: 원래 모양에서 가장 크게 벗어나는 정도 (가로, 세로)
const KICK_LAND := Vector2(0.22, -0.2)          # 착지 (1.22 x 0.80)
const KICK_CROUCH := Vector2(0.06, -0.1)        # 누르는 순간 웅크림
const KICK_TAKEOFF := Vector2(-0.12, 0.18)      # 웅크림 끝 = 박차는 순간 세로로 늘어남 (0.88 x 1.18)
const KICK_DOUBLE := Vector2(-0.08, 0.12)       # 더블점프
const KICK_TRAMP_RIDE := Vector2(0.25, -0.24)   # 트램펄린 그물에 실림 (웅크려 납작)
## 트램펄린 튕김: 결과별 세로 늘어남
const KICK_TRAMP_LAUNCH := {"miss": Vector2(0.04, -0.06), "early": Vector2(-0.04, 0.06), "good": Vector2(-0.14, 0.24), "perfect": Vector2(-0.18, 0.32)}
