"""아기 배치 확인 자료 (2026-11-19): qa_web.mjs parade_form-<chain|fairy>·parade_formstill이 찍은 장 → 영상·정지 화면·2배 확대 조각.
사용: python3 review/cat-parade/action/formation/make_videos.py <찍은 폴더>
- <방식>_<장면>_real.mp4 (30장/초 = 실제 속도), <방식>_<장면>_slow.mp4 (게임 1/60초마다 한 장을 15장/초로 = 0.25배)
  방식: chain = 줄줄이(기본), fairy = 요정 무리. 화면 왼쪽 위(생선 수)부터 주인공까지 잘라 960 폭으로.
- <방식>_6_<pc|phone>.png = 6마리 정지 화면 전체, <방식>_6_<pc|phone>_zoom.png = 아기 부분 2배
- strip_<방식>_<장면>.jpg = 0.25배 영상 장을 늘어놓은 것 (프레임 확인용, 찍은 폴더에 둠, 저장소에는 안 올림)
"""
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "motion"))
import make_videos as mv  # noqa: E402

HERE = Path(__file__).parent
MODES = ["chain", "fairy"]
SCENES = ["flat", "jump", "double", "slide", "hit", "meet"]
BOX = (0, 0, 720, 520)  # 창 1280x720: 생선 수·아기·주인공·앞 조금 (점프 꼭대기 포함)
ZOOM = {"pc": (0, 150, 330, 480), "phone": (0, 80, 180, 260)}  # 아기 부분 (폰 844x390은 0.54배로 그려짐)


def main(src: Path) -> None:
    mv.BOX = BOX
    for mode in MODES:
        for scene in SCENES:
            for speed in ("real", "slow"):
                files = mv.frames(src, f"form_{mode}_{scene}_{speed}")
                if files:
                    mv.mp4(files, mv.FPS[speed], HERE / f"{mode}_{scene}_{speed}.mp4")
            slow = mv.frames(src, f"form_{mode}_{scene}_slow")
            if slow:
                mv.strip(slow[::2], src / f"strip_{mode}_{scene}.jpg", cols=6, w=360, box=BOX)
        for size, box in ZOOM.items():
            still = src / f"form_{mode}_still_{size}.png"
            if not still.exists():
                continue
            im = Image.open(still).convert("RGB")
            im.save(HERE / f"{mode}_6_{size}.png", optimize=True)
            crop = im.crop(box)
            crop.resize((crop.width * 2, crop.height * 2), Image.LANCZOS).save(HERE / f"{mode}_6_{size}_zoom.png", optimize=True)
    for f in sorted(HERE.glob("*.mp4")):
        print(f"{f.name}: {f.stat().st_size / 1024 / 1024:.2f}MB")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
