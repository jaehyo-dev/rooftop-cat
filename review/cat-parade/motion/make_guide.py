"""A 다시 그리기용 발 위치 안내도 (B와 같은 걸음새: 네 발 차례로, 한 발이 바퀴의 30% 디딤).
사용: python3 review/cat-parade/motion/make_guide.py → prompts/a_guide.png (5열 x 2줄 중 8칸, 시트 픽셀 크기)
진한 다리 = 가까운 쪽, 옅은 다리 = 먼 쪽, 빨간 선 = 바닥, 초록 점 = 디딘 발. 몸통·머리는 모든 칸 같은 자리.
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

S = 2.53            # 게임 픽셀 → 시트 픽셀 (A 시트 아기 크기)
LEG = 22.5 * S      # 다리 길이
REACH = LEG * math.sin(math.radians(45))
DUTY = 0.3
STRIDE = 2 * REACH / DUTY
HIPS = {"hind_near": -22 * S, "front_near": 22 * S, "hind_far": -27 * S, "front_far": 17 * S}
PHASE = {"hind_near": 0.0, "front_near": 0.25, "hind_far": 0.5, "front_far": 0.75}
CELL = (300, 330)


def legs(phase: float) -> dict:
    out = {}
    for leg, hx in HIPS.items():
        p = (phase + PHASE[leg]) % 1.0
        if p < DUTY:
            out[leg] = (hx + REACH - 2 * REACH * p / DUTY, 0.0)
        else:
            u = (p - DUTY) / (1 - DUTY)
            e = u * u * (3 - 2 * u)
            out[leg] = (hx - REACH + 2 * REACH * e, -0.35 * LEG * math.sin(math.pi * u))
    return out


def main() -> None:
    img = Image.new("RGB", (CELL[0] * 5, CELL[1] * 2), (255, 255, 255))
    d = ImageDraw.Draw(img)
    for k in range(8):
        ox, oy = (k % 5) * CELL[0] + 150, (k // 5) * CELL[1] + 280
        d.line([(ox - 140, oy), (ox + 140, oy)], fill=(220, 40, 40), width=2)
        feet = legs(k / 8)
        hip_y = oy - LEG * 0.95
        for leg in ["hind_far", "front_far"]:
            fx, fy = feet[leg]
            d.line([(ox + HIPS[leg], hip_y), (ox + fx, oy + fy)], fill=(190, 190, 190), width=16)
        d.ellipse([ox - 75, hip_y - 60, ox + 75, hip_y + 12], outline=(0, 0, 0), width=3)
        d.ellipse([ox + 30, hip_y - 150, ox + 135, hip_y - 45], outline=(0, 0, 0), width=3)
        for leg in ["hind_near", "front_near"]:
            fx, fy = feet[leg]
            d.line([(ox + HIPS[leg], hip_y), (ox + fx, oy + fy)], fill=(60, 60, 60), width=16)
        for leg, (fx, fy) in feet.items():
            if fy == 0.0:
                d.ellipse([ox + fx - 7, oy - 7, ox + fx + 7, oy + 7], fill=(30, 170, 60))
        d.text((ox - 140, oy - 270), f"({k + 1})", fill=(0, 0, 0))
    img.save(Path(__file__).parent / "prompts/a_guide.png")


if __name__ == "__main__":
    main()
