"""카툰 기준 단계 확인 자료를 만든다.
사용: python3 review/restructure/cartoon/compose.py <효과 후보 내려받은 폴더>
  후보 폴더: oga28000/PNG/(Kenney 연기 묶음 압축을 푼 것), poof/Poof.png (README "효과 후보" 표의 주소에서 받음)
만드는 것: hero_compare.png(3_A 주인공 옆 새 기준 그림), slide_*/hit_* GIF·겹침 비교·장 모음, effects_compare.png
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
import cartoon_art as ca  # noqa: E402

OUT = Path(__file__).parent
ART = ROOT / "assets/concept/cartoon"
FONT = ImageFont.truetype(str(ROOT / "assets/fonts/jua/Jua-Regular.ttf"), 26)
SMALL = ImageFont.truetype(str(ROOT / "assets/fonts/jua/Jua-Regular.ttf"), 20)
INK = (60, 40, 30)
SLIDE, HIT = ART / "slide_1.png", ART / "hit_2.png"


def hero_compare():
    """왼쪽 3_A 시안 주인공, 오른쪽 새 기준 그림(크림 바탕)."""
    old = Image.open(ROOT / "review/restructure/cartoon/prompts/ref_cartoon_hero.png").convert("RGB")
    rgba = Image.fromarray(ca.cutout(Image.open(ART / "hero_reference.png")))
    new = Image.new("RGB", rgba.size, ca.PAPER)
    new.paste(rgba, (0, 0), rgba)
    h = 420
    old = old.resize((round(old.width * h / old.height), h), Image.LANCZOS)
    new = new.resize((round(new.width * h / new.height), h), Image.LANCZOS)
    sheet = Image.new("RGB", (old.width + new.width + 30, h + 50), (255, 255, 255))
    sheet.paste(old, (0, 50))
    sheet.paste(new, (old.width + 30, 50))
    d = ImageDraw.Draw(sheet)
    d.text((10, 10), "화풍 3 시안 3_A 주인공", font=FONT, fill=INK)
    d.text((old.width + 40, 10), "새 기준 그림 hero_reference.png (옆, 앞, 3/4, 뒤 + 표정 6개)", font=FONT, fill=INK)
    sheet.save(OUT / "hero_compare.png")


def frame_rgba(sheet, counts, k):
    """시트의 k번째 장(1부터)을 RGBA로."""
    clean, boxes = ca.cut_frames(ca.cutout(Image.open(sheet)), counts)
    x0, y0, x1, y1 = boxes[k - 1][2]
    return Image.fromarray(clean[y0:y1, x0:x1])


def fit(im, h):
    return im.resize((max(1, round(im.width * h / im.height)), h), Image.LANCZOS)


def toon(rgba, fill=(0xFE, 0xEB, 0xCF), line=3):
    """CC0 연기 모양을 14절 카툰으로: 평면 크림 + 짙은 고동 선 + 오른쪽 아래 그림자 한 단계."""
    a = np.asarray(rgba)[..., 3] > 110
    a = ndi.binary_opening(a, iterations=2)
    shade = a & ~ndi.shift(a, (-6, -6), order=0)          # 왼쪽 위 빛 → 오른쪽 아래 그늘
    out = np.zeros(a.shape + (4,), np.uint8)
    out[a] = fill + (255,)
    out[shade] = (0xFB, 0xD3, 0xB2, 255)
    out[ndi.binary_dilation(a, iterations=line) & ~a] = ca.LINE + (255,)
    return Image.fromarray(out)


def star_toon(size=120):
    """비교용: 14절 색의 뾰족한 충격 별 (후보 3의 짝, 모양만 코드로)."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c, pts = size / 2, []
    for i in range(20):
        r = size * (0.48 if i % 2 == 0 else 0.26)
        t = np.pi * 2 * i / 20
        pts.append((c + r * np.cos(t), c + r * np.sin(t)))
    ImageDraw.Draw(im).polygon(pts, fill=(0xF7, 0xDA, 0x37, 255), outline=ca.LINE + (255,), width=4)
    return im


def effects_compare(dl):
    dl = Path(dl)
    puff = Image.open(dl / "oga28000/PNG/White puff/whitePuff10.png").convert("RGBA")
    flash = Image.open(dl / "oga28000/PNG/Flash/flash05.png").convert("RGBA")
    poof = Image.open(dl / "poof/Poof.png").convert("RGBA").crop((1280, 256, 1536, 512))
    slide_b = fit(frame_rgba(SLIDE, [6, 3], 2), 110)  # 몸 낮추기: 시트 먼지가 없는 장
    run = fit(frame_rgba(HIT, [5], 1), 140)
    rows = [
        ("1. Kenney 연기 묶음: 흰 연기 + 번쩍임 (CC0, 원본 그대로)", fit(puff, 90), fit(flash, 120)),
        ("2. jellyfizh Poof 스프라이트 (CC0, 원본 그대로)", fit(poof, 110), fit(poof, 120)),
        ("3. Kenney 흰 연기 모양 + 카툰 후처리 (평면 크림, 선, 그늘 한 단계) / 별은 코드 도형", fit(toon(fit(puff, 90)), 90), star_toon(120)),
        ("4. 지금 Codex 시트 속 효과 (그림에 함께 그림)", None, None),
    ]
    W, H = 1100, 230
    sheet = Image.new("RGB", (W, H * len(rows) + 300), (255, 255, 255))
    d = ImageDraw.Draw(sheet)
    for i, (label, dust, hit) in enumerate(rows):
        y = i * H
        cell = Image.new("RGBA", (W, H - 40), ca.PAPER + (255,))
        cd = ImageDraw.Draw(cell)
        base = H - 60
        cd.line([(0, base), (W, base)], fill=(200, 196, 210), width=2)
        if dust is None:
            sb = fit(frame_rgba(SLIDE, [6, 3], 4), 130)
            h2 = fit(frame_rgba(HIT, [5], 2), 150)
            cell.alpha_composite(sb, (40, base - sb.height))
            cell.alpha_composite(h2, (640, base - h2.height))
        else:
            cell.alpha_composite(dust, (60, base - dust.height + 5))
            cell.alpha_composite(slide_b, (130, base - slide_b.height))
            cell.alpha_composite(run, (640, base - run.height))
            cell.alpha_composite(hit, (640 + run.width - 30, base - run.height - 30))
        sheet.paste(cell.convert("RGB"), (0, y + 40))
        d.text((10, y + 8), label, font=FONT, fill=INK)
    table = [
        "후보 | 만든 사람 | 라이선스 | 받은 곳",
        "1, 3 Smoke particle assets (White puff, Flash) | Kenney | CC0 1.0 | opengameart.org/node/28000 (license.txt 확인)",
        "2 Poof Effect Spritesheet | jellyfizh | CC0 | opengameart.org/node/107789",
        "4 Codex 내장 이미지 생성 | 직접 만든 것 | - | ASSET_PROMPTS.md",
        "속도선: CC0에서 카툰 속도선(붓끝 선) 에셋을 찾지 못함 -> 시트 그림 또는 코드 선(14-1 굵기 4~5)",
    ]
    for j, t in enumerate(table):
        d.text((10, H * len(rows) + 20 + j * 34), t, font=SMALL, fill=INK)
    sheet.save(OUT / "effects_compare.png")


def motion():
    for sheet, counts, seqs in ((SLIDE, [6, 3], {"ground": [1, 2, 3, 4, 5, 6], "air": [7, 8, 9, 3, 4, 5, 6]}),
                                (HIT, [5], None)):
        print("\n".join(ca.frames(sheet, OUT, counts, seqs)))


if __name__ == "__main__":
    hero_compare()
    motion()
    if len(sys.argv) > 1:
        effects_compare(sys.argv[1])
