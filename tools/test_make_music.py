import unittest

import numpy as np

import make_music as m


class SongTest(unittest.TestCase):
    def test_후보_곡은_방향에_맞는_빠르기와_30초_안팎(self):
        for name, song in m.SONGS.items():
            self.assertTrue(110 <= song["bpm"] <= 124, name)
            seconds = len(song["chords"].split()) * 4 * 60.0 / song["bpm"]
            self.assertTrue(28 <= seconds <= 40, f"{name} {seconds:.1f}초")

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
