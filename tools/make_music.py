"""주택가 배경 음악(루프)을 직접 합성해 만든다. 시드가 같으면 항상 같은 곡이 나온다.

사용: python3 tools/make_music.py assets/audio/neighborhood.ogg   (ffmpeg 필요)
     python3 tools/make_music.py <출력.ogg> mochi | swing   (v0.5.0 2b 후보 곡: 아래 SONGS)
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


# --- v0.5.0 2b 후보 곡: 정해진 멜로디 + 리듬 악기 + 8분 걷는 베이스 ("잠 온다" 피드백, GAME_SPEC 배경 음악 방향) ---
NOTE_NAMES = {"C": 0, "Db": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "Gb": 6, "G": 7, "Ab": 8, "A": 9, "Bb": 10, "B": 11}
# 코드 이름 → (근음 MIDI, 3화음)
MAJOR, MINOR = (0, 4, 7), (0, 3, 7)
CHORD_TABLE = {"C": (48, MAJOR), "F": (41, MAJOR), "G": (43, MAJOR), "Am": (45, MINOR), "Dm": (38, MINOR), "Bb": (46 - 12, MAJOR), "Gm": (43, MINOR)}
# 멜로디: 한 마디 8칸(8분음표), "-"는 쉼 또는 앞 음이 울리는 칸. 무작위 없이 악보 그대로 = 따라 흥얼거릴 수 있게
SONGS = {
    # 찹쌀떡 산책: 또각또각 걷는 마림바와 손뼉
    "mochi": {
        "bpm": 118, "swing": 0.0, "lead": "marimba",
        "chords": "C G Am F C G F G F G C Am F G C G",
        "melody": [
            "E5 - G5 - A5 G5 E5 -", "D5 - G5 - B5 A5 G5 -", "C5 E5 A5 - G5 E5 C5 -", "F5 - A5 G5 F5 E5 D5 -",
            "E5 - G5 - A5 G5 E5 -", "D5 - G5 - B5 A5 G5 -", "A5 - A5 G5 F5 - D5 -", "D5 G5 B5 D6 - - - -",
            "C6 - A5 C6 - A5 F5 -", "B5 - G5 B5 - G5 D5 -", "E5 G5 C6 E6 - C6 G5 -", "A5 - E5 A5 C6 - - -",
            "C6 - A5 C6 - A5 F5 -", "B5 - G5 B5 - G5 D5 -", "E6 D6 C6 G5 E5 G5 C6 -", "D6 - B5 - G5 - - -",
        ],
    },
    # 뒤뚱 스윙: 살짝 튕기는 박자의 우쿨렐레와 피치카토
    "swing": {
        "bpm": 114, "swing": 0.12, "lead": "pizzicato",
        "chords": "F Dm Bb C F Dm Bb C Gm C F Dm Gm C F C",
        "melody": [
            "A5 - C6 A5 - F5 G5 A5", "F5 - A5 F5 - D5 E5 F5", "D6 - Bb5 G5 - F5 D5 -", "C6 - Bb5 A5 G5 - - -",
            "A5 - C6 A5 - F5 G5 A5", "F5 - A5 F5 - D5 E5 F5", "D6 C6 Bb5 D6 - Bb5 G5 -", "C6 - E5 G5 C6 - - -",
            "Bb5 - D6 Bb5 - G5 A5 Bb5", "G5 - C6 G5 - E5 F5 G5", "A5 C6 F6 - E6 D6 C6 -", "D6 - A5 F5 A5 - - -",
            "Bb5 - D6 Bb5 - G5 A5 Bb5", "G5 - C6 G5 - E5 F5 G5", "F6 E6 D6 C6 A5 C6 F5 -", "G5 - A5 - Bb5 - C6 -",
        ],
    },
}


def note_midi(name: str) -> int:
    return NOTE_NAMES[name[:-1]] + 12 * (int(name[-1]) + 1)


def marimba(freq: float, volume: float) -> np.ndarray:
    """나무 건반: 기본음 + 빨리 사라지는 높은 배음 (또각)"""
    t = np.arange(int(0.7 * RATE)) / RATE
    tone = np.sin(2 * np.pi * freq * t) * np.exp(-t * 6.5) + 0.35 * np.sin(2 * np.pi * freq * 3.93 * t) * np.exp(-t * 26.0)
    return volume * tone * np.minimum(1.0, t * 900.0)


def pizzicato(freq: float, volume: float) -> np.ndarray:
    """현을 뜯는 짧은 소리"""
    t = np.arange(int(0.45 * RATE)) / RATE
    tone = np.sin(2 * np.pi * freq * t) + 0.5 * np.sin(4 * np.pi * freq * t) + 0.2 * np.sin(6 * np.pi * freq * t)
    return volume * tone * np.exp(-t * 11.0) * np.minimum(1.0, t * 700.0)


def glock(freq: float, volume: float) -> np.ndarray:
    """글로켄: 맑고 길게 남는 소리"""
    t = np.arange(int(0.8 * RATE)) / RATE
    tone = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t * 9.0)
    return volume * tone * np.exp(-t * 5.0) * np.minimum(1.0, t * 1500.0)


def kick(volume: float) -> np.ndarray:
    """가벼운 북: 짧게 내려가는 낮은 소리"""
    t = np.arange(int(0.16 * RATE)) / RATE
    phase = 2 * np.pi * (58.0 * t + 70.0 * (1.0 - np.exp(-t * 34.0)) / 34.0)
    return volume * np.sin(phase) * np.exp(-t * 24.0)


def shaker(volume: float, rng: np.random.Generator) -> np.ndarray:
    """쉐이커: 높은 쪽만 남긴 짧은 잡음"""
    noise = np.diff(rng.normal(0.0, 1.0, int(0.06 * RATE) + 1))
    t = np.arange(len(noise)) / RATE
    return volume * noise * np.exp(-t * 70.0) * np.minimum(1.0, t * 500.0)


def clap(volume: float, rng: np.random.Generator) -> np.ndarray:
    """손뼉: 아주 짧게 세 번 겹친 잡음"""
    length = int(0.14 * RATE)
    noise = np.convolve(rng.normal(0.0, 1.0, length), [1, 0, -1], "same")
    t = np.arange(length) / RATE
    env = np.exp(-t * 34.0) + 0.7 * np.exp(-np.maximum(t - 0.012, 0) * 120.0) * (t >= 0.012) + 0.6 * np.exp(-np.maximum(t - 0.024, 0) * 120.0) * (t >= 0.024)
    return volume * noise * env


def build_song(name: str) -> np.ndarray:
    """SONGS의 악보대로 만든다. 잡음 악기도 시드를 고정해 항상 같은 곡"""
    song = SONGS[name]
    beat = 60.0 / song["bpm"]
    rng = np.random.default_rng(SEED)
    chords = song["chords"].split()
    total = int(len(chords) * 4 * beat * RATE)
    tail = 2 * RATE
    track = np.zeros(total + tail)

    def put(sound: np.ndarray, start: float) -> None:
        i = int(start * RATE)
        track[i:i + len(sound)] += sound[:len(track) - i]

    def eighth(slot: int) -> float:
        # 뒷박 8분음표를 살짝 늦춰 튕기는 느낌 (swing)
        return slot * beat / 2 + (song["swing"] * beat if slot % 2 else 0.0)

    lead = {"marimba": marimba, "pizzicato": pizzicato}[song["lead"]]
    for bar, chord_name in enumerate(chords):
        root, tones = CHORD_TABLE[chord_name]
        t0 = bar * 4 * beat
        # 8분음표로 걷는 베이스: 근음 → 3음 → 5음 → 6음 → 옥타브 → 6음 → 5음 → 3음
        third = tones[1]
        for slot, step in enumerate([0, third, 7, 9, 12, 9, 7, third]):
            put(pluck(midi_hz(root + step), 0.45, 0.30 if slot % 4 == 0 else 0.22), t0 + eighth(slot))
        # 북 (1, 3박 + 4박 뒤 살짝), 손뼉 (2, 4박), 쉐이커 (8분마다, 뒷박이 조금 큼)
        for b in [0.0, 2.0, 3.5]:
            put(kick(0.75 if b != 3.5 else 0.45), t0 + b * beat)
        for b in [1.0, 3.0]:
            put(clap(0.20, rng), t0 + b * beat)
        for slot in range(8):
            put(shaker(0.09 if slot % 2 else 0.05, rng), t0 + eighth(slot))
        # 화음: 마림바 곡은 뒷박 피치카토, 스윙 곡은 우쿨렐레처럼 네 줄을 빠르게 긁기
        chord = [root + 24 + n for n in tones]
        if song["lead"] == "marimba":
            for slot in [1, 3, 5, 7]:
                for n in chord:
                    put(pizzicato(midi_hz(n), 0.07), t0 + eighth(slot))
        else:
            for slot, strength in [(0, 0.10), (3, 0.07), (4, 0.09), (5, 0.06), (7, 0.07)]:
                for k, n in enumerate(chord + [chord[0] + 12]):
                    put(pluck(midi_hz(n), 0.5, strength), t0 + eighth(slot) + k * 0.009)
        # 멜로디 + 네 마디마다 글로켄 반짝임
        for slot, token in enumerate(song["melody"][bar].split()):
            if token != "-":
                put(lead(midi_hz(note_midi(token)), 0.36), t0 + eighth(slot))
                if bar % 8 >= 4 and slot % 2 == 0:
                    put(glock(midi_hz(note_midi(token) + 12), 0.09), t0 + eighth(slot))
    track[:tail] += track[total:total + tail]  # 끝 소리 감기 (루프)
    track = track[:total]
    return track / max(1e-9, np.abs(track).max()) * 0.8


def main() -> None:
    out = Path(sys.argv[1])
    out.parent.mkdir(parents=True, exist_ok=True)
    source = build_song(sys.argv[2]) if len(sys.argv) > 2 else build()
    data = (source * 32767).astype(np.int16)
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
