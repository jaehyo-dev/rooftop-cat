"""캡처 프레임(<장면>_f000_pc.png…)을 GIF로 묶는다. 한 장 = 1/15초 (gap6_slow는 2 step마다 찍어 4배 느림).
사용: python3 review/cat-parade/make_gifs.py <캡처 폴더> review/cat-parade
3MB를 넘으면 폭을 줄여 다시 만든다 (CLAUDE.md: review GIF 3MB 이하).
"""
import re
import sys
from collections import defaultdict
from pathlib import Path

from PIL import Image

LIMIT = 3 * 1024 * 1024
# 프레임이 많은 느린 것은 두 장에 한 장만 쓰고 한 장을 두 배로 보인다 (같은 4배 느림, 3MB 안)
EVERY = {"gap6_slow": 2}


def main(src: Path, out: Path) -> None:
    clips = defaultdict(list)
    for f in sorted(src.glob("*_f[0-9][0-9][0-9]_pc.png")):
        clips[re.sub(r"_f\d{3}_pc\.png$", "", f.name)].append(f)
    for name, files in clips.items():
        every = EVERY.get(name, 1)
        files = files[::every]
        for width in (640, 560, 480, 400):
            frames = [Image.open(f).convert("RGB").resize((width, width * 9 // 16), Image.LANCZOS) for f in files]
            pal = frames[len(frames) // 2].quantize(colors=128, method=Image.Quantize.MEDIANCUT)
            frames = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
            path = out / f"{name}.gif"
            frames[0].save(path, save_all=True, append_images=frames[1:], duration=67 * every, loop=0, optimize=True)
            if path.stat().st_size <= LIMIT:
                break
        print(f"{path.name}: {len(files)}장, 폭 {width}, {path.stat().st_size / 1024 / 1024:.2f}MB")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
