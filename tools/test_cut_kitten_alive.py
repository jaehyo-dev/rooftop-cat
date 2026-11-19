"""tools/cut_kitten_alive.py: 엉덩이 자리 재기·붙이기 (만든 그림으로)."""
import importlib.util
import unittest

HAS_LIBS = all(importlib.util.find_spec(m) for m in ("numpy", "scipy", "PIL"))
if HAS_LIBS:
    import numpy as np
    from PIL import Image

    from cut_kitten_alive import BASELINE, paste, rump_x


@unittest.skipUnless(HAS_LIBS, "numpy, scipy, Pillow 필요")
class RumpTest(unittest.TestCase):
    def test_가는_꼬리는_건너뛰고_엉덩이_끝을_잰다(self):
        mask = np.zeros((100, 200), bool)
        mask[60:100, 50:150] = True   # 몸
        mask[92:97, 10:50] = True     # 바닥을 따라 뻗은 가는 꼬리
        self.assertEqual(rump_x(mask), 50)

    def test_붙이면_아랫선과_엉덩이가_기준에(self):
        rgba = np.zeros((120, 220, 4), np.uint8)
        rgba[70:110, 60:160] = (200, 150, 100, 255)
        canvas = paste(Image.fromarray(rgba), 1.0, 70)
        alpha = np.asarray(canvas)[..., 3] > 128
        rows = np.nonzero(alpha.any(axis=1))[0]
        self.assertEqual(rows[-1] + 1, BASELINE)
        self.assertEqual(rump_x(alpha), 70)


if __name__ == "__main__":
    unittest.main()
