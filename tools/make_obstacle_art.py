"""v0.6.0 장애물·하트·물러난 소품 그림을 만든다. 같은 입력이면 항상 같은 결과.

사용: python3 tools/make_obstacle_art.py
- assets/raw/obstacles_noribbon.png (마젠타 시트) → assets/sprites/obstacles/{flock,pot,ac,tank}.png
- review/v0.6.0/cut/heart_*.png → assets/sprites/hud/heart_{full,crack,empty}.png
- review/v0.6.0/cut/{churu,gold,yarn,heart_item,can,bell}.png → assets/sprites/items/{snack,gold,yarn,cookie,can,bell}.png (게임 너비의 2배)
- assets/sprites/buildings/prop_{chimney,antenna,railing}.png → prop_soft_*.png (채도 55%. 크기·불투명도는 게임이 그릴 때 정함, PLAN 1번)
게임 그림 크기(balance.gd OBSTACLES)의 2배로 저장해 고해상도 휴대폰에서도 흐리지 않게 한다.
개발용 도구 (numpy, scipy, Pillow 필요).
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

from clean_edges import clean
from cut_parts import remove_magenta

ROOT = Path(__file__).resolve().parent.parent
OBSTACLE_WIDTH = {"flock": 218, "pot": 84, "ac": 140, "tank": 135}
HEART_SIZE = (108, 92)
# 시트 이름 → (게임 파일 이름, 게임 안 너비: world_view.gd ITEM_WIDTHS). 제품 이름을 피해 질주 간식은 snack
ITEMS = {"churu": ("snack", 62), "gold": ("gold", 96), "yarn": ("yarn", 76), "heart_item": ("cookie", 72), "can": ("can", 76), "bell": ("bell", 70)}
SOFT_PROPS = ("chimney", "antenna", "railing")
PROP_SATURATION = 0.55


def soften(image: Image.Image, saturation: float = PROP_SATURATION) -> Image.Image:
    """알파는 그대로 두고 HSV 채도에 saturation을 곱한다."""
    alpha = image.getchannel("A")
    hsv = np.asarray(image.convert("RGB").convert("HSV")).copy()
    hsv[..., 1] = (hsv[..., 1] * saturation).round().astype(np.uint8)
    out = Image.fromarray(hsv, "HSV").convert("RGBA")
    out.putalpha(alpha)
    return out


def cut_obstacles(sheet: Path) -> dict:
    """시트에서 위 줄 왼쪽 큰 덩어리 셋 = 비둘기 무리, 나머지를 왼쪽부터 화분·실외기·물탱크로 묶어 자른다."""
    rgba = remove_magenta(np.asarray(Image.open(sheet).convert("RGB")))
    labels, found = ndimage.label(rgba[..., 3] > 128)
    sizes = ndimage.sum(np.ones_like(labels), labels, range(1, found + 1))
    boxes = []
    for label in np.argsort(sizes)[::-1][:6] + 1:
        rows, cols = ndimage.find_objects((labels == label).astype(int))[0]
        boxes.append((rows.start, rows.stop, cols.start, cols.stop))
    birds = [b for b in boxes if b[1] < 450]
    others = sorted((b for b in boxes if b[1] >= 450), key=lambda b: b[2])
    if len(birds) != 3 or len(others) != 3:
        raise ValueError(f"비둘기 3개와 장애물 3개가 필요한데 {len(birds)}, {len(others)}개")
    flock = (min(b[0] for b in birds), max(b[1] for b in birds), min(b[2] for b in birds), max(b[3] for b in birds))
    return {name: Image.fromarray(rgba[b[0]:b[1], b[2]:b[3]]) for name, b in zip(("flock", "pot", "ac", "tank"), [flock, *others])}


def main() -> None:
    out = ROOT / "assets/sprites/obstacles"
    out.mkdir(parents=True, exist_ok=True)
    for name, image in cut_obstacles(ROOT / "assets/raw/obstacles_noribbon.png").items():
        width = OBSTACLE_WIDTH[name] * 2
        image.resize((width, round(image.height * width / image.width)), Image.LANCZOS).save(out / f"{name}.png")
    hud = ROOT / "assets/sprites/hud"
    hud.mkdir(parents=True, exist_ok=True)
    for name in ("full", "crack", "empty"):
        Image.open(ROOT / f"review/v0.6.0/cut/heart_{name}.png").convert("RGBA").resize(HEART_SIZE, Image.LANCZOS).save(hud / f"heart_{name}.png")
    for cut, (name, width) in ITEMS.items():
        image = Image.open(ROOT / f"review/v0.6.0/cut/{cut}.png").convert("RGBA")
        small = image.resize((width * 2, round(image.height * width * 2 / image.width)), Image.LANCZOS)
        Image.fromarray(clean(np.asarray(small))).save(ROOT / f"assets/sprites/items/{name}.png")  # 줄일 때 생긴 분홍 테두리를 지움
    buildings = ROOT / "assets/sprites/buildings"
    for name in SOFT_PROPS:
        soften(Image.open(buildings / f"prop_{name}.png").convert("RGBA")).save(buildings / f"prop_soft_{name}.png")


if __name__ == "__main__":
    main()
