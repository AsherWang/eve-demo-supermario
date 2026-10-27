"""Recover deterministic video without changing any comparison inputs or frames."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil

from common import load_movie, mesen_section_input_arguments, sha256_file
from extract_reference_state import decode_line
from run_reference import build_capture_lua, build_origin_lua, run_command


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rom', type=Path, required=True)
    parser.add_argument('--movie', type=Path, required=True)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--origin-frame', type=int, required=True)
    parser.add_argument('--mesen-agent', type=Path, required=True)
    args = parser.parse_args()
    movie = load_movie(args.movie)
    reference = args.reference.resolve()
    output = reference / 'continuous-video'
    (output / 'frames').mkdir(parents=True, exist_ok=True)
    warmup = args.origin_frame + 1
    script = output / 'capture.lua'
    script.write_text(build_origin_lua(movie.get('level', 1)) + '\n' +
                      build_capture_lua(output, movie, warmup), encoding='utf-8')
    command = [str(args.mesen_agent.resolve()), str(args.rom.resolve()),
               '--home', str(output / 'mesen-home'), '--frames', str(warmup + movie['frames']),
               '--timeout', '120', '--lua', str(script), '--lua-allow-io']
    command += mesen_section_input_arguments(movie.get('reference_bootstrap', {}).get('inputs', []))
    command += mesen_section_input_arguments(movie.get('inputs', []), offset=warmup)
    result, summaries = run_command(command, output / 'events.jsonl', output / 'stderr.log')
    if result.returncode or not summaries or not summaries[-1].get('ok'):
        return 1

    def states(path):
        return [decode_line(line) for line in path.read_text().splitlines() if line.strip()]

    def writes(path):
        return [(row['frame'], row['address'], row['value'])
                for row in map(json.loads, path.read_text().splitlines())]

    original_states = states(reference / 'ram-trace.jsonl')
    video_states = states(output / 'ram-trace.jsonl')
    original_writes = writes(reference / 'apu-writes.jsonl')
    video_writes = writes(output / 'apu-writes.jsonl')
    # Comparison frame zero observes the saved origin without advancing its
    # controller input. The continuous boot has just produced that origin,
    # so its frame-zero writes are already represented by origin.mss, rather
    # than new comparison writes. Keep them in the raw evidence file.
    boundary_writes = [row for row in video_writes if row[0] == 0]
    comparison_writes = video_writes
    if not any(row[0] == 0 for row in original_writes):
        comparison_writes = [row for row in video_writes if row[0] != 0]
    expected_frames = movie.get('capture_frames', list(range(movie['frames'])))
    report = {
        'schema': 'smb-continuous-video-proof-v1',
        'state_frames': len(video_states),
        'states_equal': original_states == video_states and len(video_states) == movie['frames'],
        'apu_writes_equal': original_writes == comparison_writes,
        'pre_origin_write_count': len(boundary_writes),
        'capture_frames_complete': all((output / 'frames' / f'frame-{f:06d}.png').is_file()
                                       for f in expected_frames),
        'bootstrap_frames': warmup,
        'movie_sha256': sha256_file(args.movie),
    }
    report['passed'] = all(report[key] for key in
                           ('states_equal', 'apu_writes_equal', 'capture_frames_complete'))
    (output / 'proof.json').write_text(json.dumps(report, indent=2) + '\n')
    if not report['passed']:
        print(f'Continuous video verification failed: {output / "proof.json"}')
        return 1
    for frame in expected_frames:
        name = f'frame-{frame:06d}.png'
        shutil.copy2(output / 'frames' / name, reference / 'frames' / name)
    manifest_path = reference / 'manifest.json'
    if manifest_path.is_file():
        manifest = json.loads(manifest_path.read_text())
        manifest['continuous_video_passed'] = True
        manifest['continuous_video_proof_sha256'] = sha256_file(output / 'proof.json')
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Continuous video: {movie["frames"]} identical states; comparison APU writes identical')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
