"""Offline input search. Candidate state copies are search only; the saved movie is replayed afresh."""
import argparse,json,subprocess
from pathlib import Path
from run_world24_simulation import PRELUDE,ROOT
from common import tool_path

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True)
    p.add_argument('--beam',type=int,default=40);p.add_argument('--steps',type=int,default=200)
    p.add_argument('--prefix',type=Path);args=p.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    prefix=[]
    if args.prefix:
        from common import expand_input_masks,load_movie
        prefix=expand_input_masks(load_movie(args.prefix))[1:]
    code=PRELUDE+r'''
function copyState(value) {
    local t=typeof value;
    if(t=="table") {local out={};foreach(k,v in value) {
        if(k=="metatiles" || k=="baseMetatiles") out[k]<-v;
        else out[k]<-copyState(v);
    }return out;}
    if(t=="array") {local out=[];foreach(v in value) out.append(copyState(v));return out;}
    return value;
}
function advance(g,mask) {
    parityApplyMask(g,mask);simulateFixed(g,FIXED_DT);
    g.input.jumpQueued=false;g.input.fireQueued=false;g.input.resetQueued=false;
}
local origin=createGame();startLevel(origin,2,4);origin.player.parityOriginFriction=true;
origin.nesFrameCounter=(origin.nesFrameCounter+1)&255;
local initial='''+json.dumps(prefix)+r''';
foreach(mask in initial) advance(origin,mask);
local beam=[{g=origin,path=initial,score=origin.player.x}];
local found=null;
for(local step=0;step<STEPS;step+=1) {
    local candidates=[],seen={};
    foreach(node in beam) foreach(mask in [130,131,2,3,66,67]) {
        local g=copyState(node.g),path=clone node.path;
        for(local f=0;f<8;f+=1) {advance(g,mask);path.append(mask);if(g.player.dead) break;}
        if(g.player.dead || g.lives!=3 || g.player.y>240.0) continue;
        if(g.state!="playing") {found={g=g,path=path};break;}
        local p=g.player;
        local key=(floor(p.x/4.0))+":"+(floor(p.y/4.0))+":"+(p.grounded?1:0)+":"+
            (g.input.jumpDown?1:0)+":"+floor(p.nesYSpeed)+":"+floor(p.nesXSpeed/8.0);
        if(key in seen) continue;seen[key]<-true;
        local score=p.x-(p.y>208.0?(p.y-208.0)*2.0:0.0);
        candidates.append({g=g,path=path,score=score});
    }
    if(found!=null) break;
    candidates.sort(function(a,b){return a.score>b.score?-1:(a.score<b.score?1:0);});
    beam=[];
    for(local i=0;i<candidates.len() && i<BEAM;i+=1) beam.append(candidates[i]);
    if(beam.len()==0) {print("NO_CANDIDATES\n");break;}
    if((step%10)==0) print("PROGRESS "+step+" x="+beam[0].g.player.x+" y="+beam[0].g.player.y+"\n");
}
local best=found!=null?found:(beam.len()>0?beam[0]:null);
if(best!=null) {
    local csv="";foreach(i,mask in best.path) csv+=(i?",":"")+mask;
    print("MASKS [0,"+csv+"]\n");
    print("RESULT "+best.g.state+" x="+best.g.player.x+"\n");
}
'''
    code=code.replace('STEPS',str(args.steps)).replace('BEAM',str(args.beam))
    script=out/'search.nut';script.write_text(code)
    r=subprocess.run([str(tool_path('eve')),'run','--no-window','-r',str(script)],cwd=ROOT,capture_output=True,text=True,timeout=600)
    (out/'engine.log').write_text(r.stdout+'\n'+r.stderr)
    print('\n'.join(line for line in r.stdout.splitlines() if not line.startswith('MASKS ')))
    rows=[json.loads(line[6:]) for line in r.stdout.splitlines() if line.startswith('MASKS ')]
    if not rows:raise RuntimeError('No route; inspect engine.log')
    masks=rows[-1];masks.extend([0]*900)
    sections=[];start=0
    for end in range(1,len(masks)+1):
        if end<len(masks) and masks[end]==masks[start]:continue
        if masks[start]:sections.append(dict(start=start,end=end-1,buttons=[button for bit,button in [(1,'a'),(2,'b'),(64,'left'),(128,'right')] if masks[start]&bit]))
        start=end
    movie=dict(schema='smb-parity-movie-v1',name='world-2-4-host-route',level_id='2-4',world=2,level=4,frames=len(masks),
        description='Fixed controller candidate from normal small-Mario entrance. Must pass fresh whole-route verification; no strict parity claim.',
        reference_bootstrap=dict(frames=800,inputs=[dict(start=40,end=46,buttons=['start'])]),inputs=sections)
    (out/'movie.json').write_text(json.dumps(movie,indent=2)+'\n')
if __name__=='__main__':main()
