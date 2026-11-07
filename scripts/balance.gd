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
## 시간이 갈수록 빨라짐: 속도 = RUN_SPEED + SPEED_GAIN x 지난 시간(초), 최대 SPEED_MAX
const SPEED_GAIN := 1.5
const SPEED_MAX := 950.0

# --- 점수 ---
const PX_PER_METER := 100.0  # 거리 점수: 100픽셀 = 1미터
## 게임 끝 뒤 이 시간이 지나야 다시 시작 (떨어지며 누르던 손가락으로 바로 다시 시작되지 않게)
const RESTART_DELAY := 0.8

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
const ROOF_GAP_SAFETY_START := 0.5
const ROOF_GAP_SAFETY := 0.8
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
const FISH_ROW_CHANCE := 0.45   # 옥상 위에 생선 줄을 놓을 확률
const FISH_ROW_MIN := 3
const FISH_ROW_MAX := 6
const FISH_ARC_CHANCE := 0.35   # 틈 위에 생선 무지개를 놓을 확률
## 생선 무지개 가운데가 양 끝보다 높은 정도. 중간쯤 눌러 뛰어야 닿는다 (최대 점프 높이 JUMP_MAX_HEIGHT보다 낮게)
const FISH_ARC_HEIGHT := 120.0
## 종이상자는 옥상 BOX_EVERY_MIN~MAX개마다 하나 (한 번에 1개만 가질 수 있음)
const BOX_EVERY_MIN := 40
const BOX_EVERY_MAX := 60
## 종이상자 구제: 발이 이 높이(화면 맨 아래)까지 떨어지면 상자가 받쳐서 가까운 앞 옥상 위로 올려 준다
const RESCUE_HEIGHT := 0.0
const RESCUE_RISE_SPEED := 900.0  # 구제될 때 올라가는 속도 (초당 픽셀)

# --- 구조물: 빨래줄, 전봇대 (넓은 틈에 놓이는 다리·디딤돌) ---
## 새 옥상을 만들 때 "특수 틈"(점프 한 번으로 못 건너는 넓은 틈)으로 만들 확률, 그중 빨래줄이 될 확률 (나머지는 전봇대).
## 처음 SPECIAL_GAP_AFTER개 옥상은 일반 틈만 (처음엔 쉽게)
const SPECIAL_GAP_CHANCE := 0.3
const SPECIAL_GAP_AFTER := 3
const LINE_SHARE := 0.5
## 못 건너는 틈의 여유: 최대 점프로 닿는 거리 + 발 범위 + 코요테에 더하는 픽셀
const SPECIAL_GAP_MARGIN := 40.0
## 빨래줄: 틈 전체를 가로지르는 줄(옥상 위 LINE_HEIGHT 높이). 위에서 내려와 밟으면 튕겨 오른다 (달리다 지나가는 건 막지 않음).
## 튕겨 오른 뒤 아직 틈 위면 줄을 또 밟아 튕기니, 한 번만 밟으면 건너간다
const LINE_HEIGHT := 60.0
## 틈 너비 범위: 못 건너는 최소 ~ 최소 + 튕김 한 번의 거리 x LINE_GAP_SPAN (1이면 튕김 1~2번 만에 건넘)
const LINE_GAP_SPAN := 1.0
## 튕겨 오르는 높이 (줄 위로). 밟기 직전 JUMP_BUFFER_TIME(0.1초) 안에 새로 누르면 더 높이 (최대 점프 높이 250보다 높게)
const LINE_BOUNCE_HEIGHT := 170.0
const LINE_BOOST_HEIGHT := 290.0
## 줄 위 생선 줄의 높이 (줄에서 위로). 기본 튕김으로는 안 닿고 더 높이 튕겨야 먹는다
const LINE_FISH_HEIGHT := 300.0
## 전봇대: 틈 한가운데 판(꼭대기). 판 너비는 속도가 낮을수록 넓게 시작해 POLE_WIDTH_MIN까지 좁아진다.
## 판 높이는 앞뒤 옥상 중 높은 쪽 (판에서 벽에 막히지 않고, 판에서 다음 옥상으로는 내려감)
const POLE_WIDTH_START := 200.0
const POLE_WIDTH_MIN := 120.0
## 판까지·판에서 다음까지 각각 최대 점프 거리의 이 비율 안에 둔다 (일반 틈의 여유 0.5~0.8보다 넉넉히 어렵지 않게)
const POLE_GAP_SAFETY := 0.75
## 틈 너비 범위: 못 건너는 최소 ~ 최소 + POLE_GAP_SPAN
const POLE_GAP_SPAN := 200.0

# --- 고양이 모션 ---
const CAT_STRIDE := 150.0      # 달리기 한 바퀴(프레임 4장)에 가는 거리 (게임 픽셀)
const CAT_CROUCH_TIME := 0.06  # 뛰는 순간 웅크린 그림을 보여 주는 시간 (초)
const CAT_LAND_TIME := 0.12    # 착지 그림(앞발부터 닿고 몸이 눌림)을 보여 주는 시간 (초)

# --- 늘어남·납작해짐 연출 (가로, 세로 배율) ---
const STRETCH_RISE := Vector2(0.84, 1.2)   # 가장 빠르게 올라갈 때
const STRETCH_FALL := Vector2(0.92, 1.1)   # 가장 빠르게 떨어질 때
const SQUASH_LAND := Vector2(1.22, 0.8)    # 착지 순간
const SQUASH_TIME := 0.14                  # 착지 후 원래 모양으로 돌아오는 시간
