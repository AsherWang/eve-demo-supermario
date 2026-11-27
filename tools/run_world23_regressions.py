"""Run World 2-3 exact motion, spawn, contact, and checkpoint diagnostics."""
import argparse
import json
from pathlib import Path
import subprocess
from tool_paths import tool_path

ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    result=subprocess.run([str(tool_path('eve')),'run','--no-window','-r','tools/regression/world23.nut'],
        cwd=ROOT,capture_output=True,text=True,timeout=90)
    log=result.stdout+'\n'+result.stderr
    (args.output/'engine.log').write_text(log,encoding='utf-8',newline='\n')
    fixture=json.loads((ROOT/'tests/fixtures/world23_fish_motion.json').read_text())
    report=dict(passed=result.returncode==0 and 'WORLD23_REGRESSION_OK\n' in log,
        motion_register_pairs=fixture['pairs'],spawn_tuples=fixture['spawns'],
        scope='ROM fish motion/spawn tuples and isolated contact/checkpoint diagnostics; not whole-level parity')
    (args.output/'summary.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(log);print(json.dumps(report));return 0 if report['passed'] else 1

if __name__=='__main__': raise SystemExit(main())
