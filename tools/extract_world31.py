"""Extract the next-world entry assets required by the World 2-4 clear route.
World 3-1 whole-course mechanics/branches are not accepted by this extraction.
"""
from pathlib import Path
import hashlib,json
from extract_smb_assets import METATILE_COUNTS,compose_metatile,find_once
ROOT=Path(__file__).resolve().parents[1]
def main():
 raw=(ROOT/'roms/Super Mario Bros. (World).nes').read_bytes()
 assert hashlib.sha256(raw).hexdigest()=='f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de'
 prg,chr_data=raw[16:32784],raw[32784:40976]
 ground=find_once(prg,bytes.fromhex('3f00200f291a0f0f36170f0f30210f0f27170f'),'ground palette')
 snow=find_once(prg,bytes.fromhex('3f00040f30001000'),'snow palette')
 palette=list(prg[ground+3:ground+35]);palette[:4]=prg[snow+3:snow+7]
 graphics=find_once(prg,bytes.fromhex('242424242727272724242435'),'MetatileGraphics')
 out=ROOT/'assets/world31';out.mkdir(parents=True,exist_ok=True)
 cursor=graphics
 for group,count in enumerate(METATILE_COUNTS):
  for i in range(count):
   compose_metatile(chr_data,prg[cursor+i*4:cursor+i*4+4],palette[group*4:group*4+4]).save(out/f'metatile-{group*64+i}.png')
  cursor+=count*4
 lines=['// Verified ROM streams; next-world entry dependency, not whole-level acceptance.']
 for name,address,length in [('AREA',0xa619,117),('ENEMIES',0x9ed0,49)]:
  data=prg[address-0x8000:address-0x8000+length]
  assert data[-1]==(253 if name=='AREA' else 255)
  lines.append('ROM_WORLD_3_1_'+name+' <- ['+','.join(map(str,data))+'];')
 (ROOT/'scripts/generated/world31_data.nut').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
 (out/'manifest.json').write_text(json.dumps(dict(rom_sha256=hashlib.sha256(raw).hexdigest(),scope='World 3-1 map/entry; complete stage acceptance pending',palette=palette),indent=2)+'\n',encoding='utf-8')
if __name__=='__main__':main()
