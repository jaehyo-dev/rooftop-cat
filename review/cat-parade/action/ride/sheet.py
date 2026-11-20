"""구름 타기 그림 시트: 타기 5장 2배 (빨간 선 = ride_0 윤곽, 초록 줄 = 발끝 기준선 216), 아래 줄 = 구름·조각.
사용: python3 review/cat-parade/action/ride/sheet.py → review/cat-parade/action/ride/ride_sheet.png"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[4]
D = ROOT / "assets/sprites/kittens/cheese"
C = ROOT / "assets/sprites/kittens/ride"
NAMES = ["ride_0", "ride_1", "ride_2", "ride_up", "ride_down"]
BG = (196, 226, 245, 255)

key = np.asarray(Image.open(D / "alive_ride_0.png"))[..., 3] > 128
edge = key & ~ndimage.binary_erosion(key)
cells = []
for n in NAMES:
    im = Image.open(D / f"alive_{n}.png").convert("RGBA")
    cell = Image.new("RGBA", im.size, BG)
    cell.alpha_composite(im)
    arr = np.array(cell)
    arr[edge] = (220, 40, 40, 255)
    arr[216, :] = (40, 170, 60, 255)
    cells.append(Image.fromarray(arr).resize((im.width * 2, im.height * 2), Image.NEAREST))
w, h = cells[0].size
sheet = Image.new("RGBA", (w * 5, h + 260), BG)
for k, c in enumerate(cells):
    sheet.alpha_composite(c, (k * w, 0))
    ImageDraw.Draw(sheet).text((k * w + 8, 8), NAMES[k], fill=(0, 0, 0, 255))
x = 20
for n in ["cloud", "puff_0", "puff_1", "puff_2"]:
    im = Image.open(C / f"ride_{n}.png").convert("RGBA")
    im = im.resize((im.width * 2, im.height * 2), Image.LANCZOS)
    sheet.alpha_composite(im, (x, h + 30))
    x += im.width + 30
sheet.convert("RGB").save(Path(__file__).parent / "ride_sheet.png")
