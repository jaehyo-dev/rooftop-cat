"""아기 고양이 시안 시트에서 달리는 6마리를 잘라 게임 화면(6마리 줄 자리)에 실제 크기로 얹는다 (시안 확인용, 게임에는 안 씀).

사용: python3 review/cat-parade/kitten/composite.py review/cat-parade/kitten/01_round.png <캡처 폴더> <결과.png>
- 캡처 폴더: qa_web.mjs ... parade_bare x pc 결과 (bare_pc = 아기 숨김, bare_none_pc = 주인공도 숨김)
- 크기: 아기 폭 가운데값 = 게임 속 주인공 폭 x 0.56. 자리: 게임과 같은 줄 간격(주인공 발끝 518, 115, 69), 바닥은 주인공 발 높이.
- 주인공은 아기들 위에 다시 얹는다 (게임과 같은 그리는 순서).
개발용 (numpy, scipy, Pillow).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
from cut_parts import remove_magenta  # noqa: E402

KIDS = 6
# scripts/balance.gd와 같은 값 (6마리일 때 주인공 화면 x = CatParade.screen_x(6))
SIZE = 0.56
LEAD_GAP = 115
GAP = 69
HERO_X = 518


def blobs(mask: np.ndarray, count: int, close: int) -> list:
    """가장 큰 덩어리 count개의 (위, 아래, 왼쪽, 오른쪽). 방울·리본처럼 떨어진 작은 조각은 close만큼 붙여 한 덩어리로."""
    joined = ndimage.binary_closing(mask, iterations=close) | mask
    labels, found = ndimage.label(joined)
    sizes = ndimage.sum(mask, labels, range(1, found + 1))
    out = []
    for label in np.argsort(sizes)[::-1][:count] + 1:
        rows, cols = ndimage.find_objects((labels == label).astype(int))[0]
        out.append((rows.start, rows.stop, cols.start, cols.stop))
    return out


def main(sheet_path: str, shots: str, out_path: str) -> None:
    rgba = remove_magenta(np.asarray(Image.open(sheet_path).convert("RGB")))
    sheet = Image.fromarray(rgba)
    found = blobs(rgba[..., 3] > 128, 1 + 2 * KIDS, 6)
    hero = max(found, key=lambda b: (b[1] - b[0]) * (b[3] - b[2]))
    kids = [b for b in found if b != hero]
    middle = np.median([(b[0] + b[1]) / 2 for b in kids])
    running = sorted([b for b in kids if (b[0] + b[1]) / 2 > middle], key=lambda b: b[2])  # 아래 줄 = 달리는 자세
    assert len(running) == KIDS, f"달리는 아기 {len(running)}마리"

    shot = Path(shots)
    bare = np.asarray(Image.open(shot / "bare_pc.png").convert("RGB")).astype(int)
    none = np.asarray(Image.open(shot / "bare_none_pc.png").convert("RGB")).astype(int)
    # 게임 속 주인공: 주인공이 있는 화면 - 없는 화면 (HUD 숫자 등 다른 움직임은 주인공 둘레 밖이라 뺌)
    hero_mask = np.abs(bare - none).sum(2) > 24
    hero_mask[:, :HERO_X - 260] = False
    hero_mask[:, HERO_X + 200:] = False
    hero_mask[:200] = False
    rows = np.where(hero_mask.any(1))[0]
    cols = np.where(hero_mask.any(0))[0]
    ground, nose = rows[-1], cols[-1]
    # 아기 크기: 시트의 아기 달리기 폭 가운데값이 게임 속 주인공 폭 x PARADE_SIZE가 되게 (아기끼리 크기 차이는 그대로)
    ratio = np.median([b[3] - b[2] for b in running]) / (hero[3] - hero[2])
    k = (cols[-1] - cols[0] + 1) / (hero[3] - hero[2]) * SIZE / ratio
    out = Image.fromarray(none.astype(np.uint8)).convert("RGBA")
    shade = Image.new("RGBA", out.size)
    pasted = []
    for i, (top, bottom, left, right) in enumerate(running[::-1]):  # 오른쪽(앞) 아기부터 줄 앞자리에
        kid = sheet.crop((left, top, right, bottom))
        kid = kid.resize((round(kid.width * k), round(kid.height * k)), Image.LANCZOS)
        feet = HERO_X - LEAD_GAP - GAP * i
        x = round(feet + (nose - HERO_X) * SIZE) - kid.width  # 코끝 = 발끝 + 주인공 코 거리 x 크기
        pasted.append((kid, (x, ground - kid.height + 1)))
        ImageDraw.Draw(shade).ellipse((x + kid.width * 0.15, ground - 5, x + kid.width * 0.85, ground + 5), fill=(90, 70, 50, 70))
    out.alpha_composite(shade.filter(ImageFilter.GaussianBlur(3)))
    for kid, at in reversed(pasted):  # 맨 뒤 아기부터 (앞 아기가 위에)
        out.alpha_composite(kid, at)
    # 주인공을 다시 위에 (게임과 같은 그리는 순서)
    mask = Image.fromarray((hero_mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))
    out.paste(Image.fromarray(bare.astype(np.uint8)), (0, 0), mask)
    out.convert("RGB").save(out_path)
    ratio = np.median([(b[3] - b[2]) for b in running]) / (hero[3] - hero[2])
    print(f"{out_path}: 시트의 아기 달리기 폭 / 주인공 폭 = {ratio:.2f} (요청 {SIZE}), 게임 속 주인공 폭 {cols[-1] - cols[0] + 1}px")


if __name__ == "__main__":
    main(*sys.argv[1:4])
