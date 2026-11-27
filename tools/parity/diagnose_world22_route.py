"""Continuous original-ROM diagnostic for the normal 2-2 route, not acceptance."""
from __future__ import annotations
import argparse
import json
import re
import uuid
from pathlib import Path
from common import load_movie, mesen_section_input_arguments, sha256_file, tool_path
from extract_reference_state import decode_line
from run_reference import build_capture_lua, run_command, EXPECTED_ROM_SHA256
from world22_reference import build_world22_entrance_origin_lua

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--movie', type=Path, default=ROOT/'tests/parity/movies/world-2-2-normal-route.json')
    parser.add_argument('--rom', type=Path, default=ROOT/'roms/Super Mario Bros. (World).nes')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--capture-lock', type=Path, required=True, help='Shared atomic capture lock directory')
    parser.add_argument('--actual', type=Path, help='Host whole-route state.jsonl for selected-state diagnostics')
    args = parser.parse_args()
    movie=load_movie(args.movie)
    if (movie.get('world'),movie.get('level'),movie.get('origin'))!=(2,2,'normal-entrance'):
        parser.error('only normal 2-2 entrance movies supported')
    if sha256_file(args.rom)!=EXPECTED_ROM_SHA256:
        parser.error('unverified original ROM')
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    if any((out/'frames').glob('frame-*.png')):
        parser.error('use a fresh output directory; stale captures must not count')
    token='world22-completion '+str(uuid.uuid4())
    try:
        args.capture_lock.mkdir()
    except FileExistsError:
        print('Capture lock held; no capture started. Continue CPU work.');return 75
    owner=args.capture_lock/'owner-world22.txt'
    try:
        owner.write_text(token,encoding='utf-8')
        lua=out/'find-origin.lua';lua.write_text(build_world22_entrance_origin_lua(),encoding='utf-8')
        exe=str(tool_path('mesen'));bootstrap=movie['reference_bootstrap']
        base=[exe,str(args.rom.resolve()),'--home',str(out/'mesen-home'),'--timeout','120']
        scan=base+['--frames',str(bootstrap['frames']),'--lua',str(lua)]
        scan+=mesen_section_input_arguments(bootstrap['inputs'])
        result,summaries=run_command(scan,out/'scan.jsonl',out/'scan-stderr.log')
        match=re.search(r'PARITY_ORIGIN frame=(\d+)',result.stdout)
        if result.returncode or not match: raise RuntimeError('normal entrance not found; inspect scan')
        origin=int(match[1]);warmup=origin+1
        (out/'frames').mkdir(exist_ok=True)
        lua=out/'capture.lua'
        lua.write_text(build_world22_entrance_origin_lua()+'\n'+build_capture_lua(out,movie,warmup),encoding='utf-8')
        command=base+['--frames',str(warmup+movie['frames']),'--lua',str(lua),'--lua-allow-io']
        command+=mesen_section_input_arguments(bootstrap['inputs'])
        command+=mesen_section_input_arguments(movie['inputs'],offset=warmup)
        result,summaries=run_command(command,out/'capture.jsonl',out/'capture-stderr.log')
        if result.returncode or not summaries or not summaries[-1].get('ok'):
            raise RuntimeError('reference capture failed')
        rows=[decode_line(line) for line in (out/'ram-trace.jsonl').read_text().splitlines()]
        (out/'state.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in rows),encoding='utf-8')
        report=dict(scope='continuous original-ROM diagnostic; no restored-state proof, no host image/APU/audio acceptance',
                    strict_parity_accepted=False,movie_sha256=sha256_file(args.movie),rom_sha256=sha256_file(args.rom),
                    origin_frame=origin,state_rows=len(rows),capture_frames=len(list((out/'frames').glob('frame-*.png'))),
                    origin_rule=dict(world=2,level=2,area_number=1,engine_subroutine=7),
                    first_state=rows[0],last_state=rows[-1])
        if args.actual:
            actual=[json.loads(line) for line in args.actual.read_text().splitlines()]
            differences=[]
            for ref,act in zip(rows,actual):
                for key in ['x','y','x_speed_raw','y_speed_raw','grounded']:
                    if ref['player'][key]!=act['player'][key]:
                        differences.append(dict(frame=ref['frame'],field='player.'+key,reference=ref['player'][key],actual=act['player'][key]))
            report['selected_motion']=dict(passed=not differences and len(rows)==len(actual),difference_count=len(differences),first_differences=differences[:30])
        report['capture_passed']=len(rows)==movie['frames'] and report['capture_frames']==movie['frames']
        (out/'diagnostic.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        print(json.dumps({k:v for k,v in report.items() if k not in ('first_state','last_state','selected_motion')},indent=2))
        if 'selected_motion' in report: print(json.dumps(report['selected_motion']))
        return 0 if report['capture_passed'] else 1
    finally:
        if owner.is_file() and owner.read_text(encoding='utf-8')==token:
            owner.unlink();args.capture_lock.rmdir()


if __name__=='__main__':
    raise SystemExit(main())
