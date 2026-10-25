from __future__ import annotations

import argparse
import json
from pathlib import Path


# Addresses are SMBDIS symbols, not inferred from screenshots.
ADDR = {
    "game_engine_subroutine": 0x000E,
    "player_state": 0x001D,
    "player_facing_direction": 0x0033,
    "player_moving_direction": 0x0045,
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
    "player_relative_y": 0x03B8,
    "player_position_move_force": 0x0400,
    "player_x_scroll": 0x06FF,
    "player_x_speed_absolute": 0x0700,
    "player_gfx_offset": 0x06D5,
    "player_anim_timer_set": 0x070C,
    "player_anim_control": 0x070D,
    "player_anim_timer": 0x0781,
    "player_acceleration_fraction": 0x0705,
    "player_position_for_scroll": 0x0755,
    "scroll_amount": 0x0775,
    "scroll_thirty_two": 0x073D,
    "area_parser_task": 0x071F,
    "vram_buffer_addr_ctrl": 0x0773,
    "color_rotation_offset": 0x06D4,
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
        sprite_data_offset = ram[0x06E5 + slot]
        oam = []
        for cell in range(6):
            offset = (sprite_data_offset + cell * 4) & 0xFF
            base = 0x0200 + offset
            oam.append({
                "y": ram[base],
                "tile": ram[base + 1],
                "attributes": ram[base + 2],
                "x": ram[base + 3],
            })
        active_enemies.append({
            "slot": slot,
            "flag": flag,
            "id": ram[0x0016 + slot],
            "state_raw": ram[0x001E + slot],
            "x": ram[0x006E + slot] * 256 + ram[0x0087 + slot],
            "y": ram[0x00CF + slot],
            "x_speed_raw": signed8(ram[0x0058 + slot]),
            "relative_x": ram[0x03AE + slot],
            "relative_y": ram[0x03B9 + slot],
            "offscreen_bits": ram[0x03D1 + slot],
            "offscreen_masked": ram[0x03D8 + slot],
            "sprite_data_offset": sprite_data_offset,
            "oam": oam,
        })
    first_goomba = next((enemy for enemy in active_enemies if enemy["id"] == 6), None)
    # Power-ups reserve enemy slot 5, but the flagpole flag ($30) also lives
    # there once streamed.  Identify the object by the SMBDIS constant rather
    # than treating every slot-5 occupant as a power-up ($2e).
    powerup_enemy = next(
        (enemy for enemy in active_enemies
         if enemy["slot"] == 5 and enemy["id"] == 0x2E),
        None,
    )
    powerup_type = ram[0x0039]
    powerup_kinds = {0: "mushroom", 1: "flower", 2: "star", 3: "oneup"}
    return {
        "frame": raw["frame"],
        "world": ram[0x075F] + 1,
        "level": ram[0x075C] + 1,
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
            "relative_y": ram[ADDR["player_relative_y"]],
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
            "facing_direction_raw": ram[ADDR["player_facing_direction"]],
            "moving_direction_raw": ram[ADDR["player_moving_direction"]],
        },
        "player_animation": {
            "timer": ram[ADDR["player_anim_timer"]],
            "timer_set": ram[ADDR["player_anim_timer_set"]],
            "control": ram[ADDR["player_anim_control"]],
            "gfx_offset": ram[ADDR["player_gfx_offset"]],
        },
        "camera_x": ram[ADDR["screen_left_page"]] * 256 + ram[ADDR["screen_left_x"]],
        "scroll_amount": ram[ADDR["scroll_amount"]],
        "color_rotation_offset": ram[ADDR["color_rotation_offset"]],
        "vram_scheduler": {
            "scroll_thirty_two": ram[ADDR["scroll_thirty_two"]],
            "area_parser_task": ram[ADDR["area_parser_task"]],
            "buffer_addr_ctrl": ram[ADDR["vram_buffer_addr_ctrl"]],
        },
        "enemy0": ({"active": False} if first_goomba is None else {
            "active": True,
            **first_goomba,
        }),
        "powerup": ({"active": False} if powerup_enemy is None else {
            "active": True,
            "kind": powerup_kinds.get(powerup_type, f"raw_{powerup_type:02x}"),
            "kind_raw": powerup_type,
            "state_raw": powerup_enemy["state_raw"],
            "x": powerup_enemy["x"],
            "y": powerup_enemy["y"],
            "x_speed_raw": powerup_enemy["x_speed_raw"],
            "visible": powerup_enemy["state_raw"] >= 6,
        }),
        "enemies": active_enemies,
        "misc_raw": {
            "state": list(ram[0x002A:0x0033]),
            "page": list(ram[0x007A:0x0083]),
            "x": list(ram[0x0093:0x009C]),
            "y": list(ram[0x00DB:0x00E4]),
            "floatey_control": list(ram[0x0110:0x0117]),
            "floatey_x": list(ram[0x0117:0x011E]),
            "floatey_y": list(ram[0x011E:0x0125]),
            "floatey_timer": list(ram[0x012C:0x0133]),
        },
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
