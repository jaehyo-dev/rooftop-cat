"""효과음을 직접 합성해 WAV로 저장한다. 난수를 쓰지 않아 항상 같은 소리가 나온다.

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


def pickup() -> np.ndarray:
    """황금 생선과 아이템을 먹는 소리 (예전 생선 소리)"""
    return 0.7 * (at(bell(1175.0, 0.1, 24.0), 0.0, 0.2) + at(bell(1568.0, 0.14, 24.0), 0.055, 0.2))


def fish() -> np.ndarray:
    """생선 소리: 촘촘히 먹어도 시끄럽지 않게 짧게"""
    return 0.7 * (at(bell(1175.0, 0.04, 45.0), 0.0, 0.09) + at(bell(1568.0, 0.06, 45.0), 0.025, 0.09))


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


def stage_up() -> np.ndarray:
    """속도 단계 오름: 짧게 올라가는 세 음"""
    notes = [(587.0, 0.0), (784.0, 0.09), (1175.0, 0.18)]
    return sum(at(bell(freq, 0.26, 12.0), start, 0.46) for freq, start in notes)


def coo() -> np.ndarray:
    """비둘기 "구구": 낮고 둥근 음 두 번"""
    one = fade(sweep(330.0, 260.0, 0.16), 6.0)
    return np.concatenate([one, np.zeros(int(0.05 * RATE)), one]) * 0.6


def pang() -> np.ndarray:
    """팡: 짧고 빠르게 내려가는 터짐"""
    t = times(0.2)
    crack = np.sin(2 * np.pi * 2300.0 * t + 8.0 * np.sin(2 * np.pi * 730.0 * t)) * np.exp(-t * 45.0)
    return 0.8 * (at(fade(sweep(780.0, 130.0, 0.18), 12.0), 0.0, 0.2) + 0.6 * crack)


def jingle() -> np.ndarray:
    """딸랑: 방울이 두 번 울림"""
    return 0.7 * sum(at(bell(f, 0.3, 11.0), s, 0.45) for f, s in [(2093.0, 0.0), (2637.0, 0.1)])


def combo_up() -> np.ndarray:
    """띵: 콤보 배수가 오를 때 짧고 밝은 두 음 (생선 소리보다 한 옥타브 위, 생선 줄 속에서도 들리게)"""
    return 0.6 * (at(bell(2349.0, 0.16, 20.0), 0.0, 0.24) + 0.5 * at(bell(3136.0, 0.14, 24.0), 0.03, 0.24))


def combo_break() -> np.ndarray:
    """툭: 콤보가 끊길 때 작고 부드럽게 내려가는 소리 (기분 나쁘지 않게 짧게)"""
    return 0.5 * fade(sweep(420.0, 260.0, 0.08), 32.0)


def hit() -> np.ndarray:
    """퉁: 장애물에 부딪힐 때 둔탁한 낮은 소리 + 짧은 흔들림"""
    t = times(0.24)
    wobble = np.sin(2 * np.pi * (120.0 * t + 6.0 * np.sin(2 * np.pi * 9.0 * t))) * np.exp(-t * 16.0)
    return 0.9 * (at(fade(sweep(240.0, 75.0, 0.2), 14.0), 0.0, 0.24) + 0.5 * wobble)


def heartbeat() -> np.ndarray:
    """두근: 낮은 두 번 박동 (휴대폰 스피커에서도 들리게 2배음을 섞음)"""
    def thump(freq: float) -> np.ndarray:
        t = times(0.12)
        return (np.sin(2 * np.pi * freq * t) + 0.6 * np.sin(4 * np.pi * freq * t)) * np.exp(-t * 30.0) * np.minimum(1.0, t * 400.0)
    return 0.8 * (at(thump(95.0), 0.0, 0.32) + 0.7 * at(thump(85.0), 0.17, 0.32))


def dash() -> np.ndarray:
    """슝: 질주 시작. 바람 잡음이 커졌다 빠지며 낮은 음에서 높이 솟는 소리 (점프 소리만큼 크게)"""
    t = times(0.55)
    rise = sweep(180.0, 1400.0, 0.55)
    # 잡음은 시드 고정 대신 사인 여러 개를 겹친 바람 소리 (난수를 쓰지 않는 규칙)
    wind = sum(np.sin(2 * np.pi * (f * t + 300.0 * t * t)) for f in (713.0, 1091.0, 1597.0, 2207.0, 2963.0)) / 5.0
    env = np.sin(np.pi * np.minimum(1.0, t / 0.5)) ** 1.5
    return 0.9 * (0.7 * rise + 0.6 * wind) * env


# --- 메뉴 소리 (v0.7.0 2c): 모두 짧고 부드럽게. 게임 안 소리보다 작게 튼다 (main.gd UI_VOLUME_DB) ---

def buy() -> np.ndarray:
    """강화 사기: 동전 같은 두 음 + 위로 올라가는 반짝 (도-솔-도)"""
    return 0.7 * sum(at(bell(f, 0.22, 16.0), s, 0.45) for f, s in [(784.0, 0.0), (1175.0, 0.07), (1568.0, 0.14)])


def booster_buy() -> np.ndarray:
    """부스터 사기: 봉투에 넣는 툭 + 짧은 딸랑"""
    return 0.8 * at(fade(sweep(260.0, 180.0, 0.07), 30.0), 0.0, 0.3) + 0.5 * at(bell(1319.0, 0.18, 18.0), 0.05, 0.3)


def booster_on() -> np.ndarray:
    """부스터 켜기: 똑 (짧게 올라감)"""
    return 0.6 * fade(sweep(520.0, 880.0, 0.06), 40.0)


def no_money() -> np.ndarray:
    """생선 부족: 낮게 두 번 '뿌뿌' (기분 나쁘지 않게 둥글게)"""
    one = fade(sweep(300.0, 240.0, 0.09), 18.0)
    return 0.6 * np.concatenate([one, np.zeros(int(0.04 * RATE)), one])


def claim() -> np.ndarray:
    """미션 받기: 반짝 세 음이 위로 (생선이 날아가는 동안)"""
    return 0.6 * sum(at(bell(f, 0.2, 14.0), s, 0.5) for f, s in [(1047.0, 0.0), (1319.0, 0.08), (1760.0, 0.16)])


def rank_up() -> np.ndarray:
    """등급 오름: 도장 쿵 + 팡파르 네 음 (도-미-솔-도)"""
    thump = fade(sweep(200.0, 90.0, 0.12), 20.0)
    notes = sum(at(bell(f, 0.3, 9.0), s, 0.65) for f, s in [(523.0, 0.08), (659.0, 0.16), (784.0, 0.24), (1047.0, 0.32)])
    return 0.6 * (at(thump, 0.0, 0.65) + notes)


def swap() -> np.ndarray:
    """바꾸기: 종이를 뒤집는 사락 (내려갔다 올라가는 두 음)"""
    return 0.6 * (at(fade(sweep(700.0, 420.0, 0.08), 20.0), 0.0, 0.22) + at(fade(sweep(420.0, 760.0, 0.09), 20.0), 0.09, 0.22))


def page() -> np.ndarray:
    """화면 넘김: 바람처럼 부드러운 휙 (작게)"""
    t = times(0.2)
    wind = sum(np.sin(2 * np.pi * (f * t + 900.0 * t * t)) for f in (613.0, 977.0, 1459.0)) / 3.0
    return 0.45 * wind * np.sin(np.pi * t / 0.2) ** 2


# --- 2c 피드백 (2026-11-12): 도장 휙·쿵, 10단계 팡파르, 부스터 쏙 ---

def whoosh() -> np.ndarray:
    """도장이 내려오는 휙: 바람이 아래로 빠르게 미끄러짐 (끝에서 커졌다 쿵에 이어짐). 2c-polish: 낮은 바람 한 겹을 더해 두껍게"""
    t = times(0.2)
    wind = sum(np.sin(2 * np.pi * (f * t - 1500.0 * t * t)) for f in (613.0, 1213.0, 1697.0, 2311.0)) / 4.0
    return 0.6 * wind * (t / 0.2) ** 1.5 * np.minimum(1.0, (0.2 - t) * 200.0)


def thud() -> np.ndarray:
    """도장 쿵 (2c-polish: 사용자 "도장 소리가 너무 작다"): 종이를 때리는 탁 + 배음을 눌러 키운 북(폰 스피커에서도 큼)
    + 낮게 오래 울리는 저음 꼬리(55Hz, 0.5초). 게임은 다른 메뉴 소리보다 크게 튼다 (main.gd UI_GAIN_DB)"""
    t = times(0.6)
    click = np.sin(2 * np.pi * 2200.0 * t) * np.exp(-t * 260.0)
    slap = sum(np.sin(2 * np.pi * f * t) for f in (1873.0, 2741.0, 3529.0)) / 3.0 * np.exp(-t * 70.0)
    body = np.tanh(2.6 * at(fade(sweep(190.0, 70.0, 0.2), 12.0), 0.0, 0.6))  # 눌러서 배음이 생김 = 작은 스피커에서도 들림
    tail = np.sin(2 * np.pi * (55.0 * t - 4.0 * t * t)) * np.exp(-t * 7.0) * np.minimum(1.0, t * 80.0)
    return 0.55 * click + 0.4 * slap + 0.85 * body + 0.6 * tail


def fanfare() -> np.ndarray:
    """강화 10단계 축하: 짧은 나팔 (솔-도-미-솔-도↑ 마지막은 길게)"""
    def horn(freq: float, length: float) -> np.ndarray:
        t = times(length)
        tone = sum(np.sin(2 * np.pi * freq * k * t) / k for k in (1, 2, 3, 4))
        return tone * np.minimum(1.0, t * 60.0) * np.exp(-t * 3.0)
    notes = [(392.0, 0.0, 0.1), (523.0, 0.08, 0.1), (659.0, 0.16, 0.1), (784.0, 0.24, 0.1), (1047.0, 0.32, 0.33)]
    return 0.45 * sum(at(horn(f, n), s, 0.66) for f, s, n in notes)


def pop_in() -> np.ndarray:
    """부스터가 칸에 쏙: 빠르게 올라가는 뽁 + 작은 딸랑"""
    return 0.7 * at(fade(sweep(280.0, 900.0, 0.07), 25.0), 0.0, 0.3) + 0.4 * at(bell(1568.0, 0.16, 20.0), 0.06, 0.3)


UI_SOUNDS = {"buy": buy, "booster_buy": booster_buy, "booster_on": booster_on, "no_money": no_money, "claim": claim,
             "rank_up": rank_up, "swap": swap, "page": page,
             "whoosh": whoosh, "thud": thud, "fanfare": fanfare, "pop_in": pop_in}

SOUNDS = {"pang": pang, "bell": jingle, "coo": coo, "jump": jump, "double_jump": double_jump, "land": land, "fish": fish, "pickup": pickup, "boing": boing, "perfect": perfect, "fall": fall, "stage_up": stage_up,
          "combo_up": combo_up, "combo_break": combo_break, "hit": hit, "heartbeat": heartbeat, "dash": dash, **UI_SOUNDS}


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
