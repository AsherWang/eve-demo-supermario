"""Independent continuous-boot fixed-input World 2-3 reference diagnostic.

Stage selection is performed before area initialization. The comparison route
contains controller input only; its capture callback never writes RAM.
This records raw evidence and does not assert strict acceptance.
"""
from pathlib import Path
import argparse
import json
import re
from common import load_movie, mesen_section_input_arguments, sha256_file, tool_path
from run_reference import EXPECTED_ROM_SHA256, build_capture_lua, run_command
from world23_reference import build_world23_origin_lua
from world23_capture_lock import capture_lock
from extract_reference_state import decode_line

ROOT=Path(__file__).resolve().parents[2]

def run(movie_path,output):
    movie=load_movie(movie_path)
    if (movie.get('world'),movie.get('level'))!=(2,3): raise ValueError('World 2-3 required')
    rom=ROOT/'roms/Super Mario Bros. (World).nes'
    if sha256_file(rom)!=EXPECTED_ROM_SHA256: raise ValueError('unverified ROM')
    output.mkdir(parents=True,exist_ok=True);(output/'frames').mkdir(exist_ok=True)
    origin=build_world23_origin_lua();script=output/'origin.lua';script.write_text(origin,encoding='utf-8', newline='\n')
    bootstrap=movie.get('reference_bootstrap',dict(frames=600,inputs=[dict(start=40,end=46,buttons=['start'])]))
    command=[str(tool_path('mesen')),str(rom),'--home',str(output/'home'),'--timeout','120']
    result,_=run_command(command+['--frames',str(bootstrap['frames']),'--lua',str(script)]+
        mesen_section_input_arguments(bootstrap['inputs']),output/'origin-events.jsonl',output/'origin-stderr.log')
    match=re.search(r'PARITY_ORIGIN frame=(\d+)',result.stdout)
    if result.returncode or match is None: raise RuntimeError('Normal entrance origin not found')
    warmup=int(match[1])+1
    script=output/'capture.lua'
    script.write_text(origin+'\n'+build_capture_lua(output,movie,warmup),encoding='utf-8', newline='\n')
    result,summaries=run_command(command+['--frames',str(warmup+movie['frames']),
        '--lua',str(script),'--lua-allow-io','--audio',str(output/'continuous-audio.wav')]+
        mesen_section_input_arguments(bootstrap['inputs'])+
        mesen_section_input_arguments(movie['inputs'],offset=warmup),output/'events.jsonl',output/'stderr.log')
    rows=[decode_line(line) for line in (output/'ram-trace.jsonl').read_text().splitlines()]
    (output/'state.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in rows),encoding='utf-8', newline='\n')
    transition=next((r['frame'] for r in rows if r['world']==2 and r['level']==4),None)
    flag=next((r['frame'] for r in rows if r['rom_state']['game_engine_subroutine']==4),None)
    summary=dict(movie_sha256=sha256_file(movie_path),rom_sha256=EXPECTED_ROM_SHA256,
        origin_frame=int(match[1]),comparison_frames=len(rows),flag_frame=flag,transition_frame=transition,
        minimum_lives=min(r['lives'] for r in rows),furthest_x=max(r['player']['x'] for r in rows),
        successful_normal_route=transition is not None and min(r['lives'] for r in rows)==3,
        exit_code=result.returncode,summary=summaries[-1] if summaries else None,
        strict_parity_accepted=False,
        limitation='Continuous diagnostic; audio includes bootstrap and is not normalized for the strict audio gate.')
    (output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8', newline='\n')
    print(json.dumps(summary,indent=2))
    return summary

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--movie',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    with capture_lock('world23-reference'): run(args.movie,args.output.resolve())
