"""Extract verified World 2-1 streams and item/area-link inventory offline."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from extract_smb_assets import decode_world_1_1_blocks, find_once

ROOT=Path(__file__).resolve().parents[1]
EXPECTED='f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de'

def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rom',type=Path,default=ROOT/'roms/Super Mario Bros. (World).nes')
    args=parser.parse_args()
    raw=args.rom.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=EXPECTED: parser.error('unverified ROM')
    prg=raw[16:32784]
    records={};data={}
    for name,signature,end,label in [
        ('AREA','52310f206e40f72007841720',0xfd,'L_GroundArea9'),
        ('ENEMIES','85860b801b00db377780eb37',0xff,'E_GroundArea9')]:
        start=find_once(prg,bytes.fromhex(signature),label)
        stream=prg[start:prg.index(bytes([end]),start)+1]
        data[name]=stream
        records[name]=dict(label=label,cpu_address=hex(0x8000+start),length=len(stream),
            sha256=hashlib.sha256(stream).hexdigest())
    page=0;flag_column=None
    for offset in range(2,len(data['AREA'])-1,2):
        first,second=data['AREA'][offset:offset+2]
        if second&0x80: page+=1
        if first&15==13 and not second&0x40: page=second&31;continue
        if first&15==13 and second&0x7f==0x41: flag_column=page*16+(first>>4)
    if flag_column!=200: raise RuntimeError('unexpected World 2-1 goal column')
    links=[];cursor=0
    while cursor<len(data['ENEMIES'])-1:
        first,second=data['ENEMIES'][cursor:cursor+2]
        if first&15==14:
            links.append(dict(offset=cursor,raw=list(data['ENEMIES'][cursor:cursor+3])))
            cursor+=3
        else: cursor+=2
    dest=ROOT/'scripts/generated/world21_data.nut'
    dest.write_text('// Offline World 2-1 data; runtime loading not implemented yet.\n'+
        '\n'.join('ROM_WORLD_2_1_'+key+' <- ['+','.join(map(str,value))+'];'
            for key,value in data.items())+'\n',encoding='utf-8')
    manifest=dict(schema='smb-world21-data-v1',rom_sha256=EXPECTED,area_pointer=0x28,
        streams=records,flag_column=flag_column,items=decode_world_1_1_blocks(data['AREA']),
        area_links=links,runtime_implemented=False)
    out=ROOT/'assets/world21';out.mkdir(parents=True,exist_ok=True)
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(manifest))

if __name__=='__main__': main()
