"""Build exact active-fish register-pair diagnostics from a verified ROM trace."""
from pathlib import Path
import argparse
import json
import hashlib
from common import sha256_file
from run_reference import EXPECTED_ROM_SHA256

ROOT=Path(__file__).resolve().parents[2]

def decode(r,s):
    return [r[0x6e+s]*256+r[0x87+s],r[0xcf+s]+(r[0xb6+s]-1)*256,
            r[0x58+s],r[0x401+s],r[0xa0+s],r[0x434+s],r[0x417+s]]

def build(reference,movie):
    summary=json.loads((reference/'summary.json').read_text())
    canonical_movie=movie.read_bytes().replace(b'\r\n',b'\n')
    captured_forms={hashlib.sha256(canonical_movie).hexdigest():'LF',
        hashlib.sha256(canonical_movie.replace(b'\n',b'\r\n')).hexdigest():'CRLF'}
    if summary['movie_sha256'] not in captured_forms or summary['rom_sha256']!=EXPECTED_ROM_SHA256:
        raise ValueError('stale movie or unverified ROM')
    trace=reference/'ram-trace.jsonl'
    rows=[json.loads(l) for l in trace.read_text().splitlines()]
    ram=[bytes.fromhex(row['ram_hex']) for row in rows]
    pairs=[];locations=[];spawns=[]
    for slot in range(3):
        for f in range(len(ram)-1):
            a,b=ram[f:f+2]
            if not a[15+slot] and b[15+slot] and b[22+slot]==20 and b[0xe]==8:
                spawns.append([slot,b[0x6d]*256+b[0x86],b[0x57],list(b[0x7a7:0x7ae]),
                    a[0x417+slot],decode(b,slot),b[0x46+slot],b[0x78f]])
            if all(r[15+slot] and r[22+slot]==20 and r[0x1e+slot]==0 and
                   r[0xe]==8 and r[0x747]==0 for r in (a,b)):
                pairs.append([decode(a,slot),decode(b,slot)]);locations.append([f,slot])
    path=ROOT/'tests/fixtures/world23_fish_motion.nut'
    path.write_text('// Exact consecutive active ROM fish register pairs; diagnostics only.\nWORLD23_FISH_MOTION <- [\n'+
        ',\n'.join(json.dumps(p,separators=(',',':')) for p in pairs)+'\n];\nWORLD23_FISH_SPAWNS <- '+
        json.dumps(spawns,separators=(',',':'))+';\n',encoding='utf-8', newline='\n')
    manifest=dict(rom_sha256=EXPECTED_ROM_SHA256,movie=str(movie.resolve().relative_to(ROOT)).replace('\\','/'),
        movie_sha256=hashlib.sha256(canonical_movie).hexdigest(),
        capture_movie_sha256=summary['movie_sha256'],capture_movie_line_endings=captured_forms[summary['movie_sha256']],
        trace_sha256=sha256_file(trace),fixture_sha256=sha256_file(path),
        pairs=len(pairs),spawns=len(spawns),fields=['x','y','x_speed_raw','x_fraction','y_speed_raw','y_force','y_dummy'],
        source_frames_and_slots=locations,scope='isolated fish motion, not spawn timing/contact/whole-level parity')
    (ROOT/'tests/fixtures/world23_fish_motion.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8', newline='\n')
    print(f'{len(pairs)} exact register pairs')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--reference',type=Path,required=True)
    parser.add_argument('--movie',type=Path,required=True);args=parser.parse_args();build(args.reference,args.movie)
