import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/parity'))
from common import require_supported_stage
from run_reference import build_movie_origin_lua
from world23_reference import build_world23_origin_lua
from world24_reference import build_world24_origin_lua


class World2StrictDispatchTest(unittest.TestCase):
    def test_reference_and_actual_support_same_complete_stages(self):
        for stage, builder in [(3, build_world23_origin_lua), (4, build_world24_origin_lua)]:
            movie = dict(world=2, level=stage)
            self.assertEqual(require_supported_stage(movie), (2, stage))
            self.assertEqual(build_movie_origin_lua(movie), builder())

    def test_unimplemented_world_stays_rejected(self):
        with self.assertRaises(ValueError):
            require_supported_stage(dict(world=3, level=1))
