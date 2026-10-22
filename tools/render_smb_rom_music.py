#!/usr/bin/env python3
"""Render SMB music from a user-owned iNES ROM.

This is a structural port of the original MusicHandler: music headers, channel
offsets, note bytes, length bytes, frequency dividers, envelopes and the ground
music layout are all read from the ROM.  The sequencer advances at the NTSC NMI
rate instead of using a hand-tuned BPM or a fixed note duration.

The output stage models the four 2A03 channels used by these songs and applies
the documented nonlinear mixer and analogue filter chain.  It is deterministic
and frame/event exact; it is not a CPU-cycle emulator.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import wave
from dataclasses import dataclass
from pathlib import Path


RATE = 48_000
NTSC_CPU_HZ = 1_789_773.0
NTSC_FRAME_HZ = 60.0988
NOISE_PERIODS = [
    4, 8, 16, 32, 64, 96, 128, 160,
    202, 254, 380, 508, 762, 1016, 2034, 4068,
]
PULSE_DUTIES = [0.125, 0.25, 0.5, 0.75]
STARTUP_RAMP_SECONDS = 0.002
# Calibrated against the Mesen 48 kHz World 1-1 capture.  The first-order
# 14 kHz NES analogue approximation alone leaves too much folded high-band
# energy when this frame-level renderer is sampled directly.
RUNTIME_LOWPASS_HZ = 7_200.0


def poly_blep(phase: float, step: float) -> float:
    """Band-limit a discontinuity without changing its pitch or duty cycle."""
    if phase < step:
        value = phase / step
        return value + value - value * value - 1.0
    if phase > 1.0 - step:
        value = (phase - 1.0) / step
        return value * value + value + value + 1.0
    return 0.0


def find_once(data: bytes, signature: bytes, label: str) -> int:
    offset = data.find(signature)
    if offset < 0:
        raise SystemExit(f"Could not find {label}; incompatible ROM")
    if data.find(signature, offset + 1) >= 0:
        raise SystemExit(f"Found multiple {label} signatures; refusing to guess")
    return offset


def load_prg(path: Path) -> tuple[bytes, str]:
    rom = path.read_bytes()
    if rom[:4] != b"NES\x1a":
        raise SystemExit("Not an iNES ROM")
    mapper = (rom[6] >> 4) | (rom[7] & 0xF0)
    if mapper != 0:
        raise SystemExit(f"Expected SMB mapper 0, found mapper {mapper}")
    trainer = 512 if rom[6] & 0x04 else 0
    size = rom[4] * 16_384
    start = 16 + trainer
    prg = rom[start : start + size]
    if len(prg) != 32_768:
        raise SystemExit(f"Expected 32 KiB SMB PRG-ROM, found {len(prg)} bytes")
    return prg, hashlib.sha256(rom).hexdigest()


def cpu_address(prg_offset: int) -> int:
    return 0x8000 + prg_offset


@dataclass(frozen=True)
class MusicHeader:
    name: str
    header_offset: int
    data_offset: int
    length_offset: int
    triangle_offset: int
    square1_offset: int
    noise_offset: int
    area_music: bool


SECTION_SIGNATURES = {
    "star": "842c2c2c82042c04852c842c2c2a2a2a",
    "ground_p1": "852c221c84262a822826048722343a82",
    "ground_p2a": "8404823a38363204340424262c04262c30",
    "ground_p2b": "8404823a383632043404640464866400",
    "ground_p2c": "840485328530862c0400",
    "ground_p3a": "822c842c2c822c3004342c0426862200",
    "ground_p3b": "822c2c042c042c308534040400",
    "ground_lead": "8234843434822c8434863a0400",
    "ground_p4a": "8234842c852284248226360436862600",
    "ground_p4b": "872a4040403a3682342c0426862200",
    "ground_p4c": "822a36043687363430862c0400",
    "death": "8604822a36043687363430862c0400",
    "game_over": "822c0404220404841c87262a26842428",
    "time_running_out": "811c30043030041e3204323204203404",
    "course_clear": "8704060c141c22862c228704600e141a",
}


def locate_header(prg: bytes, data_offset: int, label: str) -> int:
    address = cpu_address(data_offset)
    pointer = bytes((address & 0xFF, address >> 8))
    candidates = []
    cursor = 0
    while True:
        found = prg.find(pointer, cursor)
        if found < 0:
            break
        if found > 0 and prg[found - 1] in (0x00, 0x08, 0x10, 0x18, 0x20, 0x28):
            candidates.append(found - 1)
        cursor = found + 1
    if len(candidates) != 1:
        raise SystemExit(
            f"Expected one ROM music header for {label}, found {len(candidates)}"
        )
    return candidates[0]


def load_header(
    prg: bytes, name: str, data_offset: int, area_music: bool
) -> MusicHeader:
    header_offset = locate_header(prg, data_offset, name)
    return MusicHeader(
        name=name,
        header_offset=header_offset,
        data_offset=data_offset,
        length_offset=prg[header_offset],
        triangle_offset=prg[header_offset + 3],
        square1_offset=prg[header_offset + 4],
        noise_offset=prg[header_offset + 5] if area_music else 0,
        area_music=area_music,
    )


class Pulse:
    def __init__(self) -> None:
        self.timer = 0
        self.volume = 0
        self.duty = 2
        self.phase = 0.0
        self.active = False

    def set_note(self, timer: int | None) -> None:
        self.active = timer is not None
        if timer is not None:
            self.timer = timer
            # Writing $4003/$4007 resets the pulse sequencer.
            self.phase = 0.0

    def set_control(self, value: int) -> None:
        self.duty = (value >> 6) & 3
        self.volume = value & 0x0F

    def sample(self) -> float:
        if not self.active or self.volume == 0:
            return 0.0
        frequency = NTSC_CPU_HZ / (16.0 * (self.timer + 1))
        step = min(frequency / RATE, 0.5)
        self.phase = (self.phase + step) % 1.0
        duty = PULSE_DUTIES[self.duty]
        value = 1.0 if self.phase < duty else -1.0
        value += poly_blep(self.phase, step)
        value -= poly_blep((self.phase - duty) % 1.0, step)
        return float(self.volume) * (value + 1.0) * 0.5


class Triangle:
    def __init__(self) -> None:
        self.timer = 0
        self.phase = 0.0
        self.active = False

    def set_note(self, timer: int | None) -> None:
        self.active = timer is not None
        if timer is not None:
            self.timer = timer

    def sample(self) -> float:
        if not self.active:
            return 0.0
        frequency = NTSC_CPU_HZ / (32.0 * (self.timer + 1))
        self.phase = (self.phase + frequency * 32.0 / RATE) % 32.0
        step = int(self.phase) & 31
        return float(15 - step if step < 16 else step - 16)


class Noise:
    def __init__(self) -> None:
        self.period_index = 0
        self.volume = 0
        self.phase = 0.0
        self.shift = 1
        self.active = False

    def set_beat(self, beat: int) -> None:
        if beat == 0:
            self.active = False
            self.volume = 0
            return
        self.active = True
        self.volume = 12
        self.period_index = 12 if beat == 0x20 else 3

    def sample(self) -> float:
        if not self.active or self.volume == 0:
            return 0.0
        clocks = NTSC_CPU_HZ / NOISE_PERIODS[self.period_index]
        self.phase += clocks / RATE
        while self.phase >= 1.0:
            feedback = (self.shift & 1) ^ ((self.shift >> 1) & 1)
            self.shift = (self.shift >> 1) | (feedback << 14)
            self.phase -= 1.0
        return float(self.volume) if not self.shift & 1 else 0.0


class FilterChain:
    def __init__(self) -> None:
        self.hp90 = [0.0, 0.0]
        self.hp440 = [0.0, 0.0]
        self.lp14k = 0.0
        self.lp_runtime = 0.0

    @staticmethod
    def high_pass(value: float, state: list[float], cutoff: float) -> float:
        dt = 1.0 / RATE
        rc = 1.0 / (2.0 * math.pi * cutoff)
        alpha = rc / (rc + dt)
        output = alpha * (state[1] + value - state[0])
        state[0], state[1] = value, output
        return output

    def process(self, value: float) -> float:
        value = self.high_pass(value, self.hp90, 90.0)
        value = self.high_pass(value, self.hp440, 440.0)
        dt = 1.0 / RATE
        rc = 1.0 / (2.0 * math.pi * 14_000.0)
        alpha = dt / (rc + dt)
        self.lp14k += alpha * (value - self.lp14k)
        rc_runtime = 1.0 / (2.0 * math.pi * RUNTIME_LOWPASS_HZ)
        alpha_runtime = dt / (rc_runtime + dt)
        self.lp_runtime += alpha_runtime * (self.lp14k - self.lp_runtime)
        return self.lp_runtime


class MusicSequencer:
    def __init__(
        self,
        prg: bytes,
        headers: list[MusicHeader],
        frequency_table: bytes,
        length_table: bytes,
        area_envelopes: bytes,
        event_envelopes: bytes,
        repeat: bool,
    ) -> None:
        self.prg = prg
        self.headers = headers
        self.frequency_table = frequency_table
        self.length_table = length_table
        self.area_envelopes = area_envelopes
        self.event_envelopes = event_envelopes
        self.repeat = repeat
        self.section_index = 0
        self.header = headers[0]
        self.square2 = Pulse()
        self.square1 = Pulse()
        self.triangle = Triangle()
        self.noise = Noise()
        self.filters = FilterChain()
        self.sq2_length_buffer = 1
        self.triangle_length_buffer = 1
        self.sq2_envelope = 0
        self.sq1_envelope = 0
        self.frame = 0
        self.finished = False
        self.wrapped = False
        self._load_section(self.header)

    def _load_section(self, header: MusicHeader) -> None:
        self.header = header
        self.sq2_offset = 0
        self.sq1_offset = header.square1_offset
        self.triangle_offset = header.triangle_offset
        self.noise_offset = header.noise_offset
        self.noise_loop_offset = header.noise_offset
        self.sq2_counter = 1
        self.sq1_counter = 1
        self.triangle_counter = 1
        self.noise_counter = 1
        # The original writes $0b then $0f to $4015 on every new header.
        self.triangle.active = False

    def _advance_section(self) -> bool:
        self.section_index += 1
        if self.section_index >= len(self.headers):
            if not self.repeat:
                self.finished = True
                return False
            self.section_index = 0
            self.wrapped = True
            return False
        self._load_section(self.headers[self.section_index])
        return True

    def _data(self, relative_offset: int) -> int:
        return self.prg[self.header.data_offset + relative_offset]

    def _length(self, index: int) -> int:
        table_index = self.header.length_offset + (index & 7)
        if table_index >= len(self.length_table):
            raise RuntimeError(f"music length index {table_index:#x} is out of range")
        return self.length_table[table_index]

    def _alternate_length(self, value: int) -> int:
        index = ((value >> 6) & 1) | (((value >> 7) & 1) << 1) | ((value & 1) << 2)
        return self._length(index)

    def _timer(self, note: int) -> int | None:
        if note + 1 >= len(self.frequency_table):
            raise RuntimeError(f"music frequency index {note:#x} is out of range")
        low = self.frequency_table[note + 1]
        if low == 0:
            return None
        high = self.frequency_table[note] & 7
        return (high << 8) | low

    def _control_seed(self) -> int:
        return 8 if self.header.area_music else 40

    def _envelope_value(self, counter: int) -> int:
        table = self.area_envelopes if self.header.area_music else self.event_envelopes
        return table[min(counter, len(table) - 1)]

    def _set_square_note(self, channel: Pulse, note: int, square2: bool) -> None:
        timer = self._timer(note)
        channel.set_note(timer)
        if timer is None:
            if square2:
                self.sq2_envelope = 0
            else:
                self.sq1_envelope = 0
            channel.set_control(0)
            return
        if square2:
            self.sq2_envelope = self._control_seed()
        else:
            self.sq1_envelope = self._control_seed()

    def _process_square2(self) -> bool:
        self.sq2_counter -= 1
        if self.sq2_counter == 0:
            while True:
                value = self._data(self.sq2_offset)
                self.sq2_offset += 1
                if value == 0:
                    if not self._advance_section():
                        return False
                    self.sq2_counter -= 1
                    continue
                if value & 0x80:
                    self.sq2_length_buffer = self._length(value)
                    value = self._data(self.sq2_offset)
                    self.sq2_offset += 1
                self._set_square_note(self.square2, value, True)
                self.sq2_counter = self.sq2_length_buffer
                break
        if self.sq2_envelope > 0:
            self.sq2_envelope -= 1
        self.square2.set_control(self._envelope_value(self.sq2_envelope))
        return True

    def _process_square1(self) -> None:
        if self.sq1_offset == 0:
            return
        self.sq1_counter -= 1
        if self.sq1_counter == 0:
            while True:
                value = self._data(self.sq1_offset)
                self.sq1_offset += 1
                if value != 0:
                    break
            self.sq1_counter = self._alternate_length(value)
            self._set_square_note(self.square1, value & 0x3E, False)
        if self.sq1_envelope > 0:
            self.sq1_envelope -= 1
        self.square1.set_control(self._envelope_value(self.sq1_envelope))

    def _process_triangle(self) -> None:
        self.triangle_counter -= 1
        if self.triangle_counter != 0:
            return
        value = self._data(self.triangle_offset)
        self.triangle_offset += 1
        if value == 0:
            self.triangle.active = False
            self.triangle_counter = 1
            return
        if value & 0x80:
            self.triangle_length_buffer = self._length(value)
            value = self._data(self.triangle_offset)
            self.triangle_offset += 1
        self.triangle.set_note(self._timer(value))
        self.triangle_counter = self.triangle_length_buffer

    def _process_noise(self) -> None:
        if not self.header.area_music or self.noise_offset == 0:
            self.noise.active = False
            return
        self.noise_counter -= 1
        if self.noise_counter != 0:
            return
        while True:
            value = self._data(self.noise_offset)
            self.noise_offset += 1
            if value != 0:
                break
            self.noise_offset = self.noise_loop_offset
        self.noise_counter = self._alternate_length(value)
        self.noise.set_beat(value & 0x3E)

    def step_frame(self) -> list[float] | None:
        self.wrapped = False
        if not self._process_square2():
            return None
        self._process_square1()
        self._process_triangle()
        self._process_noise()

        start = round(self.frame * RATE / NTSC_FRAME_HZ)
        self.frame += 1
        end = round(self.frame * RATE / NTSC_FRAME_HZ)
        samples = []
        for _ in range(end - start):
            p1 = self.square1.sample()
            p2 = self.square2.sample()
            tri = self.triangle.sample()
            noise = self.noise.sample()
            pulse = 0.0 if p1 + p2 == 0 else 95.88 / (8128.0 / (p1 + p2) + 100.0)
            tnd_divisor = tri / 8227.0 + noise / 12241.0
            tnd = 0.0 if tnd_divisor == 0 else 159.79 / (1.0 / tnd_divisor + 100.0)
            samples.append(self.filters.process(pulse + tnd))
        return samples


def render_track(
    prg: bytes,
    headers: list[MusicHeader],
    tables: tuple[bytes, bytes, bytes, bytes],
    repeat: bool,
    max_frames: int = 60_000,
) -> tuple[list[float], int]:
    renderer = MusicSequencer(prg, headers, *tables, repeat=repeat)
    output: list[float] = []
    for _ in range(max_frames):
        frame = renderer.step_frame()
        if frame is None:
            break
        output.extend(frame)
    else:
        raise RuntimeError("music renderer exceeded frame guard")
    return output, renderer.frame


def render_fixed_frames(
    prg: bytes,
    headers: list[MusicHeader],
    tables: tuple[bytes, bytes, bytes, bytes],
    frames: int,
) -> list[float]:
    """Render one continuous source while preserving oscillator/filter state."""
    renderer = MusicSequencer(prg, headers, *tables, repeat=False)
    output: list[float] = []
    for frame_index in range(frames):
        frame = renderer.step_frame()
        if frame is None:
            raise RuntimeError(
                f"music data ended at frame {frame_index}, before requested frame {frames}"
            )
        output.extend(frame)
    return output


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = bytearray()
    ramp_samples = min(len(samples), round(RATE * STARTUP_RAMP_SECONDS))
    for index, sample in enumerate(samples):
        if index < ramp_samples:
            sample *= index / max(1, ramp_samples - 1)
        value = max(-1.0, min(1.0, sample))
        pcm.extend(struct.pack("<h", int(value * 30_000)))
    with wave.open(str(path), "wb") as wav:
        wav.setparams((1, 2, RATE, len(samples), "NONE", "not compressed"))
        wav.writeframes(pcm)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rom", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    prg, rom_sha256 = load_prg(args.rom)
    offsets = {
        name: find_once(prg, bytes.fromhex(signature), name)
        for name, signature in SECTION_SIGNATURES.items()
    }
    area_names = {"star", *(name for name in offsets if name.startswith("ground_"))}
    headers = {
        name: load_header(prg, name, offset, name in area_names)
        for name, offset in offsets.items()
    }

    # The first event header follows the 49-byte offset/layout table.  Reading
    # the layout through MusicHeaderData-1 reproduces GroundMusicHeaderOfs.
    music_header_base = headers["time_running_out"].header_offset - 49
    header_by_offset = {header.header_offset: header for header in headers.values()}
    ground_layout: list[MusicHeader] = []
    for table_index in range(16, 49):
        target = music_header_base + prg[music_header_base + table_index]
        if target not in header_by_offset:
            raise SystemExit(
                f"Unknown ground layout header at PRG {target:#06x}; refusing to guess"
            )
        ground_layout.append(header_by_offset[target])

    freq_offset = find_once(
        prg,
        bytes.fromhex("0088002f000002a60280025c023a021a01df01c401ab"),
        "frequency register table",
    )
    length_offset = find_once(
        prg,
        bytes.fromhex("050a1428501e3c02040810204018300c03060c1830122408"),
        "music length table",
    )
    envelope_offset = find_once(
        prg,
        bytes.fromhex("909494959596979890919292939393949494949494959595"),
        "music envelope tables",
    )
    tables = (
        prg[freq_offset : freq_offset + 0x80],
        prg[length_offset : length_offset + 48],
        prg[envelope_offset : envelope_offset + 8],
        prg[envelope_offset + 8 : envelope_offset + 48],
    )

    tracks = {
        "death": ([headers["death"]], False),
        "course_clear": ([headers["course_clear"]], False),
        "game_over": ([headers["game_over"]], False),
    }
    manifest_tracks = {}
    for name, (track_headers, repeat) in tracks.items():
        samples, frames = render_track(prg, track_headers, tables, repeat)
        wav_path = args.output / f"{name}.wav"
        write_wav(wav_path, samples)
        manifest_tracks[name] = {
            "frames": frames,
            "samples": len(samples),
            "duration_seconds": len(samples) / RATE,
            "repeat": repeat,
            "sections": [header.name for header in track_headers],
            "wav_sha256": hashlib.sha256(wav_path.read_bytes()).hexdigest(),
        }

    # The interactive runtime uses finite, continuous streams rather than
    # joining separately rendered intro/loop WAV files.  This preserves pulse
    # phase and analogue-filter state across the original ground-music loopback.
    # 9,600 frames cover the complete World 1-1 timer window; two copies of the
    # ROM layout provide enough source data without wrapping the renderer.
    continuous_tracks = {
        "overworld": (9600, [ground_layout[0], *ground_layout[1:], *ground_layout[1:]]),
        # The star timer is 35 * 21 = 735 frames; four full ROM sections cover it.
        "star": (768, [headers["star"]] * 5),
    }
    for name, (frames, track_headers) in continuous_tracks.items():
        samples = render_fixed_frames(prg, track_headers, tables, frames)
        wav_path = args.output / f"{name}.wav"
        write_wav(wav_path, samples)
        manifest_tracks[name] = {
            "frames": frames,
            "samples": len(samples),
            "duration_seconds": len(samples) / RATE,
            "repeat": False,
            "continuous_runtime_stream": True,
            "sections": [header.name for header in track_headers],
            "wav_sha256": hashlib.sha256(wav_path.read_bytes()).hexdigest(),
        }

    # Retain the intro as a provenance/debug artifact; runtime playback no
    # longer joins this file to overworld.wav.
    intro_samples, intro_frames = render_track(prg, [ground_layout[0]], tables, False)
    intro_path = args.output / "overworld_intro.wav"
    write_wav(intro_path, intro_samples)
    manifest_tracks["overworld_intro"] = {
        "frames": intro_frames,
        "samples": len(intro_samples),
        "duration_seconds": len(intro_samples) / RATE,
        "repeat": False,
        "runtime_asset": False,
        "sections": [ground_layout[0].name],
        "wav_sha256": hashlib.sha256(intro_path.read_bytes()).hexdigest(),
    }

    manifest = {
        "generator": "tools/render_smb_rom_music.py",
        "generator_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "rom_sha256": rom_sha256,
        "timing": {
            "region": "NTSC",
            "cpu_hz": NTSC_CPU_HZ,
            "frame_hz": NTSC_FRAME_HZ,
            "sample_rate": RATE,
            "runtime_lowpass_hz": RUNTIME_LOWPASS_HZ,
            "startup_ramp_seconds": STARTUP_RAMP_SECONDS,
        },
        "rom_offsets": {
            "frequency_table": freq_offset,
            "length_table": length_offset,
            "music_header_data": music_header_base,
            "area_envelope_table": envelope_offset,
            "sections": {
                name: {
                    "header": header.header_offset,
                    "data": header.data_offset,
                    "length_offset": header.length_offset,
                    "triangle_offset": header.triangle_offset,
                    "square1_offset": header.square1_offset,
                    "noise_offset": header.noise_offset,
                    "header_bytes": prg[
                        header.header_offset : header.header_offset +
                        (6 if header.area_music else 5)
                    ].hex(),
                    "data_prefix": prg[
                        header.data_offset : header.data_offset + 16
                    ].hex(),
                }
                for name, header in headers.items()
            },
        },
        "tracks": manifest_tracks,
    }
    (args.output / "rom-music-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
