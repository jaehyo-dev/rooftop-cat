"""액션 시험판 그림 (2026-11-17): Codex 마젠타 그림 → 게임 그림. 같은 입력이면 항상 같은 결과.

사용: python3 tools/make_action_art.py sign|slide
- sign: assets/raw/action/sign.png → assets/sprites/obstacles/sign.png (게임 너비 balance.gd OBSTACLES.sign.art_w의 2배).
  밧줄은 그림 위 끝에서 잘리므로 게임이 그 위를 선으로 잇는다: 밧줄 가로 자리(너비 비율)를 찍어 world_view.gd SIGN_ROPES에 적는다.
- slide: assets/raw/action/slide.png (4칸: 슬라이딩 3 + 일어나기) → assets/sprites/cat_frames/slide_0~2, slide_up.png
  (tools/align_frames.py와 같은 캔버스·발끝 기준선, 배율은 달리기 그림 몸 길이에 맞춤)
개발용 도구 (numpy, scipy, Pillow 필요).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

from align_frames import place
from clean_edges import clean
from cut_parts import find_parts, remove_magenta

ROOT = Path(__file__).resolve().parent.parent
SIGN_WIDTH = 170 * 2
SLIDE_NAMES = ["slide_0", "slide_1", "slide_2", "slide_up"]
SLIDE_LENGTH = 1.12  # 슬라이딩 몸 길이(꼬리 뺀 불투명 가로) = 달리기 그림의 이 배 (엎드려 쭉 뻗어 조금 길게)


def sign() -> None:
    rgba = remove_magenta(np.asarray(Image.open(ROOT / "assets/raw/action/sign.png").convert("RGB")))
    top, bottom, left, right = find_parts(rgba, 1)[0]
    part = Image.fromarray(rgba[top:bottom, left:right])
    small = part.resize((SIGN_WIDTH, round(part.height * SIGN_WIDTH / part.width)), Image.LANCZOS)
    Image.fromarray(clean(np.asarray(small))).save(ROOT / "assets/sprites/obstacles/sign.png")
    row = np.asarray(small)[2, :, 3] > 128  # 맨 윗줄 = 밧줄만
    xs = np.nonzero(row)[0]
    mid = SIGN_WIDTH // 2
    print("sign.png", small.size, "밧줄 가로 자리 (SIGN_ROPES): %.3f, %.3f" % (xs[xs < mid].mean() / SIGN_WIDTH, xs[xs >= mid].mean() / SIGN_WIDTH))


def body_length(mask: np.ndarray) -> int:
    cols = np.nonzero(mask.any(axis=0))[0]
    return int(cols[-1] - cols[0])


def slide() -> None:
    rgba = remove_magenta(np.asarray(Image.open(ROOT / "assets/raw/action/slide.png").convert("RGB")))
    boxes = find_parts(rgba, 4)
    run = np.asarray(Image.open(ROOT / "assets/sprites/cat_frames/run_1.png"))[..., 3] > 128
    parts = [Image.fromarray(rgba[t:b, l:r]) for t, b, l, r in boxes]
    # 한 시트라 배율 하나: 슬라이딩 3장 몸 길이 가운데값을 달리기 x SLIDE_LENGTH에
    lengths = [body_length(np.asarray(p)[..., 3] > 128) for p in parts[:3]]
    scale = body_length(run) * SLIDE_LENGTH / float(np.median(lengths))
    for name, part in zip(SLIDE_NAMES, parts):
        out = place(part, scale)
        Image.fromarray(clean(np.asarray(out))).save(ROOT / f"assets/sprites/cat_frames/{name}.png")
        print(name, "배율 %.3f" % scale)


if __name__ == "__main__":
    {"sign": sign, "slide": slide}[sys.argv[1]]()
