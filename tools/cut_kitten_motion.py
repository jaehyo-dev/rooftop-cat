"""아기 움직임 비교(cat-parade 1단계): 치즈 아기 A 프레임 시트·B 조각 시트를 게임 그림으로 자르고 재는 도구.

사용: python3 tools/cut_kitten_motion.py a2 <예전 달리기 폴더> <공중 시트> <A 폴더>   (motion2: 달리기 + 공중 자세 13장, 아래)
      python3 tools/cut_kitten_motion.py a <시트.png> <출력 폴더>   (A: 달리기 8장 + 웅크림·도약·오름·내림·착지·멈칫)
      python3 tools/cut_kitten_motion.py b <시트.png> <출력 폴더>   (B: 몸통·머리·놀란 머리·다리 4·꼬리 + 조립 참고)
A
- 크기: 달리기 8장 불투명 넓이 가운데값을 cut_kittens.RUN_AREA로 (예전 아기와 같은 크기).
- 위치: bbox가 아니라 몸통 기준. 다리를 뺀 윗몸(아래 LEG_SHARE를 뺀 부분)을 달리기 1장과 가장 많이 겹치게 옮긴다.
  땅 자세는 발끝(가장 아랫줄)을 BASELINE에, 오름·내림은 윗몸을 가로·세로 모두 달리기 1장에 맞춘다.
- 발: 각 장에서 BASELINE 위 CONTACT_ROWS줄 안의 불투명 덩어리 = 바닥을 디딘 발. 장 k → k+1에서 디딘 발이 뒤로 간 거리의
  가운데값을 advance[k]로 (게임은 아기가 이만큼 달리면 다음 장으로 넘김 → 디딘 발이 세계에서 제자리).
- 결과: <출력>/<이름>.png, 그리고 scripts/logic/kitten_motion_data.gd(측정값, 게임이 읽음)의 A 부분.
A2 (motion2, 2026-11-16)
- 달리기: 윗몸(머리·몸통·꼬리)은 예전 run_0 한 장을 모든 장에 그대로 쓰고(머리 떨림 없음), 다리는 예전 장의 것을 그 밑에 깐다.
  윗몸은 걸음 박자(한 바퀴 2번)에 맞춰 BOB 픽셀만 오르내린다. 디딘 다리는 다리끼리 떨어진 줄 아래를 비스듬히 옮겨(최대 LEG_NUDGE)
  디딘 동안 발의 세계 x가 같게 맞춘다 (AI 그림의 발 자리 어긋남을 지움). 새로 그린 16장 시트(a_run16_1)는 발 박자가 안내도와 달라 안 씀.
- 공중 13장: 크기는 웅크림2를 지금 웅크림 넓이에, 땅 자세(웅크림2·도약2)는 발끝을 BASELINE에, 공중은 윗몸을 run_0에 맞춤,
  앞구르기 공·말기는 몸 무게중심을 run_0 무게중심에 (게임이 그 언저리를 축으로 돌림).
B
- 크기: 조립 참고 그림 넓이를 A 멈칫(네 발로 선 모습) 넓이에 맞춘다. 부품마다 꼭 맞게 잘라 <출력>/<이름>.png.
- 다리: 축 = 위 둥근 끝 안쪽(PIVOT_IN), 발 = 가장 아랫줄. 축 → 발 길이가 다리 길이 L.
- 조립 자리(어깨·엉덩이·목·꼬리 뿌리)는 B_PLACE(몸통 그림 비율)로, rest.png(조립 확인 그림)를 보며 눈으로 맞췄다.
개발용 도구 (numpy, scipy, Pillow).
"""
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).parent))
from align_frames import opaque  # noqa: E402
from cut_kittens import RUN_AREA, blobs  # noqa: E402
from cut_parts import remove_magenta  # noqa: E402

A_NAMES = [f"run_{i}" for i in range(8)] + ["crouch", "takeoff", "rise", "fall", "land", "startle"]
A_GROUND = [n for n in A_NAMES if n not in ("rise", "fall")]
CANVAS = (300, 260)
ANCHOR_X = 150
BASELINE = 236
LEG_SHARE = 0.34      # 몸통 맞추기에서 빼는 아래쪽(다리) 비율
SHIFT = 40            # 몸통 맞추기 찾는 범위 (픽셀)
CONTACT_ROWS = 2      # 바닥선 위 이 줄 수 안의 불투명 = 디딘 발
CONTACT_GAP = 4       # 이보다 가까운 덩어리는 한 발

A2_AIR = ["crouch_b", "takeoff_b", "rise_b", "apex", "apex_b", "fall_b", "flip_tuck", "flip_curl", "flip_ball", "flip_ball_b",
          "flip_open", "flail", "flail_b"]
A2_GROUND = ["crouch_b", "takeoff_b"]
A2_SPIN = ["flip_tuck", "flip_curl", "flip_ball", "flip_ball_b", "flip_open"]
BOB = 2               # 달리기 윗몸 오르내림 (캔버스 픽셀, 한 바퀴 2번)
SEAM = 8              # 윗몸 아래 끝을 다리 층과 섞는 줄 수
TRACK_MATCH = 20.0    # 같은 발로 보는 어긋남 (캔버스 픽셀)
SUB = 4               # 예전 장 하나를 사이 장 몇 장으로 (8 x 4 = 32장, 3은 앞발이 4~6px 밀림 motion2 검토)
ADV_MAX = 34.0        # 상한 (한 바퀴 160 게임 픽셀: 주인공 150과 비슷, 더 길면 짧은 다리로 성큼성큼)
ADV_MIN = 18.0        # 예전 장 하나의 거리 하한 (캔버스 픽셀). 22는 디딘 발이 바닥보다 약 10% 앞으로 밀림 (motion2 3차 검토)
LEG_NUDGE = 14        # 디딘 다리 발끝을 옮겨도 되는 최대 (캔버스 픽셀)

B_NAMES = ["torso", "head", "head_surprised", "front_near", "front_far", "hind_near", "hind_far", "tail", "assembled"]
B_LEGS = ["front_near", "front_far", "hind_near", "hind_far"]
PIVOT_IN = 0.45       # 다리 축: 위 끝에서 (다리 폭 x 이 값) 아래, 둥근 어깨·허벅지 안쪽
PAD = 4
# 몸통 그림 안 자리 (몸통 폭·높이 비율). rest.png와 조립 참고 그림을 나란히 보며 맞춤
B_PLACE = {
    "front": (0.80, 0.72),   # 앞다리 축 (가까운·먼 쪽 같은 자리, 먼 쪽은 FAR_SHIFT만큼 뒤)
    "hind": (0.22, 0.66),
    "neck": (0.80, 0.32),    # 머리 그림의 목(아래 가운데)이 오는 자리
    "tail": (0.07, 0.30),    # 꼬리 뿌리
}
FAR_SHIFT = -10.0        # 먼 쪽 다리는 이만큼 (캔버스 픽셀) 옆으로 어긋나 보이게

DATA = Path(__file__).parent.parent / "scripts/logic/kitten_motion_data.gd"


def _upper(mask: np.ndarray) -> np.ndarray:
    rows = np.nonzero(mask.any(axis=1))[0]
    cut = rows[-1] - int((rows[-1] - rows[0]) * LEG_SHARE)
    out = mask.copy()
    out[cut:] = False
    return out


def _best_shift(ref: np.ndarray, mask: np.ndarray, dys: range) -> tuple:
    """mask를 (dx, dy) 옮겨 ref와 가장 많이 겹치는 자리."""
    best = (-1, 0, 0)
    for dy in dys:
        for dx in range(-SHIFT, SHIFT + 1):
            moved = np.roll(np.roll(mask, dy, axis=0), dx, axis=1)
            score = int((moved & ref).sum())
            if score > best[0]:
                best = (score, dx, dy)
    return best[1], best[2]


def _paste(img: Image.Image, x: int, y: int) -> Image.Image:
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    canvas.paste(img, (x, y))
    if opaque(canvas).sum() < opaque(img).sum() * 0.995:
        raise ValueError("프레임이 캔버스 밖으로 나감: CANVAS·ANCHOR_X·BASELINE 조정")
    return canvas


def _pieces(sheet: Path, names: list) -> dict:
    rgba = remove_magenta(np.asarray(Image.open(sheet).convert("RGB")))
    out = {}
    for name, ((top, bottom, left, right, label), labels) in zip(names, blobs(rgba[..., 3] > 128, len(names))):
        piece = rgba[top:bottom, left:right].copy()
        piece[labels[top:bottom, left:right] != label] = 0
        out[name] = Image.fromarray(piece)
    return out


def _small(img: Image.Image, scale: float) -> Image.Image:
    return img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)


def contacts(frame: Image.Image) -> list:
    """바닥을 디딘 발 x들 (캔버스 픽셀, 왼쪽부터)."""
    band = opaque(frame)[BASELINE - CONTACT_ROWS:BASELINE].any(axis=0)
    labels, n = ndimage.label(ndimage.binary_closing(band, iterations=CONTACT_GAP) | band)
    return [float(np.nonzero(labels == i)[0].mean()) for i in range(1, n + 1)]


def advances(feet: list) -> list:
    """장마다 머무는 거리 (같은 값). 한 바퀴 보폭 = 디딘 발이 닿는 앞뒤 범위 x 2 (트롯: 한 발이 반 바퀴 디딤).
    AI 그림은 장 사이 디딘 발이 뒤로 가는 거리가 4~20픽셀로 들쭉날쭉해 장마다 다르게 재면 한 바퀴가 너무 짧아진다
    (950px/초에서 초당 130장 이상 → 장을 건너뜀). 남는 어긋남은 발 미끄러짐 검사가 그대로 잰다."""
    xs = [x for f in feet for x in f]
    return [2.0 * (max(xs) - min(xs)) / len(feet)] * len(feet)


def cut_a(sheet: Path, out_dir: Path) -> dict:
    raw = _pieces(sheet, A_NAMES)
    scale = (RUN_AREA / float(np.median([opaque(raw[f"run_{i}"]).sum() for i in range(8)]))) ** 0.5
    small = {n: _small(img, scale) for n, img in raw.items()}
    # 기준: 달리기 1장을 (윗몸 가운데 = ANCHOR_X, 발끝 = BASELINE)
    ref_img = small["run_0"]
    ref_mask = opaque(ref_img)
    rows = np.nonzero(ref_mask.any(axis=1))[0]
    ref_x = round(ANCHOR_X - np.nonzero(_upper(ref_mask))[1].mean())
    placed = {"run_0": _paste(ref_img, ref_x, BASELINE - (rows[-1] + 1))}
    ref_upper = _upper(opaque(placed["run_0"]))
    for name in A_NAMES[1:]:
        img = small[name]
        mask = opaque(img)
        rows = np.nonzero(mask.any(axis=1))[0]
        y = BASELINE - (rows[-1] + 1)
        first = _paste(img, ref_x, y)
        if name in A_GROUND:
            dx, _ = _best_shift(ref_upper, _upper(opaque(first)), range(0, 1))
            placed[name] = _paste(img, ref_x + dx, y)
        else:  # 공중: 윗몸을 세로로도 맞춤
            dx, dy = _best_shift(ref_upper, _upper(opaque(first)), range(-40, 41, 2))
            placed[name] = _paste(img, ref_x + dx, y + dy)
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, img in placed.items():
        img.save(out_dir / f"{name}.png")
    feet = [contacts(placed[f"run_{i}"]) for i in range(8)]
    adv = advances(feet)
    _write_data("A", {"A_ADVANCE": [round(a, 2) for a in adv], "A_FEET": [[round(x - ANCHOR_X, 1) for x in f] for f in feet],
                      "A_ANCHOR": [ANCHOR_X, BASELINE]})
    return {"scale": round(scale, 4), "advance": adv, "feet": feet}


def bob(k: int, n: int) -> int:
    """달리기 k장의 윗몸 내려앉음 (캔버스 픽셀, 0 = 가장 높음). 한 바퀴에 두 번 부드럽게."""
    return round(BOB * 0.5 * (1.0 - np.cos(2.0 * np.pi * 2.0 * k / n)))


def _shift(img: Image.Image, dx: int, dy: int) -> Image.Image:
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (dx, dy))
    return out


def _upper_cut(mask: np.ndarray) -> int:
    rows = np.nonzero(mask.any(axis=1))[0]
    return rows[-1] - int((rows[-1] - rows[0]) * LEG_SHARE)


def _compose_run(upper: Image.Image, cut: int, legs: Image.Image, down: int) -> Image.Image:
    """윗몸(cut 줄 위, down만큼 내려) 위에 덮고, 그 아래는 다리 층. cut 위 SEAM 줄은 윗몸이 점점 옅어지며 섞임."""
    up = np.asarray(_shift(upper, 0, down)).astype(float)
    lg = np.asarray(legs).astype(float)
    lg[:cut + down - SEAM] = 0.0  # 다리 층의 윗몸 부분은 버림 (윗몸 밖으로 비쳐 겹쳐 보임)
    w = np.zeros(up.shape[0])
    c = cut + down
    w[:c - SEAM] = 1.0
    w[c - SEAM:c] = np.linspace(1.0, 0.0, SEAM)
    w = w[:, None, None]
    ua, la = up[..., 3:] / 255.0 * w, lg[..., 3:] / 255.0
    a = ua + la * (1.0 - ua)
    rgb = (up[..., :3] * ua + lg[..., :3] * la * (1.0 - ua)) / np.maximum(a, 1e-6)
    return Image.fromarray(np.dstack([rgb, a * 255.0]).round().clip(0, 255).astype(np.uint8))


def _collar(base: Image.Image) -> Image.Image:
    """윗몸 그림의 목걸이·방울(빨강·금색 덩어리 + 둘레 3px)만 남긴 그림. 방울이 윗몸·다리 경계(cut)에 걸쳐 아래 절반이
    장마다 다른 그림에서 오면 깜빡여서(motion2 4차 검토) 합친 뒤 맨 위에 덮는다."""
    a = np.asarray(base).astype(int)
    solid = a[..., 3] > 200
    red = solid & (a[..., 0] > 170) & (a[..., 1] < 90) & (a[..., 2] < 90)
    gold = solid & (a[..., 0] > 190) & (a[..., 1] > 150) & (a[..., 2] < 80)
    mask = np.zeros(red.shape, bool)
    for part in (red, gold):
        labels, n = ndimage.label(part)
        if n:
            sizes = ndimage.sum(part, labels, range(1, n + 1))
            big = labels == int(np.argmax(sizes)) + 1
            mask |= big
    # 금색 중 가장 큰 덩어리가 방울이 아닐 수 있어 목걸이 아래 끝 가까이의 금색도 넣음
    rows = np.nonzero(red.any(axis=1))[0]
    near = np.zeros(red.shape, bool)
    near[rows[-1] - 10:rows[-1] + 30] = True
    mask |= gold & near & ndimage.binary_dilation(red, iterations=24)
    mask = ndimage.binary_dilation(mask, iterations=3) & (a[..., 3] > 0)
    out = np.asarray(base).copy()
    out[~mask] = 0
    return Image.fromarray(out)


def _with_collar(img: Image.Image, collar: Image.Image, down: int) -> Image.Image:
    out = img.copy()
    out.alpha_composite(_shift(collar, 0, down))
    return out


def _foot_part(mask: np.ndarray, x: float, others: list) -> tuple:
    """발 x에서 위로 올라가며, 다른 발과 붙기 전까지의 다리 덩어리 (위 줄, 덩어리 마스크 [위 줄:BASELINE])."""
    best = None
    for h in range(4, 44, 2):
        labels, _ = ndimage.label(mask[BASELINE - h:BASELINE])
        lab = labels[-1, int(round(x))] or labels[-2, int(round(x))]
        if not lab or any(labels[-1, int(round(o))] == lab or labels[-2, int(round(o))] == lab for o in others):
            break
        best = (BASELINE - h, labels == lab)
    return best


def _shear_legs(img: Image.Image, moves: dict) -> Image.Image:
    """moves = {디딘 발 x: 옮길 거리}. 그 발의 다리 덩어리(다른 발과 붙기 전까지)를 위 끝 0 → 발끝 전부로 비스듬히 옮김
    (다리가 엉덩이·어깨를 축으로 조금 더 기운 것처럼 보임)."""
    arr = np.asarray(img).copy()
    mask = arr[..., 3] > 128
    feet = contacts(img)
    out = arr.copy()
    parts = []
    for x, d in moves.items():
        found = _foot_part(mask, x, [o for o in feet if abs(o - x) > 3.0])
        if found and abs(d) >= 0.5:
            parts.append((found, d))
    for (y0, part), _ in parts:
        out[y0:BASELINE][part] = 0
    for (y0, part), d in parts:
        h = part.shape[0]
        for r in range(h):
            cols = np.nonzero(part[r])[0]
            if cols.size:
                dst = np.clip(cols + int(round(d * (r + 1) / h)), 0, arr.shape[1] - 1)
                out[y0 + r, dst] = arr[y0 + r, cols]
    return Image.fromarray(out)


def _tracks(feet: list, adv: float) -> list:
    """디딘 발 이어 붙이기: 장 k의 발 x가 장 k-1의 발에서 adv만큼 뒤(TRACK_MATCH 안)면 같은 발. [(장, 발 x), ...] 목록들."""
    n = len(feet)
    owner = {}
    tracks = []
    for k in range(2 * n):  # 한 바퀴를 두 번 돌아 바퀴 끝 → 처음 이음
        kk = k % n
        used = set()  # 이전 장의 발은 한 번만 (같은 발을 두 번 고르면 다른 발이 한 트랙에 섞임, Codex 리뷰)
        for x in feet[kk]:
            prev = [(t, px) for (pk, px), t in owner.items() if pk == (k - 1) and t not in used]
            best = min(prev, key=lambda a: abs(a[1] - adv - x), default=None)
            if best is not None and abs(best[1] - adv - x) <= TRACK_MATCH:
                used.add(best[0])
                tracks[best[0]].append((k, x))
                owner[(k, x)] = best[0]
            else:
                tracks.append([(k, x)])
                owner[(k, x)] = len(tracks) - 1
    return tracks


def _leg_moves(feet: list, adv: float) -> list:
    """장마다 디딘 발을 옮길 거리 {x: d}: 한 발이 디딘 동안 세계 x(= 발 x + 장 x adv)가 같게 (그 발의 가운데값으로).
    두 번째 바퀴(n~2n-1)의 결과를 씀 (첫 바퀴는 바퀴 끝에서 이어 온 발이 없어서)."""
    n = len(feet)
    moves = [dict() for _ in range(n)]
    for tr in _tracks(feet, adv):
        world = [x + k * adv for k, x in tr]
        mid = float(np.median(world))
        for (k, x), w in zip(tr, world):
            if n <= k < 2 * n or (k < n and not any(kk == k + n for kk, _ in tr)):
                d = float(np.clip(mid - w, -LEG_NUDGE, LEG_NUDGE))
                moves[k % n][x] = d
    return moves


def cut_a2(src: Path, air_sheet: Path, a_dir: Path) -> dict:
    """src = 예전 A 달리기 8장 (assets/raw/kitten_motion/a_run8, 걸음 안내도대로 그린 2차 시트에서 자른 것)."""
    n = len(list(src.glob("run_*.png")))
    base = Image.open(src / "run_0.png").convert("RGBA")
    base_mask = opaque(base)
    cut = _upper_cut(base_mask)
    ref_upper = _upper(base_mask)
    legs = [Image.open(src / f"run_{k}.png").convert("RGBA") for k in range(n)]
    feet = [contacts(l) for l in legs]
    # 사이 장: 예전 장 하나를 SUB장으로. 디딘 다리만 장마다 adv/SUB씩 더 뒤로 기울이고(들린 다리는 그대로) 윗몸은 BOB 박자대로.
    # 장마다 거리 adv: 그렇게 만든 그림을 발 미끄러짐 검사(foot_slip)로 재서 가장 작은 값.
    # 디딘 발 수가 바뀌면(두 발이 한 덩어리로 붙음) 버림. 950px/초에서도 SPEED_FRAMES장/초 안(장을 건너뛰어도 디딘 발은 제자리지만 다리가 깜빡임)
    import foot_slip  # 여기서만 (foot_slip이 이 파일을 읽음)

    def frames(a: float) -> list:
        mv = _leg_moves(feet, a)
        return [_shear_legs(legs[k], {x: d - j * a / SUB for x, d in mv[k].items()} | {x: -j * a / SUB for x in feet[k] if x not in mv[k]})
                for k in range(n) for j in range(SUB)]

    def score(a: float) -> float:
        fixed = [contacts(f) for f in frames(a)]
        if [len(f) for f in fixed] != [len(feet[i // SUB]) for i in range(n * SUB)]:
            return float("inf")
        k = foot_slip.KITTEN_PX  # 검사와 같은 게임 픽셀로
        game = [[(x - ANCHOR_X) * k for x in f] for f in fixed]
        return max(foot_slip.slip(game, a * n * k, v, advance=[a / SUB * k] * (n * SUB)) for v in foot_slip.SPEEDS)

    adv = float(min(np.arange(ADV_MIN, ADV_MAX + 0.01, 0.5), key=score))
    if not np.isfinite(score(adv)):
        raise ValueError("모든 장 거리 후보에서 디딘 발 수가 바뀜 (두 발이 붙음): LEG_NUDGE·TRACK_MATCH 확인")
    keep = _collar(base)
    out = {f"run_{i}": _with_collar(_compose_run(base, cut, f, bob(i, n * SUB)), keep, bob(i, n * SUB))
           for i, f in enumerate(frames(adv))}
    n *= SUB
    adv /= SUB
    feet = [contacts(out[f"run_{k}"]) for k in range(n)]
    # 공중·특수 자세
    air = _pieces(air_sheet, A2_AIR)
    old_crouch = opaque(Image.open(a_dir / "crouch.png")).sum()
    ascale = (old_crouch / float(opaque(air["crouch_b"]).sum())) ** 0.5
    cy, cx = [float(v.mean()) for v in np.nonzero(base_mask)]
    for name in A2_AIR:
        img = _small(air[name], ascale)
        m = opaque(img)
        rows = np.nonzero(m.any(axis=1))[0]
        if name in A2_SPIN:
            my, mx = [float(v.mean()) for v in np.nonzero(m)]
            out[name] = _paste(img, round(cx - mx), round(cy - my))
            continue
        y = BASELINE - (rows[-1] + 1)
        first = _paste(img, ANCHOR_X - img.width // 2, y)
        if name in A2_GROUND:
            dx, _ = _best_shift(ref_upper, _upper(opaque(first)), range(0, 1))
            out[name] = _paste(img, ANCHOR_X - img.width // 2 + dx, y)
        else:
            dx, dy = _best_shift(ref_upper, _upper(opaque(first)), range(-40, 41, 2))
            out[name] = _paste(img, ANCHOR_X - img.width // 2 + dx, y + dy)
    for name, img in out.items():
        img.save(a_dir / f"{name}.png")
    _write_data("A", {"A_ADVANCE": [round(float(adv), 2)] * n, "A_FEET": [[round(x - ANCHOR_X, 1) for x in f] for f in feet],
                      "A_ANCHOR": [ANCHOR_X, BASELINE]})
    return {"air_scale": round(ascale, 4), "advance": float(adv), "feet": feet}


def _leg_points(mask: np.ndarray) -> tuple:
    """다리 그림 → (축 x, 축 y, 발 y)."""
    rows = np.nonzero(mask.any(axis=1))[0]
    top_cols = np.nonzero(mask[rows[0]:rows[0] + max(4, (rows[-1] - rows[0]) // 4)].any(axis=0))[0]
    width = top_cols[-1] - top_cols[0]
    return float((top_cols[0] + top_cols[-1]) / 2), float(rows[0] + width * PIVOT_IN), float(rows[-1] + 1)


def cut_b(sheet: Path, out_dir: Path, a_dir: Path) -> dict:
    raw = _pieces(sheet, B_NAMES)
    target = opaque(Image.open(a_dir / "startle.png")).sum()
    scale = (target / float(opaque(raw["assembled"]).sum())) ** 0.5
    out_dir.mkdir(parents=True, exist_ok=True)
    parts = {}
    for name, img in raw.items():
        small = _small(img, scale)
        box = opaque(small)
        rows, cols = np.nonzero(box.any(axis=1))[0], np.nonzero(box.any(axis=0))[0]
        crop = small.crop((cols[0] - PAD, rows[0] - PAD, cols[-1] + 1 + PAD, rows[-1] + 1 + PAD))
        crop.save((Path(__file__).parent.parent / "review/cat-parade/motion/b_assembled.png") if name == "assembled" else out_dir / f"{name}.png")
        parts[name] = crop
    data = {}
    lengths = []
    for leg in B_LEGS:
        px, py, foot = _leg_points(opaque(parts[leg]))
        data[leg] = [round(px, 1), round(py, 1)]
        lengths.append(foot - py)
    tw, th = parts["torso"].size
    hb = opaque(parts["head"])
    hrows = np.nonzero(hb.any(axis=1))[0]
    neck_cols = np.nonzero(hb[hrows[-1] - 6:hrows[-1]].any(axis=0))[0]
    tb = opaque(parts["tail"])
    trows = np.nonzero(tb.any(axis=1))[0]
    root_cols = np.nonzero(tb[trows[-1] - 6:trows[-1]].any(axis=0))[0]
    out = {
        "B_SIZE": {n: list(parts[n].size) for n in B_NAMES if n != "assembled"},
        "B_PIVOT": {**data, "head": [round(float(neck_cols.mean()), 1), float(hrows[-1] - 4)],
                    "head_surprised": [round(float(neck_cols.mean()), 1), float(hrows[-1] - 4)],
                    "tail": [round(float(root_cols.mean()), 1), float(trows[-1] - 4)]},
        "B_PLACE": {k: [round(v[0] * tw, 1), round(v[1] * th, 1)] for k, v in B_PLACE.items()},
        "B_LEG_LEN": round(float(np.mean(lengths)), 1),
        "B_FAR_SHIFT": FAR_SHIFT,
    }
    rest = compose(parts, out)
    rest.save(Path(__file__).parent.parent / "review/cat-parade/motion/b_rest.png")
    # 조립한 몸이 A 멈칫과 같은 넓이가 되게 게임이 부품을 이만큼 키워 그린다
    out["B_ART"] = round((target / float(opaque(rest).sum())) ** 0.5, 4)
    _write_data("B", out)
    return {"scale": round(scale, 4), "leg_len": out["B_LEG_LEN"], "torso": [tw, th], "art": out["B_ART"]}


def compose(parts: dict, d: dict) -> Image.Image:
    """서 있는 조립 모습 (다리 곧게, 그리는 순서 = 게임과 같음). 조립 자리 맞추기·크기 재기용."""
    canvas = Image.new("RGBA", (400, 320), (0, 0, 0, 0))
    o = (100, 80)
    pl, pv, far = d["B_PLACE"], d["B_PIVOT"], d["B_FAR_SHIFT"]
    order = [("hind_far", (pl["hind"][0] + far, pl["hind"][1])), ("front_far", (pl["front"][0] + far, pl["front"][1])),
             ("tail", pl["tail"]), ("hind_near", pl["hind"]), ("front_near", pl["front"]), ("head", pl["neck"]), ("torso", None)]
    for name, at in order:
        x, y = (o[0], o[1]) if at is None else (round(o[0] + at[0] - pv[name][0]), round(o[1] + at[1] - pv[name][1]))
        canvas.alpha_composite(parts[name], (x, y))
    return canvas


def _gd(value) -> str:
    if isinstance(value, dict):
        return "{" + ", ".join(f'"{k}": {_gd(v)}' for k, v in value.items()) + "}"
    if isinstance(value, (list, tuple)):
        return "[" + ", ".join(_gd(v) for v in value) + "]"
    return repr(float(value)) if isinstance(value, float) else str(value)


def _write_data(part: str, consts: dict) -> None:
    """scripts/logic/kitten_motion_data.gd의 part(A·B) 칸을 바꿔 쓴다 (다른 칸은 그대로)."""
    text = DATA.read_text() if DATA.exists() else (
        "class_name KittenMotionData\n## 아기 움직임 측정값 (tools/cut_kitten_motion.py가 씀, 손으로 고치지 마)\n"
        "## A_: 캔버스 픽셀 (발끝 원점 기준 x), B_: 부품 그림 픽셀\n\n# A 시작\n# A 끝\n\n# B 시작\n# B 끝\n")
    body = "".join(f"const {k} := {_gd(v)}\n" for k, v in consts.items())
    text = re.sub(rf"# {part} 시작\n.*?# {part} 끝\n", f"# {part} 시작\n{body}# {part} 끝\n", text, flags=re.S)
    DATA.write_text(text)


if __name__ == "__main__":
    if len(sys.argv) == 5 and sys.argv[1] == "a2":
        print(cut_a2(Path(sys.argv[2]), Path(sys.argv[3]), Path(sys.argv[4])))
        sys.exit()
    if len(sys.argv) != 4 or sys.argv[1] not in ("a", "b"):
        sys.exit(__doc__)
    if sys.argv[1] == "a":
        print(cut_a(Path(sys.argv[2]), Path(sys.argv[3])))
    else:
        print(cut_b(Path(sys.argv[2]), Path(sys.argv[3]), Path(sys.argv[3]).parent / "cheese_a"))
