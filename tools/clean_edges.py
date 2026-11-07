"""스프라이트 가장자리에 남은 분홍·마젠타 잔여물을 안쪽 색으로 덮는다.

사용: python3 tools/clean_edges.py assets/sprites/buildings/*.png assets/sprites/structures/*.png
- 가장자리 = 불투명 픽셀 중 EDGE_DEPTH 픽셀 안에 투명(알파 0) 픽셀이 있는 곳.
- 분홍 기 = 파랑이 초록보다 낮지 않고(b >= g - 5) 빨강이 초록보다 30 이상 큰 색 (크림·갈색·주황은 파랑이 가장 낮아서 걸리지 않음).
- 분홍 기 픽셀은 가장 가까운 '가장자리 밖 안쪽 픽셀'의 색으로 바꾼다. 알파는 그대로.
개발용 도구 (numpy, scipy, Pillow 필요).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

EDGE_DEPTH = 2


def edge_mask(rgba: np.ndarray) -> np.ndarray:
    """투명 픽셀(이미지 밖은 제외)에서 EDGE_DEPTH 픽셀 안에 있는 보이는 픽셀."""
    visible = rgba[..., 3] > 0
    near_clear = ndimage.binary_dilation(~visible, iterations=EDGE_DEPTH)
    return visible & near_clear


def pinkish(rgba: np.ndarray) -> np.ndarray:
    r, g, b = (rgba[..., i].astype(int) for i in range(3))
    return (b >= g - 5) & (r - g >= 30)


def pink_edge(rgba: np.ndarray) -> np.ndarray:
    return edge_mask(rgba) & pinkish(rgba)


def clean(rgba: np.ndarray) -> np.ndarray:
    rgba = rgba.copy()
    bad = pink_edge(rgba)
    # 색을 가져올 곳: 보이고, 가장자리가 아니며, 분홍 기도 아닌 픽셀 (없으면 가장자리 중 분홍 아닌 픽셀)
    good = (rgba[..., 3] > 0) & ~edge_mask(rgba) & ~pinkish(rgba)
    if not good.any():
        good = (rgba[..., 3] > 0) & ~bad
    _, (rows, cols) = ndimage.distance_transform_edt(~good, return_indices=True)
    rgba[bad, :3] = rgba[rows[bad], cols[bad], :3]
    return rgba


if __name__ == "__main__":
    for name in sys.argv[1:]:
        path = Path(name)
        before = np.asarray(Image.open(path).convert("RGBA"))
        count = int(pink_edge(before).sum())
        if count:
            Image.fromarray(clean(before)).save(path)
        print(f"{path.name}: {count}")
