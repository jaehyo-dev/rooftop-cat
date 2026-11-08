"""안개 띠 그림의 색을 크림색 쪽으로 섞어 새 파일로 저장한다 (투명도는 그대로, 원본은 그대로 둠).

사용: python3 tools/tint_mist.py 0.45 assets/sprites/backdrop/mist_mid.png assets/sprites/backdrop/mist_near.png
     python3 tools/tint_mist.py 0.75 원본.png --suffix m2                  (결과 이름 바꾸기)
     python3 tools/tint_mist.py 0.9 원본.png --suffix m3 --color e2ebf0    (크림 대신 다른 색 쪽으로)
결과: 같은 폴더의 <이름>_cream.png(또는 <이름>_<suffix>.png). 개발용 도구 (numpy, Pillow 필요). 게임은 결과 PNG만 쓴다.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image

CREAM = np.array([0xff, 0xf6, 0xec], dtype=float)


def tint(rgba: np.ndarray, amount: float, target: np.ndarray = CREAM) -> np.ndarray:
    out = rgba.astype(float)
    out[..., :3] += (target - out[..., :3]) * amount
    return np.rint(out).astype(np.uint8)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("amount", type=float)
    parser.add_argument("files", nargs="+")
    parser.add_argument("--suffix", default="cream")
    parser.add_argument("--color", default="fff6ec")
    args = parser.parse_args()
    target = np.array(list(bytes.fromhex(args.color)), dtype=float)
    for name in args.files:
        path = Path(name)
        rgba = np.asarray(Image.open(path).convert("RGBA"))
        Image.fromarray(tint(rgba, args.amount, target)).save(path.with_name(f"{path.stem}_{args.suffix}.png"))
