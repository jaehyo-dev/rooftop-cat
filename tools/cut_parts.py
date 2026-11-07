"""부품 시트(마젠타 단색 배경)에서 배경을 지우고 부품을 하나씩 잘라 PNG로 저장한다.

사용: python3 tools/cut_parts.py assets/raw/cat_parts_sheet.png assets/sprites/cat_parts head body tail front_leg front_leg_back back_leg back_leg_back
- 부품 이름은 "위 줄 왼쪽→오른쪽, 그다음 아래 줄 왼쪽→오른쪽" 순서로 준다.
- 배경 제거: 마젠타 우세도 min(R, B) - G로 투명도를 정하고, 반투명 가장자리에서 마젠타 색을 빼서 테두리에 분홍 기가 남지 않게 한다
  (rembg는 닫힌 틈에 배경을 남기거나 밝은 몸을 반투명하게 만들 수 있어 단색 면 그림에는 이 방법이 더 깨끗하다).
개발용 도구 (numpy, scipy, Pillow 필요). 게임은 결과 PNG만 쓴다.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

MAGENTA = np.array([255.0, 0.0, 255.0])
KEY_LOW = 40.0    # 우세도가 이 값 이하면 완전히 불투명 (고양이 색)
KEY_HIGH = 200.0  # 이 값 이상이면 완전히 투명 (배경)
PADDING = 6       # 잘라낸 부품 둘레 여백 (픽셀)


def remove_magenta(rgb: np.ndarray) -> np.ndarray:
    """RGB(높이, 너비, 3) → 배경을 지운 RGBA (0~255 uint8)."""
    rgb = rgb.astype(np.float64)
    dominance = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]
    alpha = 1.0 - np.clip((dominance - KEY_LOW) / (KEY_HIGH - KEY_LOW), 0.0, 1.0)
    # 반투명 가장자리: 보이는 색 = a x 원래 색 + (1 - a) x 마젠타 → 원래 색을 되돌린다
    safe = np.maximum(alpha, 1e-3)[..., None]
    color = np.clip((rgb - (1.0 - alpha[..., None]) * MAGENTA) / safe, 0.0, 255.0)
    color[alpha == 0.0] = 0.0
    return np.dstack([color, alpha * 255.0]).round().astype(np.uint8)


def find_parts(rgba: np.ndarray, count: int) -> list:
    """가장 큰 부품 count개의 (위, 아래, 왼쪽, 오른쪽) 범위를 "위 줄 → 아래 줄, 각 줄은 왼쪽 → 오른쪽" 순서로 돌려준다."""
    labels, found = ndimage.label(rgba[..., 3] > 128)
    if found < count:
        raise ValueError(f"부품이 {count}개 필요한데 {found}개만 찾음")
    sizes = ndimage.sum(np.ones_like(labels), labels, range(1, found + 1))
    biggest = np.argsort(sizes)[::-1][:count] + 1
    boxes = []
    for label in biggest:
        rows, cols = ndimage.find_objects((labels == label).astype(int))[0]
        boxes.append((rows.start, rows.stop, cols.start, cols.stop))
    # 위아래 가운데가 첫 부품 높이의 절반 안이면 같은 줄로 본다
    boxes.sort(key=lambda b: (b[0] + b[1]) / 2)
    lines = []
    for box in boxes:
        middle = (box[0] + box[1]) / 2
        if lines and abs(middle - lines[-1][0]) < (box[1] - box[0]) / 2:
            lines[-1][1].append(box)
        else:
            lines.append([middle, [box]])
    return [box for _, line in lines for box in sorted(line, key=lambda b: b[2])]


def cut(sheet: Path, out_dir: Path, names: list) -> list:
    rgba = remove_magenta(np.asarray(Image.open(sheet).convert("RGB")))
    out_dir.mkdir(parents=True, exist_ok=True)
    saved = []
    height, width = rgba.shape[:2]
    for name, (top, bottom, left, right) in zip(names, find_parts(rgba, len(names))):
        top, left = max(0, top - PADDING), max(0, left - PADDING)
        bottom, right = min(height, bottom + PADDING), min(width, right + PADDING)
        path = out_dir / f"{name}.png"
        Image.fromarray(rgba[top:bottom, left:right]).save(path)
        saved.append((path, (left, top, right - left, bottom - top)))
    return saved


if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    for path, rect in cut(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3:]):
        print(path, "시트 안 위치(x, y, 너비, 높이) =", rect)
