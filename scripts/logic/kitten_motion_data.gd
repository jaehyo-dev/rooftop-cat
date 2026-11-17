class_name KittenMotionData
## 아기 움직임 측정값 (tools/cut_kitten_motion.py가 씀, 손으로 고치지 마). 캔버스 픽셀

const ANCHOR := [150, 236]  # 발끝 원점
const RUN_FRAMES := 32
## 달리기 장마다 윗몸이 내려앉은 만큼 (놀란 윗몸을 같이 내려 덮음)
const BOB := [0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 2, 1, 1, 1, 0, 0]
## 품종 → 달리기 장마다 거리 (아기가 이만큼 달리면 다음 장)
const ADVANCE := {"calico": 4.875, "cheese": 4.88, "cow": 4.5, "gray": 4.875, "mackerel": 4.625, "tuxedo": 4.5}
