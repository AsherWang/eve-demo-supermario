"""Capture the ROM's parsed World 2-4 castle columns (offline evidence only)."""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

from world24_capture_lock import world24_capture_lock
from common import sha256_file, tool_path
from run_reference import EXPECTED_ROM_SHA256

ROOT = Path(__file__).resolve().parents[2]


def selection_lua(absolute_frame_counter: bool = False) -> str:
    """Select World 2-4 through the ROM's normal area state variables.

    The selection follows World2Areas entry 4 ($60), not title-screen input.
    This is a test harness override used before the area parser starts; the
    resulting terrain is subsequently rendered by the unmodified ROM parser.
    """
    return """
local selected = false
emu.addEventCallback(function()
  if not selected and emu.read(0x0770, emu.memType.nesInternalRam) == 1
     and emu.read(0x000e, emu.memType.nesInternalRam) == 8 then
    selected = true
    emu.write(0x075f, 1, emu.memType.nesInternalRam) -- World 2
    emu.write(0x075c, 3, emu.memType.nesInternalRam) -- LevelNumber: level 4
    emu.write(0x0760, 4, emu.memType.nesInternalRam) -- AreaNumber: castle entry
    emu.write(0x0750, 0x62, emu.memType.nesInternalRam) -- World2Areas[4]
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
  if emu.read(0x0750, emu.memType.nesInternalRam) ~= 0x62 then return end
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
        default=ROOT / "local-parity/world24-map",
    )
    parser.add_argument("--columns", type=int, default=160)
    args = parser.parse_args()
    if sha256_file(args.rom) != EXPECTED_ROM_SHA256:
        parser.error("unverified ROM")

    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    # Single forward traversal preserves long objects across page boundaries.
    # This is offline geometry extraction, explicitly NOT route evidence.
    lua = capture_lua(output) + """
emu.addEventCallback(function()
  local ram=emu.memType.nesInternalRam
  if emu.read(0x075f,ram)==1 and emu.read(0x0750,ram)==0x62
     and emu.read(0x0770,ram)==1 and emu.read(0x0772,ram)==3
     and emu.read(0x000e,ram)==8 then
    emu.write(0x00ce,0x20,ram)
    emu.write(0x00b5,1,ram)
    emu.write(0x009f,0,ram)
    emu.write(0x0433,0,ram)
    emu.write(0x001d,2,ram)
    emu.write(0x0716,1,ram) -- disable collisions for geometry extraction only
    emu.write(0x0723,0,ram) -- let parser emit complete final room
  end
end,emu.eventType.endFrame)
"""
    script=output/'capture-forward.lua';script.write_text(lua,encoding='utf-8', newline="\n")
    with world24_capture_lock():
        result=subprocess.run([str(tool_path('mesen')),str(args.rom.resolve()),
            '--frames','2000','--home',str(output/'forward-home'),
            '--input','0:start@40-46','--input','0:right,b@80-1999',
            '--lua',str(script),'--lua-allow-io','--timeout','120'],
            capture_output=True,text=True,encoding='utf-8',timeout=150)
    (output/'stdout.log').write_text(result.stdout,encoding='utf-8', newline="\n")
    (output/'stderr.log').write_text(result.stderr,encoding='utf-8', newline="\n")
    if result.returncode:raise RuntimeError(result.stdout+result.stderr)
    columns={row['x']:row['tiles'] for row in map(json.loads,(output/'columns.jsonl').read_text().splitlines())}

    missing = [x for x in range(args.columns) if x not in columns]
    if missing:
        raise RuntimeError(f"ROM parser did not emit columns: {missing[:12]}")

    destination = ROOT / "scripts/generated/world24_map.nut"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(
        "// ROM RenderAreaGraphics output for World 2-4; offline extraction evidence.\n"
        + "ROM_WORLD_2_4_METATILES <- [\n"
        + ",\n".join(
            "[" + ",".join(map(str, columns[x])) + "]"
            for x in range(args.columns)
        )
        + "\n];\n",
        encoding="utf-8", newline="\n",
    )
    print(f"captured {len(columns)} columns; wrote {destination}")


if __name__ == "__main__":
    main()
