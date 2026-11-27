"""Replay fixed inputs through the real simulation; no route-time state patches.

This CPU diagnostic proves playability only, never frame/APU/audio acceptance.
"""
from pathlib import Path
import argparse
import json
import subprocess
from common import load_movie, expand_input_masks, sha256_file, tool_path

ROOT = Path(__file__).resolve().parents[2]

def run(movie_path, output, reference_origin=False):
    movie = load_movie(movie_path)
    if (movie.get('world'), movie.get('level')) != (2, 3):
        raise ValueError('World 2-3 movie required')
    output.mkdir(parents=True, exist_ok=True)
    source = output / 'replay.nut'
    source.write_text('''eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("main.nut");loadTexture=function(path) {return path;};loadAssets();PARITY_MOVIE_ENABLED=false;
dofile("tools/regression/world23_hooks.nut");loadWorld23Assets();
local g=createGame();initializeWorld23Diagnostic(g);
'''+('initializeWorld23Parity(g);g.player.parityOriginFriction=true;\n' if reference_origin else '')+'''
local referenceOrigin='''+('true' if reference_origin else 'false')+''';
local masks='''+json.dumps(expand_input_masks(movie))+''';
for(local f=0;f<masks.len();f+=1) {
    g.parity.frame=f;g.parity.inputMask=masks[f];parityApplyMask(g,masks[f]);
    if(referenceOrigin && f==0) g.nesFrameCounter=(g.nesFrameCounter+1)&255;
    else simulateFixed(g,FIXED_DT);
    g.input.jumpQueued=false;g.input.fireQueued=false;g.input.resetQueued=false;
    print("STATE "+parityStateJson(g,f)+"\\n");
    print("FISH "+world23ActorRegistersJson(g)+"\\n");
    print("FISH_TIMER "+g.world23.timer+"\\n");
    print("ROUTE "+f+" "+g.player.x+" "+g.player.y+" "+g.state+" "+g.lives+" "+g.world23.spawned+"\\n");
}
print("SIMULATION_COMPLETE\\n");
''', encoding='utf-8', newline='\n')
    result = subprocess.run([str(tool_path('eve')), 'run', '--no-window', '-r', str(source.resolve())],
                            cwd=ROOT, capture_output=True, text=True, timeout=120)
    (output/'engine.log').write_text(result.stdout+'\n'+result.stderr, encoding='utf-8', newline='\n')
    states = [json.loads(line[6:]) for line in result.stdout.splitlines() if line.startswith('STATE ')]
    routes = [line.split()[1:] for line in result.stdout.splitlines() if line.startswith('ROUTE ')]
    fish = [line[5:] for line in result.stdout.splitlines() if line.startswith('FISH ')]
    (output/'fish.jsonl').write_text('\n'.join(fish)+'\n',encoding='utf-8',newline='\n')
    if result.returncode or len(states)!=movie['frames'] or 'SIMULATION_COMPLETE' not in result.stdout:
        raise RuntimeError('Replay failed: '+str(output/'engine.log'))
    (output/'state.jsonl').write_text(''.join(json.dumps(s)+'\n' for s in states), encoding='utf-8', newline='\n')
    complete = next((int(r[0]) for r in routes if r[3]=='levelComplete'), None)
    flag = next((int(r[0]) for r in routes if r[3]=='endLevel'), None)
    lives = min(int(r[4]) for r in routes)
    report = dict(movie_sha256=sha256_file(movie_path),frames=len(states),entrance_x=float(routes[0][1]),
                  flag_frame=flag,settlement_frame=complete,minimum_lives=lives,fish_spawned=int(routes[-1][5]),
                  successful_normal_route=complete is not None and lives==3 and float(routes[0][1])==40,
                  reference_origin=reference_origin,strict_parity_accepted=False,
                  limitation='CPU gameplay diagnostic. Shared next-stage loader and all six strict parity gates require separate evidence.')
    (output/'summary.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8', newline='\n')
    print(json.dumps(report,indent=2))
    return report

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--movie',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--reference-origin',action='store_true',help='initialize captured ROM fixture at frame zero only')
    args=parser.parse_args();run(args.movie,args.output.resolve(),args.reference_origin)
