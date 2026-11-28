"""Replay fixed World 2-4 inputs in the real host simulation. No visual/audio gate claim."""
from pathlib import Path
import argparse, json, subprocess
from common import load_movie, expand_input_masks, tool_path, sha256_file
ROOT=Path(__file__).resolve().parents[2]
PRELUDE='''eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("main.nut");loadTexture=function(path){return path;};
loadAssets();loadWorld13Assets();loadWorld14Assets();loadWorld24Assets();
PARITY_MOVIE_ENABLED=false;
'''
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--movie',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--require-clear',action='store_true');p.add_argument('--self-test',action='store_true')
    p.add_argument('--normal-start',action='store_true',help='Advance frame zero as normal gameplay, without parity origin initialization')
    args=p.parse_args();movie=load_movie(args.movie)
    if (movie.get('world'),movie.get('level'))!=(2,4):p.error('requires world=2 level=4')
    if any(key in movie for key in ('checkpoint_page','test_state','invulnerable','teleport')):p.error('normal entrance only')
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    masks=expand_input_masks(movie)
    source=PRELUDE+('runWorld24SelfTest();\n' if args.self_test else '')+'''local g=createGame();startLevel(g,2,4);parityInitialize(g);
g.player.parityOriginFriction=true;
PARITY_MOVIE_ENABLED=true;PARITY_FRAME_MASKS=[0];
local masks='''+json.dumps(masks)+r''';
for(local f=0;f<masks.len();f+=1) {
    g.parity.frame=f;g.parity.eventSequence=0;g.parity.inputMask=masks[f];parityApplyMask(g,masks[f]);
    if(f==0) g.nesFrameCounter=(g.nesFrameCounter+1)&255;
    else simulateFixed(g,FIXED_DT);
    g.input.jumpQueued=false;g.input.fireQueued=false;g.input.resetQueued=false;
    print("STATE "+parityStateJson(g,f)+"\n");
    print("CASTLE {\"frame\":"+f+",\"world\":"+g.world+",\"stage\":"+g.level+
        ",\"state\":\""+g.state+"\",\"bridge_offset\":"+g.world24.bridgeOffset+
        ",\"rescued\":"+parityBool(g.world24.rescued)+",\"message\":"+g.world24.primaryMsgCounter+
        ",\"bowser_hidden\":"+parityBool(g.world24.bowser.hidden)+
        ",\"bowser_x\":"+g.world24.bowser.x+",\"bowser_y\":"+g.world24.bowser.y+
        ",\"bowser_slot\":"+g.world24.bowser.slot+",\"feet_timer\":"+g.world24.bowser.feetTimer+
        ",\"body_controls\":"+g.world24.bowser.bodyControls+",\"interval\":"+g.world24.interval+
        ",\"victory_task\":"+("victoryTask" in g.world24?g.world24.victoryTask:-1)+"}\n");
}
print("SIMULATION_COMPLETE\n");
'''
    if args.normal_start:
        source=source.replace('g.player.parityOriginFriction=true;','').replace('if(f==0) g.nesFrameCounter=(g.nesFrameCounter+1)&255;\n    else simulateFixed(g,FIXED_DT);','simulateFixed(g,FIXED_DT);')
    script=out/'replay.nut';script.write_text(source,newline='\n')
    r=subprocess.run([str(tool_path('eve')),'run','--no-window','-r',str(script)],cwd=ROOT,capture_output=True,text=True,timeout=120)
    (out/'engine.log').write_text(r.stdout+'\n'+r.stderr, newline="\n")
    groups={prefix:[json.loads(line[len(prefix):]) for line in r.stdout.splitlines() if line.startswith(prefix)] for prefix in ('STATE ','CASTLE ','PARITY_EVENT ')}
    for prefix,name in [('STATE ','state'),('CASTLE ','castle'),('PARITY_EVENT ','events')]:
        (out/(name+'.jsonl')).write_text(''.join(json.dumps(row)+'\n' for row in groups[prefix]), newline="\n")
    states=groups['STATE '];castle=groups['CASTLE ']
    if r.returncode or len(states)!=movie['frames'] or 'SIMULATION_COMPLETE' not in r.stdout:raise RuntimeError('replay failed: '+str(out/'engine.log'))
    deaths=[s['frame'] for s in states if s['player'].get('dead') or s.get('lives')!=3 or s.get('rom_state',{}).get('game_engine_subroutine')==11]
    final=castle[-1]
    passed=not deaths and final['state']=='worldComplete' and final['rescued'] and final['bridge_offset']==15 and final['message']==4 and final['world']==2 and final['stage']==4
    report=dict(schema='world24-host-route-v1',movie_sha256=sha256_file(args.movie),frames=len(states),passed=passed,
        scope='host fixed-input entrance-to-bounded-endpoint only; strict six gates not checked',
        death_or_life_loss_frames=deaths,final=final,
        first_states={name:next((r['frame'] for r in castle if r['state']==name),None) for name in ['world24Axe','world24VictoryWalk','world24Rescue','worldComplete']})
    (out/'verification.json').write_text(json.dumps(report,indent=2)+'\n', newline="\n");print(json.dumps(report,indent=2))
    if args.require_clear and not passed:raise SystemExit(1)
if __name__=='__main__':main()
