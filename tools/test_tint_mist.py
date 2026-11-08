import unittest

import numpy as np

from tint_mist import tint


class TintTest(unittest.TestCase):
    def test_색은_크림색_쪽으로_투명도는_그대로(self):
        rgba = np.array([[[0xfe, 0xc4, 0xbd, 77]]], dtype=np.uint8)
        out = tint(rgba, 0.45)[0, 0]
        self.assertEqual(out[3], 77)
        self.assertEqual(list(out[:3]), [0xfe, 0xda, 0xd2])  # world_view.gd MIST_FILLS.mid와 같은 값


if __name__ == "__main__":
    unittest.main()
