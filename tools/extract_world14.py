"""Extract World 1-4 castle streams, graphics, and compact audio cues.

The verified ROM is read offline. No ROM or emulator enters the game runtime.
"""
from __future__ import annotations

import hashlib
import json
import math
import struct
import wave
from pathlib import Path

from extract_smb_assets import (
    METATILE_COUNTS,
    NES_RGB,
    compose_metatile,
    compose_sprite,
    find_once,
    tile_image,
)
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_ROM_SHA256 = "f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de"

# World1Areas entry 4 is area pointer $60 (castle type). EnemyAddrHOffsets
# selects E_CastleArea1 (offset $60) for that pointer, shared with World 6-4.
AREA_SIGNATURE = bytes.fromhex("9b07053206330734")
AREA_TERMINATOR = bytes.fromhex("5dc7fd")
ENEMY_SIGNATURE = bytes.fromhex("76ddbb4cea1d1bcc565d")
CASTLE_PALETTE_SIGNATURE = bytes.fromhex(
    "3f00200f3010000f3010000f3016000f2717000f1627180f1c36170f1630270f00301000"
)
BOWSER_PALETTE_SIGNATURE = bytes.fromhex("3f14040f1a302700")
ENEMY_GFX_SIGNATURE = bytes.fromhex("fcfcaaabacadfcfcaeafb0b1")
METATILE_SIGNATURE = bytes.fromhex("242424242727272724242435")
TERRAIN_MASK_SIGNATURE = bytes.fromhex(
    "00000018011807180f18ff18011f071f0f1f811f01008f1ff11ff918f118ff1f"
)


def locate_area_stream(prg: bytes) -> int:
    cursor = 0
    matches = []
    while True:
        offset = prg.find(AREA_SIGNATURE, cursor)
        if offset < 0:
            break
        end = prg.find(bytes([0xFD]), offset, offset + 128)
        if end >= 0 and prg[end - 2 : end + 1] == AREA_TERMINATOR:
            matches.append(offset)
        cursor = offset + 1
    # CastleArea1, 2 and 3 share the same opening object prefix and tail. The
    # area data table stores CastleArea1 first; its own EnemyAddrHOffsets entry
    # is $60, matching World1Areas[4]. Keep the match explicit so a changed
    # baseline cannot silently select another castle.
    if not matches:
        raise SystemExit("World 1-4 area stream not found")
    return matches[0]


def stream(prg: bytes, start: int, terminator: int = 0xFD) -> bytes:
    if start < 0:
        raise SystemExit("stream not found")
    end = prg.find(bytes([terminator]), start)
    if end < 0 or end - start > 255:
        raise SystemExit("stream terminator missing")
    return prg[start : end + 1]


def write_wav(path: Path, notes: list[tuple[float, float]], gain: float = 0.16) -> None:
    sample_rate = 48_000
    samples: list[int] = []
    for frequency, seconds in notes:
        count = int(sample_rate * seconds)
        if frequency <= 0.0:
            samples.extend([0] * count)
            continue
        release = max(1, min(count, int(sample_rate * 0.018)))
        for index in range(count):
            envelope = min(1.0, index / 24.0, (count - index) / release)
            phase = (index * frequency / sample_rate) % 1.0
            square = 1.0 if phase < 0.25 else -1.0
            samples.append(int(32767 * gain * envelope * square))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        output.writeframes(struct.pack("<" + "h" * len(samples), *samples))


def main() -> None:
    raw = (ROOT / "roms/Super Mario Bros. (World).nes").read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != EXPECTED_ROM_SHA256:
        raise SystemExit("ROM does not match the verified baseline")
    prg, chr_data = raw[16:32784], raw[32784:40976]

    area_at = locate_area_stream(prg)
    enemy_at = find_once(prg, ENEMY_SIGNATURE, "E_CastleArea1")
    area_data = stream(prg, area_at)
    enemy_data = stream(prg, enemy_at, 0xFF)
    if len(area_data) != 97 or len(enemy_data) != 39:
        raise SystemExit(
            f"unexpected 1-4 stream sizes: area={len(area_data)} enemy={len(enemy_data)}"
        )

    masks_at = find_once(prg, TERRAIN_MASK_SIGNATURE, "TerrainRenderBits")
    metatile_at = find_once(prg, METATILE_SIGNATURE, "MetatileGraphics")
    palette_at = find_once(prg, CASTLE_PALETTE_SIGNATURE, "CastlePaletteData")
    bowser_palette_at = find_once(prg, BOWSER_PALETTE_SIGNATURE, "BowserPaletteData")
    enemy_gfx_at = find_once(prg, ENEMY_GFX_SIGNATURE, "EnemyGraphicsTable")

    metadata = {
        "schema": "smb-world14-assets-v1",
        "rom_sha256": digest,
        "offline_only": True,
        "levels": ["1-4"],
        "streams": {
            "AREA": {
                "label": "L_CastleArea1",
                "cpu_address": hex(0x8000 + area_at),
                "length": len(area_data),
                "sha256": hashlib.sha256(area_data).hexdigest(),
            },
            "ENEMY": {
                "label": "E_CastleArea1",
                "cpu_address": hex(0x8000 + enemy_at),
                "length": len(enemy_data),
                "sha256": hashlib.sha256(enemy_data).hexdigest(),
            },
        },
        "area_pointer": "0x60",
        "internal_area": 4,
        "level_number": 3,
        "shared_rom_level": "6-4",
    }

    generated = ROOT / "scripts/generated"
    generated.mkdir(parents=True, exist_ok=True)
    lines = [
        "// Generated by tools/extract_world14.py from the verified ROM.",
        "ROM_WORLD_1_4_AREA <- [" + ",".join(map(str, area_data)) + "];",
        "ROM_WORLD_1_4_ENEMY <- [" + ",".join(map(str, enemy_data)) + "];",
        "ROM_TERRAIN_MASKS <- [" + ",".join(map(str, prg[masks_at : masks_at + 32])) + "];",
        "ROM_CASTLE_PALETTE <- [" + ",".join(map(str, prg[palette_at + 3 : palette_at + 35])) + "];",
        "ROM_BOWSER_PALETTE <- [" + ",".join(map(str, prg[bowser_palette_at + 3 : bowser_palette_at + 7])) + "];",
    ]
    (generated / "world14_data.nut").write_text("\n".join(lines) + "\n", encoding="utf-8")

    out = ROOT / "assets/world14"
    out.mkdir(parents=True, exist_ok=True)
    castle_palettes = [
        list(prg[palette_at + 3 + row * 4 : palette_at + 7 + row * 4])
        for row in range(8)
    ]
    metatile_bytes = prg[metatile_at : metatile_at + sum(METATILE_COUNTS) * 4]
    for group, count in enumerate(METATILE_COUNTS):
        offset = sum(METATILE_COUNTS[:group]) * 4
        for index in range(count):
            code = group * 0x40 + index
            compose_metatile(
                chr_data,
                metatile_bytes[offset + index * 4 : offset + index * 4 + 4],
                castle_palettes[group],
            ).save(out / f"metatile-{code}.png")

    # EnemyGraphicsTable stores two 8px columns per row of a 16x24 sprite.
    enemy_gfx = prg[enemy_gfx_at : enemy_gfx_at + 48 * 6]
    bowser_palette = list(prg[bowser_palette_at + 3 : bowser_palette_at + 7])
    bowser_rows = {
        "front-0": bytes.fromhex("bfbec1c0c2fc"),
        "rear-0": bytes.fromhex("c4c3c6c5c8c7"),
        "front-1": bytes.fromhex("bfbecac9c2fc"),
        "rear-1": bytes.fromhex("c4c3c6c5cccb"),
    }
    for name, tiles in bowser_rows.items():
        if tiles not in enemy_gfx:
            raise SystemExit(f"Bowser graphics row missing: {name}")
    for frame in range(2):
        canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        front = compose_sprite(
            chr_data, bowser_rows[f"front-{frame}"], bowser_palette, 3
        )
        rear = compose_sprite(
            chr_data, bowser_rows[f"rear-{frame}"], bowser_palette, 3
        )
        canvas.alpha_composite(front, (0, 0))
        canvas.alpha_composite(rear, (16, 8))
        canvas.save(out / f"bowser-{frame}.png")

    # Original World 1-4 saves the mushroom retainer/Toad, not the princess.
    # This is the exact six-tile entry at EnemyGraphicsTable $a2. Castle sprite
    # palette 0 is the object's unmodified Enemy_SprAttrib palette.
    retainer_tiles = bytes.fromhex("cdcdcececfcf")
    if retainer_tiles not in enemy_gfx:
        raise SystemExit("mushroom retainer graphics row missing")
    compose_sprite(chr_data, retainer_tiles, castle_palettes[4], 3).save(
        out / "toad.png"
    )

    for frame, tile in enumerate((0x64, 0x65)):
        tile_image(chr_data, tile, bowser_palette, 0, True).save(
            out / f"firebar-{frame}.png"
        )
    flame = Image.new("RGBA", (24, 8), (0, 0, 0, 0))
    for index, tile in enumerate((0x51, 0x52, 0x53)):
        flame.alpha_composite(
            tile_image(chr_data, tile, bowser_palette, 0, True), (index * 8, 0)
        )
    flame.save(out / "bowser-flame.png")

    audio = ROOT / "assets/audio"
    # Small runtime cues, generated locally and kept separate from shared PCM.
    notes = [220.0, 261.63, 293.66, 329.63, 293.66, 261.63]
    write_wav(audio / "castle_theme.wav", [(note, 0.16) for note in notes])
    write_wav(
        audio / "castle_clear.wav",
        [(0.0, 0.10), (523.25, 0.10), (659.25, 0.10), (783.99, 0.18), (1046.5, 0.32)],
    )
    write_wav(audio / "bowser_fire.wav", [(92.5, 0.035), (73.4, 0.045), (61.7, 0.06)])
    write_wav(audio / "bowser_fall.wav", [(185.0, 0.12), (146.8, 0.12), (110.0, 0.18)])

    metadata["generated_textures"] = {
        "metatiles": "assets/world14/metatile-*.png",
        "bowser": ["assets/world14/bowser-0.png", "assets/world14/bowser-1.png"],
        "mushroom_retainer": "assets/world14/toad.png",
        "firebar": ["assets/world14/firebar-0.png", "assets/world14/firebar-1.png"],
        "flame": "assets/world14/bowser-flame.png",
    }
    metadata["audio"] = {
        "castle_theme": "assets/audio/castle_theme.wav",
        "castle_clear": "assets/audio/castle_clear.wav",
        "bowser_fire": "assets/audio/bowser_fire.wav",
        "bowser_fall": "assets/audio/bowser_fall.wav",
    }
    (out / "manifest.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"world14 area={metadata['streams']['AREA']['cpu_address']} "
          f"enemy={metadata['streams']['ENEMY']['cpu_address']}")


if __name__ == "__main__":
    main()
