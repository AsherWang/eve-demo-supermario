import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from extract_world21_branches import links, stream


class BranchStreamTest(unittest.TestCase):
    def test_shared_room_selects_only_matching_world_return(self):
        data = bytes([0x0e, 0x25, 0x0a, 0x2e, 0x28, 0x27, 0xff])
        self.assertEqual(links(data, 2), [dict(offset=3, column=2,
                                              destination=0x28, entrance_page=7)])
        self.assertEqual(links(data, 3), [])

    def test_page_command_and_entrance_bitfields(self):
        self.assertEqual(links(bytes([0x0f, 3, 0x2e, 0x28, 0x2a, 0xff]), 2),
                         [dict(offset=2, column=50, destination=0x28, entrance_page=10)])
        with self.assertRaises(ValueError):
            links(bytes([0x0e, 0x28]), 2)

    def test_pointer_table_and_command_boundaries(self):
        prg = bytearray(1024)
        prg[0:4] = bytes.fromhex("1f061c00")
        prg[100:104] = bytes.fromhex("0003191c")
        # Ground area 12: enemy index 6+11, object index 3+11.
        for table, index, address in [(0, 17, 0x8200), (100, 14, 0x8300)]:
            prg[table+4+index] = address & 255
            prg[table+38+index] = address >> 8
        # A terminator-valued operand must not terminate a stream.
        prg[512:518] = bytes([0x1b, 0xff, 0x0e, 0x28, 0x2a, 0xff])
        prg[768:773] = bytes([0, 0, 0x10, 0xfd, 0xfd])
        self.assertEqual(stream(prg, 0x2b, True),
                         (0x8200, bytes([0x1b, 0xff, 0x0e, 0x28, 0x2a, 0xff])))
        self.assertEqual(stream(prg, 0x2b, False),
                         (0x8300, bytes([0, 0, 0x10, 0xfd, 0xfd])))


if __name__ == "__main__":
    unittest.main()
