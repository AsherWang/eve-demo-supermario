from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
from typing import Any


FIELD_SPECS = (
    {"field": "frame_counter"},
    {"field": "player.x"},
    {"field": "player.y"},
    {"field": "player.x_speed_raw"},
    {"field": "player.y_speed_raw"},
    {"field": "player.y_move_force"},
    {"field": "player.y_move_dummy"},
    {"field": "player.x_acceleration_fraction"},
    {"field": "player.x_position_fraction"},
    {"field": "player.state_raw"},
    {"field": "player.size_raw"},
    {"field": "player.status_raw"},
    {"field": "player.big"},
    {"field": "player.fire"},
    {"field": "player.grounded"},
    {"field": "camera_x"},
    {"field": "color_rotation_offset"},
    {"field": "vram_scheduler.scroll_thirty_two"},
    {"field": "vram_scheduler.area_parser_task"},
    {"field": "vram_scheduler.buffer_addr_ctrl"},
    {"field": "lives"},
    {"field": "score"},
    {"field": "coins"},
    {"field": "time"},
    {"field": "rom_state.oper_mode"},
    {"field": "rom_state.oper_mode_task"},
    {"field": "rom_state.game_engine_subroutine"},
    {"field": "enemy0.active"},
    {"field": "enemy0.id", "requires_active_enemy0": True},
    {"field": "enemy0.state_raw", "requires_active_enemy0": True},
    {"field": "enemy0.x", "requires_active_enemy0": True},
    {"field": "powerup.active"},
    {"field": "powerup.kind", "requires_active_powerup": True},
    {"field": "powerup.state_raw", "requires_active_powerup": True},
    {"field": "powerup.x", "requires_active_powerup": True},
    {"field": "powerup.y", "requires_active_powerup": True},
    {"field": "powerup.x_speed_raw", "requires_active_powerup": True},
    {"field": "powerup.visible", "requires_active_powerup": True},
)


def load_jsonl(path: Path) -> dict[int, dict[str, Any]]:
    rows = {}
    with path.open("r", encoding="utf-8") as source:
        for line in source:
            if not line.strip():
                continue
            row = json.loads(line)
            rows[row["frame"]] = row
    return rows


def field_value(row: dict[str, Any], field: str) -> Any:
    value: Any = row
    for part in field.split("."):
        value = value[part]
    return value


def write_html(report: dict, output: Path) -> None:
    rows = []
    for field in report["fields"]:
        first = field.get("first_mismatch")
        first_text = "-" if first is None else (
            f"帧 {first['frame']}: 原版={html.escape(str(first['reference']))}, "
            f"复刻={html.escape(str(first['actual']))}"
        )
        rows.append(
            f"<tr><td>{html.escape(field['field'])}</td>"
            f"<td>{field['mismatch_frames']}</td><td>{first_text}</td></tr>"
        )
    document = f"""<!doctype html><meta charset="utf-8"><title>SMB state parity</title>
<style>body{{font-family:system-ui;margin:2rem}}table{{border-collapse:collapse}}td,th{{border:1px solid #aaa;padding:.35rem .6rem}}</style>
<h1>SMB 状态对照报告</h1>
<p>{'通过' if report['passed'] else '失败'}：共同帧 {report['compared_frames']}，缺失帧 {report['missing_frames']}。</p>
<table><thead><tr><th>字段</th><th>不一致帧数</th><th>首次差异</th></tr></thead><tbody>{''.join(rows)}</tbody></table>
"""
    (output / "state-report.html").write_text(document, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare canonical semantic state traces.")
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--actual", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    reference = load_jsonl(args.reference)
    actual = load_jsonl(args.actual)
    common_frames = sorted(set(reference) & set(actual))
    missing = len(set(reference) ^ set(actual))
    field_results = []
    for spec in FIELD_SPECS:
        field = spec["field"]
        start_frame = spec.get("start_frame", 0)
        mismatches = []
        compared_field_frames = 0
        for frame in common_frames:
            if frame < start_frame:
                continue
            reference_enemy0 = reference[frame].get("enemy0") or {"active": False}
            actual_enemy0 = actual[frame].get("enemy0") or {"active": False}
            if spec.get("requires_active_enemy0") and not (
                reference_enemy0.get("active", False) and actual_enemy0.get("active", False)
            ):
                continue
            reference_powerup = reference[frame].get("powerup") or {"active": False}
            actual_powerup = actual[frame].get("powerup") or {"active": False}
            if spec.get("requires_active_powerup") and not (
                reference_powerup.get("active", False) and actual_powerup.get("active", False)
            ):
                continue
            compared_field_frames += 1
            expected = field_value(reference[frame], field)
            observed = field_value(actual[frame], field)
            if expected != observed:
                mismatches.append({"frame": frame, "reference": expected, "actual": observed})
        field_results.append({
            "field": field,
            "compared_frames": compared_field_frames,
            "start_frame": start_frame,
            "mismatch_frames": len(mismatches),
            "first_mismatch": mismatches[0] if mismatches else None,
        })
    passed = bool(common_frames) and missing == 0 and all(
        item["mismatch_frames"] == 0 for item in field_results
    )
    report = {
        "schema": "smb-state-parity-report-v1",
        "passed": passed,
        "compared_frames": len(common_frames),
        "missing_frames": missing,
        "fields": field_results,
    }
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / "state-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    write_html(report, output)
    print(f"{'PASS' if passed else 'FAIL'}: {output / 'state-report.html'}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
