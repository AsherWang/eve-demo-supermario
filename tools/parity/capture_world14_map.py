"""Capture the ROM's parsed World 1-4 castle columns (offline evidence only)."""
from __future__ import annotations

import argparse
import json
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from common import sha256_file, tool_path
from run_reference import EXPECTED_ROM_SHA256

ROOT = Path(__file__).resolve().parents[2]


def selection_lua(absolute_frame_counter: bool = False) -> str:
    """Select World 1-4 through the ROM's normal area state variables.

    The selection follows World1Areas entry 4 ($60), not title-screen input.
    This is a test harness override used before the area parser starts; the
    resulting terrain is subsequently rendered by the unmodified ROM parser.
    """
    return """
local selected = false
emu.addEventCallback(function()
  if not selected and emu.read(0x0770, emu.memType.nesInternalRam) == 1
     and emu.read(0x000e, emu.memType.nesInternalRam) == 8 then
    selected = true
    emu.write(0x075c, 3, emu.memType.nesInternalRam) -- LevelNumber: level 4
    emu.write(0x0760, 4, emu.memType.nesInternalRam) -- AreaNumber: castle entry
    emu.write(0x0750, 0x60, emu.memType.nesInternalRam) -- World1Areas[4]
    emu.write(0x0752, 0, emu.memType.nesInternalRam)
    emu.write(0x075b, 0, emu.memType.nesInternalRam)
    emu.write(0x0757, 1, emu.memType.nesInternalRam)
    emu.write(0x0769, 1, emu.memType.nesInternalRam)
    emu.write(0x0772, 0, emu.memType.nesInternalRam)
  end
end, emu.eventType.endFrame)
"""


def capture_lua(output: Path) -> str:
    columns_path = str((output / "columns.jsonl").resolve()).replace("\\", "/")
    return selection_lua() + f"""
local columns = {{}}
local file = assert(io.open({json.dumps(columns_path)}, "wb"))
-- RenderAreaGraphics is entered once for every 8px half-column. Capture the
-- completed 13-row MetatileBuffer returned by the ROM's own area parser.
emu.addMemoryCallback(function()
  if emu.read(0x0750, emu.memType.nesInternalRam) ~= 0x60 then return end
  local x = emu.read(0x0725, emu.memType.nesInternalRam) * 16
            + emu.read(0x0726, emu.memType.nesInternalRam)
  if columns[x] then return end
  columns[x] = true
  local values = {{}}
  for row = 0, 12 do
    values[#values + 1] = tostring(emu.read(0x06a1 + row, emu.memType.nesInternalRam))
  end
  file:write('{{"x":' .. x .. ',"tiles":[' .. table.concat(values, ',') .. ']}}\\n')
  file:flush()
end, emu.callbackType.exec, 0x88ae, 0x88ae, emu.cpuType.nes)
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--rom",
        type=Path,
        default=ROOT / "roms/Super Mario Bros. (World).nes",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "local-parity/world14-map",
    )
    parser.add_argument("--columns", type=int, default=160)
    args = parser.parse_args()
    if sha256_file(args.rom) != EXPECTED_ROM_SHA256:
        parser.error("unverified ROM")

    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    total_pages = (args.columns + 15) // 16

    def capture(page: int) -> dict[int, list[int]]:
        folder = output / f"page-{page:02d}"
        folder.mkdir(parents=True, exist_ok=True)
        lua = capture_lua(folder)
        # $075B is HalfwayPage; overriding it backloads the parser from that
        # page in the same manner as the existing 1-2 map capture.
        lua = lua.replace(
            "emu.write(0x075b, 0,",
            f"emu.write(0x075b, {page},",
        )
        script = folder / "capture.lua"
        script.write_text(lua, encoding="utf-8", newline="\n")
        result = subprocess.run(
            [
                str(tool_path("mesen")),
                str(args.rom.resolve()),
                "--frames",
                "480",
                "--home",
                str(folder / "home"),
                "--input",
                "0:start@40-46",
                "--input",
                "0:right@48-467",
                "--lua",
                str(script),
                "--lua-allow-io",
                "--timeout",
                "120",
            ],
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        (folder / "stdout.log").write_text(result.stdout, encoding="utf-8")
        (folder / "stderr.log").write_text(result.stderr, encoding="utf-8")
        if result.returncode:
            raise RuntimeError(result.stderr + result.stdout)
        return {
            row["x"]: row["tiles"]
            for row in map(json.loads, (folder / "columns.jsonl").read_text().splitlines())
        }

    columns: dict[int, list[int]] = {}
    with ThreadPoolExecutor(max_workers=4) as pool:
        for page_columns in pool.map(capture, range(total_pages)):
            for x, tiles in page_columns.items():
                if x in columns and columns[x] != tiles:
                    raise RuntimeError(f"backloading produced conflicting column {x}")
                columns.setdefault(x, tiles)

    missing = [x for x in range(args.columns) if x not in columns]
    if missing:
        raise RuntimeError(f"ROM parser did not emit columns: {missing[:12]}")

    destination = ROOT / "scripts/generated/world14_map.nut"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(
        "// ROM RenderAreaGraphics output for World 1-4; offline extraction evidence.\n"
        + "ROM_WORLD_1_4_METATILES <- [\n"
        + ",\n".join(
            "[" + ",".join(map(str, columns[x])) + "]"
            for x in range(args.columns)
        )
        + "\n];\n",
        encoding="utf-8",
    )
    print(f"captured {len(columns)} columns; wrote {destination}")


if __name__ == "__main__":
    main()
