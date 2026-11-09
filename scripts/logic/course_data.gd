class_name CourseData
## 손으로 짠 구간 (설계 10개 + 밸런스로 더한 2개, 설계: review/v0.6.0/PLAN.md 5번, 그림: review/v0.6.0/segments.png).
## 길이는 픽셀이 아니라 초: t = 옥상 길이, obs = [종류, 옥상 왼쪽에서 몇 초 뒤], items = [종류, 초, 옥상 위 높이, 개수].
## gap = 최대 점프 거리의 비율, rise = 앞 옥상과의 높이 차. min_stage = 나오기 시작하는 속도 단계.
## "slot" = 아이템 자리 (무엇이 놓일지는 ItemSlots), "gold" = 황금 생선 (물탱크를 더블로 넘으면 닿음).

const SEGMENTS := {
	"E1": {"level": 0, "min_stage": 1, "roofs": [
		{"t": 3.2, "obs": [["pot", 1.8]], "items": [["fish", 0.8, 46.0, 3], ["fish", 1.55, 130.0, 3]]}]},
	"E2": {"level": 0, "min_stage": 1, "roofs": [
		{"t": 1.8, "items": [["fish", 0.6, 46.0, 3]]},
		{"gap": 0.4, "t": 2.2, "items": [["slot", 1.0, 46.0]]}]},
	"E3": {"level": 0, "min_stage": 1, "roofs": [
		{"t": 4.0, "obs": [["ac", 1.8]], "items": [["fish", 2.8, 46.0, 5], ["slot", 0.9, 46.0]]}]},
	"E4": {"level": 0, "min_stage": 1, "roofs": [
		{"t": 3.6, "obs": [["flock", 1.9]], "items": [["fish", 1.1, 46.0, 8], ["slot", 2.9, 46.0]]}]},
	"N1": {"level": 1, "min_stage": 2, "roofs": [
		{"t": 5.0, "obs": [["pot", 1.8], ["ac", 3.3]], "items": [["slot", 2.6, 46.0]]}]},
	"N2": {"level": 1, "min_stage": 2, "roofs": [
		{"t": 1.4},
		{"gap": 0.55, "rise": 60.0, "t": 3.2, "obs": [["pot", 1.6]], "items": [["fish", 2.2, 46.0, 4], ["slot", 2.8, 46.0]]}]},
	"N3": {"level": 1, "min_stage": 3, "roofs": [
		{"t": 3.9, "obs": [["tank", 2.1]], "items": [["gold", 2.13, 400.0]]}]},
	"N4": {"level": 1, "min_stage": 4, "roofs": [
		{"t": 3.6, "obs": [["pot", 1.9], ["flock", 1.9]], "items": [["fish", 2.5, 46.0, 3], ["slot", 0.9, 46.0]]}]},
	"H1": {"level": 2, "min_stage": 5, "roofs": [
		{"t": 3.5, "obs": [["tank", 2.1]], "items": [["gold", 2.13, 400.0]]},
		{"gap": 0.6, "t": 2.0, "items": [["fish", 0.6, 46.0, 4]]}]},
	"H2": {"level": 2, "min_stage": 5, "roofs": [
		{"t": 3.0, "obs": [["ac", 1.8]]},
		{"gap": 0.6, "rise": 40.0, "t": 3.4, "obs": [["pot", 1.7], ["flock", 1.7]], "items": [["slot", 2.6, 46.0]]}]},
	# 뒤 단계에 긴장이 모자랄 때 더하는 구간 (PLAN 5번 "장애물이 더 많은 구간", 밸런스 봇 익숙함이 목표보다 오래 버텨 추가)
	"H3": {"level": 2, "min_stage": 6, "roofs": [
		{"t": 5.4, "obs": [["pot", 1.8], ["ac", 3.0], ["pot", 4.2]], "items": [["fish", 2.4, 46.0, 3]]}]},
	"H4": {"level": 2, "min_stage": 7, "roofs": [
		{"t": 6.2, "obs": [["tank", 2.1], ["tank", 4.4]], "items": [["fish", 3.3, 46.0, 3]]}]},
}
