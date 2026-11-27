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

    def test_origin_identity(self):
        source=build_world23_origin_lua()
        for text in ['0x075f,1,ram','0x075c,2,ram','0x0760,3,ram','0x0750,0x27,ram',
                     '0x00e7,ram)==0x4a','0x00e8,ram)==0xa7','world=2 level=3']:
            self.assertIn(text,source)
        with self.assertRaises(ValueError): build_world23_origin_lua(15)

if __name__=='__main__': unittest.main()
