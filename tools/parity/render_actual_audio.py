from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import wave
from pathlib import Path


NES_FPS = 60.0988
TARGET_RATE = 48_000
MUSIC_VOLUME = 0.42
SFX_VOLUME = 0.58


def read_mono(path: Path) -> tuple[int, list[float]]:
    with wave.open(str(path), "rb") as source:
        if source.getsampwidth() != 2:
            raise ValueError(f"{path} must be 16-bit PCM")
        channels = source.getnchannels()
        rate = source.getframerate()
        raw = source.readframes(source.getnframes())
    values = struct.unpack(f"<{len(raw) // 2}h", raw)
    if channels == 1:
        mono = [value / 32768.0 for value in values]
    elif channels == 2:
        mono = [(values[index] + values[index + 1]) / 65536.0 for index in range(0, len(values), 2)]
    else:
        raise ValueError(f"{path} has unsupported channel count {channels}")
    return rate, mono


def resample(samples: list[float], source_rate: int, target_rate: int = TARGET_RATE) -> list[float]:
    if source_rate == target_rate:
        return samples
    target_length = round(len(samples) * target_rate / source_rate)
    if not samples or target_length <= 0:
        return []
    result = [0.0] * target_length
    ratio = source_rate / target_rate
    last = len(samples) - 1
    for index in range(target_length):
        position = index * ratio
        left = min(int(position), last)
        right = min(left + 1, last)
        fraction = position - left
        result[index] = samples[left] * (1.0 - fraction) + samples[right] * fraction
    return result


def load_assets(directory: Path) -> dict[str, list[float]]:
    result = {}
    for path in directory.glob("*.wav"):
        rate, samples = read_mono(path)
        result[path.stem] = resample(samples, rate)
    return result


def mix_samples(destination: list[float], source: list[float], start: int, volume: float,
                stop: int | None = None, loop: bool = False) -> None:
    end = len(destination) if stop is None else min(stop, len(destination))
    if start >= end or not source:
        return
    for output_index in range(max(start, 0), end):
        source_index = output_index - start
        if loop:
            source_index %= len(source)
        elif source_index >= len(source):
            break
        destination[output_index] += source[source_index] * volume


def render_ground(destination: list[float], assets: dict[str, list[float]], start: int, stop: int) -> None:
    intro = assets["overworld_intro"]
    loop = assets["overworld"]
    intro_stop = min(start + len(intro), stop)
    mix_samples(destination, intro, start, MUSIC_VOLUME, intro_stop)
    if intro_stop < stop:
        mix_samples(destination, loop, intro_stop, MUSIC_VOLUME, stop, loop=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Render deterministic EVEngine audio from its parity event trace.")
    parser.add_argument("--events", type=Path, required=True)
    parser.add_argument("--assets", type=Path, required=True)
    parser.add_argument("--frames", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    assets = load_assets(args.assets.resolve())
    events = [json.loads(line) for line in args.events.read_text(encoding="utf-8").splitlines() if line.strip()]
    total_samples = round(args.frames * TARGET_RATE / NES_FPS)
    music = [0.0] * total_samples
    effects = [0.0] * total_samples

    controls = [(0, "ground")]
    for event in events:
        if event["type"] != "audio":
            continue
        sample = round(event["frame"] * TARGET_RATE / NES_FPS)
        name = event["name"]
        if name == "star_music":
            controls.append((sample, "star"))
        elif name == "resume_music":
            controls.append((sample, "ground"))
        elif name in {"death", "flag", "course_clear", "game_over", "pipe"}:
            controls.append((sample, "silence"))

    controls.sort()
    collapsed = []
    for item in controls:
        if collapsed and collapsed[-1][0] == item[0]:
            collapsed[-1] = item
        else:
            collapsed.append(item)
    for index, (start, mode) in enumerate(collapsed):
        stop = collapsed[index + 1][0] if index + 1 < len(collapsed) else total_samples
        if mode == "ground":
            render_ground(music, assets, start, stop)
        elif mode == "star":
            mix_samples(music, assets["star"], start, MUSIC_VOLUME, stop, loop=True)

    controls_only = {"star_music", "resume_music"}
    for event in events:
        if event["type"] != "audio" or event["name"] in controls_only:
            continue
        name = event["name"]
        if name not in assets:
            continue
        start = round(event["frame"] * TARGET_RATE / NES_FPS)
        mix_samples(effects, assets[name], start, SFX_VOLUME)

    output_values = []
    for music_sample, effect_sample in zip(music, effects):
        value = max(-1.0, min(1.0, music_sample + effect_sample))
        integer = max(-32768, min(32767, round(value * 32767.0)))
        output_values.extend((integer, integer))
    raw = struct.pack(f"<{len(output_values)}h", *output_values)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(args.output), "wb") as destination:
        destination.setnchannels(2)
        destination.setsampwidth(2)
        destination.setframerate(TARGET_RATE)
        destination.writeframes(raw)
    manifest = {
        "schema": "smb-actual-audio-v1",
        "frames": args.frames,
        "nes_fps": NES_FPS,
        "sample_rate": TARGET_RATE,
        "sample_frames": total_samples,
        "pcm_sha256": hashlib.sha256(raw).hexdigest(),
        "music_volume": MUSIC_VOLUME,
        "sfx_volume": SFX_VOLUME,
        "resampler": "deterministic linear interpolation",
    }
    args.output.with_suffix(".manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(f"rendered {total_samples} stereo frames: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
