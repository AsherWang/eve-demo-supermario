"""Run the real game and compare PCM submitted to Windows with a known WAV."""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import wave
from pathlib import Path
from tool_paths import tool_path

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
    parser.add_argument("--death-respawn", action="store_true", help="Verify real music output after the World 1-1 death reload resumes music")
    parser.add_argument("--project", type=Path, default=PROJECT)
    parser.add_argument("--eve", type=Path, default=tool_path("eve"))
    parser.add_argument("--output", type=Path, default=PROJECT / "local-parity/native-audio-runtime")
    parser.add_argument("--area", choices=["main", "water", "underground", "castle"],
                        help="Select a runtime area track in a stationary scene; not a transition test")
    parser.add_argument("--sample-seconds", type=float, help="Compare only this prefix of the supplied reference")
    parser.add_argument("--hurry", action="store_true", help="Select the fast area track; requires --area")
    args = parser.parse_args()
    if args.hurry and not args.area: parser.error("--hurry requires --area")
    if args.area and (not args.use_game_assets or args.death_respawn):
        parser.error("--area requires --use-game-assets and cannot be combined with --death-respawn")
    if args.sample_seconds is not None and args.sample_seconds <= 0:
        parser.error("--sample-seconds must be positive")
    output = args.output.resolve()
    stage = output / "game"
    stage.mkdir(parents=True, exist_ok=True)
    for directory in ("scripts", "assets", "native/bin"):
        shutil.copytree(args.project / directory, stage / directory, dirs_exist_ok=True)
    shutil.copy2(args.project / "main.nut", stage / "main.nut")
    raw = pcm(args.reference)
    if args.sample_seconds is not None:
        raw = raw[:round(args.sample_seconds * 48000) * 4]
    seconds = (len(raw) // 4 + 47999) // 48000 + 1
    capture = output / "runtime-submitted.wav"
    config = (args.project / "config.nut").read_text(encoding="utf-8")
    config += f"\nconfig.hotReload = false;\nconfig.audioCaptureSeconds <- {seconds};\n"
    config += "config.audioCapturePath <- " + json.dumps(capture.as_posix()) + ";\n"
    if not args.use_game_assets:
        config += "config.audioReferenceClip <- " + json.dumps(args.reference.resolve().as_posix()) + ";\n"
    (stage / "config.nut").write_text(config, encoding="utf-8")
    main_source = (stage / "main.nut").read_text(encoding="utf-8")
    if args.area:
        main_source += """
local areaCaptureInit = eve_init;
eve_init = function() {
    areaCaptureInit();
    nativeAudio.stopAll();
    nativeAudio.beginCapture(config.audioCaptureSeconds);
    nativeAudioCaptureTime = 0.0;
    game.area = """ + json.dumps(args.area) + """;
    game.hurryActive = """ + ("true" if args.hurry else "false") + """;
    game.state = "preview";
    game.soundEvents.clear();
    resumeMusic();
};
"""
    if args.death_respawn:
        main_source += """
local capturedInit = eve_init;
eve_init = function() {
    capturedInit();
    nativeAudio.stopAll();
    stopMusic();
    nativeAudio.beginCapture(config.audioCaptureSeconds);
    nativeAudioCaptureTime = 0.0;
    game = createGame();
    finishPlayerDeath(game);
    game.deathReloadFrames = 164;
    updateDeathReload(game);
    flushSoundEvents(game);
};
"""
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
              "scenario": "World 1-1 death reload music boundary" if args.death_respawn else ("stationary area track: " + args.area + (" fast" if args.hurry else "") if args.area else "opening"),
              "boundary": "PCM submitted to waveOut; excludes Windows/device processing"}
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
