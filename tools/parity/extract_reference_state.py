from __future__ import annotations

import argparse
import json
from pathlib import Path


# Addresses are SMBDIS symbols, not inferred from screenshots.
ADDR = {
    "game_engine_subroutine": 0x000E,
    "player_state": 0x001D,
    "player_x_speed": 0x0057,
    "player_page": 0x006D,
    "player_x": 0x0086,
    "player_y_speed": 0x009F,
    "player_y_move_dummy": 0x0416,
    "player_y_move_force": 0x0433,
    "player_y_high": 0x00B5,
    "player_y": 0x00CE,
    "screen_left_page": 0x071A,
    "screen_left_x": 0x071C,
    "player_relative_x": 0x03AD,
    "player_position_move_force": 0x0400,
    "player_x_scroll": 0x06FF,
    "player_x_speed_absolute": 0x0700,
    "player_acceleration_fraction": 0x0705,
    "player_position_for_scroll": 0x0755,
    "scroll_amount": 0x0775,
    "player_size": 0x0754,
    "player_status": 0x0756,
    "oper_mode": 0x0770,
    "oper_mode_task": 0x0772,
    "number_of_lives": 0x075A,
    "coin_tally": 0x075E,
    "player_score_display": 0x07DD,
    "game_timer_display": 0x07F8,
}


def signed8(value: int) -> int:
    return value - 256 if value >= 128 else value


def decimal_digits(ram: bytes, address: int, length: int) -> int:
    value = 0
    for digit in ram[address:address + length]:
        if digit > 9:
            raise ValueError(f"invalid decimal digit {digit} at 0x{address:04x}")
        value = value * 10 + digit
    return value


def decode_line(line: str) -> dict:
    raw = json.loads(line)
    ram_hex = raw["ram_hex"]
    if len(ram_hex) != 4096:
        raise ValueError(f"frame {raw.get('frame')} RAM snapshot is not 2048 bytes")
    ram = bytes.fromhex(ram_hex)
    player_status = ram[ADDR["player_status"]]
    active_enemies = []
    for slot in range(6):
        flag = ram[0x000F + slot]
        if flag == 0:
            continue
        active_enemies.append({
            "slot": slot,
            "flag": flag,
            "id": ram[0x0016 + slot],
            "state_raw": ram[0x001E + slot],
            "x": ram[0x006E + slot] * 256 + ram[0x0087 + slot],
            "y": ram[0x00CF + slot],
            "x_speed_raw": signed8(ram[0x0058 + slot]),
        })
    first_goomba = next((enemy for enemy in active_enemies if enemy["id"] == 6), None)
    return {
        "frame": raw["frame"],
        "frame_counter": ram[0x0009],
        "player": {
            "x": ram[ADDR["player_page"]] * 256 + ram[ADDR["player_x"]],
            "y": ram[ADDR["player_y"]],
            "y_low": ram[ADDR["player_y"]],
            "y_high": ram[ADDR["player_y_high"]],
            "x_speed_raw": signed8(ram[ADDR["player_x_speed"]]),
            "x_speed_absolute": ram[ADDR["player_x_speed_absolute"]],
            "x_acceleration_fraction": ram[ADDR["player_acceleration_fraction"]],
            "x_position_fraction": ram[ADDR["player_position_move_force"]],
            "x_scroll_raw": signed8(ram[ADDR["player_x_scroll"]]),
            "relative_x": ram[ADDR["player_relative_x"]],
            "position_for_scroll": ram[ADDR["player_position_for_scroll"]],
            "y_speed_raw": signed8(ram[ADDR["player_y_speed"]]),
            "y_move_force": ram[ADDR["player_y_move_force"]],
            "y_move_dummy": ram[ADDR["player_y_move_dummy"]],
            "state_raw": ram[ADDR["player_state"]],
            "size_raw": ram[ADDR["player_size"]],
            "status_raw": player_status,
            "big": player_status >= 1,
            "fire": player_status >= 2,
            "grounded": ram[ADDR["player_state"]] == 0,
        },
        "camera_x": ram[ADDR["screen_left_page"]] * 256 + ram[ADDR["screen_left_x"]],
        "scroll_amount": ram[ADDR["scroll_amount"]],
        "enemy0": ({"active": False} if first_goomba is None else {
            "active": True,
            **first_goomba,
        }),
        "enemies": active_enemies,
        # SMB stores lives minus one; expose the user-visible count.
        "lives": ram[ADDR["number_of_lives"]] + 1,
        # ScoreAndCoinDisplay stores score in units of ten points.
        "score": decimal_digits(ram, ADDR["player_score_display"], 6) * 10,
        "coins": ram[ADDR["coin_tally"]],
        "time": decimal_digits(ram, ADDR["game_timer_display"], 3),
        "rom_state": {
            "oper_mode": ram[ADDR["oper_mode"]],
            "oper_mode_task": ram[ADDR["oper_mode_task"]],
            "game_engine_subroutine": ram[ADDR["game_engine_subroutine"]],
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Decode verified SMBDIS fields from a Mesen RAM trace.")
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    rows = []
    with args.input.open("r", encoding="utf-8") as source:
        for line in source:
            if line.strip():
                rows.append(decode_line(line))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        "".join(json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n" for row in rows),
        encoding="utf-8",
    )
    manifest = {
        "schema": "smb-reference-state-map-v1",
        "source": "SMBDIS.ASM symbols",
        "addresses": {name: f"0x{address:04x}" for name, address in ADDR.items()},
        "frames": len(rows),
    }
    args.output.with_suffix(".manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(f"decoded {len(rows)} reference states: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
