"""안개 띠 그림의 색을 크림색 쪽으로 섞어 새 파일로 저장한다 (투명도는 그대로, 원본은 그대로 둠).

사용: python3 tools/tint_mist.py 0.45 assets/sprites/backdrop/mist_mid.png assets/sprites/backdrop/mist_near.png
결과: 같은 폴더의 <이름>_cream.png. 개발용 도구 (numpy, Pillow 필요). 게임은 결과 PNG만 쓴다.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

CREAM = np.array([0xff, 0xf6, 0xec], dtype=float)


def tint(rgba: np.ndarray, amount: float) -> np.ndarray:
    out = rgba.astype(float)
    out[..., :3] += (CREAM - out[..., :3]) * amount
    return np.rint(out).astype(np.uint8)


if __name__ == "__main__":
    for name in sys.argv[2:]:
        path = Path(name)
        rgba = np.asarray(Image.open(path).convert("RGBA"))
        Image.fromarray(tint(rgba, float(sys.argv[1]))).save(path.with_name(path.stem + "_cream.png"))
