"""1단계 확인: 기준 그림 옆모습 · 적 장면 시안 속 주인공 · 게임 화면 속 달리기(고치기 전/후)를 같은 키로 나란히 + 부위별 색 표.
사용: python3 review/restructure/v0.8-art/hero_color.py <고치기 전 게임 캡처> <고친 뒤 게임 캡처> [상자 x0,y0,x1,y1]
  → hero_color_compare.png, 표는 출력 (README에 붙임). 캡처는 parade_art 평지 장(art_flat_real_f150_pc.png), 상자 = 주인공 둘레"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
from cartoon_art import HERO, cutout, palette_report  # noqa: E402

H = 260  # 나란히 놓을 키
FONT = ROOT / "assets/fonts/jua/Jua-Regular.ttf"
SOURCES = [("기준 옆모습", ROOT / "assets/concept/cartoon/hero_reference.png", (100, 40, 600, 380), True),
           ("적 장면 시안", ROOT / "review/restructure/enemies/scene_1-1.png", (230, 395, 560, 525), False),
           ]


def mask_bg(im):
    """게임 캡처에서 주인공만: 하늘·건물 등 배경 색을 투명으로 (주인공 색표 근처·선 색만 남김)."""
    a = np.asarray(im.convert("RGBA")).copy()
    pal = np.array(list(HERO.values()) + [(0x33, 0x18, 0x06), (0xF8, 0x88, 0x28), (0x70, 0xD0, 0x98)])
    d = np.abs(a[..., None, :3].astype(int) - pal).sum(-1).min(-1)
    # 배경 평면색(하늘·지평선 띠·옥상 턱·벽·나무 띠)과 거의 같은 픽셀은 뺀다
    bg = np.array([(0xC3, 0xE0, 0xFD), (0xDD, 0xDB, 0xF0), (0xFE, 0xF0, 0xDB), (0xFE, 0xE7, 0xC8), (0xFE, 0xEE, 0xD4),
                   (0xCC, 0xE4, 0xCA), (0xDE, 0xCC, 0x99), (0xFD, 0xEC, 0xC8)])
    near_bg = np.abs(a[..., None, :3].astype(int) - bg).sum(-1).min(-1) < 14
    a[..., 3] = np.where((d < 90) & ~near_bg, 255, 0)
    return Image.fromarray(a)


def load(path, box, magenta):
    im = Image.open(path)
    if magenta == "game":
        im, box = mask_bg(im.crop(box)), None
    elif magenta:
        im = Image.fromarray(cutout(im))
    im = im.convert("RGBA")
    if box:
        im = im.crop(box)
    a = np.asarray(im)
    ys, xs = np.where(a[..., 3] > 128)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def main():
    box = tuple(int(v) for v in sys.argv[3].split(",")) if len(sys.argv) > 3 else (230, 330, 420, 475)
    items = list(SOURCES) + [("게임 화면 (고치기 전)", Path(sys.argv[1]), box, "game"),
                             ("게임 화면 (고친 뒤)", Path(sys.argv[2]), box, "game")]
    ims = [(name, load(p, b, m)) for name, p, b, m in items]
    ims = [(n, im.resize((round(im.width * H / im.height), H), Image.LANCZOS)) for n, im in ims]
    W = sum(im.width for _, im in ims) + 40 * (len(ims) + 1)
    out = Image.new("RGB", (W, H + 70), (0xC3, 0xE0, 0xFD))
    d = ImageDraw.Draw(out)
    x = 40
    for n, im in ims:
        out.paste(im, (x, 50), im)
        d.text((x, 12), n, fill=(0x33, 0x18, 0x06), font=ImageFont.truetype(str(FONT), 26))
        x += im.width + 40
    out.save(Path(__file__).parent / "hero_color_compare.png")
    names = list(HERO)
    print("| 부위 | 색표 | " + " | ".join(n for n, *_ in items) + " |")
    print("|---|---|" + "---|" * len(items))
    reps = [palette_report(np.asarray(load(p, b, m)), HERO, min_count=30) for _, p, b, m in items]
    for k in names:
        cells = []
        for r in reps:
            cells.append("#%02X%02X%02X (%d)" % (*r[k][1], r[k][2]) if k in r else "-")
        print(f"| {k} | #{''.join('%02X' % v for v in HERO[k])} | " + " | ".join(cells) + " |")


if __name__ == "__main__":
    main()
