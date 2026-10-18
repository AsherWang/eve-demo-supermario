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


def read_pcm(path: Path) -> tuple[dict, list[float], bytes]:
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
    mono = []
    for index in range(0, len(values), channels):
        mono.append(sum(values[index:index + channels]) / (32768.0 * channels))
    return params, mono, raw


def rms(values: list[float]) -> float:
    return math.sqrt(sum(value * value for value in values) / len(values)) if values else 0.0


def frame_envelope(samples: list[float], sample_rate: int) -> list[float]:
    result = []
    frame = 0
    while True:
        start = round(frame * sample_rate / NES_FPS)
        stop = round((frame + 1) * sample_rate / NES_FPS)
        if start >= len(samples):
            break
        result.append(rms(samples[start:min(stop, len(samples))]))
        frame += 1
    return result


def correlation(left: list[float], right: list[float]) -> float:
    if not left or len(left) != len(right):
        return 0.0
    left_mean = sum(left) / len(left)
    right_mean = sum(right) / len(right)
    numerator = sum((a - left_mean) * (b - right_mean) for a, b in zip(left, right))
    left_energy = sum((a - left_mean) ** 2 for a in left)
    right_energy = sum((b - right_mean) ** 2 for b in right)
    denominator = math.sqrt(left_energy * right_energy)
    return numerator / denominator if denominator else 0.0


def best_envelope_lag(reference: list[float], actual: list[float], limit: int = 12) -> tuple[int, float]:
    best_lag = 0
    best_score = -2.0
    for lag in range(-limit, limit + 1):
        if lag < 0:
            left = reference[-lag:]
            right = actual[:len(left)]
        else:
            left = reference[:len(reference) - lag if lag else len(reference)]
            right = actual[lag:lag + len(left)]
        size = min(len(left), len(right))
        score = correlation(left[:size], right[:size])
        if score > best_score:
            best_lag, best_score = lag, score
    return best_lag, best_score


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare reference and reconstructed PCM audio.")
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--actual", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    reference_params, reference, reference_raw = read_pcm(args.reference)
    actual_params, actual, actual_raw = read_pcm(args.actual)
    common = min(len(reference), len(actual))
    differences = [abs(reference[index] - actual[index]) for index in range(common)]
    first_difference = next((index for index, value in enumerate(differences) if value != 0.0), None)
    reference_env = frame_envelope(reference, reference_params["sample_rate"])
    actual_env = frame_envelope(actual, actual_params["sample_rate"])
    env_common = min(len(reference_env), len(actual_env))
    envelope_mae = (
        sum(abs(reference_env[index] - actual_env[index]) for index in range(env_common)) / env_common
        if env_common else 0.0
    )
    lag, lag_correlation = best_envelope_lag(reference_env, actual_env)
    exact = reference_params == actual_params and reference_raw == actual_raw
    report = {
        "schema": "smb-audio-parity-report-v1",
        "passed": exact,
        "reference": {**reference_params, "pcm_sha256": hashlib.sha256(reference_raw).hexdigest(), "rms": rms(reference)},
        "actual": {**actual_params, "pcm_sha256": hashlib.sha256(actual_raw).hexdigest(), "rms": rms(actual)},
        "common_sample_frames": common,
        "first_different_sample_frame": first_difference,
        "mean_absolute_sample_error": sum(differences) / common if common else 0.0,
        "max_absolute_sample_error": max(differences, default=0.0),
        "sample_correlation": correlation(reference[:common], actual[:common]),
        "nes_frame_envelope_mae": envelope_mae,
        "best_envelope_lag_frames": lag,
        "best_envelope_correlation": lag_correlation,
    }
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / "audio-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    document = f"""<!doctype html><meta charset="utf-8"><title>SMB audio parity</title>
<style>body{{font-family:system-ui;margin:2rem}}td,th{{border:1px solid #aaa;padding:.35rem .6rem}}table{{border-collapse:collapse}}</style>
<h1>SMB 音频对照报告</h1><p>{'严格 PCM 一致' if exact else '严格 PCM 不一致'}</p>
<table><tr><th>指标</th><th>结果</th></tr>
<tr><td>首个差异采样帧</td><td>{first_difference}</td></tr>
<tr><td>平均绝对采样误差</td><td>{report['mean_absolute_sample_error']:.8f}</td></tr>
<tr><td>采样相关系数</td><td>{report['sample_correlation']:.6f}</td></tr>
<tr><td>NES 帧包络 MAE</td><td>{envelope_mae:.8f}</td></tr>
<tr><td>最佳包络帧偏移</td><td>{lag}</td></tr>
<tr><td>最佳包络相关系数</td><td>{lag_correlation:.6f}</td></tr></table>
"""
    (output / "audio-report.html").write_text(document, encoding="utf-8")
    print(f"{'PASS' if exact else 'FAIL'}: {output / 'audio-report.html'}")
    return 0 if exact else 1


if __name__ == "__main__":
    raise SystemExit(main())
