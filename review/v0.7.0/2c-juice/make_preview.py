"""2c 피드백 새 소리 미리 듣기 (게임과 같은 크기 관계: 모든 소리 -17dB, 저장 최고점 0.9로 같음).
순서: 생선(기준) → 도장 휙+쿵 → 강화 사기 1·5·9단계(한 음씩 높아짐, 게임은 빠르기로 올림) → 10단계 팡파르 → 부스터 쏙
사용: python3 review/v0.7.0/2c-juice/make_preview.py"""
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


gap = np.zeros(int(0.35 * m.RATE))
stamp = norm(m.whoosh())
stamp = np.concatenate([stamp, norm(m.thud())])
parts = [norm(m.fish()), stamp, *[pitched(norm(m.buy()), lv - 1) for lv in (1, 5, 9)], norm(m.fanfare()), norm(m.pop_in())]
out = np.concatenate([np.concatenate([p, gap]) for p in parts])
with wave.open(str(HERE / "sounds/juice_sounds_preview.wav"), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(m.RATE)
    w.writeframes((out * 32767).astype(np.int16).tobytes())
print(HERE / "sounds/juice_sounds_preview.wav")
