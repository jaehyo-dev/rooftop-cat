"""v0.7.0 배포 눈 검수 그림 정리 (qa_web.mjs가 찍은 원본 폴더 → review/v0.7.0/release/).
- shots/<화면>_<pc|phone>.png, shots/zoom/ : 2c-polish/make_review.py와 같음 (전체 256색, 글자 칸 2배 조각)
- shots/zoom/hud_run_<size>_top.png : 판 안 HUD 위 띠 2배 (HUD는 메뉴 칸이 아니라 따로 자름)
- compare/<화면>_<size>.png : Gaegu(2c-polish 마지막) | 주아(지금)
사용: python3 review/v0.7.0/release/make_release.py <원본 폴더>
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE.parent / "2c-polish"))
import make_review  # noqa: E402

make_review.HERE = HERE
COMPARE = ["start_normal", "shop_normal_upgrades_fish", "shop_normal_boosters_fish_bonus", "missions_normal", "result_rankup"]


def main(src: Path) -> None:
    make_review.shots(src)
    for size, h in [("pc", 150), ("phone", 90)]:
        img = Image.open(src / f"hud_run_{size}.png").convert("RGB")
        top = img.crop((0, 0, img.width, h))
        make_review.small(top.resize((top.width * 2, h * 2), Image.LANCZOS)).save(HERE / "shots/zoom" / f"hud_run_{size}_top.png", optimize=True)
    out = HERE / "compare"
    out.mkdir(exist_ok=True)
    font = ImageFont.truetype(str(HERE.parents[2] / "assets/fonts/jua/Jua-Regular.ttf"), 30)
    for name in COMPARE:
        for size in ["pc", "phone"]:
            before = HERE.parent / "2c-polish/shots" / f"{name}_{size}.png"
            if not before.exists():
                continue
            imgs = [Image.open(before).convert("RGB"), Image.open(src / f"{name}_{size}.png").convert("RGB")]
            k = 0.5 if size == "pc" else 0.76
            w, h = int(imgs[0].width * k), int(imgs[0].height * k)
            sheet = Image.new("RGB", (w * 2 + 30, h + 50), (250, 244, 232))
            draw = ImageDraw.Draw(sheet)
            for i, img in enumerate(imgs):
                sheet.paste(img.resize((w, h), Image.LANCZOS), (10 + i * (w + 10), 46))
                draw.text((14 + i * (w + 10), 6), ["전: Gaegu (2c-polish)", "후: 주아 (v0.7.0)"][i], fill=(90, 70, 54), font=font)
            make_review.small(sheet).save(out / f"{name}_{size}.png", optimize=True)


if __name__ == "__main__":
    main(Path(sys.argv[1]))
