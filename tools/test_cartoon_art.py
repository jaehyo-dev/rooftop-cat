"""카툰 시트 도구: 칸 나누기·마젠타 빼기·선 굵기 재기."""
import importlib.util
import unittest

HAS_LIBS = all(importlib.util.find_spec(name) for name in ("numpy", "scipy", "PIL", "skimage"))


@unittest.skipUnless(HAS_LIBS, "numpy, scipy, Pillow, scikit-image 필요")
class CartoonArtTest(unittest.TestCase):
    def setUp(self):
        import numpy as np
        from PIL import Image
        import cartoon_art
        self.np, self.Image, self.ca = np, Image, cartoon_art

    def test_가장_넓은_틈에서_나눈다(self):
        cols = self.np.array([0, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1], bool)
        # 틈 1칸(인덱스 3)은 칸 안의 틈, 틈 4칸·3칸이 칸 사이
        self.assertEqual(self.ca.split_columns(cols, 3), [(1, 5), (9, 11), (14, 15)])

    def test_분홍_볼은_지우지_않고_마젠타_바탕만_뺀다(self):
        a = self.np.zeros((40, 40, 3), self.np.uint8)
        a[:] = (255, 0, 255)
        a[10:30, 10:30] = (0xFD, 0xB8, 0x65)          # 주황 몸
        a[18:22, 18:22] = (0xFD, 0x9B, 0x87)          # 안쪽 분홍 볼
        out = self.ca.cutout(self.Image.fromarray(a))
        self.assertEqual(out[0, 0, 3], 0)
        self.assertEqual(out[20, 20, 3], 255)
        self.assertEqual(tuple(out[20, 20, :3]), (0xFD, 0x9B, 0x87))

    def test_칸과_바닥선을_찾는다(self):
        a = self.np.zeros((60, 120, 3), self.np.uint8)
        a[:] = (255, 0, 255)
        a[50:52, :] = (210, 210, 220)                 # 옅은 회색 바닥선
        a[20:50, 10:40] = (0xFD, 0xB8, 0x65)
        a[30:50, 70:110] = (0xFD, 0xB8, 0x65)
        _, frames = self.ca.cut_frames(self.ca.cutout(self.Image.fromarray(a)), [2])
        self.assertEqual([f[1] for f in frames], [50, 50])
        self.assertEqual([f[2][0] for f in frames], [10, 70])

    def test_선_굵기를_잰다(self):
        a = self.np.full((80, 80, 3), 250, self.np.uint8)
        a[:, 38:42] = 0x33                            # 4px 세로선
        w = self.ca.widths(self.Image.fromarray(a))
        self.assertAlmostEqual(float(self.np.median(w)), 4.0, delta=0.6)


if __name__ == "__main__":
    unittest.main()
