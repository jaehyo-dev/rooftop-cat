"""v0.7.0 생선 시안 비교 그림: 마젠타 배경을 지우고 4마리를 잘라 지금 생선·황금 생선과 같은 크기로 나란히 놓는다.
실행: python3 review/v0.7.0/concept/make_fish_compare.py (저장소 루트 또는 이 폴더)"""
import os
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../.."))


def cut_fish(path):
    """마젠타(#FF00FF) 우세 픽셀을 투명하게 하고, 빈 세로줄로 나뉜 덩어리 4개를 잘라 돌려준다"""
    a = np.asarray(Image.open(path).convert("RGBA")).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    magenta = np.minimum(r, b) - g  # 마젠타 우세도
    alpha = np.clip(255 - (magenta - 60) * 4, 0, 255)
    a[..., 3] = alpha
    cols = (alpha > 128).sum(axis=0) > 2
    runs, start = [], None
    for x, on in enumerate(list(cols) + [False]):
        if on and start is None:
            start = x
        elif not on and start is not None:
            if x - start > 40:
                runs.append((start, x))
            start = None
    img = Image.fromarray(a.astype(np.uint8))
    fish = []
    for x0, x1 in runs:
        part = img.crop((x0, 0, x1, img.height))
        fish.append(part.crop(part.getbbox()))
    return fish


def fit(im, w):
    return im.resize((w, max(1, round(im.height * w / im.width))), Image.LANCZOS)


def main():
    cur = Image.open(os.path.join(ROOT, "assets/sprites/items/fish.png")).convert("RGBA")
    gold = Image.open(os.path.join(ROOT, "assets/sprites/items/gold.png")).convert("RGBA")
    sets = {name: cut_fish(os.path.join(HERE, f"{name}.png")) for name in ("10_fish_set1", "11_fish_set2")}
    bg = (250, 236, 214)  # 노을 하늘 아래쪽 크림색 (게임 배경과 비슷하게)
    rows = []
    for name, fish in sets.items():
        assert len(fish) == 4, f"{name}: 생선 {len(fish)}마리"
        rows.append((name, [cur, gold] + fish))
    W, H = 1600, 760
    sheet = Image.new("RGBA", (W, H), bg + (255,))
    d = ImageDraw.Draw(sheet)
    col_w = W // 6
    y = 20
    for name, items in rows:
        # 큰 크기(그림 폭 200) / 게임 크기(56) / 휴대폰 실제 크기(30)
        for size, row_h in ((200, 150), (56, 50), (30, 34)):
            for i, im in enumerate(items):
                f = fit(im, size)
                sheet.alpha_composite(f, (i * col_w + (col_w - f.width) // 2, y + (row_h - f.height) // 2))
            y += row_h
        d.line((0, y + 8, W, y + 8), fill=(168, 105, 58, 255), width=2)
        y += 30
    sheet.crop((0, 0, W, y)).convert("RGB").save(os.path.join(HERE, "fish_compare.png"))
    print("저장:", os.path.join(HERE, "fish_compare.png"))


if __name__ == "__main__":
    main()
