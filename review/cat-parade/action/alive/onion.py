"""치즈 아기 살아 움직이기 그림 확인: 시트(2배)와 겹침 비교(빨간 선 = 쉬는 그림 alive_base 윤곽, 파란 선 = 예전 wait.png 윤곽).
사용: python3 review/cat-parade/action/alive/onion.py <품종>  → review/cat-parade/action/alive/<품종>_sheet.png, <품종>_onion.png"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).parent
NAMES = ["base", "blink", "cheer_0", "cheer_1", "squat", "lie", "surprised",
         "yawn_0", "yawn_1", "groom_0", "groom_1", "knead_0", "knead_1", "look"]
OWN_TAIL = {"lie", "surprised", "squat"}
BG = (190, 215, 250, 255)
W, H = 256, 240


def frame(d: Path, name: str) -> Image.Image:
    cell = Image.new("RGBA", (W, H), BG)
    if name not in OWN_TAIL:
        cell.alpha_composite(Image.open(d / "alive_tail_2.png"))
    cell.alpha_composite(Image.open(d / f"alive_{name}.png"))
    return cell


def edge(img: Image.Image) -> np.ndarray:
    a = np.asarray(img.getchannel("A")) > 128
    return a & ~ndimage.binary_erosion(a)


def main(breed: str) -> None:
    d = ROOT / "assets/sprites/kittens" / breed
    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    base.alpha_composite(Image.open(d / "alive_tail_2.png"))
    base.alpha_composite(Image.open(d / "alive_base.png"))
    wait = Image.open(d / "wait.png")
    wait.alpha_composite(Image.open(d / "wait_tail_2.png"))
    cols = 5
    rows = (len(NAMES) + cols - 1) // cols
    sheet = Image.new("RGBA", (W * cols, H * rows), BG)
    onion = Image.new("RGBA", (W * cols, H * rows), BG)
    for k, name in enumerate(NAMES):
        at = ((k % cols) * W, (k // cols) * H)
        cell = frame(d, name)
        sheet.alpha_composite(cell, at)
        arr = np.array(cell)
        arr[edge(wait)] = (40, 90, 255, 255) if name == "base" else arr[edge(wait)]
        arr[edge(base)] = (255, 0, 0, 255)
        arr[BASELINE_ROW] = (0, 150, 0, 255)  # 발끝 기준선
        onion.alpha_composite(Image.fromarray(arr), at)
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.LANCZOS).save(OUT / f"{breed}_sheet.png")
    onion.save(OUT / f"{breed}_onion.png")


BASELINE_ROW = 216
if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "cheese")
