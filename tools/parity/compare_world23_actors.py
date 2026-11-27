"""Compare every active fish slot/register; does not replace the six strict gates."""
import argparse
import json
from pathlib import Path
from common import sha256_file

FIELDS=['x','y','x_speed_raw','x_fraction','y_speed_raw','y_force','y_dummy','direction','state_raw','id']

def signed(v): return v-256 if v>=128 else v

def decode(r,slot):
    if not r[15+slot] or r[22+slot] not in (10,20): return None
    return [r[0x6e+slot]*256+r[0x87+slot],r[0xcf+slot]+(r[0xb6+slot]-1)*256,
        signed(r[0x58+slot]),r[0x401+slot],signed(r[0xa0+slot]),r[0x434+slot],r[0x417+slot],
        r[0x46+slot],r[0x1e+slot],r[22+slot]]

def compare(reference,actual,output):
    rows=[json.loads(l) for l in reference.read_text().splitlines()]
    actual_rows=[json.loads(l) for l in actual.read_text().splitlines()]
    mismatch_count=0;first=[];active=0
    for f,row in enumerate(rows):
        r=bytes.fromhex(row['ram_hex']);a=actual_rows[f] if f<len(actual_rows) else []
        for slot in range(5):
            expected=decode(r,slot);value=a[slot] if slot<len(a) else 'missing'
            if expected is not None: active+=1
            if value!=expected:
                mismatch_count+=1
                if len(first)<20: first.append(dict(frame=f,slot=slot,reference=expected,actual=value))
    report=dict(passed=mismatch_count==0 and len(rows)==len(actual_rows),
        frames=len(rows),actual_frames=len(actual_rows),slot_snapshots=len(rows)*5,
        active_slot_snapshots=active,fields=FIELDS,mismatched_slots=mismatch_count,first_mismatches=first,
        reference_sha256=sha256_file(reference),actual_sha256=sha256_file(actual),
        scope='fish identity, active slots and movement registers only; not graphics/OAM/audio/whole-level acceptance')
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(report,indent=2));return report['passed']

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference',type=Path,required=True);parser.add_argument('--actual',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    raise SystemExit(0 if compare(args.reference,args.actual,args.output) else 1)
