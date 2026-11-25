"""v0.8.0 카툰 배경·적 그림 도구: 선 깎기, 캔버스 맞추기, 적 그림 색표·선 굵기."""
import importlib.util
import unittest
from pathlib import Path

HAS_LIBS = all(importlib.util.find_spec(name) for name in ("numpy", "scipy", "PIL", "skimage"))
ROOT = Path(__file__).resolve().parent.parent


@unittest.skipUnless(HAS_LIBS, "numpy, scipy, Pillow, scikit-image 필요")
class BgArtTest(unittest.TestCase):
    def setUp(self):
        import numpy as np
        from PIL import Image
        import cartoon_art
        import make_bg_art
        self.np, self.Image, self.ca, self.b = np, Image, cartoon_art, make_bg_art

    def test_선을_안쪽에서만_깎는다(self):
        a = self.np.zeros((60, 60, 4), self.np.uint8)
        a[4:56, 4:56] = (0x33, 0x18, 0x06, 255)
        a[20:40, 20:40] = (0xD8, 0xD2, 0xCC, 255)  # 안쪽 면
        out = self.b.thin(a, 3).astype(int)
        lum = lambda p: 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
        self.assertGreater(lum(out[19, 30]), 180, "면 바로 옆 선은 면 색으로")
        self.assertGreater(lum(out[18, 30]), lum(a[18, 30].astype(int)) + 60, "2px 옆 선도 밝아짐 (다시 줄일 때 섞임)")
        self.assertLess(lum(out[6, 30]), 80, "바깥 테두리 쪽 선은 그대로")
        self.assertTrue(((out[..., 3] > 128) == (a[..., 3] > 128)).all(), "모양(알파)은 그대로")

    def test_캔버스에_비율대로_바닥_가운데(self):
        a = self.np.full((50, 100, 4), 255, self.np.uint8)
        im, k = self.b.fit(a, (200, 200), pad=0)
        ys, xs = self.np.where(im[..., 3] > 128)
        self.assertEqual(ys.max(), 199, "바닥에 붙음")
        self.assertAlmostEqual((xs.min() + xs.max()) / 2, 99.5, delta=1)
        self.assertAlmostEqual(k, 2.0)

    def test_전봇대_상수가_그림과_같다(self):
        import re
        p = self.np.asarray(self.Image.open(ROOT / "assets/sprites/structures/pole.png").convert("RGBA"))
        code = (ROOT / "scripts/world_view.gd").read_text()
        game = {k: float(v) for k, v in re.findall(r'"(\w+)": ([\d.]+)', re.search(r"const CARTOON_POLE := \{([^}]*)\}", code).group(1))}
        self.assertEqual(game, {k: float(v) for k, v in self.b.pole_consts(p).items()})

    def _frames(self, kind):
        return sorted((ROOT / f"assets/sprites/enemies/{kind}").glob("*.png"))

    def test_적_그림은_색표_안(self):
        for kind, pal in (("crow", self.ca.CROW), ("rat", self.ca.RAT)):
            files = self._frames(kind)
            self.assertEqual(len(files), 6, kind)
            for f in files:
                report = self.ca.palette_report(self.np.asarray(self.Image.open(f).convert("RGBA")), pal)
                self.assertTrue(set(pal) <= set(report), f"{f.name}: 색 {set(pal) - set(report)} 없음")
                for name, (n, med, diff) in report.items():
                    self.assertLessEqual(diff, 0x10, f"{kind}/{f.name} {name} #%02X%02X%02X" % med)

    def test_적_선_굵기는_게임_크기에서_기준_안(self):
        # 게임은 파일을 1/2로 그림. 바깥선 3.5±0.75 (ART_BIBLE 14-1), 선 중심색 #331806 ± 0x20
        import tempfile
        for kind, frame in (("crow", "fly_0"), ("rat", "run_0")):  # 가장 많이 보이는 반복 첫 장
            im = self.Image.open(ROOT / f"assets/sprites/enemies/{kind}/{frame}.png").convert("RGBA")
            bg = self.Image.new("RGBA", im.size, (255, 0, 255, 255))
            bg.alpha_composite(im)
            with tempfile.NamedTemporaryFile(suffix=".png") as t:
                bg.convert("RGB").save(t.name)
                r = self.ca.check(t.name, 0.5)
            self.assertTrue(2.75 <= r["outer"] <= 4.25, f"{kind} 바깥선 {r['outer']}")
            core = tuple(int(r["core"][i:i + 2], 16) for i in (1, 3, 5))
            self.assertTrue(all(abs(c - l) <= 0x20 for c, l in zip(core, self.ca.LINE)), f"{kind} 선 색 {r['core']}")


if __name__ == "__main__":
    unittest.main()
