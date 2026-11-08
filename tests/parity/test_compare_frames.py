import random
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageChops

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools/parity"))
from compare_frames import compare, image_sha256, save_difference


class FrameStatisticsTest(unittest.TestCase):
    def assert_matches_pixel_loop(self, reference, actual, tolerances):
        difference = ImageChops.difference(reference, actual)
        pixels = list(difference.getdata())
        for tolerance in tolerances:
            with self.subTest(tolerance=tolerance):
                result = compare(reference, actual, tolerance)
                mismatches = sum(max(pixel) > tolerance for pixel in pixels)
                self.assertEqual(result["mismatched_pixels"], mismatches)
                self.assertEqual(result["mismatch_ratio"], mismatches / len(pixels))
                self.assertEqual(result["mean_absolute_channel_error"],
                                 sum(map(sum, pixels)) / (len(pixels) * 3))
                self.assertEqual(result["max_channel_error"], max(map(max, pixels)))
                self.assertEqual(result["reference_sha256"], image_sha256(reference))
                self.assertEqual(result["actual_sha256"], image_sha256(actual))
                self.assertEqual(result["difference"].tobytes(), difference.tobytes())

    def test_threshold_boundaries_and_each_channel(self):
        reference = Image.new("RGB", (5, 1))
        actual = Image.new("RGB", (5, 1))
        actual.putdata([(0, 0, 0), (1, 0, 0), (0, 127, 0),
                        (0, 0, 255), (12, 13, 14)])
        self.assert_matches_pixel_loop(reference, actual,
                                       [-1, 0, 1, 12, 13, 14, 126, 127, 254, 255, 256])

    def test_seeded_full_frame(self):
        rng = random.Random(517)
        size = (256, 240)
        reference = Image.frombytes("RGB", size, rng.randbytes(256 * 240 * 3))
        actual = Image.frombytes("RGB", size, rng.randbytes(256 * 240 * 3))
        self.assert_matches_pixel_loop(reference, actual, [0, 7, 128, 255])

    def test_identical_black_and_white_frames(self):
        for color in [(0, 0, 0), (255, 255, 255)]:
            image = Image.new("RGB", (16, 16), color)
            self.assert_matches_pixel_loop(image, image, [-1, 0, 255])

    def test_difference_visual_matches_pixel_loop(self):
        rng = random.Random(553)
        difference = Image.frombytes("RGB", (16, 16), rng.randbytes(16 * 16 * 3))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "diff.png"
            for tolerance in [-1, 0, 32, 128, 254, 255, 256]:
                with self.subTest(tolerance=tolerance):
                    expected = Image.new("RGB", difference.size)
                    expected.putdata([(255, max(32, max(pixel)), 0)
                                      if max(pixel) > tolerance else (0, 0, 0)
                                      for pixel in difference.getdata()])
                    expected = expected.resize((512, 480), Image.Resampling.NEAREST)
                    save_difference(difference, path, tolerance)
                    with Image.open(path) as actual:
                        self.assertEqual(actual.tobytes(), expected.tobytes())


if __name__ == "__main__":
    unittest.main()
