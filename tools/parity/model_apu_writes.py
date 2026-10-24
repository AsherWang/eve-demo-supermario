from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT / "tools"))

from render_smb_rom_music import (  # noqa: E402
    SECTION_SIGNATURES,
    find_once,
    load_header,
    load_prg,
)


SQ1 = 0x4000
SQ2 = 0x4004
TRI = 0x4008
NOISE = 0x400C
DAC = 0x4011
STATUS = 0x4015
FRAME_COUNTER = 0x4017


def load_jsonl(path: Path) -> list[dict]:
    return [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]


class SmbApuModel:
    """Frame-level port of SMB's MusicHandler and the SFX paths used by 1-1.

    The model starts from the first captured sound-RAM image.  Subsequent
    requests come from the remake's semantic event trace, so the comparison
    checks the independent handler port without running the original CPU.
    """

    def __init__(self, prg: bytes, initial_ram: bytes) -> None:
        self.prg = prg
        self.ram = bytearray(initial_ram)
        self.writes: list[tuple[int, int]] = []

        offsets = {
            name: find_once(prg, bytes.fromhex(signature), name)
            for name, signature in SECTION_SIGNATURES.items()
        }
        headers = {
            name: load_header(
                prg,
                name,
                offset,
                name == "star" or name.startswith("ground_"),
            )
            for name, offset in offsets.items()
        }
        self.header_base = headers["time_running_out"].header_offset - 49
        self.frequency_offset = find_once(
            prg,
            bytes.fromhex("0088002f000002a60280025c023a021a01df01c401ab"),
            "frequency register table",
        )
        self.length_offset = find_once(
            prg,
            bytes.fromhex("050a1428501e3c02040810204018300c03060c1830122408"),
            "music length table",
        )
        self.envelope_offset = find_once(
            prg,
            bytes.fromhex("909494959596979890919292939393949494949494959595"),
            "music envelope tables",
        )
        self.brick_envelopes = prg[
            self.envelope_offset + 80 : self.envelope_offset + 96
        ]

    def r(self, address: int) -> int:
        return self.ram[address]

    def s(self, address: int, value: int) -> None:
        self.ram[address] = value & 0xFF

    def dec(self, address: int) -> int:
        value = (self.r(address) - 1) & 0xFF
        self.s(address, value)
        return value

    def inc(self, address: int) -> int:
        value = (self.r(address) + 1) & 0xFF
        self.s(address, value)
        return value

    def write(self, address: int, value: int) -> None:
        self.writes.append((address, value & 0xFF))

    def rom_cpu(self, address: int) -> int:
        if not 0x8000 <= address <= 0xFFFF:
            raise RuntimeError(f"music pointer outside PRG-ROM: {address:#06x}")
        return self.prg[address - 0x8000]

    def music_byte(self, relative: int) -> int:
        pointer = self.r(0xF5) | (self.r(0xF6) << 8)
        return self.rom_cpu((pointer + relative) & 0xFFFF)

    def length(self, value: int) -> tuple[int, int]:
        index = (value & 7) + self.r(0xF0) + self.r(0x07C4)
        return self.prg[self.length_offset + index], index

    def alternate_length(self, value: int) -> tuple[int, int]:
        index = ((value >> 6) & 1) | (((value >> 7) & 1) << 1) | ((value & 1) << 2)
        return self.length(index)

    def set_frequency(self, register: int, note: int) -> tuple[int, int, int]:
        low = self.prg[self.frequency_offset + note + 1]
        x = register - SQ1
        y = note
        if low == 0:
            return 0, x, y
        self.write(register + 2, low)
        high = self.prg[self.frequency_offset + note] | 0x08
        self.write(register + 3, high)
        return high, x, y

    def control_seed(self) -> int:
        if self.r(0x07B1) & 0x08:
            return 0x04
        if self.r(0xF4) & 0x7D:
            return 0x08
        return 0x28

    def envelope(self, index: int) -> int:
        if self.r(0x07B1) & 0x08:
            return self.prg[self.envelope_offset - 4 + index]
        base = self.envelope_offset if self.r(0xF4) & 0x7D else self.envelope_offset + 8
        return self.prg[base + index]

    def stop_square1(self) -> None:
        self.s(0xF1, 0)
        self.write(STATUS, 0x0E)
        self.write(STATUS, 0x0F)

    def stop_square2(self, clear_buffer: bool = False) -> None:
        if clear_buffer:
            self.s(0xF2, 0)
        self.write(STATUS, 0x0D)
        self.write(STATUS, 0x0F)

    def play_square1(self, note: int, control: int, sweep: int) -> None:
        self.write(SQ1 + 1, sweep)
        self.write(SQ1, control)
        self.set_frequency(SQ1, note)

    def play_square2(self, note: int, control: int, sweep: int) -> None:
        self.write(SQ2, control)
        self.write(SQ2 + 1, sweep)
        self.set_frequency(SQ2, note)

    def handle_square1_sfx(self) -> None:
        queue = self.r(0xFF)
        if queue:
            self.s(0xF1, queue)
            selected = queue
            starting = True
        else:
            selected = self.r(0xF1)
            starting = False
        if selected == 0:
            return

        if selected & 0x80:
            kind = "small_jump"
        elif selected & 0x01:
            kind = "big_jump"
        elif selected & 0x02:
            kind = "bump"
        elif selected & 0x04:
            kind = "stomp"
        elif selected & 0x08:
            kind = "smack"
        elif selected & 0x10:
            kind = "pipe"
        elif selected & 0x20:
            kind = "fireball"
        else:
            kind = "flag"

        if starting:
            if kind in {"small_jump", "big_jump"}:
                self.play_square1(0x26 if kind == "small_jump" else 0x18, 0x82, 0xA7)
                self.s(0x07BB, 0x28)
            elif kind == "bump":
                self.s(0x07BB, 0x0A)
                self.play_square1(0x0C, 0x9E, 0x93)
            elif kind == "stomp":
                self.s(0x07BB, 0x0E)
                self.play_square1(0x26, 0x9E, 0x9C)
            elif kind == "smack":
                self.s(0x07BB, 0x0E)
                self.play_square1(0x28, 0x9F, 0xCB)
            elif kind == "pipe":
                self.s(0x07BB, 0x2F)
            elif kind == "fireball":
                self.s(0x07BB, 0x05)
                self.play_square1(0x0C, 0x9E, 0x99)
            else:
                self.s(0x07BB, 0x40)
                self.set_frequency(SQ1, 0x62)
                self.write(SQ1 + 1, 0xBC)
                self.write(SQ1, 0x99)

        length = self.r(0x07BB)
        if kind in {"small_jump", "big_jump"}:
            if length == 0x25:
                self.write(SQ1 + 1, 0xF6)
                self.write(SQ1, 0x5F)
            elif length == 0x20:
                self.write(SQ1 + 1, 0xBC)
                self.write(SQ1, 0x48)
        elif kind in {"bump", "fireball"}:
            if length == 0x06:
                self.write(SQ1 + 1, 0xBB)
        elif kind == "stomp":
            envelope = bytes.fromhex("9f9b989695949290909a97959392")
            self.write(SQ1, envelope[length - 1])
            if length == 0x06:
                self.write(SQ1 + 2, 0x9E)
        elif kind == "smack" and not starting:
            if length == 0x08:
                self.write(SQ1 + 2, 0xA0)
                self.write(SQ1, 0x9F)
            else:
                self.write(SQ1, 0x90)
        elif kind == "pipe":
            shifted = length >> 1
            if not (length & 1) and not (shifted & 1) and (shifted >> 1) & 0x02:
                self.play_square1(0x44, 0x9A, 0x91)

        length = (length - 1) & 0xFF
        self.s(0x07BB, length)
        if length == 0:
            self.stop_square1()

    def handle_square2_sfx(self) -> None:
        buffer = self.r(0xF2)
        queue = self.r(0xFE)
        if buffer & 0x40:
            selected, starting = buffer, False
        elif queue:
            self.s(0xF2, queue)
            selected, starting = queue, True
        else:
            selected, starting = buffer, False
        if selected == 0:
            return

        if selected & 0x80:
            kind = "bowser"
        elif selected & 0x01:
            kind = "coin"
        elif selected & 0x02:
            kind = "reveal"
        elif selected & 0x04:
            kind = "vine"
        elif selected & 0x08:
            kind = "blast"
        elif selected & 0x10:
            kind = "timer"
        elif selected & 0x20:
            kind = "grab"
        else:
            kind = "oneup"

        if kind in {"reveal", "vine"}:
            if starting:
                self.s(0x07BD, 0x10 if kind == "reveal" else 0x20)
                self.write(SQ2 + 1, 0x7F)
                self.s(0x07BE, 0)
            secondary = self.inc(0x07BE)
            index = secondary >> 1
            if index == self.r(0x07BD):
                self.stop_square2(clear_buffer=True)
                return
            sequence = bytes.fromhex(
                "1404222416042426180426281a04282a1c042a2c1e042c2e20042e3022043032"
            )
            self.write(SQ2, 0x9D)
            self.set_frequency(SQ2, sequence[index])
            return

        if starting:
            if kind == "coin":
                self.s(0x07BD, 0x35)
                self.play_square2(0x42, 0x8D, 0x7F)
            elif kind == "blast":
                self.s(0x07BD, 0x20)
                self.play_square2(0x5E, 0x9F, 0x94)
            elif kind == "grab":
                self.s(0x07BD, 0x36)
            elif kind == "oneup":
                self.s(0x07BD, 0x30)
            elif kind == "timer":
                self.s(0x07BD, 0x06)
                self.play_square2(0x42, 0x98, 0x7F)
            elif kind == "bowser":
                self.s(0x07BD, 0x38)
                self.play_square2(0x18, 0x9F, 0xC4)

        length = self.r(0x07BD)
        if kind in {"coin", "timer"} and length == 0x30:
            self.write(SQ2 + 2, 0x54)
        elif kind == "blast" and length == 0x18:
            self.play_square2(0x18, 0x9F, 0x93)
        elif kind == "grab" and not (length & 1):
            sequence = bytes.fromhex(
                "4c524c483e363e3630284a504a643c323c322c243a643a342c222c"
            )
            note = sequence[(length >> 1) - 1]
            self.play_square2(note, 0x5D, 0x7F)
        elif kind == "oneup" and length & 7 == 0:
            sequence = bytes.fromhex("580254564e44")
            self.play_square2(sequence[(length >> 3) - 1], 0x82, 0x7F)
        elif kind == "bowser" and length == 0x08:
            self.play_square2(0x5A, 0x9F, 0xA4)

        length = (length - 1) & 0xFF
        self.s(0x07BD, length)
        if length == 0:
            self.stop_square2(clear_buffer=True)

    def handle_noise_sfx(self) -> None:
        queue = self.r(0xFD)
        if queue:
            self.s(0xF3, queue)
            selected, starting = queue, True
        else:
            selected, starting = self.r(0xF3), False
        if selected == 0:
            return
        if selected & 1:
            if starting:
                self.s(0x07BF, 0x20)
            length = self.r(0x07BF)
            if length & 1:
                index = length >> 1
                frequencies = bytes.fromhex("010e0e0d0b060c0f0a09030d080d060c")
                self.write(NOISE, self.brick_envelopes[index])
                self.write(NOISE + 2, frequencies[index])
                self.write(NOISE + 3, 0x18)
            length = (length - 1) & 0xFF
            self.s(0x07BF, length)
            if length == 0:
                self.write(NOISE, 0xF0)
                self.s(0xF3, 0)

    def load_music_header(self, y: int) -> None:
        header = self.header_base + self.prg[self.header_base - 1 + y]
        self.s(0xF0, self.prg[header])
        self.s(0xF5, self.prg[header + 1])
        self.s(0xF6, self.prg[header + 2])
        self.s(0xF9, self.prg[header + 3])
        self.s(0xF8, self.prg[header + 4])
        self.s(0x07B0, self.prg[header + 5])
        self.s(0x07C1, self.prg[header + 5])
        for address in (0x07B4, 0x07B6, 0x07B9, 0x07BA):
            self.s(address, 1)
        self.s(0xF7, 0)
        self.s(0x07CA, 0)
        self.write(STATUS, 0x0B)
        self.write(STATUS, 0x0F)

    @staticmethod
    def bit_header_index(value: int, start: int) -> int:
        y = start
        while True:
            y += 1
            carry = value & 1
            value >>= 1
            if carry:
                return y

    def restart_area_music(self, value: int) -> None:
        self.s(0x07B1, 0)
        self.s(0xF4, value)
        if value == 1:
            y = self.inc(0x07C7)
            if y == 0x31:
                y = 0x11
                self.s(0x07C7, y)
        else:
            y = self.bit_header_index(value, 8)
        self.load_music_header(y)

    def load_music_request(self) -> bool:
        event = self.r(0xFC)
        if event:
            self.s(0x07B1, event)
            if event == 1:
                self.stop_square1()
                self.stop_square2()
            self.s(0x07C5, self.r(0xF4))
            self.s(0x07C4, 8 if event == 0x40 else 0)
            self.s(0xF4, 0)
            self.load_music_header(self.bit_header_index(event, 0))
            return True

        area = self.r(0xFB)
        if area:
            if area == 4:
                self.stop_square1()
            self.s(0x07C7, 0x10)
            self.restart_area_music(area)
            return True
        return False

    def handle_music(self) -> None:
        loaded = self.load_music_request()
        if not loaded and not (self.r(0x07B1) or self.r(0xF4)):
            return

        while True:
            if self.dec(0x07B4) != 0:
                break
            offset = self.r(0xF7)
            self.s(0xF7, offset + 1)
            value = self.music_byte(offset)
            if value == 0:
                event = self.r(0x07B1)
                if event == 0x40 and self.r(0x07C5):
                    self.restart_area_music(self.r(0x07C5))
                    continue
                if event & 0x04:
                    self.load_music_header(self.bit_header_index(event, 0))
                    continue
                area = self.r(0xF4) & 0x5F
                if area:
                    self.restart_area_music(area)
                    continue
                self.s(0xF4, 0)
                self.s(0x07B1, 0)
                self.write(TRI, 0)
                self.write(SQ1, 0x90)
                self.write(SQ2, 0x90)
                return
            if value & 0x80:
                length, _ = self.length(value)
                self.s(0x07B3, length)
                offset = self.r(0xF7)
                self.s(0xF7, offset + 1)
                value = self.music_byte(offset)
            if self.r(0xF2) == 0:
                a, x, y = self.set_frequency(SQ2, value)
                if a:
                    a, x, y = self.control_seed(), 0x82, 0x7F
                self.s(0x07B5, a)
                self.write(SQ2, x)
                self.write(SQ2 + 1, y)
            self.s(0x07B4, self.r(0x07B3))
            break

        if self.r(0xF2) == 0 and not (self.r(0x07B1) & 0x91):
            y = self.r(0x07B5)
            if y:
                self.dec(0x07B5)
            self.write(SQ2, self.envelope(y))
            self.write(SQ2 + 1, 0x7F)

        if self.r(0xF8):
            if self.dec(0x07B6) == 0:
                while True:
                    offset = self.r(0xF8)
                    self.s(0xF8, offset + 1)
                    value = self.music_byte(offset)
                    if value:
                        break
                    self.write(SQ1, 0x83)
                    self.write(SQ1 + 1, 0x94)
                    self.s(0x07CA, 0x94)
                length, _ = self.alternate_length(value)
                self.s(0x07B6, length)
                if self.r(0xF1) == 0:
                    a, x, y = self.set_frequency(SQ1, value & 0x3E)
                    if a:
                        a, x, y = self.control_seed(), 0x82, 0x7F
                    self.s(0x07B7, a)
                    self.write(SQ1 + 1, y)
                    self.write(SQ1, x)
            if self.r(0xF1) == 0:
                if not (self.r(0x07B1) & 0x91):
                    y = self.r(0x07B7)
                    if y:
                        self.dec(0x07B7)
                    self.write(SQ1, self.envelope(y))
                self.write(SQ1 + 1, self.r(0x07CA) or 0x7F)

        if self.dec(0x07B9) == 0:
            offset = self.r(0xF9)
            self.s(0xF9, offset + 1)
            value = self.music_byte(offset)
            if value & 0x80:
                length, _ = self.length(value)
                self.s(0x07B8, length)
                self.write(TRI, 0x1F)
                offset = self.r(0xF9)
                self.s(0xF9, offset + 1)
                value = self.music_byte(offset)
            if value:
                self.set_frequency(TRI, value)
                length = self.r(0x07B8)
                self.s(0x07B9, length)
                sustained = (self.r(0x07B1) & 0x6E) or (self.r(0xF4) & 0x0A)
                if sustained:
                    self.write(TRI, 0xFF if length >= 0x12 else 0x1F)
            else:
                self.write(TRI, 0)

        if self.r(0xF4) & 0xF3 and self.dec(0x07BA) == 0:
            while True:
                offset = self.r(0x07B0)
                self.s(0x07B0, offset + 1)
                value = self.music_byte(offset)
                if value:
                    break
                self.s(0x07B0, self.r(0x07C1))
            length, y = self.alternate_length(value)
            self.s(0x07BA, length)
            beat = value & 0x3E
            if beat == 0x30:
                a, x, y = 0x1C, 0x03, 0x58
            elif beat == 0x20:
                a, x, y = 0x1C, 0x0C, 0x18
            elif beat & 0x10:
                a, x, y = 0x1C, 0x03, 0x18
            else:
                a, x = 0x10, value
            self.write(NOISE, a)
            self.write(NOISE + 2, x)
            self.write(NOISE + 3, y)

    def step(self) -> list[tuple[int, int]]:
        self.writes = []
        self.write(FRAME_COUNTER, 0xFF)
        self.write(STATUS, 0x0F)
        self.handle_square1_sfx()
        self.handle_square2_sfx()
        self.handle_noise_sfx()
        self.handle_music()
        for address in (0xFB, 0xFC, 0xFF, 0xFE, 0xFD, 0xFA):
            self.s(address, 0)
        old_dac = self.r(0x07C0)
        if self.r(0xF4) & 3:
            self.inc(0x07C0)
            if old_dac >= 0x30:
                self.dec(0x07C0)
        elif old_dac:
            self.dec(0x07C0)
        self.write(DAC, old_dac)
        return self.writes

    def queue_event(self, event: dict, state: dict | None) -> None:
        if event.get("type") == "audio":
            name = event.get("name")
            sq1 = {
                "bump": 0x02,
                "stomp": 0x04,
                "kick": 0x08,
                "pipe": 0x10,
                "fireball": 0x20,
                "flag": 0x40,
            }
            sq2 = {"coin": 0x01, "blast": 0x08, "oneup": 0x40}
            if name == "jump":
                big = bool(state and state.get("player", {}).get("big"))
                self.s(0xFF, 0x01 if big else 0x80)
            elif name in sq1:
                self.s(0xFF, sq1[name])
            elif name in sq2:
                self.s(0xFE, sq2[name])
            elif name == "break":
                self.s(0xFD, 0x01)
            elif name == "powerup":
                self.s(0xFE, 0x02 if event.get("variant") == "reveal" else 0x20)
            elif name == "death":
                self.s(0xFC, 0x01)
            elif name == "course_clear":
                self.s(0xFC, 0x20)
            elif name == "hurry":
                self.s(0xFC, 0x40)
            elif name == "game_over":
                self.s(0xFC, 0x02)
            elif name == "star_music":
                self.s(0xFB, 0x40)
            elif name == "resume_music":
                self.s(0xFB, 0x01)
        elif event.get("type") == "music":
            name = event.get("name")
            if name == "silence":
                self.s(0xFC, 0x80)
            elif name == "underground" and event.get("frame", 0) > 0:
                self.s(0xFB, 0x04)
            elif name == "overworld" and event.get("frame", 0) > 0:
                self.s(0xFB, 0x01)


def main() -> int:
    parser = argparse.ArgumentParser(description="Model SMB APU writes from ROM data and remake events.")
    parser.add_argument("--rom", type=Path, required=True)
    parser.add_argument("--initial-ram-trace", type=Path, required=True)
    parser.add_argument("--events", type=Path, required=True)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--frames", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    prg, rom_sha256 = load_prg(args.rom.resolve())
    initial_rows = load_jsonl(args.initial_ram_trace.resolve())
    if not initial_rows or initial_rows[0].get("frame") != 0:
        raise SystemExit("initial RAM trace must contain comparison frame 0")
    initial_ram = bytes.fromhex(initial_rows[0]["ram_hex"])
    events_by_frame: dict[int, list[dict]] = defaultdict(list)
    loaded_events = load_jsonl(args.events.resolve())
    reveal_frames = {
        int(event["frame"])
        for event in loaded_events
        if event.get("type") == "gameplay" and event.get("name") == "powerup_spawn"
    }
    for event in loaded_events:
        if (event.get("type") == "audio" and event.get("name") == "powerup"
                and int(event["frame"]) in reveal_frames):
            event = {**event, "variant": "reveal"}
        events_by_frame[int(event["frame"])].append(event)
    states = {int(row["frame"]): row for row in load_jsonl(args.state.resolve())}

    model = SmbApuModel(prg, initial_ram)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    records = []
    for frame in range(1, args.frames):
        previous = frame - 1
        for event in events_by_frame.get(previous, []):
            model.queue_event(event, states.get(previous))
        state = states.get(frame, {})
        rom_state = state.get("rom_state", {})
        # Area initialization resets FrameCounter to zero in a pass that does
        # not call SoundEngine.  The queued silence request survives and is
        # consumed on the following frame.
        skip_sound_engine = (
            state.get("frame_counter") == 0
            and rom_state.get("oper_mode_task") == 1
        )
        writes = [] if skip_sound_engine else model.step()
        for sequence, (address, value) in enumerate(writes):
            records.append({
                "frame": frame,
                "sequence": sequence,
                "address": address,
                "value": value,
            })
    args.output.write_text(
        "".join(json.dumps(row, separators=(",", ":")) + "\n" for row in records),
        encoding="utf-8",
    )
    manifest = {
        "schema": "smb-apu-model-v1",
        "rom_sha256": rom_sha256,
        "frames": args.frames,
        "writes": len(records),
        "initial_state": "reference frame-0 sound RAM",
        "input": "EVEngine semantic event and state traces",
    }
    args.output.with_suffix(".manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(f"modeled {len(records)} APU writes: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
