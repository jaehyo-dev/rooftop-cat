"""2c-fix 시작 화면 앉은 고양이: assets/raw/cat_frames_sit.png(3x2 격자) → assets/sprites/cat_frames/sit_*.png

사용: python3 review/v0.7.0/2c-fix/cut_sit.py
- 칸 순서: 1 앉음(머리 방향이 달라 안 씀), 2 꼬리 조금 → sit_0, 3 꼬리 위 → sit_1, 4 꼬리 아래 → sit_2, 5 눈 감음 → sit_blink, 6 일어남 → sit_up
- 배율: tools/align_frames.py와 같은 방법(앉은 4장의 불투명 넓이 가운데값이 기준 그림 넓이와 같게) x HEAD_MATCH.
  웅크려 앉은 몸은 넓이가 작아 그대로 맞추면 머리가 달리기 프레임보다 커진다 (머리 폭 run_0 125px : 앉음 160px, 눈으로 잼)
- 위치: 앉은 4장은 꼬리만 다르므로 몸 중심이 아니라 오른쪽 끝(얼굴·가슴)과 발끝을 같은 자리에 둔다 (꼬리를 흔들어도 몸이 안 떨리게).
  가로 자리는 sit_0의 몸 중심이 다른 프레임처럼 ANCHOR_X에 오게 정하고 나머지도 같은 오른쪽 끝을 쓴다. 일어남은 달리기처럼 몸 중심.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
from align_frames import CANVAS, BASELINE, ANCHOR_X, OUT_SCALE, area, opaque, body_center_x, place  # noqa: E402
from cut_parts import remove_magenta  # noqa: E402
from cut_buildings import despill  # noqa: E402
from clean_edges import clean  # noqa: E402

OUT = ROOT / "assets/sprites/cat_frames"
CELLS = {1: "sit_0", 2: "sit_1", 3: "sit_2", 4: "sit_blink", 5: "sit_up"}  # 칸 번호(0부터) → 이름
PAD = 6
HEAD_MATCH = 0.78  # 머리 크기를 달리기 프레임과 맞춤


def cells(path: Path) -> list:
    rgba = despill(remove_magenta(np.asarray(Image.open(path).convert("RGB"))))
    h, w = rgba.shape[:2]
    out = []
    for i in range(6):
        r, c = divmod(i, 3)
        cell = rgba[r * h // 2:(r + 1) * h // 2, c * w // 3:(c + 1) * w // 3]
        ys, xs = np.nonzero(cell[..., 3] > 16)
        assert ys.min() > 0 and xs.min() > 0 and ys.max() < cell.shape[0] - 1 and xs.max() < cell.shape[1] - 1, f"칸 {i} 고양이가 칸 경계에 닿음"
        part = cell[ys.min() - PAD:ys.max() + PAD + 1, xs.min() - PAD:xs.max() + PAD + 1]
        out.append(Image.fromarray(part.copy()))
    return out


def place_right(image: Image.Image, scale: float, right: int) -> Image.Image:
    small = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    mask = opaque(small)
    rows = np.nonzero(mask.any(axis=1))[0]
    cols = np.nonzero(mask.any(axis=0))[0]
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    canvas.paste(small, (right - (cols[-1] + 1), BASELINE - (rows[-1] + 1)))
    assert area(canvas) >= area(small) * 0.995, "캔버스 밖으로 나감"
    return canvas


def save(image: Image.Image, name: str) -> None:
    path = OUT / f"{name}.png"
    Image.fromarray(clean(np.asarray(image))).save(path)
    print(path.relative_to(ROOT))


if __name__ == "__main__":
    parts = cells(ROOT / "assets/raw/cat_frames_sit.png")
    ref_area = area(Image.open(ROOT / "assets/sprites/cat_base_run.png").convert("RGBA"))
    sitting = [parts[i] for i in (1, 2, 3, 4)]
    scale = (ref_area / float(np.median([area(i) for i in sitting]))) ** 0.5 * OUT_SCALE * HEAD_MATCH
    # sit_0의 몸 중심이 ANCHOR_X에 오는 오른쪽 끝을 모든 앉은 프레임에 씀
    first = place(parts[1], scale)
    right = int(np.nonzero(opaque(first).any(axis=0))[0][-1]) + 1
    for i in (1, 2, 3, 4):
        save(place_right(parts[i], scale, right), CELLS[i])
    save(place(parts[5], scale), CELLS[5])
    print("배율 %.3f, 오른쪽 끝 %d, sit_0 몸 중심 %.0f" % (scale, right, body_center_x(opaque(first))))
