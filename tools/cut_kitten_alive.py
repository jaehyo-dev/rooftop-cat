"""떠다니는 아기 "살아 움직이기" 시트(마젠타 배경, 5-5-4칸)를 wait.png와 같은 캔버스·기준점으로 자른다.

사용: python3 tools/cut_kitten_alive.py <시트.png> <출력 폴더>
예:   python3 tools/cut_kitten_alive.py assets/raw/kitten_alive/cheese_1.png assets/sprites/kittens/cheese
- 칸 순서(NAMES)는 review/cat-parade/action/alive/prompts/alive.txt와 같다. 1번 "기본"이 떠다니는 아기의 쉬는 그림(alive_base)이다.
  wait.png는 머리 비율이 조금 달라(새 그림 머리가 작음) 섞으면 머리 크기가 튀므로, 떠다닐 때는 이 시트 그림만 쓴다.
- 크기: 기본 칸(꼬리 포함)의 불투명 넓이가 지금 wait.png + wait_tail_2 넓이와 같아지는 배율 하나를 모든 칸에 쓴다
  (한 시트 안의 아기는 같은 크기로 그려졌다고 봄).
- 위치: 발·배 아랫선을 BASELINE에, x는 엉덩이 왼쪽 끝(아래 띠에서 꽉 찬 가장 왼쪽 열)을 기본 칸과 같은 자리에 둔다.
  기본 칸은 wait 그림과 겹치는 넓이가 가장 큰 자리로 맞추고, 그때의 엉덩이 자리를 모든 칸의 기준으로 쓴다.
- 꼬리: 기본 칸의 세운 꼬리를 split_tail로 떼어 alive_tail_0~4(돌린 꼬리)로 저장하고, 다른 칸의 세운 꼬리는 떼어 버린다
  (게임은 alive_tail을 늘 몸 뒤에 그려 살랑임).
  OWN_TAIL 칸(엎드리기·놀람)은 꼬리 모양이 달라 그대로 두고 게임이 따로 붙인 꼬리를 숨긴다.
결과: alive_<이름>.png, alive_tail_<번호>.png (256x240, KITTEN_ANCHOR 기준). 개발용 도구 (numpy, scipy, Pillow).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).parent))
from align_frames import opaque  # noqa: E402
from cut_kittens import BASELINE, CANVAS, blobs, split_tail  # noqa: E402
from cut_parts import remove_magenta  # noqa: E402

NAMES = ["base", "blink", "cheer_0", "cheer_1", "squat",
         "lie", "surprised", "yawn_0", "yawn_1", "groom_0",
         "groom_1", "knead_0", "knead_1", "look"]
OWN_TAIL = {"lie", "surprised", "squat"}  # 꼬리 모양이 다르거나(엎드림·놀람) 등이 낮아 붙인 꼬리 뿌리가 드러남(폭 앉기)
BAND = 16          # 엉덩이 자리를 재는 아래 띠 높이 (캔버스 픽셀)
BAND_FULL = 0.8    # 띠 안에서 이 비율 이상 찬 열부터 몸 (가는 꼬리·발끝은 건너뜀)
EDGE_SLACK = 3     # 엉덩이 쪽에서 기본 칸 윤곽보다 이만큼(픽셀)까지는 남김
SEARCH = 12        # 기본 칸을 wait에 맞출 때 찾아보는 x 범위 (±픽셀)


def rump_x(mask: np.ndarray) -> int:
    """아랫선 위 BAND줄에서 BAND_FULL 이상 찬 가장 왼쪽 열 (엉덩이 왼쪽 끝)."""
    rows = np.nonzero(mask.any(axis=1))[0]
    band = mask[rows[-1] + 1 - BAND:rows[-1] + 1]
    full = np.nonzero(band.mean(axis=0) >= BAND_FULL)[0]
    return int(full[0])


def paste(img: Image.Image, scale: float, left: int) -> Image.Image:
    """배율 scale로 줄여 아랫선은 BASELINE, 엉덩이 왼쪽 끝은 캔버스 x = left에 둔다."""
    small = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    mask = opaque(small)
    rows = np.nonzero(mask.any(axis=1))[0]
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    canvas.paste(small, (left - rump_x(mask), BASELINE - (rows[-1] + 1)))
    if opaque(canvas).sum() < mask.sum() * 0.995:
        raise ValueError("프레임이 캔버스 밖으로 나감")
    return canvas


def fit_left(base: Image.Image, scale: float, target: np.ndarray) -> int:
    """기본 칸을 wait(꼬리 포함)와 가장 많이 겹치게 하는 엉덩이 x."""
    guess = rump_x(target)
    return max(range(guess - SEARCH, guess + SEARCH + 1),
               key=lambda left: int((opaque(paste(base, scale, left)) & target).sum()))


def cut(sheet: Path, out_dir: Path) -> dict:
    rgba = remove_magenta(np.asarray(Image.open(sheet).convert("RGB")))
    mask = rgba[..., 3] > 128
    frames = {}
    for name, ((top, bottom, left, right, label), labels) in zip(NAMES, blobs(mask, len(NAMES))):
        piece = rgba[top:bottom, left:right].copy()
        piece[labels[top:bottom, left:right] != label] = 0
        frames[name] = Image.fromarray(piece)
    wait = Image.open(out_dir / "wait.png").convert("RGBA")
    wait.alpha_composite(Image.open(out_dir / "wait_tail_2.png").convert("RGBA"))  # 0도 꼬리 = 기본 자세
    target = opaque(wait)
    scale = (target.sum() / opaque(frames["base"]).sum()) ** 0.5
    left = fit_left(frames["base"], scale, target)
    base = paste(frames["base"], scale, left)
    body, tails = split_tail(base)
    for i, tail in enumerate(tails):
        tail.save(out_dir / f"alive_tail_{i}.png")
    # 꼬리 자리 = 기본 칸에서 뗀 부분의 오른쪽·아래 끝. 다른 칸도 이 자리를 지워 꼬리가 두 개로 보이지 않게
    cut_mask = opaque(base) & ~opaque(body)
    ys, xs = np.nonzero(cut_mask)
    outline = ndimage.binary_dilation(opaque(base), iterations=EDGE_SLACK)
    overlap = {}
    for name, img in frames.items():
        placed = body if name == "base" else paste(img, scale, left)
        if name not in OWN_TAIL:
            arr = np.array(placed)
            arr[:ys.max() + 1, :xs.max() + 1] = 0
            # 엉덩이 쪽(꼬리 자리 왼쪽 열)에서 기본 칸 윤곽 밖으로 삐져나온 원래 꼬리 조각도 지움
            arr[:, :xs.max() + 1][~outline[:, :xs.max() + 1]] = 0
            placed = Image.fromarray(arr)
        overlap[name] = round(float((opaque(placed) & target).sum() / target.sum()), 3)
        placed.save(out_dir / f"alive_{name}.png")
    return {"scale": round(scale, 4), "left": left, "wait_overlap": overlap}


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    print(cut(Path(sys.argv[1]), Path(sys.argv[2])))
