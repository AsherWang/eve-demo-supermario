"""Capture World 1-3's ROM area-parser metatiles as offline evidence."""
from __future__ import annotations

import argparse
import json
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from common import sha256_file, tool_path
from run_reference import EXPECTED_ROM_SHA256, build_origin_lua


ROOT = Path(__file__).resolve().parents[2]
WIDTH = 160
PAGES = range(10)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--rom", type=Path, default=ROOT / "roms/Super Mario Bros. (World).nes"
    )
    parser.add_argument(
        "--output", type=Path, default=ROOT / "local-parity/world13-map"
    )
    args = parser.parse_args()
    if sha256_file(args.rom) != EXPECTED_ROM_SHA256:
        parser.error("unverified ROM")

    prg = args.rom.read_bytes()[16:32784]
    signature = bytes.fromhex("ad260729018505ac40038400ad2107")
    if prg.count(signature) != 1:
        raise RuntimeError("RenderAreaGraphics signature not unique")
    offset = prg.index(signature)

    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    lua = (
        build_origin_lua(3)
        + f'''
local columns = {{}}
local path = {json.dumps(str(out / "columns.jsonl").replace(chr(92), "/"))}
local file = assert(io.open(path, "wb"))
emu.addMemoryCallback(function()
  if emu.read(0x0750, emu.memType.nesInternalRam) ~= 0x26 then return end
  if emu.read(0x075c, emu.memType.nesInternalRam) ~= 2 then return end
  local x = emu.read(0x0725, emu.memType.nesInternalRam) * 16
             + emu.read(0x0726, emu.memType.nesInternalRam)
  if columns[x] then return end
  columns[x] = true
  local values = {{}}
  local blocks = {{}}
  for row = 0, 12 do
    values[#values + 1] = tostring(emu.read(0x06a1 + row, emu.memType.nesInternalRam))
  end
  local block_column = emu.read(0x06a0, emu.memType.nesInternalRam)
  local block_base = (block_column & 0xf0) == 0 and 0x0500 or 0x05d0
  local block_offset = block_column & 0x0f
  for row = 0, 12 do
    blocks[#blocks + 1] = tostring(emu.read(block_base + block_offset + row * 16,
                                             emu.memType.nesInternalRam))
  end
  file:write('{{"x":' .. x .. ',"tiles":[' .. table.concat(values, ",") ..
             '],"blocks":[' .. table.concat(blocks, ",") .. ']}}\\n')
  file:flush()
end, emu.callbackType.exec, {offset + 0x8000}, {offset + 0x8000}, emu.cpuType.nes)
'''
    )

    def capture(page: int) -> dict[int, dict[str, list[int]]]:
        folder = out / f"page-{page}"
        folder.mkdir(parents=True, exist_ok=True)
        columns_path = str(folder / "columns.jsonl").replace(chr(92), "/")
        script = lua.replace(
            str(out / "columns.jsonl").replace(chr(92), "/"), columns_path
        )
        script = script.replace(
            "emu.write(0x075b, 0,", f"emu.write(0x075b, {page},"
        )
        script_path = folder / "capture.lua"
        script_path.write_text(script, encoding="utf-8", newline="\n")
        result = subprocess.run(
            [
                str(tool_path("mesen")),
                str(args.rom.resolve()),
                "--frames",
                "180",
                "--home",
                str(folder / "home"),
                "--input",
                "0:start@40-46",
                "--lua",
                str(script_path),
                "--lua-allow-io",
                "--timeout",
                "120",
            ],
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        (folder / "stdout.log").write_text(
            result.stdout, encoding="utf-8", newline="\n"
        )
        if result.returncode:
            raise RuntimeError(result.stderr + result.stdout)
        return {
            value["x"]: {"tiles": value["tiles"], "blocks": value["blocks"]}
            for value in map(
                json.loads, (folder / "columns.jsonl").read_text().splitlines()
            )
        }

    columns: dict[int, dict[str, list[int]]] = {}
    continuation_conflicts = 0
    with ThreadPoolExecutor(max_workers=4) as pool:
        for result in pool.map(capture, PAGES):
            for x, data in result.items():
                if x in columns and columns[x] != data:
                    # When a tree-ledge object crosses a page boundary, a direct
                    # backload of the later page starts after that object and
                    # cannot reconstruct its two inherited collision columns.
                    # The forward parse of the earlier page owns those columns.
                    later_page = x // 16
                    inherited = x in (later_page * 16, later_page * 16 + 1)
                    if not inherited:
                        raise RuntimeError(
                            f"Backloading produced conflicting column {x}: "
                            f"{columns[x]} != {data}"
                        )
                    continuation_conflicts += 1
                    continue
                columns.setdefault(x, data)
    if not all(x in columns for x in range(WIDTH)):
        raise RuntimeError("ROM parser did not emit every World 1-3 column")

    destination = ROOT / "scripts/generated/world13_map.nut"
    destination.write_text(
        "// Generated by tools/parity/capture_world13_map.py from the verified ROM.\n"
        "ROM_WORLD_1_3_METATILES <- [\n"
        + ",\n".join(
            "[" + ",".join(map(str, columns[x]["tiles"])) + "]"
            for x in range(WIDTH)
        )
        + "\n];\nROM_WORLD_1_3_BLOCKS <- [\n"
        + ",\n".join(
            "[" + ",".join(map(str, columns[x]["blocks"])) + "]"
            for x in range(WIDTH)
        )
        + "\n];\n",
        encoding="utf-8",
        newline="\n",
    )
    manifest = {
        "rom_sha256": sha256_file(args.rom),
        "parser_cpu_address": hex(offset + 0x8000),
        "width": WIDTH,
        "height": 13,
        "columns": len(columns),
        "continuation_conflicts": continuation_conflicts,
        "output": str(destination.relative_to(ROOT)).replace("\\", "/"),
        "output_sha256": sha256_file(destination),
    }
    (out / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(f"captured {len(columns)} columns; wrote {destination}")


if __name__ == "__main__":
    main()
