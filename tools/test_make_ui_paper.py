"""tools/make_ui_paper.py: 가장자리 비움, 같은 굵기 갈색 테두리, 결 없음, 저장된 그림 = 도구가 그리는 그림"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
try:
    import numpy as np
    from PIL import Image

    import make_ui_paper as m
except ImportError as error:  # numpy·Pillow는 개발 도구용이라 GitHub Actions에는 없다 (다른 도구 테스트와 같이 건너뜀)
    raise unittest.SkipTest(f"numpy·Pillow 없음: {error}")

UI = Path(__file__).parent.parent / "assets/sprites/ui"


class UiPaperTest(unittest.TestCase):
    def kinds(self):
        for name, (size, radius, top, bottom) in m.KINDS.items():
            yield name, np.array(m.paper(size, radius, top, bottom))
        yield "cork", np.array(m.cork())

    def test_가장자리_1px은_비고_가운데_줄에_갈색_테두리(self):
        for name, img in self.kinds():
            a = img[..., 3]
            self.assertEqual(int(np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]]).max()), 0, name)
            mid = img[img.shape[0] // 2]
            line = mid[m.EDGE + m.HALO_W + 1][:3]  # 밝은 테두리 바로 안쪽 = 갈색 선
            self.assertTrue(np.abs(line.astype(int) - m.BROWN).max() < 30, (name, line))

    def test_결이_없다(self):
        panel = dict(self.kinds())["panel"][60:130, 60:130, :3].astype(float)
        self.assertLess(panel.std(axis=1).max(), 1.0)  # 가로로 같은 색 (위아래 밝기 차이만)

    def test_게임이_쓰는_그림은_도구가_그린_그림과_같다(self):
        for name, img in self.kinds():
            np.testing.assert_array_equal(np.array(Image.open(UI / f"{name}.png").convert("RGBA")), img, name)


if __name__ == "__main__":
    unittest.main()
