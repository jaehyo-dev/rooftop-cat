"""가장자리 분홍·마젠타 잔여물 검사: 건물·소품·구조물 그림의 가장자리에 분홍 기가 없어야 한다."""
import importlib.util
import unittest
from pathlib import Path

HAS_LIBS = all(importlib.util.find_spec(name) for name in ("numpy", "scipy", "PIL"))

ROOT = Path(__file__).resolve().parent.parent / "assets" / "sprites"


@unittest.skipUnless(HAS_LIBS, "numpy, scipy, Pillow 필요")
class CleanEdgesTest(unittest.TestCase):
    def setUp(self):
        import numpy as np
        from PIL import Image
        import clean_edges
        self.np, self.Image, self.ce = np, Image, clean_edges

    def test_가장자리_분홍을_안쪽_색으로_덮는다(self):
        img = self.np.zeros((8, 8, 4), self.np.uint8)
        img[2:7, 2:7] = (230, 200, 150, 255)   # 크림색 몸통
        img[2, 2:7] = (200, 60, 120, 255)      # 맨 윗줄 분홍 잔여물
        self.assertTrue(self.ce.pink_edge(img).any())
        self.assertFalse(self.ce.pink_edge(self.ce.clean(img)).any())
        self.assertTrue((self.ce.clean(img)[..., 3] == img[..., 3]).all())  # 알파(윤곽)는 그대로

    def test_실제_그림_가장자리에_분홍_기가_없다(self):
        files = [p for d in ("buildings", "structures", "items") for p in (ROOT / d).glob("*.png")]
        self.assertTrue(files)
        for path in files:
            count = int(self.ce.pink_edge(self.np.asarray(self.Image.open(path).convert("RGBA"))).sum())
            self.assertEqual(count, 0, f"{path.name} 가장자리 분홍 픽셀 {count}개")


if __name__ == "__main__":
    unittest.main()
