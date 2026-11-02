"""Fast World 2-1 state diagnostic. Does not validate rendered frames or device audio."""
from __future__ import annotations
import argparse
import json
import subprocess
from pathlib import Path
from common import expand_input_masks, load_movie, tool_path

ROOT=Path(__file__).resolve().parents[2]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--movie',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    movie=load_movie(args.movie)
    if (movie.get('world',1),movie.get('level',1))!=(2,1):
        parser.error('only World 2-1 origins are supported')
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    source=out/'replay.nut'
    source.write_text("""eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("main.nut");loadTexture=function(path) {return path;};loadAssets();loadWorld13Assets();loadWorld14Assets();loadWorld21Assets();PARITY_MOVIE_ENABLED=false;
local g=createGame();startLevel(g,2,1);initializeWorld21Parity(g);
"""+f'if({movie.get("checkpoint_page",0)}>0) initializeWorld21Checkpoint(g,{movie.get("checkpoint_page",0)},(g.nesFrameCounter+255)&255);\n'+
        'parityInitialize(g);g.player.parityOriginFriction=true;\nlocal masks='+json.dumps(expand_input_masks(movie))+';\n'+r"""
for(local f=0;f<masks.len();f+=1) {
    g.parity.frame=f;g.parity.inputMask=masks[f];parityApplyMask(g,masks[f]);
    if(f==0) g.nesFrameCounter=(g.nesFrameCounter+1)&255;
    else simulateFixed(g,FIXED_DT);
    g.input.jumpQueued=false;g.input.fireQueued=false;g.input.resetQueued=false;
    print("STATE "+parityStateJson(g,f)+"\n");
}
print("SIMULATION_COMPLETE\n");
""",encoding='utf-8')
    result=subprocess.run([str(tool_path('eve')),'run','--no-window','-r',str(source)],cwd=ROOT,capture_output=True,text=True,timeout=90)
    (out/'engine.log').write_text(result.stdout+'\n'+result.stderr,encoding='utf-8')
    rows=[line[6:] for line in result.stdout.splitlines() if line.startswith('STATE ')]
    if result.returncode or len(rows)!=movie['frames'] or 'SIMULATION_COMPLETE' not in result.stdout:
        raise RuntimeError('simulation failed; inspect '+str(out/'engine.log'))
    (out/'state.jsonl').write_text('\n'.join(rows)+'\n',encoding='utf-8')
    print(f'{len(rows)} simulation states: {out}; image/device-audio acceptance not checked')

if __name__=='__main__':
    main()
