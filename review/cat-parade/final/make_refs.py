"""Codex에 넘길 아기 참고 그림 (흰 바탕에 나란히): ref_<품종>_frames.png = 달리기·웅크림·도약·오름·내림·착지 (공중 시트용),
ref_<품종>_scared.png = 달리기·웅크림·멈칫 (놀람 시트용). 사용: python3 review/cat-parade/final/make_refs.py <품종>"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SETS = {"frames": ["run_0", "crouch", "takeoff", "rise", "fall", "land"], "scared": ["run_0", "crouch", "startle"]}


def strip(folder: Path, names: list) -> Image.Image:
    imgs = [Image.open(folder / f"{n}.png").convert("RGBA") for n in names]
    w, h = imgs[0].size
    out = Image.new("RGBA", (w * len(imgs), h), (255, 255, 255, 255))
    for i, im in enumerate(imgs):
        out.alpha_composite(im, (i * w, 0))
    return out.convert("RGB")


if __name__ == "__main__":
    breed = sys.argv[1]
    for kind, names in SETS.items():
        strip(ROOT / f"assets/sprites/kitten_motion/{breed}", names).save(Path(__file__).parent / f"prompts/ref_{breed}_{kind}.png")
