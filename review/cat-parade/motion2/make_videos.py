"""치즈 아기 A 움직임 고침 영상 (캡처 프레임 motion2_<장면>_<real|slow>_f000_pc.png → mp4).
사용: python3 review/cat-parade/motion2/make_videos.py <캡처 폴더> [출력 폴더 = review/cat-parade/motion2]
- real: 4 step(1/30초)마다 찍음 → 30장/초 = 실제 속도. slow: 2 step마다 → 15장/초로 묶어 4배 느리게.
- 주인공 + 치즈 아기가 있는 부분만 잘라 크게 (트램펄린·평지는 높이 뛰어 위를 더 넉넉히). 찍은 장을 한 장씩 그대로 (빠지거나 겹치는 장 없음).
- strip_<장면>.jpg = 4배 느린 영상의 장을 늘어놓은 것 (검토자용, 저장소에는 안 올림).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "motion"))
import make_videos as mv  # noqa: E402

BOXES = {"flat": (60, 160, 540, 510), "gap": (60, 200, 540, 520), "tramp": (40, 0, 620, 560), "flee": (0, 240, 540, 510)}


def main(src: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    for scene, box in BOXES.items():
        mv.BOX = box
        for speed in ("real", "slow"):
            files = mv.frames(src, f"motion2_{scene}_{speed}")
            if files:
                mv.mp4(files, mv.FPS[speed], out / f"{scene}_{speed}.mp4")
        slow = mv.frames(src, f"motion2_{scene}_slow")
        if slow:
            mv.strip(slow, src / f"strip_{scene}.jpg", cols=8, w=300, box=box)


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).parent)
