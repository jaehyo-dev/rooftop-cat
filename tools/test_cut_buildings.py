"""건물 자르기 도구 테스트 (numpy·scipy·Pillow가 없는 환경에서는 건너뜀)."""
import importlib.util
import unittest

HAS_LIBS = all(importlib.util.find_spec(name) for name in ("numpy", "scipy", "PIL"))


@unittest.skipUnless(HAS_LIBS, "numpy, scipy, Pillow 필요")
class CutBuildingsTest(unittest.TestCase):
    def setUp(self):
        import numpy as np
        import cut_buildings
        self.np, self.cb = np, cut_buildings

    def test_가장자리_분홍_기는_안쪽_색으로_바뀌고_모양은_그대로(self):
        np = self.np
        rgba = np.zeros((8, 8, 4), np.uint8)
        rgba[:, :5] = (250, 230, 190, 255)   # 크림색 벽
        rgba[:, 5] = (221, 129, 200, 165)    # 마젠타가 섞인 반투명 가장자리
        fixed = self.cb.despill(rgba)
        self.assertEqual(tuple(fixed[3, 5, :3]), (250, 230, 190))
        self.assertEqual(fixed[3, 5, 3], 165)   # 알파는 그대로
        self.assertEqual(tuple(fixed[3, 2]), (250, 230, 190, 255))

    def test_지붕_턱_윗줄이_조각의_맨_위다(self):
        np = self.np
        body = np.zeros((10, 6, 4), np.uint8)
        body[3:, :] = (200, 180, 160, 255)
        self.assertEqual(self.cb._top_row(body), 3)

    def test_건물_조각_범위가_서로_이어진다(self):
        # 왼쪽 캡 끝 = 첫 가운데 조각 시작, 조각들은 빈틈·겹침 없이 오른쪽 캡 시작까지 이어짐
        for name, spec in self.cb.BUILDINGS.items():
            edge = spec["left"]
            for start, end in spec["mids"]:
                self.assertEqual(start, edge, name)
                edge = end
            self.assertEqual(edge, spec["right"], name)


if __name__ == "__main__":
    unittest.main()
