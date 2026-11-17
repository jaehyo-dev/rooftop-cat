"""6마리 움직임 마무리 영상 (캡처 프레임 final_<장면>_<real|slow>_f000_pc.png → mp4).
사용: python3 review/cat-parade/final/make_videos.py <캡처 폴더> [출력 폴더 = review/cat-parade/final]
- real: 4 step(1/30초)마다 찍음 → 30장/초 = 실제 속도. slow: 2 step마다 → 15장/초로 묶어 4배 느리게. H.264 -preset veryfast.
- 주인공 + 6마리 줄이 들어가는 부분만 잘라 크게 (트램펄린·더블점프는 높이 뛰어 위까지).
- strip_<장면>.jpg = 4배 느린 영상 장을 늘어놓은 것 (검토자용, 캡처 폴더에 둠, 저장소에는 안 올림).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "motion"))
import make_videos as mv  # noqa: E402

LINE = (0, 140, 760, 640)  # 1280x720 창에서 주인공(화면 x 약 545)과 맨 뒤 아기까지, 카메라 높이가 달라도 발까지
BOXES = {"flat": LINE, "gap": (0, 100, 760, 660), "flip": (0, 0, 760, 660), "tramp": (0, 0, 800, 660),
         "dash": LINE, "flee": LINE, "meet": (0, 140, 1180, 640)}


def main(src: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    for scene, box in BOXES.items():
        mv.BOX = box
        for speed in ("real", "slow"):
            files = mv.frames(src, f"final_{scene}_{speed}")
            if files:
                mv.mp4(files, mv.FPS[speed], out / f"{scene}_{speed}.mp4")
        slow = mv.frames(src, f"final_{scene}_slow")
        if slow:
            mv.strip(slow, src / f"strip_{scene}.jpg", cols=8, w=360, box=box)
    for f in sorted(out.glob("*.mp4")):
        print(f"{f.name}: {f.stat().st_size / 1024 / 1024:.2f}MB")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).parent)
