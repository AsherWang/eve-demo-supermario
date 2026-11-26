"""Run the water-motion and checkpoint diagnostics; not whole-level acceptance."""
from __future__ import annotations
import argparse
import json
import subprocess
from pathlib import Path
from tool_paths import tool_path

ROOT=Path(__file__).resolve().parents[1]


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    result=subprocess.run([str(tool_path('eve')),'run','--no-window','-r',
        'tools/regression/world22.nut'],cwd=ROOT,capture_output=True,text=True,timeout=90)
    text=result.stdout+'\n'+result.stderr
    (args.output/'engine.log').write_text(text,encoding='utf-8')
    manifest=json.loads((ROOT/'tests/fixtures/world22_motion.json').read_text(encoding='utf-8'))
    expected_frames=sum(case['frames'] for case in manifest['cases'])
    passed=result.returncode==0 and f'WORLD22_REGRESSION_OK frames={expected_frames}\n' in text
    report=dict(passed=passed,exit_code=result.returncode,
        scope='selected player/enemy movement registers, checkpoint, contact and segmented entry/exit flow diagnostics; full image/audio/campaign acceptance remains pending')
    (args.output/'summary.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(text);print(json.dumps(report))
    return 0 if passed else 1


if __name__=='__main__':
    raise SystemExit(main())
