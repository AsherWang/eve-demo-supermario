"""Fast World 2-2 state diagnostic. Does not validate rendered frames or device audio."""
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
    parser.add_argument('--reference',type=Path,help='Decoded reference state.jsonl; compare player motion only')
    args=parser.parse_args()
    movie=load_movie(args.movie)
    if (movie.get('world',1),movie.get('level',1))!=(2,2):
        parser.error('only World 2-2 origins are supported')
    if movie.get('checkpoint_page',0): parser.error('only water-origin probe supported')
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    source=out/'replay.nut'
    source.write_text("""eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("main.nut");loadTexture=function(path) {return path;};loadAssets();loadWorld13Assets();loadWorld14Assets();loadWorld21Assets();loadWorld22Assets();PARITY_MOVIE_ENABLED=false;
local g=createGame();initializeWorld22SwimProbe(g);
"""+
        'parityInitialize(g);g.player.parityOriginFriction=false;\nlocal masks='+json.dumps(expand_input_masks(movie))+';\n'+r"""
for(local f=0;f<masks.len();f+=1) {
    g.parity.frame=f;g.parity.inputMask=masks[f];parityApplyMask(g,masks[f]);
    if(f>0) simulateFixed(g,FIXED_DT);
    g.input.jumpQueued=false;g.input.fireQueued=false;g.input.resetQueued=false;
    print("STATE "+parityStateJson(g,f)+"\n");
    local actors="[";
    for(local slot=0;slot<5;slot+=1) {
        if(slot>0) actors+=",";
        local e=g.world22.enemies[slot];
        if(e==null) actors+="null";
        else if(e.kind=="blooper") actors+="[7,"+e.x+","+e.y+","+e.speed+","+e.force+","+e.phase+","+e.timer+","+e.direction+"]";
        else actors+="["+e.id+","+e.x+","+e.y+","+e.xForce+","+e.fishDummy+","+e.fishDirection+","+e.originY+"]";
    }
    print("ACTORS "+actors+"]\n");
}
print("SIMULATION_COMPLETE\n");
""",encoding='utf-8')
    result=subprocess.run([str(tool_path('eve')),'run','--no-window','-r',str(source)],cwd=ROOT,capture_output=True,text=True,timeout=90)
    (out/'engine.log').write_text(result.stdout+'\n'+result.stderr,encoding='utf-8')
    actor_rows=[line[7:] for line in result.stdout.splitlines() if line.startswith('ACTORS ')]
    (out/'actors.jsonl').write_text('\n'.join(actor_rows)+'\n',encoding='utf-8')
    rows=[line[6:] for line in result.stdout.splitlines() if line.startswith('STATE ')]
    if result.returncode or len(rows)!=movie['frames'] or 'SIMULATION_COMPLETE' not in result.stdout:
        raise RuntimeError('simulation failed; inspect '+str(out/'engine.log'))
    (out/'state.jsonl').write_text('\n'.join(rows)+'\n',encoding='utf-8')
    if args.reference:
        expected=[json.loads(line) for line in args.reference.read_text(encoding='utf-8').splitlines()]
        actual=list(map(json.loads,rows))
        keys=['x','y','x_speed_raw','y_speed_raw','y_move_force','y_move_dummy',
              'x_position_fraction','x_acceleration_fraction','grounded',
              'facing_direction_raw','moving_direction_raw']
        differences=[]
        for f,(ref,act) in enumerate(zip(expected,actual)):
            for key in keys:
                if ref['player'][key]!=act['player'][key]:
                    differences.append(dict(frame=f,field='player.'+key,
                        expected=ref['player'][key],actual=act['player'][key]))
            if ref['camera_x']!=act['camera_x']:
                differences.append(dict(frame=f,field='camera_x',expected=ref['camera_x'],actual=act['camera_x']))
        report=dict(passed=not differences and len(expected)==len(actual),frames=len(actual),
            expected_frames=len(expected),scope='selected player motion and camera only; no enemies, image or audio comparison',
            fields=keys+['camera_x'],difference_count=len(differences),first_differences=differences[:30])
        (out/'motion-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        if not report['passed']:
            raise RuntimeError('motion differs; inspect '+str(out/'motion-report.json'))
    print(f'{len(rows)} simulation states: {out}; image/device-audio acceptance not checked')

if __name__=='__main__':
    main()
