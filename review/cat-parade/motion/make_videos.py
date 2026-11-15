"""아기 움직임 A·B 비교 영상 (캡처 프레임 motion_<a|b>_<장면>_<real|slow>_f000_pc.png → mp4·GIF·필름 시트).
사용: python3 review/cat-parade/motion/make_videos.py <캡처 폴더> [출력 폴더 = review/cat-parade/motion]
- real: 4 step(1/30초)마다 찍음 → 30장/초 = 실제 속도. slow: 2 step마다 → 15장/초로 묶어 4배 느리게.
- 주인공 + 치즈 아기가 있는 부분(BOX)만 잘라 크게. ab_<장면>_<속도>.mp4 = A(위)·B(아래) 나란히.
- mp4는 H.264(-preset veryfast), GIF는 느린 것만 3MB 이하(넘으면 폭을 줄임), strip_*.jpg·close_*.jpg = 검토자용 프레임 늘어놓기.
- 저장소에는 ab_*.mp4·*_slow.gif만 올림 (a_·b_ 따로 mp4와 필름 시트는 검토용 중간 산출물).
"""
import subprocess
import sys
from pathlib import Path

from PIL import Image

BOX = (60, 240, 540, 510)   # 창 1280x720에서 주인공(화면 x 340)과 아기(약 180)가 들어가는 부분 (점프 꼭대기 포함)
CLOSE = (110, 350, 300, 455)  # 평지 장면 아기만 크게 (다리·발 보기)
FPS = {"real": 30, "slow": 15}
LIMIT = 3 * 1024 * 1024


def frames(src: Path, name: str) -> list:
    return sorted(src.glob(f"{name}_f[0-9][0-9][0-9]_pc.png"))


def mp4(files: list, fps: int, out: Path, width: int = 960) -> None:
    pattern = str(files[0]).replace("f000_pc.png", "f%03d_pc.png")  # 찍은 장을 그대로 한 장씩 (빠지거나 겹치는 장 없이)
    x, y, x2, y2 = BOX
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps), "-i", pattern,
                    "-vf", f"crop={x2 - x}:{y2 - y}:{x}:{y},scale={width}:-2:flags=lanczos",
                    "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p", "-r", str(fps), str(out)], check=True)


def stack(top: Path, bottom: Path, out: Path) -> None:
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(top), "-i", str(bottom), "-filter_complex",
                    "[0:v][1:v]vstack=inputs=2", "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p", str(out)], check=True)


def gif(files: list, fps: int, out: Path) -> None:
    """3MB 안에 들 때까지 폭을 줄이고, 그래도 크면 두 장에 한 장만 (한 장을 두 배로 보여 같은 4배 느림)."""
    for width, step in ((560, 1), (480, 1), (480, 2), (400, 2), (320, 2)):
        h = width * (BOX[3] - BOX[1]) // (BOX[2] - BOX[0])
        imgs = [Image.open(f).convert("RGB").crop(BOX).resize((width, h), Image.LANCZOS) for f in files[::step]]
        pal = imgs[len(imgs) // 2].quantize(colors=128, method=Image.Quantize.MEDIANCUT)
        imgs = [i.quantize(palette=pal, dither=Image.Dither.NONE) for i in imgs]
        imgs[0].save(out, save_all=True, append_images=imgs[1:], duration=round(1000 * step / fps), loop=0, optimize=True)
        if out.stat().st_size <= LIMIT:
            return


def strip(files: list, out: Path, cols: int = 6, w: int = 320, box: tuple = BOX) -> None:
    h = w * (box[3] - box[1]) // (box[2] - box[0])
    sheet = Image.new("RGB", (cols * w, -(-len(files) // cols) * h), "white")
    for i, f in enumerate(files):
        sheet.paste(Image.open(f).convert("RGB").crop(box).resize((w, h), Image.LANCZOS), ((i % cols) * w, (i // cols) * h))
    sheet.save(out, quality=85)


def main(src: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    for scene in ("flat", "gap", "flee", "meet"):
        for speed in ("real", "slow"):
            made = []
            for m in ("a", "b"):
                files = frames(src, f"motion_{m}_{scene}_{speed}")
                if not files:
                    continue
                path = out / f"{m}_{scene}_{speed}.mp4"
                mp4(files, FPS[speed], path)
                made.append(path)
                if speed == "slow":
                    gif(files, FPS[speed], out / f"{m}_{scene}_slow.gif")
                    strip(files[::2], out / f"strip_{m}_{scene}.jpg")
                    if scene == "flat":  # 한 걸음씩: 4배 느린 프레임 처음 1초 (게임 0.25초)
                        strip(files[:24], out / f"close_{m}_flat.jpg", cols=6, w=380, box=CLOSE)
                elif scene == "meet":
                    strip(files, out / f"strip_{m}_{scene}.jpg")
            if len(made) == 2:
                stack(made[0], made[1], out / f"ab_{scene}_{speed}.mp4")
    for f in sorted(out.glob("*.mp4")) + sorted(out.glob("*.gif")):
        print(f"{f.name}: {f.stat().st_size / 1024 / 1024:.2f}MB")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).parent)
