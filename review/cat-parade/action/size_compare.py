"""아기 크기 비교 그림 (2026-11-19): qa_web.mjs parade_size가 찍은 size_<번호>_<pc|phone>.png를 나란히 붙인다.
사용: python3 review/cat-parade/action/size_compare.py <찍은 폴더>
→ review/cat-parade/action/size_compare_pc.png, size_compare_phone.png (폰은 아래 줄에 무리 2배 확대)
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
FONT = ImageFont.truetype(str(HERE / "../../../assets/fonts/jua/Jua-Regular.ttf"), 26)
NAMES = ["작게 0.28배", "중간 0.36배 (기본)", "지금 0.46배"]  # Balance.KITTEN_SIZES 차례
# 잘라 낼 칸 (무리 + 주인공), 폰은 무리만 2배로 한 줄 더
CROPS = {"pc": (0, 150, 560, 500), "phone": (0, 62, 380, 260)}
ZOOM = (35, 100, 145, 215)


def main(src: Path) -> None:
    for size, box in CROPS.items():
        rows = [[Image.open(src / f"size_{i}_{size}.png").convert("RGB").crop(box) for i in range(3)]]
        if size == "phone":
            w, h = ZOOM[2] - ZOOM[0], ZOOM[3] - ZOOM[1]
            rows.append([Image.open(src / f"size_{i}_phone.png").convert("RGB").crop(ZOOM).resize((w * 2, h * 2), Image.NEAREST) for i in range(3)])
        cw = max(im.width for row in rows for im in row)
        out = Image.new("RGB", (cw * 3 + 20, 40 + sum(row[0].height + 10 for row in rows)), "white")
        draw = ImageDraw.Draw(out)
        y = 40
        for i, name in enumerate(NAMES):
            draw.text((i * (cw + 10) + 8, 6), name, font=FONT, fill=(90, 60, 40))
        for row in rows:
            for i, im in enumerate(row):
                out.paste(im, (i * (cw + 10), y))
            y += row[0].height + 10
        out.save(HERE / f"size_compare_{size}.png", optimize=True)
        print(HERE / f"size_compare_{size}.png")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
