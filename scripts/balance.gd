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
const RUN_SPEED := 430.0  # 초당 픽셀. 1단계는 일정 (빨라지는 건 2단계)

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
const ROOF_GAP_SAFETY := 0.8
## 옥상을 미리 만들어 두는 거리 (고양이 앞쪽)
const ROOF_LOOKAHEAD := 2200.0

# --- 떨어짐 (1단계: 다음 옥상에서 다시 시작. 게임 끝은 2단계) ---
const FALL_LIMIT := -160.0  # 이 높이보다 아래로 떨어지면 떨어진 것으로 본다

# --- 부딪힘 → 투명화 ---
## 높은 옥상 벽에 부딪히면 이 시간 동안 깜빡이며 투명해지고, 벽을 통과해 그 옥상 위로 떠오른다
const GHOST_TIME := 1.2
const GHOST_RISE_SPEED := 700.0  # 투명화 중 옥상 위로 떠오르는 속도 (초당 픽셀)

# --- 늘어남·납작해짐 연출 (가로, 세로 배율) ---
const STRETCH_RISE := Vector2(0.84, 1.2)   # 가장 빠르게 올라갈 때
const STRETCH_FALL := Vector2(0.92, 1.1)   # 가장 빠르게 떨어질 때
const SQUASH_LAND := Vector2(1.22, 0.8)    # 착지 순간
const SQUASH_TIME := 0.14                  # 착지 후 원래 모양으로 돌아오는 시간
