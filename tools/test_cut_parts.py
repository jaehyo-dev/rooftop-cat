"""부품 자르기 도구 테스트 (numpy·scipy·Pillow가 없는 환경에서는 건너뜀)."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

HAS_LIBS = all(importlib.util.find_spec(name) for name in ("numpy", "scipy", "PIL"))


@unittest.skipUnless(HAS_LIBS, "numpy, scipy, Pillow 필요")
class CutPartsTest(unittest.TestCase):
    def setUp(self):
        import numpy as np
        from PIL import Image
        import cut_parts
        self.np, self.Image, self.cut_parts = np, Image, cut_parts

    def _sheet(self):
        # 마젠타 바탕에 위 줄 2개(왼쪽 큰 것, 오른쪽 작은 것), 아래 줄 1개
        np = self.np
        rgb = np.zeros((100, 200, 3), np.uint8)
        rgb[:] = (255, 0, 255)
        rgb[10:40, 10:60] = (240, 170, 100)    # 위 왼쪽: 주황
        rgb[15:35, 150:170] = (255, 255, 255)  # 위 오른쪽: 흰색
        rgb[60:90, 80:120] = (120, 200, 140)   # 아래: 초록
        rgb[60:90, 79] = (255, 128, 255)       # 반투명 가장자리 (흰색과 마젠타가 반씩 섞임)
        return rgb

    def test_배경은_투명하고_고양이_색은_불투명(self):
        rgba = self.cut_parts.remove_magenta(self._sheet())
        self.assertEqual(rgba[0, 0, 3], 0)
        for y, x in [(20, 20), (20, 160), (70, 100)]:
            self.assertEqual(rgba[y, x, 3], 255)
        # 반투명 가장자리는 마젠타를 빼서 원래 흰색으로 되돌린다
        edge = rgba[70, 79]
        self.assertTrue(60 < edge[3] < 200, edge)
        self.assertTrue(all(c > 235 for c in edge[:3]), edge)

    def test_부품을_줄과_왼쪽부터_순서대로_자른다(self):
        with tempfile.TemporaryDirectory() as tmp:
            sheet = Path(tmp) / "sheet.png"
            self.Image.fromarray(self._sheet()).save(sheet)
            saved = self.cut_parts.cut(sheet, Path(tmp) / "out", ["a", "b", "c"])
            rects = {path.stem: rect for path, rect in saved}
            pad = self.cut_parts.PADDING
            self.assertEqual(rects["a"], (10 - pad, 10 - pad, 50 + pad * 2, 30 + pad * 2))
            self.assertEqual(rects["b"][0], 150 - pad)
            self.assertEqual(rects["c"][1], 60 - pad)
            image = self.Image.open(Path(tmp) / "out" / "a.png")
            self.assertEqual(image.mode, "RGBA")
            self.assertEqual(image.getpixel((0, 0))[3], 0)

    def test_부품이_모자라면_알려준다(self):
        with self.assertRaises(ValueError):
            self.cut_parts.find_parts(self.cut_parts.remove_magenta(self._sheet()), 4)


if __name__ == "__main__":
    unittest.main()
