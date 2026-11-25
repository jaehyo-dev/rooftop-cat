"""v0.8.0 1부 확인 자료 (review/restructure/v0.8-art/).
사용: python3 make_review.py gifs              # 적 반복 동작 GIF (실제 크기·2배) + 멈춘 장 줄
      python3 make_review.py shots <찍은 폴더>  # 1-1 정지 화면(PC·폰)을 시안 scene_1-1.png와 나란히, 평지 영상(실제·0.25배)
찍기: GODOT=<경로> bash review/v0.7.0/2c-juice/export_qa.sh →
      PLAYWRIGHT=<경로> node review/cat-parade/qa_web.mjs build/qa <폴더> parade_art x pc  (폰은 parade_art-still x phone)
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "review/cat-parade/motion"))
import make_videos as mv  # noqa: E402

FONT = ImageFont.truetype(str(ROOT / "assets/fonts/jua/Jua-Regular.ttf"), 22)
INK = (0x33, 0x18, 0x06)
ROOF = (0xFE, 0xE7, 0xC8)  # 옥상 턱 크림 (14-2)
SKY = (0xC3, 0xE0, 0xFD)
ENEMY = ROOT / "assets/sprites/enemies"
LOOPS = {"crow": (["fly_0", "fly_1", "fly_2", "fly_3"], 10), "rat": (["run_0", "run_1", "run_2", "run_3"], 12)}
STILLS = {"crow": ["dash", "hit"], "rat": ["surprise", "hit"]}
PACK = [0, 2, 1]  # EnemyAnim.PACK_OFFSETS
RAT_FOOT_Y = 236  # EnemyAnim.FOOT.rat.y (파일 px)


def frame(kind, name, scale):
    """적 그림 한 장 (scale 1 = 게임 크기 = 파일의 1/2)."""
    im = Image.open(ENEMY / kind / f"{name}.png").convert("RGBA")
    return im.resize((round(im.width * scale / 2), round(im.height * scale / 2)), Image.LANCZOS)


def gifs():
    for scale, tag in ((1, "x1"), (2, "x2")):
        names, fps = LOOPS["crow"]
        crow = [frame("crow", n, scale) for n in names]
        names, fps_r = LOOPS["rat"]
        rats = [frame("rat", n, scale) for n in names]
        gap = round(rats[0].width * 0.8)
        w = crow[0].width + gap * 2 + rats[0].width + 20 * scale
        h = max(crow[0].height, rats[0].height) + 20 * scale
        out = []
        for i in range(100):  # 1/50초 간격으로 2초 (GIF는 20ms보다 짧으면 브라우저가 느리게 틂)
            t = i / 50
            bg = Image.new("RGBA", (w, h), SKY + (255,))
            d = ImageDraw.Draw(bg)
            floor = h - 10 * scale
            d.rectangle([0, floor, w, h], fill=ROOF + (255,))
            d.line([0, floor, w, floor], fill=INK + (255,), width=max(1, round(1.5 * scale)))
            c = crow[int(t * fps) % 4]
            bg.alpha_composite(c, (0, 0))
            for j in range(3):
                r = rats[(int(t * fps_r) + PACK[j]) % 4]
                bg.alpha_composite(r, (crow[0].width + 10 * scale + j * gap, floor - round(RAT_FOOT_Y * scale / 2)))
            out.append(bg.convert("RGB"))
        out[0].save(HERE / f"enemies_loop_{tag}.gif", save_all=True, append_images=out[1:], duration=20, loop=0)
        # 멈춘 장 (돌진·맞음·놀람)
        row = [frame(k, n, scale) for k in STILLS for n in STILLS[k]]
        strip = Image.new("RGB", (sum(r.width for r in row) + 20 * len(row), max(r.height for r in row) + 30), SKY)
        x = 10
        for (k, n), r in zip([(k, n) for k in STILLS for n in STILLS[k]], row):
            strip.paste(r, (x, 30), r)
            ImageDraw.Draw(strip).text((x, 4), f"{k}/{n}", fill=INK, font=FONT)
            x += r.width + 20
        strip.save(HERE / f"enemies_stills_{tag}.png")
        print(f"enemies_loop_{tag}.gif {(HERE / f'enemies_loop_{tag}.gif').stat().st_size / 1e6:.2f}MB")


def label(im, text):
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 12 + len(text) * 22, 34], fill=(255, 255, 255))
    d.text((8, 4), text, fill=INK, font=FONT)
    return im


def shots(src: Path):
    concept = Image.open(HERE.parent / "enemies/scene_1-1.png").convert("RGB").resize((1280, 720))
    stills = sorted(src.glob("art_still_*_pc.png"))
    for f in stills:
        im = Image.open(f).convert("RGB")
        out = Image.new("RGB", (1280, 1450), (255, 255, 255))
        out.paste(label(concept.copy(), "시안 scene_1-1"), (0, 0))
        out.paste(label(im, "게임 " + f.stem.replace("_pc", "")), (0, 730))
        out.save(HERE / f"compare_{f.stem.replace('_pc', '')}.jpg", quality=88)
    pencil = sorted(src.glob("art_pencil_*_pc.png"))
    if pencil:  # 같은 자리 = 같은 번호 (art_pencil_5 ↔ art_still_5)
        a = Image.open(pencil[0]).convert("RGB")
        b = Image.open(str(pencil[0]).replace("art_pencil_", "art_still_")).convert("RGB")
        out = Image.new("RGB", (1280, 1450), (255, 255, 255))
        out.paste(label(a, "예전 배경 (같은 자리)"), (0, 0))
        out.paste(label(b, "카툰 배경"), (0, 730))
        out.save(HERE / "compare_pencil_vs_cartoon.jpg", quality=88)
    for f in sorted(src.glob("art_still_*_phone.png")):
        im = Image.open(f).convert("RGB")
        out = Image.new("RGB", (844, 390 * 2 + 10), (255, 255, 255))
        out.paste(label(concept.resize((844, 475)).crop((0, 42, 844, 432)), "시안 (폰 크기)"), (0, 0))
        out.paste(label(im, "게임 폰 844x390"), (0, 400))
        out.save(HERE / f"phone_{f.stem.replace('_phone', '')}.jpg", quality=88)
    mv.BOX = (0, 0, 1280, 720)
    for speed in ("real", "slow"):
        files = mv.frames(src, f"art_flat_{speed}")
        if files:
            mv.mp4(files, mv.FPS[speed], HERE / f"flat_{speed}.mp4", width=1280)
            print(f"flat_{speed}.mp4 {len(files)}장 {(HERE / f'flat_{speed}.mp4').stat().st_size / 1e6:.2f}MB")
    for f in src.glob("console_*.txt"):
        text = f.read_text().strip()
        print(f"{f.name}: 콘솔 오류 {len(text.splitlines()) if text else 0}")


if __name__ == "__main__":
    if sys.argv[1] == "gifs":
        gifs()
    else:
        shots(Path(sys.argv[2]))
