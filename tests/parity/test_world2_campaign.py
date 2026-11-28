import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/parity'))
from run_world2_campaign import validate_campaign


class CampaignTest(unittest.TestCase):
    def rows(self):
        return [dict(frame=f, world=2, level=level, lives=3, dead=False, state=state)
                for f, (level, state) in enumerate([(2, 'playing'), (3, 'playing'),
                                                   (4, 'playing'), (4, 'worldComplete')])]

    def test_complete(self):
        self.assertTrue(validate_campaign(self.rows(), dict(world=2, level=2, frames=3))['passed'])

    def test_rejects_invalid_campaigns(self):
        for index, field, value in [(1, 'level', 4), (1, 'dead', True), (2, 'lives', 2),
                                     (3, 'state', 'playing'), (2, 'frame', 1)]:
            with self.subTest(field=field):
                rows = self.rows()
                rows[index][field] = value
                self.assertFalse(validate_campaign(rows, dict(world=2, level=2, frames=3))['passed'])
