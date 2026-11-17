"""액션 시험판 영상 (캡처 프레임 act_<장면>_<real|slow>_f000_pc.png → mp4).
사용: python3 review/cat-parade/action/make_videos.py <캡처 폴더> [출력 폴더 = review/cat-parade/action]
- real: 4 step(1/30초)마다 찍음 → 30장/초 = 실제 속도. slow: 2 step마다 → 15장/초로 묶어 4배 느리게. H.264 -preset veryfast.
- 화면 전체(1280x720)를 960 폭으로 (HUD 배지·능력 고리도 보이게).
- strip_<장면>.jpg = 4배 느린 영상 장을 늘어놓은 것 (검토자용, 캡처 폴더에 둠, 저장소에는 안 올림).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "motion"))
import make_videos as mv  # noqa: E402

SCENES = ["float_flat", "float_jump", "float_double", "float_flock", "stomp", "punch", "fetch", "sparkle", "hit", "meet",
          "slide_sign", "dive_stomp", "dive_slide"]


def main(src: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    mv.BOX = (0, 0, 1280, 720)
    for scene in SCENES:
        for speed in ("real", "slow"):
            files = mv.frames(src, f"act_{scene}_{speed}")
            if files:
                mv.mp4(files, mv.FPS[speed], out / f"{scene}_{speed}.mp4")
        slow = mv.frames(src, f"act_{scene}_slow")
        if slow:
            mv.strip(slow[::2], src / f"strip_{scene}.jpg", cols=6, w=400, box=mv.BOX)
    for f in sorted(out.glob("*.mp4")):
        print(f"{f.name}: {f.stat().st_size / 1024 / 1024:.2f}MB")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).parent)
