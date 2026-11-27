"""Search controller-only route candidates; export a fixed movie for independent replay."""
import argparse
import json
from pathlib import Path
import subprocess
from common import tool_path

ROOT=Path(__file__).resolve().parents[2]

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--reference-origin',action='store_true');args=parser.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    script=out/'search.nut';script.write_text('WORLD23_SEARCH_REFERENCE_ORIGIN <- '+
        ('true' if args.reference_origin else 'false')+';\ndofile("tools/regression/world23_search.nut");\n',
        encoding='utf-8',newline='\n')
    result=subprocess.run([str(tool_path('eve')),'run','--no-window','-r',str(script)],cwd=ROOT,
        capture_output=True,text=True,timeout=120)
    log=result.stdout+'\n'+result.stderr;(out/'engine.log').write_text(log,encoding='utf-8',newline='\n')
    if result.returncode or 'WORLD23_SEARCH_SUCCESS' not in log:
        raise RuntimeError('Search failed; inspect '+str(out/'engine.log'))
    masks=json.loads(log.split('MASKS ',1)[1].split(']',1)[0]+']')+[0]*30
    inputs=[];start=0
    for i in range(1,len(masks)+1):
        if i==len(masks) or masks[i]!=masks[start]:
            if masks[start]: inputs.append(dict(port=0,start=start,end=i-1,
                buttons=[n for b,n in [(1,'a'),(2,'b'),(128,'right')] if masks[start]&b]))
            start=i
    name='world-2-3-original-clear-candidate' if args.reference_origin else 'world-2-3-runtime-clear-candidate'
    movie=dict(schema='smb-parity-movie-v1',name=name,level_id='2-3',world=2,level=3,
        description='Controller-only runtime search candidate. Original ROM independent verification required.',
        frames=len(masks),inputs=inputs,reference_bootstrap=dict(frames=600,inputs=[dict(port=0,start=40,end=46,buttons=['start'])]),
        capture_frames=[0,400,800,1200,len(masks)-1])
    (out/'movie.json').write_text(json.dumps(movie,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(next(l for l in log.splitlines() if l.startswith('WORLD23_SEARCH_SUCCESS')))
    print(out/'movie.json')

if __name__=='__main__': main()
