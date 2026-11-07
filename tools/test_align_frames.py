"""프레임 정렬 도구 테스트 (numpy·Pillow가 없는 환경에서는 건너뜀)."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

HAS_LIBS = all(importlib.util.find_spec(name) for name in ("numpy", "PIL"))


@unittest.skipUnless(HAS_LIBS, "numpy, Pillow 필요")
class AlignFramesTest(unittest.TestCase):
    def setUp(self):
        import numpy as np
        from PIL import Image, ImageDraw
        import align_frames
        self.np, self.Image, self.Draw, self.af = np, Image, ImageDraw, align_frames

    def _frame(self, path, box, tail=None):
        image = self.Image.new("RGBA", (400, 300), (0, 0, 0, 0))
        draw = self.Draw.Draw(image)
        draw.rectangle(box, fill=(240, 170, 100, 255))
        if tail:
            draw.rectangle(tail, fill=(255, 255, 255, 255))
        image.save(path)

    def _bounds(self, path):
        mask = self.np.asarray(self.Image.open(path).getchannel("A")) > 128
        rows = self.np.nonzero(mask.any(axis=1))[0]
        return mask, rows[-1] + 1

    def test_발끝과_몸_중심을_같은_자리에_맞추고_시트_배율은_하나(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            ref = tmp / "ref.png"
            self._frame(ref, (0, 0, 199, 99))  # 넓이 20000
            # 같은 시트: 위치·모양이 다른 두 자세 (넓이 5000, 꼬리 달린 것 포함)
            a, b = tmp / "a.png", tmp / "b.png"
            self._frame(a, (50, 100, 149, 149))
            self._frame(b, (200, 20, 299, 69), tail=(150, 0, 170, 30))
            saved = self.af.align(ref, tmp / "out", [[a, b]])
            scales = {round(s, 6) for _, s in saved}
            self.assertEqual(len(scales), 1, "한 시트는 배율 하나")
            for out, _ in saved:
                mask, feet = self._bounds(out)
                self.assertEqual(feet, self.af.BASELINE, out.name)
                self.assertAlmostEqual(self.af.body_center_x(mask), self.af.ANCHOR_X, delta=1.0, msg=out.name)
            # 넓이 가운데값이 기준 넓이 x OUT_SCALE^2 근처가 된다
            mask, _ = self._bounds(tmp / "out" / "a.png")
            self.assertAlmostEqual(mask.sum(), 20000 * self.af.OUT_SCALE ** 2, delta=20000 * 0.05)

    def test_몸_중심은_꼬리_쪽을_빼고_잰다(self):
        np = self.np
        mask = np.zeros((10, 100), bool)
        mask[:, 30:100] = True   # 몸
        mask[0:3, 0:10] = True   # 꼬리 (왼쪽 끝)
        # 왼쪽 30%(x < 30)를 빼면 몸 30~99의 가운데
        self.assertAlmostEqual(self.af.body_center_x(mask), 64.5, delta=0.01)

    def test_캔버스_밖으로_나가면_알려준다(self):
        image = self.Image.new("RGBA", (2000, 100), (240, 170, 100, 255))
        with self.assertRaises(ValueError):
            self.af.place(image, 1.0)


if __name__ == "__main__":
    unittest.main()
