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
    def test_게임_17종_메뉴_8종이고_터지지_않으며_짧다(self):
        self.assertEqual(len(make_sfx.SOUNDS), 17 + 8)
        self.assertEqual(len(make_sfx.UI_SOUNDS), 8)
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

    def test_질주_슝은_올라가고_생선보다_길다(self):
        sound = make_sfx.dash()
        half = len(sound) // 2
        self.assertGreater(end_pitch(sound[half:]), end_pitch(sound[:half]))
        self.assertGreater(len(sound), len(make_sfx.fish()) * 3)


    def test_메뉴_소리는_생선_소리보다_크게_들리지_않는다(self):
        # 같은 크기로 저장되므로(최고점 0.9) 평균 크기(RMS)를 비교: 메뉴 소리는 게임에서 생선과 같은 -17dB로 틀어
        # 생선보다 평균이 1.6배(4dB)를 넘지 않으면 튀지 않는다
        def rms(sound):
            sound = sound / np.abs(sound).max()
            return float(np.sqrt(np.mean(sound ** 2)))
        for name, make in make_sfx.UI_SOUNDS.items():
            self.assertLess(rms(make()), rms(make_sfx.fish()) * 1.6, name)


if __name__ == "__main__":
    unittest.main()
