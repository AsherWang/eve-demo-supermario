"""Capture the fixed 2-2 host route with ordinary startLevel and no state patches."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import subprocess
import shutil
import time
import uuid
from common import load_movie, sha256_file, tool_path, expand_input_masks

ROOT=Path(__file__).resolve().parents[2]


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--movie',type=Path,default=ROOT/'tests/parity/movies/world-2-2-normal-route.json')
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--capture-lock',type=Path,required=True)
    args=parser.parse_args();movie=load_movie(args.movie)
    if (movie.get('world'),movie.get('level'),movie.get('origin'))!=(2,2,'normal-entrance'):
        parser.error('requires normal 2-2 entrance')
    out=args.output.resolve();(out/'frames').mkdir(parents=True,exist_ok=True)
    if any((out/'frames').glob('frame-*.png')):
        parser.error('use a fresh output directory; stale captures must not count')
    token='world22-native '+str(uuid.uuid4())
    try:args.capture_lock.mkdir()
    except FileExistsError:print('Capture lock held; no capture started.');return 75
    owner=args.capture_lock/'owner-world22.txt';process=None
    try:
        owner.write_text(token,encoding='utf-8')
        project=out/'project';project.mkdir(exist_ok=True)
        for name in ('scripts','assets'):
            link=project/name
            if not link.exists():
                subprocess.run(['cmd','/c','mklink','/J',str(link),str(ROOT/name)],check=True,capture_output=True)
        shutil.copyfile(ROOT/'config.nut',project/'config.nut')
        shutil.copyfile(ROOT/'main.nut',project/'original.nut')
        source=project/'main.nut'
        source.write_text('''eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("original.nut");
PARITY_MOVIE_ENABLED=true;PARITY_MOVIE_NAME="world-2-2-normal-route";
PARITY_OUTPUT_DIR='''+json.dumps(out.as_posix())+''';
PARITY_FRAME_MASKS='''+json.dumps(expand_input_masks(movie))+''';
PARITY_CAPTURE_FRAMES='''+json.dumps(list(range(movie['frames'])))+''';
eve_init=function() {
    gfx.setBackgroundColor(146.0/255.0,144.0/255.0,1.0,1.0);
    loadAssets();loadWorld13Assets();loadWorld14Assets();loadWorld21Assets();loadWorld22Assets();
    game=createGame();startLevel(game,2,2);parityInitialize(game);
};
// Frame zero observes startLevel unchanged, exactly as the headless route gate.
// No motion-fixture initialization, origin friction patch, or counter write.
eve_update=function(dt) {
    local g=game;
    if(g.parity.done || g.parity.awaitingCapture) return;
    local f=g.parity.frame,mask=PARITY_FRAME_MASKS[f];
    g.parity.inputMask=mask;g.parity.eventSequence=0;parityApplyMask(g,mask);
    if(f>0) simulateFixed(g,FIXED_DT);
    g.input.jumpQueued=false;g.input.fireQueued=false;g.input.resetQueued=false;
    requireSelfTest(!g.player.dead && g.lives==3 && g.player.invulnerable==0 &&
        g.player.starTimer==0,"native route must stay alive and unprotected");
    if(f==PARITY_FRAME_MASKS.len()-1) requireSelfTest(g.state=="levelComplete","native route settlement");
    // Audio is not initialized in this visual diagnostic; keep queued events.
    g.parity.awaitingCapture=true;
};
''',encoding='utf-8')
        with (out/'stdout.log').open('w',encoding='utf-8') as stdout,(out/'stderr.log').open('w',encoding='utf-8') as stderr:
            process=subprocess.Popen([str(tool_path('eve')),'run',str(project)],cwd=ROOT,stdout=stdout,stderr=stderr)
            final=out/'frames'/f"frame-{movie['frames']-1:06d}.png"
            deadline=time.monotonic()+150
            while process.poll() is None and time.monotonic()<deadline:
                if final.is_file() and final.stat().st_size>0:
                    time.sleep(.3);break
                time.sleep(.1)
            if process.poll() is None:process.terminate();process.wait(timeout=10)
        log=(out/'stdout.log').read_text(encoding='utf-8',errors='replace')
        rows=[];events=[]
        for line in log.splitlines():
            for prefix,dest in [('PARITY_STATE ',rows),('PARITY_EVENT ',events)]:
                if prefix in line:dest.append(json.loads(line.split(prefix,1)[1]))
        for name,data in [('state.jsonl',rows),('events.jsonl',events)]:
            (out/name).write_text(''.join(json.dumps(r)+'\n' for r in data),encoding='utf-8')
        count=len(list((out/'frames').glob('frame-*.png')))
        passed=len(rows)==movie['frames'] and count==movie['frames'] and rows[-1]['state']=='levelComplete'
        report=dict(passed=passed,strict_parity_accepted=False,movie_sha256=sha256_file(args.movie),
                    frames=count,state_rows=len(rows),scope='silent native visual gameplay diagnostic only')
        (out/'diagnostic.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps(report))
        return 0 if passed else 1
    finally:
        if process is not None and process.poll() is None:process.terminate();process.wait(timeout=10)
        if owner.is_file() and owner.read_text(encoding='utf-8')==token:
            owner.unlink();args.capture_lock.rmdir()


if __name__=='__main__':raise SystemExit(main())
