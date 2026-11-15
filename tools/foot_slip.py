"""발 미끄러짐 재기 (cat-parade 아기 움직임 1단계): 프레임 그림 달리기를 60장/초로 돌리며
바닥을 디딘 발의 세계 x가 디디는 동안 얼마나 움직이는지 잰다. 아기 A와 주인공을 같은 방법으로 (tools/test_kitten_motion.py).
사용: python3 tools/foot_slip.py  → 속도별 A·주인공 최대 미끄러짐 (게임 픽셀)
- 장마다 디딘 발 = cut_kitten_motion.contacts (바닥선 위 2줄 안 불투명 덩어리).
- 같은 장이 이어지는 동안은 같은 발(그림 안 순서). 장이 바뀌면 직전 세계 자리에서 MATCH 픽셀 안의 가장 가까운 디딘 발이
  같은 발, 없으면 들린 것 (그래서 한 장 안에서 크게 밀리는 발도 끝까지 잰다).
- 아기 A는 게임이 쓰는 KittenMotionData.A_ADVANCE(scripts/logic/kitten_motion_data.gd)로 장을 고른다 (KittenMotion.a_frame과 같음).
- 미끄러짐 = 한 발이 디딘 동안 (세계 x 최대 - 최소).
"""
import re
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import cut_kitten_motion as ckm  # noqa: E402
from align_frames import ANCHOR_X as HERO_X, BASELINE as HERO_BASE  # noqa: E402

ROOT = Path(__file__).parent.parent
FPS = 60.0
MATCH = 24.0
SPEEDS = (430.0, 640.0, 950.0)
# 게임 픽셀 배율 (cat_view.gd·balance.gd와 같은 값을 읽음)
_balance = (ROOT / "scripts/balance.gd").read_text()
_view = (ROOT / "scripts/cat_view.gd").read_text()
BODY_W = float(re.search(r"CAT_BODY_SIZE := Vector2\(([\d.]+)", _balance).group(1))
HERO_STRIDE = float(re.search(r"const CAT_STRIDE := ([\d.]+)", _balance).group(1))
PARADE_SIZE = float(re.search(r"const PARADE_SIZE := ([\d.]+)", _balance).group(1))
KITTEN_ART = float(re.search(r"const KITTEN_ART := ([\d.]+)", _view).group(1))
HERO_PX = BODY_W / (711.0 * 0.5)          # CatView.art_scale()
KITTEN_PX = KITTEN_ART * HERO_PX * PARADE_SIZE  # KittenMotion.px()


def hero_frames() -> list:
    """주인공 달리기 4장의 디딘 발 x (게임 픽셀, 발끝 원점)."""
    out = []
    for i in range(4):
        img = Image.open(ROOT / f"assets/sprites/cat_frames/run_{i}.png")
        mask = ckm.opaque(img)
        band = mask[HERO_BASE - ckm.CONTACT_ROWS:HERO_BASE].any(axis=0)
        out.append([(x - HERO_X) * HERO_PX for x in _runs(band)])
    return out


def kitten_a_frames(folder: Path = ROOT / "assets/sprites/kitten_motion/cheese_a") -> list:
    return [[(x - ckm.ANCHOR_X) * KITTEN_PX for x in ckm.contacts(Image.open(folder / f"run_{i}.png"))] for i in range(8)]


def _runs(band) -> list:
    from scipy import ndimage
    labels, n = ndimage.label(ndimage.binary_closing(band, iterations=ckm.CONTACT_GAP) | band)
    return [float((labels == i).nonzero()[0].mean()) for i in range(1, n + 1)]


def a_advance() -> list:
    """게임이 쓰는 A 장마다 거리 (캔버스 픽셀)."""
    text = (ROOT / "scripts/logic/kitten_motion_data.gd").read_text()
    return [float(v) for v in re.search(r"const A_ADVANCE := \[([^\]]*)\]", text).group(1).split(",")]


def frame_at(dist: float, advance: list) -> int:
    """KittenMotion.a_frame과 같음: 한 바퀴 안에서 장마다 거리만큼 머묾."""
    d = dist % sum(advance)
    for k, a in enumerate(advance):
        d -= a
        if d < 0.0:
            return k
    return len(advance) - 1


def slip(frames: list, stride: float, speed: float, seconds: float = 3.0, advance: list = None) -> float:
    """거리 기준으로 장을 넘기며 디딘 발의 최대 미끄러짐. advance(게임 픽셀)가 없으면 장마다 stride / 장 수."""
    advance = advance or [stride / len(frames)] * len(frames)
    active = []  # 발마다 [마지막 x, 최소, 최대] (그림 안 순서대로)
    last_k = -1
    worst = 0.0
    for tick in range(int(seconds * FPS)):
        body = speed * tick / FPS
        k = frame_at(body, advance)
        feet = sorted(body + x for x in frames[k])
        if k == last_k:  # 같은 장: 같은 발
            nxt = [[x, min(a[1], x), max(a[2], x)] for a, x in zip(active, feet)]
        else:
            nxt = []
            pool = list(active)
            for x in feet:
                best = min(pool, key=lambda a: abs(a[0] - x), default=None)
                if best is not None and abs(best[0] - x) <= MATCH:
                    pool.remove(best)
                    nxt.append([x, min(best[1], x), max(best[2], x)])
                else:
                    nxt.append([x, x, x])
        for a in active:
            worst = max(worst, a[2] - a[1])
        active, last_k = nxt, k
    for a in active:
        worst = max(worst, a[2] - a[1])
    return worst


def report() -> dict:
    a = kitten_a_frames()
    adv = [x * KITTEN_PX for x in a_advance()]
    return {"A": {v: round(slip(a, sum(adv), v, advance=adv), 1) for v in SPEEDS}, "A_stride": round(sum(adv), 1),
            "hero": {v: round(slip(hero_frames(), HERO_STRIDE, v), 1) for v in SPEEDS}, "hero_stride": HERO_STRIDE}


if __name__ == "__main__":
    print(report())
