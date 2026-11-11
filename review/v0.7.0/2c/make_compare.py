"""v0.7.0 2c 검토 그림: 고른 시안과 만든 화면을 나란히, 메뉴 소리 들어 보기 파일.

사용: python3 review/v0.7.0/2c/make_compare.py <캡처 폴더(capture_2c.gd shots 결과)>
- compare_start·shop·missions.png: 왼쪽 시안(01·05·08), 오른쪽 게임 PC 캡처
- sounds/ui_sounds_preview.wav: 생선 소리(기준) → 강화 사기 → 부스터 사기 → 부스터 켜기 → 생선 부족 → 미션 받기 → 등급 오름 → 바꾸기 → 화면 넘김
  (게임에서처럼 생선과 메뉴 소리 모두 -17dB로 줄여 이어 붙임)
"""
import sys
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PAIRS = [("start", "01_start_A.png", "start_pc.png"), ("shop", "05_shop_B.png", "shop_upgrades_pc.png"),
         ("missions", "08_mission_B.png", "missions_pc.png")]
SOUNDS = ["fish", "buy", "booster_buy", "booster_on", "no_money", "claim", "rank_up", "swap", "page"]


def compare(caps: Path) -> None:
    for name, concept, shot in PAIRS:
        a = Image.open(ROOT / "review/v0.7.0/concept" / concept).convert("RGB").resize((960, 540), Image.LANCZOS)
        b = Image.open(caps / shot).convert("RGB").resize((960, 540), Image.LANCZOS)
        out = Image.new("RGB", (1940, 560), (255, 247, 235))
        out.paste(a, (0, 20))
        out.paste(b, (980, 20))
        ImageDraw.Draw(out).text((8, 2), f"concept {concept}", fill=(90, 70, 54))
        ImageDraw.Draw(out).text((988, 2), f"game {shot}", fill=(90, 70, 54))
        out.save(HERE / f"compare_{name}.png", optimize=True)
        print(HERE / f"compare_{name}.png")


def sounds() -> None:
    gain = 10 ** (-17 / 20)
    parts = []
    rate = 22050
    for name in SOUNDS:
        with wave.open(str(ROOT / "assets/audio/sfx" / f"{name}.wav")) as w:
            rate = w.getframerate()
            data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64)
        parts += [data * gain, np.zeros(int(0.7 * rate))]
    (HERE / "sounds").mkdir(exist_ok=True)
    with wave.open(str(HERE / "sounds/ui_sounds_preview.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(np.concatenate(parts).astype(np.int16).tobytes())
    print(HERE / "sounds/ui_sounds_preview.wav")


if __name__ == "__main__":
    compare(Path(sys.argv[1]))
    sounds()
