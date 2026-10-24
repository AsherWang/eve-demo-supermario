"""Offline asset capture with the local Mesen oracle; no emulator in the game.

Requests use SMBDIS's $FA-$FF sound queues. The ROM executes SoundEngine and
Mesen synthesizes 2A03 PCM. This captures isolated clips, not shared-channel
runtime behavior: music/SFX voice stealing still requires a live APU backend.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import wave
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from tool_paths import tool_path

PROJECT = Path(__file__).resolve().parents[1]
REQUESTS = {
    "star": (0xFB, 0x40, 1202),
    "underground": (0xFB, 0x04, 10820),
    "death": (0xFC, 0x01, 240),
    "course_clear": (0xFC, 0x20, 480),
    "game_over": (0xFC, 0x02, 480),
    "jump": (0xFF, 0x80, 90),
    "jump_big": (0xFF, 0x01, 90),
    "bump": (0xFF, 0x02, 60),
    "stomp": (0xFF, 0x04, 60),
    "kick": (0xFF, 0x08, 60),
    "pipe": (0xFF, 0x10, 120),
    "fireball": (0xFF, 0x20, 60),
    "flag": (0xFF, 0x40, 120),
    "coin": (0xFE, 0x01, 90),
    "powerup_reveal": (0xFE, 0x02, 120),
    "blast": (0xFE, 0x08, 120),
    "powerup": (0xFE, 0x20, 120),
    "oneup": (0xFE, 0x40, 180),
    "break": (0xFD, 0x01, 90),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path, required=True)
    parser.add_argument("--origin-state", type=Path, required=True)
    parser.add_argument("--mesen", type=Path, default=tool_path("mesen"))
    parser.add_argument("--output", type=Path, default=PROJECT / "assets/audio")
    parser.add_argument("--work", type=Path, default=PROJECT / "local-parity/native-audio-assets")
    parser.add_argument("--only", choices=["overworld", *REQUESTS], help="Recapture one clip in an existing asset set")
    args = parser.parse_args()
    if sha(args.rom) != "f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de":
        parser.error("ROM hash differs from the verified SMB sound-queue baseline")
    args.output.mkdir(parents=True, exist_ok=True)
    args.work.mkdir(parents=True, exist_ok=True)
    def run(name: str, state: Path, frames: int, lua: str, output: list[str]) -> None:
        home = args.work / "home" / name
        home.mkdir(parents=True, exist_ok=True)
        script = args.work / f"{name}.lua"
        script.write_text(lua, encoding="utf-8")
        command = [str(args.mesen.resolve()), str(args.rom.resolve()), "--home", str(home.resolve()),
                   "--load-state", str(state.resolve()), "--frames", str(frames), "--timeout", "240",
                   "--lua", str(script.resolve()), *output]
        process = subprocess.run(command, capture_output=True, encoding="utf-8", timeout=260)
        (args.work / f"{name}.log").write_text(process.stdout + process.stderr, encoding="utf-8")
        summaries = [json.loads(line) for line in process.stdout.splitlines() if line.startswith('{"event":"summary"')]
        # Accept whitespace in JSON records as emitted by different agent builds.
        if not summaries:
            for line in process.stdout.splitlines():
                try:
                    value = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if value.get("event") == "summary":
                    summaries.append(value)
        if process.returncode or not summaries or not summaries[-1].get("ok"):
            raise RuntimeError(f"Mesen capture failed: {args.work / (name + '.log')}")

    # Freeze only the gameplay timer. SoundEngine still advances normally.
    freeze = """local frame = 0
emu.addEventCallback(function()
  frame = frame + 1
  if frame > 700 then
    emu.write(0x0787, 0xff, emu.memType.nesInternalRam)
  end
end, emu.eventType.endFrame)
"""
    silent = args.work / "silent-origin.mss"
    run("silence", args.origin_state, 120,
        "emu.write(0xfc, 0x80, emu.memType.nesInternalRam)\n" + freeze,
        ["--save-state", str(silent.resolve())])
    def capture(request: tuple) -> tuple[str, dict]:
        name, address, value, frames = request
        print(f"Capturing {name} ({frames} frames)", flush=True)
        path = args.output / f"{name}.wav"
        lua = freeze if name == "overworld" else (
            f"emu.write({address}, {value}, emu.memType.nesInternalRam)\n" + freeze
        )
        run(name, args.origin_state if name == "overworld" else silent, frames, lua,
            ["--audio", str(path.resolve())])
        with wave.open(str(path), "rb") as wav:
            if (wav.getframerate(), wav.getsampwidth(), wav.getnchannels()) != (48000, 2, 2):
                raise RuntimeError(f"Unexpected oracle PCM format: {path}")
            count = wav.getnframes()
        print(f"Captured {name}", flush=True)
        return name, {"sha256": sha(path), "sample_frames": count,
                      "queue_address": address, "queue_value": value, "emulated_frames": frames,
                      "timer_freeze_after_frame": 700}
    requests = [("overworld", 0, 0, 10820)] + [(name, *request) for name, request in REQUESTS.items()]
    records = {}
    if args.only:
        manifest_path = args.output / "oracle-audio-manifest.json"
        if manifest_path.exists():
            records = json.loads(manifest_path.read_text(encoding="utf-8"))["clips"]
            for entry in records.values():
                entry.setdefault("timer_freeze_after_frame", 0)
        requests = [request for request in requests if request[0] == args.only]
    with ThreadPoolExecutor(max_workers=4) as pool:
        records.update(pool.map(capture, requests))
    manifest = {
        "schema": "smb-oracle-audio-assets-v1", "rom_sha256": sha(args.rom),
        "mesen_sha256": sha(args.mesen), "origin_sha256": sha(args.origin_state),
        "sample_rate": 48000, "channels": 2, "sample_width": 2,
        "method": "Offline original SoundEngine and Mesen 2A03; unmodified captured PCM",
        "limitation": "Isolated clips; runtime shared APU channel stealing is not reproduced",
        "clips": records,
    }
    (args.output / "oracle-audio-manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
