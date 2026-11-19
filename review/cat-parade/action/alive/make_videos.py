"""아기 살아 움직이기 확인 영상 (2026-11-19): qa_web.mjs parade_alive가 찍은 장 → 영상.
사용: python3 review/cat-parade/action/alive/make_videos.py <찍은 폴더>
- <장면>_real.mp4 (30장/초 = 실제 속도), <장면>_slow.mp4 (게임 1/60초마다 한 장을 15장/초로 = 0.25배): 생선 수부터 주인공 앞까지 960 폭
- <장면>_zoom_real.mp4, <장면>_zoom_slow.mp4: 맨 앞 치즈냥 둘레를 2배로 (pos_parade_alive_pc.json의 발끝 자리를 따라 자름)
- strip_<장면>.jpg: 0.25배 확대 장을 늘어놓은 것 (프레임 확인용, 찍은 폴더에 둠, 저장소에는 안 올림)
장면: flat 평지 10초(0.25배는 앞 4초) · jump · double · slide · stomp · hit · cloud(하늘 구름 앞 점프)
"""
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "motion"))
import make_videos as mv  # noqa: E402

HERE = Path(__file__).parent
SCENES = ["flat", "jump", "double", "slide", "stomp", "hit", "cloud"]
BOX = (0, 0, 720, 520)
ZOOM = (150, 120)   # 확대 상자 (창 픽셀): 발끝 기준 왼쪽 75·오른쪽 75, 위 95·아래 25 → 2배
ABOVE = 95
SMOOTH = 0.35       # 상자가 발끝을 따라가는 정도 (장마다, 상자가 덜덜 떨지 않게)


def zoom_frames(files: list, pos: dict, out_dir: Path) -> list:
    out_dir.mkdir(parents=True, exist_ok=True)
    at = None
    made = []
    for f in files:
        p = pos.get(f.stem)
        if p:
            at = p if at is None else [at[0] + (p[0] - at[0]) * SMOOTH, at[1] + (p[1] - at[1]) * SMOOTH]
        x, y = round(at[0] - ZOOM[0] / 2), round(at[1] - ABOVE)
        im = Image.open(f).convert("RGB").crop((x, y, x + ZOOM[0], y + ZOOM[1]))
        dst = out_dir / f.name
        im.resize((ZOOM[0] * 2, ZOOM[1] * 2), Image.LANCZOS).save(dst)
        made.append(dst)
    return made


def mp4(files: list, fps: int, out: Path) -> None:
    pattern = str(files[0]).replace("f000_pc.png", "f%03d_pc.png")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps), "-i", pattern,
                    "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p", "-r", str(fps), str(out)], check=True)


def main(src: Path) -> None:
    mv.BOX = BOX
    pos = {}  # 장면을 나눠 찍으면 (parade_alive-slide-cloud 등) 기록 파일도 나뉨
    for f in src.glob("pos_parade_alive*_pc.json"):
        pos.update(json.loads(f.read_text()))
    for scene in SCENES:
        for speed in ("real", "slow"):
            files = mv.frames(src, f"alive_{scene}_{speed}")
            if not files:
                continue
            mv.mp4(files, mv.FPS[speed], HERE / f"{scene}_{speed}.mp4")
            zoomed = zoom_frames(files, pos, src / "zoom")
            mp4(zoomed, mv.FPS[speed], HERE / f"{scene}_zoom_{speed}.mp4")
            if speed == "slow":
                mv.strip(zoomed, src / f"strip_{scene}.jpg", cols=10, w=ZOOM[0] * 2, box=(0, 0, ZOOM[0] * 2, ZOOM[1] * 2))
    for f in sorted(HERE.glob("*.mp4")):
        print(f"{f.name}: {f.stat().st_size / 1024 / 1024:.2f}MB")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
