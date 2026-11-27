"""Replay fixed inputs from a normal runtime entrance; gameplay evidence, not parity."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from common import load_movie, expand_input_masks, tool_path

ROOT = Path(__file__).resolve().parents[2]


def validate_route(rows: list[dict], movie: dict) -> dict:
    origin = (movie.get('world', 1), movie.get('level', 1))
    following = (origin[0], origin[1] + 1) if origin[1] < 4 else (origin[0] + 1, 1)
    reasons = []
    if len(rows) != movie['frames'] + 1 or [r['frame'] for r in rows] != list(range(len(rows))):
        reasons.append('missing, extra or non-contiguous runtime frames')
    if not rows or (rows[0]['world'], rows[0]['level']) != origin:
        reasons.append('wrong normal-entry stage')
    deaths = [r['frame'] for r in rows if r['dead'] or r['state'] in ('deathReload', 'gameOver')]
    if deaths or (rows and min(r['lives'] for r in rows) < rows[0]['lives']):
        reasons.append('route contains death or life loss')
    endpoints = [r for r in rows if (r['world'], r['level']) == following or
                 ((r['world'], r['level']) == origin and r['state'] in ('levelComplete', 'worldComplete'))]
    if not endpoints:
        reasons.append('successful course/world endpoint was not reached')
    if any((r['world'], r['level']) not in (origin, following) for r in rows):
        reasons.append('unexpected stage transition')
    if not any(r['state'] == 'playing' and (r['world'], r['level']) == origin for r in rows):
        reasons.append('no normal gameplay in requested stage')
    return dict(passed=not reasons, reasons=reasons, frames=max(0,len(rows)-1),
                start=rows[0] if rows else None, end=rows[-1] if rows else None,
                first_endpoint=endpoints[0] if endpoints else None, death_frames=deaths,
                scope='fixed-input normal-entry gameplay only; not image/state parity, audio, branches or formal whole-level acceptance')


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--movie',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();movie=load_movie(args.movie)
    world,stage=movie.get('world',1),movie.get('level',1)
    if type(world) is not int or type(stage) is not int or not (1<=world<=8 and 1<=stage<=4):
        parser.error('invalid world/stage')
    if movie.get('checkpoint_page',0): parser.error('whole routes must start at the normal entrance')
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    source='''eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("main.nut");loadTexture=function(path) {return path;};loadAssets();
PARITY_MOVIE_ENABLED=false;
local g=createGame();
'''+f'startLevel(g,{world},{stage});\nlocal masks='+json.dumps(expand_input_masks(movie))+''';
function routeState(g,f) {
    print("ROUTE "+"{\\"frame\\":"+f+",\\"world\\":"+g.world+",\\"level\\":"+g.level+
        ",\\"area\\":\\""+g.area+"\\",\\"state\\":\\""+g.state+"\\",\\"x\\":"+g.player.x+
        ",\\"y\\":"+g.player.y+",\\"lives\\":"+g.lives+",\\"dead\\":"+(g.player.dead?"true":"false")+"}\\n");
}
routeState(g,0);
for(local f=0;f<masks.len();f+=1) {
    parityApplyMask(g,masks[f]);simulateFixed(g,FIXED_DT);
    g.input.jumpQueued=false;g.input.fireQueued=false;g.input.startQueued=false;
    routeState(g,f+1);
}
print("ROUTE_REPLAY_COMPLETE\\n");
'''
    script=out/'replay.nut';script.write_text(source,encoding='utf-8')
    result=subprocess.run([str(tool_path('eve')),'run','--no-window','-r',str(script)],cwd=ROOT,
                          capture_output=True,text=True,timeout=180)
    (out/'engine.log').write_text(result.stdout+'\n'+result.stderr,encoding='utf-8')
    rows=[json.loads(line[6:]) for line in result.stdout.splitlines() if line.startswith('ROUTE ')]
    report=validate_route(rows,movie)
    if result.returncode or 'ROUTE_REPLAY_COMPLETE' not in result.stdout:
        report['passed']=False;report['reasons'].append('runtime failed or replay did not finish')
    report['movie_sha256']=hashlib.sha256(args.movie.read_bytes()).hexdigest()
    report['runner_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    report['replay_sha256']=hashlib.sha256(script.read_bytes()).hexdigest()
    report['exit_code']=result.returncode
    runtime_hash=hashlib.sha256()
    for path in sorted([ROOT/'main.nut', *(ROOT/'scripts').rglob('*.nut')]):
        runtime_hash.update(path.relative_to(ROOT).as_posix().encode()+b'\0'+path.read_bytes())
    report['runtime_sources_sha256']=runtime_hash.hexdigest()
    (out/'state.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in rows),encoding='utf-8')
    (out/'summary.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='death_frames'}));return 0 if report['passed'] else 1


if __name__=='__main__': raise SystemExit(main())
