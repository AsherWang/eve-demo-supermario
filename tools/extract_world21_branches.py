"""Extract World 2-1 bonus streams and world-specific returns offline."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from extract_world21 import EXPECTED
from extract_smb_assets import find_once

ROOT = Path(__file__).resolve().parents[1]


def stream(prg: bytes, pointer: int, enemies: bool) -> tuple[int, bytes]:
    signature = bytes.fromhex("1f061c00" if enemies else "0003191c")
    table = find_once(prg, signature, "area pointer table")
    index = prg[table + ((pointer >> 5) & 3)] + (pointer & 31)
    if index >= 34:
        raise ValueError("area pointer outside verified table")
    address = prg[table + 4 + index] | (prg[table + 38 + index] << 8)
    start = address - 0x8000
    if not 0 <= start < len(prg):
        raise ValueError("area pointer outside PRG")
    cursor = start if enemies else start + 2
    end = 0xff if enemies else 0xfd
    while cursor < len(prg) and prg[cursor] != end:
        cursor += 3 if enemies and (prg[cursor] & 15) == 14 else 2
    if cursor >= len(prg):
        raise ValueError("unterminated area stream")
    return address, prg[start:cursor + 1]


def links(data: bytes, world: int) -> list[dict]:
    result, page, cursor = [], 0, 0
    while cursor < len(data) and data[cursor] != 0xff:
        if cursor + 1 >= len(data):
            raise ValueError("truncated enemy stream")
        first, second = data[cursor:cursor + 2]
        page += bool(second & 0x80)
        row = first & 15
        if row == 15 and not second & 0x80:
            page = second & 63
        elif row == 14:
            if cursor + 2 >= len(data):
                raise ValueError("truncated area link")
            third = data[cursor + 2]
            if third >> 5 == world - 1:
                result.append(dict(offset=cursor, column=page * 16 + (first >> 4),
                                   destination=second, entrance_page=third & 31))
            cursor += 3
            continue
        cursor += 2
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path, default=ROOT / "roms/Super Mario Bros. (World).nes")
    args = parser.parse_args()
    raw = args.rom.read_bytes()
    if hashlib.sha256(raw).hexdigest() != EXPECTED:
        parser.error("unverified ROM")
    prg = raw[16:32784]
    if stream(prg, 0x28, True)[0] != 0x9f51 or stream(prg, 0x28, False)[0] != 0xa7cd:
        raise ValueError("pointer tables disagree with verified main area")
    source = ["// Generated offline by tools/extract_world21_branches.py."]
    records = []
    for name, pointer, return_page in [("SKY", 0x2b, 10), ("UNDERGROUND", 0x42, 7)]:
        record = dict(name=name.lower(), area_pointer=pointer, streams={})
        for label, enemy in [("AREA", False), ("ENEMIES", True)]:
            address, data = stream(prg, pointer, enemy)
            record["streams"][label.lower()] = dict(cpu_address=hex(address), length=len(data),
                                                     sha256=hashlib.sha256(data).hexdigest())
            source.append("ROM_WORLD_2_1_" + name + "_" + label + " <- [" +
                          ",".join(map(str, data)) + "];")
            if enemy:
                returns = links(data, 2)
                if len(returns) != 1 or returns[0]["destination"] != 0x28 or returns[0]["entrance_page"] != return_page:
                    raise ValueError("unexpected World 2-1 bonus return")
                record["world2_returns"] = returns
        records.append(record)
    target = ROOT / "scripts/generated/world21_branches.nut"
    target.write_text("\n".join(source) + "\n", encoding="utf-8", newline="\n")
    manifest = dict(schema="smb-world21-branches-v1", rom_sha256=EXPECTED,
                    branches=records, runtime_connected=False,
                    output=str(target.relative_to(ROOT)).replace("\\", "/"),
                    output_sha256=hashlib.sha256(target.read_bytes()).hexdigest())
    (ROOT / "assets/world21/branches-manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(manifest))


if __name__ == "__main__":
    main()
