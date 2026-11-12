"""v0.7.0 2c 그림 자르기: 마젠타 시트 → assets/sprites/ (tools/cut_parts.py의 배경 지우기·부품 찾기를 씀).

사용: python3 review/v0.7.0/2c/cut_art.py fish|paper|icons|stamp
- fish: 시안 10(세트 1)의 생선 4마리 → assets/sprites/items/fish_0~3.png (지금 fish.png와 같은 240x136 칸에 비율 그대로 맞춤,
  반짝이 같은 작은 조각은 버림). 0단계 멸치는 몸이 가늘어 칸 안에서 작게 보인다 = "작은 멸치에서 시작"
- paper / icons / stamp: assets/raw/ui_*.png → assets/sprites/ui/
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
from cut_parts import remove_magenta, find_parts  # noqa: E402
from cut_buildings import despill  # noqa: E402
from clean_edges import clean  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
UI = ROOT / "assets/sprites/ui"
PAD = 6
MAX_SIDE = 512  # 아이콘·부품은 이 크기 안으로 줄임 (화면에서 가장 크게 써도 이 정도)

PAPER = ["panel", "note", "cork", "button_orange", "button_cream", "pin_red", "pin_yellow", "clip"]
ICONS = ["combo", "clock", "dash_start", "bell_start", "fish_bonus", "footprints", "jump", "smash",
         "items", "swap", "rank_face", "basket", "note_check", "star", "back", "speed"]


def sheet(path: Path) -> np.ndarray:
    return despill(remove_magenta(np.asarray(Image.open(path).convert("RGB"))))


def clean_file(path: Path) -> None:
    """가장자리 분홍 기 지우기 (tools/clean_edges.py, 저장한 크기에서)"""
    Image.fromarray(clean(np.asarray(Image.open(path).convert("RGBA")))).save(path)


def crop(rgba: np.ndarray, box: tuple) -> np.ndarray:
    top, bottom, left, right = box
    h, w = rgba.shape[:2]
    part = rgba[max(0, top - PAD):min(h, bottom + PAD), max(0, left - PAD):min(w, right + PAD)].copy()
    # 상자 안에 걸친 이웃 부품 조각은 지운다: 상자 테두리에 닿는 작은 덩어리 대신 가장 큰 덩어리만 남김
    from scipy import ndimage
    labels, found = ndimage.label(part[..., 3] > 0)
    if found > 1:
        sizes = ndimage.sum(np.ones_like(labels), labels, range(1, found + 1))
        keep = np.isin(labels, [i + 1 for i, s in enumerate(sizes) if s >= sizes.max() * 0.02])
        part[~keep] = 0
    return part


def save(rgba: np.ndarray, path: Path, max_side: int = MAX_SIDE) -> None:
    img = Image.fromarray(rgba)
    k = min(1.0, max_side / max(img.size))
    if k < 1.0:
        img = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    clean_file(path)
    print(path.relative_to(ROOT), img.size)


def fit(rgba: np.ndarray, size: tuple) -> np.ndarray:
    """비율 그대로 size 칸 안에 가운데 맞춤 (여백 투명)"""
    img = Image.fromarray(rgba)
    k = min((size[0] - 4) / img.width, (size[1] - 4) / img.height)
    img = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.paste(img, ((size[0] - img.width) // 2, (size[1] - img.height) // 2))
    return np.asarray(canvas)


def cut_grid(path: Path, names: list, cols: int, out: Path, max_side: int) -> None:
    """격자 칸마다 보이는 것을 모두 담아 자른다 (발자국·화살표처럼 여러 조각인 아이콘)"""
    rgba = sheet(path)
    h, w = rgba.shape[:2]
    rows = (len(names) + cols - 1) // cols
    for i, name in enumerate(names):
        r, c = divmod(i, cols)
        cell = rgba[r * h // rows:(r + 1) * h // rows, c * w // cols:(c + 1) * w // cols]
        ys, xs = np.nonzero(cell[..., 3] > 16)
        part = cell[max(0, ys.min() - PAD):ys.max() + PAD + 1, max(0, xs.min() - PAD):xs.max() + PAD + 1]
        save(part.copy(), out / f"{name}.png", max_side)


def cut_named(path: Path, names: list, out: Path, max_side: int = MAX_SIDE) -> None:
    rgba = sheet(path)
    for name, box in zip(names, find_parts(rgba, len(names))):
        save(crop(rgba, box), out / f"{name}.png", max_side)


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "fish":
        rgba = sheet(ROOT / "review/v0.7.0/concept/10_fish_set1.png")
        size = Image.open(ROOT / "assets/sprites/items/fish.png").size
        for i, box in enumerate(find_parts(rgba, 4)):
            out = ROOT / f"assets/sprites/items/fish_{i}.png"
            Image.fromarray(fit(crop(rgba, box), size)).save(out)
            clean_file(out)
            print(out.relative_to(ROOT), size)
    elif what == "paper":
        cut_named(ROOT / "assets/raw/ui_paper_sheet.png", PAPER, UI, 1024)
        # 버튼은 화면에서 높이 88~120으로 쓴다: 늘림 칸(9칸 나누기)의 둥근 끝이 찌그러지지 않게 높이 100으로 줄여 둠
        for name in ["button_orange", "button_cream"]:
            img = Image.open(UI / f"{name}.png")
            img.resize((round(img.width * 100 / img.height), 100), Image.LANCZOS).save(UI / f"{name}.png")
            clean_file(UI / f"{name}.png")
            print(name, "높이 100")
    elif what == "icons":
        cut_grid(ROOT / "assets/raw/ui_icons_sheet.png", ICONS, 4, UI / "icons", 256)
    elif what == "cookie_clock":
        # 하트 쿠키 간격 강화: 지금 쿠키 그림 오른쪽 아래에 작은 시계 (PLAN 9번)
        cookie = Image.open(ROOT / "assets/sprites/items/cookie.png").convert("RGBA")
        clock = Image.open(UI / "icons/clock.png").convert("RGBA")
        side = 256
        canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        k = 210 / max(cookie.size)
        cookie = cookie.resize((round(cookie.width * k), round(cookie.height * k)), Image.LANCZOS)
        canvas.alpha_composite(cookie, (8, 8))
        k = 120 / max(clock.size)
        clock = clock.resize((round(clock.width * k), round(clock.height * k)), Image.LANCZOS)
        canvas.alpha_composite(clock, (side - clock.width - 2, side - clock.height - 2))
        canvas.save(UI / "icons/cookie_clock.png")
        clean_file(UI / "icons/cookie_clock.png")
        print("assets/sprites/ui/icons/cookie_clock.png", canvas.size)
    elif what == "stamp":
        # 발바닥 + 떨어진 발가락 4개를 모두 담아 자름 (2c-fix: 가장 큰 덩어리 상자로 자르면 발가락이 잘렸음)
        cut_grid(ROOT / "assets/raw/ui_stamp.png", ["stamp"], 1, UI / "icons", 256)
