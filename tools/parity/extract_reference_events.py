from __future__ import annotations

import argparse
import json
from pathlib import Path


QUEUE_NAMES = {
    0xFA: "pause",
    0xFB: "area_music",
    0xFC: "event_music",
    0xFD: "noise_sfx",
    0xFE: "square2_sfx",
    0xFF: "square1_sfx",
}

# Values and queue ownership come directly from the SMBDIS constants/handlers.
BIT_EVENTS = {
    0xFB: {
        0x01: ("music", "overworld"),
        0x02: ("music", "water"),
        0x04: ("music", "underground"),
        0x08: ("music", "castle"),
        0x10: ("music", "cloud"),
        0x20: ("music", "pipe_intro"),
        0x40: ("music", "star"),
        0x80: ("music", "silence"),
    },
    0xFC: {
        0x01: ("audio", "death"),
        0x02: ("audio", "game_over"),
        0x04: ("music", "victory"),
        0x08: ("music", "end_castle"),
        0x20: ("audio", "course_clear"),
        0x40: ("music", "time_warning"),
        0x80: ("music", "silence"),
    },
    0xFD: {
        0x01: ("audio", "break"),
        0x02: ("audio", "bowser_flame"),
    },
    0xFE: {
        0x01: ("audio", "coin"),
        0x02: ("audio", "powerup"),
        0x04: ("audio", "vine"),
        0x08: ("audio", "blast"),
        0x10: ("audio", "timer_tick"),
        0x20: ("audio", "powerup"),
        0x40: ("audio", "oneup"),
        0x80: ("audio", "bowser_fall"),
    },
    0xFF: {
        0x01: ("audio", "jump"),
        0x02: ("audio", "bump"),
        0x04: ("audio", "stomp"),
        0x08: ("audio", "kick"),
        0x10: ("audio", "pipe"),
        0x20: ("audio", "fireball"),
        0x40: ("audio", "flag"),
        0x80: ("audio", "jump"),
    },
}


def load_ram_trace(path: Path | None) -> list[tuple[int, bytes]]:
    if path is None:
        return []
    frames = []
    with path.open("r", encoding="utf-8") as source:
        for line in source:
            if not line.strip():
                continue
            raw = json.loads(line)
            frames.append((raw["frame"], bytes.fromhex(raw["ram_hex"])))
    return frames


def main() -> int:
    parser = argparse.ArgumentParser(description="Decode SMBDIS sound queues into semantic reference events.")
    parser.add_argument("--queues", type=Path, required=True)
    parser.add_argument("--ram-trace", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    events = []
    ram_trace = load_ram_trace(args.ram_trace)
    first_ram = ram_trace[0][1] if ram_trace else None
    if first_ram is not None:
        area_music = first_ram[0xF4]
        for bit, (event_type, name) in BIT_EVENTS[0xFB].items():
            if area_music & bit and bit != 0x80:
                events.append({
                    "frame": 0,
                    "sequence": -1,
                    "type": event_type,
                    "name": name,
                    "source": "AreaMusicBuffer",
                    "raw_value": area_music,
                })

    writes_by_frame: dict[int, list[dict]] = {}
    with args.queues.open("r", encoding="utf-8") as source:
        for line in source:
            if line.strip():
                write = json.loads(line)
                writes_by_frame.setdefault(write["frame"], []).append(write)

    for frame in sorted(writes_by_frame):
        writes = writes_by_frame[frame]
        # The sound engine first consumes pending queues, then the game loop
        # clears all six queue bytes, and only then do new gameplay producers
        # write their requests.  Treating the consume-phase writes as new
        # events creates false duplicate bump/coin/jump events one frame late.
        zero_addresses = set()
        clear_sequence = -1
        for write in writes:
            if write["value"] == 0 and write["address"] in QUEUE_NAMES:
                zero_addresses.add(write["address"])
                if len(zero_addresses) == len(QUEUE_NAMES):
                    clear_sequence = write["sequence"]

        for write in writes:
            if write["sequence"] <= clear_sequence:
                continue
            address = write["address"]
            value = write["value"]
            if value == 0 or address not in BIT_EVENTS:
                continue
            decoded = False
            for bit, (event_type, name) in BIT_EVENTS[address].items():
                if value & bit:
                    decoded = True
                    event = {
                        "frame": write["frame"],
                        "sequence": write["sequence"],
                        "type": event_type,
                        "name": name,
                        "source": QUEUE_NAMES[address],
                        "address": address,
                        "raw_value": value,
                        "raw_bit": bit,
                    }
                    events.append(event)
                    if address == 0xFC and bit == 0x01:
                        events.append({
                            "frame": write["frame"],
                            "sequence": write["sequence"],
                            "type": "gameplay",
                            "name": "player_death",
                            "source": "DeathMusic queue transition",
                        })
            if not decoded:
                events.append({
                    "frame": write["frame"],
                    "sequence": write["sequence"],
                    "type": "raw_audio_queue",
                    "name": f"{QUEUE_NAMES[address]}_0x{value:02x}",
                    "source": QUEUE_NAMES[address],
                    "address": address,
                    "raw_value": value,
                })

    synthesized = []
    for event in events:
        if event["type"] == "audio" and event["name"] == "bump":
            synthesized.append({
                "frame": event["frame"],
                "sequence": event["sequence"],
                "type": "gameplay",
                "name": "block_hit",
                "source": "bump queue after gameplay queue-clear phase",
            })
        if event["type"] == "audio" and event["name"] == "coin":
            synthesized.append({
                "frame": event["frame"],
                "sequence": event["sequence"],
                "type": "gameplay",
                "name": "coin_award",
                "source": "coin queue after gameplay queue-clear phase",
            })
        if event["type"] == "audio" and event["name"] == "stomp":
            synthesized.append({
                "frame": event["frame"],
                "sequence": event["sequence"],
                "type": "gameplay",
                "name": "enemy_stomp",
                "source": "stomp queue after gameplay queue-clear phase",
            })
    previous_subroutine = None
    for frame, ram in ram_trace:
        subroutine = ram[0x000E]
        if subroutine in (4, 5) and previous_subroutine not in (4, 5):
            synthesized.append({
                "frame": frame,
                "sequence": -1,
                "type": "gameplay",
                "name": "flagpole_touch",
                "source": "GameEngineSubroutine transition into FlagpoleSlide/PlayerEndLevel",
            })
        previous_subroutine = subroutine
    events.extend(synthesized)
    events.sort(key=lambda item: (item["frame"], item["sequence"], item["type"], item["name"]))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        "".join(json.dumps(event, separators=(",", ":")) + "\n" for event in events),
        encoding="utf-8",
    )
    print(f"decoded {len(events)} reference events: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
