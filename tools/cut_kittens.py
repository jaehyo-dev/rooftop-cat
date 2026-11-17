"""아기 고양이 동작 시트(마젠타 배경, 6열 x 3줄, 17칸)를 게임 프레임으로 자르고 맞춘다 (cat-parade).

사용: python3 tools/cut_kittens.py <시트.png> <출력 폴더>
예:   python3 tools/cut_kittens.py assets/raw/kittens/cheese_1.png assets/sprites/kittens/cheese
- 칸 순서(NAMES)는 review/cat-parade/kitten2/prompts/common.txt와 같다. 덩어리 17개를 줄 → 왼쪽부터로 읽는다.
- 크기: 시트마다 달리기 4장의 불투명 넓이 가운데값이 RUN_AREA가 되게 (모든 아기가 같은 크기, 프레임마다 배율 하나).
- 위치: 주인공 프레임(align_frames.py)처럼 발끝(가장 아랫줄)을 BASELINE에, 꼬리 쪽을 뺀 몸 중심을 ANCHOR_X에.
  "도망"(flee)은 왼쪽을 보고 그려져 좌우를 뒤집어 저장한다 (게임이 다시 뒤집어 그림).
- 기다리기: wait 그림에서 세운 꼬리를 떼어 몸(wait)과 꼬리(wait_tail_0~4, 꼬리 뿌리 축으로 돌림)로 나눈다.
  몸은 한 장이라 꼬리가 살랑여도 몸이 떨리지 않는다 (주인공 make_sit_tail.py와 같은 생각).
- 얼굴: 기다리기 몸에서 머리를 정사각형으로 잘라 face.png (HUD·결과 카드 얼굴 줄).
게임은 이 그림을 KITTEN_ART(cat_view.gd)배로 키워 그린다. 개발용 도구 (numpy, scipy, Pillow).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).parent))
from align_frames import TAIL_SHARE, opaque  # noqa: E402
from cut_parts import remove_magenta  # noqa: E402

NAMES = ["run_0", "run_1", "run_2", "run_3", "crouch", "takeoff",
         "rise", "fall", "land", "flail", "flip_tuck", "flip_curl",
         "flip_ball", "flip_open", "wait", "scared", "flee"]
CANVAS = (256, 240)
ANCHOR_X = 140         # cat_view.gd KITTEN_ANCHOR.x
BASELINE = 216         # cat_view.gd KITTEN_ANCHOR.y
RUN_AREA = 15500.0     # 달리기 4장 불투명 넓이 가운데값 (게임에서 폭 약 110px = 주인공의 0.56배)
JOIN = 4               # 방울·리본처럼 떨어진 작은 조각을 몸에 붙이는 닫기 반복
TAIL_DIP = 12          # 꼬리 꼭대기와 등의 오목한 곳 높이 차이가 이보다 작으면 꼬리를 떼지 않음
TAIL_OVERLAP = 10      # 꼬리 그림을 경계 아래로 더 가져가는 픽셀 (돌려도 뿌리에 틈이 안 보이게)
TAIL_ANGLES = [-8, -4, 0, 4, 8]  # 기다리기 꼬리 (도, 양수 = 꼬리 끝이 뒤로)
FACE_HEAD = 0.78      # 배지 지름에 대한 머리(귀·삐친 털 포함) 지름
# 기다리기 그림(wait.png)에서 눈으로 잰 머리 가운데 x, y와 지름 (귀 끝·삐친 털 포함). 시트를 다시 뽑으면 다시 잰다
FACE_AT = {"cheese": (151, 142, 98), "mackerel": (147, 143, 95), "tuxedo": (153, 137, 98),
           "calico": (150, 150, 95), "cow": (153, 140, 105), "gray": (149, 131, 120)}
FACE_RING = 0.05       # 얼굴 배지 갈색 테두리 굵기 (지름 비율, 96px에서 약 5px)
FACE_PAPER = (255, 251, 240, 255)  # ui_kit.gd PAPER
FACE_BROWN = (90, 70, 54, 255)     # ui_kit.gd BROWN
FACE_SIZE = 96


def blobs(mask: np.ndarray, count: int) -> list:
    """가장 큰 덩어리 count개의 (위, 아래, 왼쪽, 오른쪽)을 줄(위→아래) → 왼쪽부터 순서로."""
    labels, found = ndimage.label(ndimage.binary_closing(mask, iterations=JOIN) | mask)
    if found < count:
        raise ValueError(f"덩어리가 {count}개 필요한데 {found}개")
    sizes = ndimage.sum(mask, labels, range(1, found + 1))
    boxes = []
    for label in np.argsort(sizes)[::-1][:count] + 1:
        rows, cols = ndimage.find_objects((labels == label).astype(int))[0]
        boxes.append((rows.start, rows.stop, cols.start, cols.stop, label))
    boxes.sort(key=lambda b: (b[0] + b[1]) / 2)
    lines = []
    for box in boxes:
        middle = (box[0] + box[1]) / 2
        if lines and abs(middle - lines[-1][0]) < 120:
            lines[-1][1].append(box)
        else:
            lines.append([middle, [box]])
    return [(b, labels) for _, line in lines for b in sorted(line, key=lambda b: b[2])]


def body_center_x(mask: np.ndarray) -> float:
    cols = np.nonzero(mask.any(axis=0))[0]
    left = cols[0] + (cols[-1] - cols[0]) * TAIL_SHARE
    xs = np.nonzero(mask)[1]
    return float(xs[xs >= left].mean())


def place(image: Image.Image, scale: float) -> Image.Image:
    small = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))), Image.LANCZOS)
    mask = opaque(small)
    rows = np.nonzero(mask.any(axis=1))[0]
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    canvas.paste(small, (round(ANCHOR_X - body_center_x(mask)), BASELINE - (rows[-1] + 1)))
    if opaque(canvas).sum() < mask.sum() * 0.995:
        raise ValueError("프레임이 캔버스 밖으로 나감: CANVAS·ANCHOR_X·BASELINE 조정")
    return canvas


def split_tail(wait: Image.Image) -> tuple:
    """기다리기 그림 → (꼬리 뗀 몸, [꼬리 돌린 그림...]).
    세운 꼬리는 엉덩이에 붙어 있어 윗선(열마다 가장 위 픽셀)으로 찾는다: 왼쪽의 꼬리 꼭대기와 오른쪽 머리 꼭대기 사이에서
    윗선이 가장 낮은 곳(등의 오목한 곳)이 꼬리와 몸의 경계. 그 왼쪽·그 높이 위가 꼬리다.
    꼬리 그림은 경계 아래 TAIL_OVERLAP만큼 더 가져가 돌려도 뿌리에 틈이 안 보이게 하고 게임은 몸 뒤에 그린다.
    오목한 곳이 TAIL_DIP보다 얕으면(젖소의 짧은 방울 꼬리) 꼬리를 떼지 않는다 (꼬리 그림은 빈 그림)."""
    rgba = np.array(wait)
    mask = rgba[..., 3] > 20
    cols = np.nonzero(mask.any(axis=0))[0]
    top = np.where(mask.any(axis=0), mask.argmax(axis=0), mask.shape[0])
    mid = (cols[0] + cols[-1]) // 2
    tail_x = cols[0] + int(np.argmin(top[cols[0]:cols[0] + (mid - cols[0]) * 2 // 3]))
    head_x = mid + int(np.argmin(top[mid:cols[-1] + 1]))
    dip_x = tail_x + int(np.argmax(top[tail_x:head_x]))
    empty = Image.new("RGBA", wait.size, (0, 0, 0, 0))
    if top[dip_x] - top[tail_x] < TAIL_DIP:
        return wait, [empty] * len(TAIL_ANGLES)
    cut_y = int(top[dip_x]) + 2
    ys, xs = np.mgrid[:mask.shape[0], :mask.shape[1]]
    tail = mask & (xs < dip_x) & (ys < cut_y)
    root_xs = np.nonzero(tail[cut_y - 1])[0]
    root = (float(root_xs.mean()), float(cut_y))
    tail_rgba = rgba.copy()
    tail_rgba[~(mask & (xs < dip_x) & (ys < cut_y + TAIL_OVERLAP))] = 0
    body_rgba = rgba.copy()
    body_rgba[tail] = 0
    tail_img = Image.fromarray(tail_rgba)
    return Image.fromarray(body_rgba), [tail_img.rotate(a, resample=Image.BICUBIC, center=root) for a in TAIL_ANGLES]


def face(body: Image.Image, at: tuple) -> Image.Image:
    """얼굴 배지: 크림 원(ART_BIBLE 13-1 쪽지 크림) 안에 머리, 갈색 테두리. at = (머리 가운데 x, y, 머리 지름) 기다리기 그림 픽셀.
    머리 지름이 원의 FACE_HEAD 비율이 되게 잘라 6마리 머리 크기·자리가 같다 (원 밖에 걸린 몸통은 잘림)."""
    cx, cy, d = at
    half = d / FACE_HEAD * 0.5
    big = FACE_SIZE * 4  # 4배로 그려 줄여 원 가장자리를 매끈하게
    head = body.crop((round(cx - half), round(cy - half), round(cx + half), round(cy + half))).resize((big, big), Image.LANCZOS)
    ring = round(big * FACE_RING)
    disc = Image.new("L", (big, big), 0)
    ImageDraw.Draw(disc).ellipse((ring, ring, big - ring - 1, big - ring - 1), fill=255)
    out = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    out.paste(FACE_PAPER, (0, 0), disc)
    clipped = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    clipped.paste(head, (0, 0), ImageChops.multiply(head.getchannel("A"), disc))
    out.alpha_composite(clipped)
    ImageDraw.Draw(out).ellipse((ring // 2, ring // 2, big - ring // 2 - 1, big - ring // 2 - 1), outline=FACE_BROWN, width=ring)
    return out.resize((FACE_SIZE, FACE_SIZE), Image.LANCZOS)


def cut(sheet: Path, out_dir: Path) -> dict:
    rgba = remove_magenta(np.asarray(Image.open(sheet).convert("RGB")))
    mask = rgba[..., 3] > 128
    frames = {}
    for name, ((top, bottom, left, right, label), labels) in zip(NAMES, blobs(mask, len(NAMES))):
        piece = rgba[top:bottom, left:right].copy()
        piece[labels[top:bottom, left:right] != label] = 0  # 옆 칸 조각이 끼지 않게
        img = Image.fromarray(piece)
        frames[name] = img.transpose(Image.FLIP_LEFT_RIGHT) if name == "flee" else img
    scale = (RUN_AREA / float(np.median([opaque(frames[f"run_{i}"]).sum() for i in range(4)]))) ** 0.5
    out_dir.mkdir(parents=True, exist_ok=True)
    placed = {name: place(img, scale) for name, img in frames.items()}
    placed["wait"], tails = split_tail(placed["wait"])
    for i, t in enumerate(tails):
        placed[f"wait_tail_{i}"] = t
    for name, img in placed.items():
        if name.startswith("wait"):  # 줄·도망 아기 그림은 이제 kitten_motion (cut_kitten_motion.py), 여기서는 기다리는 길고양이만
            img.save(out_dir / f"{name}.png")
    face(placed["wait"], FACE_AT[out_dir.name]).save(out_dir / "face.png")
    return {"scale": scale}


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    print(cut(Path(sys.argv[1]), Path(sys.argv[2])))
