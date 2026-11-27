"""Audit raw normal-entry World 2-4 reference route; never promotes host parity."""
import argparse,json
from pathlib import Path
from common import sha256_file,load_movie

def verify(movie_path,folder):
    movie=load_movie(movie_path)
    manifest=json.loads((folder/'manifest.json').read_text())
    rows=[json.loads(line) for line in (folder/'ram-trace.jsonl').read_text().splitlines()]
    ram=[bytes.fromhex(row['ram_hex']) for row in rows]
    first=ram[0];last=ram[-1]
    def find(predicate):return next((i for i,r in enumerate(ram) if predicate(r)),None)
    milestones=dict(axe=find(lambda r:r[0x770]==2),
        retainer=find(lambda r:r[0x770]==2 and r[0x772]==3),
        next_world=find(lambda r:r[0x75f]==2))
    initial=first[0x75f]==1 and first[0x75c]==3 and first[0x750]==0x62 and first[0x6d]*256+first[0x86]==40 and first[0xce]==80 and first[0x770]==1 and first[0xe]==8
    deaths=[i for i,r in enumerate(ram) if r[0xe]==11 or r[0x75a]!=first[0x75a]]
    captures=[i for i in range(movie['frames']) if (folder/'frames'/f'frame-{i:06d}.png').is_file()]
    checks=dict(normal_entrance=initial,frames=len(rows)==movie['frames'] and [r['frame'] for r in rows]==list(range(movie['frames'])),
        full_video=len(captures)==movie['frames'],movie_hash=manifest['movie_sha256']==sha256_file(movie_path),
        no_death_or_life_loss=not deaths,axe=milestones['axe'] is not None,
        retainer=milestones['retainer'] is not None,next_world=milestones['next_world'] is not None,
        continuous_video=manifest.get('continuous_video_passed') is True)
    result=dict(schema='world24-original-route-v1',passed=all(checks.values()),checks=checks,
        movie_sha256=sha256_file(movie_path),milestones=milestones,death_frames=deaths,
        final=dict(world=last[0x75f]+1,level=last[0x75c]+1,x=last[0x6d]*256+last[0x86],y=last[0xce],oper_mode=last[0x770],oper_task=last[0x772],lives=last[0x75a]+1),
        limitation='Original-only route audit, not six-gate host acceptance')
    (folder/'verification.json').write_text(json.dumps(result,indent=2)+'\n', newline="\n")
    return result
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--movie',type=Path,required=True);p.add_argument('--reference',type=Path,required=True)
    a=p.parse_args();r=verify(a.movie,a.reference);print(json.dumps(r,indent=2));raise SystemExit(0 if r['passed'] else 1)
