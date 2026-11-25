"""첫 동네 적 시안 비교 그림을 만든다.
사용: python3 review/restructure/enemies/compose.py
만드는 것: scene_1-1.png(장면 1280x720), lineup.png(게임 크기 2배로 주인공과 적 기본 자세 나란히), phone_compare.png(폰 844x390에서 장면 + 적 줄)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
import cartoon_art as ca  # noqa: E402

OUT = Path(__file__).parent
ART = ROOT / "assets/concept/cartoon/enemies"
FONT = ImageFont.truetype(str(ROOT / "assets/fonts/jua/Jua-Regular.ttf"), 24)
INK = (60, 40, 30)
HERO_GAME_H = 113   # 게임 속 주인공 그림 키 = 판정 몸 높이 92 / 판정·그림 비율 0.816 (balance.gd SLIDE_BODY 주석)
PHONE = (844, 390)
# 시트마다 (주인공 칸, [(이름, 기본 자세 칸)]) 가로 범위 (원본 2172px 기준)
SHEETS = {
    "crows_1.png": ((40, 345), [("까마귀 졸개", (400, 600)), ("폭탄 까마귀", (1185, 1465))]),
    "ground_1.png": ((20, 290), [("쥐 무리", (300, 600)), ("비둘기 방패병", (1290, 1540))]),
    "boss_1.png": ((35, 300), [("까마귀 두목", (310, 660))]),
}


def crop(rgba, x0, x1):
    """가로 범위를 잘라 그림이 있는 곳만 남긴다 (바닥선 회색 줄은 알파 0.6 미만이라 빠지게 굵은 것만)."""
    part = rgba[:, x0:x1]
    a = part[..., 3] > 200
    a[np.abs(part[..., :3].astype(int) - 225).max(-1) < 30] = False   # 옅은 회색 바닥선 빼기
    ys, xs = np.nonzero(a)
    return Image.fromarray(part[ys.min():ys.max() + 1, xs.min():xs.max() + 1])


def figures():
    """[(이름, 게임 크기 그림)]: 시트마다 주인공 키를 게임 키로 맞춘 배율을 적용한다."""
    out = []
    for name, (hero_x, enemies) in SHEETS.items():
        rgba = ca.cutout(Image.open(ART / name))
        hero = crop(rgba, *hero_x)
        k = HERO_GAME_H / hero.height
        def fit(im):
            return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
        if not out:
            out.append(("주인공", fit(hero)))
        out += [(n, fit(crop(rgba, *xr))) for n, xr in enemies]
    return out


def row(figs, scale, gap, label):
    """같은 바닥선 위에 나란히. label이면 이름을 아래에."""
    ims = [im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS) for _, im in figs]
    h = max(im.height for im in ims)
    w = sum(im.width for im in ims) + gap * (len(ims) + 1)
    canvas = Image.new("RGB", (w, h + (50 if label else 10) + 20), ca.PAPER)
    d = ImageDraw.Draw(canvas)
    x = gap
    for (n, _), im in zip(figs, ims):
        canvas.paste(im, (x, 20 + h - im.height), im)
        if label:
            tw = d.textlength(n, font=FONT)
            d.text((x + (im.width - tw) / 2, h + 30), n, fill=INK, font=FONT)
        x += im.width + gap
    return canvas


def main():
    Image.open(ART / "scene_1.png").convert("RGB").resize((1280, 720), Image.LANCZOS).save(OUT / "scene_1-1.png")
    figs = figures()
    row(figs, 2.0, 60, True).save(OUT / "lineup.png")
    # 폰: 1280x720 화면이 높이 390에 맞춰 0.54배 (stretch aspect=expand, 가로는 더 보임)
    k = PHONE[1] / 720
    scene = Image.open(ART / "scene_1.png").convert("RGB").resize((round(1280 * k), PHONE[1]), Image.LANCZOS)
    phone = Image.new("RGB", PHONE, ca.PAPER)
    phone.paste(scene, ((PHONE[0] - scene.width) // 2, 0))
    small = row(figs, k, 24, False)
    top = 40
    sheet = Image.new("RGB", (max(PHONE[0], small.width) + 40, top + PHONE[1] + 30 + small.height + 50), (235, 228, 215))
    d = ImageDraw.Draw(sheet)
    d.text((20, 8), "폰 844x390 실제 크기: 장면(게임 화면 0.54배)", fill=INK, font=FONT)
    sheet.paste(phone, (20, top))
    d.text((20, top + PHONE[1] + 6), "같은 배율의 주인공, 졸개, 폭탄 까마귀, 쥐 무리, 방패병, 두목", fill=INK, font=FONT)
    sheet.paste(small, (20, top + PHONE[1] + 40))
    sheet.save(OUT / "phone_compare.png")
    print("\n".join(f"{n}: {im.width}x{im.height}" for n, im in figs))


if __name__ == "__main__":
    main()
