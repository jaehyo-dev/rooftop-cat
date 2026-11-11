class_name MissionTable
extends RefCounted
## 미션 후보·보상·바꾸기 값·고냥이 등급 표 (review/v0.7.0/PLAN.md 5·6번). 미션·등급 수치는 이 파일 한 곳에서만 고친다.
## 후보 칸: kind = 일일 record(한 판 기록, 그 판 값의 최고) / sum(누적) / action(행동, 누적), 주간 daily(일일 미션 축) / sum
##   topic = 같은 날(주) 하나만 나오는 주제, stat = MissionTracker가 세는 값 이름, target = 목표, tier = 1 쉬움 / 2 보통 / 3 어려움(보상 칸),
##   text = 화면 문구(%s = 목표), skilled = "익숙함 이상"(최근 판 거리 가운데 값 SKILLED_MEDIAN m 이상)에게만 뽑음 (tier 3도 마찬가지)
## 목표 수치는 2b 봇 측정으로 맞춤 (review/v0.7.0/2b/missions.md 전후 표)

const DAILY := {
	# 한 판 기록형
	"d_dist_1": {"kind": "record", "topic": "dist", "stat": "meters", "target": 300, "tier": 1, "text": "한 판에 %s m 달리기"},
	"d_dist_2": {"kind": "record", "topic": "dist", "stat": "meters", "target": 500, "tier": 2, "text": "한 판에 %s m 달리기"},
	"d_dist_3": {"kind": "record", "topic": "dist", "stat": "meters", "target": 800, "tier": 3, "text": "한 판에 %s m 달리기"},
	"d_fish_r1": {"kind": "record", "topic": "fish", "stat": "fish", "target": 400, "tier": 1, "text": "한 판에 생선 %s마리"},
	"d_fish_r2": {"kind": "record", "topic": "fish", "stat": "fish", "target": 700, "tier": 2, "text": "한 판에 생선 %s마리"},
	"d_combo_1": {"kind": "record", "topic": "combo", "stat": "combo", "target": 100, "tier": 1, "text": "한 판에 콤보 %s"},
	"d_combo_2": {"kind": "record", "topic": "combo", "stat": "combo", "target": 150, "tier": 2, "text": "한 판에 콤보 %s"},
	"d_stage_1": {"kind": "record", "topic": "stage", "stat": "stage", "target": 4, "tier": 1, "text": "한 판에 %s단계까지 빨라지기"},
	"d_stage_2": {"kind": "record", "topic": "stage", "stat": "stage", "target": 6, "tier": 3, "text": "한 판에 %s단계까지 빨라지기"},
	"d_x5": {"kind": "record", "topic": "combo", "stat": "mult", "target": 5, "tier": 1, "text": "콤보 배수 x%s 만들기"},
	"d_smash_r": {"kind": "record", "topic": "dash", "stat": "smash_one", "target": 5, "tier": 1, "text": "질주 한 번에 장애물 %s개 부수기"},
	# 누적형
	"d_fish_c1": {"kind": "sum", "topic": "fish", "stat": "fish", "target": 1000, "tier": 1, "text": "생선 %s마리 모으기"},
	"d_fish_c2": {"kind": "sum", "topic": "fish", "stat": "fish", "target": 1500, "tier": 2, "text": "생선 %s마리 모으기"},
	"d_dist_c": {"kind": "sum", "topic": "dist", "stat": "meters", "target": 1000, "tier": 1, "text": "%s m 달리기"},
	"d_runs": {"kind": "sum", "topic": "runs", "stat": "runs", "target": 2, "tier": 1, "text": "%s판 하기"},
	"d_gold": {"kind": "sum", "topic": "item", "stat": "gold", "target": 2, "tier": 2, "text": "황금 생선 %s개 먹기"},
	"d_yarn": {"kind": "sum", "topic": "item", "stat": "yarn", "target": 3, "tier": 1, "text": "털실 %s번 먹기"},
	"d_dash": {"kind": "sum", "topic": "dash", "stat": "dash", "target": 2, "tier": 1, "text": "질주 %s번 하기"},
	"d_stage_c": {"kind": "sum", "topic": "stage", "stat": "stage_ups", "target": 8, "tier": 1, "text": "빨라지기 %s번"},
	"d_dodge_pigeon": {"kind": "sum", "topic": "obstacle", "stat": "pass_flock", "target": 8, "tier": 2, "text": "비둘기 떼 %s번 피하기"},
	"d_dodge_pot": {"kind": "sum", "topic": "obstacle", "stat": "pass_pot", "target": 12, "tier": 1, "text": "화분 %s개 넘기"},
	"d_dodge_tank": {"kind": "sum", "topic": "obstacle", "stat": "pass_tank", "target": 3, "tier": 2, "text": "물탱크 %s개 넘기", "skilled": true},
	"d_dodge_ac": {"kind": "sum", "topic": "obstacle", "stat": "pass_ac", "target": 10, "tier": 1, "text": "실외기 %s개 넘기"},
	# 행동형
	"d_double": {"kind": "action", "topic": "jump", "stat": "double", "target": 10, "tier": 1, "text": "더블점프 %s번"},
	"d_double_2": {"kind": "action", "topic": "jump", "stat": "double", "target": 15, "tier": 2, "text": "더블점프 %s번"},
	"d_tramp": {"kind": "action", "topic": "tramp", "stat": "tramp", "target": 2, "tier": 1, "text": "트램펄린에서 %s번 튕기기"},
	"d_perfect": {"kind": "action", "topic": "tramp", "stat": "perfect", "target": 1, "tier": 2, "text": "트램펄린 퍼펙트 %s번", "skilled": true},
	"d_perfect_2": {"kind": "action", "topic": "tramp", "stat": "perfect", "target": 3, "tier": 3, "text": "트램펄린 퍼펙트 %s번"},
	"d_pole": {"kind": "action", "topic": "jump", "stat": "pole", "target": 3, "tier": 2, "text": "전봇대 위에 %s번 내려서기"},
	"d_smash": {"kind": "action", "topic": "dash", "stat": "smash", "target": 12, "tier": 2, "text": "질주로 장애물 %s개 부수기"},
	"d_can": {"kind": "action", "topic": "item", "stat": "can", "target": 1, "tier": 2, "text": "통조림 %s번 열기", "skilled": true},
	"d_bell": {"kind": "action", "topic": "item", "stat": "bell", "target": 1, "tier": 2, "text": "방울로 %s번 막기", "skilled": true},
}

const WEEKLY := {
	"w_daily_10": {"kind": "daily", "topic": "daily", "stat": "daily_done", "target": 10, "tier": 1, "text": "일일 미션 %s개 깨기"},
	"w_daily_15": {"kind": "daily", "topic": "daily", "stat": "daily_done", "target": 15, "tier": 3, "text": "일일 미션 %s개 깨기"},
	"w_alldays": {"kind": "daily", "topic": "daily", "stat": "full_day", "target": 4, "tier": 3, "text": "일일 미션 3개를 다 깬 날 %s일"},
	"w_fish_10k": {"kind": "sum", "topic": "fish", "stat": "fish", "target": 10000, "tier": 1, "text": "이번 주 생선 %s마리"},
	"w_fish_20k": {"kind": "sum", "topic": "fish", "stat": "fish", "target": 20000, "tier": 2, "text": "이번 주 생선 %s마리"},
	"w_dist": {"kind": "sum", "topic": "dist", "stat": "meters", "target": 10000, "tier": 1, "text": "이번 주 %s m 달리기"},
	"w_runs": {"kind": "sum", "topic": "runs", "stat": "runs", "target": 8, "tier": 1, "text": "%s판 하기"},
	"w_double": {"kind": "sum", "topic": "jump", "stat": "double", "target": 100, "tier": 2, "text": "더블점프 %s번"},
	"w_perfect": {"kind": "sum", "topic": "tramp", "stat": "perfect", "target": 10, "tier": 2, "text": "트램펄린 퍼펙트 %s번"},
	"w_smash": {"kind": "sum", "topic": "dash", "stat": "smash", "target": 60, "tier": 2, "text": "질주로 장애물 %s개 부수기"},
	"w_gold": {"kind": "sum", "topic": "item", "stat": "gold", "target": 20, "tier": 2, "text": "황금 생선 %s개"},
	"w_shop": {"kind": "sum", "topic": "shop", "stat": "shop", "target": 3, "tier": 1, "text": "상점에서 %s번 사기"},
}

## 보상 (tier 1·2·3 순서): 생선, 고냥이 등급 경험치
const DAILY_FISH := [400, 500, 600]
const DAILY_XP := [10, 15, 20]
const WEEKLY_FISH := [2500, 3000, 3500]
const WEEKLY_XP := [50, 60, 70]
## 일일 미션 바꾸기 값: 그날 몇 번째인지 (마지막 값이 그 뒤로 계속), 주간은 고정
const SWAP_PRICES := [200, 400, 800]
const WEEKLY_SWAP_PRICE := 1000
## "익숙함 이상": 최근 RECENT_RUNS판(모자라면 있는 만큼) 거리의 가운데 값. 어려움(tier 3)과 skilled 칸(통조림 120초·방울 90초 뒤부터 나옴)은
## 이 값을 넘은 사람에게만, 하루 최대 1개 뽑는다 (2b는 한 판 최고 1,500m였는데 초보 봇도 운 좋은 한 판으로 넘어 4판 안 59%로 떨어짐.
## 가운데 값은 운 좋은 한 판에 흔들리지 않음. 수치는 봇으로 정함, review/v0.7.0/2b/missions.md "2c 전 수정")
const SKILLED_MEDIAN := 1000
const RECENT_RUNS := 10

## 고냥이 등급 (1~10). NEXT_XP[i] = (i+1)등급에서 다음 등급까지 경험치
const RANK_NAMES := ["아기 고냥이", "골목 고냥이", "담장 고냥이", "지붕 고냥이", "굴뚝 고냥이",
		"전봇대 고냥이", "노을 고냥이", "별빛 고냥이", "달빛 고냥이", "전설의 고냥이"]
const RANK_NEXT_XP := [100, 150, 200, 250, 300, 350, 400, 450, 500]
## 등급에 오를 때 보너스: RANK_BONUS[i] = (i+2)등급 [생선, 부스터 목록]
const RANK_BONUS := [
	[1000, ["dash_start"]], [1500, ["bell_start"]], [2000, ["fish_bonus"]],
	[2500, ["dash_start", "bell_start", "fish_bonus"]], [3000, ["dash_start", "bell_start", "fish_bonus"]],
	[3500, ["dash_start", "bell_start", "fish_bonus"]], [4000, ["dash_start", "bell_start", "fish_bonus"]],
	[4500, ["dash_start", "bell_start", "fish_bonus"]], [5000, ["dash_start", "bell_start", "fish_bonus"]],
]
## 마지막 등급 뒤: 이 경험치마다 생선
const RANK_AFTER_MAX_XP := 500
const RANK_AFTER_MAX_FISH := 2000
