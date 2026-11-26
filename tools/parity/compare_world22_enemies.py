"""Compare water enemy slots and movement registers, without image/audio claims."""
from __future__ import annotations
import argparse
import json
from pathlib import Path


def decode_enemies(ram: bytes) -> list:
    result=[]
    for slot in range(5):
        if not ram[15+slot]: result.append(None);continue
        kind=ram[22+slot];x=ram[0x6e+slot]*256+ram[0x87+slot];y=ram[0xcf+slot]
        if kind==7:
            result.append([kind,x,y,ram[0x58+slot],ram[0x434+slot],ram[0xa0+slot],ram[0x796+slot],ram[0x46+slot]])
        elif kind in (10,11):
            result.append([kind,x,y,ram[0x401+slot],ram[0x417+slot],ram[0x58+slot],ram[0x434+slot]])
        else: raise ValueError(f'unsupported reference enemy ID {kind} in slot {slot}')
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference',type=Path,required=True,help='ROM ram-trace.jsonl')
    parser.add_argument('--actual',type=Path,required=True,help='Simulation actors.jsonl')
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    source=[json.loads(line) for line in args.reference.read_text(encoding='utf-8').splitlines()]
    if [row['frame'] for row in source]!=list(range(len(source))): raise ValueError('non-contiguous reference')
    expected=[decode_enemies(bytes.fromhex(row['ram_hex'])) for row in source]
    actual=[json.loads(line) for line in args.actual.read_text(encoding='utf-8').splitlines()]
    differences=[dict(frame=f,slot=s,expected=r[s],actual=a[s])
        for f,(r,a) in enumerate(zip(expected,actual)) for s in range(5) if r[s]!=a[s]]
    report=dict(passed=bool(expected) and len(expected)==len(actual) and not differences,
        frames=len(actual),reference_frames=len(expected),difference_count=len(differences),
        scope='all five water enemy slots and selected movement registers; not image/audio or full collision acceptance',
        first_differences=differences[:30])
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report));return 0 if report['passed'] else 1


if __name__=='__main__': raise SystemExit(main())
