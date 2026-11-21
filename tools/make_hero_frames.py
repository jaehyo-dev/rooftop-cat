"""카툰 주인공 동작 시트(마젠타 배경, Codex) → 게임 프레임 그림 (assets/sprites/cat_frames/).

사용: python3 tools/make_hero_frames.py            # SHEETS 표의 시트를 모두 잘라 저장하고 프레임마다 크기·발끝을 출력
- 자르기: tools/cartoon_art.py의 cutout(마젠타 빼기)·cut_frames(바닥선 찾아 칸 나누기)를 그대로 쓴다.
- 크기: 시트마다 머리 너비(눈 높이에서 뒤통수 ~ 볼 앞, 원본 px, 손으로 잼)를 HEAD_PX에 맞춘다.
  HEAD_PX = 예전 색연필 run_0의 같은 너비라 화면 크기·판정(Balance.CAT_BODY_SIZE)은 그대로다.
- 위치: align_frames.py와 같은 캔버스·기준점. 가장 아랫줄 → BASELINE, 꼬리 쪽 30%를 뺀 무게중심 → ANCHOR_X.
  LIFTED 프레임(튕겨 뜬 장)은 시트 바닥선에서 떠 있던 높이를 그대로 둔다.
- 선 색: #331806보다 어두운 픽셀은 #331806으로 올린다 (ART_BIBLE 14-1).
- 앉기: 몸 한 장 + 따로 그린 꼬리 2개를 돌려 8장, 눈 감은 몸은 눈을 덮고 감은 눈 선을 그려 만든다 (몸이 0px도 안 움직임).
개발용 도구 (numpy, scipy, scikit-image, Pillow). 게임은 결과 PNG만 쓴다.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

sys.path.insert(0, str(Path(__file__).resolve().parent))
from align_frames import ANCHOR_X, BASELINE, CANVAS, body_center_x  # noqa: E402
from cartoon_art import LINE, cut_frames, cutout, lum  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/concept/cartoon/hero"
OUT = ROOT / "assets/sprites/cat_frames"
HEAD_PX = 143.0  # 예전 run_0 머리 너비 (프레임 px, 눈 높이)
# 시트: 파일, 줄마다 칸 수, 칸 이름(순서대로, None = 안 씀), 원본 머리 너비(px).
# 머리 너비는 손으로 잰 뒤, 만든 프레임에서 눈 높이 머리 너비(뒤통수 선 ~ 얼굴 앞)를 재 시트끼리 같아지게(145px 안팎) 고친 값
SHEETS = {
    "run": ("run_2.png", [6], ["run_0", "run_1", "run_2", "run_3", "run_4", "run_5"], 120),
    "air": ("air_2.png", [6], ["crouch", "takeoff", "rise", "fall", "land", "flail"], 136),  # air_1은 목도리가 앞 리본이라 달리기와 달라 다시 뽑음
    "flip": ("flip_2.png", [4, 2], ["flip_tuck", "flip_curl", "flip_ball", "flip_open", "paw_0", "paw_1"], 154),
    "slide": ("slide_1.png", [5, 2], ["slide_down", "slide_a", "slide_b", "slide_up1", "slide_up2", None, "slide_squash"], 114),
    "dive": ("dive_1.png", [1], ["dive"], 215),  # 슬라이딩 시트의 내리꽂기는 목도리가 위로 솟아 따로 다시 뽑음
    "hit": ("hit_1.png", [3], ["hit", "hit_fly", "hit_wobble"], 212),
    "sit": ("sit_1.png", [4], ["sit_body", "tail_low", "tail_up", "sit_up"], 218),
}
LIFTED = {"hit_fly"}
THICKEN = 2  # 선을 양쪽으로 키우는 픽셀 (프레임 px). 게임 크기(x0.42)에서 바깥선이 2.0~2.5px로 14-1의 3.5±0.75보다 가늘어서 (2px로 3.0~3.5)
SIT_TAILS = [("low", 0), ("low", -6), ("low", -12), ("low", -18), ("up", 8), ("up", 5), ("up", 2), ("up", 0)]


def darken_fix(rgba):
    """선 색보다 어두운 픽셀을 선 색으로 (순검정 금지)."""
    out = rgba.copy()
    dark = lum(out[..., :3].astype(float)) < lum(np.array(LINE, float))
    out[dark, :3] = LINE
    return out


def thicken(rgba, r=THICKEN):
    """선(선 색에 가까운 픽셀)을 r px씩 두껍게: 선다움을 회색 팽창해 그 몫만큼 선 색을 덮는다 (가장자리는 부드럽게)."""
    a = rgba.astype(float)
    near = np.clip(1 - np.abs(a[..., :3] - LINE).sum(2) / 150.0, 0, 1) * a[..., 3] / 255  # 0 = 선 아님, 1 = 선
    grown = ndi.grey_dilation(near, footprint=ndi.generate_binary_structure(2, 1), mode="constant") if r else near
    for _ in range(r - 1):
        grown = ndi.grey_dilation(grown, footprint=ndi.generate_binary_structure(2, 1), mode="constant")
    k = np.maximum(grown - near, 0)[..., None]  # 새로 덮을 몫
    alpha = a[..., 3:4] / 255
    new_alpha = np.maximum(alpha, grown[..., None])
    rgb = (a[..., :3] * alpha * (1 - k) + np.array(LINE, float) * k) / np.maximum(alpha * (1 - k) + k, 1e-6)
    return np.dstack([np.clip(rgb, 0, 255), new_alpha * 255]).astype(np.uint8)


def place(im, lift=0.0):
    """프레임 한 장을 캔버스에: 아랫줄을 BASELINE - lift, 몸 중심을 ANCHOR_X에. 잘린 픽셀 수도 돌려줌."""
    a = np.asarray(im)[..., 3] > 128
    ys = np.where(a.any(1))[0]
    cx = body_center_x(a)
    pos = (int(round(ANCHOR_X - cx)), int(round(BASELINE - lift - (ys[-1] + 1))))
    # 몸에서 떨어진 조각(먼지 등)이 캔버스 밖으로 걸치면 그 조각만 뺀다 (몸이 잘리는 건 그대로 알림)
    lab, n = ndi.label(np.asarray(im)[..., 3] > 8)
    sizes = ndi.sum(np.ones_like(lab), lab, range(1, n + 1))
    for i in range(1, n + 1):
        xs = np.where((lab == i).any(0))[0]
        if sizes[i - 1] < sizes.max() and (xs[0] + pos[0] < 0 or xs[-1] + pos[0] >= CANVAS[0]):
            arr = np.asarray(im).copy()
            arr[lab == i, 3] = 0
            im = Image.fromarray(arr)
    a = np.asarray(im)[..., 3] > 128
    for _ in range(3):  # 캔버스 밖으로 잘린 만큼 몸 중심이 밀리면 다시 맞춘다 (잘린 뒤 무게중심 = ANCHOR_X)
        canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        canvas.alpha_composite(im, (max(pos[0], 0), max(pos[1], 0)), (max(-pos[0], 0), max(-pos[1], 0)))
        off = body_center_x(np.asarray(canvas)[..., 3] > 128) - ANCHOR_X
        if abs(off) < 0.5:
            break
        pos = (pos[0] - int(round(off)), pos[1])
    lost = int(a.sum()) - int((np.asarray(canvas)[..., 3] > 128).sum())
    c = np.asarray(canvas).copy()
    foot = c[BASELINE - 4:BASELINE].astype(int)  # 맨 아래 4줄의 밝고 푸르스름한 픽셀 = 줄여 놓은 바닥선 찌꺼기 (발바닥은 짙은 외곽선)
    c[BASELINE - 4:BASELINE, :, 3][(foot[..., :3].sum(2) > 3 * 170) & (foot[..., 2] >= foot[..., 0] - 10)] = 0
    c[BASELINE:, :, 3] = 0  # 발끝 아래로 번진 반투명 가장자리 (게임의 발끝 = 이 줄)
    canvas = Image.fromarray(c)
    if lost > 0:  # 걸친 먼지 끝이 칼같이 잘려 보이지 않게 캔버스 양 끝 24px를 서서히 옅게
        c = np.asarray(canvas).copy()
        fade = np.clip(np.minimum(np.arange(CANVAS[0]), CANVAS[0] - 1 - np.arange(CANVAS[0])) / 24.0, 0, 1)
        c[..., 3] = (c[..., 3] * fade[None, :]).astype(np.uint8)
        canvas = Image.fromarray(c)
    return canvas, lost


def cut_sheet(key):
    """시트를 잘라 {이름: (RGBA 그림, 바닥선 위로 뜬 높이)} (배율 적용 뒤)."""
    file, counts, names, head = SHEETS[key]
    clean, boxes = cut_frames(cutout(Image.open(SRC / file)), counts)
    k = HEAD_PX / head
    out = {}
    clean = clean.copy()
    for name, (_, base, (x0, y0, x1, y1)) in zip(names, boxes):
        if name is None:
            continue
        if y1 >= base - 6:
            # 바닥선에 닿은 칸: cut_frames는 바닥선 3px 위에서 자르므로 발바닥 외곽선까지 내려 자르고,
            # 그 띠에 남은 바닥선(푸르스름한 회색)·마젠타 섞인 가장자리만 지운다
            y1 = base + 7
            strip = clean[base - 2:y1, x0:x1].astype(int)
            r, g, b = strip[..., 0], strip[..., 1], strip[..., 2]
            junk = (b > r + 8) | (g < np.minimum(r, b) - 25)
            junk[2:] |= ((r + g + b) > 3 * 170)[2:] & (b >= r - 10)[2:]  # 바닥선 줄 자체(base부터)의 밝은 회색 = 선 (발 외곽선은 짙음)
            clean[base - 2:y1, x0:x1, 3][junk] = 0
        # 몸 안쪽 구석에 갇힌 마젠타 섞인 픽셀 (cutout은 바깥 가장자리만 지움)
        box = clean[y0:y1, x0:x1].astype(int)
        trapped = box[..., 1] < np.minimum(box[..., 0], box[..., 2]) - 40
        clean[y0:y1, x0:x1, 3][trapped] = 0
        im = Image.fromarray(darken_fix(clean[y0:y1, x0:x1]))
        im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
        im = Image.fromarray(thicken(np.pad(np.asarray(im), ((THICKEN, THICKEN), (THICKEN, THICKEN), (0, 0)))))
        out[name] = (im, max(0.0, (base - y1) * k - THICKEN))
    return out


def blink(body):
    """눈 감은 몸: 머리의 작은 선 색 점(눈)을 둘레 털 색으로 덮고 아래로 둥근 짧은 선을 그린다."""
    a = np.asarray(body).copy()
    used = np.where(a[..., 3] > 128)
    top, bottom = used[0].min(), used[0].max()
    dark = (np.abs(a[..., :3].astype(int) - LINE).sum(2) < 90) & (a[..., 3] > 200)
    dark[int(top + (bottom - top) * 0.55):] = False  # 머리(위쪽)만
    lab, n = ndi.label(dark)
    eyes = []
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        h, w = np.ptp(ys) + 1, np.ptp(xs) + 1
        if 60 <= len(ys) <= 900 and 0.6 <= h / w <= 1.8 and len(ys) > 0.55 * h * w:  # 꽉 찬 둥근 점 = 눈 (선은 가늘고 김)
            eyes.append((ys, xs))
    img = Image.fromarray(a)
    d = ImageDraw.Draw(img)
    for ys, xs in eyes:
        m = np.zeros(a.shape[:2], bool)
        m[ys, xs] = True
        ring = ndi.binary_dilation(m, iterations=6) & ~ndi.binary_dilation(m, iterations=3) & (a[..., 3] > 250) & ~dark
        fur = tuple(int(v) for v in np.median(a[ring][:, :3], 0)) + (255,)
        for y, x in zip(*np.where(ndi.binary_dilation(m, iterations=2))):
            img.putpixel((int(x), int(y)), fur)
        cy, cx, r = ys.mean(), xs.mean(), (np.ptp(xs) + 1) * 0.75
        d.arc([cx - r, cy - r * 1.2, cx + r, cy + r * 0.4], 20, 160, fill=LINE + (255,), width=7)
    return img, len(eyes)


def sit_frames(parts):
    """앉기: 몸·일어남은 그대로 놓고, 꼬리는 몸 엉덩이 뒤에 뿌리를 맞춰 8장."""
    body, _ = place(parts["sit_body"][0])
    out = {"sit_body": body, "sit_up": place(parts["sit_up"][0])[0]}
    out["sit_body_blink"], eyes = blink(body)
    ba = np.asarray(body)[..., 3] > 128
    ys, xs = np.where(ba)
    low = ys > ys.max() - (ys.max() - ys.min()) * 0.45      # 엉덩이 높이
    rump = (float(xs[low].min()) + 18, float(ys.max() - (ys.max() - ys.min()) * 0.12))  # 엉덩이 뒤 가장자리 조금 안쪽
    for i, (which, deg) in enumerate(SIT_TAILS):
        tail = parts["tail_" + which][0]
        ta = np.asarray(tail)[..., 3] > 128
        tys, txs = np.where(ta)
        # 뿌리 = 꼬리 그림의 오른쪽 아래 끝 (몸에 붙는 쪽)
        right = txs > txs.max() - 25
        root = (float(txs[right].mean()), float(tys[right].max()) - 12)
        canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        canvas.alpha_composite(tail, (int(round(rump[0] - root[0])), int(round(rump[1] - root[1]))))
        if deg:
            canvas = canvas.rotate(deg, resample=Image.BICUBIC, center=rump)
        c = np.asarray(canvas).copy()
        c[BASELINE:, :, 3] = 0  # 바닥선 아래로 내려가지 않게
        out[f"sit_tail_{i}"] = Image.fromarray(c)
    return out, eyes


def shadow_row(im):
    """CatShadow.FRAME_BODY 값: 아래 30%의 [가운데 x, 너비] (게임 px, 발끝 기준). test_shadow.gd와 같은 방법."""
    a = np.asarray(im)[..., 3] > 127
    ys = np.where(a.any(1))[0]
    rows = [np.where(a[y])[0] for y in range(ys[-1] + 1 - int((ys[-1] + 1 - ys[0]) * 0.3), ys[-1] + 1, 3)]
    lo, hi = min(r.min() for r in rows if len(r)), max(r.max() for r in rows if len(r))
    art = 150 / (711 * 0.5)
    return f"[{((lo + hi) / 2 - ANCHOR_X) * art:.1f}, {(hi - lo) * art:.1f}]"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for key in SHEETS:
        parts = cut_sheet(key)
        if key == "sit":
            frames, eyes = sit_frames(parts)
            print(f"sit: 눈 {eyes}개를 감김")
            items = {n: (im, 0) for n, im in frames.items()}
        else:
            items = {n: place(im, lift if n in LIFTED else 0.0) for n, (im, lift) in parts.items()}
        for name, (im, lost) in items.items():
            im.save(OUT / f"{name}.png")
            a = np.asarray(im)[..., 3] > 128
            ys, xs = np.where(a)
            warn = f"  !! 캔버스 밖 {lost}px" if lost > 0 else ""
            print(f"{name:15s} 상자 x {xs.min()}~{xs.max()} y {ys.min()}~{ys.max()} (키 {ys.max() - ys.min() + 1})"
                  f" 그림자 {shadow_row(im)}{warn}")


if __name__ == "__main__":
    main()
