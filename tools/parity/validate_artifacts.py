from __future__ import annotations

import argparse
import html
import json
import wave
from pathlib import Path
from typing import Any

from common import load_movie, sha256_file


def load_json(path: Path, errors: list[str]) -> dict[str, Any] | None:
    if not path.is_file():
        errors.append(f"missing file: {path}")
        return None
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"invalid JSON {path}: {exc}")
        return None
    if not isinstance(value, dict):
        errors.append(f"JSON root is not an object: {path}")
        return None
    return value


def validate_manifest(
    path: Path,
    producer: str,
    movie: dict[str, Any],
    movie_hash: str,
    errors: list[str],
) -> dict[str, Any] | None:
    manifest = load_json(path, errors)
    if manifest is None:
        return None
    expected = {
        "schema": "smb-parity-artifact-v1",
        "producer": producer,
        "movie": movie["name"],
        "movie_sha256": movie_hash,
        "comparison_frames": movie["frames"],
    }
    for field, value in expected.items():
        if manifest.get(field) != value:
            errors.append(
                f"{path.name} {field}: expected {value!r}, got {manifest.get(field)!r}"
            )
    return manifest


def validate_frame_set(
    directory: Path, expected: set[int], label: str, errors: list[str]
) -> dict[str, Any]:
    observed: set[int] = set()
    malformed: list[str] = []
    if not directory.is_dir():
        errors.append(f"missing directory: {directory}")
    else:
        for path in directory.glob("frame-*.png"):
            try:
                observed.add(int(path.stem.removeprefix("frame-")))
            except ValueError:
                malformed.append(path.name)
    missing = sorted(expected - observed)
    extra = sorted(observed - expected)
    if malformed:
        errors.append(f"{label} malformed frame names: {malformed}")
    if missing:
        errors.append(f"{label} missing capture frames: {missing}")
    if extra:
        errors.append(f"{label} unexpected capture frames: {extra}")
    return {
        "expected": len(expected),
        "observed": len(observed),
        "missing": missing,
        "extra": extra,
    }


def validate_jsonl_timeline(
    path: Path, frame_count: int, label: str, errors: list[str]
) -> dict[str, Any]:
    frames: list[int] = []
    invalid_rows = 0
    if not path.is_file():
        errors.append(f"missing file: {path}")
        return {"rows": 0, "invalid_rows": 0, "missing": list(range(frame_count)), "duplicates": []}
    with path.open("r", encoding="utf-8") as source:
        for line_number, line in enumerate(source, 1):
            if not line.strip():
                continue
            try:
                row = json.loads(line)
                frame = row["frame"]
                if not isinstance(frame, int):
                    raise ValueError("frame is not an integer")
                frames.append(frame)
            except (json.JSONDecodeError, KeyError, TypeError, ValueError) as exc:
                invalid_rows += 1
                errors.append(f"{label} invalid row {line_number}: {exc}")
    counts: dict[int, int] = {}
    for frame in frames:
        counts[frame] = counts.get(frame, 0) + 1
    expected = set(range(frame_count))
    observed = set(frames)
    missing = sorted(expected - observed)
    extra = sorted(observed - expected)
    duplicates = sorted(frame for frame, count in counts.items() if count > 1)
    if missing:
        errors.append(f"{label} missing timeline frames: {missing}")
    if extra:
        errors.append(f"{label} out-of-range frames: {extra}")
    if duplicates:
        errors.append(f"{label} duplicate frames: {duplicates}")
    return {
        "rows": len(frames),
        "invalid_rows": invalid_rows,
        "missing": missing,
        "extra": extra,
        "duplicates": duplicates,
    }


def validate_event_trace(path: Path, frame_count: int, label: str, errors: list[str]) -> dict[str, Any]:
    rows = 0
    invalid_rows = 0
    if not path.is_file():
        errors.append(f"missing file: {path}")
        return {"rows": 0, "invalid_rows": 0}
    with path.open("r", encoding="utf-8") as source:
        for line_number, line in enumerate(source, 1):
            if not line.strip():
                continue
            rows += 1
            try:
                event = json.loads(line)
                frame = event["frame"]
                sequence = event["sequence"]
                if not isinstance(frame, int) or not 0 <= frame < frame_count:
                    raise ValueError(f"frame {frame!r} outside [0,{frame_count})")
                if not isinstance(sequence, int):
                    raise ValueError("sequence is not an integer")
            except (json.JSONDecodeError, KeyError, TypeError, ValueError) as exc:
                invalid_rows += 1
                errors.append(f"{label} invalid row {line_number}: {exc}")
    return {"rows": rows, "invalid_rows": invalid_rows}


def validate_frame_timing(
    path: Path, frame_count: int, label: str, errors: list[str]
) -> dict[str, Any]:
    rows: list[dict[str, int]] = []
    if not path.is_file():
        errors.append(f"missing file: {path}")
        return {"rows": 0, "invalid_rows": 0, "cycle_counts": []}
    invalid_rows = 0
    with path.open("r", encoding="utf-8") as source:
        for line_number, line in enumerate(source, 1):
            if not line.strip():
                continue
            try:
                row = json.loads(line)
                required = (
                    "frame", "cpu_cycle_start", "cpu_cycle_end", "cpu_cycles",
                    "master_clock_start", "master_clock_end",
                )
                if not all(isinstance(row.get(field), int) for field in required):
                    raise ValueError("timing fields must all be integers")
                if row["frame"] != len(rows):
                    raise ValueError(f"expected frame {len(rows)}, got {row['frame']}")
                if row["cpu_cycle_end"] - row["cpu_cycle_start"] != row["cpu_cycles"]:
                    raise ValueError("cpu_cycles does not match start/end delta")
                if row["cpu_cycles"] <= 0:
                    raise ValueError("cpu_cycles must be positive")
                if rows and row["cpu_cycle_start"] != rows[-1]["cpu_cycle_end"]:
                    raise ValueError("CPU cycle timeline is not contiguous")
                rows.append(row)
            except (json.JSONDecodeError, TypeError, ValueError) as exc:
                invalid_rows += 1
                errors.append(f"{label} invalid row {line_number}: {exc}")
    if len(rows) != frame_count:
        errors.append(f"{label} expected {frame_count} rows, got {len(rows)}")
    return {
        "rows": len(rows),
        "invalid_rows": invalid_rows,
        "cycle_counts": sorted({row["cpu_cycles"] for row in rows}),
    }


def validate_cycle_stamped_apu_trace(
    path: Path, frame_count: int, label: str, errors: list[str]
) -> dict[str, Any]:
    rows = 0
    invalid_rows = 0
    if not path.is_file():
        errors.append(f"missing file: {path}")
        return {"rows": 0, "invalid_rows": 0}
    with path.open("r", encoding="utf-8") as source:
        for line_number, line in enumerate(source, 1):
            if not line.strip():
                continue
            rows += 1
            try:
                row = json.loads(line)
                required = (
                    "frame", "sequence", "address", "value", "cpu_cycle",
                    "master_clock", "cycle_in_frame",
                )
                if not all(isinstance(row.get(field), int) for field in required):
                    raise ValueError("cycle-stamped APU fields must all be integers")
                if not 0 <= row["frame"] <= frame_count:
                    raise ValueError(f"frame {row['frame']} outside [0,{frame_count}]")
                if row["cycle_in_frame"] < 0:
                    raise ValueError("cycle_in_frame must not be negative")
            except (json.JSONDecodeError, TypeError, ValueError) as exc:
                invalid_rows += 1
                errors.append(f"{label} invalid row {line_number}: {exc}")
    return {"rows": rows, "invalid_rows": invalid_rows}


def validate_wave(path: Path, label: str, errors: list[str]) -> dict[str, Any]:
    if not path.is_file():
        errors.append(f"missing file: {path}")
        return {"sample_frames": 0}
    try:
        with wave.open(str(path), "rb") as source:
            result = {
                "channels": source.getnchannels(),
                "sample_width": source.getsampwidth(),
                "sample_rate": source.getframerate(),
                "sample_frames": source.getnframes(),
            }
    except (OSError, wave.Error) as exc:
        errors.append(f"invalid WAV {label}: {exc}")
        return {"sample_frames": 0}
    if result["channels"] <= 0 or result["sample_width"] != 2 or result["sample_frames"] <= 0:
        errors.append(f"invalid WAV format {label}: {result}")
    return result


def count_jsonl_rows(path: Path) -> int:
    with path.open("r", encoding="utf-8") as source:
        return sum(1 for line in source if line.strip())


def validate_actual_audio_manifest(
    path: Path,
    movie_hash: str,
    apu_writes: Path,
    audio: Path,
    errors: list[str],
) -> dict[str, Any]:
    manifest = load_json(path, errors)
    if manifest is None:
        return {"valid": False}
    expected = {
        "schema": "smb-actual-apu-audio-v1",
        "renderer": "mesen-2a03-cycle-carrier",
        "cycle_schedule": "reference ROM execution",
        "register_values": "EVEngine-side source-derived APU model",
        "movie_sha256": movie_hash,
    }
    for field, value in expected.items():
        if manifest.get(field) != value:
            errors.append(
                f"{path.name} {field}: expected {value!r}, got {manifest.get(field)!r}"
            )
    if apu_writes.is_file():
        write_count = count_jsonl_rows(apu_writes)
        if manifest.get("apu_writes_sha256") != sha256_file(apu_writes):
            errors.append(f"{path.name} apu_writes_sha256 does not match {apu_writes}")
    else:
        write_count = 0
    if audio.is_file() and manifest.get("wav_sha256") != sha256_file(audio):
        errors.append(f"{path.name} wav_sha256 does not match {audio}")
    statuses = manifest.get("replay_statuses")
    if not isinstance(statuses, dict):
        errors.append(f"{path.name} replay_statuses is not an object")
        statuses = {}
    elif set(statuses) != {"injected"}:
        errors.append(
            f"{path.name} replay_statuses must contain only 'injected', got {statuses}"
        )
    if statuses.get("injected") != write_count:
        errors.append(
            f"{path.name} injected write count: expected {write_count}, "
            f"got {statuses.get('injected')!r}"
        )
    return {
        "valid": all(manifest.get(field) == value for field, value in expected.items())
        and set(statuses) == {"injected"}
        and statuses.get("injected") == write_count,
        "modeled_writes": write_count,
        "replay_statuses": statuses,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate ROM/reference and EVEngine artifact contracts.")
    parser.add_argument("--movie", type=Path, required=True)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--actual", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    movie_path = args.movie.resolve()
    movie = load_movie(movie_path)
    movie_hash = sha256_file(movie_path)
    reference = args.reference.resolve()
    actual = args.actual.resolve()
    errors: list[str] = []
    reference_manifest = validate_manifest(
        reference / "manifest.json", "mesen-agent-reference", movie, movie_hash, errors
    )
    actual_manifest = validate_manifest(
        actual / "manifest.json", "evengine-remake", movie, movie_hash, errors
    )
    expected_captures = set(movie.get("capture_frames", range(movie["frames"])))
    checks = {
        "reference_frames": validate_frame_set(
            reference / "frames", expected_captures, "reference frames", errors
        ),
        "actual_frames": validate_frame_set(
            actual / "frames", expected_captures, "actual frames", errors
        ),
        "reference_timeline": validate_jsonl_timeline(
            reference / "ram-trace.jsonl", movie["frames"], "reference RAM trace", errors
        ),
        "actual_timeline": validate_jsonl_timeline(
            actual / "state.jsonl", movie["frames"], "actual state trace", errors
        ),
        "reference_events": validate_event_trace(
            reference / "events-semantic.jsonl", movie["frames"], "reference events", errors
        ),
        "actual_events": validate_event_trace(
            actual / "events.jsonl", movie["frames"], "actual events", errors
        ),
        "reference_apu_writes": validate_event_trace(
            reference / "apu-writes.jsonl", movie["frames"] + 1,
            "reference APU writes", errors
        ),
        "reference_apu_cycles": validate_cycle_stamped_apu_trace(
            reference / "apu-writes.jsonl", movie["frames"],
            "reference cycle-stamped APU writes", errors
        ),
        "reference_frame_timing": validate_frame_timing(
            reference / "frame-timing.jsonl", movie["frames"],
            "reference frame timing", errors
        ),
        "actual_apu_writes": validate_event_trace(
            actual / "apu-writes.jsonl", movie["frames"], "actual APU writes", errors
        ),
        "reference_audio": validate_wave(reference / "audio.wav", "reference audio", errors),
        "actual_audio": validate_wave(actual / "audio.wav", "actual audio", errors),
    }
    checks["actual_audio_replay"] = validate_actual_audio_manifest(
        actual / "audio.manifest.json",
        movie_hash,
        actual / "apu-writes.jsonl",
        actual / "audio.wav",
        errors,
    )
    if reference_manifest is not None and reference_manifest.get("rom_sha256") is None:
        errors.append("reference manifest has no rom_sha256")
    if not (reference / "origin-state.json").is_file():
        errors.append(f"missing file: {reference / 'origin-state.json'}")
    report = {
        "schema": "smb-parity-artifact-validation-v1",
        "passed": not errors,
        "movie": movie["name"],
        "movie_sha256": movie_hash,
        "comparison_frames": movie["frames"],
        "capture_frames": sorted(expected_captures),
        "checks": checks,
        "errors": errors,
    }
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / "artifact-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    error_items = "".join(f"<li>{html.escape(error)}</li>" for error in errors)
    (output / "artifact-report.html").write_text(
        "<!doctype html><meta charset=\"utf-8\"><title>SMB artifact contract</title>"
        f"<h1>SMB 产物契约</h1><p>{'通过' if report['passed'] else '失败'}</p>"
        f"<p>录像：{html.escape(movie['name'])}；比较帧：{movie['frames']}；"
        f"截图检查点：{len(expected_captures)}</p>"
        f"<ul>{error_items if error_items else '<li>两端产物完整且来自同一录像。</li>'}</ul>",
        encoding="utf-8",
    )
    print(f"{'PASS' if report['passed'] else 'FAIL'}: {output / 'artifact-report.html'}")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
