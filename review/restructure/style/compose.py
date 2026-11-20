"""화풍 시안 정리: 원본(assets/concept/restructure_style/s<화풍>_<장면>.png)을 게임 크기로 맞추고 비교 그림을 만든다.
사용: python3 review/restructure/style/compose.py"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "assets/concept/restructure_style"
OUT = Path(__file__).parent
FONT = ImageFont.truetype(str(ROOT / "assets/fonts/jua/Jua-Regular.ttf"), 40)
NAMES = {1: "1. 색연필 + 굵은 효과", 2: "2. 색연필 + 굵은 선, 선명한 색", 3: "3. 깔끔한 카툰"}
SIZE = {"A": (1280, 720), "B": (1280, 720), "C": (1280, 640)}  # C는 원본이 2:1 시트


def one(s, sc):
    return Image.open(RAW / f"s{s}_{sc}.png").convert("RGB").resize(SIZE[sc], Image.LANCZOS)


def row(images, label_h=60):
    # 세 장을 가로로 붙이고 위에 화풍 이름
    w, h = images[0].size
    sheet = Image.new("RGB", (w * 3 + 40, h + label_h), (250, 246, 238))
    d = ImageDraw.Draw(sheet)
    for i, im in enumerate(images):
        x = i * (w + 20)
        sheet.paste(im, (x, label_h))
        d.text((x + 10, 8), NAMES[i + 1], font=FONT, fill=(70, 50, 40))
    return sheet


for sc in "ABC":
    ims = [one(s, sc) for s in (1, 2, 3)]
    for s, im in zip((1, 2, 3), ims):
        im.save(OUT / f"{s}_{sc}.jpg", quality=90)
    row(ims).save(OUT / f"compare_{sc}.jpg", quality=88)

# 폰(844x390): 화면 높이에 맞춰 0.54배(693x390), 남는 양옆은 회색(실제 게임은 expand라 배경이 더 보임)
phone = []
for s in (1, 2, 3):
    im = one(s, "A").resize((693, 390), Image.LANCZOS)
    frame = Image.new("RGB", (844, 390), (200, 200, 200))
    frame.paste(im, ((844 - 693) // 2, 0))
    phone.append(frame)
row(phone).save(OUT / "compare_A_phone.jpg", quality=90)
