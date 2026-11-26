import hashlib
import json
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from extract_world22 import read_stream, enemy_commands, extract


class World22DataTests(unittest.TestCase):
    def test_command_boundaries(self):
        self.assertEqual(read_stream(bytes([0,0,0x11,0xfd,0xfd]),0,False),
                         bytes([0,0,0x11,0xfd,0xfd]))
        self.assertEqual(read_stream(bytes([0x0e,0xff,0xff,0xff]),0,True),
                         bytes([0x0e,0xff,0xff,0xff]))
        for data in [b"", bytes([0x0e,1]), bytes([0x11,2])]:
            with self.assertRaises(ValueError):
                read_stream(data,0,True)

    def test_enemy_page_and_world_filters(self):
        records = enemy_commands(bytes([0x0f,1,0x2e,0x25,0x2b,0x67,0xc7,0xff]))
        self.assertEqual(records[0], dict(offset=2,column=18,row=14,kind="area_link",
            destination=0x25,world=2,entrance_page=11))
        self.assertEqual(records[1]["column"],38)
        self.assertEqual(records[1]["enemy_id"],7)
        self.assertTrue(records[1]["hard_only"])
        with self.assertRaises(ValueError):
            enemy_commands(bytes([0x0e,0x25]))

    def test_water_map_completeness_and_asset_coverage(self):
        manifest = json.loads((ROOT/"assets/world22/map-manifest.json").read_text())
        path = ROOT/manifest["output"]
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),manifest["output_sha256"])
        self.assertEqual((manifest["world"],manifest["stage"],manifest["area_pointer"]),(2,2,1))
        source = path.read_text()
        for key in ["METATILES","BLOCKS"]:
            columns = json.loads(re.search(key+r" <- (\[.*?\]);",source,re.S)[1])
            self.assertEqual(len(columns),208)
            self.assertTrue(all(len(column)==13 for column in columns))
            if key == "METATILES":
                for tile in {t for column in columns for t in column}:
                    self.assertTrue((ROOT/f"assets/world22/metatile-{tile}.png").is_file())
        self.assertEqual(manifest["tail_overlap_columns"],list(range(194,200)))
        self.assertFalse(manifest["runtime_implemented"])

    def test_committed_motion_fixture_provenance(self):
        manifest=json.loads((ROOT/'tests/fixtures/world22_motion.json').read_text())
        fixture=ROOT/'tests/fixtures/world22_motion.nut'
        self.assertEqual(hashlib.sha256(fixture.read_bytes()).hexdigest(),manifest['fixture_sha256'])
        self.assertEqual(sum(c['frames'] for c in manifest['cases']),1800)
        rows=json.loads(fixture.read_text().split(' <- ',1)[1].rstrip().removesuffix(';'))
        self.assertEqual(len(rows),len(manifest['cases']))
        for case,frames in zip(manifest['cases'],rows):
            movie=ROOT/case['movie']
            self.assertEqual(hashlib.sha256(movie.read_bytes()).hexdigest(),case['movie_sha256'])
            self.assertEqual(len(frames),case['frames'])
            self.assertTrue(all(len(row)==len(manifest['fields']) for row in frames))

    def test_reference_support_does_not_enable_unimplemented_runtime(self):
        sys.path.insert(0, str(ROOT / "tools/parity"))
        from common import require_supported_stage
        from run_reference import build_movie_origin_lua
        movie = dict(world=2,level=2)
        with self.assertRaises(ValueError):
            require_supported_stage(movie)
        lua = build_movie_origin_lua(movie)
        self.assertIn("0x0760,2,ram",lua)
        self.assertIn("world=2 level=2",lua)
        self.assertIn("0x00e7,ram)==0x47",lua)
        self.assertIn("world=2 level=1",build_movie_origin_lua(dict(world=2,level=1)))
        with self.assertRaises(ValueError):
            build_movie_origin_lua(dict(world=2,level=3))

    def test_unverified_rom_rejected(self):
        with self.assertRaisesRegex(ValueError,"unverified ROM"):
            extract(bytes(40976))

    def test_committed_streams_and_assets_match_manifest(self):
        manifest = json.loads((ROOT/"assets/world22/manifest.json").read_text())
        source = (ROOT/"scripts/generated/world22_data.nut").read_text()
        streams = {k: bytes(map(int,v.split(","))) for k,v in
                   re.findall(r"ROM_WORLD_2_2_(\w+) <- \[(.*?)\];",source)}
        self.assertEqual(len(streams),6)
        for area,record in manifest["areas"].items():
            for kind,meta in record["streams"].items():
                data = streams[area.upper()+"_"+kind]
                self.assertEqual(len(data),meta["length"])
                self.assertEqual(hashlib.sha256(data).hexdigest(),meta["sha256"])
            self.assertEqual(enemy_commands(streams[area.upper()+"_ENEMIES"]),record["enemy_commands"])
        self.assertEqual((manifest["exit"]["destination"],manifest["exit"]["entrance_page"]),(0x25,11))
        self.assertEqual(manifest["checkpoint_page"],5)
        for asset in manifest["assets"]["files"]:
            self.assertEqual(hashlib.sha256((ROOT/"assets/world22"/asset["path"]).read_bytes()).hexdigest(),asset["sha256"])


if __name__ == "__main__":
    unittest.main()
