import unittest

try:
    import numpy as np

    import make_sfx
except ImportError as error:  # numpy는 개발 도구용이라 GitHub Actions에는 없다 (다른 도구 테스트와 같이 건너뜀)
    raise unittest.SkipTest(f"numpy 없음: {error}")


def end_pitch(sound):
    # 소리 뒷부분(앞 40%~)의 가장 센 주파수
    part = sound[: len(sound)]
    spectrum = np.abs(np.fft.rfft(part * np.hanning(len(part))))
    return np.argmax(spectrum) * make_sfx.RATE / len(part)


class SfxTest(unittest.TestCase):
    def test_열여섯_종류이고_터지지_않으며_짧다(self):
        self.assertEqual(len(make_sfx.SOUNDS), 16)
        for name, make in make_sfx.SOUNDS.items():
            sound = make()
            self.assertGreater(np.abs(sound).max(), 0.1, name)
            self.assertLess(len(sound) / make_sfx.RATE, 0.7, name)
            self.assertFalse(np.isnan(sound).any(), name)

    def test_생선_소리는_아이템_소리보다_짧다(self):
        self.assertLess(len(make_sfx.fish()), len(make_sfx.pickup()) * 0.6)

    def test_더블점프는_첫_점프보다_높은_음(self):
        self.assertGreater(make_sfx.DOUBLE_TOP, make_sfx.JUMP_TOP)
        self.assertGreater(end_pitch(make_sfx.double_jump()), end_pitch(make_sfx.jump()) * 1.2)

    def test_콤보_띵은_생선보다_높고_툭은_짧다(self):
        self.assertGreater(end_pitch(make_sfx.combo_up()), end_pitch(make_sfx.fish()) * 1.4)
        self.assertLess(len(make_sfx.combo_break()) / make_sfx.RATE, 0.12)
        self.assertLess(end_pitch(make_sfx.heartbeat()), 250.0)


if __name__ == "__main__":
    unittest.main()
