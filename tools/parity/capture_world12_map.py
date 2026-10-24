"""Capture the ROM area parser's metatile columns (offline evidence, not gameplay)."""
from __future__ import annotations
import argparse
import json
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from common import tool_path, sha256_file
from run_reference import build_origin_lua, EXPECTED_ROM_SHA256

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rom', type=Path, default=ROOT/'roms/Super Mario Bros. (World).nes')
    parser.add_argument('--output', type=Path, default=ROOT/'local-parity/world12-map')
    parser.add_argument('--area', choices=['underground','bonus'], default='underground')
    args = parser.parse_args()
    if sha256_file(args.rom) != EXPECTED_ROM_SHA256:
        parser.error('unverified ROM')
    raw = args.rom.read_bytes()[16:32784]
    # RenderAreaGraphics entry, verified against SMBDIS. Execute callback reads
    # the complete MetatileBuffer before either 8px half-column is emitted.
    signature = bytes.fromhex('ad260729018505ac40038400ad2107')
    offset = raw.index(signature)
    if raw.count(signature) != 1:
        raise RuntimeError('RenderAreaGraphics signature not unique')
    out = args.output.resolve(); out.mkdir(parents=True, exist_ok=True)
    lua = build_origin_lua(2) + f'''
local columns = {{}}
local path = {json.dumps(str(out/'columns.jsonl').replace(chr(92),'/'))}
local file = assert(io.open(path, "wb"))
emu.addMemoryCallback(function()
  if emu.read(0x0750,emu.memType.nesInternalRam) ~= 0xc0 then return end
  local x=emu.read(0x0725,emu.memType.nesInternalRam)*16+emu.read(0x0726,emu.memType.nesInternalRam)
  if columns[x] then return end
  columns[x]=true
  local values={{}}
  for row=0,12 do values[#values+1]=tostring(emu.read(0x06a1+row,emu.memType.nesInternalRam)) end
  file:write('{{"x":'..x..',"tiles":['..table.concat(values,",")..']}}\\n')
  file:flush()
end,emu.callbackType.exec,{offset+0x8000}, {offset+0x8000},emu.cpuType.nes)
'''
    if args.area == 'bonus':
        lua=lua.replace('0xc0','0xc2')
    # Initialize each page with the ROM's own backloading path. This captures
    # untouched geometry without gameplay actors bumping blocks or hitting a
    # scroll lock. The same stream parser reconstructs preceding attributes.
    def capture(page: int) -> dict:
        folder=out/f'page-{page}'; folder.mkdir(parents=True,exist_ok=True)
        text=lua.replace(str(out/'columns.jsonl').replace(chr(92),'/'),str(folder/'columns.jsonl').replace(chr(92),'/'))
        text=text.replace('emu.write(0x075b, 0,','emu.write(0x075b, '+str(page)+',')
        script=folder/'capture.lua';script.write_text(text,encoding='utf-8')
        result=subprocess.run([str(tool_path('mesen')),str(args.rom.resolve()),'--frames','180',
            '--home',str(folder/'home'),'--input','0:start@40-46','--lua',str(script),'--lua-allow-io',
            '--timeout','120'],capture_output=True,text=True,encoding='utf-8')
        (folder/'stdout.log').write_text(result.stdout,encoding='utf-8')
        if result.returncode: raise RuntimeError(result.stderr+result.stdout)
        return {v['x']:v['tiles'] for v in map(json.loads,(folder/'columns.jsonl').read_text().splitlines())}
    columns={}
    with ThreadPoolExecutor(max_workers=4) as pool:
        for result in pool.map(capture,[2] if args.area=='bonus' else range(0,13)):
            for x,tiles in result.items():
                if x in columns and columns[x] != tiles:
                    raise RuntimeError(f'Backloading produced conflicting column {x}')
                columns.setdefault(x,tiles)
    print('columns', len(columns), 'range', min(columns,default=0), max(columns,default=0))
    first=32 if args.area=='bonus' else 0
    width=17 if args.area=='bonus' else 208
    if not all(x in columns for x in range(first,first+width)):
        raise RuntimeError('ROM parser did not emit the complete map')
    dest=ROOT/('scripts/generated/world12_bonus_map.nut' if args.area=='bonus' else 'scripts/generated/world12_map.nut')
    symbol='ROM_WORLD_1_2_BONUS_METATILES' if args.area=='bonus' else 'ROM_WORLD_1_2_METATILES'
    dest.write_text('// ROM RenderAreaGraphics metatile output; regenerate with capture_world12_map.py.\n'
        +symbol+' <- [\n'+',\n'.join('['+','.join(map(str,columns[x]))+']' for x in range(first,first+width))+'\n];\n',encoding='utf-8')
    print(dest)


if __name__=='__main__': main()
