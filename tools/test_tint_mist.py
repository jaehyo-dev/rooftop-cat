import unittest

try:
    import numpy as np

    from tint_mist import tint
except ImportError as error:  # numpy는 개발 도구용이라 GitHub Actions에는 없다 (다른 도구 테스트와 같이 건너뜀)
    raise unittest.SkipTest(f"numpy 없음: {error}")


class TintTest(unittest.TestCase):
    def test_색은_크림색_쪽으로_투명도는_그대로(self):
        rgba = np.array([[[0xfe, 0xc4, 0xbd, 77]]], dtype=np.uint8)
        out = tint(rgba, 0.45)[0, 0]
        self.assertEqual(out[3], 77)
        self.assertEqual(list(out[:3]), [0xfe, 0xda, 0xd2])  # world_view.gd MIST_LOOKS.M1.mid_fill과 같은 값

    def test_다른_색_쪽으로도_섞는다(self):
        rgba = np.array([[[100, 100, 100, 200]]], dtype=np.uint8)
        target = np.array([200.0, 0.0, 100.0])
        self.assertEqual(list(tint(rgba, 0.5, target)[0, 0]), [150, 50, 100, 200])


if __name__ == "__main__":
    unittest.main()
