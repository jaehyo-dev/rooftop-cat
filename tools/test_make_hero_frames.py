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

    def test_주인공_그림은_모두_색표_안(self):
        # 2026-11-25: 시트 색(짙은 초록 목도리·회갈색 먼 다리)이 그대로 들어간 일이 있어 그림 파일마다 14-2 색표 ±0x10을 확인
        import cartoon_art as ca
        frames = sorted((self.h.OUT).glob("*.png"))
        self.assertGreater(len(frames), 30)
        for f in frames:
            a = self.np.asarray(self.Image.open(f).convert("RGBA"))
            report = ca.palette_report(a, ca.HERO)
            self.assertIn("body", report, f.name)
            for name, (n, med, diff) in report.items():
                self.assertLessEqual(diff, 0x10, f"{f.name} {name} #%02X%02X%02X ({n}px)" % med)
            self.assertLessEqual(ca.dark_blobs(a), 30, f"{f.name}: 선이 아닌 검은 갈색 덩어리")

    def test_시트_색을_색표로_옮기고_선은_그대로(self):
        import cartoon_art as ca
        a = self._blob(40, 20, (0x73, 0xD0, 0x97))  # 짙은 초록 목도리
        a[:, :10, :3] = (0x33, 0x18, 0x06)
        a[:, 10, :3] = (0x53, 0x74, 0x4E)  # 선과 반쯤 섞인 가장자리
        out = ca.recolor(a, [((0x73, 0xD0, 0x97), "scarf")], ca.HERO).astype(int)
        self.assertEqual(tuple(out[5, 30, :3]), ca.HERO["scarf"])
        self.assertEqual(tuple(out[5, 2, :3]), (0x33, 0x18, 0x06), "선은 그대로")
        mid = out[5, 10, :3]
        self.assertTrue(all(0x33 < v < c for v, c in zip(mid, ca.HERO["scarf"])), "가장자리는 섞인 몫만큼")

    def test_얇은_어두운_띠는_그늘색으로_바꾸지_않는다(self):
        import cartoon_art as ca
        a = self._blob(40, 40)
        a[10:30, 10:30, :3] = (0x9D, 0x50, 0x1A)  # 덩어리 = 먼 쪽 다리
        a[35, :, :3] = (0x9D, 0x50, 0x1A)          # 1px 띠 = 선과 섞인 가장자리
        pairs = [((0xFD, 0xB8, 0x65), "body"), ((0x9D, 0x50, 0x1A), "body_shade")]
        out = ca.recolor(a, pairs, {**ca.HERO, **ca.HERO_SHADE}).astype(int)
        self.assertEqual(tuple(out[20, 20, :3]), ca.HERO_SHADE["body_shade"])
        self.assertNotEqual(tuple(out[35, 20, :3]), ca.HERO_SHADE["body_shade"])


if __name__ == "__main__":
    unittest.main()
