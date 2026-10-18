#!/usr/bin/env python3
"""Extract assembled SMB sprites and metatiles from a user-provided iNES ROM."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image


# A commonly used NTSC 2C02 palette. The ROM stores indexes into these 64 colours.
NES_RGB = [
    (84, 84, 84), (0, 30, 116), (8, 16, 144), (48, 0, 136),
    (68, 0, 100), (92, 0, 48), (84, 4, 0), (60, 24, 0),
    (32, 42, 0), (8, 58, 0), (0, 64, 0), (0, 60, 0),
    (0, 50, 60), (0, 0, 0), (0, 0, 0), (0, 0, 0),
    (152, 150, 152), (8, 76, 196), (48, 50, 236), (92, 30, 228),
    (136, 20, 176), (160, 20, 100), (152, 34, 32), (120, 60, 0),
    (84, 90, 0), (40, 114, 0), (8, 124, 0), (0, 118, 40),
    (0, 102, 120), (0, 0, 0), (0, 0, 0), (0, 0, 0),
    (236, 238, 236), (76, 154, 236), (120, 124, 236), (176, 98, 236),
    (228, 84, 236), (236, 88, 180), (236, 106, 100), (212, 136, 32),
    (160, 170, 0), (116, 196, 0), (76, 208, 32), (56, 204, 108),
    (56, 180, 204), (60, 60, 60), (0, 0, 0), (0, 0, 0),
    (236, 238, 236), (168, 204, 236), (188, 188, 236), (212, 178, 236),
    (236, 174, 236), (236, 174, 212), (236, 180, 176), (228, 196, 144),
    (204, 210, 120), (180, 222, 120), (168, 226, 144), (152, 226, 180),
    (160, 214, 228), (160, 162, 160), (0, 0, 0), (0, 0, 0),
]

BIG_MARIO_NAMES = [
    "walk-1", "walk-2", "walk-3", "skid", "jump", "swim-1",
    "swim-2", "swim-3", "climb-1", "climb-2", "crouch", "fireball",
]
SMALL_MARIO_NAMES = [
    "walk-1", "walk-2", "walk-3", "skid", "jump", "swim-1",
    "swim-2", "swim-3", "climb-1", "climb-2", "dead",
]

ENEMY_NAMES = [
    "buzzy-beetle-1", "buzzy-beetle-2", "green-koopa-1", "green-koopa-2",
    "green-paratroopa-1", "green-paratroopa-2", "spiny-1", "spiny-2",
    "spiny-egg-1", "spiny-egg-2", "bloober-1", "bloober-2",
    "grey-cheep-1", "grey-cheep-2", "goomba", "green-shell-up-1",
    "green-shell-up-2", "green-shell-1", "green-shell-2", "buzzy-shell-1",
    "buzzy-shell-2", "buzzy-shell-up-1", "buzzy-shell-up-2", "goomba-defeated",
    "lakitu-1", "lakitu-2", "princess", "mushroom-retainer",
    "hammer-bro-1", "hammer-bro-2", "hammer-bro-3", "hammer-bro-4",
    "piranha-1", "piranha-2", "podoboo", "bowser-front-1",
    "bowser-rear-1", "bowser-front-2", "bowser-rear-2", "bullet-bill",
    "jumpspring-1", "jumpspring-2", "jumpspring-3",
]

ENEMY_PALETTES = [
    3, 3, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 1, 1, 3, 1, 1, 1, 1,
    3, 3, 3, 3, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 3,
    2, 2, 2,
]

METATILE_COUNTS = [39, 46, 10, 6]
METATILE_NAMES = [
    [
        "blank", "black", "bush-left", "bush-middle", "bush-right",
        "mountain-left", "mountain-left-bottom", "mountain-middle-top",
        "mountain-right", "mountain-right-bottom", "mountain-middle-bottom",
        "bridge-guardrail", "chain", "tall-tree-top", "short-tree-top",
        "tall-tree-bottom", "warp-pipe-top-left", "warp-pipe-top-right",
        "decor-pipe-top-left", "decor-pipe-top-right", "pipe-shaft-left",
        "pipe-shaft-right", "tree-ledge-left", "tree-ledge-middle",
        "tree-ledge-right", "mushroom-left", "mushroom-middle", "mushroom-right",
        "side-pipe-top-end", "side-pipe-top-shaft", "side-pipe-top-joint",
        "side-pipe-bottom-end", "side-pipe-bottom-shaft", "side-pipe-bottom-joint",
        "sea-plant", "hit-block-blank", "flagpole-ball", "flagpole-shaft", "vine-blank",
    ],
    [
        "vertical-rope", "horizontal-rope", "left-pulley", "right-pulley",
        "balance-rope-blank", "castle-top", "castle-window-left", "castle-wall",
        "castle-window-right", "castle-top-brick", "entrance-top", "entrance-bottom",
        "green-ledge-stump", "fence", "tree-trunk", "mushroom-stump-top",
        "mushroom-stump-bottom", "brick-lined", "brick", "brick-lined-unused",
        "cracked-rock", "brick-powerup-lined", "brick-vine-lined", "brick-star-lined",
        "brick-coins-lined", "brick-oneup-lined", "brick-powerup", "brick-vine",
        "brick-star", "brick-coins", "brick-oneup", "hidden-coin", "hidden-oneup",
        "solid-3d", "solid-white", "bridge", "cannon-barrel", "cannon-top",
        "cannon-bottom", "jumpspring-blank", "half-brick-spring", "water-rock",
        "half-brick", "water-pipe-top", "water-pipe-bottom", "flag-ball-residual",
    ],
    [
        "cloud-left", "cloud-middle", "cloud-right", "cloud-bottom-left",
        "cloud-bottom-middle", "cloud-bottom-right", "water-top", "water",
        "cloud-terrain", "bowser-bridge",
    ],
    ["question-coin", "question-powerup", "coin", "underwater-coin", "empty-block", "axe"],
]


def find_once(data: bytes, signature: bytes, label: str) -> int:
    offset = data.find(signature)
    if offset < 0:
        raise SystemExit(f"Could not find {label}; this ROM is not structurally compatible")
    if data.find(signature, offset + 1) >= 0:
        raise SystemExit(f"Found multiple {label} signatures; refusing to guess")
    return offset


def decode_tile(chr_data: bytes, tile_id: int, table: int = 0) -> list[int]:
    offset = table * 4096 + tile_id * 16
    tile = chr_data[offset : offset + 16]
    result = []
    for y in range(8):
        low, high = tile[y], tile[y + 8]
        for x in range(8):
            bit = 7 - x
            result.append(((low >> bit) & 1) | (((high >> bit) & 1) << 1))
    return result


def tile_image(
    chr_data: bytes,
    tile_id: int,
    palette: list[int],
    table: int,
    transparent: bool,
    flip_x: bool = False,
    flip_y: bool = False,
) -> Image.Image:
    image = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    if tile_id == 0xFC and transparent:
        return image
    pixels = decode_tile(chr_data, tile_id, table)
    for y in range(8):
        for x in range(8):
            value = pixels[y * 8 + x]
            if transparent and value == 0:
                colour = (0, 0, 0, 0)
            else:
                colour = (*NES_RGB[palette[value] & 0x3F], 255)
            px = 7 - x if flip_x else x
            py = 7 - y if flip_y else y
            image.putpixel((px, py), colour)
    return image


def compose_sprite(
    chr_data: bytes,
    tiles: bytes,
    palette: list[int],
    rows: int,
    mirror_right: bool = False,
    flip_x_indices: set[int] | None = None,
) -> Image.Image:
    image = Image.new("RGBA", (16, rows * 8), (0, 0, 0, 0))
    flip_x_indices = flip_x_indices or set()
    for index, tile_id in enumerate(tiles):
        column, row = index % 2, index // 2
        tile = tile_image(
            chr_data, tile_id, palette, 0, True,
            flip_x=(mirror_right and column == 1) or index in flip_x_indices,
        )
        image.alpha_composite(tile, (column * 8, row * 8))
    return image


def compose_metatile(chr_data: bytes, tiles: bytes, palette: list[int]) -> Image.Image:
    image = Image.new("RGBA", (16, 16))
    # SMB stores metatile bytes column-major: TL, BL, TR, BR.
    positions = [(0, 0), (0, 8), (8, 0), (8, 8)]
    for tile_id, position in zip(tiles, positions):
        # Background pattern value 0 is the PPU universal backdrop colour. Keep
        # it transparent so the host engine can supply the current sky colour.
        image.alpha_composite(tile_image(chr_data, tile_id, palette, 1, True), position)
    return image


def compose_explosion(chr_data: bytes, tile_id: int, palette: list[int]) -> Image.Image:
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for x, y, flip_x, flip_y in (
        (0, 0, False, False), (0, 8, False, True),
        (8, 0, True, False), (8, 8, True, True),
    ):
        image.alpha_composite(
            tile_image(chr_data, tile_id, palette, 0, True, flip_x, flip_y),
            (x, y),
        )
    return image


def compose_koopa_shell(
    chr_data: bytes, tiles: bytes, palette: list[int], right_side_up: bool
) -> Image.Image:
    """Apply the shell-specific OAM flips from EnemyGfxHandler."""
    image = Image.new("RGBA", (16, 24), (0, 0, 0, 0))
    for index, tile_id in enumerate(tiles):
        column, row = index % 2, index // 2
        image.alpha_composite(
            tile_image(
                chr_data,
                tile_id,
                palette,
                0,
                True,
                flip_x=column == 1 and row > 0,
                flip_y=right_side_up and row > 0,
            ),
            (column * 8, row * 8),
        )
    return image


def save_1x_and_preview(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    image.resize((image.width * 4, image.height * 4), Image.Resampling.NEAREST).save(
        path.with_name(path.stem + "-4x" + path.suffix)
    )


def make_sheet(images: list[Image.Image], columns: int, cell: tuple[int, int]) -> Image.Image:
    rows = math.ceil(len(images) / columns)
    sheet = Image.new("RGBA", (columns * cell[0], rows * cell[1]), (0, 0, 0, 0))
    for index, image in enumerate(images):
        x = (index % columns) * cell[0] + (cell[0] - image.width) // 2
        y = (index // columns) * cell[1] + (cell[1] - image.height) // 2
        sheet.alpha_composite(image, (x, y))
    return sheet


def decode_world_1_1_blocks(area_data: bytes) -> dict[str, list[tuple[int, int]]]:
    """Decode item-bearing blocks from SMB's two-byte area object stream."""
    blocks: dict[str, list[tuple[int, int]]] = {
        "question_powerups": [],
        "question_coins": [],
        "hidden_coins": [],
        "hidden_oneups": [],
        "brick_powerups": [],
        "brick_vines": [],
        "brick_stars": [],
        "brick_coins": [],
        "brick_oneups": [],
    }
    small_object_names = list(blocks)
    page = 0
    cursor = 2  # skip the two-byte area header
    while cursor < len(area_data) and area_data[cursor] != 0xFD:
        first, second = area_data[cursor : cursor + 2]
        cursor += 2
        row = first & 0x0F
        if second & 0x80:
            page += 1
        if row == 0x0D and not second & 0x40:
            page = second & 0x1F
            continue

        column = page * 16 + (first >> 4)
        if row < 12 and second & 0x70 == 0:
            object_id = second & 0x0F
            if object_id < len(small_object_names):
                blocks[small_object_names[object_id]].append((column, row + 2))
        elif row == 0x0C:
            object_id = (second & 0x70) >> 4
            if object_id in (6, 7):
                screen_row = (3 if object_id == 6 else 7) + 2
                for offset in range((second & 0x0F) + 1):
                    blocks["question_coins"].append((column + offset, screen_row))
    return blocks


def write_runtime_data(
    path: Path,
    scenery: bytes,
    metatiles: bytes,
    world_1_1_area_data: bytes,
    world_1_1_enemy_data: bytes,
    underground_bonus_area_data: bytes,
    underground_bonus_enemy_data: bytes,
    world_1_1_blocks: dict[str, list[tuple[int, int]]],
) -> None:
    def rows(values: bytes, width: int) -> str:
        lines = []
        for start in range(0, len(values), width):
            chunk = values[start : start + width]
            lines.append("    " + ", ".join(f"0x{value:02X}" for value in chunk))
        return ",\n".join(lines)

    def squirrel_points(name: str, points: list[tuple[int, int]]) -> str:
        values = ", ".join(f"[{x}, {y}]" for x, y in points)
        return f"{name} <- [{values}];\n"

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "// Generated from the user-provided SMB ROM. Do not hand-edit.\n"
        "ROM_BACK_SCENERY_OFFSETS <- [0x00, 0x30, 0x60];\n"
        "ROM_BACK_SCENERY_DATA <- [\n"
        f"{rows(scenery, 16)}\n"
        "];\n"
        "ROM_BACK_SCENERY_METATILES <- [\n"
        f"{rows(metatiles, 12)}\n"
        "];\n"
        "ROM_WORLD_1_1_BACKGROUND_SCENERY <- 2;\n"
        "ROM_WORLD_1_1_AREA_DATA <- [\n"
        f"{rows(world_1_1_area_data, 16)}\n"
        "];\n"
        "ROM_WORLD_1_1_ENEMY_DATA <- [\n"
        f"{rows(world_1_1_enemy_data, 16)}\n"
        "];\n"
        "ROM_UNDERGROUND_BONUS_AREA_DATA <- [\n"
        f"{rows(underground_bonus_area_data, 16)}\n"
        "];\n"
        "ROM_UNDERGROUND_BONUS_ENEMY_DATA <- [\n"
        f"{rows(underground_bonus_enemy_data, 16)}\n"
        "];\n"
        + squirrel_points(
            "ROM_WORLD_1_1_QUESTION_POWERUPS",
            world_1_1_blocks["question_powerups"],
        )
        + squirrel_points(
            "ROM_WORLD_1_1_QUESTION_COINS",
            world_1_1_blocks["question_coins"],
        )
        + squirrel_points(
            "ROM_WORLD_1_1_HIDDEN_ONEUPS",
            world_1_1_blocks["hidden_oneups"],
        )
        + squirrel_points(
            "ROM_WORLD_1_1_BRICK_COIN_BLOCKS",
            world_1_1_blocks["brick_coins"],
        )
        + squirrel_points(
            "ROM_WORLD_1_1_BRICK_STAR_BLOCKS",
            world_1_1_blocks["brick_stars"],
        ),
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rom", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--runtime-nut", type=Path)
    args = parser.parse_args()

    rom = args.rom.read_bytes()
    if rom[:4] != b"NES\x1a":
        raise SystemExit("Not an iNES ROM")
    trainer = 512 if rom[6] & 0x04 else 0
    prg_size, chr_size = rom[4] * 16384, rom[5] * 8192
    prg_offset = 16 + trainer
    prg = rom[prg_offset : prg_offset + prg_size]
    chr_data = rom[prg_offset + prg_size : prg_offset + prg_size + chr_size]
    if len(chr_data) < 8192:
        raise SystemExit("This extractor requires at least 8 KiB of CHR-ROM")

    palette_offset = find_once(
        prg, bytes.fromhex("3f00200f291a0f0f36170f0f30210f0f27170f"), "ground palette"
    )
    underground_palette_offset = find_once(
        prg,
        bytes.fromhex("3f00200f291a090f3c1c0f0f30211c0f27171c"),
        "underground palette",
    )
    player_offset = find_once(
        prg, bytes.fromhex("000102030405060708090a0b0c0d0e0f"), "player graphics table"
    )
    enemy_offset = find_once(
        prg, bytes.fromhex("fcfcaaabacadfcfcaeafb0b1"), "enemy graphics table"
    )
    metatile_offset = find_once(
        prg, bytes.fromhex("242424242727272724242435"), "metatile graphics table"
    )
    back_scenery_offset = find_once(
        prg,
        bytes.fromhex("93000011121213000051525300000000"),
        "background scenery data",
    )
    back_scenery_metatile_offset = find_once(
        prg,
        bytes.fromhex("808300818400828500020000030000040000"),
        "background scenery metatile table",
    )
    back_scenery_data = prg[back_scenery_offset : back_scenery_offset + 144]
    back_scenery_metatiles = prg[
        back_scenery_metatile_offset : back_scenery_metatile_offset + 36
    ]
    world_1_1_area_offset = find_once(
        prg,
        bytes.fromhex("502107814724570063017701c97168f2"),
        "World 1-1 area data",
    )
    world_1_1_area_end = prg.index(0xFD, world_1_1_area_offset)
    world_1_1_area_data = prg[world_1_1_area_offset : world_1_1_area_end + 1]
    world_1_1_enemy_offset = find_once(
        prg,
        bytes.fromhex("1ec2006b068b8663b70f05030623064b"),
        "World 1-1 enemy data",
    )
    world_1_1_enemy_end = prg.index(0xFF, world_1_1_enemy_offset)
    world_1_1_enemy_data = prg[
        world_1_1_enemy_offset : world_1_1_enemy_end + 1
    ]
    underground_bonus_area_offset = find_once(
        prg,
        bytes.fromhex("48010e01005a3e06454647465344ae01df4a4dc7"),
        "underground bonus area data",
    )
    underground_bonus_area_end = prg.index(0xFD, underground_bonus_area_offset)
    underground_bonus_area_data = prg[
        underground_bonus_area_offset : underground_bonus_area_end + 1
    ]
    underground_bonus_enemy_offset = find_once(
        prg,
        bytes.fromhex("1ea50a2e28272e33c70f031e40072e30e7"),
        "underground bonus enemy data",
    )
    underground_bonus_enemy_end = prg.index(0xFF, underground_bonus_enemy_offset)
    underground_bonus_enemy_data = prg[
        underground_bonus_enemy_offset : underground_bonus_enemy_end + 1
    ]
    world_1_1_blocks = decode_world_1_1_blocks(world_1_1_area_data)
    if args.runtime_nut:
        write_runtime_data(
            args.runtime_nut,
            back_scenery_data,
            back_scenery_metatiles,
            world_1_1_area_data,
            world_1_1_enemy_data,
            underground_bonus_area_data,
            underground_bonus_enemy_data,
            world_1_1_blocks,
        )

    palette_data = list(prg[palette_offset + 3 : palette_offset + 35])
    palettes = [palette_data[i : i + 4] for i in range(0, 32, 4)]
    bg_palettes, sprite_palettes = palettes[:4], palettes[4:]
    underground_palette_data = list(
        prg[underground_palette_offset + 3 : underground_palette_offset + 35]
    )
    underground_palettes = [
        underground_palette_data[i : i + 4] for i in range(0, 32, 4)
    ]
    # GetPlayerColors uses this ROM-resident palette for both fiery Mario and
    # fiery Luigi.  Keep the transparent entry first for PNG composition.
    fiery_player_palette = [0x22, 0x37, 0x27, 0x16]

    output = args.output
    output.mkdir(parents=True, exist_ok=True)

    # SMB status-bar characters are background CHR tiles $00-$2e.  Rendering
    # them as white transparent glyphs preserves the original 8x8 pixel forms
    # while allowing the game backdrop to show through like the PPU nametable.
    hud_palette = [0x0F, 0x30, 0x30, 0x30]
    for tile_id in range(0x2F):
        save_1x_and_preview(
            tile_image(chr_data, tile_id, hud_palette, 1, True),
            output / "hud-font" / f"{tile_id:02X}.png",
        )

    palette_image = Image.new("RGBA", (64, 128), (0, 0, 0, 255))
    for palette_index, palette in enumerate(palettes):
        for colour_index, nes_index in enumerate(palette):
            colour = (*NES_RGB[nes_index & 0x3F], 255)
            for y in range(palette_index * 16, palette_index * 16 + 16):
                for x in range(colour_index * 16, colour_index * 16 + 16):
                    palette_image.putpixel((x, y), colour)
    save_1x_and_preview(palette_image, output / "palettes" / "ground-palettes.png")

    player_data = prg[player_offset : player_offset + 208]
    big_frames = [player_data[i : i + 8] for i in range(0, 96, 8)]
    small_frames = [player_data[i : i + 8] for i in range(96, 184, 8)]
    common_frames = [player_data[i : i + 8] for i in range(184, 208, 8)]
    big_frames.append(common_frames[2])
    small_frames.append(common_frames[0])
    big_names = BIG_MARIO_NAMES + ["stand"]
    small_names = SMALL_MARIO_NAMES + ["stand"]

    mario_manifest = {}
    # SMB's OAM renderer applies extra per-tile flips after laying out the
    # PlayerGraphicsTable. Repeating a tile ID is not enough: the right-hand
    # copy must be mirrored for these poses to form a continuous silhouette.
    player_flip_tiles = {
        ("big", "crouch"): {7},
        ("big", "stand"): {7},
        ("small", "dead"): {5, 7},
        ("small", "stand"): {7},
    }
    for size, names, frames in (
        ("big", big_names, big_frames), ("small", small_names, small_frames)
    ):
        rendered = []
        for name, frame in zip(names, frames):
            right = compose_sprite(
                chr_data,
                frame,
                sprite_palettes[0],
                4,
                flip_x_indices=player_flip_tiles.get((size, name)),
            )
            left = right.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            save_1x_and_preview(right, output / "sprites" / f"mario-{size}" / f"{name}-right.png")
            save_1x_and_preview(left, output / "sprites" / f"mario-{size}" / f"{name}-left.png")
            # Star Mario selects sprite palettes 0-3 through the OAM attribute
            # bits.  Emit the three alternate palettes so the host renderer can
            # reproduce that hardware palette cycle without tinting the PNGs.
            for palette_id in range(1, 4):
                palette_right = compose_sprite(
                    chr_data,
                    frame,
                    sprite_palettes[palette_id],
                    4,
                    flip_x_indices=player_flip_tiles.get((size, name)),
                )
                palette_dir = output / "sprites" / f"mario-{size}-palette-{palette_id}"
                save_1x_and_preview(
                    palette_right, palette_dir / f"{name}-right.png"
                )
                save_1x_and_preview(
                    palette_right.transpose(Image.Transpose.FLIP_LEFT_RIGHT),
                    palette_dir / f"{name}-left.png",
                )
            if size == "big":
                fire_right = compose_sprite(
                    chr_data,
                    frame,
                    fiery_player_palette,
                    4,
                    flip_x_indices=player_flip_tiles.get((size, name)),
                )
                save_1x_and_preview(
                    fire_right,
                    output / "sprites" / "mario-fire" / f"{name}-right.png",
                )
                save_1x_and_preview(
                    fire_right.transpose(Image.Transpose.FLIP_LEFT_RIGHT),
                    output / "sprites" / "mario-fire" / f"{name}-left.png",
                )
            rendered.append(right)
            mario_manifest[name] = [f"0x{value:02X}" for value in frame]
        save_1x_and_preview(
            make_sheet(rendered, len(rendered), (16, 32)),
            output / "sprites" / f"mario-{size}-sheet.png",
        )

    transition = compose_sprite(
        chr_data, common_frames[1], sprite_palettes[0], 4, flip_x_indices={7}
    )
    save_1x_and_preview(transition, output / "sprites" / "mario-transition.png")

    powerup_tiles = bytes.fromhex("76777879d6d6d9d98d8de4e476777879")
    powerup_names = ["mushroom", "fire-flower", "star", "one-up"]
    powerup_palette_ids = [2, 1, 2, 1]
    powerup_images = []
    for index, name in enumerate(powerup_names):
        image = compose_sprite(
            chr_data,
            powerup_tiles[index * 4 : index * 4 + 4],
            sprite_palettes[powerup_palette_ids[index]],
            2,
            mirror_right=name in {"fire-flower", "star"},
        )
        save_1x_and_preview(image, output / "sprites" / "powerups" / f"{name}.png")
        powerup_images.append(image)
    save_1x_and_preview(
        make_sheet(powerup_images, 4, (16, 16)), output / "sprites" / "powerups-sheet.png"
    )

    # DrawFireball alternates CHR tiles $64/$65 with sprite palette 2.
    for tile_id in (0x64, 0x65):
        fireball = tile_image(chr_data, tile_id, sprite_palettes[2], 0, True)
        save_1x_and_preview(
            fireball,
            output / "sprites" / "effects" / f"fireball-{tile_id - 0x63}.png",
        )
    for index, tile_id in enumerate((0x68, 0x67, 0x66), start=1):
        explosion = compose_explosion(chr_data, tile_id, sprite_palettes[2])
        save_1x_and_preview(
            explosion,
            output / "sprites" / "effects" / f"fireball-explosion-{index}.png",
        )

    # JCoinGfxHandler stacks the same 8x8 tile twice and vertically flips the
    # lower copy.  FrameCounter/2 selects tiles $60-$63.
    for frame, tile_id in enumerate((0x60, 0x61, 0x62, 0x63)):
        jump_coin = Image.new("RGBA", (8, 16), (0, 0, 0, 0))
        jump_coin.alpha_composite(
            tile_image(chr_data, tile_id, sprite_palettes[2], 0, True), (0, 0)
        )
        jump_coin.alpha_composite(
            tile_image(
                chr_data, tile_id, sprite_palettes[2], 0, True, flip_y=True
            ),
            (0, 8),
        )
        save_1x_and_preview(
            jump_coin,
            output / "sprites" / "effects" / f"jump-coin-{frame}.png",
        )

    flag = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    flag.alpha_composite(tile_image(chr_data, 0x7E, sprite_palettes[1], 0, True), (0, 0))
    flag.alpha_composite(tile_image(chr_data, 0x7F, sprite_palettes[1], 0, True), (8, 0))
    flag.alpha_composite(tile_image(chr_data, 0x7E, sprite_palettes[1], 0, True), (8, 8))
    save_1x_and_preview(flag, output / "sprites" / "effects" / "flagpole-flag.png")

    castle_flag = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for tile_id, position in zip((0x54, 0x56, 0x55, 0x57),
                                 ((0, 0), (0, 8), (8, 0), (8, 8))):
        castle_flag.alpha_composite(
            tile_image(chr_data, tile_id, sprite_palettes[2], 0, True), position
        )
    save_1x_and_preview(
        castle_flag, output / "sprites" / "effects" / "castle-flag.png"
    )

    # DrawBrickChunks uses sprite tile $84 with sprite palette 3 in ground areas.
    brick_fragment = tile_image(chr_data, 0x84, sprite_palettes[3], 0, True)
    save_1x_and_preview(
        brick_fragment, output / "sprites" / "effects" / "brick-fragment.png"
    )

    enemy_data = prg[enemy_offset : enemy_offset + len(ENEMY_NAMES) * 6]
    enemy_images = []
    for index, name in enumerate(ENEMY_NAMES):
        frame = enemy_data[index * 6 : index * 6 + 6]
        if name.startswith("green-shell"):
            image = compose_koopa_shell(
                chr_data,
                frame,
                sprite_palettes[ENEMY_PALETTES[index]],
                right_side_up=not name.startswith("green-shell-up"),
            )
        else:
            image = compose_sprite(
                chr_data, frame, sprite_palettes[ENEMY_PALETTES[index]], 3,
                mirror_right=name.startswith(("bloober", "piranha", "podoboo", "jumpspring")),
            )
        save_1x_and_preview(image, output / "sprites" / "enemies" / f"{name}.png")
        if name.startswith("green-koopa-"):
            # The ROM frame faces right. Emit explicit directional variants so
            # the host renderer can select orientation from enemy velocity.
            save_1x_and_preview(
                image,
                output / "sprites" / "enemies" / f"{name}-right.png",
            )
            save_1x_and_preview(
                image.transpose(Image.Transpose.FLIP_LEFT_RIGHT),
                output / "sprites" / "enemies" / f"{name}-left.png",
            )
        enemy_images.append(image)
    save_1x_and_preview(
        make_sheet(enemy_images, 11, (16, 24)), output / "sprites" / "enemies-sheet.png"
    )

    metatile_data = prg[metatile_offset : metatile_offset + sum(METATILE_COUNTS) * 4]
    cursor = 0
    metatile_manifest = {}
    all_metatile_images = []
    for palette_id, (count, names) in enumerate(zip(METATILE_COUNTS, METATILE_NAMES)):
        group_images = []
        group_manifest = {}
        for index in range(count):
            tiles = metatile_data[cursor : cursor + 4]
            cursor += 4
            image = compose_metatile(chr_data, tiles, bg_palettes[palette_id])
            filename = f"{index:02X}-{names[index]}.png"
            save_1x_and_preview(image, output / "metatiles" / f"palette-{palette_id}" / filename)
            group_images.append(image)
            all_metatile_images.append(image)
            group_manifest[f"0x{index:02X}"] = {
                "name": names[index],
                "tiles": [f"0x{value:02X}" for value in tiles],
            }
        metatile_manifest[f"palette-{palette_id}"] = group_manifest
        save_1x_and_preview(
            make_sheet(group_images, 16, (16, 16)),
            output / "metatiles" / f"palette-{palette_id}-sheet.png",
        )
    save_1x_and_preview(
        make_sheet(all_metatile_images, 16, (16, 16)), output / "metatiles" / "all-sheet.png"
    )

    # AreaType=2 uses UndergroundPaletteData.  Export the exact variants used
    # by World 1-1's bonus room instead of recolouring ground-area PNGs later.
    palette_starts = [0, METATILE_COUNTS[0] * 4,
                      sum(METATILE_COUNTS[:2]) * 4,
                      sum(METATILE_COUNTS[:3]) * 4]
    underground_brick_tiles = metatile_data[
        palette_starts[1] + 0x12 * 4 : palette_starts[1] + 0x13 * 4
    ]
    save_1x_and_preview(
        compose_metatile(chr_data, underground_brick_tiles, underground_palettes[1]),
        output / "metatiles" / "underground" / "brick.png",
    )
    for index in range(0x1C, 0x22):
        tiles = metatile_data[
            palette_starts[0] + index * 4 : palette_starts[0] + (index + 1) * 4
        ]
        save_1x_and_preview(
            compose_metatile(chr_data, tiles, underground_palettes[0]),
            output / "metatiles" / "underground" / f"side-pipe-{index:02X}.png",
        )

    color_rotation = [0x27, 0x27, 0x27, 0x17, 0x07, 0x17]
    question_tiles = metatile_data[palette_starts[3] : palette_starts[3] + 4]
    coin_tiles = metatile_data[
        palette_starts[3] + 2 * 4 : palette_starts[3] + 3 * 4
    ]
    for frame, color in enumerate(color_rotation):
        ground_cycle = list(bg_palettes[3])
        ground_cycle[1] = color
        underground_cycle = list(underground_palettes[3])
        underground_cycle[1] = color
        save_1x_and_preview(
            compose_metatile(chr_data, question_tiles, ground_cycle),
            output / "metatiles" / "animated" / f"question-{frame}.png",
        )
        save_1x_and_preview(
            compose_metatile(chr_data, coin_tiles, underground_cycle),
            output / "metatiles" / "animated" / f"underground-coin-{frame}.png",
        )

    manifest = {
        "source_rom": str(args.rom.resolve()),
        "native_scale": "1 PNG pixel = 1 NES pixel",
        "prg_offsets": {
            "ground_palette": palette_offset,
            "underground_palette": underground_palette_offset,
            "metatile_graphics": metatile_offset,
            "enemy_graphics": enemy_offset,
            "player_graphics": player_offset,
            "background_scenery": back_scenery_offset,
            "background_scenery_metatiles": back_scenery_metatile_offset,
            "world_1_1_area_data": world_1_1_area_offset,
            "world_1_1_enemy_data": world_1_1_enemy_offset,
        },
        "ground_palettes": {
            f"{'background' if i < 4 else 'sprite'}-{i if i < 4 else i - 4}": [
                f"0x{value:02X}" for value in palette
            ]
            for i, palette in enumerate(palettes)
        },
        "mario_frame_tiles": mario_manifest,
        "enemy_sheet_order": ENEMY_NAMES,
        "powerup_sheet_order": powerup_names,
        "world_1_1_blocks": world_1_1_blocks,
        "metatiles": metatile_manifest,
    }
    (output / "assets-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps({
        "output": str(output.resolve()),
        "mario_frames": len(big_frames) + len(small_frames) + 1,
        "enemy_frames": len(enemy_images),
        "powerups": len(powerup_images),
        "metatiles": len(all_metatile_images),
        "palettes": len(palettes),
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
