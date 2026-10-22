from __future__ import annotations

import argparse
import html
import json
from collections import Counter, defaultdict
from pathlib import Path


APU_ADDRESSES = set(range(0x4000, 0x4014)) | {0x4015, 0x4017}
CHANNELS = {
    "pulse1": set(range(0x4000, 0x4004)),
    "pulse2": set(range(0x4004, 0x4008)),
    "triangle": set(range(0x4008, 0x400C)),
    "noise": set(range(0x400C, 0x4010)),
    "dmc": set(range(0x4010, 0x4014)),
    "control": {0x4015, 0x4017},
}


def load(path: Path) -> dict[int, list[tuple[int, int]]]:
    frames: dict[int, list[tuple[int, int]]] = defaultdict(list)
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        row = json.loads(line)
        address = int(row["address"])
        if address not in APU_ADDRESSES:
            continue
        frames[int(row["frame"])].append((address, int(row["value"])))
    return frames


def final_registers(writes: list[tuple[int, int]], previous: dict[int, int]) -> dict[int, int]:
    result = dict(previous)
    for address, value in writes:
        result[address] = value
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare frame-ordered 2A03 APU writes.")
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--actual", type=Path, required=True)
    parser.add_argument("--frames", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    reference = load(args.reference.resolve())
    actual = load(args.actual.resolve())
    exact_frames = 0
    snapshot_frames = 0
    first_stream_mismatch = None
    first_snapshot_mismatch = None
    ref_registers: dict[int, int] = {}
    actual_registers: dict[int, int] = {}
    address_mismatches: Counter[int] = Counter()
    channel_mismatches: Counter[str] = Counter()
    frame_rows = []

    for frame in range(args.frames):
        ref_writes = reference.get(frame, [])
        actual_writes = actual.get(frame, [])
        stream_equal = ref_writes == actual_writes
        if stream_equal:
            exact_frames += 1
        elif first_stream_mismatch is None:
            first_stream_mismatch = frame

        ref_registers = final_registers(ref_writes, ref_registers)
        actual_registers = final_registers(actual_writes, actual_registers)
        differing = sorted(
            address
            for address in APU_ADDRESSES
            if ref_registers.get(address) != actual_registers.get(address)
        )
        if not differing:
            snapshot_frames += 1
        elif first_snapshot_mismatch is None:
            first_snapshot_mismatch = frame
        for address in differing:
            address_mismatches[address] += 1
            for channel, addresses in CHANNELS.items():
                if address in addresses:
                    channel_mismatches[channel] += 1
                    break
        if not stream_equal or differing:
            frame_rows.append({
                "frame": frame,
                "reference_writes": len(ref_writes),
                "actual_writes": len(actual_writes),
                "stream_equal": stream_equal,
                "differing_registers": [f"0x{address:04X}" for address in differing],
                "reference_stream": [f"{address:04X}:{value:02X}" for address, value in ref_writes],
                "actual_stream": [f"{address:04X}:{value:02X}" for address, value in actual_writes],
            })

    passed = exact_frames == args.frames
    report = {
        "schema": "smb-apu-write-parity-v1",
        "passed": passed,
        "frames": args.frames,
        "exact_write_stream_frames": exact_frames,
        "matching_end_state_frames": snapshot_frames,
        "first_stream_mismatch": first_stream_mismatch,
        "first_end_state_mismatch": first_snapshot_mismatch,
        "reference_writes": sum(len(reference.get(frame, [])) for frame in range(args.frames)),
        "actual_writes": sum(len(actual.get(frame, [])) for frame in range(args.frames)),
        "register_mismatch_frames": {
            f"0x{address:04X}": count for address, count in sorted(address_mismatches.items())
        },
        "channel_register_mismatches": dict(channel_mismatches),
        "mismatching_frames": frame_rows,
    }
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "apu-report.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )

    channel_rows = "".join(
        f"<tr><td>{html.escape(channel)}</td><td>{count}</td></tr>"
        for channel, count in channel_mismatches.most_common()
    )
    mismatch_rows = "".join(
        "<tr>"
        f"<td>{row['frame']}</td><td>{row['reference_writes']}</td>"
        f"<td>{row['actual_writes']}</td>"
        f"<td>{html.escape(', '.join(row['differing_registers']))}</td>"
        f"<td><code>{html.escape(' '.join(row['reference_stream']))}</code></td>"
        f"<td><code>{html.escape(' '.join(row['actual_stream']))}</code></td>"
        "</tr>"
        for row in frame_rows[:120]
    )
    document = f"""<!doctype html><meta charset="utf-8"><title>SMB APU parity</title>
<h1>逐帧 APU 写入对照</h1>
<p>{'通过' if passed else '存在已量化差异'}；严格写入流 {exact_frames}/{args.frames} 帧，
帧末寄存器状态 {snapshot_frames}/{args.frames} 帧。</p>
<p>首个写入流差异：{first_stream_mismatch}；首个帧末状态差异：{first_snapshot_mismatch}。</p>
<h2>声道差异计数</h2><table><tr><th>声道</th><th>寄存器·帧</th></tr>{channel_rows}</table>
<h2>前 120 个差异帧</h2><table><tr><th>帧</th><th>参考写入</th><th>复刻写入</th>
<th>帧末差异寄存器</th><th>参考流</th><th>复刻流</th></tr>{mismatch_rows}</table>"""
    (args.output / "apu-report.html").write_text(document, encoding="utf-8")
    print(f"{'PASS' if passed else 'FAIL'}: {args.output / 'apu-report.html'}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
