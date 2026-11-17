"""아기 움직임 A (motion2): 프레임 그림 달리기의 발 미끄러짐·바닥 붙음·머리 흔들림 (그림을 재므로 파이썬).
- 발 미끄러짐: tools/foot_slip.py (아기 A와 주인공을 같은 방법으로). 요구: 예전 A(22~28px)보다 줄이기 → A_MAX.
- 머리: 장마다 머리 자리를 run_0에 맞춰 잼. 가로는 그대로, 세로는 장 사이 HEAD_STEP 안, 전체 HEAD_RANGE 안 (걸음 박자의 작은 오르내림 하나).
6마리 모두 (아기마다 subTest). 바닥 붙음·장 넘김·도망 그림은 tests/test_kitten_motion.gd."""
import importlib.util
import unittest

# 그림을 재므로 numpy·scipy·Pillow가 있는 곳(로컬)에서만. Actions에는 없어 다른 그림 도구 테스트처럼 건너뜀
HAS_LIBS = all(importlib.util.find_spec(m) for m in ("numpy", "scipy", "PIL"))
if HAS_LIBS:
    import numpy as np
    from PIL import Image

    import cut_kitten_motion as ckm
    import foot_slip as fs

A_MAX = 8.0        # 게임 픽셀 (예전 A 25~31, 주인공 48~56, 같은 검사)
HEAD_STEP = 1      # 이웃 장 사이 머리 세로 차이 상한 (캔버스 픽셀 = 0.59 게임 픽셀)
HEAD_RANGE = 2     # 한 바퀴 머리 세로 움직임 상한 (= cut_kitten_motion.BOB)


def _head_shift(img, ref, box) -> tuple:
    """box(위, 아래, 왼, 오른) 안의 ref 머리를 img에서 찾은 (dx, dy)."""
    t, b, l, r = box
    a = np.asarray(ref, dtype=float)[t:b, l:r]
    best = None
    for dy in range(-6, 7):
        for dx in range(-6, 7):
            c = np.asarray(img, dtype=float)[t + dy:b + dy, l + dx:r + dx]
            d = float(np.abs(c - a).mean())
            if best is None or d < best[0]:
                best = (d, dx, dy)
    return best[1], best[2]


@unittest.skipUnless(HAS_LIBS, "numpy, scipy, Pillow 필요")
class FootSlip(unittest.TestCase):
    def test_아기마다_디딘_발이_덜_미끄러진다(self):
        for b in fs.BREEDS:
            with self.subTest(b):
                r = fs.report(b)
                for v in fs.SPEEDS:
                    self.assertLessEqual(r["A"][v], A_MAX, f"{b} 속도 {v}: {r['A'][v]}px")
                    self.assertLessEqual(r["A"][v], r["hero"][v] * 0.25, f"{b} 속도 {v}: {r['A'][v]} / 주인공 {r['hero'][v]}")

    def test_달리는_동안_늘_한_발_이상_디딤(self):
        for b in fs.BREEDS:
            for i, feet in enumerate(fs.kitten_a_frames(b)):
                self.assertGreaterEqual(len(feet), 1, f"{b} run_{i}")

    def test_한_장_안에서_밀리는_발도_잰다(self):
        # 한 장뿐인 그림을 빠르게 돌리면 발이 몸과 같이 계속 밀린다 (예전 검사는 새 발로 봐 0이었음, Codex 리뷰)
        self.assertGreater(fs.slip([[0.0]], 100000.0, 1500.0, seconds=1.0), 1000.0)

    def test_정지한_발은_미끄러짐_0(self):
        # 검사 자체 확인: 디딘 발이 장마다 한 장 거리만큼 정확히 뒤로 가는 가짜 달리기는 장 안에서 밀리는 만큼만
        frames = [[10.0], [5.0], [0.0], []]  # 세 장 디디고 한 장 들림
        self.assertLessEqual(fs.slip(frames, 20.0, 300.0), 5.0 + 1e-6)

    def test_새로_디딘_발이_디디던_발의_짝을_빼앗지_않는다(self):
        # 디디던 발(제자리)과 그 뒤에 새로 디딘 발: 앞에서부터 고르면 새 발이 디디던 발의 짝이 돼 미끄러짐으로 잼 (motion2에서 고침)
        frames = [[20.0], [10.0, 0.0]]  # 장 거리 10: 첫 발은 제자리, 둘째 장에 뒤쪽(세계 10)에 새 발
        self.assertLessEqual(fs.slip(frames, 20.0, 600.0, seconds=2.0 / 60.0), 1e-6)  # 두 장면만 (장 0 → 장 1)


    def test_한_바퀴를_건너뛰어도_들린_발을_놓치지_않는다(self):
        # 디딘 장 → 들린 장 → 디딘 장을 한 장면에 건너뛰면 같은 발이 아님 (Codex 리뷰: 예전엔 20px로 잼)
        self.assertLessEqual(fs.slip([[0.0], []], 10.0, 600.0, seconds=3.0 / 60.0), 1e-6)


@unittest.skipUnless(HAS_LIBS, "numpy, scipy, Pillow 필요")
class Head(unittest.TestCase):
    def test_달릴_때_머리는_몸과_같이_작게_오르내린다(self):
        for b in fs.BREEDS:
            with self.subTest(b):
                self._head(b)

    def _head(self, b):
        folder = fs.ROOT / "assets/sprites/kitten_motion" / b
        n = len(fs.a_advance(b))
        frames = [Image.open(folder / f"run_{i}.png").convert("RGBA") for i in range(n)]
        m = ckm.opaque(frames[0])
        rows = np.nonzero(m.any(axis=1))[0]
        box = (rows[0] + 6, rows[0] + 6 + (rows[-1] - rows[0]) // 2, ckm.ANCHOR_X - 10, ckm.ANCHOR_X + 80)  # 머리 (몸 오른쪽 위)
        ys = []
        for i, f in enumerate(frames):
            dx, dy = _head_shift(f, frames[0], box)
            self.assertEqual(dx, 0, f"{b} run_{i} 머리 가로")
            ys.append(dy)
        for i in range(n):
            self.assertLessEqual(abs(ys[i] - ys[i - 1]), HEAD_STEP, f"{b} run_{i - 1} → run_{i} 머리 {ys}")
        self.assertLessEqual(max(ys) - min(ys), HEAD_RANGE, f"{b} 머리 {ys}")
        self.assertGreater(max(ys) - min(ys), 0, "걸음 박자에 맞춘 오르내림이 있음")


if __name__ == "__main__":
    unittest.main()
