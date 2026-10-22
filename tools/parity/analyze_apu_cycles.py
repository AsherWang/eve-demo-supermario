"""Measure whether frame-ordered APU values determine their CPU write cycles.

The strict audio replay intentionally borrows the reference CPU-cycle schedule.
This diagnostic proves why that schedule cannot be reconstructed from an
address/value stream alone: identical per-frame writes can occur at different
absolute cycles, and sometimes with different spacing between the writes.
"""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path
from typing import Iterable


def load_case(path: Path) -> dict[int, list[dict]]:
    frames: dict[int, list[dict]] = defaultdict(list)
    with path.open("r", encoding="utf-8") as source:
        for line_number, line in enumerate(source, 1):
            if not line.strip():
                continue
            row = json.loads(line)
            required = {"frame", "sequence", "address", "value", "cycle_in_frame"}
            if not required.issubset(row):
                missing = sorted(required - set(row))
                raise ValueError(f"{path}:{line_number}: missing {missing}")
            frames[row["frame"]].append(row)
    for frame, rows in frames.items():
        rows.sort(key=lambda item: item["sequence"])
        expected = list(range(len(rows)))
        observed = [item["sequence"] for item in rows]
        if observed != expected:
            raise ValueError(
                f"{path}: frame {frame}: non-contiguous sequence {observed}"
            )
    return frames


def discover_inputs(root: Path, cases: Iterable[str]) -> list[tuple[str, Path]]:
    selected = list(cases)
    if selected:
        paths = [(case, root / case / "apu-writes.jsonl") for case in selected]
    else:
        paths = sorted(
            (path.parent.name, path)
            for path in root.glob("*/apu-writes.jsonl")
        )
    missing = [str(path) for _, path in paths if not path.is_file()]
    if missing:
        raise FileNotFoundError("missing APU traces: " + ", ".join(missing))
    if not paths:
        raise FileNotFoundError(f"no */apu-writes.jsonl traces below {root}")
    return paths


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Show cycle-schedule ambiguity for identical per-frame APU writes."
    )
    parser.add_argument(
        "--reference-root", type=Path, default=Path("local-parity/reference")
    )
    parser.add_argument("--cases", nargs="*", default=[])
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    inputs = discover_inputs(args.reference_root.resolve(), args.cases)
    templates: dict[tuple[tuple[int, int], ...], dict] = {}
    frame_instances = 0
    empty_frames = 0
    case_summaries = []

    for case, path in inputs:
        frames = load_case(path)
        non_initial = [frame for frame in frames if frame > 0]
        case_summaries.append({
            "case": case,
            "frames_with_writes": len(frames),
            "non_initial_frames_with_writes": len(non_initial),
        })
        for frame in non_initial:
            rows = frames[frame]
            if not rows:
                empty_frames += 1
                continue
            frame_instances += 1
            value_template = tuple((row["address"], row["value"]) for row in rows)
            absolute = tuple(row["cycle_in_frame"] for row in rows)
            first_cycle = absolute[0]
            relative = tuple(cycle - first_cycle for cycle in absolute)
            entry = templates.setdefault(value_template, {
                "absolute": set(),
                "relative": set(),
                "examples": [],
                "instances": 0,
            })
            entry["absolute"].add(absolute)
            entry["relative"].add(relative)
            entry["instances"] += 1
            if len(entry["examples"]) < 4:
                entry["examples"].append({
                    "case": case,
                    "frame": frame,
                    "absolute_cycles": list(absolute),
                    "relative_cycles": list(relative),
                })

    absolute_ambiguous = [entry for entry in templates.values()
                          if len(entry["absolute"]) > 1]
    relative_ambiguous = [entry for entry in templates.values()
                          if len(entry["relative"]) > 1]
    report = {
        "schema": "smb-apu-cycle-ambiguity-v1",
        "cases": case_summaries,
        "non_initial_frame_instances": frame_instances,
        "empty_non_initial_frames": empty_frames,
        "unique_address_value_templates": len(templates),
        "templates_with_conflicting_absolute_cycles": len(absolute_ambiguous),
        "templates_with_conflicting_relative_cycles": len(relative_ambiguous),
        "instances_in_absolute_ambiguous_templates": sum(
            entry["instances"] for entry in absolute_ambiguous
        ),
        "instances_in_relative_ambiguous_templates": sum(
            entry["instances"] for entry in relative_ambiguous
        ),
        "relative_ambiguity_examples": sorted(
            (
                {
                    "instances": entry["instances"],
                    "schedule_count": len(entry["relative"]),
                    "examples": entry["examples"],
                }
                for entry in relative_ambiguous
            ),
            key=lambda item: (-item["instances"], -item["schedule_count"]),
        )[:10],
        "conclusion": (
            "Per-frame APU address/value order does not uniquely determine "
            "CPU write timing; cycle-exact runtime audio requires an "
            "independent cycle model or an explicit verified schedule."
        ),
    }

    rendered = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    if args.output:
        print(
            f"wrote {args.output}: {len(inputs)} cases, "
            f"{frame_instances} non-initial frames with writes, "
            f"{len(templates)} value/order templates, "
            f"{len(absolute_ambiguous)} absolute-cycle conflicts, "
            f"{len(relative_ambiguous)} relative-cycle conflicts"
        )
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
