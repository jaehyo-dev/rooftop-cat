"""아기별 전체 그림 시트 (무늬·소품이 장마다 같은지 보는 용): 달리기 32장 → 땅·공중 자세 → 놀람(달리기 + 놀란 윗몸, 움츠림, 펄쩍).
빨간 선 = 발끝 기준선. 사용: python3 review/cat-parade/final/make_frames_sheet.py <품종> [출력]"""
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
DATA = (ROOT / "scripts/logic/kitten_motion_data.gd").read_text()
N = int(re.search(r"const RUN_FRAMES := (\d+)", DATA).group(1))
POSES = re.search(r"const POSES := \[(.*?)\]", (ROOT / "scripts/kitten_view.gd").read_text(), re.S).group(1)
POSES = re.findall(r'"(\w+)"', POSES)
COLS = 10
W, H = 300, 260
S = 0.6


def sheet(breed: str) -> Image.Image:
    d = ROOT / f"assets/sprites/kitten_motion/{breed}"
    names = [f"run_{i}" for i in range(N)] + POSES + ["scared_run"]
    rows = (len(names) + COLS - 1) // COLS
    out = Image.new("RGBA", (int(W * S) * COLS, int(H * S) * rows), (236, 228, 214, 255))
    draw = ImageDraw.Draw(out)
    for i, n in enumerate(names):
        if n == "scared_run":
            img = Image.open(d / "run_0.png").convert("RGBA")
            img.alpha_composite(Image.open(d / "scared_upper.png").convert("RGBA"))
        else:
            img = Image.open(d / f"{n}.png").convert("RGBA")
        x, y = (i % COLS) * int(W * S), (i // COLS) * int(H * S)
        out.alpha_composite(img.resize((int(W * S), int(H * S)), Image.LANCZOS), (x, y))
        draw.line([(x, y + int(236 * S)), (x + int(W * S) - 4, y + int(236 * S))], fill=(220, 60, 60, 255))
        draw.text((x + 4, y + 2), n, fill=(90, 70, 54, 255))
    return out


if __name__ == "__main__":
    b = sys.argv[1]
    sheet(b).convert("RGB").save(sys.argv[2] if len(sys.argv) > 2 else Path(__file__).parent / f"frames_{b}.png")
