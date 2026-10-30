"""Offline parser capture of World 2-1 bonus-entry map windows."""
from __future__ import annotations
import argparse
import json
import subprocess
import sys
from pathlib import Path
from common import sha256_file, tool_path
from run_reference import EXPECTED_ROM_SHA256
from world21_reference import build_world21_origin_lua
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from extract_world21_branches import stream

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path, default=ROOT / "roms/Super Mario Bros. (World).nes")
    parser.add_argument("--output", type=Path, default=ROOT / "local-parity/world21-branches-map")
    parser.add_argument("--reuse-capture", action="store_true", help="reuse completed capture only if its Lua and successful summary match")
    args = parser.parse_args()
    if sha256_file(args.rom) != EXPECTED_ROM_SHA256:
        parser.error("unverified ROM")
    prg = args.rom.read_bytes()[16:32784]
    signature = bytes.fromhex("ad260729018505ac40038400ad2107")
    if prg.count(signature) != 1:
        raise ValueError("parser callback signature is not unique")
    callback = prg.index(signature) + 0x8000
    all_columns, records = {}, []
    for name, pointer, width in [("sky", 0x2b, 48), ("underground", 0x42, 16)]:
        out = args.output.resolve() / name
        out.mkdir(parents=True, exist_ok=True)
        area_base = stream(prg, pointer, False)[0] + 2
        origin = build_world21_origin_lua().replace("0x28", hex(pointer))
        origin = origin.replace("emu.write(0x0752,0,ram)",
            "emu.write(0x0752,0,ram)\n    emu.write(0x0751,0,ram)\n    emu.write(0x0743," + str(int(name == "sky")) + ",ram)")
        lua = origin + f"""
local seen={{}}
local file=assert(io.open({json.dumps(str(out / 'columns.jsonl').replace(chr(92), '/'))},"wb"))
local function active(ram)
 return emu.read(0x075f,ram)==1 and emu.read(0x075c,ram)==0
    and emu.read(0x00e7,ram)=={area_base & 255}
    and emu.read(0x00e8,ram)=={area_base >> 8}
end
emu.addMemoryCallback(function()
 local ram=emu.memType.nesInternalRam
 if not active(ram) then return end
 local x=emu.read(0x0725,ram)*16+emu.read(0x0726,ram)
 if seen[x] then return end
 seen[x]=true
 local tiles,blocks={{}},{{}}
 local col=emu.read(0x06a0,ram)
 local base=(col & 0xf0)==0 and 0x0500 or 0x05d0
 for row=0,12 do
  tiles[#tiles+1]=tostring(emu.read(0x06a1+row,ram))
  blocks[#blocks+1]=tostring(emu.read(base+(col & 15)+row*16,ram))
 end
 file:write('{{"x":'..x..',"tiles":['..table.concat(tiles,",")..'],"blocks":['..table.concat(blocks,",")..']}}\\n')
 file:flush()
end,emu.callbackType.exec,{callback},{callback},emu.cpuType.nes)
emu.addEventCallback(function()
 local ram=emu.memType.nesInternalRam
 if active(ram) and emu.read(0x0772,ram)==3 and emu.read(0x000e,ram)==8 then
  emu.write(0x00ce,0x20,ram);emu.write(0x00b5,1,ram)
  emu.write(0x009f,0,ram);emu.write(0x0433,0,ram);emu.write(0x001d,2,ram)
 end
end,emu.eventType.endFrame)
"""
        script = out / "capture.lua"
        if args.reuse_capture:
            if script.read_text(encoding="utf-8") != lua:
                raise ValueError("existing Lua does not match this capture configuration")
        else:
            script.write_text(lua, encoding="utf-8")
            result = subprocess.run([str(tool_path("mesen")), str(args.rom.resolve()),
                "--frames", "1400", "--home", str(out / "home"),
                "--input", "0:start@40-46", "--input", "0:right,b@80-1399",
                "--lua", str(script), "--lua-allow-io", "--timeout", "120"],
                capture_output=True, text=True, encoding="utf-8")
            (out / "stdout.log").write_text(result.stdout, encoding="utf-8")
            (out / "stderr.log").write_text(result.stderr, encoding="utf-8")
            if result.returncode:
                raise RuntimeError(result.stdout + result.stderr)
        events = [json.loads(line) for line in (out / "stdout.log").read_text().splitlines() if line.startswith("{")]
        if not any(e.get("event")=="summary" and e.get("ok") and e.get("frames_executed")==1400 for e in events):
            raise ValueError("capture lacks successful full-length emulator summary")
        if any(e.get("error_count",0) for e in events):
            raise ValueError("Lua capture reported errors")
        columns = {d["x"]: d for d in map(json.loads, (out / "columns.jsonl").read_text().splitlines())}
        missing = sorted(set(range(width)) - columns.keys())
        if missing:
            raise ValueError(f"{name}: missing columns {missing}; capture retained")
        all_columns[name] = [columns[x] for x in range(width)]
        records.append(dict(name=name, area_pointer=pointer, area_data_address=hex(area_base),
            width=width, height=13, observed_columns=len(columns), cloud_override=int(name == "sky"),
            columns_sha256=sha256_file(out / "columns.jsonl"),
            stdout_sha256=sha256_file(out / "stdout.log"),
            script_sha256=sha256_file(script), scope="bonus-entry window; not whole shared area"))
    lines = ["// Offline ROM parser output; generated by capture_world21_branches.py."]
    for name, columns in all_columns.items():
        for key, suffix in [("tiles", "METATILES"), ("blocks", "BLOCKS")]:
            lines.append("ROM_WORLD_2_1_" + name.upper() + "_" + suffix + " <- [\n" +
                ",\n".join("[" + ",".join(map(str, col[key])) + "]" for col in columns) + "\n];")
    target = ROOT / "scripts/generated/world21_branch_maps.nut"
    target.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    manifest = dict(rom_sha256=EXPECTED_ROM_SHA256, parser_cpu_address=hex(callback),
        captures=records, fixture_player_above_terrain=True, runtime_connected=False,
        output_sha256=sha256_file(target))
    (ROOT / "assets/world21/branch-maps-manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(manifest))


if __name__ == "__main__":
    main()
