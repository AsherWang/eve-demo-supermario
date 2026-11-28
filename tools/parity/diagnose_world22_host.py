"""Full input-movie CPU diagnostics for source-driven 2-2 transitions."""
from __future__ import annotations
import argparse,json,subprocess
from pathlib import Path
from common import load_movie,expand_input_masks,tool_path
ROOT=Path(__file__).resolve().parents[2]

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--movie',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--reference',type=Path);p.add_argument('--local-transition-hook',action='store_true');a=p.parse_args()
 movie=load_movie(a.movie);out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
 hook='''local previousHandler=updateWorld12Transition;updateWorld12Transition=function(g) {return isWorld22(g)?updateWorld22Transition(g):previousHandler(g);};
local previousScheduler=updateVramAreaParserScheduler;
updateVramAreaParserScheduler=function(g) {local before=g.vramAreaParserTask;previousScheduler(g);if(isWorld22Water(g) && before!=g.vramAreaParserTask) parseWorld22AreaColumn(g,g.vramAreaParserTask);};
local previousCamera=updateCamera;
updateCamera=function(g) {if(isWorld22Water(g) && g.world22.scrollLocked) {g.displayCameraX=g.cameraX;g.previousScrollAmount=0;return;}previousCamera(g);};\n''' if a.local_transition_hook else ''
 source='''eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("main.nut");loadTexture=function(path) {return path;};loadAssets();loadWorld22Assets();PARITY_MOVIE_ENABLED=false;
'''+hook+'''local g=createGame();initializeWorld22Parity(g);parityInitialize(g);
local masks='''+json.dumps(expand_input_masks(movie))+''';
for(local f=0;f<masks.len();f+=1) {
 g.parity.frame=f;g.parity.inputMask=masks[f];parityApplyMask(g,masks[f]);if(f>0) simulateFixed(g,FIXED_DT);
 g.input.jumpQueued=false;g.input.fireQueued=false;g.input.resetQueued=false;
 print("STATE "+parityStateJson(g,f)+"\\n");
 local t=g.world22Transition;
 print("TASK {\\"frame\\":"+f+",\\"phase\\":\\""+t.phase+"\\",\\"oper_task\\":"+t.operTask+",\\"engine_task\\":"+t.engineTask+",\\"screen_task\\":"+t.screenTask+",\\"interval\\":"+g.intervalTimerControl+"}\\n");
}
print("WORLD22_FULL_DIAGNOSTIC_DONE\\n");
'''
 script=out/'replay.nut';script.write_text(source,encoding='utf-8',newline='\n')
 r=subprocess.run([str(tool_path('eve')),'run','--no-window','-r',str(script)],cwd=ROOT,capture_output=True,text=True,timeout=90)
 (out/'engine.log').write_text(r.stdout+'\n'+r.stderr,encoding='utf-8')
 rows=[]
 for name,prefix in [('state','STATE '),('tasks','TASK ')]:
  lines=[s[len(prefix):] for s in r.stdout.splitlines() if s.startswith(prefix)];(out/(name+'.jsonl')).write_text('\n'.join(lines)+'\n',encoding='utf-8')
  if name=='state':rows=[json.loads(s) for s in lines]
 expected=[json.loads(s) for s in a.reference.read_text(encoding='utf-8').splitlines()] if a.reference else []
 differences=[];first_by_field={}
 for ref,act in zip(expected,rows):
  for k in ['x','y','x_speed_raw','x_acceleration_fraction','x_position_fraction','y_speed_raw','y_move_force','y_move_dummy','grounded','facing_direction_raw','moving_direction_raw']:
   if ref['player'][k]!=act['player'][k]:
    d=dict(frame=ref['frame'],field=k,reference=ref['player'][k],actual=act['player'][k]);differences.append(d);first_by_field.setdefault(k,d)
  for k in ['camera_x','time','lives','frame_counter','score','coins']:
   if ref[k]!=act[k]:
    d=dict(frame=ref['frame'],field=k,reference=ref[k],actual=act[k]);differences.append(d);first_by_field.setdefault(k,d)
 report=dict(frames=len(rows),expected_frames=len(expected),reference_compared=a.reference is not None,complete=len(rows)==movie['frames'] and (not a.reference or len(expected)==len(rows)) and r.returncode==0,differences=len(differences),first_by_field=first_by_field,first_differences=differences[:30],last_state=rows[-1] if rows else None,alive_all_frames=all(r['lives']==3 for r in rows))
 (out/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps(report,indent=2));return 0 if report['complete'] and not differences else 1
if __name__=='__main__':raise SystemExit(main())
