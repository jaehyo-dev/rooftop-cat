"""발 미끄러짐 재기 (cat-parade 아기 움직임 1단계): 프레임 그림 달리기를 60장/초로 돌리며
바닥을 디딘 발의 세계 x가 디디는 동안 얼마나 움직이는지 잰다. 아기 A와 주인공을 같은 방법으로 (tools/test_kitten_motion.py).
사용: python3 tools/foot_slip.py [품종]  → 속도별 아기·주인공 최대 미끄러짐 (게임 픽셀)
- 장마다 디딘 발 = cut_kitten_motion.contacts (바닥선 위 2줄 안 불투명 덩어리).
- 같은 장이 이어지는 동안은 같은 발(그림 안 순서). 장이 바뀌면 (건너뛴 장도 차례로 지나며) 직전 세계 자리에서 MATCH 픽셀 안의
  디딘 발을 가장 가까운 짝부터 같은 발로, 짝이 없으면 들린 것 (그래서 한 장 안에서 크게 밀리는 발도 끝까지 잰다).
- 아기는 게임이 쓰는 KittenMotionData.ADVANCE[품종](scripts/logic/kitten_motion_data.gd)으로 장을 고른다 (KittenMotion.a_frame과 같음).
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


BREEDS = ("cheese", "mackerel", "tuxedo", "calico", "cow", "gray")  # CatParade.LOOKS


def kitten_a_frames(breed: str = "cheese") -> list:
    folder = ROOT / "assets/sprites/kitten_motion" / breed
    return [[(x - ckm.ANCHOR_X) * KITTEN_PX for x in ckm.contacts(Image.open(folder / f"run_{i}.png"))] for i in range(len(a_advance(breed)))]


def _runs(band) -> list:
    from scipy import ndimage
    labels, n = ndimage.label(ndimage.binary_closing(band, iterations=ckm.CONTACT_GAP) | band)
    return [float((labels == i).nonzero()[0].mean()) for i in range(1, n + 1)]


def a_advance(breed: str = "cheese") -> list:
    """게임이 쓰는 장마다 거리 (캔버스 픽셀, 장 수만큼)."""
    text = (ROOT / "scripts/logic/kitten_motion_data.gd").read_text()
    n = int(re.search(r"const RUN_FRAMES := (\d+)", text).group(1))
    return [float(re.search(rf'"{breed}": ([\d.]+)', text.split("const ADVANCE", 1)[1]).group(1))] * n


def frame_at(dist: float, advance: list, inside: bool = False):
    """KittenMotion.a_frame과 같음: 한 바퀴 안에서 장마다 거리만큼 머묾. inside면 (장, 그 장에서 간 거리)."""
    d = dist % sum(advance)
    for k, a in enumerate(advance):
        if d < a:
            return (k, d) if inside else k
        d -= a
    return (len(advance) - 1, advance[-1]) if inside else len(advance) - 1


def _match(active: list, feet: list, seen: bool) -> tuple:
    """디디던 발(active)과 새 장의 발(세계 x)을 MATCH 안에서 가장 가까운 짝부터 잇는다 (앞에서부터 고르면 새로 디딘 발이
    디디던 발의 짝을 빼앗아 미끄러짐을 부풀림, motion2). seen이면 보인 최소·최대에 넣는다. → (이은 발들, 들린 발들)"""
    pairs = sorted((abs(a[0] - x), i, j) for i, a in enumerate(active) for j, x in enumerate(feet) if abs(a[0] - x) <= MATCH)
    got, used = {}, set()
    for _, i, j in pairs:
        if i not in used and j not in got:
            got[j] = active[i]
            used.add(i)
    out = []
    for j, x in enumerate(feet):
        lo, hi = (got[j][1], got[j][2]) if j in got else (float("inf"), float("-inf"))
        out.append([x, min(lo, x), max(hi, x)] if seen else [x, lo, hi])
    return out, [a for i, a in enumerate(active) if i not in used]


def slip(frames: list, stride: float, speed: float, seconds: float = 3.0, advance: list = None) -> float:
    """거리 기준으로 장을 넘기며 디딘 발의 최대 미끄러짐. advance(게임 픽셀)가 없으면 장마다 stride / 장 수."""
    advance = advance or [stride / len(frames)] * len(frames)
    active = []  # 발마다 [잇는 데 쓰는 세계 x, 보인 최소, 보인 최대] (그림 안 순서대로)
    last_k = -1
    worst = 0.0
    n = len(frames)
    for tick in range(int(seconds * FPS)):
        body = speed * tick / FPS
        k, inside = frame_at(body, advance, True)
        abs_k = int(body // sum(advance)) * n + k  # 누적 장 번호 (한 바퀴 이상 건너뛰어도 놓치지 않게, Codex 리뷰)
        feet = sorted(body + x for x in frames[k])
        lifted = []
        if abs_k == last_k:  # 같은 장: 같은 발
            nxt = [[x, min(a[1], x), max(a[2], x)] for a, x in zip(active, feet)]
        else:
            # 건너뛴 장(빠르면 한 장면에 몇 장씩 넘어감)도 차례로 지나며 발을 잇는다. 그 장은 화면에 안 보였으니 최소·최대에는 안 넣음
            skipped = [j % n for j in range(last_k + 1, abs_k)] if last_k >= 0 else []
            start = body - inside
            starts = []
            for j in reversed(skipped):
                start -= advance[j]
                starts.append(start)
            for j, st in zip(skipped, reversed(starts)):
                active, gone = _match(active, [st + x for x in frames[j]], seen=False)
                lifted += gone
            nxt, gone = _match(active, feet, seen=True)
            lifted += gone
        for a in lifted:
            worst = max(worst, a[2] - a[1])
        active, last_k = nxt, abs_k
    for a in active:
        worst = max(worst, a[2] - a[1])
    return worst


def report(breed: str = "cheese") -> dict:
    a = kitten_a_frames(breed)
    adv = [x * KITTEN_PX for x in a_advance(breed)]
    return {"A": {v: round(slip(a, sum(adv), v, advance=adv), 1) for v in SPEEDS}, "A_stride": round(sum(adv), 1),
            "hero": {v: round(slip(hero_frames(), HERO_STRIDE, v), 1) for v in SPEEDS}, "hero_stride": HERO_STRIDE}


if __name__ == "__main__":
    print(report(sys.argv[1] if len(sys.argv) > 1 else "cheese"))
