"""Extract World 1-4 castle streams, graphics, and compact audio cues.

The verified ROM is read offline. No ROM or emulator enters the game runtime.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import wave
from concurrent.futures import ThreadPoolExecutor
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
from tool_paths import tool_path

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


AUDIO_CLIPS = {
    # Name: (SMBDIS queue address, queued value, emulated frames, semantic,
    #        hurry note-length table adder)
    "castle_theme": (0xFB, 0x08, 10820, "area_music.castle", 0),
    "castle_fast": (0xFB, 0x08, 3600, "area_music.castle_hurry", 8),
    "castle_clear": (0xFC, 0x08, 480, "event_music.end_castle", 0),
    "bowser_fire": (0xFD, 0x02, 90, "noise_sfx.bowser_flame", 0),
    "bowser_fall": (0xFE, 0x80, 90, "square2_sfx.bowser_fall", 0),
}


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def mesen_summary(stdout: str) -> dict:
    summaries = []
    for line in stdout.splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if value.get("event") == "summary":
            summaries.append(value)
    if not summaries or not summaries[-1].get("ok"):
        raise RuntimeError("Mesen did not report a successful run")
    return summaries[-1]


def capture_world14_audio(rom: Path, origin_state: Path, mesen: Path,
                          output: Path, work: Path) -> dict:
    """Capture original SoundEngine output twice and prove identical PCM."""
    work.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    freeze = """local frame = 0
emu.addEventCallback(function()
  frame = frame + 1
  if frame > 700 then
    emu.write(0x0787, 0xff, emu.memType.nesInternalRam)
  end
end, emu.eventType.endFrame)
"""
    silent_script = work / "silence.lua"
    silent_script.write_text(
        "emu.write(0xfc, 0x80, emu.memType.nesInternalRam)\n" + freeze,
        encoding="utf-8",
    )
    silent_state = work / "silent-origin.mss"
    silent_home = work / "home-silence"
    silent_home.mkdir(parents=True, exist_ok=True)
    silent = subprocess.run([
        str(mesen), str(rom), "--home", str(silent_home),
        "--load-state", str(origin_state), "--frames", "120", "--timeout", "120",
        "--lua", str(silent_script), "--lua-allow-io", "--save-state", str(silent_state),
    ], capture_output=True, text=True, encoding="utf-8", timeout=150)
    (work / "silence.log").write_text(silent.stdout + silent.stderr, encoding="utf-8")
    if silent.returncode or not silent_state.is_file():
        raise RuntimeError(f"World 1-4 silent origin capture failed: {work / 'silence.log'}")
    mesen_summary(silent.stdout)

    def capture_once(name: str, reference: str) -> dict:
        queue, value, frames, semantic, adder = AUDIO_CLIPS[name]
        script = work / f"{name}-{reference}.lua"
        source = ""
        if adder:
            source += f"emu.write(0x07c4, {adder}, emu.memType.nesInternalRam)\n"
        source += f"emu.write(0x{queue:02x}, 0x{value:02x}, emu.memType.nesInternalRam)\n"
        script.write_text(source + freeze, encoding="utf-8")
        clip = work / f"{name}-{reference}.wav"
        home = work / f"home-{name}-{reference}"
        home.mkdir(parents=True, exist_ok=True)
        completed = subprocess.run([
            str(mesen), str(rom), "--home", str(home),
            "--load-state", str(silent_state), "--frames", str(frames),
            "--timeout", "300", "--lua", str(script), "--lua-allow-io",
            "--audio", str(clip),
        ], capture_output=True, text=True, encoding="utf-8", timeout=320)
        (work / f"{name}-{reference}.log").write_text(
            completed.stdout + completed.stderr, encoding="utf-8"
        )
        if completed.returncode:
            raise RuntimeError(f"World 1-4 audio capture failed: {work / f'{name}-{reference}.log'}")
        mesen_summary(completed.stdout)
        with wave.open(str(clip), "rb") as source_wav:
            params = source_wav.getparams()
            if (params.framerate, params.sampwidth, params.nchannels) != (48000, 2, 2):
                raise RuntimeError(f"Unexpected Mesen PCM format for {clip}: {params}")
        return {
            "reference": reference,
            "sha256": file_sha256(clip),
            "sample_frames": params.nframes,
            "queue_address": f"0x{queue:02x}",
            "queue_value": f"0x{value:02x}",
            "emulated_frames": frames,
            "semantic": semantic,
            "note_length_table_adder": adder,
            "timer_freeze_after_frame": 700,
            "path": clip,
        }

    jobs = [(name, reference) for name in AUDIO_CLIPS for reference in ("reference-a", "reference-b")]
    with ThreadPoolExecutor(max_workers=4) as pool:
        rows = list(pool.map(lambda job: capture_once(*job), jobs))
    records: dict[str, dict] = {}
    for name, (_, _, frames, semantic, adder) in AUDIO_CLIPS.items():
        pair = [row for row in rows if row["path"].name.startswith(name + "-")]
        if len(pair) != 2 or pair[0]["sha256"] != pair[1]["sha256"]:
            raise RuntimeError(f"Mesen PCM references disagree for {name}")
        destination = output / f"{name}.wav"
        shutil.copyfile(pair[0]["path"], destination)
        records[name] = {
            "asset": destination.relative_to(ROOT).as_posix(),
            "semantic": semantic,
            "queue_address": pair[0]["queue_address"],
            "queue_value": pair[0]["queue_value"],
            "emulated_frames": frames,
            "note_length_table_adder": adder,
            "timer_freeze_after_frame": 700,
            "references": [
                {key: value for key, value in row.items() if key != "path"}
                for row in pair
            ],
            "references_match": True,
            "sha256": pair[0]["sha256"],
            "sample_frames": pair[0]["sample_frames"],
        }
    manifest = {
        "schema": "smb-world14-audio-v2",
        "rom_sha256": file_sha256(rom),
        "mesen_sha256": file_sha256(mesen),
        "origin_state_sha256": file_sha256(origin_state),
        "sample_rate": 48000,
        "channels": 2,
        "sample_width": 2,
        "method": "Offline original SMBDIS SoundEngine and Mesen 2A03; unmodified captured PCM",
        "limitation": "Isolated original clips; runtime song resume and channel stealing remain separate gates",
        "clips": records,
    }
    (ROOT / "assets/world14/audio-manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path,
                        default=ROOT / "roms/Super Mario Bros. (World).nes")
    parser.add_argument("--origin-state", type=Path,
                        help="Mesen state at normal World 1-4 player control; required for audio")
    parser.add_argument("--mesen", type=Path, default=tool_path("mesen"))
    parser.add_argument("--audio-work", type=Path,
                        default=ROOT / "local-parity/world14-audio-capture")
    args = parser.parse_args()
    raw = args.rom.read_bytes()
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

    if args.origin_state is None:
        parser.error("--origin-state is required; capture must use the original SoundEngine, not synthesized notes")
    if not args.origin_state.is_file():
        parser.error(f"origin state does not exist: {args.origin_state}")
    if not args.mesen.is_file():
        parser.error(f"Mesen agent does not exist: {args.mesen}")
    audio_manifest = capture_world14_audio(
        args.rom.resolve(), args.origin_state.resolve(), args.mesen.resolve(),
        ROOT / "assets/audio", args.audio_work.resolve(),
    )

    metadata["generated_textures"] = {
        "metatiles": "assets/world14/metatile-*.png",
        "bowser": ["assets/world14/bowser-0.png", "assets/world14/bowser-1.png"],
        "mushroom_retainer": "assets/world14/toad.png",
        "firebar": ["assets/world14/firebar-0.png", "assets/world14/firebar-1.png"],
        "flame": "assets/world14/bowser-flame.png",
    }
    metadata["audio"] = {
        name: record["asset"] for name, record in audio_manifest["clips"].items()
    }
    metadata["audio_manifest"] = "assets/world14/audio-manifest.json"
    (out / "manifest.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"world14 area={metadata['streams']['AREA']['cpu_address']} "
          f"enemy={metadata['streams']['ENEMY']['cpu_address']}")


if __name__ == "__main__":
    main()
