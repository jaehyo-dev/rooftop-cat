"""2c-juice 검수 그림 정리 (qa_web.mjs가 찍은 원본 폴더 → review/v0.7.0/2c-juice/).
- shots/<화면>_<look>_<pc|phone>.png : 전체 화면 (256색으로 줄여 저장소 크기를 줄임, 글자 판독 확인)
- shots/zoom/<화면>_<look>_<size>_NN.png : 글자가 든 칸 2배 조각 (같은 그림은 하나만)
- compare/<화면>_<size>.png : 지금 | A | B 나란히
- gif/<이름>.gif : 연출 GIF (3MB 넘으면 크기를 줄여 다시)
사용: python3 review/v0.7.0/2c-juice/make_review.py <원본 폴더>
"""
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
LOOKS = [("old", "지금"), ("a", "A 깔끔한 종이"), ("b", "B 거의 평면")]
GIF_MAX = 3_000_000  # 3MB (10진, 넉넉히 엄격하게)
SLOW = 0.12  # tools/qa_web.gd SLOW: GIF는 느리게 찍었으니 시간을 곱해 실제 빠르기로


def small(img: Image.Image) -> Image.Image:
    return img.convert("RGB").quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)


def shots(src: Path) -> None:
    out = HERE / "shots"
    (out / "zoom").mkdir(parents=True, exist_ok=True)
    seen = set()
    for cells_file in sorted(src.glob("cells_*.json")):
        for name, cells in json.loads(cells_file.read_text()).items():
            img = Image.open(src / f"{name}.png").convert("RGB")
            small(img).save(out / f"{name}.png", optimize=True)
            for i, (x, y, w, h) in enumerate(cells):
                piece = img.crop((x, y, x + w, y + h)).resize((w * 2, h * 2), Image.LANCZOS)
                digest = hashlib.md5(piece.tobytes()).hexdigest()
                if digest in seen:
                    continue
                seen.add(digest)
                small(piece).save(out / "zoom" / f"{name}_{i:02d}.png", optimize=True)


def compare(src: Path) -> None:
    out = HERE / "compare"
    out.mkdir(exist_ok=True)
    font = ImageFont.truetype(str(HERE.parents[2] / "assets/fonts/gaegu/Gaegu-Bold.ttf"), 34)
    names = sorted({p.stem.rsplit("_", 2)[0] for p in src.glob("*_a_pc.png")})
    for name in names:
        for size in ("pc", "phone"):
            imgs = [Image.open(src / f"{name}_{look}_{size}.png").convert("RGB") for look, _ in LOOKS
                    if (src / f"{name}_{look}_{size}.png").exists()]
            if len(imgs) < 3:
                continue
            k = 0.5 if size == "pc" else 0.76  # 한 장 640 넓이
            w, h = int(imgs[0].width * k), int(imgs[0].height * k)
            sheet = Image.new("RGB", (w * 3 + 40, h + 56), (250, 244, 232))
            draw = ImageDraw.Draw(sheet)
            for i, img in enumerate(imgs):
                sheet.paste(img.resize((w, h), Image.LANCZOS), (10 + i * (w + 10), 50))
                draw.text((14 + i * (w + 10), 6), LOOKS[i][1], fill=(90, 70, 54), font=font)
            small(sheet).save(out / f"{name}_{size}.png", optimize=True)


def gifs(src: Path) -> None:
    out = HERE / "gif"
    out.mkdir(exist_ok=True)
    for folder in sorted((src / "gif").iterdir()):
        times = json.loads((folder / "times.json").read_text())
        frames = sorted(folder.glob("f*.png"))[:len(times)]
        # 3MB 안에 들 때까지: 넓이를 줄이고, 그래도 크면 한 장 걸러 (건너뛴 시간은 앞 장에 더함)
        for width, step in ((720, 1), (600, 1), (480, 1), (480, 2), (400, 2), (400, 3)):
            pics, durations = [], []
            for i in range(0, len(frames), step):
                img = Image.open(frames[i]).convert("RGB")
                pics.append(small(img.resize((width, img.height * width // img.width), Image.LANCZOS)))
                end = times[i + step] if i + step < len(times) else times[-1] + 600
                durations.append(max(20, int((end - times[i]) * SLOW)))
            path = out / f"{folder.name}.gif"
            pics[0].save(path, save_all=True, append_images=pics[1:], duration=durations, loop=0, optimize=True)
            if path.stat().st_size <= GIF_MAX:
                break
        print(path.name, len(pics), "장", width, "px", "1/%d" % step, round(path.stat().st_size / 1e6, 2), "MB")


if __name__ == "__main__":
    source = Path(sys.argv[1])
    shots(source)
    compare(source)
    if (source / "gif").exists():
        gifs(source)
