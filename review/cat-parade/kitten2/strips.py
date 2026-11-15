"""GIF 장면의 프레임을 한 장에 늘어놓은 필름 시트 (검수자가 움직임을 한눈에 보게). 줄 부분(make_gifs LINE_BOX)만 잘라 4열.
사용: python3 review/cat-parade/kitten2/strips.py <캡처 폴더> <출력 폴더> <장면> [건너뛰기]
"""
import sys
from pathlib import Path

from PIL import Image

BOX = (0, 90, 1024, 666)
COLS = 4
W = 480


def main(src: Path, out: Path, name: str, every: int) -> None:
    files = sorted(src.glob(f"{name}_f[0-9][0-9][0-9]_pc.png"))[::every]
    h = W * (BOX[3] - BOX[1]) // (BOX[2] - BOX[0])
    sheet = Image.new("RGB", (COLS * W, -(-len(files) // COLS) * h), "white")
    for i, f in enumerate(files):
        sheet.paste(Image.open(f).convert("RGB").crop(BOX).resize((W, h), Image.LANCZOS), ((i % COLS) * W, (i // COLS) * h))
    sheet.save(out / f"strip_{name}.jpg", quality=85)  # PNG는 5MB까지 커짐
    print(f"strip_{name}.jpg: {len(files)}장")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], int(sys.argv[4]) if len(sys.argv) > 4 else 1)
