"""카툰 주인공 프레임 도구: 선 색 올리기, 발끝·몸 중심 맞추기, 떨어진 먼지 빼기, 눈 감기."""
import importlib.util
import unittest

HAS_LIBS = all(importlib.util.find_spec(name) for name in ("numpy", "scipy", "PIL", "skimage"))


@unittest.skipUnless(HAS_LIBS, "numpy, scipy, Pillow, scikit-image 필요")
class HeroFramesTest(unittest.TestCase):
    def setUp(self):
        import numpy as np
        from PIL import Image, ImageDraw
        import make_hero_frames
        self.np, self.Image, self.Draw, self.h = np, Image, ImageDraw, make_hero_frames

    def _blob(self, w, h, color=(0xFD, 0xB8, 0x65)):
        a = self.np.zeros((h, w, 4), self.np.uint8)
        a[...] = color + (255,)
        return a

    def test_선보다_어두운_색은_선_색으로_올린다(self):
        a = self._blob(4, 1)
        a[0, 0, :3] = (0, 0, 0)
        a[0, 1, :3] = (0x33, 0x18, 0x06)
        out = self.h.darken_fix(a)
        self.assertEqual(tuple(out[0, 0, :3]), (0x33, 0x18, 0x06))
        self.assertEqual(tuple(out[0, 2, :3]), (0xFD, 0xB8, 0x65), "주황은 그대로")

    def test_발끝은_바닥선에_몸_중심은_기준점에(self):
        im = self.Image.fromarray(self._blob(120, 60))
        canvas, lost = self.h.place(im)
        a = self.np.asarray(canvas)[..., 3] > 128
        ys = self.np.where(a.any(1))[0]
        self.assertEqual(ys[-1] + 1, self.h.BASELINE)
        self.assertAlmostEqual(self.h.body_center_x(a), self.h.ANCHOR_X, delta=1.0)
        self.assertEqual(lost, 0)
        lifted, _ = self.h.place(im, lift=16)
        self.assertEqual(self.np.where((self.np.asarray(lifted)[..., 3] > 128).any(1))[0][-1] + 1, self.h.BASELINE - 16, "튕겨 뜬 장은 떠 있음")

    def test_캔버스_밖으로_나가는_떨어진_먼지만_뺀다(self):
        a = self.np.zeros((40, 900, 4), self.np.uint8)
        a[:, 500:800] = (0xFD, 0xB8, 0x65, 255)   # 몸
        a[20:40, 0:40] = (0xFE, 0xEB, 0xCF, 255)  # 멀리 떨어진 먼지 (캔버스 왼쪽 밖으로 나감)
        canvas, lost = self.h.place(self.Image.fromarray(a))
        self.assertEqual(lost, 0, "몸은 안 잘림")
        c = self.np.asarray(canvas)
        self.assertFalse(((c[..., 0] == 0xFE) & (c[..., 3] > 0)).any(), "먼지 없음")

    def test_눈_감은_몸은_점_눈을_덮고_선을_그린다(self):
        img = self.Image.fromarray(self._blob(200, 200))
        d = self.Draw.Draw(img)
        d.ellipse([120, 50, 134, 66], fill=(0x33, 0x18, 0x06, 255))  # 점 눈 (위쪽)
        out, eyes = self.h.blink(img)
        self.assertEqual(eyes, 1)
        o = self.np.asarray(out).astype(int)
        self.assertEqual(tuple(o[52, 127, :3]), (0xFD, 0xB8, 0x65), "눈 위쪽(감은 눈 선 위)은 털 색으로 덮임")
        self.assertTrue((self.np.abs(o[40:75, 110:145, :3] - (0x33, 0x18, 0x06)).sum(2) < 10).any(), "감은 눈 선")

    def test_달리기는_머리_높이가_거의_같다(self):
        # 깡충거림 방지: 달리기 8장의 머리 꼭대기 높이 차이가 머리 너비의 15% 이하 (그림 파일에서 잼)
        _, spread, head = self.h.run_heads()
        self.assertGreater(head, 100, "머리를 찾음")
        self.assertLessEqual(spread, head * 0.15)

    def test_머리_너비와_꼭대기(self):
        img = self.Image.new("RGBA", (300, 300), (0, 0, 0, 0))
        d = self.Draw.Draw(img)
        d.ellipse([50, 60, 250, 260], fill=(0xFD, 0xB8, 0x65, 255), outline=(0x33, 0x18, 0x06, 255), width=6)
        d.ellipse([200, 140, 214, 156], fill=(0x33, 0x18, 0x06, 255))  # 오른쪽 점 눈
        w, top = self.h.head_box(img)
        self.assertEqual(top, 60)
        self.assertAlmostEqual(w, 200, delta=4)


if __name__ == "__main__":
    unittest.main()
