"""주택가 시안(마젠타 배경)에서 건물 조각과 옥상 소품을 잘라 assets/sprites/buildings/ 에 저장한다.

사용: python3 tools/cut_buildings.py assets/raw/neighborhood_concept.png assets/sprites/buildings
- 건물 = 왼쪽 캡(l) / 반복 가운데 조각(m0, m1, ...) / 오른쪽 캡(r). 게임이 옥상 폭에 맞춰 가운데를 골라 늘여 이어 붙인다.
- 지붕 위 실외기·화분은 건물 그림에서 지우고(캡과 벽 무늬를 옆에서 복사) 소품으로 따로 저장한다.
- 모든 조각은 위쪽이 지붕 턱 윗면(첫 불투명 행)이라, 옥상 충돌선 = 조각의 맨 위 줄이다.
개발용 도구 (numpy, scipy, Pillow 필요). 게임은 결과 PNG만 쓴다.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

from cut_parts import remove_magenta

ART_SCALE = 0.8     # 건물 조각을 줄이는 비율 (게임에서 1:1로 그림)
PROP_SCALE = 0.7    # 소품을 줄이는 비율
CAP_TOP = 249       # 시트에서 건물 지붕 턱 윗줄 (행)
WALL_BOTTOM = 499   # 시트에서 건물 그림 아래 끝 (행)

# 시트 좌표(원본 픽셀). x0~x1 = 건물 전체(지붕 턱 포함), left/right = 캡이 끝나는 곳, mids = 가운데 조각 [시작, 끝)
# repair = (고칠 열 범위, 고칠 행 범위, 복사해 올 열 시작): 지붕 위 소품 흔적을 같은 높이의 깨끗한 곳으로 덮는다
BUILDINGS = {
    "brick": {"x0": 22, "x1": 507, "left": 72, "right": 488, "mids": [(72, 240), (240, 488)],
              "repair": ((85, 200), (244, 262), 300)},
    "villa": {"x0": 526, "x1": 1010, "left": 566, "right": 995, "mids": [(566, 676), (676, 785), (785, 995)],
              "repair": ((590, 715), (244, 312), 830)},
    "tile": {"x0": 1030, "x1": 1515, "left": 1085, "right": 1495, "mids": [(1085, 1240), (1240, 1495)],
             "repair": ((1090, 1200), (244, 262), 1250)},
}
# 소품: 시트에서 찾을 사각형 (왼쪽, 위, 오른쪽, 아래)
PROPS = {
    "chimney": (60, 695, 190, 875),
    "tank": (265, 630, 430, 878),
    "antenna": (475, 650, 680, 880),
    "plants": (705, 690, 935, 880),
    "railing": (985, 745, 1230, 878),
    "aircon": (1290, 745, 1490, 878),
}


SPILL_BAND = 3          # 가장자리 색을 가져올 수 있는 최대 거리 (픽셀)


def despill(rgba: np.ndarray) -> np.ndarray:
    """배경을 지운 뒤에도 가장자리에 남는 분홍·마젠타 기를 걷어 낸다.
    반투명한 가장자리 픽셀(알파 250 미만)의 색을 가까운(SPILL_BAND 픽셀 안) 불투명 픽셀 색으로 바꾼다. 알파는 그대로라 윤곽 모양은 같다."""
    rgba = rgba.copy()
    solid = rgba[..., 3] >= 250
    distance, (rows, cols) = ndimage.distance_transform_edt(~solid, return_indices=True)
    rim = (~solid) & (rgba[..., 3] > 0) & (distance <= SPILL_BAND)
    rgba[rim, :3] = rgba[rows[rim], cols[rim], :3]
    return rgba


def _resize(rgba: np.ndarray, scale: float) -> np.ndarray:
    """알파가 있는 그림을 줄인다 (가장자리에 마젠타·검정 기가 번지지 않게 알파 곱한 색으로 줄임)."""
    image = Image.fromarray(rgba).convert("RGBa")
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    return np.asarray(image.resize(size, Image.LANCZOS).convert("RGBA"))


def _top_row(rgba: np.ndarray) -> int:
    """맨 윗면: 가운데쯤 열에서 처음 불투명한 행."""
    return int(np.argmax(rgba[:, rgba.shape[1] // 2, 3] > 128))


def cut_building(sheet: np.ndarray, spec: dict) -> dict:
    """건물 하나 → {"l": 그림, "r": 그림, "m0": 그림, ...}, 아래 채움 색"""
    sheet = sheet.copy()
    (c0, c1), (r0, r1), source = spec["repair"]
    sheet[r0:r1, c0:c1] = sheet[r0:r1, source:source + (c1 - c0)]
    body = _resize(sheet[CAP_TOP:WALL_BOTTOM, spec["x0"]:spec["x1"]], ART_SCALE)
    body = body[_top_row(body):]
    def x(value):
        return round((value - spec["x0"]) * ART_SCALE)
    pieces = {"l": body[:, :x(spec["left"])], "r": body[:, x(spec["right"]):]}
    for index, (start, end) in enumerate(spec["mids"]):
        pieces[f"m{index}"] = body[:, x(start):x(end)]
    # 아래 채움 색: 모든 조각 맨 아랫부분 색의 가운데값 (대부분이 벽이라 창틀·화분에 휘둘리지 않음)
    patch = np.concatenate([piece[-10:-3].reshape(-1, 4) for piece in pieces.values()])
    fill = np.median(patch[patch[:, 3] > 200][:, :3], axis=0).round().astype(int)
    return {"pieces": pieces, "fill": "#%02x%02x%02x" % tuple(fill)}


def cut_prop(sheet: np.ndarray, rect: tuple) -> np.ndarray:
    left, top, right, bottom = rect
    part = sheet[top:bottom, left:right]
    rows, cols = np.where(part[..., 3] > 128)
    part = part[rows.min():rows.max() + 1, cols.min():cols.max() + 1]
    return _resize(part, PROP_SCALE)


def main(sheet_path: Path, out_dir: Path) -> None:
    sheet = despill(remove_magenta(np.asarray(Image.open(sheet_path).convert("RGB"))))
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, spec in BUILDINGS.items():
        built = cut_building(sheet, spec)
        for key, piece in built["pieces"].items():
            Image.fromarray(piece).save(out_dir / f"{name}_{key}.png")
        print(name, "채움 색", built["fill"], {k: v.shape[1] for k, v in built["pieces"].items()}, "높이", built["pieces"]["l"].shape[0])
    for name, rect in PROPS.items():
        prop = cut_prop(sheet, rect)
        Image.fromarray(prop).save(out_dir / f"prop_{name}.png")
        print("소품", name, prop.shape[1], "x", prop.shape[0])


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(Path(sys.argv[1]), Path(sys.argv[2]))
