"""Run the real game and compare PCM submitted to Windows with a known WAV."""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import wave
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]


def pcm(path: Path) -> bytes:
    with wave.open(str(path), "rb") as stream:
        if (stream.getframerate(), stream.getnchannels(), stream.getsampwidth()) != (48000, 2, 2):
            raise ValueError(f"Expected 48 kHz stereo PCM16: {path}")
        return stream.readframes(stream.getnframes())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--use-game-assets", action="store_true", help="Verify the shipped opening music without replacing it")
    parser.add_argument("--project", type=Path, default=PROJECT)
    parser.add_argument("--eve", type=Path, default=Path.home() / ".codex/cache/evengine/v0.6.0/sdk/eve-sdk/win32/bin/eve.exe")
    parser.add_argument("--output", type=Path, default=PROJECT / "local-parity/native-audio-runtime")
    args = parser.parse_args()
    output = args.output.resolve()
    stage = output / "game"
    stage.mkdir(parents=True, exist_ok=True)
    for directory in ("scripts", "assets", "native/bin"):
        shutil.copytree(args.project / directory, stage / directory, dirs_exist_ok=True)
    shutil.copy2(args.project / "main.nut", stage / "main.nut")
    raw = pcm(args.reference)
    seconds = (len(raw) // 4 + 47999) // 48000 + 1
    capture = output / "runtime-submitted.wav"
    config = (args.project / "config.nut").read_text(encoding="utf-8")
    config += f"\nconfig.hotReload = false;\nconfig.audioCaptureSeconds <- {seconds};\n"
    config += "config.audioCapturePath <- " + json.dumps(capture.as_posix()) + ";\n"
    if not args.use_game_assets:
        config += "config.audioReferenceClip <- " + json.dumps(args.reference.resolve().as_posix()) + ";\n"
    (stage / "config.nut").write_text(config, encoding="utf-8")
    main_source = (stage / "main.nut").read_text(encoding="utf-8")
    main_source += """
local capturedUpdate = eve_update;
eve_update = function(dt) {
    capturedUpdate(dt);
    if (nativeAudioCaptureTime < 0.0) platform_event.pushData("quit", "");
};
"""
    (stage / "main.nut").write_text(main_source, encoding="utf-8")
    with (output / "stdout.log").open("w", encoding="utf-8") as stdout, (output / "stderr.log").open("w", encoding="utf-8") as stderr:
        result = subprocess.run([str(args.eve.resolve()), "run", "-l", str(output / "eve.log"), str(stage)],
                                cwd=stage, stdout=stdout, stderr=stderr, timeout=seconds + 60)
    log = (output / "stdout.log").read_text(encoding="utf-8")
    status = [line for line in log.splitlines() if line.startswith("NATIVE_AUDIO_CAPTURE ")]
    if result.returncode or not status:
        raise RuntimeError(f"Runtime capture failed; inspect {output}")
    actual = pcm(capture)
    # Find a non-silent fingerprint to account only for the queue's startup delay.
    probe = next(i for i in range(0, len(raw), 4) if raw[i:i + 4] != b"\0\0\0\0")
    found = actual.find(raw[probe:probe + 4096])
    offset = found - probe if found >= 0 else -1
    equal = offset >= 0 and actual[offset:offset + len(raw)] == raw
    healthy = all(token in status[-1] for token in ("underruns=0 ", "clipped_samples=0 ", "error=0"))
    report = {"schema": "smb-native-audio-verification-v1", "passed": equal and healthy,
              "input": "game assets" if args.use_game_assets else "reference override",
              "reference_pcm_sha256": hashlib.sha256(raw).hexdigest(),
              "compared_sample_frames": len(raw) // 4, "startup_offset_frames": offset // 4,
              "sample_exact": equal, "runtime_status": status[-1],
              "boundary": "PCM submitted to waveOut; excludes Windows/device processing"}
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
