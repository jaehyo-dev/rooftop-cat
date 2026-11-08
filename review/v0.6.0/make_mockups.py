#!/usr/bin/env python3
"""30초 장면 시안: v0.5.0 실제 게임 캡처(sheets/base_*.png, 고양이 숨김) 위에 잘라 낸 시트와 코드 효과를 합성한다.
크기는 PLAN.md의 그림 크기 그대로라, 휴대폰 배율(0.54)로 줄인 그림으로 읽히는지 확인할 수 있다.
실행: python3 review/v0.6.0/make_mockups.py
shortcut: 정지 그림이라 화면 멀어짐·흔들림은 표현하지 않음. 움직임은 2b에서 GIF로 확인.
"""
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance

HERE = Path(__file__).parent
ROOT = HERE.parent.parent
CUT = HERE / "cut"
FONT = str(ROOT / "assets/fonts/Gaegu/Gaegu-Bold.ttf")
ROOF_Y = 565      # 지붕 턱 윗면 가운데 (고양이 발이 닿는 화면 y)
BROWN = (92, 62, 42, 255)


def sprite(name, width=None, height=None):
    im = Image.open(CUT / f"{name}.png").convert("RGBA")
    k = (width / im.width) if width else (height / im.height)
    return im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)


def cat(frame, scale=0.422):
    im = Image.open(ROOT / f"assets/sprites/cat_frames/{frame}.png").convert("RGBA")
    im = im.crop(im.getbbox())
    return im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)


def put(base, im, cx, bottom):
    base.alpha_composite(im, (round(cx - im.width / 2), round(bottom - im.height)))


def shadow(base, cx, y, w, alpha=70):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse((cx - w / 2, y - w / 12, cx + w / 2, y + w / 12), fill=(90, 60, 50, alpha))
    base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(3)))


def text(base, xy, s, size, fill=BROWN):
    d = ImageDraw.Draw(base)
    d.text(xy, s, font=ImageFont.truetype(FONT, size), fill=fill, stroke_width=3, stroke_fill=(255, 250, 240, 255), anchor="mm")


def hearts(base, states, y=48):
    w = 54
    x = 640 - (len(states) - 1) * (w + 8) / 2
    for s in states:
        put(base, sprite(s, width=w), x, y + 24)
        x += w + 8


def fish_row(base, pts, name="fish"):
    f = Image.open(ROOT / "assets/sprites/items/fish.png").convert("RGBA").resize((56, 32), Image.LANCZOS)
    for x, y in pts:
        base.alpha_composite(f, (round(x - 28), round(y - 16)))


def star(d, x, y, r, fill):
    d.polygon([(x, y - r), (x + r * .25, y - r * .25), (x + r, y), (x + r * .25, y + r * .25),
               (x, y + r), (x - r * .25, y + r * .25), (x - r, y), (x - r * .25, y - r * .25)], fill=fill)


def speed_lines(base, rng, n, alpha, top=120, bottom=540):
    layer = Image.new("RGBA", base.size, (255, 250, 235, 0))  # 번짐에 검정이 섞이지 않게 같은 색의 투명으로
    d = ImageDraw.Draw(layer)
    for _ in range(n):
        y = rng.randint(top, bottom)
        x = rng.randint(380, 1200)
        d.line((x, y, x + rng.randint(90, 300), y), fill=(255, 252, 240, alpha), width=rng.choice((2, 3, 3, 4)))
    base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.6)))


def decor(base, name, cx):
    """장식 소품 규칙의 시안: 옅게 + 지붕 뒤로 살짝 묻기 (장애물과 구분)."""
    im = Image.open(ROOT / f"assets/sprites/buildings/prop_{name}.png").convert("RGBA")
    im = im.resize((round(im.width * 0.8), round(im.height * 0.8)), Image.LANCZOS)
    im = ImageEnhance.Color(im).enhance(0.55)
    a = im.getchannel("A").point(lambda v: int(v * 0.6))
    im.putalpha(a)
    put(base, im, cx, 556)


def obstacle_scene():
    base = Image.open(HERE / "sheets/base_roof.png").convert("RGBA")
    decor(base, "chimney", 640)   # 판정 없는 소품: 옅고 작게
    decor(base, "antenna", 200)
    # 장애물: 그림 아래 접지 그림자 + 지붕 턱 위
    shadow(base, 345, ROOF_Y + 2, 110)
    put(base, sprite("pot", width=84), 345, ROOF_Y + 4)
    shadow(base, 800, ROOF_Y + 2, 170)
    put(base, sprite("ac", width=140), 800, ROOF_Y + 4)
    shadow(base, 1150, ROOF_Y + 2, 170)
    put(base, sprite("tank", height=320), 1150, ROOF_Y + 4)
    # 비둘기: 그림자가 옥상에 먼저 보임
    shadow(base, 985, ROOF_Y + 2, 200, 55)
    for i, name in enumerate(("bird", "bird2", "bird3")):
        put(base, sprite(name, width=78), 915 + i * 70, ROOF_Y - 236 + (i % 2) * 6)  # 판정 240~310
    # 생선: 화분 위 무지개와 실외기 앞 줄
    fish_row(base, [(250, 425), (320, 395), (390, 395), (460, 425)])
    fish_row(base, [(560, 520), (630, 520), (700, 520)])
    # 고양이: 화분을 톡 넘는 중 (그림자는 캡처에 이미 있음)
    put(base, cat("rise"), 340, ROOF_Y - 62)
    # 효과: 방금 뗀 발밑 먼지, 먹은 생선 숫자
    d = ImageDraw.Draw(base)
    for x, y, r in [(262, 552, 8), (240, 548, 6)]:
        d.ellipse((x - r, y - r, x + r, y + r), fill=(250, 240, 222, 190))
    star(d, 322, 375, 12, (255, 225, 120, 255))
    text(base, (345, 345), "+1", 34)
    hearts(base, ["heart_full", "heart_full", "heart_empty"])
    return base


def dash_scene():
    rng = random.Random(7)
    base = Image.open(HERE / "sheets/base_gap.png").convert("RGBA")
    # 따뜻한 빛 (화면 전체 살짝)
    glow = Image.new("RGBA", base.size, (255, 196, 110, 30))
    base.alpha_composite(glow)
    speed_lines(base, rng, 34, 215)
    # 앞쪽 옥상 위 장애물과 생선 길
    shadow(base, 1085, ROOF_Y + 2, 170)
    put(base, sprite("ac", width=140), 1085, ROOF_Y + 4)
    fish_row(base, [(560 + i * 70, 515) for i in range(4)])
    fish_row(base, [(880, 515), (950, 515)])
    # 부서져 날아가는 화분: 회전 + 파편 + 팡 글자
    pot = sprite("pot", width=84).rotate(-38, expand=True, resample=Image.BICUBIC)
    put(base, pot, 590, 395)
    d = ImageDraw.Draw(base)
    for dx, dy, r, c in [(-70, 40, 9, (214, 150, 100, 255)), (-40, 90, 7, (150, 190, 90, 255)), (30, 70, 8, (214, 150, 100, 255)),
                         (70, 20, 6, (150, 190, 90, 255)), (-95, 90, 6, (245, 215, 130, 255))]:
        d.polygon([(560 + dx, 400 + dy - r), (560 + dx + r, 400 + dy), (560 + dx, 400 + dy + r * .7), (560 + dx - r * .8, 400 + dy + r * .2)], fill=c)
    for dx, dy, r in [(-110, -10, 15), (70, -60, 13), (95, 60, 10)]:
        star(d, 560 + dx, 400 + dy, r, (255, 225, 120, 255))
    text(base, (500, 320), "팡!", 56, fill=(205, 85, 60, 255))
    # 고양이: 잔상 → 빛 → 몸. 틈 위 미끄러지는 투명 발판 높이
    feet = ROOF_Y + 2
    body = cat("run_1")
    for i, a in ((3, 45), (2, 75), (1, 115)):
        ghost = body.copy()
        ghost.putalpha(ghost.getchannel("A").point(lambda v, a=a: v * a // 255))
        put(base, ghost, 340 - i * 62, feet)
    sil = Image.new("RGBA", base.size, (0, 0, 0, 0))
    put(sil, body, 340, feet)
    aura = Image.new("RGBA", base.size, (255, 210, 90, 0))
    aura.putalpha(sil.getchannel("A").filter(ImageFilter.GaussianBlur(14)).point(lambda v: min(255, v * 2)))
    base.alpha_composite(aura)
    put(base, body, 340, feet)
    # 발밑 빛 줄 (틈 위에 있어도 안 떨어짐을 보여 줌)
    layer = Image.new("RGBA", base.size, (255, 230, 150, 0))
    ImageDraw.Draw(layer).line((120, feet + 3, 430, feet + 3), fill=(255, 230, 150, 200), width=7)
    base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(3)))
    # HUD: 하트 + 질주 남은 시간
    hearts(base, ["heart_full", "heart_full", "heart_crack"])
    put(base, sprite("churu", height=46), 572, 138)
    d = ImageDraw.Draw(base)
    d.rounded_rectangle((598, 108, 708, 128), 9, fill=(255, 250, 240, 230), outline=BROWN, width=3)
    d.rounded_rectangle((602, 112, 672, 124), 5, fill=(240, 150, 90, 255))
    return base


def main():
    for name, im in (("mockup_obstacles", obstacle_scene()), ("mockup_dash", dash_scene())):
        im.convert("RGB").save(HERE / f"{name}.png")
        im.convert("RGB").resize((691, 389), Image.LANCZOS).save(HERE / f"{name}_phone_scale.png")


main()
