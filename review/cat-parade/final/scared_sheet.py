"""놀람 그림 확인 시트: 위 = 달리기(웃음), 아래 = 같은 장 + 놀란 윗몸 덮음 (게임과 같이 BOB만큼 내림), 오른쪽 = 움츠림·펄쩍·멈칫.
사용: python3 review/cat-parade/final/scared_sheet.py <품종> [출력]"""
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
BOB = [int(v) for v in re.search(r"const BOB := \[([^\]]*)\]", (ROOT / "scripts/logic/kitten_motion_data.gd").read_text()).group(1).split(",")]


def sheet(breed: str) -> Image.Image:
    d = ROOT / f"assets/sprites/kitten_motion/{breed}"
    up = Image.open(d / "scared_upper.png").convert("RGBA")
    ks = [0, 6, 12, 20]
    w, h = 300, 260
    out = Image.new("RGBA", (w * (len(ks) + 3), h * 2), (236, 228, 214, 255))
    for i, k in enumerate(ks):
        run = Image.open(d / f"run_{k}.png").convert("RGBA")
        out.alpha_composite(run, (i * w, 0))
        both = run.copy()
        moved = Image.new("RGBA", up.size)
        moved.paste(up, (0, BOB[k]))
        both.alpha_composite(moved)
        out.alpha_composite(both, (i * w, h))
    for j, name in enumerate(["scared_crouch", "scared_hop", "startle"]):
        out.alpha_composite(Image.open(d / f"{name}.png").convert("RGBA"), ((len(ks) + j) * w, h))
    ImageDraw.Draw(out).line([(0, h + 236), (out.width, h + 236)], fill=(220, 60, 60, 255))
    return out


if __name__ == "__main__":
    b = sys.argv[1]
    sheet(b).save(sys.argv[2] if len(sys.argv) > 2 else Path(__file__).parent / f"scared_{b}.png")
