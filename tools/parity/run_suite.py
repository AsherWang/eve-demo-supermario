from __future__ import annotations

import argparse
import html
import json
import subprocess
import sys
from pathlib import Path

from common import load_movie


DEFAULT_CASES = (
    "walk-right-smoke",
    "first-goomba-jump",
    "first-goomba-death-lifecycle",
    "first-powerup-mushroom",
    "world-1-1-tas",
    "world-1-1-high-flag",
)


def run(command: list[str], accepted: set[int] = {0}) -> int:
    print("+", subprocess.list2cmdline(command), flush=True)
    result = subprocess.run(command)
    if result.returncode not in accepted:
        raise RuntimeError(f"command failed with exit code {result.returncode}: {command[1]}")
    return result.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description="Run and aggregate the deterministic SMB parity suite.")
    parser.add_argument("--rom", type=Path, required=True)
    parser.add_argument("--artifacts", type=Path, default=Path("local-parity"))
    parser.add_argument("--cases", nargs="*", default=list(DEFAULT_CASES))
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--skip-runs", action="store_true", help="Reuse both reference and actual captures")
    mode.add_argument(
        "--reuse-reference",
        action="store_true",
        help="Replay EVEngine, but reuse the existing ROM reference captures",
    )
    args = parser.parse_args()

    project = Path(__file__).resolve().parents[2]
    tools = Path(__file__).resolve().parent
    movies = project / "tests" / "parity" / "movies"
    artifacts = (project / args.artifacts).resolve() if not args.artifacts.is_absolute() else args.artifacts.resolve()
    python = sys.executable
    summaries = []

    for case in args.cases:
        movie_path = movies / f"{case}.json"
        if not movie_path.is_file():
            parser.error(f"unknown parity case: {case}")
        movie = load_movie(movie_path)
        if movie["name"] != case:
            parser.error(f"movie name {movie['name']!r} does not match filename {case!r}")
        if args.reuse_reference:
            run([
                python, str(tools / "run_actual.py"), "--movie", str(movie_path),
                "--output", str(artifacts / "actual" / case), "--project", str(project),
            ])
        command = [
            python, str(tools / "run_case.py"), "--rom", str(args.rom.resolve()),
            "--movie", str(movie_path), "--artifacts", str(artifacts),
        ]
        if args.skip_runs or args.reuse_reference:
            command.append("--skip-runs")
        run(command, {0, 1})
        summary_path = artifacts / "reports" / case / "summary.json"
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
        summaries.append(summary)

    passed = all(summary["passed"] for summary in summaries)
    report = {
        "schema": "smb-parity-suite-summary-v1",
        "passed": passed,
        "cases": summaries,
    }
    reports = artifacts / "reports"
    reports.mkdir(parents=True, exist_ok=True)
    (reports / "suite-summary.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    rows = []
    for summary in summaries:
        checks = ", ".join(
            f"{html.escape(name)}={'通过' if value['passed'] else '失败'}"
            for name, value in summary["checks"].items()
        )
        case = summary["case"]
        rows.append(
            f'<tr><td><a href="{html.escape(case)}/index.html">{html.escape(case)}</a></td>'
            f"<td>{'通过' if summary['passed'] else '失败'}</td><td>{checks}</td></tr>"
        )
    (reports / "index.html").write_text(
        "<!doctype html><meta charset=\"utf-8\"><title>SMB parity suite</title>"
        f"<h1>SMB 对照测试总览</h1><p>{'通过' if passed else '存在已量化差异'}</p>"
        "<table><thead><tr><th>用例</th><th>严格结果</th><th>分项</th></tr></thead><tbody>"
        f"{''.join(rows)}</tbody></table>",
        encoding="utf-8",
    )
    print(f"{'PASS' if passed else 'FAIL'}: {reports / 'index.html'}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
