"""tools/cut_kittens.py: 기다리기 꼬리 떼기·얼굴 자르기 (만든 그림으로)."""
import importlib.util
import unittest

HAS_LIBS = all(importlib.util.find_spec(m) for m in ("numpy", "scipy", "PIL"))
if HAS_LIBS:
    import numpy as np
    from PIL import Image

    from cut_kittens import TAIL_ANGLES, face, split_tail


def kitten(tail: bool) -> Image.Image:
    """웅크린 몸(가로 긴 네모) + 오른쪽 위 머리 + 왼쪽 엉덩이에서 위로 선 꼬리."""
    rgba = np.zeros((240, 256, 4), np.uint8)
    rgba[150:216, 40:200] = (200, 150, 100, 255)   # 몸
    rgba[100:170, 140:205] = (210, 160, 110, 255)  # 머리
    if tail:
        rgba[80:152, 45:65] = (190, 140, 90, 255)  # 세운 꼬리
    return Image.fromarray(rgba)


@unittest.skipUnless(HAS_LIBS, "numpy, scipy, Pillow 필요")
class SplitTailTest(unittest.TestCase):
    def test_세운_꼬리는_몸에서_떼어_돌린다(self):
        body, tails = split_tail(kitten(True))
        alpha = np.asarray(body)[..., 3]
        self.assertEqual(alpha[80:140, 45:65].max(), 0, "몸 그림에 꼬리가 없음")
        self.assertEqual(len(tails), len(TAIL_ANGLES))
        middle = np.asarray(tails[len(tails) // 2])[..., 3]
        self.assertGreater((middle[80:140, 45:65] > 128).mean(), 0.9, "0도 꼬리는 제자리")
        self.assertFalse(np.array_equal(np.asarray(tails[0]), np.asarray(tails[-1])), "양 끝 꼬리는 다르게 돌아감")

    def test_오목한_곳이_얕으면_꼬리를_떼지_않는다(self):
        img = kitten(False)
        body, tails = split_tail(img)
        self.assertTrue(np.array_equal(np.asarray(body), np.asarray(img)))
        self.assertTrue(all(np.asarray(t)[..., 3].max() == 0 for t in tails))

    def test_얼굴은_둥근_배지(self):
        out = np.asarray(face(kitten(False), (172, 135, 70)))
        self.assertEqual(out.shape[:2], (96, 96))
        self.assertEqual(out[48, 48, 3], 255, "가운데는 불투명")
        self.assertEqual(out[2, 2, 3], 0, "네 귀퉁이는 투명 (둥긂)")
        self.assertLess(out[48, 1, :3].max(), 120, "가장자리는 갈색 테두리")


if __name__ == "__main__":
    unittest.main()
