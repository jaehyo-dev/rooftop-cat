"""깔끔한 메뉴 종이·버튼 그림 (v0.7.0 2c 피드백 "깔끔한 UI"). 9칸 늘이기(NinePatch)용 작은 그림을 직접 그린다.
"거의 평면"(B, 2026-11-12 사용자 확정): 크림 판 + 또렷한 같은 굵기 갈색 테두리 + 바깥 얇은 밝은 테두리, 버튼은 주황·크림에 위아래 밝기 차이만.
사용: python3 tools/make_ui_paper.py assets/sprites/ui
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

# 종류: 크기, 둥근 모서리, 채움 위·아래 색 (9칸 여백은 scripts/ui/ui_kit.gd PAPER)
KINDS = {
    "panel": ((192, 192), 26, (255, 244, 222), (253, 238, 212)),
    "note": ((160, 160), 16, (255, 251, 240), (252, 245, 228)),
    "cream": ((200, 100), 34, (255, 248, 232), (246, 230, 202)),
    "orange": ((200, 100), 34, (248, 176, 96), (232, 136, 58)),
}
CORK = ((256, 256), 22)
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


def layer(rgb: np.ndarray, color, mask: np.ndarray) -> np.ndarray:
    return rgb * (1 - mask[..., None]) + np.array(color, float) * mask[..., None]


def cover(d: np.ndarray) -> np.ndarray:
    """거리 → 덮는 정도 (1px 부드러운 가장자리)"""
    return np.clip(0.5 - d, 0, 1)


def paper(size, radius, top, bottom) -> Image.Image:
    w, h = size
    d = rounded_sdf(w, h, EDGE, radius)
    t = (np.arange(h)[:, None] / (h - 1)) * np.ones((1, w))
    rgb = np.array(top, float) * (1 - t[..., None]) + np.array(bottom, float) * t[..., None]
    rgb = layer(rgb, BROWN, cover(d + HALO_W) - cover(d + HALO_W + LINE_W))
    rgb = layer(rgb, HALO, cover(d) - cover(d + HALO_W))
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255), cover(d) * 255]).astype(np.uint8), "RGBA")


def cork() -> Image.Image:
    (w, h), radius = CORK
    d = rounded_sdf(w, h, EDGE, radius)
    rgb = np.ones((h, w, 3)) * np.array(CORK_FILL, float)
    frame = 1 + HALO_W + LINE_W + 16  # 나무 테두리 안쪽 끝 (가장자리에서)
    wood = np.ones((h, w, 3)) * np.array(CORK_WOOD, float)
    inner = rounded_sdf(w, h, frame, max(4, radius - frame + 6))
    rgb = rgb * (1 - cover(-inner)[..., None]) + wood * cover(-inner)[..., None]          # 나무 테두리
    rgb = layer(rgb, BROWN, cover(inner - 1.5) - cover(inner + 1.5))                       # 안쪽 가는 선
    rgb = layer(rgb, BROWN, cover(d + HALO_W) - cover(d + HALO_W + LINE_W))
    rgb = layer(rgb, HALO, cover(d) - cover(d + HALO_W))
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255), cover(d) * 255]).astype(np.uint8), "RGBA")


def make(out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    for name, (size, radius, top, bottom) in KINDS.items():
        paper(size, radius, top, bottom).save(out / f"{name}.png")
    cork().save(out / "cork.png")


if __name__ == "__main__":
    make(Path(sys.argv[1]))
