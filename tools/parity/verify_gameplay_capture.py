"""Check all-frame native playback against the independently replayed gameplay route.

This compares two host execution paths, not the original NES or its pixels/audio.
"""
from pathlib import Path
import argparse, hashlib, json, math
from PIL import Image


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--gameplay',type=Path,required=True)
    p.add_argument('--actual',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args()
    cpu=[json.loads(l) for l in (args.gameplay/'state.jsonl').read_text().splitlines()]
    native=[json.loads(l) for l in (args.actual/'state.jsonl').read_text().splitlines()]
    baseline=json.loads((args.gameplay/'summary.json').read_text())
    manifest=json.loads((args.actual/'manifest.json').read_text())
    differences=[]
    for f,(expected,actual) in enumerate(zip(cpu[1:],native)):
        actual_fields={k:actual[k] for k in ('world','level','state','lives')}
        actual_fields.update(x=actual['player']['x'],y=actual['player']['y'])
        for key,value in actual_fields.items():
            want=expected[key]
            # parityStateJson encodes the OAM-origin Y as an unsigned byte.
            # Headless replay records the full body-origin Y (small body +16).
            if key=='y':want=(math.floor(expected['y'])-(0 if actual['player']['big'] else 16))&255
            if value!=want:differences.append(dict(frame=f,field=key,expected=want,actual=value))
    count=len(cpu)-1
    expected_names=[f'frame-{f:06d}.png' for f in range(count)]
    files=sorted((args.actual/'frames').glob('frame-*.png'))
    images_valid=[f.name for f in files]==expected_names
    invalid=[]
    for file in files:
        try:
            with Image.open(file) as im:
                if im.size not in ((256,240),(768,720)):raise ValueError('unexpected dimensions')
                im.verify()
        except (OSError,ValueError) as error:invalid.append(dict(file=file.name,error=str(error)))
    complete=(len(native)==count and [s['frame'] for s in native]==list(range(count)))
    passed=bool(baseline['passed'] and complete and images_valid and not invalid and not differences and not manifest.get('runtime_errors'))
    report=dict(passed=passed,frames=count,captured_frames=len(files),complete_states=complete,
        complete_images=images_valid,invalid_images=invalid,difference_count=len(differences),first_differences=differences[:20],
        baseline_movie_sha256=baseline['movie_sha256'],capture_movie_sha256=manifest['movie_sha256'],
        runtime_sources_sha256=baseline.get('runtime_sources_sha256'),
        scope='native full-frame gameplay versus headless normal-entry replay; not original-ROM pixel/state/audio acceptance')
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report));return 0 if passed else 1


if __name__=='__main__':raise SystemExit(main())
