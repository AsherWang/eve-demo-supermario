import hashlib
import json
from pathlib import Path
import re
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/parity'))
from world23_reference import build_world23_origin_lua

class World23DataTests(unittest.TestCase):
    def test_stream_provenance(self):
        manifest=json.loads((ROOT/'assets/world23/manifest.json').read_text())
        source=(ROOT/'scripts/generated/world23_data.nut').read_text()
        for name,record in manifest['streams'].items():
            data=bytes(json.loads(re.search('ROM_WORLD_2_3_'+name+r' <- (\[.*?\]);',source,re.S)[1]))
            self.assertEqual(len(data),record['length'])
            self.assertEqual(hashlib.sha256(data).hexdigest(),record['sha256'])
        self.assertEqual(manifest['streams']['AREA']['cpu_address'],'0xa748')
        self.assertEqual(manifest['streams']['ENEMIES']['cpu_address'],'0x9f3c')
        self.assertEqual(manifest['streams']['AREA']['length'],133)
        self.assertEqual(manifest['streams']['ENEMIES']['length'],21)

    def test_map_and_assets(self):
        manifest=json.loads((ROOT/'assets/world23/map-manifest.json').read_text())
        path=ROOT/manifest['output']
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),manifest['output_sha256'])
        self.assertEqual((manifest['world'],manifest['stage'],manifest['area_pointer']),(2,3,0x27))
        source=path.read_text()
        for name in ['METATILES','BLOCKS']:
            columns=json.loads(re.search(name+r' <- (\[.*?\]);',source,re.S)[1])
            self.assertEqual(len(columns),244)
            self.assertTrue(all(len(c)==13 for c in columns))
            if name=='METATILES':
                for meta in {v for c in columns for v in c}:
                    self.assertTrue((ROOT/f'assets/world23/metatile-{meta}.png').is_file())
                self.assertIn(0x24,columns[225])

    def test_defeated_fish_tile_rows(self):
        from PIL import Image
        for name in ['fish-0-left','fish-0-right','green-fish-0']:
            live=Image.open(ROOT/'assets/world23'/f'{name}.png').convert('RGBA')
            dead=Image.open(ROOT/'assets/world23'/f'{name}-dead.png').convert('RGBA')
            self.assertEqual(dead.crop((0,0,16,8)).getbbox(), None)
            self.assertEqual(dead.crop((0,8,16,24)).tobytes(),
                             live.crop((0,8,16,24)).transpose(Image.Transpose.FLIP_TOP_BOTTOM).tobytes())

    def test_capture_lock_preserves_other_owner(self):
        import tempfile
        from unittest.mock import patch
        from world23_capture_lock import capture_lock
        with tempfile.TemporaryDirectory() as folder:
            lock=Path(folder)/'capture.lock'
            with patch('world23_capture_lock.lock_directory',return_value=lock):
                with capture_lock('first',wait_seconds=0):
                    owner=(lock/'owner.json').read_bytes()
                    with self.assertRaises(RuntimeError):
                        with capture_lock('second',wait_seconds=0):
                            self.fail('contended capture acquired')
                    self.assertEqual((lock/'owner.json').read_bytes(),owner)
                self.assertFalse(lock.exists())

    def test_origin_identity(self):
        source=build_world23_origin_lua()
        for text in ['0x075f,1,ram','0x075c,2,ram','0x0760,3,ram','0x0750,0x27,ram',
                     '0x00e7,ram)==0x4a','0x00e8,ram)==0xa7','world=2 level=3']:
            self.assertIn(text,source)
        with self.assertRaises(ValueError): build_world23_origin_lua(15)

    def test_motion_fixture_provenance(self):
        record=json.loads((ROOT/'tests/fixtures/world23_fish_motion.json').read_text())
        fixture=ROOT/'tests/fixtures/world23_fish_motion.nut'
        self.assertEqual(hashlib.sha256(fixture.read_bytes()).hexdigest(),record['fixture_sha256'])
        self.assertEqual(hashlib.sha256((ROOT/record['movie']).read_bytes()).hexdigest(),record['movie_sha256'])
        self.assertEqual(record['pairs'],2727)
        self.assertGreater(record['spawns'],5)

    def test_full_capture_preserves_successful_inputs(self):
        from common import load_movie, expand_input_masks
        movies=ROOT/'tests/parity/movies'
        historical=load_movie(movies/'world-2-3-original-clear-candidate.json')
        strict=load_movie(movies/'world-2-3-strict-clear.json')
        self.assertEqual(strict['frames'],2132)
        self.assertNotIn('capture_frames',strict)
        self.assertEqual(expand_input_masks(strict),expand_input_masks(historical))
        normal=load_movie(movies/'world-2-3-normal-clear.json')
        extended=load_movie(movies/'world-2-3-normal-load-clear.json')
        masks=expand_input_masks(extended)
        self.assertEqual(masks[:normal['frames']],expand_input_masks(normal))
        self.assertEqual(masks[normal['frames']:],[0]*180)

    def test_successful_original_movie_provenance(self):
        record=json.loads((ROOT/'tests/fixtures/world23_route_evidence.json').read_text())
        movie=ROOT/record['movie']
        self.assertEqual(hashlib.sha256(movie.read_bytes()).hexdigest(),record['movie_sha256'])
        self.assertTrue(record['reference']['successful_normal_route'])
        self.assertEqual(record['reference']['minimum_lives'],3)
        self.assertEqual(record['reference']['transition_frame'],2103)
        self.assertEqual(record['fish_registers']['mismatched_slots'],0)
        self.assertFalse(record['strict_parity_accepted'])

if __name__=='__main__': unittest.main()
