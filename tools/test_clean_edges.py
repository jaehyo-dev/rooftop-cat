"""가장자리 분홍·마젠타 잔여물 검사: 건물·소품·구조물 그림의 가장자리에 분홍 기가 없어야 한다."""
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

from clean_edges import clean, pink_edge

ROOT = Path(__file__).resolve().parent.parent / "assets" / "sprites"


class CleanEdgesTest(unittest.TestCase):
    def test_가장자리_분홍을_안쪽_색으로_덮는다(self):
        img = np.zeros((8, 8, 4), np.uint8)
        img[2:7, 2:7] = (230, 200, 150, 255)   # 크림색 몸통
        img[2, 2:7] = (200, 60, 120, 255)      # 맨 윗줄 분홍 잔여물
        self.assertTrue(pink_edge(img).any())
        self.assertFalse(pink_edge(clean(img)).any())
        self.assertTrue((clean(img)[..., 3] == img[..., 3]).all())  # 알파(윤곽)는 그대로

    def test_실제_그림_가장자리에_분홍_기가_없다(self):
        files = [p for d in ("buildings", "structures", "items") for p in (ROOT / d).glob("*.png")]
        self.assertTrue(files)
        for path in files:
            count = int(pink_edge(np.asarray(Image.open(path).convert("RGBA"))).sum())
            self.assertEqual(count, 0, f"{path.name} 가장자리 분홍 픽셀 {count}개")


if __name__ == "__main__":
    unittest.main()
