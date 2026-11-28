"""Stage 2-4 ROM provenance and fixture integrity; not whole-level acceptance."""
import hashlib,json,re,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
sys.path.insert(0,str(ROOT/'tools/parity'))
from extract_world14 import EXPECTED_ROM_SHA256,locate_area_stream,find_once,ENEMY_SIGNATURE,stream
from world24_reference import build_world24_origin_lua

def data(name):
    text=(ROOT/'scripts/generated/world24_data.nut').read_text()
    return bytes(map(int,re.search(r'ROM_WORLD_2_4_'+name+r' <- \[(.*?)\]',text)[1].split(',')))

class World24DataTests(unittest.TestCase):
    def test_rom_identity_and_streams(self):
        raw=(ROOT/'roms/Super Mario Bros. (World).nes').read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(),EXPECTED_ROM_SHA256)
        prg=raw[16:32784]
        self.assertEqual(data('AREA'),stream(prg,locate_area_stream(prg)+0xe0))
        self.assertEqual(data('ENEMY'),stream(prg,find_once(prg,ENEMY_SIGNATURE,'E_CastleArea1')+0x40,255))
        self.assertEqual((len(data('AREA')),len(data('ENEMY'))),(115,47))
    def test_manifest_stage_identity(self):
        m=json.loads((ROOT/'assets/world24/manifest.json').read_text())
        self.assertEqual(m['levels'],['2-4']);self.assertEqual(m['area_pointer'],'0x62')
        self.assertEqual(m['streams']['AREA']['cpu_address'],'0xa28f')
        self.assertEqual(m['streams']['ENEMY']['cpu_address'],'0x9db0')
    def test_normal_enemy_inventory(self):
        e=data('ENEMY');ids=[e[i+1]&63 for i in range(0,len(e)-1,2) if not e[i+1]&64]
        self.assertEqual(ids.count(12),2)
        self.assertEqual(sum(ids.count(i) for i in range(27,32)),6)
        for ident in [0x2b,0x2c,0x28,0x15,0x2d,0x35]:self.assertEqual(ids.count(ident),1)
    def test_origin_selects_world_two_castle_three(self):
        s=build_world24_origin_lua()
        self.assertIn('emu.write(0x075f, 1,',s)
        self.assertIn('emu.write(0x0750, 98,',s)
        self.assertIn('emu.write(0x075c, 3,',s)
        self.assertIn('emu.write(0x0760, 4,',s)
        self.assertIn('not selected',s)
        with self.assertRaises(ValueError):build_world24_origin_lua(6)
    def test_endpoint_and_death_identity(self):
        s=(ROOT/'scripts/world24.nut').read_text()
        self.assertNotIn('startLevel(g,2,1)',s)
        self.assertNotIn('g.world=1;',s)
        self.assertIn('beginWorld31Load(g);',s)
        self.assertIn('g.checkpointPage=0;g.lives-=1;',s)

if __name__=='__main__':unittest.main()
