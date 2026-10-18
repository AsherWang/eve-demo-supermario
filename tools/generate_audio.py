#!/usr/bin/env python3
"""Generate local NES-style placeholder sound effects for the EVEngine runtime.

Music is intentionally not generated here.  Run render_smb_rom_music.py with
the user's ROM to produce ROM-data-driven music without hand-tuned tempos.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
NTSC_FRAME_HZ = 60.0988
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"


def write(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    peak = max(1.0, max(abs(v) for v in samples))
    pcm = b"".join(struct.pack("<h", int(max(-1, min(1, v / peak)) * 15000)) for v in samples)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as wav:
        wav.setparams((1, 2, RATE, len(samples), "NONE", "not compressed"))
        wav.writeframes(pcm)


def pulse(freq: float, duration: float, duty: float = 0.5, fade: bool = True) -> list[float]:
    count = int(RATE * duration)
    result = []
    for i in range(count):
        phase = (i * freq / RATE) % 1.0
        env = (1.0 - i / count) if fade else 1.0
        result.append((1.0 if phase < duty else -1.0) * env)
    return result


def sweep(start: float, end: float, duration: float, duty: float = 0.5) -> list[float]:
    count = int(RATE * duration)
    phase = 0.0
    result = []
    for i in range(count):
        t = i / max(1, count - 1)
        phase = (phase + (start + (end - start) * t) / RATE) % 1.0
        result.append((1.0 if phase < duty else -1.0) * (1.0 - t))
    return result


def noise(duration: float) -> list[float]:
    rng = random.Random(1985)
    count = int(RATE * duration)
    return [(1 if rng.random() > 0.5 else -1) * (1 - i / count) for i in range(count)]


def melody(notes: list[tuple[float, float]], loop_pad: float = 0.0) -> list[float]:
    result: list[float] = []
    for frequency, duration in notes:
        if frequency <= 0:
            result.extend([0.0] * int(RATE * duration))
        else:
            result.extend(pulse(frequency, duration, 0.25, False))
    result.extend([0.0] * int(RATE * loop_pad))
    return result


def brick_shatter() -> list[float]:
    """Render the ROM's 32-frame noise SFX table instead of white noise."""
    frequencies = [
        0x01, 0x0E, 0x0E, 0x0D, 0x0B, 0x06, 0x0C, 0x0F,
        0x0A, 0x09, 0x03, 0x0D, 0x08, 0x0D, 0x06, 0x0C,
    ]
    envelopes = [
        0x15, 0x16, 0x16, 0x17, 0x17, 0x18, 0x19, 0x19,
        0x1A, 0x1A, 0x1C, 0x1D, 0x1D, 0x1E, 0x1E, 0x1F,
    ]
    periods = [4, 8, 16, 32, 64, 96, 128, 160,
               202, 254, 380, 508, 762, 1016, 2034, 4068]
    state = 1
    phase = 0.0
    result: list[float] = []
    # The 6502 indexes the tables from 15 down to 0, changing every 2 frames.
    for table_index in range(15, -1, -1):
        count = int(RATE * (2.0 / NTSC_FRAME_HZ))
        clock = min(RATE * 0.48, 1_789_773 / periods[frequencies[table_index]])
        volume = (envelopes[table_index] & 0x0F) / 15.0
        for _ in range(count):
            phase += clock / RATE
            while phase >= 1.0:
                feedback = (state ^ (state >> 1)) & 1
                state = (state >> 1) | (feedback << 14)
                phase -= 1.0
            result.append((1.0 if state & 1 else -1.0) * volume)
    return result


def main() -> None:
    write("jump", sweep(280, 720, 0.18, 0.25))
    write("coin", pulse(988, 0.06, 0.5) + pulse(1319, 0.18, 0.5))
    write("bump", pulse(110, 0.10, 0.25))
    write("break", brick_shatter())
    write("powerup", sweep(220, 880, 0.55, 0.25))
    write("oneup", melody([(659, .08), (784, .08), (988, .08), (1319, .28)]))
    write("stomp", sweep(180, 90, 0.11, 0.5))
    write("kick", sweep(120, 240, 0.08, 0.25))
    write("fireball", pulse(330, 0.06, 0.25) + noise(0.05))
    write("pipe", sweep(300, 90, 0.35, 0.5))
    write("flag", sweep(440, 1047, 0.55, 0.25))
    write("blast", noise(0.18))


if __name__ == "__main__":
    main()
