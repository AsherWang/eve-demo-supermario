"""CPU state/event diagnostic using the same observation-frame adapter as native capture.

No PNG/audio artifacts are produced, so this cannot pass whole-level acceptance.
"""
import argparse
import json
import subprocess
from pathlib import Path
from common import load_movie, require_supported_stage, tool_path, sha256_file
from run_actual import squirrel_source

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--movie', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    movie = load_movie(args.movie)
    world, stage = require_supported_stage(movie)
    if world != 2 or stage not in (2, 3, 4):
        parser.error('this diagnostic currently initializes only World 2-3/2-4 reference origins')
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    source = '''eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("main.nut");loadTexture=function(path){return path;};loadAssets();
loadWorld13Assets();loadWorld14Assets();loadWorld23Assets();loadWorld24Assets();
''' + squirrel_source(movie, out) + f'\nlocal g=createGame();startLevel(g,{world},{stage});\n'
    if stage == 2:
        source += 'initializeWorld22Parity(g);\n'
    if stage == 3:
        source += 'initializeWorld23Parity(g);\n'
    source += '''parityInitialize(g);
for(local frame=0;frame<PARITY_FRAME_MASKS.len();frame+=1) {
    g.parity.frame=frame;
    parityAdvanceOneFrame(g);
    print("STATE "+parityStateJson(g,frame)+"\\n");
    g.parity.awaitingCapture=false;
    g.soundEvents.clear();
}
print("STRICT_SIMULATION_COMPLETE\\n");
'''
    script = out / 'replay.nut'
    script.write_text(source, encoding='utf-8', newline='\n')
    result = subprocess.run([str(tool_path('eve')), 'run', '--no-window', '-r', str(script)],
                            cwd=ROOT, capture_output=True, text=True, timeout=120)
    (out/'engine.log').write_text(result.stdout+'\n'+result.stderr, encoding='utf-8')
    rows = {}
    for prefix, name in [('STATE ', 'state'), ('PARITY_EVENT ', 'events')]:
        rows[name] = [json.loads(line[len(prefix):]) for line in result.stdout.splitlines() if line.startswith(prefix)]
        (out/(name+'.jsonl')).write_text(''.join(json.dumps(row)+'\n' for row in rows[name]), encoding='utf-8')
    complete = (result.returncode == 0 and len(rows['state']) == movie['frames']
                and 'STRICT_SIMULATION_COMPLETE' in result.stdout)
    report = dict(completed=complete, frames=len(rows['state']), movie_sha256=sha256_file(args.movie),
                  replay_sha256=sha256_file(script), scope='CPU state/event diagnostic, not strict acceptance')
    (out/'diagnostic.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report))
    return 0 if complete else 1


if __name__ == '__main__':
    raise SystemExit(main())
