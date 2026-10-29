import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools/parity"))
from extract_reference_state import ADDR, decode_line
from run_actual import runtime_error_lines


class ReferenceLivesTest(unittest.TestCase):
    def test_lives_minus_one_and_game_over_sentinel(self):
        for raw, visible in [(0, 1), (1, 2), (2, 3), (127, 128), (254, 255), (255, 0)]:
            with self.subTest(raw=raw):
                ram = bytearray(2048)
                ram[ADDR["number_of_lives"]] = raw
                result = decode_line(json.dumps({"frame": 0, "ram_hex": ram.hex()}))
                self.assertEqual(result["lives"], visible)
                self.assertEqual(result["lives_raw"], raw)


class ReplayErrorTest(unittest.TestCase):
    def test_render_fault_is_not_success_even_when_capture_completes(self):
        log = ("NATIVE_AUDIO backend=winmm-pcm error=0\n"
               "frame error: game:/scripts/render.nut:390: invalid type\n"
               "PARITY_DONE frames=2650\n")
        self.assertEqual(runtime_error_lines(log), [
            "frame error: game:/scripts/render.nut:390: invalid type"])

    def test_script_failure_is_detected_but_audio_status_is_not(self):
        self.assertEqual(runtime_error_lines("Run failed: Script execute failed"),
                         ["Run failed: Script execute failed"])
        self.assertEqual(runtime_error_lines("NATIVE_AUDIO error=0\nPARITY_DONE frames=120"), [])


if __name__ == "__main__":
    unittest.main()
