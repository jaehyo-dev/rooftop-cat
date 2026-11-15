"""검수 시트: 아기마다 모든 프레임(frames_<품종>.png), 6마리를 같은 자세끼리(compare_N.png).
연한 바탕 + 발끝 기준선(빨강)·몸 중심선(파랑). 기다리기 칸은 꼬리 0·2·4번을 몸 뒤에 겹쳐 3칸.
사용: python3 review/cat-parade/kitten2/make_sheets.py
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
from cut_kittens import ANCHOR_X, BASELINE, CANVAS, NAMES  # noqa: E402

BREEDS = ["cheese", "mackerel", "tuxedo", "calico", "cow", "gray"]
OUT = Path(__file__).parent
BG = (238, 230, 214, 255)


def frame(breed: str, name: str) -> Image.Image:
    d = ROOT / "assets/sprites/kittens" / breed
    cell = Image.new("RGBA", CANVAS, BG)
    draw = ImageDraw.Draw(cell)
    draw.line([(0, BASELINE), (CANVAS[0], BASELINE)], fill=(220, 80, 80, 255))
    draw.line([(ANCHOR_X, 0), (ANCHOR_X, CANVAS[1])], fill=(120, 150, 220, 255))
    if name.startswith("wait"):
        cell.alpha_composite(Image.open(d / f"wait_tail_{name[-1]}.png"))
        name = "wait"
    cell.alpha_composite(Image.open(d / f"{name}.png"))
    return cell


def cells() -> list:
    return [n for n in NAMES if n != "wait"] + ["wait_0", "wait_2", "wait_4", "face"]


def main() -> None:
    names = cells()
    w, h = CANVAS
    for breed in BREEDS:
        cols = 7
        sheet = Image.new("RGBA", (cols * w, -(-len(names) // cols) * h), (255, 255, 255, 255))
        for i, n in enumerate(names):
            img = frame(breed, n) if n != "face" else Image.open(ROOT / "assets/sprites/kittens" / breed / "face.png")
            sheet.alpha_composite(img, ((i % cols) * w, (i // cols) * h))
        sheet.convert("RGB").save(OUT / f"frames_{breed}.png")
    poses = names[:-1]
    for k in range(0, len(poses), 7):
        group = poses[k:k + 7]
        sheet = Image.new("RGBA", (len(BREEDS) * w, len(group) * h), (255, 255, 255, 255))
        for r, n in enumerate(group):
            for c, breed in enumerate(BREEDS):
                sheet.alpha_composite(frame(breed, n), (c * w, r * h))
        sheet.convert("RGB").save(OUT / f"compare_{k // 7 + 1}.png")


if __name__ == "__main__":
    main()
