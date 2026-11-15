"""아기 움직임 비교(cat-parade 1단계): 치즈 아기 A 프레임 시트·B 조각 시트를 게임 그림으로 자르고 재는 도구.

사용: python3 tools/cut_kitten_motion.py a <시트.png> <출력 폴더>   (A: 달리기 8장 + 웅크림·도약·오름·내림·착지·멈칫)
      python3 tools/cut_kitten_motion.py b <시트.png> <출력 폴더>   (B: 몸통·머리·놀란 머리·다리 4·꼬리 + 조립 참고)
A
- 크기: 달리기 8장 불투명 넓이 가운데값을 cut_kittens.RUN_AREA로 (예전 아기와 같은 크기).
- 위치: bbox가 아니라 몸통 기준. 다리를 뺀 윗몸(아래 LEG_SHARE를 뺀 부분)을 달리기 1장과 가장 많이 겹치게 옮긴다.
  땅 자세는 발끝(가장 아랫줄)을 BASELINE에, 오름·내림은 윗몸을 가로·세로 모두 달리기 1장에 맞춘다.
- 발: 각 장에서 BASELINE 위 CONTACT_ROWS줄 안의 불투명 덩어리 = 바닥을 디딘 발. 장 k → k+1에서 디딘 발이 뒤로 간 거리의
  가운데값을 advance[k]로 (게임은 아기가 이만큼 달리면 다음 장으로 넘김 → 디딘 발이 세계에서 제자리).
- 결과: <출력>/<이름>.png, 그리고 scripts/logic/kitten_motion_data.gd(측정값, 게임이 읽음)의 A 부분.
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
    if len(sys.argv) != 4 or sys.argv[1] not in ("a", "b"):
        sys.exit(__doc__)
    if sys.argv[1] == "a":
        print(cut_a(Path(sys.argv[2]), Path(sys.argv[3])))
    else:
        print(cut_b(Path(sys.argv[2]), Path(sys.argv[3]), Path(sys.argv[3]).parent / "cheese_a"))
