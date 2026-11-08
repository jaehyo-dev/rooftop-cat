import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
try:
    import numpy as np
    from PIL import Image
    from make_obstacle_art import soften
except ImportError:
    np = None  # 개발용 도구라 CI에는 numpy·Pillow·scipy가 없다


@unittest.skipIf(np is None, "numpy, Pillow, scipy가 없으면 건너뜀")
class SoftenTest(unittest.TestCase):
    def test_채도만_55퍼센트로_줄고_알파는_그대로(self):
        image = Image.new("RGBA", (4, 4), (200, 100, 50, 77))
        out = soften(image)
        before = np.asarray(image.convert("RGB").convert("HSV"))[0, 0, 1]
        after = np.asarray(out.convert("RGB").convert("HSV"))[0, 0, 1]
        self.assertAlmostEqual(after / before, 0.55, delta=0.02)
        self.assertEqual(out.getpixel((0, 0))[3], 77)


if __name__ == "__main__":
    unittest.main()
