"""아기 움직임(방식 A, motion2): 아기마다 Codex 시트를 게임 그림으로 자르고 재는 도구. 결과는 assets/sprites/kitten_motion/<품종>/.

사용 (한 아기를 처음부터, 차례대로):
  python3 tools/cut_kitten_motion.py frames <품종> <달리기 시트>  달리기 8장 + 웅크림·도약·오름·내림·착지·멈칫 (+ assets/raw/kitten_motion/<품종>_run8/)
  python3 tools/cut_kitten_motion.py a2 <품종> <공중 시트>         달리기 32장 + 공중 자세 13장, 장마다 거리를 kitten_motion_data.gd에
  python3 tools/cut_kitten_motion.py scared <품종> <놀람 시트>     놀란 윗몸(달리기 위에 덮음)·놀라 움츠림·깜짝 펄쩍
frames (예전 A)
- 크기: 달리기 8장 불투명 넓이 가운데값을 cut_kittens.RUN_AREA로 (예전 아기와 같은 크기).
- 위치: bbox가 아니라 몸통 기준. 다리를 뺀 윗몸(아래 LEG_SHARE를 뺀 부분)을 달리기 1장과 가장 많이 겹치게 옮긴다.
  땅 자세는 발끝(가장 아랫줄)을 BASELINE에, 오름·내림은 윗몸을 가로·세로 모두 달리기 1장에 맞춘다.
a2 (motion2, 2026-11-16)
- 달리기: 윗몸(머리·몸통·꼬리)은 예전 run_0 한 장을 모든 장에 그대로 쓰고(머리 떨림 없음), 다리는 예전 장의 것을 그 밑에 깐다.
  윗몸은 걸음 박자(한 바퀴 2번)에 맞춰 BOB 픽셀만 오르내린다. 디딘 다리는 다리끼리 떨어진 줄 아래를 비스듬히 옮겨(최대 LEG_NUDGE)
  디딘 동안 발의 세계 x가 같게 맞춘다 (AI 그림의 발 자리 어긋남을 지움).
- 공중 13장: 크기는 웅크림2를 지금 웅크림 넓이에, 땅 자세(웅크림2·도약2)는 발끝을 BASELINE에, 공중은 윗몸을 run_0에 맞춤,
  앞구르기 공·말기는 몸 무게중심을 run_0 무게중심에 (게임이 그 언저리를 축으로 돌림).
scared (2026-11-17)
- 놀란 달리기 칸을 run_0 윗몸에 크기(넓이)·자리(윗몸 겹침)를 맞춰, 달리기와 같은 윗몸 자르기로 scared_upper.png를 만든다.
  게임은 도망 달리기 때 달리기 그림 위에 이것을 같은 오르내림(BOB)만큼 내려 덮는다 (32장을 또 만들지 않음).
  놀란 윗몸이 비는 곳은 원래 윗몸을 깔아 덮었을 때 웃는 윗몸이 비치지 않게.
- 움츠림은 땅 자세처럼, 펄쩍은 발끝을 BASELINE에 두고 무게중심 x를 run_0에 맞춤.
개발용 도구 (numpy, scipy, Pillow).
"""
import shutil
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
# 아기별 같은 발 어긋남. 턱시도: 20은 한 장에 33px 옮긴 발을 새 발로 봐 못 고침(미끄러짐 14px) → 24로 5~6px.
# 회색: 20·24는 다른 발까지 한 발로 이어 옮기다 두 발이 붙음(모든 장 거리 실패) → 16으로 3.5~3.9px
TRACK_MATCH_OF = {"tuxedo": 24.0, "gray": 16.0}
SUB = 4               # 예전 장 하나를 사이 장 몇 장으로 (8 x 4 = 32장, 3은 앞발이 4~6px 밀림 motion2 검토)
ADV_MAX = 34.0        # 상한 (한 바퀴 160 게임 픽셀: 주인공 150과 비슷, 더 길면 짧은 다리로 성큼성큼)
ADV_MIN = 18.0        # 예전 장 하나의 거리 하한 (캔버스 픽셀). 22는 디딘 발이 바닥보다 약 10% 앞으로 밀림 (motion2 3차 검토)
LEG_NUDGE = 14        # 디딘 다리 발끝을 옮겨도 되는 최대 (캔버스 픽셀)

HEAD_SHARE = 0.55     # 놀란 윗몸에서 놀란 그림을 쓰는 오른쪽(머리) 비율
HEAD_BLEND = 12.0     # 그 경계를 섞는 폭 (캔버스 픽셀)
SCARED = ["scared_run", "scared_crouch", "scared_hop"]  # 놀람 시트 칸 순서

ROOT = Path(__file__).parent.parent
DATA = ROOT / "scripts/logic/kitten_motion_data.gd"
RAW = ROOT / "assets/raw/kitten_motion"
SPRITES = ROOT / "assets/sprites/kitten_motion"


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
    return {"scale": round(scale, 4), "advance": advances(feet), "feet": feet}


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
    if not red.any():
        return Image.new("RGBA", base.size)  # 목걸이·나비넥타이가 없는 아기
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


def _tracks(feet: list, adv: float, match: float = TRACK_MATCH) -> list:
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
            if best is not None and abs(best[1] - adv - x) <= match:
                used.add(best[0])
                tracks[best[0]].append((k, x))
                owner[(k, x)] = best[0]
            else:
                tracks.append([(k, x)])
                owner[(k, x)] = len(tracks) - 1
    return tracks


def _leg_moves(feet: list, adv: float, match: float = TRACK_MATCH) -> list:
    """장마다 디딘 발을 옮길 거리 {x: d}: 한 발이 디딘 동안 세계 x(= 발 x + 장 x adv)가 같게 (그 발의 가운데값으로).
    두 번째 바퀴(n~2n-1)의 결과를 씀 (첫 바퀴는 바퀴 끝에서 이어 온 발이 없어서)."""
    n = len(feet)
    moves = [dict() for _ in range(n)]
    for tr in _tracks(feet, adv, match):
        world = [x + k * adv for k, x in tr]
        mid = float(np.median(world))
        for (k, x), w in zip(tr, world):
            if n <= k < 2 * n or (k < n and not any(kk == k + n for kk, _ in tr)):
                d = float(np.clip(mid - w, -LEG_NUDGE, LEG_NUDGE))
                moves[k % n][x] = d
    return moves


def cut_a2(breed: str, air_sheet: Path) -> dict:
    """달리기 8장(frames가 assets/raw/kitten_motion/<품종>_run8에 둔 것, 걸음 안내도대로 그린 시트) + 공중 시트 → 32장 + 공중 13장."""
    src, a_dir = RAW / f"{breed}_run8", SPRITES / breed
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
        mv = _leg_moves(feet, a, TRACK_MATCH_OF.get(breed, TRACK_MATCH))
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
    _write_data(breed, round(float(adv), 3), n)
    return {"air_scale": round(ascale, 4), "advance": float(adv), "feet": feet}


def cut_frames(breed: str, sheet: Path) -> dict:
    """달리기 시트 → 예전 A 그림 (달리기 8장은 a2의 재료로 RAW/<품종>_run8에도)."""
    out = SPRITES / breed
    r = cut_a(sheet, out)
    run8 = RAW / f"{breed}_run8"
    run8.mkdir(parents=True, exist_ok=True)
    for i in range(8):
        shutil.copy(out / f"run_{i}.png", run8 / f"run_{i}.png")
    return r


def cut_scared(breed: str, sheet: Path) -> dict:
    """놀람 시트 (놀란 달리기·움츠림·펄쩍) → scared_upper·scared_crouch·scared_hop."""
    out = SPRITES / breed
    base = Image.open(RAW / f"{breed}_run8" / "run_0.png").convert("RGBA")  # 달리기 32장 윗몸의 원본
    bm = opaque(base)
    ref_upper = _upper(bm)
    raw = _pieces(sheet, SCARED)
    scale = (bm.sum() / float(opaque(raw["scared_run"]).sum())) ** 0.5
    imgs = {n: _small(img, scale) for n, img in raw.items()}

    def ground(img: Image.Image) -> tuple:
        rows = np.nonzero(opaque(img).any(axis=1))[0]
        return ANCHOR_X - img.width // 2, BASELINE - (rows[-1] + 1)

    x, y = ground(imgs["scared_run"])
    dx, dy = _best_shift(ref_upper, _upper(opaque(_paste(imgs["scared_run"], x, y))), range(-20, 21))
    face = _paste(imgs["scared_run"], x + dx, y + dy)
    under = base.copy()
    under.alpha_composite(face)  # 놀란 윗몸이 비는 곳은 원래 윗몸 (덮었을 때 웃는 윗몸이 비치지 않게)
    # 머리 쪽(윗몸 오른쪽 HEAD_SHARE)만 놀란 그림, 그 왼쪽(등·꼬리)은 원래 윗몸 그대로: 꼬리 자리가 조금 달라 두 꼬리 테두리가 겹쳐 보임
    cols = np.nonzero(ref_upper.any(axis=0))[0]
    xh = cols[-1] - (cols[-1] - cols[0]) * HEAD_SHARE
    w = np.clip((np.arange(CANVAS[0]) - xh) / HEAD_BLEND + 0.5, 0.0, 1.0)[None, :, None]
    under = Image.fromarray((np.asarray(under).astype(float) * w + np.asarray(base).astype(float) * (1.0 - w)).round().astype(np.uint8))
    upper = _with_collar(_compose_run(under, _upper_cut(bm), Image.new("RGBA", CANVAS), 0), _collar(face), 0)
    upper.save(out / "scared_upper.png")
    x, y = ground(imgs["scared_crouch"])
    cdx, _ = _best_shift(ref_upper, _upper(opaque(_paste(imgs["scared_crouch"], x, y))), range(0, 1))
    _paste(imgs["scared_crouch"], x + cdx, y).save(out / "scared_crouch.png")
    x, y = ground(imgs["scared_hop"])
    hx = float(np.nonzero(opaque(imgs["scared_hop"]))[1].mean())
    _paste(imgs["scared_hop"], round(float(np.nonzero(bm)[1].mean()) - hx), y).save(out / "scared_hop.png")
    return {"scale": round(scale, 4), "upper_shift": [dx, dy], "uncovered": int((bm & ~opaque(face)).sum())}


def _write_data(breed: str, adv: float, n: int) -> None:
    """scripts/logic/kitten_motion_data.gd를 다시 쓴다 (다른 아기의 장마다 거리는 그대로)."""
    import re
    old = dict(re.findall(r'"(\w+)": ([\d.]+)', DATA.read_text().split("const ADVANCE", 1)[-1])) if DATA.exists() else {}
    old[breed] = adv
    body = ", ".join(f'"{k}": {float(v)}' for k, v in sorted(old.items()))
    DATA.write_text(
        "class_name KittenMotionData\n## 아기 움직임 측정값 (tools/cut_kitten_motion.py가 씀, 손으로 고치지 마). 캔버스 픽셀\n\n"
        f"const ANCHOR := [{ANCHOR_X}, {BASELINE}]  # 발끝 원점\n"
        f"const RUN_FRAMES := {n}\n"
        f"## 달리기 장마다 윗몸이 내려앉은 만큼 (놀란 윗몸을 같이 내려 덮음)\n"
        f"const BOB := [{', '.join(str(bob(i, n)) for i in range(n))}]\n"
        f"## 품종 → 달리기 장마다 거리 (아기가 이만큼 달리면 다음 장)\n"
        f"const ADVANCE := {{{body}}}\n")


if __name__ == "__main__":
    steps = {"frames": cut_frames, "a2": cut_a2, "scared": cut_scared}
    if len(sys.argv) != 4 or sys.argv[1] not in steps:
        sys.exit(__doc__)
    print(steps[sys.argv[1]](sys.argv[2], Path(sys.argv[3])))
