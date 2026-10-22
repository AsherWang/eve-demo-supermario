"""Rank extracted sprite assets against pixels in a captured NES frame.

This is a diagnostic tool for parity work: transparent asset pixels are
ignored, and candidate anchors are searched in a small caller-provided box.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


LOGICAL_SIZE = (256, 240)


def normalize(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    if image.size != LOGICAL_SIZE:
        image = image.resize(LOGICAL_SIZE, Image.Resampling.NEAREST)
    return image


def score(frame: Image.Image, sprite: Image.Image, x: int, y: int) -> tuple[int, int]:
    mismatches = 0
    compared = 0
    for sy in range(sprite.height):
        for sx in range(sprite.width):
            red, green, blue, alpha = sprite.getpixel((sx, sy))
            if alpha == 0:
                continue
            px, py = x + sx, y + sy
            if px < 0 or px >= frame.width or py < 0 or py >= frame.height:
                continue
            if frame.getpixel((px, py))[:3] != (red, green, blue):
                mismatches += 1
            compared += 1
    return mismatches, compared


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("frame", type=Path)
    parser.add_argument("assets", type=Path)
    parser.add_argument("--x", type=int, required=True)
    parser.add_argument("--y", type=int, required=True)
    parser.add_argument("--radius", type=int, default=3)
    parser.add_argument("--limit", type=int, default=12)
    args = parser.parse_args()

    frame = normalize(args.frame)
    results: list[tuple[int, int, Path, int, int]] = []
    for path in args.assets.rglob("*.png"):
        sprite = Image.open(path).convert("RGBA")
        if sprite.width > 32 or sprite.height > 32:
            continue
        for y in range(args.y - args.radius, args.y + args.radius + 1):
            for x in range(args.x - args.radius, args.x + args.radius + 1):
                mismatches, compared = score(frame, sprite, x, y)
                if compared == 0:
                    continue
                results.append((mismatches, -compared, path, x, y))

    for mismatches, neg_compared, path, x, y in sorted(results)[: args.limit]:
        print(f"{mismatches:3}/{-neg_compared:3}  ({x:3},{y:3})  {path.as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
