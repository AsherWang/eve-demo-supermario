"""Run World 1 simulation regressions; require explicit completion, not just exit 0."""
from __future__ import annotations
import argparse
import json
import subprocess
from pathlib import Path
from tool_paths import tool_path

ROOT=Path(__file__).resolve().parents[1]

def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=ROOT/'local-parity/world1-regression')
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    result=subprocess.run([str(tool_path('eve')),'run','--no-window','-r',
        'tools/regression/world1.nut'],cwd=ROOT,capture_output=True,text=True,timeout=90)
    output=result.stdout+'\n'+result.stderr
    (args.output/'engine.log').write_text(output,encoding='utf-8')
    suites=[line.removeprefix('REGRESSION_PASS ') for line in output.splitlines()
        if line.startswith('REGRESSION_PASS ')]
    passed=result.returncode==0 and 'WORLD1_REGRESSION_OK' in output and len(suites)==10
    commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    dirty=bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip())
    report=dict(passed=passed,commit=commit,working_tree_dirty=dirty,suites=suites,exit_code=result.returncode,
        scope='simulation only; not image, device audio or strict whole-level acceptance')
    (args.output/'summary.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(output)
    print(json.dumps(report))
    return 0 if passed else 1

if __name__=='__main__':
    raise SystemExit(main())
