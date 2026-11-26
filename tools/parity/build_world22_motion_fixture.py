"""Build test-only expected water motion from independently replayed ROM traces."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from common import load_movie, expand_input_masks, sha256_file

ROOT=Path(__file__).resolve().parents[2]
FIELDS=['x','y','x_speed_raw','y_speed_raw','x_acceleration_fraction',
        'x_position_fraction','y_move_force','y_move_dummy','grounded',
        'facing_direction_raw','moving_direction_raw']


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case',action='append',nargs=2,metavar=('MOVIE','REFERENCE'),required=True)
    args=parser.parse_args();cases=[];manifest=[]
    for movie_name,ref_name in args.case:
        movie_path=Path(movie_name);movie=load_movie(movie_path);ref=Path(ref_name)
        proof=json.loads((ref/'continuous-video/proof.json').read_text(encoding='utf-8'))
        if (movie.get('world'),movie.get('level'))!=(2,2) or not proof['passed'] or proof['movie_sha256']!=sha256_file(movie_path):
            raise ValueError('reference is not a verified replay of this water movie')
        state_path=ref/'state.jsonl'
        states=[json.loads(line) for line in state_path.read_text(encoding='utf-8').splitlines()]
        if len(states)!=movie['frames']: raise ValueError('incomplete state trace')
        rows=[]
        for f,(mask,state) in enumerate(zip(expand_input_masks(movie),states)):
            if state['frame']!=f or (state['world'],state['level'])!=(2,2):
                raise ValueError('invalid frame or level in reference')
            rows.append([mask]+[int(state['player'][key]) for key in FIELDS]+[state['camera_x']])
        cases.append(rows)
        manifest.append(dict(movie=movie_path.relative_to(ROOT).as_posix() if movie_path.is_absolute() else movie_path.as_posix(),
            movie_sha256=sha256_file(movie_path),state_sha256=sha256_file(state_path),frames=len(rows)))
    output=ROOT/'tests/fixtures/world22_motion.nut'
    output.write_text('// Test-only ROM-derived motion; never read by game runtime.\nWORLD22_MOTION_CASES <- [\n'+
        ',\n'.join('[\n'+',\n'.join(json.dumps(row,separators=(',',':')) for row in rows)+'\n]' for rows in cases)+'\n];\n',encoding='utf-8',newline='\n')
    (output.with_suffix('.json')).write_text(json.dumps(dict(schema='world22-motion-fixture-v1',
        scope='player motion and camera only; not image/audio/enemy/whole-level acceptance',
        fields=['input_mask']+FIELDS+['camera_x'],cases=manifest,fixture_sha256=sha256_file(output)),indent=2)+'\n',encoding='utf-8')
    print(f'wrote {sum(len(rows) for rows in cases)} expected frames')


if __name__=='__main__': main()
