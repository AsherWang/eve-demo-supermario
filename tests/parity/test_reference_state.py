import json
import sys
import unittest
import tempfile
from unittest.mock import Mock, patch
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools/parity"))
from extract_reference_state import ADDR, decode_line
from run_actual import runtime_error_lines, RuntimeLogMonitor
import run_actual


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

    def test_incremental_log_detects_split_initialization_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "process.log"
            monitor = RuntimeLogMonitor([path])
            self.assertEqual(monitor.poll(), [])
            path.write_bytes(b"NATIVE_AUDIO error=0\neve_init fai")
            self.assertEqual(monitor.poll(), [])
            with path.open("ab") as stream:
                stream.write(b"led: missing slot\nStack:\n")
            self.assertEqual(monitor.poll(), ["eve_init failed: missing slot"])
            self.assertEqual(monitor.poll(), [])

    def test_initialization_failure_stops_process_and_disables_adapter(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            generated = root / "scripts/generated/parity_movie.nut"
            generated.parent.mkdir(parents=True)
            generated.write_text("original adapter", encoding="utf-8")
            for name in ("main.nut", "config.nut"):
                (root/name).write_text("// fixture", encoding="utf-8")
            (root/"assets").mkdir()
            process = Mock()
            process.poll.return_value = None

            def start(*args, **kwargs):
                kwargs["stdout"].write("eve_init failed: missing game state\n")
                kwargs["stdout"].flush()
                return process

            movie = Path(__file__).parent / "movies/world-2-1-normal-clear.json"
            argv = ["run_actual.py", "--movie", str(movie), "--output", str(root / "capture"),
                    "--project", str(root), "--timeout", "300"]
            with patch.object(sys, "argv", argv), patch.object(run_actual.subprocess, "Popen", side_effect=start):
                with self.assertRaisesRegex(RuntimeError, "eve_init failed: missing game state"):
                    run_actual.main()
            process.terminate.assert_called_once()
            process.wait.assert_called_once_with(timeout=5)
            self.assertEqual(generated.read_text(encoding="utf-8"), "original adapter")
            snapshot=root/"capture/runtime-project/scripts/generated/parity_movie.nut"
            self.assertEqual(snapshot.read_text(encoding="utf-8"), run_actual.DISABLED_SOURCE)
            self.assertIn("eve_init failed", (root / "capture/process-stdout.log").read_text())

    def test_script_failure_is_detected_but_audio_status_is_not(self):
        self.assertEqual(runtime_error_lines("Run failed: Script execute failed"),
                         ["Run failed: Script execute failed"])
        self.assertEqual(runtime_error_lines("NATIVE_AUDIO error=0\nPARITY_DONE frames=120"), [])


if __name__ == "__main__":
    unittest.main()
