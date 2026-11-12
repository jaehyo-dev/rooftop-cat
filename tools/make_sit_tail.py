"""시작 화면 앉은 고양이: 몸 한 장 + 꼬리 8장 (v0.7.0 2c-polish, 사용자 피드백 "고양이가 위아래로 흔들린다, 꼬리 프레임 더").
앉은 그림 sit_0(꼬리 아래)·sit_1(꼬리 위)은 몸이 같고 꼬리만 다르다. 몸은 한 장으로 고정하고(바닥 위치 차이 0px),
꼬리는 두 그림에서 떼어 꼬리 뿌리를 축으로 조금씩 돌려 사이 그림을 만든다 (같은 그림체, 새로 그리지 않음).
게임은 꼬리를 몸 뒤에 그린다 (꼬리 뿌리의 잘린 자리는 몸이 가림).
사용: python3 tools/make_sit_tail.py assets/sprites/cat_frames
만드는 것: sit_body.png, sit_body_blink.png, sit_tail_0.png ~ sit_tail_7.png (모두 640x512, align_frames.py와 같은 기준점)
개발용 도구 (numpy, Pillow). 게임은 결과 PNG만 쓴다.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ALPHA = 20          # 이 값보다 불투명하면 그림이 있는 픽셀
STUB_X = 270        # 이보다 왼쪽(엉덩이 뒤)에서는 몸 마스크의 가는 꼬리 뿌리 조각을 깎는다
OPEN_R = 5
FACE_Y = 340        # 이보다 위(머리)만 눈 감은 그림에서 가져옴          # 깎는 정도 (픽셀, 가는 조각만 없어지고 엉덩이 곡선은 남음)
# 꼬리 8장: (어느 꼬리, 회전 도). 아래 꼬리(sit_0)를 들어 올리다가 위 꼬리(sit_1)로 넘어가 끝까지
TAILS = [("low", 0), ("low", -6), ("low", -12), ("low", -18), ("up", 8), ("up", 5), ("up", 2), ("up", 0)]


def load(path: Path) -> np.ndarray:
    return np.array(Image.open(path).convert("RGBA")).astype(np.float64)


def _erode(mask: np.ndarray, r: int) -> np.ndarray:
    out = mask.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                out &= np.roll(np.roll(mask, dy, 0), dx, 1)
    return out


def _dilate(mask: np.ndarray, r: int) -> np.ndarray:
    out = mask.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                out |= np.roll(np.roll(mask, dy, 0), dx, 1)
    return out


def body_mask(a0: np.ndarray, a1: np.ndarray) -> np.ndarray:
    """두 그림에 모두 있는 몸. 엉덩이 뒤 가는 꼬리 뿌리 조각은 열기(깎고 다시 키우기)로 없앤다"""
    both = a0 & a1
    opened = _dilate(_erode(both, OPEN_R), OPEN_R) & both
    left = np.zeros_like(both)
    left[:, :STUB_X] = True
    return np.where(left, opened, both)


def pivot(tail: np.ndarray, body: np.ndarray) -> tuple:
    """꼬리 뿌리 축: 몸에 닿는 꼬리 픽셀 가운데 가장 아래 (뿌리 끝).
    축이 뿌리 끝에 있어야 돌려도 잘린 뿌리가 몸 밖으로 나오지 않는다"""
    touch = tail & _dilate(body, 2)
    ys, xs = np.nonzero(touch)
    bottom = ys >= ys.max() - 3
    return float(xs[bottom].mean()), float(ys.max())


def rotate(img: np.ndarray, deg: float, center: tuple) -> np.ndarray:
    """center를 축으로 deg도 (화면에서 양수 = 시계 반대). 미리 곱한 알파로 돌려 가장자리 번짐이 없게"""
    pre = img.copy()
    pre[..., :3] *= pre[..., 3:4] / 255.0
    out = np.array(Image.fromarray(pre.astype(np.uint8), "RGBA").rotate(deg, resample=Image.BICUBIC, center=center)).astype(np.float64)
    a = out[..., 3:4]
    out[..., :3] = np.where(a > 0, out[..., :3] * 255.0 / np.maximum(a, 1), 0)
    return out


def cut(img: np.ndarray, mask: np.ndarray) -> np.ndarray:
    out = img.copy()
    out[..., 3] *= mask
    return out


def make(frames: Path) -> dict:
    s0, s1, sb = (load(frames / f"{n}.png") for n in ("sit_0", "sit_1", "sit_blink"))
    a0, a1 = s0[..., 3] > ALPHA, s1[..., 3] > ALPHA
    body = body_mask(a0, a1)
    # 엉덩이 왼쪽 아래는 sit_0에서 아래 꼬리 뿌리가 덮어 테두리가 없다 → 꼬리가 위로 간 sit_1의 엉덩이(테두리 있음)를 쓴다
    up_root = int(np.nonzero(_dilate(_erode(a1 & ~body, 2), 4))[0].max()) + 2
    rump = np.zeros_like(body)
    rump[up_root:, :STUB_X] = True
    body = np.where(rump, a1, body)
    patch = lambda img: np.where(rump[..., None], s1, img)
    ground = int(np.nonzero(s0[..., 3] > ALPHA)[0].max())
    src = {"low": s0, "up": s1}
    tails = {}
    for which, a in (("low", a0), ("up", a1)):
        core = _dilate(_erode(a & ~body, 2), 4)  # 몸 둘레 가는 테두리 차이는 버리고 꼬리 덩어리만
        tails[which] = core & (src[which][..., 3] > 0)
    face = np.zeros_like(body)
    face[:FACE_Y, :] = True  # 눈 감은 그림은 얼굴만 가져옴 (아랫줄은 몸 그림과 똑같이: 바닥 차이 0px)
    open_body = cut(patch(s0), body)
    out = {"sit_body": open_body, "sit_body_blink": np.where(face[..., None], cut(sb, body), open_body)}
    for i, (which, deg) in enumerate(TAILS):
        mask = tails[which] & ~body
        tail = cut(src[which], _dilate(mask, 3) & (src[which][..., 3] > 0))  # 뿌리를 몸 밑으로 조금 더 (몸이 가림, 이음매 틈 메움)
        tail = rotate(tail, deg, pivot(mask, body)) if deg else tail
        tail[ground + 1:, :, 3] = 0  # 꼬리가 바닥선 아래로 내려가지 않게
        out[f"sit_tail_{i}"] = tail
    for name, img in out.items():
        Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA").save(frames / f"{name}.png")
    return out


if __name__ == "__main__":
    make(Path(sys.argv[1]))
