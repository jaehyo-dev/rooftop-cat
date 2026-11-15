class_name KittenMotionData
## 아기 움직임 측정값 (tools/cut_kitten_motion.py가 씀, 손으로 고치지 마)
## A_: 캔버스 픽셀 (발끝 원점 기준 x), B_: 부품 그림 픽셀

# A 시작
const A_ADVANCE := [31.62, 31.62, 31.62, 31.62, 31.62, 31.62, 31.62, 31.62]
const A_FEET := [[-27.5, 16.0], [-45.0], [-72.5, 54.0], [25.0], [-20.0, 16.5], [-42.0], [-72.5, 53.5], [37.0]]
const A_ANCHOR := [150, 236]
# A 끝

# B 시작
const B_SIZE := {"torso": [154, 87], "head": [120, 118], "head_surprised": [120, 118], "front_near": [47, 69], "front_far": [47, 70], "hind_near": [60, 74], "hind_far": [60, 74], "tail": [66, 83]}
const B_PIVOT := {"front_near": [20.5, 18.0], "front_far": [21.0, 18.4], "hind_near": [27.5, 24.2], "hind_far": [27.5, 24.2], "head": [52.5, 109.0], "head_surprised": [52.5, 109.0], "tail": [42.0, 74.0]}
const B_PLACE := {"front": [123.2, 62.6], "hind": [33.9, 57.4], "neck": [123.2, 27.8], "tail": [10.8, 26.1]}
const B_LEG_LEN := 46.5
const B_FAR_SHIFT := -10.0
const B_ART := 0.8345
# B 끝
