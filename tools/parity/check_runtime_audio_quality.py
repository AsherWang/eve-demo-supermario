from __future__ import annotations

import argparse
import hashlib
import html
import json
import math
import struct
import wave
from pathlib import Path


NES_FPS = 60.0988
TARGET_RATE = 48_000
COMPARISON_FRAMES = 190


def read_pcm(path: Path) -> tuple[dict, list[float]]:
    with wave.open(str(path), "rb") as source:
        params = {
            "channels": source.getnchannels(),
            "sample_width": source.getsampwidth(),
            "sample_rate": source.getframerate(),
            "sample_frames": source.getnframes(),
        }
        raw = source.readframes(source.getnframes())
    if params["sample_width"] != 2:
        raise ValueError(f"{path} must be 16-bit PCM")
    values = struct.unpack(f"<{len(raw) // 2}h", raw)
    channels = params["channels"]
    if channels not in (1, 2):
        raise ValueError(f"{path} must be mono or stereo")
    mono = [
        sum(values[index:index + channels]) / (32768.0 * channels)
        for index in range(0, len(values), channels)
    ]
    params["pcm_sha256"] = hashlib.sha256(raw).hexdigest()
    params["duration_seconds"] = params["sample_frames"] / params["sample_rate"]
    return params, mono


def rms(values: list[float]) -> float:
    return math.sqrt(sum(value * value for value in values) / len(values)) if values else 0.0


def high_band_proxy(values: list[float], sample_rate: int, cutoff: float = 8_000.0) -> float:
    """Return high-pass residual energy / total energy without optional FFT dependencies."""
    decay = math.exp(-2.0 * math.pi * cutoff / sample_rate)
    low = 0.0
    high_energy = 0.0
    total_energy = 0.0
    for value in values:
        low = (1.0 - decay) * value + decay * low
        high = value - low
        high_energy += high * high
        total_energy += value * value
    return high_energy / total_energy if total_energy else 0.0


def check(name: str, passed: bool, actual: object, expected: str) -> dict:
    return {"name": name, "passed": passed, "actual": actual, "expected": expected}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check shipped EVEngine WAV quality against a Mesen reference capture."
    )
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--actual", type=Path, required=True)
    parser.add_argument("--assets", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    assets = args.assets.resolve()
    manifest = json.loads((assets / "oracle-audio-manifest.json").read_text(encoding="utf-8"))
    checks: list[dict] = []
    asset_params = {}
    for name, entry in sorted(manifest["clips"].items()):
        path = assets / f"{name}.wav"
        params, samples = read_pcm(path)
        asset_params[path.name] = params
        checks.append(check(
            f"{path.name}: format",
            params["sample_rate"] == TARGET_RATE and params["sample_width"] == 2 and params["channels"] == 2,
            f"{params['sample_rate']} Hz, {params['sample_width'] * 8}-bit, {params['channels']} ch",
            "48000 Hz, 16-bit, stereo",
        ))
        checks.append(check(
            f"{path.name}: captured asset hash",
            hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"],
            hashlib.sha256(path.read_bytes()).hexdigest(),
            entry["sha256"],
        ))

    for name, minimum in (("overworld", 150.0), ("star", 12.0)):
        duration = manifest["clips"][name]["sample_frames"] / manifest["sample_rate"]
        checks.append(check(
            f"{name}: continuous stream",
            duration >= minimum,
            duration,
            f"finite continuous stream >= {minimum:.0f}s",
        ))

    reference_params, reference = read_pcm(args.reference.resolve())
    actual_params, actual = read_pcm(args.actual.resolve())
    comparison_samples = round(
        COMPARISON_FRAMES * min(reference_params["sample_rate"], actual_params["sample_rate"]) / NES_FPS
    )
    reference_segment = reference[:comparison_samples]
    actual_segment = actual[:comparison_samples]
    reference_rms = rms(reference_segment)
    actual_rms = rms(actual_segment)
    rms_ratio = actual_rms / reference_rms if reference_rms else 0.0
    reference_high = high_band_proxy(reference_segment, reference_params["sample_rate"])
    actual_high = high_band_proxy(actual_segment, actual_params["sample_rate"])
    high_ratio = actual_high / reference_high if reference_high else 0.0
    peak = max((abs(value) for value in actual), default=0.0)

    checks.extend((
        check(
            "runtime mix: format",
            actual_params["sample_rate"] == reference_params["sample_rate"] == TARGET_RATE
            and actual_params["sample_width"] == reference_params["sample_width"] == 2,
            actual_params,
            "same 48000 Hz, 16-bit format as Mesen reference",
        ),
        check("runtime mix: pre-death RMS", 0.80 <= rms_ratio <= 1.20, rms_ratio, "0.80..1.20 of reference"),
        check(
            "runtime mix: high-band residual",
            high_ratio <= 1.85,
            high_ratio,
            "<= 1.85x Mesen reference",
        ),
        check("runtime mix: clipping", peak < 0.98, peak, "peak < 0.98"),
    ))

    passed = all(item["passed"] for item in checks)
    report = {
        "schema": "smb-runtime-audio-quality-v1",
        "passed": passed,
        "comparison_frames": COMPARISON_FRAMES,
        "reference": {
            **reference_params,
            "rms": reference_rms,
            "high_band_proxy": reference_high,
        },
        "actual": {
            **actual_params,
            "rms": actual_rms,
            "rms_ratio": rms_ratio,
            "high_band_proxy": actual_high,
            "high_band_ratio": high_ratio,
            "peak": peak,
        },
        "assets": asset_params,
        "checks": checks,
    }
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / "runtime-audio-quality.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    rows = "".join(
        "<tr><td>{}</td><td>{}</td><td><code>{}</code></td><td>{}</td></tr>".format(
            html.escape(item["name"]),
            "通过" if item["passed"] else "失败",
            html.escape(json.dumps(item["actual"], ensure_ascii=False)),
            html.escape(item["expected"]),
        )
        for item in checks
    )
    document = (
        "<!doctype html><meta charset=\"utf-8\"><title>Runtime audio quality</title>"
        "<style>body{font-family:system-ui;margin:2rem}td,th{border:1px solid #aaa;padding:.35rem .6rem}"
        "table{border-collapse:collapse}</style>"
        f"<h1>运行时音频质量门禁</h1><p>{'通过' if passed else '失败'}</p>"
        "<p>频谱门限来自同一输入下的 Mesen 48 kHz 参考 WAV；它不替代逐采样 APU 对照。</p>"
        "<table><thead><tr><th>检查</th><th>结果</th><th>实际</th><th>门限</th></tr></thead>"
        f"<tbody>{rows}</tbody></table>"
    )
    (output / "index.html").write_text(document, encoding="utf-8")
    print(f"{'PASS' if passed else 'FAIL'}: {output / 'index.html'}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
