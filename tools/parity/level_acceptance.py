from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

from PIL import Image


INVENTORY_SCHEMA = "smb-level-acceptance-inventory-v1"
REPORT_SCHEMA = "smb-level-acceptance-report-v1"
MOVIE_SCHEMA = "smb-parity-movie-v1"
MANIFEST_SCHEMA = "smb-parity-artifact-v1"
SUMMARY_SCHEMA = "smb-parity-case-summary-v1"
FRAME_REPORT_SCHEMA = "smb-parity-report-v1"
GATE_NAMES = ("artifacts", "frames", "states", "events", "apu", "audio")
GATE_REPORT_FILES = {
    "artifacts": "artifact-report.json",
    "frames": "report.json",
    "states": "state-report.json",
    "events": "event-report.json",
    "apu": "apu-report.json",
    "audio": "audio-report.json",
}
LOGICAL_SIZE = (256, 240)
FRAME_NAME = re.compile(r"^frame-(\d+)$")
LIMITATIONS = [
    "The tool checks file structure, hashes, report contents, and review records. "
    "It cannot prove from metadata that a reviewer observed the intended gameplay route.",
    "A complete status requires a reviewer to record entrance, transition or final-ending, "
    "and branch coverage evidence after inspecting the replay.",
]


def _load_json(path: Path, *, reasons: list[str], label: str) -> dict[str, Any] | None:
    if not path.is_file():
        reasons.append(f"{label} is missing: {path.as_posix()}")
        return None
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        reasons.append(f"{label} cannot be read as JSON: {exc}")
        return None
    if not isinstance(value, dict):
        reasons.append(f"{label} must contain a JSON object")
        return None
    return value


def _string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _zero(value: Any) -> bool:
    return _integer(value) and value == 0


def _expected_levels() -> list[tuple[int, int]]:
    return [(world, stage) for world in range(1, 9) for stage in range(1, 5)]


def _expected_capture_frames(frame_count: int) -> list[int]:
    return list(range(frame_count))


def _frame_map(directory: Path, frame_count: int, label: str, reasons: list[str]) -> dict[int, Path]:
    frames: dict[int, Path] = {}
    malformed: list[str] = []
    if not directory.is_dir():
        reasons.append(f"{label} frame directory is missing")
        return frames
    for path in sorted(directory.glob("*.png")):
        match = FRAME_NAME.match(path.stem)
        if match is None:
            malformed.append(path.name)
            continue
        frame = int(match.group(1))
        if frame in frames:
            malformed.append(path.name)
        else:
            frames[frame] = path
    expected = set(range(frame_count))
    observed = set(frames)
    if malformed:
        reasons.append(f"{label} frames have malformed filenames: {', '.join(malformed[:3])}")
    if observed != expected:
        reasons.append(
            f"{label} frames must exactly cover 0..{frame_count - 1} "
            f"(missing {len(expected - observed)}, extra {len(observed - expected)})"
        )
    return frames


def _normalized_image_sha256(path: Path) -> str:
    with Image.open(path) as source:
        image = source.convert("RGB")
    if image.size != LOGICAL_SIZE:
        width, height = image.size
        if width % LOGICAL_SIZE[0] or height % LOGICAL_SIZE[1]:
            raise ValueError(f"image size {image.size} is not a logical-screen multiple")
        if width // LOGICAL_SIZE[0] != height // LOGICAL_SIZE[1]:
            raise ValueError(f"image size {image.size} has non-uniform scaling")
        image = image.resize(LOGICAL_SIZE, Image.Resampling.NEAREST)
    return hashlib.sha256(image.tobytes()).hexdigest()


def _jsonl_rows(path: Path, label: str, reasons: list[str]) -> int | None:
    if not path.is_file():
        reasons.append(f"{label} is missing")
        return None
    try:
        return sum(1 for line in path.read_text(encoding="utf-8").splitlines() if line.strip())
    except (OSError, UnicodeError) as exc:
        reasons.append(f"{label} cannot be read: {exc}")
        return None


def _validate_frame_report(
    report: dict[str, Any],
    frame_count: int,
    reference_frames: dict[int, Path],
    actual_frames: dict[int, Path],
    reasons: list[str],
) -> None:
    if report.get("schema") != FRAME_REPORT_SCHEMA:
        reasons.append("frames report has an unexpected schema")
    if report.get("logical_size") != list(LOGICAL_SIZE):
        reasons.append("frames report logical_size must be 256x240")
    if report.get("passed") is not True:
        reasons.append("frames report is not passing")
    if not _zero(report.get("channel_tolerance")):
        reasons.append("frames report channel_tolerance must be exactly 0")
    if not _zero(report.get("max_mismatched_pixels")):
        reasons.append("frames report max_mismatched_pixels must be exactly 0")
    if not _zero(report.get("failed_frames")):
        reasons.append("frames report contains failed frames")
    if not _zero(report.get("missing_frames")):
        reasons.append("frames report contains missing frames")
    if report.get("compared_frames") != frame_count:
        reasons.append(
            "frames report compared_frames must equal the movie frame count "
            f"({frame_count})"
        )

    rows = report.get("frames")
    if not isinstance(rows, list):
        reasons.append("frames report has no per-frame list")
        return
    frame_ids = [row.get("frame") for row in rows if isinstance(row, dict)]
    expected = _expected_capture_frames(frame_count)
    if frame_ids != expected:
        reasons.append(
            "frames report must contain each frame exactly once in ascending order "
            f"(expected {frame_count}, observed {len(rows)})"
        )
        return

    frame_reasons: list[str] = []
    for row in rows:
        frame = row["frame"]
        if row.get("status") != "match":
            frame_reasons.append(f"frame {frame} is not a match")
        if row.get("mismatch_ratio") != 0:
            frame_reasons.append(f"frame {frame} has a nonzero mismatch ratio")
        if not _zero(row.get("mismatched_pixels")):
            frame_reasons.append(f"frame {frame} has mismatched pixels")
        if row.get("mean_absolute_channel_error") != 0:
            frame_reasons.append(f"frame {frame} has a nonzero mean channel error")
        if not _zero(row.get("max_channel_error")):
            frame_reasons.append(f"frame {frame} has a nonzero channel error")
        try:
            reference_sha = _normalized_image_sha256(reference_frames[frame])
            actual_sha = _normalized_image_sha256(actual_frames[frame])
        except (KeyError, OSError, ValueError) as exc:
            frame_reasons.append(f"frame {frame} capture cannot be verified: {exc}")
            continue
        if row.get("reference_sha256") != reference_sha:
            frame_reasons.append(f"frame {frame} reference hash does not match its image")
        if row.get("actual_sha256") != actual_sha:
            frame_reasons.append(f"frame {frame} actual hash does not match its image")
        if reference_sha != actual_sha and row.get("status") == "match":
            frame_reasons.append(f"frame {frame} capture hashes do not match")
        if len(frame_reasons) >= 12:
            frame_reasons.append("additional frame failures omitted")
            break
    reasons.extend(frame_reasons)


def _validate_common_manifest(
    path: Path,
    side: str,
    producer: str,
    case_id: str,
    movie_sha256: str,
    frame_count: int,
    reasons: list[str],
) -> dict[str, Any] | None:
    manifest = _load_json(path, reasons=reasons, label=f"{side} manifest")
    if manifest is None:
        return None
    if manifest.get("schema") != MANIFEST_SCHEMA:
        reasons.append(f"{side} manifest has an unexpected schema")
    if manifest.get("producer") != producer:
        reasons.append(f"{side} manifest has the wrong producer")
    if manifest.get("movie") != case_id:
        reasons.append(f"{side} manifest names a different movie")
    if manifest.get("movie_sha256") != movie_sha256:
        reasons.append(f"{side} manifest is stale for the current movie hash")
    if manifest.get("comparison_frames") != frame_count:
        reasons.append(f"{side} manifest comparison_frames does not match the movie")
    return manifest


def _validate_reference_manifest(
    path: Path, case_id: str, movie_sha256: str, frame_count: int, reasons: list[str]
) -> None:
    manifest = _validate_common_manifest(
        path, "reference", "mesen-agent-reference", case_id, movie_sha256,
        frame_count, reasons,
    )
    if manifest is None:
        return
    if manifest.get("capture_frames") != _expected_capture_frames(frame_count):
        reasons.append("reference manifest capture_frames do not cover every movie frame")
    summary = manifest.get("summary")
    if not isinstance(summary, dict) or summary.get("ok") is not True:
        reasons.append("reference manifest has no successful run summary")
    elif summary.get("frames_executed") != frame_count:
        reasons.append("reference manifest summary does not cover every movie frame")
    if manifest.get("exit_code") != 0:
        reasons.append("reference manifest has a nonzero exit_code")


def _validate_actual_manifest(
    path: Path,
    case_id: str,
    movie_sha256: str,
    frame_count: int,
    actual_frame_count: int,
    state_rows: int | None,
    event_rows: int | None,
    reasons: list[str],
) -> None:
    manifest = _validate_common_manifest(
        path, "actual", "evengine-remake", case_id, movie_sha256, frame_count, reasons
    )
    if manifest is None:
        return
    captured = manifest.get("captured_frames")
    if not _integer(captured) or captured != actual_frame_count:
        reasons.append("actual manifest captured_frames does not match its frame files")
    if captured != frame_count:
        reasons.append("actual manifest captured_frames do not cover every movie frame")
    if manifest.get("state_rows") != state_rows:
        reasons.append("actual manifest state_rows does not match state.jsonl")
    if state_rows != frame_count:
        reasons.append("actual state.jsonl does not cover every movie frame")
    if manifest.get("event_rows") != event_rows:
        reasons.append("actual manifest event_rows does not match events.jsonl")


def _validate_artifact_report(
    report: dict[str, Any], case_id: str, movie_sha256: str, frame_count: int,
    capture_frames: list[int], reasons: list[str]
) -> None:
    if report.get("passed") is not True:
        reasons.append("artifact gate is not passing")
    if report.get("movie") != case_id:
        reasons.append("artifact gate names a different movie")
    if report.get("movie_sha256") != movie_sha256:
        reasons.append("artifact gate is stale for the current movie hash")
    if report.get("comparison_frames") != frame_count:
        reasons.append("artifact gate comparison_frames does not match the movie")
    if report.get("capture_frames") != capture_frames:
        reasons.append("artifact gate capture_frames do not cover every movie frame")
    if report.get("errors") != []:
        reasons.append("artifact gate contains errors")
    checks = report.get("checks")
    if not isinstance(checks, dict) or not checks:
        reasons.append("artifact gate has no detailed checks")


def _validate_state_report(
    report: dict[str, Any], frame_count: int, reasons: list[str]
) -> None:
    if report.get("passed") is not True:
        reasons.append("state gate is not passing")
    if report.get("compared_frames") != frame_count:
        reasons.append("state gate compared_frames does not match the movie")
    if report.get("missing_frames") != 0:
        reasons.append("state gate contains missing frames")
    fields = report.get("fields")
    if not isinstance(fields, list) or not fields:
        reasons.append("state gate has no compared fields")
        return
    for field in fields:
        if not isinstance(field, dict) or field.get("mismatch_frames") != 0:
            reasons.append("state gate contains a field mismatch")
            break


def _case_evidence(root: Path, case_id: str, level_id: str) -> dict[str, Any]:
    reasons: list[str] = []
    movie_path = root / "tests" / "parity" / "movies" / f"{case_id}.json"
    movie = _load_json(movie_path, reasons=reasons, label="movie")
    frame_count: int | None = None
    movie_sha256: str | None = None
    summary: dict[str, Any] | None = None
    frame_report: dict[str, Any] | None = None
    gate_reports: dict[str, dict[str, Any]] = {}
    reference_frames: dict[int, Path] = {}
    actual_frames: dict[int, Path] = {}
    if movie is not None:
        if movie.get("schema") != MOVIE_SCHEMA:
            reasons.append("movie has an unexpected schema")
        if movie.get("name") != case_id:
            reasons.append("movie name does not match its case id")
        if movie.get("level_id") != level_id:
            reasons.append(f"movie level_id must be {level_id}")
        frames = movie.get("frames")
        if not _integer(frames) or frames <= 0:
            reasons.append("movie frames must be a positive integer")
        else:
            frame_count = frames
            try:
                movie_sha256 = hashlib.sha256(movie_path.read_bytes()).hexdigest()
            except OSError as exc:
                reasons.append(f"movie hash cannot be computed: {exc}")
            captures = movie.get("capture_frames", _expected_capture_frames(frames))
            if not isinstance(captures, list) or captures != _expected_capture_frames(frames):
                reasons.append("movie capture_frames are sampled rather than full per-frame")

    if frame_count is not None and movie_sha256 is not None:
        reference_frames = _frame_map(
            root / "local-parity" / "reference" / case_id / "frames",
            frame_count,
            "reference",
            reasons,
        )
        actual_frames = _frame_map(
            root / "local-parity" / "actual" / case_id / "frames",
            frame_count,
            "actual",
            reasons,
        )
        actual_dir = root / "local-parity" / "actual" / case_id
        state_rows = _jsonl_rows(actual_dir / "state.jsonl", "actual state.jsonl", reasons)
        event_rows = _jsonl_rows(actual_dir / "events.jsonl", "actual events.jsonl", reasons)
        _validate_reference_manifest(
            root / "local-parity" / "reference" / case_id / "manifest.json",
            case_id,
            movie_sha256,
            frame_count,
            reasons,
        )
        _validate_actual_manifest(
            actual_dir / "manifest.json",
            case_id,
            movie_sha256,
            frame_count,
            len(actual_frames),
            state_rows,
            event_rows,
            reasons,
        )

    reports = root / "local-parity" / "reports" / case_id
    summary = _load_json(reports / "summary.json", reasons=reasons, label="case summary report")
    if summary is not None:
        if summary.get("schema") != SUMMARY_SCHEMA:
            reasons.append("case summary report has an unexpected schema")
        if summary.get("case") != case_id:
            reasons.append("case summary report names a different case")
        if summary.get("passed") is not True:
            reasons.append("case summary report is not passing")
        checks = summary.get("checks")
        if not isinstance(checks, dict):
            reasons.append("case summary report has no gate checks")
        else:
            if set(checks) != set(GATE_NAMES):
                reasons.append("case summary report does not contain exactly all six gates")
            for gate in GATE_NAMES:
                check = checks.get(gate)
                if not isinstance(check, dict):
                    reasons.append(f"summary gate {gate} is missing")
                elif check.get("passed") is not True or check.get("exit_code") != 0:
                    reasons.append(f"summary gate {gate} did not pass")

    for gate in GATE_NAMES:
        report = _load_json(
            reports / GATE_REPORT_FILES[gate],
            reasons=reasons,
            label=f"{gate} detailed report",
        )
        if report is not None:
            gate_reports[gate] = report
            if report.get("passed") is not True:
                reasons.append(f"detailed {gate} gate is not passing")

    if frame_count is not None and movie_sha256 is not None:
        captures = _expected_capture_frames(frame_count)
        artifact = gate_reports.get("artifacts")
        if artifact is not None:
            _validate_artifact_report(
                artifact, case_id, movie_sha256, frame_count, captures, reasons
            )
        frame_report = gate_reports.get("frames")
        if frame_report is not None:
            _validate_frame_report(
                frame_report, frame_count, reference_frames, actual_frames, reasons
            )
        state = gate_reports.get("states")
        if state is not None:
            _validate_state_report(state, frame_count, reasons)

    return {
        "id": case_id,
        "passed": not reasons,
        "frame_count": frame_count,
        "movie_sha256": movie_sha256,
        "checks": {
            "movie": movie is not None,
            "reference_manifest": (
                root / "local-parity" / "reference" / case_id / "manifest.json"
            ).is_file(),
            "actual_manifest": (
                root / "local-parity" / "actual" / case_id / "manifest.json"
            ).is_file(),
            "case_summary": summary is not None,
            "all_gates": len(gate_reports) == len(GATE_NAMES),
            "full_frames": frame_report is not None and frame_report.get("passed") is True,
        },
        "reasons": reasons,
    }


def _reviewed_header(review: dict[str, Any], reasons: list[str], label: str) -> None:
    if not _string(review.get("reviewed_by")):
        reasons.append(f"{label} needs reviewed_by")
    if not _string(review.get("reviewed_at")):
        reasons.append(f"{label} needs reviewed_at")


def _valid_case_frame(
    reference: dict[str, Any], value: Any, field: str, reasons: list[str]
) -> bool:
    if not _integer(value):
        reasons.append(f"{field} must be an integer frame")
        return False
    frames = reference.get("frame_count")
    if frames is None or not 0 <= value < frames:
        reasons.append(f"{field} is outside the case movie timeline")
        return False
    return True


def _validate_review_provenance(
    review: dict[str, Any], case: dict[str, Any], label: str, reasons: list[str]
) -> None:
    value = review.get("movie_sha256")
    if not _string(value) or not re.fullmatch(r"[0-9a-f]{64}", value):
        reasons.append(f"{label} needs the reviewed movie_sha256")
    elif value != case.get("movie_sha256"):
        reasons.append(f"{label} provenance is stale for the current movie hash")


def _validate_route_review(
    level: dict[str, Any], evidence: dict[str, dict[str, Any]]
) -> dict[str, Any]:
    reasons: list[str] = []
    review = level.get("route_review")
    if not isinstance(review, dict):
        return {"passed": False, "reasons": ["reviewed route evidence is missing"]}
    _reviewed_header(review, reasons, "route review")
    case_id = review.get("case")
    if not _string(case_id):
        reasons.append("route review needs a case id")
        return {"passed": False, "reasons": reasons}
    case = evidence.get(case_id)
    if case is None:
        reasons.append(f"route review case {case_id} is not a required case for this level")
    elif not case.get("passed"):
        reasons.append(f"route case {case_id} has incomplete parity evidence")
    if case is not None:
        _validate_review_provenance(review, case, "route review", reasons)
    start = review.get("entrance_frame")
    end = review.get("exit_frame")
    if case is not None:
        valid_start = _valid_case_frame(case, start, "entrance_frame", reasons)
        valid_end = _valid_case_frame(case, end, "exit_frame", reasons)
        if valid_start and valid_end and start >= end:
            reasons.append("route entrance_frame must precede exit_frame")
    stage = level["stage"]
    expected_kind = "transition"
    if level["world"] == 8 and stage == 4:
        expected_kind = "final-ending"
    if review.get("endpoint_kind") != expected_kind:
        reasons.append(f"route endpoint_kind must be {expected_kind}")
    if not _string(review.get("evidence")):
        reasons.append("route review needs an evidence description")
    return {"passed": not reasons, "reasons": reasons}


def _validate_branch_review(
    level: dict[str, Any], evidence: dict[str, dict[str, Any]]
) -> dict[str, Any]:
    reasons: list[str] = []
    required = level.get("required_branches")
    if not isinstance(required, list):
        return {
            "passed": False,
            "reasons": ["branch coverage matrix has not been inventoried"],
        }
    if any(not _string(item) for item in required) or len(required) != len(set(required)):
        return {
            "passed": False,
            "reasons": ["required_branches must be unique nonempty strings"],
        }
    review = level.get("branch_review")
    if not isinstance(review, dict):
        return {"passed": False, "reasons": ["reviewed branch evidence is missing"]}
    _reviewed_header(review, reasons, "branch review")
    if not _string(review.get("evidence")):
        reasons.append("branch review needs an evidence description")
    branches = review.get("branches")
    if not isinstance(branches, list):
        reasons.append("branch review has no branch list")
        return {"passed": False, "reasons": reasons}
    names: list[str] = []
    for branch in branches:
        if not isinstance(branch, dict) or not _string(branch.get("id")):
            reasons.append("branch review contains an invalid branch id")
            continue
        name = branch["id"]
        names.append(name)
        case_id = branch.get("case")
        case = evidence.get(case_id) if _string(case_id) else None
        if case is None:
            reasons.append(f"branch {name} uses a case not required by this level")
        elif not case.get("passed"):
            reasons.append(f"branch {name} uses case {case_id} with incomplete evidence")
        if not _string(branch.get("evidence")):
            reasons.append(f"branch {name} needs an evidence description")
        if case is not None:
            _valid_case_frame(case, branch.get("frame"), f"branch {name} frame", reasons)
            _validate_review_provenance(branch, case, f"branch {name}", reasons)
    if len(names) != len(set(names)):
        reasons.append("branch review contains duplicate branch ids")
    if set(names) != set(required):
        missing = sorted(set(required) - set(names))
        extra = sorted(set(names) - set(required))
        if missing:
            reasons.append(f"branch review is missing: {', '.join(missing)}")
        if extra:
            reasons.append(f"branch review has unlisted branches: {', '.join(extra)}")
    return {"passed": not reasons, "reasons": reasons}


def _validate_inventory(inventory: dict[str, Any]) -> list[dict[str, Any]]:
    if inventory.get("schema") != INVENTORY_SCHEMA:
        raise ValueError(f"inventory schema must be {INVENTORY_SCHEMA}")
    levels = inventory.get("levels")
    if not isinstance(levels, list):
        raise ValueError("inventory levels must be a list")
    expected = _expected_levels()
    actual: list[tuple[int, int]] = []
    owners: dict[str, str] = {}
    for level in levels:
        if not isinstance(level, dict):
            raise ValueError("each inventory level must be an object")
        world = level.get("world")
        stage = level.get("stage")
        if not _integer(world) or not _integer(stage):
            raise ValueError("each inventory level needs integer world and stage")
        actual.append((world, stage))
        expected_id = f"{world}-{stage}"
        if level.get("id") != expected_id:
            raise ValueError(f"level id must be {expected_id}")
        required_cases = level.get("required_cases")
        supplemental = level.get("supplemental_cases")
        for field, cases in (
            ("required_cases", required_cases),
            ("supplemental_cases", supplemental),
        ):
            if not isinstance(cases, list) or any(not _string(case) for case in cases):
                raise ValueError(f"level {expected_id} {field} must be a list of case ids")
            if len(cases) != len(set(cases)):
                raise ValueError(f"level {expected_id} {field} contains duplicates")
        if set(required_cases) & set(supplemental):
            raise ValueError(f"level {expected_id} repeats a case as required and supplemental")
        for case_id in required_cases:
            if case_id in owners:
                raise ValueError(
                    f"required case {case_id} is assigned to both {owners[case_id]} and {expected_id}"
                )
            owners[case_id] = expected_id
    if len(actual) != len(set(actual)) or set(actual) != set(expected):
        raise ValueError("inventory must contain World 1-8 stages 1-4 exactly once")
    return levels


def collect_acceptance(root: Path, inventory_path: Path) -> dict[str, Any]:
    reasons: list[str] = []
    inventory = _load_json(inventory_path, reasons=reasons, label="inventory")
    if inventory is None:
        raise ValueError("; ".join(reasons))
    levels = _validate_inventory(inventory)
    results: list[dict[str, Any]] = []
    for level in levels:
        evidence = {
            case_id: _case_evidence(root, case_id, level["id"])
            for case_id in level["required_cases"]
        }
        case_reasons: list[str] = []
        if not level["required_cases"]:
            case_reasons.append("no required movies are assigned to this level")
        for case in evidence.values():
            if not case["passed"]:
                case_reasons.extend(
                    f"case {case['id']}: {reason}" for reason in case["reasons"]
                )
        route = _validate_route_review(level, evidence)
        branches = _validate_branch_review(level, evidence)
        all_reasons = case_reasons + route["reasons"] + branches["reasons"]
        results.append(
            {
                "id": level["id"],
                "world": level["world"],
                "stage": level["stage"],
                "status": "pending" if all_reasons else "complete",
                "required_cases": list(evidence.values()),
                "supplemental_cases": level["supplemental_cases"],
                "requirements": {
                    "case_evidence": {
                        "passed": bool(evidence) and not case_reasons,
                        "reasons": case_reasons,
                    },
                    "route_review": route,
                    "branch_coverage": branches,
                },
                "reasons": all_reasons,
            }
        )
    complete = sum(level["status"] == "complete" for level in results)
    return {
        "schema": REPORT_SCHEMA,
        "inventory": inventory_path.as_posix(),
        "summary": {
            "total": len(results),
            "complete": complete,
            "pending": len(results) - complete,
        },
        "limitations": LIMITATIONS,
        "levels": results,
    }


def render_markdown(report: dict[str, Any]) -> str:
    counts = report["summary"]
    lines = [
        "# Whole-level acceptance inventory",
        "",
        f"{counts['complete']} complete, {counts['pending']} pending, {counts['total']} total.",
        "",
        "| Level | Status | Required | Supplemental | Route review | Branches | Reasons |",
        "|---|---:|---:|---:|---:|---:|---|",
    ]
    for level in report["levels"]:
        requirements = level["requirements"]
        reasons = level["reasons"]
        reason_text = "; ".join(reasons).replace("|", "\\|") or "all evidence complete"
        lines.append(
            f"| {level['id']} | {level['status']} | {len(level['required_cases'])} | "
            f"{len(level['supplemental_cases'])} | "
            f"{'pass' if requirements['route_review']['passed'] else 'pending'} | "
            f"{'pass' if requirements['branch_coverage']['passed'] else 'pending'} | "
            f"{reason_text} |"
        )
    lines.extend(["", "## Review limitation", ""])
    lines.extend(f"- {item}" for item in report["limitations"])
    lines.append("")
    return "\n".join(lines)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Report conservative whole-level acceptance evidence for World 1-8."
    )
    parser.add_argument("--root", type=Path, default=Path("."), help="Repository root")
    parser.add_argument(
        "--inventory",
        type=Path,
        default=Path("tests/parity/level_acceptance.json"),
        help="Inventory path, relative to the repository root unless absolute",
    )
    parser.add_argument("--format", choices=("json", "markdown"), default="markdown")
    parser.add_argument("--output", type=Path, help="Write the report to this file")
    parser.add_argument(
        "--fail-on-pending",
        action="store_true",
        help="Return exit code 1 when any level is not complete",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    root = args.root.resolve()
    inventory = args.inventory if args.inventory.is_absolute() else root / args.inventory
    try:
        report = collect_acceptance(root, inventory)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    if args.format == "json":
        output = json.dumps(report, indent=2) + "\n"
    else:
        output = render_markdown(report)
    if args.output:
        destination = args.output if args.output.is_absolute() else root / args.output
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(output, encoding="utf-8")
    else:
        print(output, end="")
    if args.fail_on_pending and report["summary"]["pending"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
