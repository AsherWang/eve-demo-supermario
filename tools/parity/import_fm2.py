from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


# FCEUX FM2 controller text is ordered R, L, D, U, Start, Select, B, A.
FM2_BUTTONS = ("right", "left", "down", "up", "start", "select", "b", "a")


def read_masks(path: Path) -> list[tuple[str, ...]]:
    frames: list[tuple[str, ...]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|"):
            continue
        fields = line.split("|")
        if len(fields) < 3 or len(fields[2]) != 8:
            continue
        state = fields[2]
        frames.append(tuple(name for char, name in zip(state, FM2_BUTTONS) if char != "."))
    if not frames:
        raise ValueError(f"no FM2 input frames found in {path}")
    return frames


def compress(states: list[tuple[str, ...]], start: int, count: int) -> list[dict]:
    end = min(start + count, len(states))
    records: list[dict] = []
    run_start = start
    previous: tuple[str, ...] | None = None
    for absolute in range(start, end + 1):
        current = states[absolute] if absolute < end else None
        if current == previous:
            continue
        if previous:
            records.append({
                "port": 0,
                "start": run_start - start,
                "end": absolute - start - 1,
                "buttons": list(previous),
            })
        run_start = absolute
        previous = current
    return records


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert a text FCEUX FM2 into a parity movie.")
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--comparison-start", type=int, required=True)
    parser.add_argument("--frames", type=int, required=True)
    parser.add_argument("--bootstrap-frames", type=int, default=600)
    parser.add_argument(
        "--bootstrap-mode",
        choices=("canonical", "source"),
        default="canonical",
        help="Use the harness' canonical Start pulse or the FM2 power-on inputs.",
    )
    parser.add_argument("--source-url")
    parser.add_argument("--author")
    args = parser.parse_args()

    source = args.source.resolve()
    states = read_masks(source)
    if args.comparison_start + args.frames > len(states):
        parser.error("requested comparison slice exceeds the FM2 input log")
    source_sha1 = hashlib.sha1(source.read_bytes()).hexdigest()
    if args.bootstrap_mode == "source":
        bootstrap_inputs = compress(states, 0, args.bootstrap_frames)
    else:
        # Keep every gameplay case on the same measured first-control state.
        # The imported FM2 is used only for comparison-period controller input.
        bootstrap_inputs = [{
            "port": 0,
            "start": 40,
            "end": 46,
            "buttons": ["start"],
        }]
    movie = {
        "schema": "smb-parity-movie-v1",
        "name": args.name,
        "description": "Natural World 1-1 input imported from the attributed FCEUX FM2 fixture.",
        "frames": args.frames,
        "reference_bootstrap": {
            "frames": args.bootstrap_frames,
            "inputs": bootstrap_inputs,
        },
        "inputs": compress(states, args.comparison_start, args.frames),
        "capture_frames": sorted(set(
            list(range(0, args.frames, 60)) +
            [0, 7, 33, 109, 375, 579, 932, 1109, args.frames - 1]
        )),
        "provenance": {
            "format": "FCEUX FM2 controller input only",
            "source_sha1": source_sha1,
            "source_url": args.source_url,
            "author": args.author,
            "comparison_start_frame": args.comparison_start,
            "bootstrap_mode": args.bootstrap_mode,
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(movie, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {args.frames} comparison frames to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
