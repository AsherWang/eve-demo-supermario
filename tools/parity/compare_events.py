from __future__ import annotations

import argparse
import html
import json
from collections import defaultdict
from pathlib import Path


def load_events(path: Path) -> list[dict]:
    with path.open("r", encoding="utf-8") as source:
        return [json.loads(line) for line in source if line.strip()]


def write_html(report: dict, output: Path) -> None:
    rows = []
    for item in report["event_groups"]:
        deltas = ", ".join(str(value) for value in item["frame_deltas"]) or "-"
        rows.append(
            f"<tr><td>{html.escape(item['type'])}</td><td>{html.escape(item['name'])}</td>"
            f"<td>{item['reference_count']}</td><td>{item['actual_count']}</td>"
            f"<td>{html.escape(deltas)}</td><td>{'通过' if item['passed'] else '失败'}</td></tr>"
        )
    document = f"""<!doctype html><meta charset="utf-8"><title>SMB event parity</title>
<style>body{{font-family:system-ui;margin:2rem}}table{{border-collapse:collapse}}td,th{{border:1px solid #aaa;padding:.35rem .6rem}}</style>
<h1>SMB 事件对照报告</h1><p>{'通过' if report['passed'] else '失败'}；帧容差 ±{report['frame_tolerance']}。</p>
<table><thead><tr><th>类型</th><th>事件</th><th>原版次数</th><th>复刻次数</th><th>复刻-原版帧差</th><th>结果</th></tr></thead>
<tbody>{''.join(rows)}</tbody></table>
"""
    (output / "event-report.html").write_text(document, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare semantic event order and frame timing.")
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--actual", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--frame-tolerance", type=int, default=0)
    parser.add_argument("--types", nargs="*", default=["gameplay", "audio", "music"])
    args = parser.parse_args()

    reference_groups = defaultdict(list)
    actual_groups = defaultdict(list)
    allowed = set(args.types)
    for event in load_events(args.reference):
        if event.get("type") in allowed:
            reference_groups[(event["type"], event["name"])].append(event["frame"])
    for event in load_events(args.actual):
        if event.get("type") in allowed:
            actual_groups[(event["type"], event["name"])].append(event["frame"])

    groups = []
    for event_type, name in sorted(set(reference_groups) | set(actual_groups)):
        expected = reference_groups[(event_type, name)]
        observed = actual_groups[(event_type, name)]
        deltas = [actual - reference for reference, actual in zip(expected, observed)]
        passed = len(expected) == len(observed) and all(
            abs(delta) <= args.frame_tolerance for delta in deltas
        )
        groups.append({
            "type": event_type,
            "name": name,
            "reference_count": len(expected),
            "actual_count": len(observed),
            "reference_frames": expected,
            "actual_frames": observed,
            "frame_deltas": deltas,
            "passed": passed,
        })

    report = {
        "schema": "smb-event-parity-report-v1",
        "passed": bool(groups) and all(item["passed"] for item in groups),
        "frame_tolerance": args.frame_tolerance,
        "event_groups": groups,
    }
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / "event-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    write_html(report, output)
    print(f"{'PASS' if report['passed'] else 'FAIL'}: {output / 'event-report.html'}")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
