"""Fast original-ROM route diagnostic from the verified normal origin; no screenshots or route state writes."""
import argparse,json,subprocess
from pathlib import Path
from common import load_movie,mesen_section_input_arguments,tool_path,sha256_file
from world24_capture_lock import world24_capture_lock
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('--movie',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
 p.add_argument('--origin',type=Path,default=ROOT/'local-parity/world24-entrance-reference/origin.mss')
 a=p.parse_args();m=load_movie(a.movie);out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
 lua=r'''local f=0
local file=assert(io.open(PATH,"wb"))
emu.addEventCallback(function()
 local ram=emu.memType.nesInternalRam
 local bytes={}
 for a=0,2047 do bytes[#bytes+1]=string.format("%02x",emu.read(a,ram)) end
 file:write(string.format('{"frame":%d,"ram_hex":"%s"}\n',f,table.concat(bytes)))
 file:flush();f=f+1
end,emu.eventType.endFrame)
'''.replace('PATH',json.dumps(str(out/'ram-trace.jsonl').replace(chr(92),'/')))
 script=out/'probe.lua';script.write_text(lua, newline="\n")
 cmd=[str(tool_path('mesen')),str(ROOT/'roms/Super Mario Bros. (World).nes'),'--load-state',str(a.origin.resolve()),'--home',str(out/'home'),'--frames',str(m['frames']),'--timeout','120','--lua',str(script),'--lua-allow-io']+mesen_section_input_arguments(m.get('inputs',[]))
 with world24_capture_lock():r=subprocess.run(cmd,capture_output=True,text=True,timeout=150)
 (out/'engine.log').write_text(r.stdout+'\n'+r.stderr, newline="\n")
 if r.returncode:raise RuntimeError('Mesen failed')
 rows=[bytes.fromhex(json.loads(l)['ram_hex']) for l in (out/'ram-trace.jsonl').read_text().splitlines()]
 result=dict(frames=len(rows),movie_sha256=sha256_file(a.movie),origin_sha256=sha256_file(a.origin),
  death=next((i for i,r in enumerate(rows) if r[0xe]==11 or r[0x75a]!=2),None),
  axe=next((i for i,r in enumerate(rows) if r[0x770]==2),None),
  next_world=next((i for i,r in enumerate(rows) if r[0x75f]==2),None))
 (out/'summary.json').write_text(json.dumps(result,indent=2)+'\n', newline="\n");print(json.dumps(result))
 for i in range(700,min(len(rows),1201),25):
  r=rows[i];print(i,r[0x6d]*256+r[0x86],r[0xce],r[0x1d],r[0xe],r[0x75a])
if __name__=='__main__':main()
