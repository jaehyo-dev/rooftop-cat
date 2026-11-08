"""효과음 7종을 직접 합성해 WAV로 저장한다. 난수를 쓰지 않아 항상 같은 소리가 나온다.

사용: python3 tools/make_sfx.py assets/audio/sfx
개발용 도구 (numpy 필요). 게임은 결과 파일만 쓴다.
"""
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 22050
# 점프 소리의 끝 음 (Hz). 더블점프는 이보다 높게 (GAME_SPEC: 첫 점프보다 높은 음)
JUMP_TOP = 620.0
DOUBLE_TOP = 980.0


def times(length: float) -> np.ndarray:
    return np.arange(int(length * RATE)) / RATE


def sweep(start: float, end: float, length: float) -> np.ndarray:
    """start → end Hz로 미끄러지는 둥근 소리 (기본음 + 약한 배음)"""
    freq = np.geomspace(start, end, int(length * RATE))
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return np.sin(phase) + 0.25 * np.sin(2 * phase)


def bell(freq: float, length: float, decay: float) -> np.ndarray:
    """맑은 종소리 (글로켄 비슷)"""
    t = times(length)
    return (np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2.76 * t)) * np.exp(-t * decay)


def fade(sound: np.ndarray, decay: float) -> np.ndarray:
    t = np.arange(len(sound)) / RATE
    return sound * np.exp(-t * decay) * np.minimum(1.0, t * 800.0)


def at(sound: np.ndarray, start: float, length: float) -> np.ndarray:
    out = np.zeros(int(length * RATE))
    i = int(start * RATE)
    out[i:i + len(sound)] += sound[:len(out) - i]
    return out


def jump() -> np.ndarray:
    return fade(sweep(300.0, JUMP_TOP, 0.14), 9.0)


def double_jump() -> np.ndarray:
    return at(fade(sweep(520.0, DOUBLE_TOP, 0.13), 8.0), 0.0, 0.26) + 0.45 * at(bell(DOUBLE_TOP * 1.5, 0.16, 22.0), 0.08, 0.26)


def land() -> np.ndarray:
    """통: 짧고 낮은 소리 (자주 나므로 작게, 끝에서 볼륨)"""
    return 0.55 * fade(sweep(170.0, 90.0, 0.09), 30.0)


def fish() -> np.ndarray:
    return 0.7 * (at(bell(1175.0, 0.1, 24.0), 0.0, 0.2) + at(bell(1568.0, 0.14, 24.0), 0.055, 0.2))


def boing() -> np.ndarray:
    """보잉: 낮은 음에서 올라가며 떨리는 소리"""
    t = times(0.34)
    freq = 150.0 + 260.0 * (1.0 - np.exp(-t * 11.0)) + 34.0 * np.sin(2 * np.pi * 21.0 * t) * np.exp(-t * 7.0)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return (np.sin(phase) + 0.4 * np.sin(2 * phase)) * np.exp(-t * 7.5) * np.minimum(1.0, t * 800.0)


def perfect() -> np.ndarray:
    """반짝: 위로 올라가는 세 음 (도-미-솔)"""
    return 0.65 * sum(at(bell(f, 0.28, 13.0), s, 0.5) for f, s in [(1047.0, 0.0), (1319.0, 0.07), (1568.0, 0.14)])


def fall() -> np.ndarray:
    """떨어짐: 길게 내려가는 소리"""
    return 0.7 * fade(sweep(760.0, 170.0, 0.55), 2.5)


SOUNDS = {"jump": jump, "double_jump": double_jump, "land": land, "fish": fish, "boing": boing, "perfect": perfect, "fall": fall}


def write(path: Path, sound: np.ndarray) -> None:
    data = (np.clip(sound / max(1.0, float(np.abs(sound).max())), -1.0, 1.0) * 0.9 * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


if __name__ == "__main__":
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for name, make in SOUNDS.items():
        write(out / f"{name}.wav", make())
