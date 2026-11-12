"""tools/make_ui_paper.py: 가장자리 비움, 같은 굵기 갈색 테두리, b는 결 없음·a는 옅은 결, 같은 시드면 같은 그림"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
try:
    import numpy as np

    import make_ui_paper as m
except ImportError as error:  # numpy·Pillow는 개발 도구용이라 GitHub Actions에는 없다 (다른 도구 테스트와 같이 건너뜀)
    raise unittest.SkipTest(f"numpy·Pillow 없음: {error}")


class UiPaperTest(unittest.TestCase):
    def kinds(self, look):
        for name, (size, radius, top, bottom, amp, margin) in m.KINDS.items():
            yield name, np.array(m.paper(size, radius, top, bottom, amp if look == "a" else 0.0, 1, margin))
        yield "cork", np.array(m.cork(look == "a"))

    def test_가장자리_1px은_비고_가운데_줄에_갈색_테두리(self):
        for look in "ab":
            for name, img in self.kinds(look):
                a = img[..., 3]
                self.assertEqual(int(np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]]).max()), 0, name)
                mid = img[img.shape[0] // 2]
                line = mid[m.EDGE + m.HALO_W + 1][:3]  # 밝은 테두리 바로 안쪽 = 갈색 선
                self.assertTrue(np.abs(line.astype(int) - m.BROWN).max() < 30, (name, line))

    def test_b는_결이_없고_a는_옅은_결(self):
        flat = dict(self.kinds("b"))["panel"][60:130, 60:130, :3].astype(float)
        grainy = dict(self.kinds("a"))["panel"][60:130, 60:130, :3].astype(float)
        self.assertLess(flat.std(axis=1).max(), 1.0)  # 가로로 같은 색 (위아래 밝기 차이만)
        self.assertGreater(grainy.std(axis=1).mean(), 1.0)
        self.assertLess(grainy.std(axis=1).mean(), 8.0)  # 은은하게

    def test_a_종이_결은_가운데_칸_크기로_되풀이된다(self):
        # 게임이 9칸 가운데·가장자리 띠를 바둑판처럼 이어 붙이므로, 한 칸 건너 같은 결이어야 이음매가 없다
        for size, margin in [(v[0], v[5]) for v in m.KINDS.values()] + [(m.CORK[0], m.CORK[2])]:
            w, h = size
            tw, th = w - 2 * margin, h - 2 * margin
            g = m.tiled_grain(w, h, margin, 1)
            np.testing.assert_array_equal(g[:, :w - tw], g[:, tw:])
            np.testing.assert_array_equal(g[:h - th], g[th:])

    def test_같은_시드면_같은_결(self):
        self.assertTrue(np.array_equal(m.grain(32, 32, 3), m.grain(32, 32, 3)))


if __name__ == "__main__":
    unittest.main()
