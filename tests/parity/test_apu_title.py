import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools/parity"))
from model_apu_writes import SmbApuModel, STATUS
from extract_reference_events import is_new_game_transition


class TitleSoundTest(unittest.TestCase):
    def model(self):
        model = SmbApuModel.__new__(SmbApuModel)
        model.ram = bytearray([0x55] * 2048)
        model.writes = []
        return model

    def state(self, mode, task=3, counter=1):
        return {"frame_counter": counter,
                "rom_state": {"oper_mode": mode, "oper_mode_task": task}}

    def test_water_music_event_queues_rom_area_bit_after_origin(self):
        model = self.model()
        model.queue_event({"type": "music", "name": "water", "frame": 4}, None)
        self.assertEqual(model.r(0xFB), 0x02)
        model.s(0xFB, 0)
        model.queue_event({"type": "music", "name": "water", "frame": 0}, None)
        self.assertEqual(model.r(0xFB), 0)

    def test_castle_events_reach_their_original_sound_queues(self):
        for kind, name, address, value in [('audio', 'bowser_flame', 0xFD, 2),
                                         ('audio', 'bowser_fall', 0xFE, 0x80),
                                         ('music', 'end_castle', 0xFC, 8)]:
            model = self.model()
            model.queue_event(dict(type=kind, name=name, frame=10), None)
            self.assertEqual(model.r(address), value)

    def test_flame_duration_and_final_preceding_envelope_byte(self):
        model = self.model()
        model.flame_envelopes = bytes(range(33))
        model.s(0xFD, 2)
        model.handle_noise_sfx()
        self.assertEqual(model.writes, [(0x400C, 32), (0x400E, 15), (0x400F, 24)])
        model.s(0xFD, 0)
        for _ in range(62):
            model.handle_noise_sfx()
        model.writes = []
        model.handle_noise_sfx()
        self.assertEqual(model.writes, [(0x400C, 0), (0x400E, 15), (0x400F, 24), (0x400C, 240)])
        self.assertEqual(model.r(0xF3), 0)

    def test_title_disables_channels_without_consuming_queues_or_advancing_music(self):
        model = self.model()
        before = bytes(model.ram)
        self.assertEqual(model.step(0), [(STATUS, 0)])
        self.assertEqual(bytes(model.ram), before)

    def test_sound_engine_observes_mode_before_gameplay_changes_it(self):
        model = self.model()
        calls = []
        model.step = lambda mode: calls.append(mode) or [(STATUS, mode)]
        self.assertEqual(model.advance_frame(self.state(3), self.state(0)), [(STATUS, 3)])
        self.assertEqual(model.advance_frame(self.state(0), self.state(1)), [(STATUS, 0)])
        self.assertEqual(calls, [3, 0])

    def test_title_initialization_clears_sound_state_without_writes(self):
        model = self.model()
        self.assertEqual(model.advance_frame(self.state(0), self.state(0, 0, 0)), [])
        self.assertEqual(model.ram[:0x100], bytes(0x100))
        self.assertEqual(model.ram[0x7B0:0x7D0], bytes(0x20))
        self.assertEqual(model.ram[0x100], 0x55)
        self.assertEqual(model.ram[0x7D0], 0x55)

    def test_counter_wrap_when_entering_title_still_runs_previous_mode_sound(self):
        model = self.model()
        before = bytes(model.ram)
        model.step = lambda mode: [(STATUS, mode)]
        self.assertEqual(model.advance_frame(self.state(3), self.state(0, 0, 0)),
                         [(STATUS, 3)])
        self.assertEqual(bytes(model.ram), before)

    def test_area_initialization_preserves_queued_music_until_next_sound_pass(self):
        model = self.model()
        before = bytes(model.ram)
        self.assertEqual(model.advance_frame(self.state(1), self.state(1, 1, 0)), [])
        self.assertEqual(bytes(model.ram), before)

    def test_new_game_requires_a_title_to_world_one_setup_transition(self):
        title = bytes(2048)
        game = bytearray(title)
        game[0x770] = 1
        self.assertTrue(is_new_game_transition(title, game))
        self.assertFalse(is_new_game_transition(None, game))
        self.assertFalse(is_new_game_transition(game, game))
        self.assertFalse(is_new_game_transition(title, title))
        game[0x75F] = 1
        self.assertFalse(is_new_game_transition(title, game))
        game[0x75F] = 0
        game[0x772] = 3
        self.assertFalse(is_new_game_transition(title, game))


if __name__ == "__main__":
    unittest.main()
