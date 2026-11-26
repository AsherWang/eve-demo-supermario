"""Extract World 2-2 area graph from verified ROM pointer tables (offline only)."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from extract_smb_assets import find_once, compose_metatile, compose_sprite, METATILE_COUNTS, ENEMY_PALETTES
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = "f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de"


def read_stream(prg: bytes, start: int, enemies: bool) -> bytes:
    """Terminators are commands, not arbitrary operand bytes."""
    cursor = start if enemies else start + 2
    terminator = 0xff if enemies else 0xfd
    while cursor < len(prg):
        if prg[cursor] == terminator:
            return prg[start:cursor + 1]
        size = 3 if enemies and prg[cursor] & 15 == 14 else 2
        if cursor + size > len(prg):
            raise ValueError("truncated area stream")
        cursor += size
    raise ValueError("unterminated area stream")


def enemy_commands(data: bytes) -> list[dict]:
    cursor = page = 0
    records = []
    while cursor < len(data) and data[cursor] != 0xff:
        if cursor + 1 >= len(data):
            raise ValueError("truncated enemy command")
        first, second = data[cursor:cursor + 2]
        row = first & 15
        if second & 128:
            page += 1
        if row == 15 and not second & 128:
            page = second & 63
            cursor += 2
            continue
        record = dict(offset=cursor, column=page * 16 + (first >> 4), row=row)
        if row == 14:
            if cursor + 2 >= len(data):
                raise ValueError("truncated area link")
            third = data[cursor + 2]
            record.update(kind="area_link", destination=second,
                          world=(third >> 5) + 1, entrance_page=third & 31)
            cursor += 3
        else:
            record.update(kind="enemy", enemy_id=second & 63,
                          hard_only=bool(second & 64))
            cursor += 2
        records.append(record)
    return records


def area_commands(data: bytes) -> list[dict]:
    page = 0
    records = []
    for offset in range(2, len(data) - 1, 2):
        first, second = data[offset:offset+2]
        if second & 128:
            page += 1
        row = first & 15
        if row == 13 and not second & 64:
            page = second & 31
            continue
        records.append(dict(offset=offset, column=page*16+(first>>4),
                            row=row, value=second&127))
    return records


def extract(raw: bytes) -> tuple[dict, dict]:
    if hashlib.sha256(raw).hexdigest() != EXPECTED:
        raise ValueError("unverified ROM")
    prg = raw[16:32784]
    enemies = find_once(prg, bytes.fromhex("1f061c00"), "enemy pointer table") + 4
    areas = find_once(prg, bytes.fromhex("0003191c"), "area pointer table") + 4
    worlds = find_once(prg, bytes.fromhex("2529c026602829012762"), "world pointers")
    world2 = list(prg[worlds + 5:worlds + 10])
    if world2 != [0x28, 0x29, 1, 0x27, 0x62]:
        raise ValueError("unexpected World 2 area order")
    streams, manifest = {}, dict(schema="smb-world22-data-v1", rom_sha256=EXPECTED,
        world_area_order=world2, areas={}, runtime_implemented=False)
    # Water enemy links select GroundArea6 page 11 for World 2's exit.
    for name, pointer in [("INTRO", world2[1]), ("WATER", world2[2]), ("EXIT", 0x25)]:
        area_type, number = (pointer >> 5) & 3, pointer & 31
        record = dict(area_pointer=pointer, area_type=area_type, streams={})
        for suffix, table, index, is_enemy in [
            ("AREA", areas, [0, 3, 25, 28][area_type] + number, False),
            ("ENEMIES", enemies, [31, 6, 28, 0][area_type] + number, True)]:
            address = prg[table + index] | prg[table + 34 + index] << 8
            if not 0x8000 <= address < 0x10000:
                raise ValueError("invalid PRG address")
            stream = read_stream(prg, address - 0x8000, is_enemy)
            streams[name + "_" + suffix] = stream
            record["streams"][suffix] = dict(cpu_address=address, length=len(stream),
                sha256=hashlib.sha256(stream).hexdigest())
            if is_enemy:
                record["enemy_commands"] = enemy_commands(stream)
            else:
                record["object_commands"] = area_commands(stream)
                record["header"] = dict(entrance_control=(stream[0]>>3)&7,
                    timer_setting=stream[0]>>6, terrain_control=stream[1]&15,
                    background_scenery=(stream[1]>>4)&3, area_style=stream[1]>>6)
        manifest["areas"][name.lower()] = record
    links = [r for r in manifest["areas"]["water"]["enemy_commands"]
             if r["kind"] == "area_link" and r["world"] == 2]
    if len(links) != 1 or (links[0]["destination"], links[0]["entrance_page"]) != (0x25, 11):
        raise ValueError("unexpected World 2-2 exit link")
    manifest["exit"] = links[0]
    objects = manifest["areas"]["water"]["object_commands"]
    manifest["whirlpools"] = [dict(column=c["column"], left=(c["column"]-1)*16,
        length=((c["value"]&15)+2)*16) for c in objects if c["row"]==12 and c["value"]<16]
    manifest["frenzy_commands"] = [c for c in objects if c["row"]==13 and c["value"] in (0x48,0x49,0x4a)]
    manifest["water_pipes"] = [c for c in objects if c["row"]<12 and c["value"]==9]
    halfway = find_once(prg, bytes.fromhex("5640657066406640"), "HalfwayPageNybbles")
    manifest["checkpoint_page"] = prg[halfway+2] & 15
    manifest["checkpoint_table_cpu_address"] = halfway+0x8000
    return streams, manifest


def extract_assets(raw: bytes, output: Path) -> dict:
    prg, chr_data = raw[16:32784], raw[32784:40976]
    ground = find_once(prg, bytes.fromhex("3f00200f291a0f0f36170f0f30210f0f27170f"), "ground palette")
    water = ground - 36  # adjacent 36-byte palette packets in BackgroundColorData
    if prg[water:water+3] != bytes.fromhex("3f0020") or prg[water+35] != 0:
        raise ValueError("invalid water palette packet")
    palettes = [list(prg[water+3+i*4:water+7+i*4]) for i in range(8)]
    output.mkdir(parents=True, exist_ok=True)
    cursor = find_once(prg, bytes.fromhex("242424242727272724242435"), "metatiles")
    files = []
    def save(image, name):
        path = output / name
        image.save(path)
        files.append(dict(path=name, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    for group, count in enumerate(METATILE_COUNTS):
        for index in range(count):
            save(compose_metatile(chr_data, prg[cursor:cursor+4], palettes[group]),
                 f"metatile-{group*64+index}.png")
            cursor += 4
    graphics = find_once(prg, bytes.fromhex("fcfcaaabacadfcfcaeafb0b1"), "enemy graphics")
    for name, index in [("bloober-0",10), ("bloober-1",11),
                        ("cheep-0",12), ("cheep-1",13)]:
        image = compose_sprite(chr_data, prg[graphics+index*6:graphics+(index+1)*6],
            palettes[4+ENEMY_PALETTES[index]], 3, mirror_right=name.startswith("bloober"))
        save(image, name+".png")
        save(image.transpose(Image.Transpose.FLIP_LEFT_RIGHT), name+"-flipped.png")
    for frame in range(2):
        index=12+frame
        image=compose_sprite(chr_data, prg[graphics+index*6:graphics+(index+1)*6], palettes[6], 3)
        save(image, f"red-cheep-{frame}.png")
        save(image.transpose(Image.Transpose.FLIP_LEFT_RIGHT), f"red-cheep-{frame}-flipped.png")
    player = find_once(prg, bytes(range(16)), "player graphics")
    for size, base in [("big",0),("small",96)]:
        for frame in range(3):
            offset = player+base+(5+frame)*8
            image = compose_sprite(chr_data, prg[offset:offset+8], palettes[4], 4)
            save(image, f"mario-{size}-swim-{frame}-right.png")
            save(image.transpose(Image.Transpose.FLIP_LEFT_RIGHT), f"mario-{size}-swim-{frame}-left.png")
    return dict(palette_cpu_address=water+0x8000, palettes=palettes, files=files)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path, default=ROOT / "roms/Super Mario Bros. (World).nes")
    parser.add_argument("--output-root", type=Path, default=ROOT)
    args = parser.parse_args()
    streams, manifest = extract(args.rom.read_bytes())
    dest = args.output_root / "scripts/generated/world22_data.nut"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text("// Offline verified World 2-2 area streams; no runtime ROM dependency.\n" +
        "\n".join("ROM_WORLD_2_2_" + key + " <- [" + ",".join(map(str, value)) + "];"
                  for key, value in streams.items()) + "\n", encoding="utf-8", newline="\n")
    out = args.output_root / "assets/world22/manifest.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    manifest["assets"] = extract_assets(args.rom.read_bytes(), out.parent)
    out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(dict(streams=len(streams), exit=manifest["exit"])))


if __name__ == "__main__":
    main()
