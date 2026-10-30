import hashlib
import json
import re
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


class CapturedBranchMapTest(unittest.TestCase):
    def test_committed_entry_maps_match_manifest_and_room_geometry(self):
        root = Path(__file__).resolve().parents[2]
        data = (root / "scripts/generated/world21_branch_maps.nut").read_bytes()
        manifest = json.loads((root / "assets/world21/branch-maps-manifest.json").read_text())
        self.assertEqual(hashlib.sha256(data).hexdigest(), manifest["output_sha256"])
        self.assertFalse(manifest["runtime_connected"])
        maps = {}
        for name, payload in re.findall(r"ROM_WORLD_2_1_(\w+) <- (\[.*?\]);", data.decode(), re.S):
            maps[name] = json.loads(payload)
        for name, width in [("SKY", 48), ("UNDERGROUND", 16)]:
            for kind in ["METATILES", "BLOCKS"]:
                self.assertEqual(len(maps[name+"_"+kind]), width)
                self.assertTrue(all(len(column)==13 for column in maps[name+"_"+kind]))
        underground = maps["UNDERGROUND_METATILES"]
        self.assertEqual(sum(column.count(0xc2) for column in underground), 19)
        self.assertEqual(underground[13][9:11], [0x1c, 0x1f])
        self.assertEqual(underground[15][9:11], [0x1e, 0x21])


if __name__ == "__main__":
    unittest.main()
