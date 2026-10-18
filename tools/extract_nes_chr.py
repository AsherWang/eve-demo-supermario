#!/usr/bin/env python3
"""Inspect an iNES ROM and export its CHR-ROM as diagnostic tile sheets."""

from __future__ import annotations

import argparse
import hashlib
import json
import zlib
from pathlib import Path

from PIL import Image


def hashes(data: bytes) -> dict[str, str]:
    return {
        "size": len(data),
        "crc32": f"{zlib.crc32(data) & 0xFFFFFFFF:08X}",
        "md5": hashlib.md5(data).hexdigest().upper(),
        "sha1": hashlib.sha1(data).hexdigest().upper(),
        "sha256": hashlib.sha256(data).hexdigest().upper(),
    }


def decode_tile(tile: bytes) -> list[int]:
    pixels: list[int] = []
    for y in range(8):
        low, high = tile[y], tile[y + 8]
        for x in range(8):
            bit = 7 - x
            pixels.append(((low >> bit) & 1) | (((high >> bit) & 1) << 1))
    return pixels


def render_table(chr_data: bytes, first_tile: int, tile_count: int = 256) -> Image.Image:
    palette = [(15, 15, 18), (94, 99, 112), (180, 186, 197), (255, 255, 255)]
    image = Image.new("RGB", (128, 128))
    for local_index in range(tile_count):
        tile_index = first_tile + local_index
        tile = chr_data[tile_index * 16 : tile_index * 16 + 16]
        if len(tile) < 16:
            break
        ox, oy = (local_index % 16) * 8, (local_index // 16) * 8
        pixels = decode_tile(tile)
        for y in range(8):
            for x in range(8):
                image.putpixel((ox + x, oy + y), palette[pixels[y * 8 + x]])
    return image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rom", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    rom = args.rom.read_bytes()
    if len(rom) < 16 or rom[:4] != b"NES\x1a":
        raise SystemExit("Not a valid iNES image")

    prg_banks, chr_banks = rom[4], rom[5]
    flags6, flags7 = rom[6], rom[7]
    trainer_size = 512 if flags6 & 0x04 else 0
    prg_offset = 16 + trainer_size
    prg_size, chr_size = prg_banks * 16384, chr_banks * 8192
    chr_offset = prg_offset + prg_size
    prg = rom[prg_offset : prg_offset + prg_size]
    chr_data = rom[chr_offset : chr_offset + chr_size]
    if len(prg) != prg_size or len(chr_data) != chr_size:
        raise SystemExit("ROM is truncated")

    mapper = (flags6 >> 4) | (flags7 & 0xF0)
    tiles = [chr_data[i : i + 16] for i in range(0, len(chr_data), 16)]
    manifest = {
        "source": str(args.rom.resolve()),
        "format": "iNES",
        "mapper": mapper,
        "mirroring": "four-screen" if flags6 & 0x08 else "vertical" if flags6 & 0x01 else "horizontal",
        "battery": bool(flags6 & 0x02),
        "trainer": bool(flags6 & 0x04),
        "offsets": {"prg": prg_offset, "chr": chr_offset},
        "hashes": {
            "whole_file": hashes(rom),
            "prg_chr": hashes(prg + chr_data),
            "prg": hashes(prg),
            "chr": hashes(chr_data),
        },
        "resources": {
            "prg_bytes": len(prg),
            "chr_bytes": len(chr_data),
            "chr_tile_count": len(tiles),
            "chr_unique_tile_count": len(set(tiles)),
            "chr_blank_tile_count": sum(tile == bytes(16) for tile in tiles),
        },
        "notes": [
            "Each CHR tile is 8x8 pixels, 2 bits per pixel, and 16 bytes.",
            "Rendered colours are diagnostic grayscale values, not the in-game NES palettes.",
        ],
    }

    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "chr.bin").write_bytes(chr_data)
    (args.output / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    tables = []
    for index, first_tile in enumerate(range(0, len(tiles), 256)):
        table = render_table(chr_data, first_tile, min(256, len(tiles) - first_tile))
        table.save(args.output / f"pattern-table-{index}.png")
        table.resize((512, 512), Image.Resampling.NEAREST).save(
            args.output / f"pattern-table-{index}-preview.png"
        )
        tables.append(table)

    combined = Image.new("RGB", (128 * len(tables), 128))
    for index, table in enumerate(tables):
        combined.paste(table, (index * 128, 0))
    combined.save(args.output / "chr-all.png")
    combined.resize((combined.width * 4, combined.height * 4), Image.Resampling.NEAREST).save(
        args.output / "chr-all-preview.png"
    )
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
