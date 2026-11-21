"""카툰 주인공 게임 안 영상 (2026-11-21): qa_web.mjs parade_hero가 찍은 장 → mp4.
사용: python3 review/restructure/hero/make_videos.py <찍은 폴더>
- <장면>_real.mp4 (30장/초 = 실제 속도), <장면>_slow.mp4 (게임 1/60초마다 한 장을 15장/초로 = 0.25배): 주인공 둘레 BOX를 960 폭으로
- <장면>_zoom_real.mp4, <장면>_zoom_slow.mp4: 주인공 발끝을 따라 ZOOM 상자를 2배로
- strip_<장면>.jpg: 0.25배 확대 장을 늘어놓은 것 (찍은 폴더에 둠, 저장소에는 안 올림. 장마다 확인용)
장면: flat · jump · double · slide_ground · slide_air · hit · sign · sit
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "cat-parade/motion"))
import make_videos as mv  # noqa: E402  (cat-parade/motion)
import importlib.util  # noqa: E402

spec = importlib.util.spec_from_file_location("alive", Path(__file__).resolve().parents[2] / "cat-parade/action/alive/make_videos.py")
alive = importlib.util.module_from_spec(spec)
spec.loader.exec_module(alive)

HERE = Path(__file__).parent / "video"
SCENES = ["flat", "jump", "double", "slide_ground", "slide_air", "hit", "sign", "sit"]
BOX = (120, 140, 760, 540)


def main(src: Path) -> None:
    HERE.mkdir(exist_ok=True)
    mv.BOX = BOX
    alive.ZOOM = (300, 230)  # 발끝 기준 왼쪽 150·오른쪽 150, 위 190·아래 40 → 2배
    alive.ABOVE = 190
    pos = {}
    for f in src.glob("pos_parade_hero*_pc.json"):
        pos.update(json.loads(f.read_text()))
    for scene in SCENES:
        for speed in ("real", "slow"):
            files = mv.frames(src, f"hero_{scene}_{speed}")
            if not files:
                continue
            mv.mp4(files, mv.FPS[speed], HERE / f"{scene}_{speed}.mp4")
            zoomed = alive.zoom_frames(files, pos, src / "zoom" / f"{scene}_{speed}")
            alive.mp4(zoomed, mv.FPS[speed], HERE / f"{scene}_zoom_{speed}.mp4")
            if speed == "slow":
                mv.strip(zoomed, src / f"strip_{scene}.jpg", cols=8, w=300, box=(0, 0, 600, 460))
    for f in sorted(HERE.glob("*.mp4")):
        print(f"{f.name}: {f.stat().st_size / 1024 / 1024:.2f}MB")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
