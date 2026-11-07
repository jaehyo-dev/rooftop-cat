"""주택가 배경 음악(루프)을 직접 합성해 만든다. 시드가 같으면 항상 같은 곡이 나온다.

사용: python3 tools/make_music.py assets/audio/neighborhood.ogg   (ffmpeg 필요)
- C-Am-F-G 진행, 96BPM, 16마디. 멜로디(펜타토닉 위 무작위 걷기)는 뜯는 소리, 코드는 부드러운 패드, 베이스는 마디의 1·3박.
- 곡 끝을 넘어가는 소리를 처음에 겹쳐 더해(감기) 루프가 끊기지 않게 한다.
개발용 도구 (numpy 필요). 게임은 결과 파일만 쓴다.
"""
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

RATE = 44100
BPM = 96
BEAT = 60.0 / BPM
BARS = 16
SEED = 20261108
# 마디별 코드(C Am F G 반복): 근음 MIDI와 3화음 구성
CHORDS = [(48, (0, 4, 7)), (45, (0, 3, 7)), (41, (0, 4, 7)), (43, (0, 4, 7))]
PENTATONIC = [0, 2, 4, 7, 9]  # C 메이저 펜타토닉


def midi_hz(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def pluck(freq: float, length: float, volume: float) -> np.ndarray:
    """뜯는 소리: 기본음 + 배음 두 개, 빠르게 줄어드는 소리"""
    t = np.arange(int(length * RATE)) / RATE
    wave_ = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(4 * np.pi * freq * t) + 0.12 * np.sin(6 * np.pi * freq * t)
    env = np.exp(-t * 3.2) * np.minimum(1.0, t * 400.0)
    return volume * wave_ * env


def pad(freqs: list, length: float, volume: float) -> np.ndarray:
    """부드러운 패드: 천천히 켜지고 꺼지는 사인파 겹침"""
    t = np.arange(int(length * RATE)) / RATE
    env = np.minimum(1.0, t / 0.35) * np.minimum(1.0, (length - t) / 0.5)
    return volume * sum(np.sin(2 * np.pi * f * t) for f in freqs) * env / len(freqs)


def build() -> np.ndarray:
    rng = np.random.default_rng(SEED)
    total = int(BARS * 4 * BEAT * RATE)
    tail = 3 * RATE  # 곡 끝을 넘어가는 소리를 처음에 이어 붙일 여유
    track = np.zeros(total + tail)

    def put(sound: np.ndarray, start: float) -> None:
        i = int(start * RATE)
        track[i:i + len(sound)] += sound[:len(track) - i]

    step = 3  # 멜로디 음 높이(펜타토닉 안 위치), 걸으며 바뀜
    for bar in range(BARS):
        root, tones = CHORDS[bar % 4]
        t0 = bar * 4 * BEAT
        put(pad([midi_hz(root + 12 + n) for n in tones], 4 * BEAT, 0.16), t0)
        put(pluck(midi_hz(root), 2.0 * BEAT, 0.34), t0)
        put(pluck(midi_hz(root), 2.0 * BEAT, 0.26), t0 + 2 * BEAT)
        for eighth in range(8):
            if rng.random() < 0.28:  # 가끔 쉼
                continue
            step = int(np.clip(step + rng.integers(-2, 3), 0, 9))
            note = 60 + PENTATONIC[step % 5] + 12 * (step // 5)
            put(pluck(midi_hz(note), 1.4, 0.22), t0 + eighth * BEAT / 2)
    track[:tail] += track[total:total + tail]  # 끝 소리 감기
    track = track[:total]
    return track / max(1e-9, np.abs(track).max()) * 0.8


def main() -> None:
    out = Path(sys.argv[1])
    out.parent.mkdir(parents=True, exist_ok=True)
    data = (build() * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = Path(tmp) / "m.wav"
        with wave.open(str(wav_path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(data.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "3", str(out)], check=True)
    print(out, f"{len(data) / RATE:.1f}초")


if __name__ == "__main__":
    main()
