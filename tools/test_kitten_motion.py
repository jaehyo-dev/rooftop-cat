"""아기 움직임 1단계: 프레임 그림 달리기의 발 미끄러짐 (A 아기 vs 주인공, 같은 검사 tools/foot_slip.py).
A는 8장 그림이라 한 장에 머무는 동안 발이 몸과 같이 밀리는 만큼(한 장 거리 약 19px)은 구조상 남는다.
허용: A 30px 이하이고 주인공의 60% 이하. B는 tests/test_kitten_motion.gd (0.5px 이하)."""
import importlib.util
import unittest

# 그림을 재므로 numpy·scipy·Pillow가 있는 곳(로컬)에서만. Actions에는 없어 다른 그림 도구 테스트처럼 건너뜀
HAS_LIBS = all(importlib.util.find_spec(m) for m in ("numpy", "scipy", "PIL"))
if HAS_LIBS:
    import foot_slip as fs

A_MAX = 30.0
VS_HERO = 0.6


@unittest.skipUnless(HAS_LIBS, "numpy, scipy, Pillow 필요")
class FootSlip(unittest.TestCase):
    def test_A는_주인공보다_덜_미끄러진다(self):
        r = fs.report()
        for v in fs.SPEEDS:
            self.assertLessEqual(r["A"][v], A_MAX, f"속도 {v}: A {r['A'][v]}px")
            self.assertLessEqual(r["A"][v], r["hero"][v] * VS_HERO, f"속도 {v}: A {r['A'][v]} / 주인공 {r['hero'][v]}")

    def test_한_장_안에서_밀리는_발도_잰다(self):
        # 한 장뿐인 그림을 빠르게 돌리면 발이 몸과 같이 계속 밀린다 (예전 검사는 새 발로 봐 0이었음, Codex 리뷰)
        self.assertGreater(fs.slip([[0.0]], 100000.0, 1500.0, seconds=1.0), 1000.0)

    def test_정지한_발은_미끄러짐_0(self):
        # 검사 자체 확인: 디딘 발이 장마다 한 장 거리만큼 정확히 뒤로 가는 가짜 달리기는 장 안에서 밀리는 만큼만
        frames = [[10.0], [5.0], [0.0], []]  # 세 장 디디고 한 장 들림
        self.assertLessEqual(fs.slip(frames, 20.0, 300.0), 5.0 + 1e-6)


if __name__ == "__main__":
    unittest.main()
