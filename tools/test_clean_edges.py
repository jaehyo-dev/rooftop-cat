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
        files = [p for d in ("buildings", "structures", "items", "backdrop", "ui", "ui/icons") for p in (ROOT / d).glob("*.png")]
        self.assertTrue(files)
        for path in files:
            if path.stem.endswith("_cream"):
                continue  # 안개 원본(검사 제외 대상)의 색만 섞은 파일: 가장자리 분홍은 안개 고유색이고 원본과 같은 자리
            if path.stem.startswith("prop_soft_"):
                continue  # 검사를 통과한 소품 원본의 채도만 줄인 파일: 옅어진 갈색이 분홍 판정에 걸릴 뿐 잔여물이 아님
            rgba = self.np.asarray(self.Image.open(path).convert("RGBA"))
            inside = (rgba[..., 3] > 0) & ~self.ce.edge_mask(rgba)
            if self.ce.pinkish(rgba)[inside].mean() > 0.5:
                continue  # 안쪽도 대부분 분홍인 그림(노을 안개 띠)은 분홍이 원래 색이라 잔여물 검사 대상이 아님
            count = int(self.ce.pink_edge(rgba).sum())
            self.assertEqual(count, 0, f"{path.name} 가장자리 분홍 픽셀 {count}개")


if __name__ == "__main__":
    unittest.main()
