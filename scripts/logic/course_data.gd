class_name CourseData
## 손으로 짠 구간 (설계: review/v0.6.0/PLAN.md 5·16번, 그림: review/v0.6.0/segments.png).
## 길이는 픽셀이 아니라 초: t = 옥상 길이, obs = [종류, 옥상 왼쪽에서 몇 초 뒤, 정답 동작(FishRoad: tok/mid/long/double), "gold"면 호 꼭대기에 황금 생선].
## 비둘기는 뛰지 않는 게 정답이라 동작이 없다 (화분과 함께 있으면 화분의 동작). 생선 길은 동작대로 FishRoad가 깐다.
## gap = 최대 점프 거리의 비율, rise = 앞 옥상과의 높이 차, jump = 그 틈을 건너는 동작 (없으면 가장 쉬운 동작). items = ["slot", 초, 옥상 위 높이]: 아이템 자리 (무엇이 놓일지는 ItemSlots).
## min_stage = 나오기 시작하는 속도 단계.

const SEGMENTS := {
	"E1": {"name": "첫 화분", "level": 0, "min_stage": 1, "roofs": [
		{"t": 3.2, "obs": [["pot", 1.8, "mid"]]}]},
	"E2": {"name": "작은 틈", "level": 0, "min_stage": 1, "roofs": [
		{"t": 1.8},
		{"gap": 0.4, "t": 2.2, "items": [["slot", 1.0, 46.0]]}]},
	"E3": {"name": "실외기", "level": 0, "min_stage": 1, "roofs": [
		{"t": 4.0, "obs": [["ac", 1.8, "long"]], "items": [["slot", 0.9, 46.0]]}]},
	"E4": {"name": "비둘기 지나가기", "level": 0, "min_stage": 1, "roofs": [
		{"t": 3.6, "obs": [["flock", 1.9]], "items": [["slot", 2.9, 46.0]]}]},
	"N1": {"name": "화분·실외기 박자", "level": 1, "min_stage": 2, "roofs": [
		{"t": 5.0, "obs": [["pot", 1.8, "mid"], ["ac", 3.3, "long"]], "items": [["slot", 2.6, 46.0]]}]},
	"N2": {"name": "틈 뒤 화분", "level": 1, "min_stage": 2, "roofs": [
		{"t": 1.4},
		{"gap": 0.7, "rise": 60.0, "t": 3.2, "obs": [["pot", 1.6, "mid"]], "items": [["slot", 2.8, 46.0]]}]},
	"N3": {"name": "물탱크", "level": 1, "min_stage": 3, "roofs": [
		{"t": 3.9, "obs": [["tank", 2.1, "double", "gold"]]}]},
	"N4": {"name": "낮게!", "level": 1, "min_stage": 3, "roofs": [
		{"t": 3.6, "obs": [["pot", 1.9, "tok"], ["flock", 1.9]], "items": [["slot", 0.9, 46.0]]}]},
	"N5": {"name": "화분 뒤 비둘기", "level": 1, "min_stage": 3, "roofs": [
		{"t": 4.2, "obs": [["pot", 1.8, "mid"], ["flock", 3.0]], "items": [["slot", 0.9, 46.0]]}]},
	"N6": {"name": "틈 뒤 실외기", "level": 1, "min_stage": 3, "roofs": [
		{"t": 1.6},
		{"gap": 0.75, "t": 3.4, "obs": [["ac", 1.7, "long"]]}]},
	"N7": {"name": "실외기 둘", "level": 1, "min_stage": 4, "roofs": [
		{"t": 5.0, "obs": [["ac", 1.8, "long"], ["ac", 3.4, "long"]], "items": [["slot", 0.9, 46.0]]}]},
	"H1": {"name": "황금 물탱크", "level": 2, "min_stage": 5, "roofs": [
		{"t": 3.5, "obs": [["tank", 2.1, "double", "gold"]]},
		{"gap": 0.75, "t": 2.0}]},
	"H2": {"name": "계단과 비둘기", "level": 2, "min_stage": 5, "roofs": [
		{"t": 3.0, "obs": [["ac", 1.8, "long"]]},
		{"gap": 0.75, "rise": 40.0, "t": 3.4, "obs": [["pot", 1.7, "tok"], ["flock", 1.7]], "items": [["slot", 2.6, 46.0]]}]},
	"H3": {"name": "화분·실외기·화분", "level": 2, "min_stage": 6, "roofs": [
		{"t": 6.2, "obs": [["pot", 1.8, "mid"], ["ac", 3.2, "long"], ["pot", 4.8, "mid"]]}]},
	"H4": {"name": "물탱크 둘", "level": 2, "min_stage": 7, "roofs": [
		{"t": 6.6, "obs": [["tank", 2.1, "double"], ["tank", 4.7, "double", "gold"]]}]},
	"H5": {"name": "낭떠러지 끝 물탱크", "level": 2, "min_stage": 6, "roofs": [
		{"t": 3.5, "obs": [["tank", 2.1, "double"]]},
		{"gap": 0.75, "t": 3.0, "obs": [["pot", 1.7, "mid"]], "items": [["slot", 2.6, 46.0]]}]},
	"H6": {"name": "화분 연타", "level": 2, "min_stage": 6, "roofs": [
		{"t": 7.0, "obs": [["pot", 1.8, "mid"], ["pot", 3.05, "mid"], ["pot", 4.3, "mid"], ["pot", 5.55, "mid"]]}]},
	"H7": {"name": "틈·비둘기·실외기", "level": 2, "min_stage": 7, "roofs": [
		{"t": 1.5},
		{"gap": 0.8, "t": 4.6, "obs": [["flock", 1.6], ["ac", 3.0, "long"]]}]},
	"H9": {"name": "낮게 낮게", "level": 2, "min_stage": 5, "roofs": [
		{"t": 6.0, "obs": [["pot", 1.9, "tok"], ["flock", 1.9], ["pot", 3.9, "tok"], ["flock", 3.9]]}]},
	"H10": {"name": "틈 뒤 낮게", "level": 2, "min_stage": 6, "roofs": [
		{"t": 1.6},
		{"gap": 0.75, "t": 3.6, "obs": [["pot", 1.9, "tok"], ["flock", 1.9]]}]},
	"H11": {"name": "실외기 연타", "level": 2, "min_stage": 6, "roofs": [
		{"t": 6.4, "obs": [["ac", 1.8, "long"], ["ac", 3.4, "long"], ["ac", 5.0, "long"]]}]},
	"H12": {"name": "물탱크 뒤 틈", "level": 2, "min_stage": 8, "roofs": [
		{"t": 3.6, "obs": [["tank", 2.0, "double"]]},
		{"gap": 0.8, "t": 3.2, "obs": [["ac", 1.8, "long"]]}]},
	# 최고 속도 뒤에만 나오는 연타: 빠른 손으로 끝까지 가지 못하게 (숙련 봇 기준)
	"X1": {"name": "톡톡톡", "level": 2, "min_stage": 9, "roofs": [
		{"t": 7.8, "obs": [["pot", 1.8, "tok"], ["pot", 2.9, "tok"], ["pot", 4.0, "tok"], ["pot", 5.1, "tok"], ["pot", 6.2, "tok"]]}]},
	"X2": {"name": "낮게 톡톡", "level": 2, "min_stage": 9, "roofs": [
		{"t": 6.6, "obs": [["pot", 1.9, "tok"], ["flock", 1.9], ["pot", 3.0, "tok"], ["pot", 4.1, "tok"], ["flock", 4.1]]}]},
	"X3": {"name": "낮게 셋", "level": 2, "min_stage": 10, "roofs": [
		{"t": 7.4, "obs": [["pot", 1.9, "tok"], ["flock", 1.9], ["pot", 3.3, "tok"], ["flock", 3.3], ["pot", 4.7, "tok"], ["flock", 4.7]]}]},
	"X4": {"name": "틈 뒤 낮게 둘", "level": 2, "min_stage": 10, "roofs": [
		{"t": 1.6},
		{"gap": 0.8, "t": 5.6, "obs": [["pot", 1.9, "tok"], ["flock", 1.9], ["pot", 3.5, "tok"], ["flock", 3.5]]}]},
	"X5": {"name": "낮게 넷", "level": 2, "min_stage": 11, "roofs": [
		{"t": 8.4, "obs": [["pot", 1.9, "tok"], ["flock", 1.9], ["pot", 3.2, "tok"], ["flock", 3.2], ["pot", 4.5, "tok"], ["flock", 4.5], ["pot", 5.8, "tok"], ["flock", 5.8]]}]},
	"X6": {"name": "실외기 뒤 낮게", "level": 2, "min_stage": 11, "roofs": [
		{"t": 7.0, "obs": [["ac", 1.8, "long"], ["pot", 3.4, "tok"], ["flock", 3.4], ["pot", 4.8, "tok"], ["flock", 4.8]]}]},
	"X7": {"name": "낮게 다섯", "level": 2, "min_stage": 12, "roofs": [
		{"t": 9.6, "obs": [["pot", 1.9, "tok"], ["flock", 1.9], ["pot", 3.2, "tok"], ["flock", 3.2], ["pot", 4.5, "tok"], ["flock", 4.5], ["pot", 5.8, "tok"], ["flock", 5.8], ["pot", 7.1, "tok"], ["flock", 7.1]]}]},
	"H8": {"name": "물탱크 뒤 비둘기와 화분", "level": 2, "min_stage": 8, "roofs": [
		{"t": 6.4, "obs": [["tank", 2.1, "double"], ["flock", 3.9], ["pot", 5.0, "mid"]]}]},
}
