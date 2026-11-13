"""글꼴 비교 그림 합치기: font_web.mjs가 찍은 <글꼴>_<size>/ 캡처를 화면마다 2x2(4칸)로 붙이고,
HUD·큰 점수 조각과 폰 보조 글자 2배 조각을 만든다.
사용: python3 compose.py <캡처 폴더> <출력 폴더>"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

FONTS = [("gaegu", "지금: Gaegu Bold"), ("nsr", "나눔스퀘어라운드 EB/B/R"), ("jua", "주아 Jua"), ("gowun", "고운돋움 Gowun Dodum")]
SCREENS = [("1_start", "시작 화면"), ("2_shop", "상점 강화 탭"), ("3_missions", "미션"), ("4_result", "결과 카드"), ("5_hud", "판 안 HUD")]
LABEL = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 26)
BG, INK = (40, 34, 30), (255, 244, 224)


def tag(img: Image.Image, text: str) -> Image.Image:
    """그림 위에 이름 띠를 붙임"""
    out = Image.new("RGB", (img.width, img.height + 40), BG)
    out.paste(img.convert("RGB"), (0, 40))
    ImageDraw.Draw(out).text((10, 4), text, font=LABEL, fill=INK)
    return out


def grid(tiles: list, cols: int, gap: int = 8) -> Image.Image:
    w, h = max(t.width for t in tiles), max(t.height for t in tiles)
    rows = (len(tiles) + cols - 1) // cols
    out = Image.new("RGB", (cols * w + (cols - 1) * gap, rows * h + (rows - 1) * gap), BG)
    for i, t in enumerate(tiles):
        out.paste(t, ((i % cols) * (w + gap), (i // cols) * (h + gap)))
    return out


def pick(rects: list, n: int = 6) -> list:
    """보조 크기 칸 중 경험치(숫자/숫자) 먼저, 그다음 글이 긴 것 n개 (같은 글은 하나만, 한글 우선), 화면 순서대로"""
    seen, uniq = set(), []
    for i, r in enumerate(rects):
        if r[4] not in seen and r[2] > 2 and r[3] > 2:
            seen.add(r[4])
            uniq.append((i, r))
    best = sorted(uniq, key=lambda t: ("/" in t[1][4], any("가" <= c <= "힣" for c in t[1][4]), len(t[1][4])), reverse=True)[:n]
    return [r for _, r in sorted(best)]


def main(src: Path, dst: Path, crops: dict) -> None:
    dst.mkdir(parents=True, exist_ok=True)
    for size in ["pc", "phone"]:
        for key, title in SCREENS:
            tiles = [tag(Image.open(src / f"{f}_{size}" / f"{key}.png"), f"{name} - {title} ({size})") for f, name in FONTS]
            grid(tiles, 2).save(dst / f"{key}_{size}.png", optimize=True)
    # 조각: crops = {이름: [화면, size, x, y, w, h, 배율]}
    for name, (key, size, x, y, w, h, k) in crops.items():
        tiles = [tag(Image.open(src / f"{f}_{size}" / f"{key}.png").crop((x, y, x + w, y + h)).resize((w * k, h * k), Image.LANCZOS), n) for f, n in FONTS]
        grid(tiles, 1).save(dst / f"{name}.png", optimize=True)
    # 폰 보조 크기 글자 2배: 화면마다 작은 글자 칸을 글꼴별로 (같은 순서의 칸끼리 한 줄)
    for key, title in SCREENS[:4]:  # HUD엔 보조 크기 글자가 버전 표시뿐
        per_font = []
        for f, n in FONTS:
            rects = pick(json.loads((src / f"{f}_phone" / "small.json").read_text()).get(key) or [])
            img = Image.open(src / f"{f}_phone" / f"{key}.png")
            parts = [img.crop((r[0] - 6, r[1] - 6, r[0] + r[2] + 6, r[1] + r[3] + 6)) for r in rects]
            if not parts:
                continue
            row_w = sum(p.width for p in parts) + 10 * (len(parts) - 1)
            row = Image.new("RGB", (row_w, max(p.height for p in parts)), BG)
            x = 0
            for p in parts:
                row.paste(p.convert("RGB"), (x, 0))
                x += p.width + 10
            per_font.append(tag(row.resize((row.width * 2, row.height * 2), Image.LANCZOS), f"{n} - {title} 보조 크기 2배 (폰)"))
        if per_font:
            grid(per_font, 1).save(dst / f"7_small_{key}_phone.png", optimize=True)


if __name__ == "__main__":
    crops = json.loads(Path(sys.argv[3]).read_text()) if len(sys.argv) > 3 else {}
    main(Path(sys.argv[1]), Path(sys.argv[2]), crops)
