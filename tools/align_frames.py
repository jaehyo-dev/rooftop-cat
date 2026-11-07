"""프레임 애니메이션 그림을 같은 크기·같은 기준점으로 맞춰 화면이 떨리지 않게 한다.

사용: python3 tools/align_frames.py <기준 그림> <출력 폴더> <프레임.png>... [-- <다른 시트의 프레임.png>...]
- `--`로 시트(한 번에 생성한 그림)를 나눈다. 한 시트 안의 자세는 생성할 때 같은 크기로 그려졌으므로 배율 하나를 함께 쓴다
  (자세마다 배율을 따로 정하면 웅크림·늘어남 때문에 프레임마다 크기가 출렁인다).
- 크기: 시트의 프레임 불투명 넓이 가운데값이 기준 그림 넓이와 같아지게 (x OUT_SCALE).
- 위치: 모든 프레임을 같은 캔버스에 놓고, 발끝(불투명 범위의 가장 아랫줄)을 BASELINE에, 몸 중심을 ANCHOR_X에 맞춘다.
  몸 중심 = 꼬리 쪽(왼쪽 TAIL_SHARE)을 뺀 불투명 픽셀의 가로 무게중심 (꼬리가 흔들려도 몸이 좌우로 떨리지 않게).
개발용 도구 (numpy, Pillow 필요). 게임은 결과 PNG만 쓴다.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

CANVAS = (640, 512)
OUT_SCALE = 0.5        # 기준 그림(1024x1024)의 절반 크기로 저장
ANCHOR_X = 360         # 몸 중심의 가로 위치 (꼬리가 왼쪽으로 길게 나오므로 오른쪽에 둠)
BASELINE = 450         # 발끝 높이
TAIL_SHARE = 0.3       # 몸 중심을 잴 때 빼는 왼쪽(꼬리 쪽) 비율
ALPHA_CUT = 128


def opaque(image: Image.Image) -> np.ndarray:
    return np.asarray(image.getchannel("A")) > ALPHA_CUT


def area(image: Image.Image) -> int:
    return int(opaque(image).sum())


def body_center_x(mask: np.ndarray) -> float:
    """꼬리 쪽을 뺀 불투명 픽셀의 가로 무게중심."""
    cols = np.nonzero(mask.any(axis=0))[0]
    left = cols[0] + (cols[-1] - cols[0]) * TAIL_SHARE
    ys, xs = np.nonzero(mask)
    keep = xs >= left
    return float(xs[keep].mean())


def place(image: Image.Image, scale: float) -> Image.Image:
    """배율 scale로 줄이고 발끝·몸 중심을 기준점에 맞춘 캔버스를 돌려준다."""
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    small = image.resize(size, Image.LANCZOS)
    mask = opaque(small)
    rows = np.nonzero(mask.any(axis=1))[0]
    dx = round(ANCHOR_X - body_center_x(mask))
    dy = BASELINE - (rows[-1] + 1)
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    # 빈 캔버스라 마스크 없이 그대로 복사한다 (마스크를 쓰면 반투명 가장자리의 투명도가 두 번 곱해짐)
    canvas.paste(small, (dx, dy))
    if area(canvas) < area(small) * 0.995:
        raise ValueError("프레임이 캔버스 밖으로 나감: CANVAS, ANCHOR_X, BASELINE을 조정")
    return canvas


def align(reference: Path, out_dir: Path, sheets: list) -> list:
    """sheets = [[프레임 경로...], ...] (시트별). 저장한 (경로, 배율) 목록을 돌려준다."""
    ref_area = area(Image.open(reference).convert("RGBA"))
    out_dir.mkdir(parents=True, exist_ok=True)
    saved = []
    for frames in sheets:
        images = [Image.open(path).convert("RGBA") for path in frames]
        scale = (ref_area / float(np.median([area(i) for i in images]))) ** 0.5 * OUT_SCALE
        for path, image in zip(frames, images):
            out = out_dir / Path(path).name
            place(image, scale).save(out)
            saved.append((out, scale))
    return saved


if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    groups, current = [], []
    for arg in sys.argv[3:]:
        if arg == "--":
            groups.append(current)
            current = []
        else:
            current.append(arg)
    groups.append(current)
    for path, scale in align(Path(sys.argv[1]), Path(sys.argv[2]), [g for g in groups if g]):
        print(path, "배율 %.3f" % scale)
