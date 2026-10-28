"""Capture World 2-1's ROM area-parser metatiles as offline evidence."""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

from common import sha256_file, tool_path
from run_reference import EXPECTED_ROM_SHA256
from world21_reference import build_world21_origin_lua


ROOT = Path(__file__).resolve().parents[2]
WIDTH = 212


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--rom", type=Path, default=ROOT / "roms/Super Mario Bros. (World).nes"
    )
    parser.add_argument(
        "--output", type=Path, default=ROOT / "local-parity/world21-map"
    )
    args = parser.parse_args()
    if sha256_file(args.rom) != EXPECTED_ROM_SHA256:
        parser.error("unverified ROM")

    prg = args.rom.read_bytes()[16:32784]
    area_start = prg.index(bytes.fromhex("52310f206e40f72007841720")) + 0x8000 + 2
    signature = bytes.fromhex("ad260729018505ac40038400ad2107")
    if prg.count(signature) != 1:
        raise RuntimeError("RenderAreaGraphics signature not unique")
    offset = prg.index(signature)

    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    lua = (
        build_world21_origin_lua()
        + f'''
local columns = {{}}
local path = {json.dumps(str(out / "columns.jsonl").replace(chr(92), "/"))}
local file = assert(io.open(path, "wb"))
emu.addMemoryCallback(function()
  -- AreaPointer changes to a destination when a bonus link is parsed. Match
  -- the active area-data base instead of confusing that link with an exit.
  if emu.read(0x00e7, emu.memType.nesInternalRam) ~= {area_start & 255}
     or emu.read(0x00e8, emu.memType.nesInternalRam) ~= {area_start >> 8} then return end
  if emu.read(0x075c, emu.memType.nesInternalRam) ~= 0 then return end
  if emu.read(0x075f, emu.memType.nesInternalRam) ~= 1 then return end
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

    # Parse the entire course in one forward pass. Restarting at checkpoints
    # loses long object continuations (e.g. the question row at columns 79..82).
    # Keep the offline fixture player above terrain; never modify map/parser RAM.
    lua += f"""
emu.addEventCallback(function()
  local ram=emu.memType.nesInternalRam
  if emu.read(0x075f,ram)==1 and emu.read(0x00e7,ram)=={area_start & 255}
     and emu.read(0x00e8,ram)=={area_start >> 8}
     and emu.read(0x0770,ram)==1 and emu.read(0x0772,ram)==3
     and emu.read(0x000e,ram)==8 then
    emu.write(0x00ce,0x20,ram)
    emu.write(0x00b5,1,ram)
    emu.write(0x009f,0,ram)
    emu.write(0x0433,0,ram)
    emu.write(0x001d,2,ram)
  end
end,emu.eventType.endFrame)
"""
    script=out/"capture-forward.lua"
    script.write_text(lua,encoding="utf-8")
    result=subprocess.run([str(tool_path("mesen")),str(args.rom.resolve()),
        "--frames","2600","--home",str(out/"forward-home"),
        "--input","0:start@40-46","--input","0:right,b@80-2599",
        "--lua",str(script),"--lua-allow-io","--timeout","120"],
        capture_output=True,text=True,encoding="utf-8")
    (out/"stdout.log").write_text(result.stdout,encoding="utf-8")
    (out/"stderr.log").write_text(result.stderr,encoding="utf-8")
    if result.returncode: raise RuntimeError(result.stdout+result.stderr)
    columns={v["x"]:{"tiles":v["tiles"],"blocks":v["blocks"]}
        for v in map(json.loads,(out/"columns.jsonl").read_text().splitlines())
        if 0<=v["x"]<WIDTH}
    # The course's scroll lock can leave continuation columns beyond the
    # visible goal room unparsed. Capture that tail from the final checkpoint,
    # but require its preceding columns to agree with the continuous parse.
    tail_overlap=[]
    missing=[x for x in range(WIDTH) if x not in columns]
    if missing:
        first=missing[0]
        if missing!=list(range(first,WIDTH)) or first<200:
            raise RuntimeError(f"ROM forward parser emitted only {len(columns)}/{WIDTH} columns")
        tail=out/"tail";tail.mkdir(exist_ok=True)
        tail_lua=lua.replace(build_world21_origin_lua(),build_world21_origin_lua(12))
        tail_lua=tail_lua.replace(str(out/"columns.jsonl").replace(chr(92),"/"),
            str(tail/"columns.jsonl").replace(chr(92),"/"))
        tail_script=tail/"capture.lua";tail_script.write_text(tail_lua,encoding="utf-8")
        result=subprocess.run([str(tool_path("mesen")),str(args.rom.resolve()),
            "--frames","360","--home",str(tail/"home"),"--input","0:start@40-46",
            "--lua",str(tail_script),"--lua-allow-io","--timeout","120"],
            capture_output=True,text=True,encoding="utf-8")
        (tail/"stdout.log").write_text(result.stdout,encoding="utf-8")
        (tail/"stderr.log").write_text(result.stderr,encoding="utf-8")
        if result.returncode: raise RuntimeError(result.stdout+result.stderr)
        extra={v["x"]:{"tiles":v["tiles"],"blocks":v["blocks"]}
            for v in map(json.loads,(tail/"columns.jsonl").read_text().splitlines())}
        tail_overlap=list(range(first-6,first))
        if any(extra.get(x)!=columns[x] for x in tail_overlap):
            raise RuntimeError("Goal continuation does not match continuous parse")
        for x in missing: columns[x]=extra[x]

    destination = ROOT / "scripts/generated/world21_map.nut"
    destination.write_text(
        "// Generated by tools/parity/capture_world21_map.py from the verified ROM.\n"
        "ROM_WORLD_2_1_METATILES <- [\n"
        + ",\n".join(
            "[" + ",".join(map(str, columns[x]["tiles"])) + "]"
            for x in range(WIDTH)
        )
        + "\n];\nROM_WORLD_2_1_BLOCKS <- [\n"
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
        "world": 2,
        "stage": 1,
        "area_pointer": 0x28,
        "area_data_address": hex(area_start),
        "width": WIDTH,
        "height": 13,
        "columns": len(columns),
        "capture_mode": "continuous-forward-with-verified-tail",
        "tail_overlap_columns": tail_overlap,
        "fixture_player_above_terrain": True,
        "runtime_implemented": False,
        "output": str(destination.relative_to(ROOT)).replace("\\", "/"),
        "output_sha256": sha256_file(destination),
        "capture_script_sha256": sha256_file(script),
        "columns_sha256": sha256_file(out/"columns.jsonl"),
        "tail_columns_sha256": sha256_file(out/"tail/columns.jsonl") if tail_overlap else None,
        "tail_capture_script_sha256": sha256_file(out/"tail/capture.lua") if tail_overlap else None,
        "generator_sha256": sha256_file(Path(__file__)),
    }
    (out / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    asset_manifest=ROOT/"assets/world21/map-manifest.json"
    asset_manifest.parent.mkdir(parents=True,exist_ok=True)
    asset_manifest.write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    print(f"captured {len(columns)} columns; wrote {destination}")


if __name__ == "__main__":
    main()
