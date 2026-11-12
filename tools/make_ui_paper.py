"""깔끔한 메뉴 종이·버튼 그림 (v0.7.0 2c 피드백 "깔끔한 UI"). 9칸 늘이기(NinePatch)용 작은 그림을 직접 그린다.
번짐·얼룩 없이: 크림 판 + 또렷한 같은 굵기 갈색 테두리 + 바깥 얇은 밝은 테두리, 버튼은 주황·크림에 위아래 밝기 차이만.
  a = "깔끔한 종이": 판·쪽지·코르크에 아주 옅은 결 (난수는 시드 고정, 게임은 결을 바둑판처럼 이어 붙임)
  b = "거의 평면": 결 없음
사용: python3 tools/make_ui_paper.py assets/sprites/ui   (→ clean_a/, clean_b/)
개발용 도구 (numpy, Pillow). 게임은 결과 PNG만 쓴다.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

BROWN = (90, 70, 54)      # UiKit.BROWN
HALO = (255, 249, 236)    # 바깥 얇은 밝은 테두리 (복잡한 배경에서도 판이 보이게)
EDGE = 1                  # 가장자리 1px은 비움 (그림 가장자리 검사)
HALO_W = 2
LINE_W = 4                # 갈색 테두리 굵기: 모든 판·버튼이 같음 (가장자리에서 1+2+4 = 7px, 글자 칸 검사 8px 안)

# 종류: 크기, 둥근 모서리, 채움 위·아래 색, 결 세기(a만), 9칸 여백(scripts/ui/ui_kit.gd PAPER와 같음)
# 결이 있는 a 종이는 게임이 바둑판처럼 이어 붙이므로(늘이면 결이 번져 보임) 위아래 밝기 차이 없이 한 색 + 이어 붙는 결
KINDS = {
    "panel": ((192, 192), 26, (255, 244, 222), (253, 238, 212), 0.02, 40),
    "note": ((160, 160), 16, (255, 251, 240), (252, 245, 228), 0.016, 30),
    "cream": ((200, 100), 34, (255, 248, 232), (246, 230, 202), 0.0, 40),
    "orange": ((200, 100), 34, (248, 176, 96), (232, 136, 58), 0.0, 40),
}
CORK = ((256, 256), 22, 48)
CORK_WOOD = (196, 146, 96)
CORK_FILL = (214, 168, 112)


def rounded_sdf(w: int, h: int, inset: float, radius: float) -> np.ndarray:
    """둥근 사각형까지 거리 (안쪽 음수). 픽셀 가운데 기준"""
    y, x = np.mgrid[0:h, 0:w] + 0.5
    hw, hh = w / 2 - inset, h / 2 - inset
    qx = np.abs(x - w / 2) - (hw - radius)
    qy = np.abs(y - h / 2) - (hh - radius)
    outside = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    return outside + np.minimum(np.maximum(qx, qy), 0) - radius


def grain(w: int, h: int, seed: int) -> np.ndarray:
    """평균 0, 표준편차 1인 부드러운 결 (가로·세로로 이어지게 둘러 흐림)"""
    n = np.random.default_rng(seed).standard_normal((h, w))
    for _ in range(3):  # 5x5 상자 흐림 세 번 (둘러 이어짐): 점이 아니라 옅은 결로
        n = sum(np.roll(np.roll(n, dy, 0), dx, 1) for dy in range(-2, 3) for dx in range(-2, 3)) / 25
    return (n - n.mean()) / n.std()


def tiled_grain(w: int, h: int, margin: int, seed: int) -> np.ndarray:
    """9칸 가운데 칸 크기로 되풀이되는 결을 그림 전체에 깐다 (가운데·가장자리 띠를 이어 붙여도 이음매가 없게)"""
    tw, th = w - 2 * margin, h - 2 * margin
    g = grain(tw, th, seed)
    y, x = np.mgrid[0:h, 0:w]
    return g[(y - margin) % th, (x - margin) % tw]


def layer(rgb: np.ndarray, color, mask: np.ndarray) -> np.ndarray:
    return rgb * (1 - mask[..., None]) + np.array(color, float) * mask[..., None]


def cover(d: np.ndarray) -> np.ndarray:
    """거리 → 덮는 정도 (1px 부드러운 가장자리)"""
    return np.clip(0.5 - d, 0, 1)


def paper(size, radius, top, bottom, grain_amp, seed, margin=0) -> Image.Image:
    w, h = size
    d = rounded_sdf(w, h, EDGE, radius)
    if grain_amp:  # 이어 붙이는 종이: 한 색 + 이어지는 결
        rgb = np.ones((h, w, 3)) * ((np.array(top, float) + bottom) / 2) * (1 + grain_amp * tiled_grain(w, h, margin, seed))[..., None]
    else:
        t = (np.arange(h)[:, None] / (h - 1)) * np.ones((1, w))
        rgb = np.array(top, float) * (1 - t[..., None]) + np.array(bottom, float) * t[..., None]
    rgb = layer(rgb, BROWN, cover(d + HALO_W) - cover(d + HALO_W + LINE_W))
    rgb = layer(rgb, HALO, cover(d) - cover(d + HALO_W))
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255), cover(d) * 255]).astype(np.uint8), "RGBA")


def cork(with_grain: bool) -> Image.Image:
    (w, h), radius, margin = CORK
    d = rounded_sdf(w, h, EDGE, radius)
    rgb = np.ones((h, w, 3)) * np.array(CORK_FILL, float)
    if with_grain:
        rgb *= 1 + 0.035 * tiled_grain(w, h, margin, 7)[..., None]
    frame = 1 + HALO_W + LINE_W + 16  # 나무 테두리 안쪽 끝 (가장자리에서)
    wood = np.ones((h, w, 3)) * np.array(CORK_WOOD, float)
    inner = rounded_sdf(w, h, frame, max(4, radius - frame + 6))
    rgb = rgb * (1 - cover(-inner)[..., None]) + wood * cover(-inner)[..., None]          # 나무 테두리
    rgb = layer(rgb, BROWN, cover(inner - 1.5) - cover(inner + 1.5))                       # 안쪽 가는 선
    rgb = layer(rgb, BROWN, cover(d + HALO_W) - cover(d + HALO_W + LINE_W))
    rgb = layer(rgb, HALO, cover(d) - cover(d + HALO_W))
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255), cover(d) * 255]).astype(np.uint8), "RGBA")


def make(out: Path) -> None:
    for look in ("a", "b"):
        folder = out / f"clean_{look}"
        folder.mkdir(parents=True, exist_ok=True)
        for i, (name, (size, radius, top, bottom, amp, margin)) in enumerate(KINDS.items()):
            paper(size, radius, top, bottom, amp if look == "a" else 0.0, i + 1, margin).save(folder / f"{name}.png")
        cork(look == "a").save(folder / "cork.png")


if __name__ == "__main__":
    make(Path(sys.argv[1]))
