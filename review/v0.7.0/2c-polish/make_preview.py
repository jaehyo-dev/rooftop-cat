"""2c-polish 소리 미리 듣기 (게임과 같은 크기 관계: 메뉴 소리 -17dB, 쿵 +5dB, 휙 +3dB, 저장 최고점 0.9로 같음).
순서: 생선(기준) → 예전 휙+쿵 → 새 휙+쿵 → 강화 사기 1·5·9단계 → 10단계 팡파르 → 부스터 쏙
사용: python3 review/v0.7.0/2c-polish/make_preview.py"""
import sys
import wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE.parents[2] / "tools"))
import make_sfx as m  # noqa: E402


def norm(s):
    return s / np.abs(s).max() * 0.9


def pitched(s, semis):
    """빠르기를 2^(semis/12)배로 (게임의 pitch_scale과 같음)"""
    k = 2 ** (semis / 12)
    idx = np.arange(0, len(s) - 1, k)
    return np.interp(idx, np.arange(len(s)), s)


def db(s, gain):
    return s * 10 ** (gain / 20)


def old_thud():
    t = m.times(0.24)
    low = m.fade(m.sweep(170.0, 60.0, 0.24), 14.0)
    slap = sum(np.sin(2 * np.pi * f * t) for f in (1873.0, 2741.0, 3529.0)) / 3.0 * np.exp(-t * 90.0)
    return 0.9 * low + 0.35 * slap


def old_whoosh():
    t = m.times(0.16)
    wind = sum(np.sin(2 * np.pi * (f * t - 1800.0 * t * t)) for f in (1213.0, 1697.0, 2311.0)) / 3.0
    return 0.5 * wind * (t / 0.16) ** 1.5 * np.minimum(1.0, (0.16 - t) * 200.0)


gap = np.zeros(int(0.35 * m.RATE))
old = np.concatenate([norm(old_whoosh()), norm(old_thud())])
new = np.concatenate([db(norm(m.whoosh()), 3.0), db(norm(m.thud()), 5.0)])
parts = [norm(m.fish()), old, new, *[pitched(norm(m.buy()), lv - 1) for lv in (1, 5, 9)], norm(m.fanfare()), norm(m.pop_in())]
parts = [p / 10 ** (5.0 / 20) for p in parts]  # 가장 큰 쿵(+5dB)이 넘치지 않게 모두 같이 낮춤 (크기 관계는 그대로)
out = np.concatenate([np.concatenate([p, gap]) for p in parts])
with wave.open(str(HERE / "sounds/stamp_preview.wav"), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(m.RATE)
    w.writeframes((out * 32767).astype(np.int16).tobytes())
print(HERE / "sounds/stamp_preview.wav")
