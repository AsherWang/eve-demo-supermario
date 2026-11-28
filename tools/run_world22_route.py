"""Replay the complete 2-2 input-only host route; never claims strict ROM parity."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/parity'))
from common import expand_input_masks, load_movie
from tool_paths import tool_path

DEFAULT_MOVIE = ROOT / 'tests/parity/movies/world-2-2-normal-route.json'


def route_masks(movie: dict) -> list[int]:
    if (movie.get('world'), movie.get('level'), movie.get('origin')) != (2, 2, 'normal-entrance'):
        raise ValueError('requires 2-2 normal-entrance movie')
    if movie.get('checkpoint_page', 0) != 0:
        raise ValueError('checkpoint starts are not whole routes')
    for item in movie['inputs']:
        if item.get('port', 0) != 0 or set(item['buttons']) - {'a', 'b', 'left', 'right', 'up', 'down'}:
            raise ValueError('route permits only player-one gameplay controls')
    masks = expand_input_masks(movie)
    if not masks or masks[0] != 0:
        raise ValueError('frame zero is the unmodified normal entrance')
    return masks


def run(movie_path: Path, output: Path) -> dict:
    movie = load_movie(movie_path)
    masks = route_masks(movie)
    output.mkdir(parents=True, exist_ok=True)
    source = output / 'replay.nut'
    source.write_text('''eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("main.nut");loadTexture=function(path) {return path;};loadAssets();loadWorld22Assets();PARITY_MOVIE_ENABLED=false;
dofile("tools/regression/world22_route.nut");
runWorld22WholeRoute(''' + json.dumps(masks) + ');\n', encoding='utf-8')
    result = subprocess.run([str(tool_path('eve')), 'run', '--no-window', '-r', str(source.resolve())],
                            cwd=ROOT, capture_output=True, text=True, timeout=90)
    log = result.stdout + '\n' + result.stderr
    (output / 'engine.log').write_text(log, encoding='utf-8')
    rows = [json.loads(s.removeprefix('ROUTE_STATE ')) for s in result.stdout.splitlines() if s.startswith('ROUTE_STATE ')]
    events = [json.loads(s.removeprefix('ROUTE_EVENT ')) for s in result.stdout.splitlines() if s.startswith('ROUTE_EVENT ')]
    summaries = [json.loads(s.removeprefix('WORLD22_ROUTE_OK ')) for s in result.stdout.splitlines() if s.startswith('WORLD22_ROUTE_OK ')]
    for name, data in [('state.jsonl', rows), ('route-events.jsonl', events)]:
        (output / name).write_text(''.join(json.dumps(row) + '\n' for row in data), encoding='utf-8')
    source_paths = [ROOT / 'main.nut', *sorted((ROOT / 'scripts').rglob('*.nut')),
                    ROOT / 'tools/regression/world22_route.nut']
    hashes = {str(p.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest() for p in source_paths}
    passed = (result.returncode == 0 and len(summaries) == 1 and len(rows) == len(masks)
              and [row['frame'] for row in rows] == list(range(len(masks))))
    report = dict(passed=passed, strict_parity_accepted=False,
                  scope='continuous host gameplay only; original frames/states/events/APU/audio gates are reported separately',
                  movie_sha256=hashlib.sha256(movie_path.read_bytes()).hexdigest(),
                  exit_code=result.returncode, state_rows=len(rows), route_events=events,
                  result=summaries[0] if summaries else None, source_sha256=hashes)
    (output / 'summary.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--movie', type=Path, default=DEFAULT_MOVIE)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = run(args.movie.resolve(), args.output.resolve())
    print(json.dumps({k: v for k, v in report.items() if k not in ('source_sha256', 'route_events')}, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
