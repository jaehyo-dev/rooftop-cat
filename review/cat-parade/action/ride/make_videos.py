"""구름 타기 확인 영상 (2026-11-20): qa_web.mjs parade_ride가 찍은 장 → 영상.
사용: python3 review/cat-parade/action/ride/make_videos.py <찍은 폴더>
- compare_<장면>_<6|1>_<real|slow>.mp4: 위 = 예전(구름 방석에 앉기), 아래 = 새(구름 타기). 생선 수부터 주인공 앞까지 (창 x 0~800, y 40~520)
  6 = 치즈냥이 맨 앞인 6마리 (다른 5마리는 아직 예전 그림), 1 = 치즈냥 한 마리
- zoom_<장면>_<real|slow>.mp4: 새 방식 6마리의 치즈냥 둘레 2배 (기록한 발끝 자리를 따라 자름)
- strip_<...>.jpg: 0.25배 장을 늘어놓은 것 (프레임 확인용, 찍은 폴더에 둠, 저장소에는 안 올림)
실제 속도 = 30장/초, 0.25배 = 게임 1/60초마다 한 장을 15장/초로.
"""
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).parent
SCENES = ["flat", "jump", "double", "slide", "hit"]
FPS = {"real": 30, "slow": 15}
BOX = (0, 40, 800, 520)
ZOOM = (180, 110)   # 확대 상자 (창 픽셀): 발끝 기준 왼쪽 110·오른쪽 70, 위 75·아래 35 → 2배
ABOVE = 75
LEFT = 110
SMOOTH = 0.35
FONT = ImageFont.truetype(str(ROOT / "assets/fonts/jua/Jua-Regular.ttf"), 26)


def frames(src: Path, name: str) -> list:
    return sorted(src.glob(f"{name}_f*_pc.png"))


def encode(dir_: Path, fps: int, out: Path) -> None:
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps), "-i", str(dir_ / "%03d.png"),
                    "-c:v", "libx264", "-preset", "veryfast", "-crf", "26", "-pix_fmt", "yuv420p", str(out)], check=True)


def label(im: Image.Image, text: str) -> None:
    d = ImageDraw.Draw(im)
    d.text((620, 8), text, font=FONT, fill=(90, 50, 30), stroke_width=4, stroke_fill=(255, 250, 240))


def compare(src: Path, n: int, scene: str, speed: str) -> Path | None:
    old, new = frames(src, f"ride_old_{n}_{scene}_{speed}"), frames(src, f"ride_new_{n}_{scene}_{speed}")
    if not old or not new:
        return None
    tmp = src / "cmp" / f"{n}_{scene}_{speed}"
    tmp.mkdir(parents=True, exist_ok=True)
    w, h = BOX[2] - BOX[0], BOX[3] - BOX[1]
    for k, (a, b) in enumerate(zip(old, new)):
        im = Image.new("RGB", (w, h * 2 + 4), (60, 60, 60))
        top, bottom = Image.open(a).convert("RGB").crop(BOX), Image.open(b).convert("RGB").crop(BOX)
        label(top, "예전 (앉기)")
        label(bottom, "새 (구름 타기)")
        im.paste(top, (0, 0))
        im.paste(bottom, (0, h + 4))
        im.save(tmp / f"{k:03d}.png")
    out = HERE / f"compare_{scene}_{n}_{speed}.mp4"
    encode(tmp, FPS[speed], out)
    return tmp


def zoom(src: Path, pos: dict, scene: str, speed: str) -> Path | None:
    files = frames(src, f"ride_new_6_{scene}_{speed}")
    if not files:
        return None
    tmp = src / "zoom" / f"{scene}_{speed}"
    tmp.mkdir(parents=True, exist_ok=True)
    at = None
    for k, f in enumerate(files):
        p = pos.get(f.stem)
        if p:
            at = p if at is None else [at[0] + (p[0] - at[0]) * SMOOTH, at[1] + (p[1] - at[1]) * SMOOTH]
        x, y = round(at[0] - LEFT), round(at[1] - ABOVE)
        im = Image.open(f).convert("RGB").crop((x, y, x + ZOOM[0], y + ZOOM[1]))
        im.resize((ZOOM[0] * 2, ZOOM[1] * 2), Image.LANCZOS).save(tmp / f"{k:03d}.png")
    encode(tmp, FPS[speed], HERE / f"zoom_{scene}_{speed}.mp4")
    return tmp


def strip(dir_: Path, out: Path, every: int = 2, cols: int = 8, w: int = 360) -> None:
    files = sorted(dir_.glob("*.png"))[::every]
    first = Image.open(files[0])
    h = round(first.height * w / first.width)
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w, rows * h), (40, 40, 40))
    for k, f in enumerate(files):
        sheet.paste(Image.open(f).resize((w, h), Image.LANCZOS), ((k % cols) * w, (k // cols) * h))
    sheet.save(out, quality=85)


def main(src: Path) -> None:
    pos = {}
    for f in src.glob("pos_parade_ride*_pc.json"):
        pos.update(json.loads(f.read_text()))
    for scene in SCENES:
        for speed in FPS:
            for n in (6, 1):
                tmp = compare(src, n, scene, speed)
                if tmp and speed == "slow":
                    strip(tmp, src / f"strip_cmp_{scene}_{n}.jpg")
            tmp = zoom(src, pos, scene, speed)
            if tmp and speed == "slow":
                strip(tmp, src / f"strip_zoom_{scene}.jpg", every=1, cols=10, w=360)
    for f in sorted(HERE.glob("*.mp4")):
        print(f"{f.name}: {f.stat().st_size / 1024 / 1024:.2f}MB")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
