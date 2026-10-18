from __future__ import annotations

import argparse
import html
import json
import subprocess
import sys
from pathlib import Path

from common import load_movie


def run(command: list[str], accepted: set[int] = {0}) -> int:
    print("+", subprocess.list2cmdline(command), flush=True)
    result = subprocess.run(command)
    if result.returncode not in accepted:
        raise RuntimeError(f"command failed with exit code {result.returncode}: {command[1]}")
    return result.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description="Run one complete ROM-vs-EVEngine parity case.")
    parser.add_argument("--rom", type=Path, required=True)
    parser.add_argument("--movie", type=Path, required=True)
    parser.add_argument("--artifacts", type=Path, default=Path("local-parity"))
    parser.add_argument("--skip-runs", action="store_true", help="Reuse existing reference/actual captures")
    args = parser.parse_args()

    project = Path(__file__).resolve().parents[2]
    movie_path = args.movie.resolve()
    movie = load_movie(movie_path)
    name = movie["name"]
    artifacts = (project / args.artifacts).resolve() if not args.artifacts.is_absolute() else args.artifacts.resolve()
    reference = artifacts / "reference" / name
    actual = artifacts / "actual" / name
    reports = artifacts / "reports" / name
    reports.mkdir(parents=True, exist_ok=True)
    python = sys.executable
    tools = Path(__file__).resolve().parent

    if not args.skip_runs:
        run([python, str(tools / "run_reference.py"), "--rom", str(args.rom.resolve()),
             "--movie", str(movie_path), "--output", str(reference)])
        run([python, str(tools / "run_actual.py"), "--movie", str(movie_path),
             "--output", str(actual), "--project", str(project)])

    run([python, str(tools / "extract_reference_state.py"),
         "--input", str(reference / "ram-trace.jsonl"), "--output", str(reference / "state.jsonl")])
    run([python, str(tools / "extract_reference_events.py"),
         "--queues", str(reference / "audio-queues.jsonl"),
         "--ram-trace", str(reference / "ram-trace.jsonl"),
         "--output", str(reference / "events-semantic.jsonl")])
    run([python, str(tools / "render_actual_audio.py"),
         "--events", str(actual / "events.jsonl"), "--assets", str(project / "assets" / "audio"),
         "--frames", str(movie["frames"]), "--output", str(actual / "audio.wav")])

    checks = {}
    checks["artifacts"] = run([
        python, str(tools / "validate_artifacts.py"), "--movie", str(movie_path),
        "--reference", str(reference), "--actual", str(actual), "--output", str(reports),
    ], {0, 1})
    checks["frames"] = run([
        python, str(tools / "compare_frames.py"), "--reference", str(reference / "frames"),
        "--actual", str(actual / "frames"), "--output", str(reports),
    ], {0, 1})
    checks["states"] = run([
        python, str(tools / "compare_states.py"), "--reference", str(reference / "state.jsonl"),
        "--actual", str(actual / "state.jsonl"), "--output", str(reports),
    ], {0, 1})
    checks["events"] = run([
        python, str(tools / "compare_events.py"), "--reference", str(reference / "events-semantic.jsonl"),
        "--actual", str(actual / "events.jsonl"), "--output", str(reports),
    ], {0, 1})
    checks["audio"] = run([
        python, str(tools / "compare_audio.py"), "--reference", str(reference / "audio.wav"),
        "--actual", str(actual / "audio.wav"), "--output", str(reports),
    ], {0, 1})

    summary = {
        "schema": "smb-parity-case-summary-v1",
        "case": name,
        "passed": all(code == 0 for code in checks.values()),
        "checks": {name: {"passed": code == 0, "exit_code": code} for name, code in checks.items()},
        "reports": {
            "artifacts": "artifact-report.html",
            "frames": "report.html",
            "states": "state-report.html",
            "events": "event-report.html",
            "audio": "audio-report.html",
        },
    }
    (reports / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    rows = "".join(
        f'<li><a href="{html.escape(summary["reports"][key])}">{html.escape(key)}</a>: '
        f'{"通过" if value["passed"] else "失败"}</li>'
        for key, value in summary["checks"].items()
    )
    (reports / "index.html").write_text(
        f"<!doctype html><meta charset=\"utf-8\"><title>{html.escape(name)} parity</title>"
        f"<h1>{html.escape(name)} 对照汇总</h1><p>{'通过' if summary['passed'] else '失败'}</p><ul>{rows}</ul>",
        encoding="utf-8",
    )
    print(f"{'PASS' if summary['passed'] else 'FAIL'}: {reports / 'index.html'}")
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
