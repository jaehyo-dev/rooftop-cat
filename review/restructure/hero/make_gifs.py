"""카툰 주인공 동작별 GIF(실제 화면 크기·2배)와 장 사이 겹침 비교, 예전 그림과 크기 비교.

사용: python3 review/restructure/hero/make_gifs.py   (결과: review/restructure/hero/motion/)
실제 크기 = 게임 배율(CatView.art_scale = 150 / (711 x 0.5)). 그림은 발끝 기준점(360, 450)에 놓는다.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[3]
NEW = ROOT / "assets/sprites/cat_frames"
OLD = ROOT / "assets/sprites/cat_frames_pencil"
OUT = Path(__file__).resolve().parent / "motion"
ART = 150 / (711 * 0.5)
BG = (198, 224, 250)
ONION = (40, 90, 230)
# 동작: [(그림, 밀리초)] — 시간은 게임과 같게 (CatPose: 슬라이딩 낮추기 0.06, 눌림 0.1, 일어나기 0.08씩, 피격 0.08/0.18/0.22)
RUN = [(f"run_{i}", round(350 * w)) for i, w in enumerate([0.15, 0.16, 0.13, 0.08, 0.08, 0.13, 0.13, 0.14])]  # 처음 속도 430px/s, 한 바퀴 150px = 0.35초, 장 길이는 CatPose.RUN_UNTIL
MOTIONS = {
    "run": RUN,
    "jump": RUN[:3] + [("crouch", 60), ("takeoff", 120), ("rise", 220), ("fall", 220), ("land", 120)] + RUN,
    "flip": [("rise", 160), ("flip_tuck", 70), ("flip_curl", 70), ("flip_ball", 200), ("flip_open", 80), ("fall", 200), ("land", 120)] + RUN,
    "slide_ground": RUN + [("slide_down", 60)] + [("slide_a", 116), ("slide_b", 116)] * 3 + [("slide_up1", 80), ("slide_up2", 80)] + RUN,
    "slide_air": [("rise", 200), ("dive", 160), ("slide_squash", 100)] + [("slide_a", 116), ("slide_b", 116)] * 2 + [("slide_up1", 80), ("slide_up2", 80)] + RUN,
    "hit": RUN + [("hit", 80), ("hit_fly", 180), ("hit_wobble", 220)] + RUN,
    "paw": [("run_0", 200), ("paw_0", 300), ("paw_1", 300), ("run_0", 200)],
    "sit": [("sit", 0)],
}


def load(d, name):
    return Image.open(d / f"{name}.png").convert("RGBA")


def sit_frames():
    """앉기: 몸 뒤에 꼬리 8장을 오가고(2.4초), 한 번 깜빡인 뒤 일어나 달린다."""
    body, blink = load(NEW, "sit_body"), load(NEW, "sit_body_blink")
    out = []
    order = list(range(8)) + list(range(7, -1, -1))
    for k, i in enumerate(order):
        fr = Image.new("RGBA", body.size)
        fr.alpha_composite(load(NEW, f"sit_tail_{i}"))
        fr.alpha_composite(blink if k in (12, 13) else body)
        out.append((fr, 150))
    return out + [(load(NEW, "sit_up"), 150)] + [(load(NEW, n), ms) for n, ms in RUN * 2]


def canvas(img, zoom):
    """캔버스 그림을 게임 크기 x zoom으로 줄이고 바닥선을 그린 RGB."""
    w, h = round(640 * ART * zoom), round(512 * ART * zoom)
    small = img.resize((w, h), Image.LANCZOS)
    bg = Image.new("RGBA", (w, h), BG + (255,))
    ImageDraw.Draw(bg).line([(0, round(450 * ART * zoom)), (w, round(450 * ART * zoom))], fill=(150, 140, 160), width=max(1, zoom))
    bg.alpha_composite(small)
    return bg.convert("RGB").crop((0, round(100 * ART * zoom), w, round(480 * ART * zoom)))


def onion(seq, path):
    """장 사이 겹침: 다음 장 위에 앞 장 윤곽선(파랑). 같은 그림이 이어지는 칸은 뺀다."""
    pairs, seen = [], set()
    for (a, _), (b, _) in zip(seq, seq[1:]):
        key = (id(a), id(b))
        if key not in seen and a is not b:
            seen.add(key)
            pairs.append((a, b))
    cells = []
    for a, b in pairs[:12]:
        m = np.asarray(a)[..., 3] > 128
        edge = m & ~ndi.binary_erosion(m, iterations=3)
        c = np.asarray(b).copy()
        c[edge] = ONION + (255,)
        cells.append(canvas(Image.fromarray(c), 2))
    w, h = cells[0].size
    grid = Image.new("RGB", (w * 3 + 16, h * ((len(cells) + 2) // 3) + 8 * ((len(cells) - 1) // 3)), (255, 255, 255))
    for i, c in enumerate(cells):
        grid.paste(c, ((i % 3) * (w + 8), (i // 3) * (h + 8)))
    grid.save(path)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cache = {}
    for name, spec in MOTIONS.items():
        seq = sit_frames() if name == "sit" else [(cache.setdefault(n, load(NEW, n)), ms) for n, ms in spec]
        for zoom in (1, 2):
            frames = [canvas(im, zoom) for im, _ in seq]
            frames[0].save(OUT / f"{name}_x{zoom}.gif", save_all=True, append_images=frames[1:],
                           duration=[ms for _, ms in seq], loop=0)
        onion(seq, OUT / f"{name}_onion.png")
    # 예전(색연필)과 크기 비교: 같은 이름 그림을 나란히 (실제 크기 x2)
    pairs = [("run_0", "run_0"), ("run_2", "run_1"), ("fall", "fall"), ("slide_0", "slide_a"), ("sit_body", "sit_body")]
    cells = []
    for old, new in pairs:
        row = Image.new("RGB", (0, 0))
        a, b = canvas(load(OLD, old), 2), canvas(load(NEW, new), 2)
        row = Image.new("RGB", (a.width * 2 + 8, a.height), (255, 255, 255))
        row.paste(a, (0, 0))
        row.paste(b, (a.width + 8, 0))
        cells.append(row)
    grid = Image.new("RGB", (cells[0].width, sum(c.height + 8 for c in cells)), (255, 255, 255))
    for i, c in enumerate(cells):
        grid.paste(c, (0, i * (c.height + 8)))
    grid.save(OUT.parent / "size_old_vs_new.png")


if __name__ == "__main__":
    main()
