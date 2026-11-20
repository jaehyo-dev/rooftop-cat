"""tools/cut_kitten_alive.py: 엉덩이 자리 재기·붙이기 (만든 그림으로)."""
import importlib.util
import unittest

HAS_LIBS = all(importlib.util.find_spec(m) for m in ("numpy", "scipy", "PIL"))
if HAS_LIBS:
    import numpy as np
    from PIL import Image

    from cut_kitten_alive import BASELINE, CLOUD_WIDTH, RIM_TRIM, cut_cloud, paste, restyle, rump_x


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

    def test_그림체_맞추기는_선만_진하게_하고_테두리를_깎는다(self):
        rgba = np.zeros((60, 60, 4), np.uint8)
        rgba[10:50, 10:50] = (240, 190, 140, 255)   # 면
        rgba[28:31, 15:45] = (170, 110, 70, 255)    # 선
        out = np.asarray(restyle(Image.fromarray(rgba))).astype(int)
        self.assertLess(out[29, 30, :3].mean(), 110)                        # 선은 진해짐
        self.assertEqual(list(out[18, 30, :3]), [240, 190, 140])            # 선에서 먼 면은 그대로
        self.assertEqual(out[10 + RIM_TRIM - 1, 30, 3], 0)                  # 바깥 RIM_TRIM픽셀은 지워짐
        self.assertEqual(out[10 + RIM_TRIM, 30, 3], 255)


    def test_구름_시트는_한_배율로_줄여_조각_크기_비율을_지킨다(self):
        import tempfile
        from pathlib import Path
        sheet = np.zeros((400, 900, 3), np.uint8)
        sheet[...] = (255, 0, 255)
        sheet[40:140, 100:700] = (250, 245, 235)    # 타는 구름 600 폭
        for k, w in enumerate((120, 90, 60)):       # 조각 3개
            sheet[250:300, 100 + k * 250:100 + k * 250 + w] = (250, 245, 235)
        with tempfile.TemporaryDirectory() as d:
            src = Path(d) / "s.png"
            Image.fromarray(sheet).save(src)
            sizes = cut_cloud(src, Path(d))
        self.assertEqual(sizes["cloud"][0], CLOUD_WIDTH)
        for name, w in (("puff_0", 120), ("puff_1", 90), ("puff_2", 60)):
            self.assertAlmostEqual(sizes[name][0], w * CLOUD_WIDTH / 600, delta=2)


if __name__ == "__main__":
    unittest.main()
