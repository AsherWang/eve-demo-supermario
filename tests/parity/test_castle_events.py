import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/parity'))
from extract_reference_events import castle_milestones


class CastleEventsTest(unittest.TestCase):
    def ram(self, mode, task, world=1, stage=3):
        ram = bytearray(2048)
        ram[0x770], ram[0x772], ram[0x75F], ram[0x75C] = mode, task, world, stage
        return ram

    def test_actual_victory_transitions(self):
        self.assertEqual(castle_milestones(self.ram(1, 3), self.ram(2, 0)), ['axe_touched'])
        self.assertEqual(castle_milestones(self.ram(2, 2), self.ram(2, 3)), ['mushroom_retainer_saved'])
        self.assertEqual(castle_milestones(self.ram(2, 4), self.ram(1, 0, 2, 0)), ['world24_complete'])

    def test_repeated_axe_tasks_and_other_transitions_are_not_new_milestones(self):
        for before, after in [(self.ram(2, 2), self.ram(2, 0)),
                              (self.ram(2, 3), self.ram(2, 3)),
                              (self.ram(2, 4), self.ram(2, 4)),
                              (self.ram(1, 3, stage=2), self.ram(2, 0)),
                              (None, self.ram(2, 3))]:
            self.assertEqual(castle_milestones(before, after), [])
