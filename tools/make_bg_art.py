"""v0.8.0 1-1 카툰 그림 (Codex 마젠타 시트, assets/concept/cartoon/v08/) → 게임 그림.

사용: python3 tools/make_bg_art.py            # 모두 만들고 크기·상수를 출력
      python3 tools/make_bg_art.py --pencil   # 처음 한 번: 덮어쓸 예전 그림을 <폴더>_pencil/로 복사 (이미 있으면 건너뜀)
- 예전 그림 파일 자리를 카툰으로 덮어쓴다 (Godot uid·preload 그대로). 예전 그림은 <폴더>_pencil/ (시험 단추 "배경 화풍").
- 장애물·소품·아이템: 예전 캔버스 크기 안에 비율 그대로 넣는다(장애물·소품은 바닥 가운데, 아이템은 가운데) →
  게임이 그리는 너비·높이와 판정의 관계가 예전과 같다.
- 건물: 세 건물을 같은 높이(예전 198px)로 줄이고, 왼쪽·오른쪽 캡은 벽 바깥선이 그림 끝에서 OVERHANG(9px) 안쪽에 오게 자른다.
  가운데 조각은 장식(짙은 선)이 없는 세로줄(민벽)에서만 자른다. 조각 수가 모자라면 민벽 조각을 더한다.
- 선: #331806보다 어두운 픽셀은 #331806으로 (먼 배경·구름은 색 있는 선이라 그대로).
- 적: assets/sprites/enemies/<적>/ 에 같은 캔버스·같은 발 기준점, 게임 크기의 2배로 저장 (게임은 0.5배로 그림).
개발용 도구 (numpy, scipy, Pillow). 게임은 결과 PNG만 쓴다.
"""
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cartoon_art import LINE, cutout, lum  # noqa: E402
from clean_edges import clean  # noqa: E402
from make_hero_frames import darken_fix, thicken  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/concept/cartoon/v08"
SPR = ROOT / "assets/sprites"
OVERHANG = 9      # BuildingLayout.OVERHANG: 옥상 턱이 벽보다 튀어나온 폭
FOOT_SINK = 16    # world_view.gd FOOT_SINK: 고양이 발을 옥상 충돌선(그림 맨 윗줄)보다 이만큼 아래에 그림
BUILDING_H = 198  # 예전 건물 조각 높이
FAR = 0.75        # 먼 배경·구름 배율 (선 3.3px, 예전 먼 동네 높이와 비슷)
# 적 게임 키 (px, 기본 자세): 졸개 = 시안 크기, 쥐 = 시안 50px의 1.5배 (폰 0.54배에서 40px 이상)
ENEMY_H = {"crow": 84, "rat": 75}
POLE_THIN = 2     # 전봇대는 판 너비 140~240px로 그림 1배 안팎이라 시트 선(약 7px)이 너무 굵음 → 안쪽에서 2px·바깥에서 1px 깎음 (안쪽 선이 남게). 화면 바깥선: 판 140px 2.5 / 183px 4.0 / 240px 5.0
ENEMY_FILE_SCALE = 2  # 적 그림은 게임 크기의 2배로 저장
ENEMY_THICKEN = {"crow": 1, "rat": 1}  # 2배 파일 px (한쪽). 바깥선 졸개 2.8 → 3.3, 쥐 2.1 → 3.1 (14-1 3.5±0.75)

# 덮어쓰는 예전 그림 (--pencil이 <폴더>_pencil/로 복사)
REPLACED = ["backdrop/far_town.png"] + [f"backdrop/cloud{i}.png" for i in range(1, 5)] + \
    [f"buildings/{s}_{p}.png" for s, ps in (("brick", "l m0 m1 r"), ("villa", "l m0 m1 m2 r"), ("tile", "l m0 m1 r")) for p in ps.split()] + \
    [f"buildings/prop_soft_{n}.png" for n in ("chimney", "antenna", "railing")] + \
    [f"obstacles/{n}.png" for n in ("pot", "ac", "tank", "sign")] + \
    ["structures/pole.png"] + [f"structures/trampoline_{n}.png" for n in ("rest", "pressed", "launch")] + \
    [f"items/{n}.png" for n in ("fish", "fish_0", "gold", "cookie", "bell")]


def thin(rgba, r, up=4, outer=0):
    """선을 안쪽에서 r px 깎는다: 선 픽셀 중 칠한 면에서 r px 안에 있는 것을 가장 가까운 면 색으로 (바깥 테두리는 그대로).
    작은 시트 그림을 크게 쓰는 전봇대처럼 선이 화면에서 너무 굵어지는 그림용. 계단이 생기지 않게 up배로 키워 깎고 다시 줄인다."""
    big = np.asarray(Image.fromarray(rgba).resize((rgba.shape[1] * up, rgba.shape[0] * up), Image.LANCZOS)).copy()
    op = big[..., 3] > 128
    line = op & (lum(big.astype(float)) < 140)  # 선과 선에 섞인 가장자리 (전봇대·트램펄린 면은 밝기 170 이상)
    fill = op & ~line
    solid = ndi.binary_erosion(fill, iterations=up)  # 색은 섞이지 않은 면 속에서 가져온다
    d = ndi.distance_transform_edt(~fill)
    _, (iy, ix) = ndi.distance_transform_edt(~solid, return_indices=True)
    rep = line & (d <= r * up)
    big[rep, :3] = big[iy[rep], ix[rep], :3]
    if outer:  # 바깥 테두리도 바깥쪽에서 outer px 깎는다 (실루엣을 줄임, 안쪽 선은 그대로)
        keep = ndi.binary_erosion(op, iterations=outer * up)
        big[..., 3] = np.where(keep, big[..., 3], 0)
    return np.asarray(Image.fromarray(big).resize((rgba.shape[1], rgba.shape[0]), Image.LANCZOS))


def figures(sheet, gap=14, min_area=400):
    """시트의 그림 덩어리들 (가까운 조각은 하나로: 반짝임·별·땀방울). [(상자 x0,y0,x1,y1, RGBA 잘라낸 것)] 왼→오, 위→아래."""
    a = cutout(Image.open(SRC / sheet))
    m = a[..., 3] > 40
    lab, n = ndi.label(ndi.binary_dilation(m, iterations=gap))
    out = []
    for i, sl in enumerate(ndi.find_objects(lab), 1):
        part = a[sl].copy()
        part[..., 3][lab[sl] != i] = 0
        ys, xs = np.where(part[..., 3] > 40)
        if len(ys) < min_area:
            continue
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        out.append(((sl[1].start + x0, sl[0].start + y0, sl[1].start + x1, sl[0].start + y1), part[y0:y1, x0:x1]))
    return out


def figures_n(sheet, n, gap=3):
    """칸이 가까워 덩어리끼리 붙는 시트: 가장 큰 덩어리 n개를 칸으로, 나머지 작은 조각(별·땀방울)은 가장 가까운 칸에 붙인다. 왼→오."""
    a = cutout(Image.open(SRC / sheet))
    lab, m = ndi.label(ndi.binary_dilation(a[..., 3] > 40, iterations=gap))
    sizes = ndi.sum(np.ones_like(lab), lab, range(1, m + 1))
    seeds = list(np.argsort(-sizes)[:n] + 1)
    cents = ndi.center_of_mass(np.ones_like(lab), lab, range(1, m + 1))
    group = {s: [s] for s in seeds}
    for i in range(1, m + 1):
        if i not in group and sizes[i - 1] > 30:
            c = cents[i - 1]
            near = min(seeds, key=lambda s: (cents[s - 1][0] - c[0]) ** 2 + (cents[s - 1][1] - c[1]) ** 2)
            group[near].append(i)
    out = []
    for s in seeds:
        mask = np.isin(lab, group[s]) & (a[..., 3] > 0)
        ys, xs = np.where(mask)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        part = a[y0:y1, x0:x1].copy()
        part[..., 3][~mask[y0:y1, x0:x1]] = 0
        out.append(((x0, y0, x1, y1), part))
    return sorted(out, key=lambda f: f[0][0])


def rows(figs, tol=60):
    """세로 위치가 비슷한 것끼리 줄로 묶고 줄 안에서는 왼쪽부터."""
    figs = sorted(figs, key=lambda f: (f[0][1] + f[0][3]) / 2)
    out, cur = [], []
    for f in figs:
        if cur and (f[0][1] + f[0][3]) / 2 - (cur[-1][0][1] + cur[-1][0][3]) / 2 > tol:
            out.append(sorted(cur, key=lambda f: f[0][0]))
            cur = []
        cur.append(f)
    return out + [sorted(cur, key=lambda f: f[0][0])]


def resize(rgba, k):
    """알파를 곱한 색으로 줄여 가장자리에 마젠타 기가 번지지 않게."""
    a = rgba.astype(np.float32)
    pre = np.dstack([a[..., :3] * a[..., 3:4] / 255, a[..., 3]])
    w, h = max(1, round(rgba.shape[1] * k)), max(1, round(rgba.shape[0] * k))
    ch = [np.asarray(Image.fromarray(pre[..., c]).resize((w, h), Image.LANCZOS)) for c in range(4)]
    al = np.clip(ch[3], 0, 255)
    rgb = np.stack(ch[:3], -1) * 255 / np.maximum(al[..., None], 1e-3)
    return np.dstack([np.clip(rgb, 0, 255), al]).astype(np.uint8)


def fit(rgba, size, anchor="bottom", pad=2):
    """캔버스 size 안에 비율 그대로 가장 크게 (pad 여백), anchor = bottom(바닥 가운데) / center."""
    w, h = size
    k = min((w - 2 * pad) / rgba.shape[1], (h - 2 * pad) / rgba.shape[0])
    im = resize(rgba, k)
    canvas = np.zeros((h, w, 4), np.uint8)
    x = (w - im.shape[1]) // 2
    y = h - im.shape[0] if anchor == "bottom" else (h - im.shape[0]) // 2
    canvas[y:y + im.shape[0], x:x + im.shape[1]] = im
    return canvas, k


def save(rgba, rel):
    """저장. 먼 배경(분홍 집·구름 선이 원래 색)이 아니면 가장자리에 남은 마젠타 기를 안쪽 색으로 덮는다 (clean_edges)."""
    if not rel.startswith("backdrop/"):
        rgba = clean(rgba)
    path = SPR / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba).save(path)
    return path


def old_size(rel):
    src = SPR / (str(Path(rel).parent) + "_pencil") / Path(rel).name
    return Image.open(src if src.exists() else SPR / rel).size


def copy_pencil():
    for rel in REPLACED:
        src, dst = SPR / rel, SPR / (str(Path(rel).parent) + "_pencil") / Path(rel).name
        if not dst.exists():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            print("예전 그림 →", dst.relative_to(ROOT))


# --- 먼 배경 ---

def backdrop():
    clouds, town, trees = rows(figures("backdrop_1.png", gap=6, min_area=2000))
    town = max(town, key=lambda f: f[1].shape[1])  # 띠 (폭 전체)
    trees = max(trees, key=lambda f: f[1].shape[1])
    for f, name in ((town, "far_town"), (trees, "trees")):
        band = resize(f[1], FAR)
        band[..., 3] = np.where(band[..., 3] > 8, band[..., 3], 0)
        # 이어 붙이기: 띠 아래 끝 줄은 불투명하게 채운다(그 아래를 같은 색 평면으로 이음)
        save(band, f"backdrop/{name}.png")
        print(f"{name}: {band.shape[1]}x{band.shape[0]}, 맨 아랫줄 색 #{''.join('%02X' % v for v in np.median(band[-3, :, :3], 0).astype(int))}")
    # 구름: 큰 것부터 예전 cloud2 > cloud3 > cloud4 > cloud1 자리 (예전 크기 순서와 같게)
    by_size = sorted(clouds, key=lambda f: -f[1].shape[1])
    for f, i in zip(by_size, (2, 3, 4, 1)):
        c = f[1]  # 구름은 원래 크기 (0.75배면 예전 구름의 2/3로 작아 하늘이 비어 보임, 선 4.5px)
        save(c, f"backdrop/cloud{i}.png")
        print(f"cloud{i}: {c.shape[1]}x{c.shape[0]}")


# --- 건물 ---

def wall_edges(rgba, top):
    """벽 바깥선 왼·오른쪽 x: 옥상 턱 아래 벽 줄들에서 가장 바깥 짙은 픽셀의 가운데값."""
    a = rgba.astype(int)
    h = a.shape[0]
    lefts, rights = [], []
    for y in range(top + (h - top) // 3, h - 10, 5):
        dark = np.where((a[y, :, 3] > 200) & (lum(a[y].astype(float)) < 90))[0]
        if len(dark):
            lefts.append(dark[0])
            rights.append(dark[-1])
    return int(np.median(lefts)), int(np.median(rights))


def ledge_bottom(rgba):
    """옥상 턱 아래 끝 줄 = 가운데 세로줄에서 위에서부터 두 번째로 만나는 짙은 선 띠의 끝."""
    col = rgba[:, rgba.shape[1] // 2].astype(float)
    dark = (col[:, 3] > 200) & (lum(col) < 90)
    runs, y = [], 0
    while y < len(dark):
        if dark[y]:
            s = y
            while y < len(dark) and dark[y]:
                y += 1
            runs.append((s, y))
        y += 1
    return runs[1][1] if len(runs) > 1 else 0


def plain_columns(rgba, top, left, right):
    """장식 없는 세로줄 (짙은 선이 하나도 없는 줄 = 창·등·실외기가 없음. 벽돌 줄눈은 밝아서 괜찮다): 턱 아래 ~ 바닥 위 4px."""
    a = rgba[top + 4: -4].astype(float)
    ok = ~(lum(a) < 110).any(0)
    ok[:left + 6] = False
    ok[right - 5:] = False
    return ok


def buildings():
    figs = sorted(figures("buildings_1.png", gap=6, min_area=5000), key=lambda f: f[0][0])
    assert len(figs) == 3, f"건물 {len(figs)}개"
    names = ["brick", "villa", "tile"]
    mids_want = {"brick": 2, "villa": 3, "tile": 2}
    fills = []
    for (box, part), name in zip(figs, names):
        part = darken_fix(part)
        k = BUILDING_H / part.shape[0]
        im = resize(part, k)
        im[..., 3] = np.where(im[..., 3] > 128, 255, 0)  # 조각 경계가 비치지 않게 (모서리는 선 색이라 각이 안 보임)
        # 시트 건물 아래 끝 테두리 선은 잘라 낸다 (게임은 그림 아래를 벽 색 평면으로 화면 바닥까지 이어 그림: 선이 남으면 벽 가운데 가로줄)
        mid = im[:, im.shape[1] // 2].astype(float)
        cut = im.shape[0]
        while cut > 0 and (mid[cut - 1, 3] < 128 or lum(mid[cut - 1]) < 150):
            cut -= 1
        im = im[:cut - 1]
        # 지붕 턱 윗면(앞에서 본 띠) 가운데에 같은 줄을 끼워 띠 가운데를 FOOT_SINK(16) 줄에 맞춘다 (고양이 발이 띠 가운데에 섬)
        top = ledge_bottom(im)
        mid_row = top // 2
        grow = 2 * FOOT_SINK - top + 2  # 띠 1 ~ top-2줄 → 가운데 = (top + grow) / 2 - 1
        if grow > 0:
            im = np.concatenate([im[:mid_row], np.repeat(im[mid_row:mid_row + 1], grow, 0), im[mid_row:]])
            top += grow
        left, right = wall_edges(im, top)
        # 벽 색 = 맨 아래 위쪽 민벽 줄의 가운데값
        wall = np.median(im[-16:-2, left + 6:right - 5, :3].reshape(-1, 3), 0).astype(int)  # 벽돌은 줄눈보다 벽돌 면이 많음
        fills.append("#%02X%02X%02X" % tuple(wall))
        ok = plain_columns(im, top, left, right)
        runs = []  # 민벽 구간 [시작, 끝)
        x = 0
        while x < len(ok):
            if ok[x]:
                s = x
                while x < len(ok) and ok[x]:
                    x += 1
                runs.append((s, x))
            x += 1
        # 캡: 왼쪽 = 그림 시작을 벽선 - OVERHANG으로, 끝은 첫 민벽 구간 가운데. 오른쪽도 거울
        x0 = left - OVERHANG
        x1 = right + 1 + OVERHANG
        cuts = [(s + e) // 2 for s, e in runs]
        a, b = cuts[0], cuts[-1]
        inner = cuts[1:-1]
        mids = [a] + inner + [b]
        segs = list(zip(mids[:-1], mids[1:]))
        while len(segs) > mids_want[name]:  # 조각이 많으면 가장 좁은 이웃끼리 합친다
            i = min(range(len(segs) - 1), key=lambda j: segs[j + 1][1] - segs[j][0])
            segs[i:i + 2] = [(segs[i][0], segs[i + 1][1])]
        extra = []
        if len(segs) < mids_want[name]:  # 모자라면 창을 자르지 않고 가장 넓은 민벽 구간에서 민벽 조각을 떼어 더한다 (넓은 옥상의 쉼표)
            s, e = max(runs[1:-1] or runs, key=lambda r: r[1] - r[0])
            extra = [(s, e)] * (mids_want[name] - len(segs))
        canvas = np.zeros((im.shape[0], x1 - x0, 4), np.uint8)
        src0 = max(0, x0)
        canvas[:, src0 - x0: src0 - x0 + min(x1, im.shape[1]) - src0] = im[:, src0:min(x1, im.shape[1])]
        pieces = {"l": (0, a - x0)}
        for i, (s, e) in enumerate(segs + extra):
            pieces[f"m{i}"] = (s - x0, e - x0)
        pieces["r"] = (segs[-1][1] - x0, x1 - x0)
        for key, (s, e) in pieces.items():
            save(canvas[:, s:e], f"buildings/{name}_{key}.png")
        print(f"{name}: 배율 {k:.3f}, 턱 아래 {top}, 벽선 {left}~{right}, 벽 색 {fills[-1]}, "
              + ", ".join(f"{k}={e - s}" for k, (s, e) in pieces.items()))
    print("CARTOON_FILLS =", fills)


# --- 옥상 사물 ---

def props():
    figs = figures("props_1.png", gap=10, min_area=3000)
    # 윗줄: 물탱크(왼쪽, 아주 김)·화분·실외기·간판, 아랫줄: 굴뚝·안테나·난간
    tank = max(figs, key=lambda f: f[1].shape[0])
    top, bottom = rows([f for f in figs if f is not tank], tol=120)
    named = dict(zip(["pot", "ac", "sign"], top))
    named["tank"] = tank
    named.update(zip(["chimney", "antenna", "railing"], bottom))
    for n in ("pot", "ac", "tank", "sign"):
        im, k = fit(darken_fix(named[n][1]), old_size(f"obstacles/{n}.png"), pad=0 if n == "sign" else 2)
        if n == "sign":  # 밧줄이 위 끝까지 (게임이 그 위를 선으로 이음)
            im = top_ropes(im)
        save(im, f"obstacles/{n}.png")
        print(f"{n}: {im.shape[1]}x{im.shape[0]} (시트 배율 {k:.3f})")
    for n in ("chimney", "antenna", "railing"):
        im, k = fit(darken_fix(named[n][1]), old_size(f"buildings/prop_soft_{n}.png"))
        save(im, f"buildings/prop_soft_{n}.png")
        print(f"prop_soft_{n}: {im.shape[1]}x{im.shape[0]}")


def top_ropes(im):
    """간판 그림 위에 빈 줄이 있으면 밧줄 맨 윗줄을 위로 늘려 캔버스 위 끝에 닿게."""
    ys = np.where((im[..., 3] > 128).any(1))[0]
    if ys[0] > 0:
        im[:ys[0]] = im[ys[0]]
    return im


# --- 전봇대·트램펄린 ---

def structures():
    figs = figures("structures_1.png", gap=8, min_area=3000)
    pole = max(figs, key=lambda f: f[1].shape[0])
    tramps = sorted([f for f in figs if f is not pole], key=lambda f: f[0][0])
    assert len(tramps) == 3, len(tramps)
    p = np.pad(thin(darken_fix(pole[1]), POLE_THIN, outer=1), ((2, 2), (2, 2), (0, 0)))  # 가장자리 검사(잘림 없음)용 여백
    save(p, "structures/pole.png")
    c = pole_consts(p)
    print(f"pole: {p.shape[1]}x{p.shape[0]}, CARTOON_POLE = {c}")
    # 세 상태 모두 테 폭 209px(x 3~212)·발끝 97행 (예전 TRAMP_SRC_* 상수 그대로). 배율은 가만히 칸 기준으로 같게,
    # 튕김 칸은 솟은 그물 때문에 키가 커서 세로만 캔버스(97px)에 맞게 눌러 넣는다 (0.07초 보이는 칸)
    k = min(209 / tramps[0][1].shape[1], 95 / tramps[0][1].shape[0])  # 위 2px 여백 (가장자리 검사)
    rim_w = round(tramps[0][1].shape[1] * k)
    for f, n in zip(tramps, ("rest", "pressed", "launch")):
        canvas = np.zeros((100, 216, 4), np.uint8)
        part = thin(darken_fix(f[1]), 1)
        im = resize(part, k)
        if im.shape[0] > 95 or im.shape[1] != rim_w:
            im = np.asarray(Image.fromarray(im).resize((rim_w, min(95, im.shape[0])), Image.LANCZOS))
        x = 3 + (209 - rim_w) // 2
        canvas[97 - im.shape[0]:97, x:x + rim_w] = im
        save(canvas, f"structures/trampoline_{n}.png")
        print(f"trampoline_{n}: 배율 {k:.3f}, 그물 가운데 열 {net_rows(canvas)}")


def pole_consts(p):
    """world_view.gd CARTOON_POLE: 통 폭(가장 넓은 줄), 뚜껑 윗면 줄, 머리(통·가로대·애자) 줄 수, 기둥 x·폭."""
    op = p[..., 3] > 128
    widths = op.sum(1)
    drum_w = int(widths[: p.shape[0] // 4].max())
    drum_rows = np.where(widths > drum_w * 0.8)[0]
    trunk_w = int(np.median(widths[p.shape[0] // 2: p.shape[0] * 3 // 4]))
    head = int(np.where(widths[drum_rows[-1]:] <= trunk_w + 2)[0][20]) + drum_rows[-1]  # 가로대·애자 아래로 기둥만 남는 줄
    first = int(np.where(op.any(1))[0][0])
    lid = first + int((drum_rows[0] - first) * 0.5 + 6)
    xs = np.where(op[p.shape[0] * 2 // 3])[0]
    return {"drum_w": drum_w, "lid": lid, "head": head, "trunk_x": int(xs[0]), "trunk_w": int(xs[-1] - xs[0] + 1)}


def net_rows(canvas):
    """가운데 세로줄의 파란 그물 줄 범위 (TRAMP_SRC_NET 고를 때 참고)."""
    col = canvas[:, 108].astype(int)
    blue = np.where((col[:, 3] > 128) & (col[:, 2] > col[:, 0] + 40))[0]
    return (int(blue.min()), int(blue.max())) if len(blue) else None


# --- 아이템 ---

def items():
    figs = sorted(figures("items_1.png", gap=30, min_area=2000), key=lambda f: f[0][0])
    assert len(figs) == 4, len(figs)
    for f, n in zip(figs, ("fish", "gold", "cookie", "bell")):
        part = thicken(np.pad(darken_fix(f[1]), ((4, 4), (4, 4), (0, 0))), 2)
        im, k = fit(part, old_size(f"items/{n}.png"), anchor="center")
        save(im, f"items/{n}.png")
        if n == "fish":
            save(im, "items/fish_0.png")  # 생선 그림 1단계(기본)
        print(f"{n}: {im.shape[1]}x{im.shape[0]}")


# --- 적 ---

def enemies():
    """적 동작 칸: 배율은 첫 칸(기본 자세) 몸 키 = ENEMY_H, 가로는 몸 무게중심을 맞추고 세로는 시트 위치 그대로
    (Codex가 같은 줄에 그려서 칸끼리 몸 높이가 맞음: 날갯짓에 몸이 출렁이지 않게). 캔버스는 모든 칸을 담는 크기(4의 배수),
    기준점(발) = 첫 칸 몸 아래 끝 가운데. 기준점은 출력한다 (게임 상수)."""
    out = {}
    for sheet, enemy, names in (("crow_1.png", "crow", ["fly_0", "fly_1", "fly_2", "fly_3", "dash", "hit"]),
                                ("rats_1.png", "rat", ["run_0", "run_1", "run_2", "run_3", "surprise", "hit"])):
        figs = figures_n(sheet, 6)
        base = body_only(figs[0][1])
        k = ENEMY_H[enemy] * ENEMY_FILE_SCALE / base.shape[0]
        t = ENEMY_THICKEN[enemy]
        placed = []  # (그림, 기준점 기준 왼쪽 위 x, y)
        bx0, by0, bx1, by1 = body_box(figs[0][1])
        foot_sheet_y = figs[0][0][1] + by1  # 첫 칸 몸 아래 끝 (시트 y)
        for (box, part), n in zip(figs, names):
            im = resize(darken_fix(part), k)
            if t:
                im = thicken(np.pad(im, ((t, t), (t, t), (0, 0))), t)
            dx = -body_center(im)
            dy = (box[1] - foot_sheet_y) * k - t
            placed.append((n, im, dx, dy))
        x0 = min(dx for _, _, dx, _ in placed) - 4
        y0 = min(dy for _, _, _, dy in placed) - 4
        x1 = max(dx + im.shape[1] for _, im, dx, _ in placed) + 4
        y1 = max(dy + im.shape[0] for _, im, _, dy in placed) + 4
        w, h = int(np.ceil((x1 - x0) / 4) * 4), int(np.ceil((y1 - y0) / 4) * 4)
        foot = (int(round(-x0)), int(round(-y0)))
        for n, im, dx, dy in placed:
            canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            canvas.alpha_composite(Image.fromarray(im), (int(round(dx - x0)), int(round(dy - y0))))
            arr = np.asarray(canvas)
            save(arr, f"enemies/{enemy}/{n}.png")
            out[f"{enemy}/{n}"] = arr
            print(f"{enemy}/{n}: 몸 키 {body_only(im).shape[0] / ENEMY_FILE_SCALE:.0f} (게임 px)")
        print(f"{enemy}: 캔버스 {w}x{h}, 발 기준점 {foot} (파일 px, 게임은 1/{ENEMY_FILE_SCALE})")
    return out


def body_box(im):
    """가장 큰 덩어리(몸)의 상자 x0, y0, x1, y1 (별·땀방울 제외)."""
    lab, n = ndi.label(im[..., 3] > 128)
    sizes = ndi.sum(np.ones_like(lab), lab, range(1, n + 1))
    sl = ndi.find_objects(lab)[int(np.argmax(sizes))]
    return sl[1].start, sl[0].start, sl[1].stop, sl[0].stop


def body_only(im):
    x0, y0, x1, y1 = body_box(im)
    return im[y0:y1, x0:x1]


def body_center(im):
    """몸 덩어리 픽셀의 가로 무게중심."""
    lab, n = ndi.label(im[..., 3] > 128)
    sizes = ndi.sum(np.ones_like(lab), lab, range(1, n + 1))
    return float(np.where(lab == int(np.argmax(sizes)) + 1)[1].mean())


def main():
    if "--pencil" in sys.argv:
        copy_pencil()
        return
    missing = [r for r in REPLACED if not (SPR / (str(Path(r).parent) + "_pencil") / Path(r).name).exists()]
    if missing:
        raise SystemExit(f"예전 그림이 _pencil/에 없음 (먼저 --pencil): {missing[:3]}...")
    backdrop()
    buildings()
    props()
    structures()
    items()
    enemies()


if __name__ == "__main__":
    main()
