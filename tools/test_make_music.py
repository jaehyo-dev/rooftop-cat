import unittest

try:
    import numpy as np

    import make_music as m
except ImportError as error:  # numpy는 개발 도구용이라 GitHub Actions에는 없다 (다른 도구 테스트와 같이 건너뜀)
    raise unittest.SkipTest(f"numpy 없음: {error}")


class SongTest(unittest.TestCase):
    def test_후보_곡은_방향에_맞는_빠르기와_30초_안팎(self):
        for name in ("mochi", "swing"):
            song = m.SONGS[name]
            self.assertTrue(110 <= song["bpm"] <= 124, name)
            seconds = len(song["chords"].split()) * 4 * 60.0 / song["bpm"]
            self.assertTrue(28 <= seconds <= 40, f"{name} {seconds:.1f}초")

    def test_게임_곡은_60초_안팎이고_같은_마디만_반복하지_않는다(self):
        song = m.SONGS["mochi_game"]
        seconds = len(song["chords"].split()) * 4 * 60.0 / song["bpm"]
        self.assertTrue(55 <= seconds <= 65, f"{seconds:.1f}초")
        self.assertGreater(len(set(song["melody"])), 16)
        self.assertEqual(song["chords"].split()[-1], "G")  # 첫 마디 C로 돌아가는 코드

    def test_게임_곡_반복_이음매가_튀지_않는다(self):
        a = m.build_song("mochi_game")
        # 끝 → 처음으로 넘어가는 샘플 변화가 곡 안에서 나오는 샘플 변화 범위 안
        self.assertLessEqual(abs(a[0] - a[-1]), float(np.abs(np.diff(a)).max()))
        # 이음매 앞뒤 0.5초의 세기가 크게 다르지 않다 (뚝 끊기거나 갑자기 커지지 않음)
        n = m.RATE // 2
        end, start = np.sqrt(np.mean(a[-n:] ** 2)), np.sqrt(np.mean(a[:n] ** 2))
        self.assertLess(max(end, start) / min(end, start), 2.0)

    def test_악보는_마디마다_8칸이고_코드_수와_같다(self):
        for name, song in m.SONGS.items():
            self.assertEqual(len(song["melody"]), len(song["chords"].split()), name)
            for bar in song["melody"]:
                self.assertEqual(len(bar.split()), 8, f"{name}: {bar}")
                for token in bar.split():
                    if token != "-":
                        m.note_midi(token)
            for chord in song["chords"].split():
                self.assertIn(chord, m.CHORD_TABLE)

    def test_같은_곡은_항상_같고_터지지_않는다(self):
        a = m.build_song("mochi")
        self.assertTrue(np.array_equal(a, m.build_song("mochi")))
        self.assertLessEqual(float(np.abs(a).max()), 0.8 + 1e-9)

    def test_음이름(self):
        self.assertEqual(m.note_midi("C4"), 60)
        self.assertEqual(m.note_midi("Bb5"), 82)


if __name__ == "__main__":
    unittest.main()
