"""구름 타기 치즈냥 그림과 다른 아기(삼색이·고등어) wait.png 그림체 비교 (2026-11-20).
사용: python3 review/cat-parade/action/ride/style_compare.py → review/cat-parade/action/ride/style_compare.png
줄: 원본 크기(256x240) / 게임 크기(0.28배 아기 = 그림 x 0.295, 화면 그대로) / 게임 크기를 2배로 확대 (최근접이 아니라 부드럽게)
칸: 치즈냥 타기·올라가기·내려가기(새 그림) | 삼색이 wait | 고등어 wait. 배경은 게임 하늘색.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[4]
D = ROOT / "assets/sprites/kittens"
GAME = 2.5 * 150.0 / (711.0 * 0.5) * 0.28  # CatView.KITTEN_ART x art_scale x 크기 0.28
SKY = (205, 225, 238, 255)
CELLS = [("cheese", "alive_ride_0", None), ("cheese", "alive_ride_up", None),
         ("cheese", "alive_ride_down", None), ("calico", "wait", "wait_tail_2"), ("mackerel", "wait", "wait_tail_2")]
LABELS = ["치즈 타기", "치즈 올라가기", "치즈 내려가기", "삼색이 wait", "고등어 wait"]


def art(breed: str, body: str, tail) -> Image.Image:
    im = Image.new("RGBA", (256, 240), (0, 0, 0, 0))
    if tail:
        im.alpha_composite(Image.open(D / breed / f"{tail}.png").convert("RGBA"))
    im.alpha_composite(Image.open(D / breed / f"{body}.png").convert("RGBA"))
    return im


def main() -> None:
    small = (round(256 * GAME), round(240 * GAME))
    rows = [(256, 240), small, (small[0] * 2, small[1] * 2)]
    pad = 12
    w = len(CELLS) * (256 + pad) + pad
    top = 30  # 이름표
    h = top + sum(r[1] for r in rows) + pad * (len(rows) + 1)
    out = Image.new("RGBA", (w, h), SKY)
    y = top + pad
    for k, size in enumerate(rows):
        for c, cell in enumerate(CELLS):
            im = art(*cell)
            if k > 0:
                im = im.resize(small, Image.LANCZOS)
            if k == 2:
                im = im.resize(size, Image.BILINEAR)
            out.alpha_composite(im, (pad + c * (256 + pad) + (256 - size[0]) // 2, y))
        y += size[1] + pad
    font = ImageFont.truetype(str(ROOT / "assets/fonts/jua/Jua-Regular.ttf"), 20)
    for c, label in enumerate(LABELS):
        ImageDraw.Draw(out).text((pad + c * (256 + pad) + 8, 6), label, fill=(60, 60, 60, 255), font=font)
    out.convert("RGB").save(Path(__file__).parent / "style_compare.png")


if __name__ == "__main__":
    main()
