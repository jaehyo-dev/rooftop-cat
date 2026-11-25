"""카툰 화풍(ART_BIBLE 14절) 측정·확인 도구.

사용:
  python3 tools/cartoon_art.py measure                 # 화풍 ③ 시안(s3_A·B·C)의 선 굵기·선 색을 잰다 (14절 숫자의 출처)
  python3 tools/cartoon_art.py check <시트.png> <화면 배율> # 마젠타 배경 시트의 바깥선·안쪽선 굵기(화면 px)와 선 색
  python3 tools/cartoon_art.py frames <시트.png> <출력 폴더> <줄마다 칸 수...> [-- 이름=1,2,3 ...]  # 장마다 잘라 GIF(0.12초, 실제·2배)와 겹침 비교
선 찾기: 주변보다 어두운 가는 띠(검은 탑햇)를 4배로 키운 그림에서 대비의 절반을 경계로 잡고(반값 폭),
뼈대 위 2 x 거리 = 굵기. 색 있는 선(분홍 구름선 등)도 잡힌다. 마젠타는 밝기가 낮아(약 105) 선과 대비가 약하므로
크림색으로 바꾼 뒤 잰다. 개발용 도구 (numpy, scipy, scikit-image, Pillow 필요).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from skimage.morphology import skeletonize

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "assets/concept/restructure_style"
UP = 4                       # 굵기를 소수 단위로 재려고 키우는 배율
CREAM = (250, 240, 225)      # 마젠타 대신 깔 바탕
LINE = (0x33, 0x18, 0x06)    # 14절 선 색


def lum(a):
    return a[..., :3] @ np.array([0.299, 0.587, 0.114])


def shade(rgb, k=(1.0, 0.86, 0.83)):
    """캐릭터 그림자 한 단계 (14-3: base x #FFDBD4)."""
    return tuple(int(round(c * m)) for c, m in zip(rgb, k))


# 주인공 색표 (14-2) + 그림자 한 단계 (14-3). 먼 쪽 다리는 몸·크림의 그림자 값 (검은 갈색 금지)
HERO = {"body": (0xFD, 0xB8, 0x65), "stripe": (0xF0, 0x80, 0x20), "cream": (0xFE, 0xF8, 0xEC),
        "scarf": (0xA6, 0xDA, 0xAA), "cheek": (0xFD, 0x9B, 0x87)}
HERO_SHADE = {"body_shade": shade(HERO["body"]), "cream_shade": shade(HERO["cream"])}
# Codex 주인공 시트의 실제 색(run_3 k-means) → 맞출 색표 이름. 시트마다 이 값에서 시작해 k-means로 다시 잡는다.
# 목도리 그늘은 따로 두지 않는다(회색 먼 발과 한 군집으로 섞임): 목도리 차이만큼 같이 옮겨진다
HERO_SEEDS = [((0xFC, 0xAE, 0x51), "body"), ((0xF9, 0x7F, 0x1E), "stripe"), ((0xFC, 0xFA, 0xEF), "cream"),
              ((0x73, 0xD0, 0x97), "scarf"), ((0xF6, 0x7B, 0x7E), "cheek"),
              ((0xFC, 0x9A, 0x9C), "cheek"), ((0xFF, 0x7B, 0x7F), "cheek"),  # 분홍 볼(공중 시트), 발바닥 젤리도 볼 색으로
              ((0xAC, 0x97, 0x7C), "cream_shade"), ((0x9D, 0x50, 0x1A), "body_shade"), ((0x63, 0x61, 0x44), "body_shade")]
# 첫 동네 적 색표 (14-2, 2026-11-25 게임 그림 enemies/에서 잼). 두건은 일당 공통
BANDANA = (0xE8, 0x46, 0x3A)
CROW = {"feather": (0x63, 0x57, 0x5E), "belly": (0xBD, 0xAC, 0x9F), "beak": (0xFB, 0xD0, 0x41), "bandana": BANDANA}
RAT = {"fur": (0xC9, 0xAA, 0x91), "pink": (0xF8, 0xB4, 0xA0), "bandana": BANDANA}
SHADE_NAMES = {"cream_shade", "body_shade"}  # 선과 섞인 가장자리 색과 겹쳐서 덩어리일 때만 바꾸는 색


def fit_seeds(rgba, seeds, palette, min_count=30, max_move=48):
    """시트의 불투명·선 아닌 픽셀로 k-means를 돌려 seeds 색을 이 시트의 실제 색으로 옮긴다.
    픽셀이 적은 색, 씨앗과 색표 둘 다에서 max_move(채널 차 합)보다 먼 색(다른 군집으로 샌 것)은 뺀다."""
    from scipy.cluster.vq import kmeans2
    a = rgba.astype(float)
    p = a[..., :3][(a[..., 3] > 250) & (lum(a) > 70)][::5]
    init = np.array([s for s, _ in seeds], float)
    c, lab = kmeans2(p, init, minit="matrix", iter=20)
    n = np.bincount(lab, minlength=len(seeds))
    return [(tuple(c[i]), name) for i, (seed, name) in enumerate(seeds)
            if n[i] >= min_count and min(np.abs(c[i] - seed).sum(), np.abs(c[i] - palette[name]).sum()) <= max_move]


def recolor(rgba, pairs, palette, shade_names=SHADE_NAMES, blob=2):
    """시트 색 → 색표: 픽셀마다 가장 가까운 시트 색(선 포함)을 찾아 그 색과 색표 차이만큼 옮긴다.
    선과 섞인 가장자리는 섞인 몫(t)만큼만 옮겨 선이 번지지 않는다. 그늘 색은 blob px 열림을 견딘 덩어리만 (얇은 섞임 띠 제외)."""
    a = rgba.astype(np.float32)
    rgb = a[..., :3]
    L = np.array(LINE, np.float32)
    src = np.array([LINE] + [s for s, _ in pairs], np.float32)
    tgt = np.array([LINE] + [palette[n] for _, n in pairs], np.float32)
    d = ((rgb[..., None, :] - src) ** 2).sum(-1)
    k = d.argmin(-1)
    for i, (_, name) in enumerate(pairs, 1):
        if name in shade_names:
            m = k == i
            keep = ndi.binary_dilation(ndi.binary_opening(m, iterations=blob), iterations=blob) & m
            d[m & ~keep, i] = np.inf
    k = d.argmin(-1)
    s = src[k]
    t = np.clip(((rgb - L) * (s - L)).sum(-1) / np.maximum(((s - L) ** 2).sum(-1), 1), 0, 1)
    out = rgb + t[..., None] * (tgt[k] - s)
    return np.dstack([np.clip(np.round(out), 0, 255), a[..., 3]]).astype(np.uint8)


def palette_report(rgba, palette, min_count=80, near=60):
    """색표 이름마다 (픽셀 수, 가운데값, 최대 채널 차이). 불투명 픽셀을 가장 가까운 색표 색(선 포함, 거리 near 안)으로 나누고,
    다른 색과 섞인 가장자리를 빼려고 1px 깎은 속만 잰다 (작은 볼은 속이 적어 깎기 전 값)."""
    a = rgba.astype(int)
    names = list(palette)
    c = np.array([palette[n] for n in names] + [LINE])
    d = np.abs(a[..., None, :3] - c).sum(-1)
    k, dm = d.argmin(-1), d.min(-1)
    out = {}
    for i, n in enumerate(names):
        m = (k == i) & (dm < near) & (a[..., 3] > 250)
        core = ndi.binary_erosion(m)
        s = a[..., :3][core if core.sum() >= min_count else m]
        if len(s) >= min_count:
            med = tuple(int(v) for v in np.median(s, 0))
            out[n] = (len(s), med, max(abs(x - y) for x, y in zip(med, palette[n])))
    return out


def dark_blobs(rgba, blob=2):
    """선 색이 아닌데 어두운(밝기 < 120) 덩어리 픽셀 수: 먼 쪽 다리를 검은 갈색으로 칠한 곳 찾기."""
    a = rgba.astype(float)
    dark = (a[..., 3] > 250) & (lum(a) < 120) & (np.abs(a[..., :3] - LINE).sum(-1) > 60)
    return int(ndi.binary_opening(dark, iterations=blob).sum())


def magenta_amount(a):
    """0(마젠타 아님) ~ 1(순 마젠타)."""
    a = a.astype(float)
    return np.clip(((a[..., 0] + a[..., 2]) / 2 - a[..., 1]) / 255, 0, 1)


def on_cream(img):
    """마젠타 배경을 크림으로 바꾼 RGB와 고양이 실루엣(True = 고양이)."""
    a = np.asarray(img.convert("RGB"))
    bg = magenta_amount(a) > 0.55
    out = np.where(bg[..., None], np.array(CREAM, np.uint8), a)
    return Image.fromarray(out.astype(np.uint8)), ndi.binary_opening(~bg, iterations=2)


def line_skeleton(img):
    """(키운 그림 RGB, 뼈대, 뼈대 위 굵기[원래 px])."""
    big = np.asarray(img.convert("RGB").resize((img.width * UP, img.height * UP), Image.BICUBIC)).astype(float)
    th = ndi.grey_closing(lum(big), size=(17 * UP, 17 * UP)) - lum(big)
    m = ndi.binary_opening(th > 0.5 * np.percentile(th, 99), iterations=1)
    sk = skeletonize(m)
    w = 2 * ndi.distance_transform_edt(m) / UP
    return big, sk & (w > 0.8), w


def widths(img):
    _, sk, w = line_skeleton(img)
    return w[sk]


def outer_inner(img, silhouette):
    """실루엣 가장자리에 붙은 선 = 바깥선, 나머지 = 안쪽선 (각각 굵기 배열)."""
    big, sk, w = line_skeleton(img)
    sil = np.asarray(Image.fromarray(silhouette.astype(np.uint8) * 255).resize((img.width * UP, img.height * UP))) > 127
    d_out = ndi.distance_transform_edt(sil) / UP          # 바탕까지 거리(원래 px)
    outer = sk & (d_out <= w * 0.8 + 2)
    inner = sk & (d_out > w * 0.8 + 3)
    return w[outer], w[inner], big[sk]


def core_color(pixels):
    c = np.median(pixels.reshape(-1, 3), 0).astype(int)
    return "#%02X%02X%02X" % tuple(c)


def stat(a):
    if len(a) == 0:
        return "선 없음"
    return f"p25 {np.percentile(a, 25):.1f} / 중앙 {np.median(a):.1f} / p75 {np.percentile(a, 75):.1f} (뼈대 {len(a)}점)"


# 14절 표의 출처: 1280x720(C는 1280x640)으로 줄인 시안에서 잰 영역
REGIONS = {
    "A": [("주인공", (165, 335, 480, 505)), ("거대 발(큰 사물)", (700, 0, 990, 330)),
          ("옥상 집(사물)", (680, 340, 920, 500)), ("앞 건물 창·난간", (0, 540, 1280, 720)),
          ("먼 집 왼쪽", (0, 300, 300, 470)), ("먼 집 오른쪽", (1030, 300, 1280, 470)),
          ("구름", (0, 140, 250, 280)), ("집중선(효과)", (400, 80, 620, 280)), ("HUD 하트", (1050, 20, 1260, 80))],
    "B": [("주인공", (475, 250, 780, 450)), ("얼굴 카드(UI)", (30, 575, 860, 700)),
          ("가구", (820, 130, 1260, 400)), ("창틀", (380, 0, 940, 270))],
}
SIZE = {"A": (1280, 720), "B": (1280, 720), "C": (1280, 640)}


def measure():
    for sc, regions in REGIONS.items():
        img = Image.open(RAW / f"s3_{sc}.png").convert("RGB").resize(SIZE[sc], Image.LANCZOS)
        for name, box in regions:
            big, sk, w = line_skeleton(img.crop(box))
            print(f"3_{sc} {name:14s} 굵기 {stat(w[sk])}  선 중심색 {core_color(big[sk])}")
    img = Image.open(RAW / "s3_C.png").convert("RGB").resize(SIZE["C"], Image.LANCZOS).crop((0, 100, 1280, 560))
    cream, sil = on_cream(img)
    o, i, px = outer_inner(cream, sil)
    print(f"3_C 바깥선 {stat(o)}\n3_C 안쪽선 {stat(i)}  선 중심색 {core_color(px)}")


def check(path, scale):
    """시트를 화면 배율로 줄여 바깥선·안쪽선 굵기(화면 px)와 선 색을 잰다."""
    img = Image.open(path).convert("RGB")
    img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    cream, sil = on_cream(img)
    o, i, px = outer_inner(cream, sil)
    black = float((px.max(1) <= 16 * 1.0).mean()) if len(px) else 0.0
    return {"outer": float(np.median(o)) if len(o) else 0.0, "inner": float(np.median(i)) if len(i) else 0.0,
            "core": core_color(px), "black_share": black}


GIF_MS = 120          # 장마다 0.12초
RUN_HEIGHT = 131      # "실제 크기": 첫 칸(달리기) 키를 3_C 시트의 화면 크기(131px)에 맞춘다
PAPER = (254, 248, 236)
ONION = (40, 120, 255)


def cutout(img):
    """마젠타를 빼서 RGBA로. 가장자리 섞인 색은 마젠타 몫을 덜어 낸다."""
    a = np.asarray(img.convert("RGB")).astype(float)
    m = magenta_amount(a)
    # 바탕과 붙은 가장자리 2px에서만 마젠타를 덜어 낸다 (안쪽 분홍 볼·귀를 바탕으로 착각하지 않게)
    edge = ndi.binary_dilation(m > 0.55, iterations=2)
    alpha = np.where(edge, np.clip(1 - m / 0.5, 0, 1), 1.0)
    mag = np.array([255.0, 0.0, 255.0])
    rgb = (a - (1 - alpha[..., None]) * mag) / np.maximum(alpha[..., None], 0.05)
    out = np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8)
    return out


def baselines(rgba):
    """옅은 회색 바닥선 줄(y)을 찾아 지운다. 바닥선 = 폭의 60% 넘게 덮은 회색·연보라 가로줄."""
    a = rgba.astype(int)
    grey = (a[..., 3] > 128) & (abs(a[..., 0] - a[..., 1]) < 30) & (a[..., 2] >= a[..., 0] - 6) & (a[..., 0] > 150)
    rows = np.where(grey.mean(1) > 0.6)[0]
    groups = np.split(rows, np.where(np.diff(rows) > 3)[0] + 1) if len(rows) else []
    out = rgba.copy()
    out[..., 3][grey & np.isin(np.arange(len(a))[:, None], rows)] = 0
    return out, [int(g.min()) for g in groups if len(g)]


def split_columns(cols, n):
    """칠해진 열(cols, bool)을 가장 넓은 빈 틈 n-1개에서 나눠 n개의 (시작, 끝+1)로."""
    xs = np.where(cols)[0]
    gaps = [(xs[i + 1] - xs[i], i) for i in range(len(xs) - 1) if xs[i + 1] - xs[i] > 1]
    cut = sorted(i for _, i in sorted(gaps, reverse=True)[:n - 1])
    if len(cut) != n - 1:
        raise ValueError(f"빈 틈 {len(gaps)}개로 {n}칸을 나눌 수 없음")
    starts = [xs[0]] + [xs[i + 1] for i in cut]
    ends = [xs[i] + 1 for i in cut] + [xs[-1] + 1]
    return [(int(a), int(b)) for a, b in zip(starts, ends)]


def cut_frames(rgba, counts):
    """줄마다(바닥선 위 띠) 가장 넓은 세로 틈으로 칸을 나눈다. 반환: (바닥선 지운 그림, [(줄 번호, 바닥선 y, 상자)])."""
    clean, lines = baselines(rgba)
    if len(lines) != len(counts):
        raise ValueError(f"바닥선 {len(lines)}개, 줄 {len(counts)}개")
    frames, top = [], 0
    for r, (y, n) in enumerate(zip(lines, counts)):
        band = clean[top:y - 3, :, 3] > 128      # 바닥선 바로 위까지 (바닥선 가장자리 남은 픽셀이 칸을 잇지 않게)
        for x0, x1 in split_columns(band.any(0), n):
            ys = np.where(band[:, x0:x1].any(1))[0]
            frames.append((r, y, (x0, top + int(ys[0]), x1, top + int(ys[-1]) + 1)))
        top = y + 10   # 바닥선 아래 가장자리 픽셀을 다음 줄에 넣지 않게
    return clean, frames


def orange_center(rgba):
    """몸 중심 x = 주황 털 픽셀의 가로 무게중심 (먼지·별·목도리가 붙어도 몸이 떨리지 않게)."""
    a = rgba.astype(int)
    o = (a[..., 3] > 128) & (a[..., 0] > 200) & (a[..., 1] > 110) & (a[..., 1] < 200) & (a[..., 2] < 120)
    return float(np.where(o)[1].mean())


def frames(path, out_dir, counts, sequences=None):
    """sequences = {이름: [장 번호(1부터)...]}: 이름마다 GIF(실제·2배)와 겹침 비교. 없으면 전체 순서 하나."""
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stem = Path(path).stem
    clean, boxes = cut_frames(cutout(Image.open(path)), counts)
    first = boxes[0][2]
    scale = RUN_HEIGHT / (first[3] - first[1])
    parts = []  # (RGBA 장, 바닥선 기준 위쪽 높이, 몸 중심)
    for _, y, (x0, y0, x1, y1) in boxes:
        im = Image.fromarray(clean[y0:y1, x0:x1])
        im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
        a = np.asarray(im)
        parts.append((im, (y - y0) * scale, orange_center(a), (y1 - y) * scale))
    left = max(c for _, _, c, _ in parts) + 10
    right = max(im.width - c for im, _, c, _ in parts) + 10
    up = max(h for _, h, _, _ in parts) + 10
    down = max(d for _, _, _, d in parts) + 10
    W, H, base = int(left + right), int(up + down), int(up)
    shots, masks, report = [], [], []
    for i, (im, h, c, _) in enumerate(parts):
        fr = Image.new("RGBA", (W, H), PAPER + (255,))
        ImageDraw.Draw(fr).line([(0, base), (W, base)], fill=(200, 196, 210), width=2)
        pos = (int(round(left - c)), int(round(base - h)))
        fr.alpha_composite(im, pos)
        shots.append(fr.convert("RGB"))
        m = np.zeros((H, W), bool)
        m[pos[1]:pos[1] + im.height, pos[0]:pos[0] + im.width] = np.asarray(im)[..., 3] > 128
        masks.append(m)
        bottom = np.where(m.any(1))[0][-1] + 1
        report.append(f"{i + 1}장: 크기 {im.width}x{im.height}, 가장 낮은 점 - 바닥선 {bottom - base:+d}px")
    strip = Image.new("RGB", (W * len(shots), H), PAPER)
    for i, sh in enumerate(shots):
        strip.paste(sh, (i * W, 0))
    strip.save(out / f"{stem}_frames.png")
    for name, order in (sequences or {"": list(range(1, len(shots) + 1))}).items():
        tag = f"{stem}{'_' + name if name else ''}"
        for z in (1, 2):
            seq = [shots[k - 1].resize((W * z, H * z), Image.LANCZOS) for k in order]
            seq[0].save(out / f"{tag}_x{z}.gif", save_all=True, append_images=seq[1:], duration=GIF_MS, loop=0)
        # 겹침 비교: 다음 장 위에 앞 장 윤곽선(파랑), 3열 격자
        cells = []
        for k0, k1 in zip(order, order[1:]):
            m = masks[k0 - 1]
            c = np.asarray(shots[k1 - 1]).copy()
            c[m & ~ndi.binary_erosion(m, iterations=2)] = ONION
            cell = Image.fromarray(c)
            ImageDraw.Draw(cell).text((6, 4), f"{k0} -> {k1}", fill=(40, 40, 40))
            cells.append(cell)
        cols = min(3, len(cells))
        rows = -(-len(cells) // cols)
        grid = Image.new("RGB", (cols * W + (cols - 1) * 8, rows * H + (rows - 1) * 8), (255, 255, 255))
        for i, cell in enumerate(cells):
            grid.paste(cell, ((i % cols) * (W + 8), (i // cols) * (H + 8)))
        grid.save(out / f"{tag}_onion.png")
    return report


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "measure":
        measure()
    elif len(sys.argv) >= 4 and sys.argv[1] == "frames":
        args = sys.argv[4:]
        cut = args.index("--") if "--" in args else len(args)
        seqs = {k: [int(n) for n in v.split(",")] for k, v in (a.split("=") for a in args[cut + 1:])}
        print("\n".join(frames(sys.argv[2], sys.argv[3], [int(n) for n in args[:cut]], seqs or None)))
    elif len(sys.argv) == 4 and sys.argv[1] == "check":
        print(check(sys.argv[2], float(sys.argv[3])))
    else:
        print(__doc__)
        sys.exit(1)
