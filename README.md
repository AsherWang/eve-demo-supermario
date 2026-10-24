# Super Mario Bros. World 1-1 / 1-2 — EVEngine

Personal-study, ROM-data-driven reconstruction of NES World 1-1 and 1-2 in EVEngine.
The packaged game does not include a ROM. Runtime assets were extracted locally
from a user-provided ROM for this study build.

The user-supplied ROM for local extraction and parity tests is kept at
`roms/Super Mario Bros. (World).nes`; see [`roms/README.md`](roms/README.md) for
its SHA-256 and usage. It is not included in packaged game releases.

This is a vibe coding project, developed through AI-assisted, iterative
experimentation and verification against the original game.

This is an unofficial, non-commercial study project and is not affiliated with
or endorsed by Nintendo.

## Included

- Full World 1-1 foreground, scenery and enemy streams decoded from the ROM
- Small, Super and Fire Mario with original integer movement tables
- Original item-bearing blocks, hidden 1UP, multi-coin brick and star brick
- Goombas, green Koopa shell lifecycle, fireballs and block-hit enemy flips
- Enterable pipe, ROM-defined underground coin room and main-area return pipe
- Flag slide, automatic castle walk, time bonus, fireworks and course completion
- ROM 8×8 HUD font, 400 timer, lives, halfway checkpoint and Game Over
- Offline ROM/Mesen-captured 48 kHz stereo music and sound effects
- Independent Windows PCM playback through a native EVEngine plugin
- Startup regression suite covering layout, objects, movement and state changes
- World 1-2 underground map and coin room from the original ROM parser's metatiles
- World 1-2 entrance, pipe return, surface exit, lifts, piranha plants and roof route

World 1-2 implementation and its current comparison coverage are documented in
[`docs/WORLD_1_2_PLAN.md`](docs/WORLD_1_2_PLAN.md). Warp Zone destinations beyond
World 1 are not implemented; selecting one ends at a destination screen.

The overall milestones, current gaps, and acceptance criteria are tracked in
[`docs/ROADMAP.md`](docs/ROADMAP.md).

For isolated parallel development, see
[`docs/WORKTREE_DEVELOPMENT.md`](docs/WORKTREE_DEVELOPMENT.md).

## Controls

- Move: arrow keys or A/D
- Run / fireball: X or Left Shift
- Jump: Z or Space
- Enter pipe: Down while standing on the World 1-1 warp pipe
- Reset (or restart after Game Over): R
- Start World 1-2 at its entrance: F2 (or finish World 1-1)

For development, set `startLevel = 2` in `config.nut`; `startArea` accepts
`intro`, `underground`, `bonus`, or `exit` to inspect that World 1-2 area.

## Run from source

Project layout and local development data are documented in
[`docs/PROJECT_LAYOUT.md`](docs/PROJECT_LAYOUT.md). Builds use `build/` and
standalone Windows packages use `dist/` inside this project.

On Windows x64, install Python 3.12+ (available as `python` on PATH) and Visual
Studio 2022 C++ Build Tools with Desktop development with C++ and CMake tools.
PowerShell 7 is recommended. Then run from the project root:

```powershell
./tools/setup_windows.ps1
./tools/package_windows.ps1
```

Setup downloads checksum-pinned EVEngine v0.6.0 and Mesen agent v0.1.0 into
ignored `.tools/`, and installs `requirements.txt` into `.venv/`. Open the newest
`dist/super-mario-<timestamp>-win64/SuperMario.exe` to play. To run editable source:

```powershell
./tools/build_native_audio.ps1
& ./.tools/evengine/eve-sdk/win32/bin/eve.exe run .
```

## Rebuild local audio

Generate the origin state first; a fresh clone contains no emulator save states:

```powershell
.\.venv\Scripts\python.exe tools/parity/run_reference.py `
  --rom 'roms/Super Mario Bros. (World).nes' `
  --movie tests/parity/movies/world-1-1-idle-opening-10s.json `
  --output local-parity/reference/world-1-1-idle-opening-10s

.\.venv\Scripts\python.exe tools/render_reference_audio_assets.py `
  --rom 'roms/Super Mario Bros. (World).nes' `
  --origin-state local-parity/reference/world-1-1-idle-opening-10s/origin.mss
```

This offline renderer uses the verified ROM's sound queues and the Mesen 2A03
output. It records provenance in `oracle-audio-manifest.json`. The older
`generate_audio.py` and `render_smb_rom_music.py` are historical synthesis
experiments; they do not produce the current runtime assets.

The native playback design, actual-game PCM verification and remaining
shared-channel limitations are documented in [`native/audio/README.md`](native/audio/README.md).
The engine integration change record (Chinese), including the unchanged engine
boundary, build instructions and verification evidence, is in
[`docs/ENGINE_AUDIO_CHANGES.md`](docs/ENGINE_AUDIO_CHANGES.md).

The exact-vs-approximate boundary and automatic comparison inventory are in
[`ORIGINAL_PARITY_CHECKLIST.md`](ORIGINAL_PARITY_CHECKLIST.md).
The source-of-truth rules and ordered path to frame/cycle accuracy are in
[`REPRODUCTION_METHOD.md`](REPRODUCTION_METHOD.md).
The executable ROM-vs-remake regression plan and local commands are in
[`PARITY_TEST_PLAN.md`](PARITY_TEST_PLAN.md).
The versioned movie and artifact contract is in
[`PARITY_ARTIFACT_SPEC.md`](PARITY_ARTIFACT_SPEC.md).

## Deterministic ROM parity suite

The ROM is used only by the local Mesen reference runner. It is never linked
into the EVEngine executable or copied into `dist/`.

```powershell
.\.venv\Scripts\python.exe tools\parity\run_suite.py `
  --rom 'roms\Super Mario Bros. (World).nes'
```

The first run generates all reference captures. Add `--reuse-reference` only
after a successful first run. For a quick first check, add `--cases walk-right-smoke`.
See [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) for tool overrides and verification.

Open `local-parity/reports/index.html` for artifact, frame, state, event, APU,
strict PCM and runtime-WAV quality results. The current seven movies pass the artifact contract, all
4,260 compared semantic-state frames, all semantic events, every sampled RGB
frame, and the complete per-frame `$4000-$4017` APU write stream (controller
and DMA registers excluded). The APU model is seeded from reference frame 0,
then driven only by the remake's events and state. Strict comparison PCM is
also sample-exact: the ROM/Mesen replay supplies the original CPU-cycle
schedule and 2A03 mixer, while every injected APU register value comes from
the independent remake-side model.

The interactive runtime now uses an independent Windows PCM worker and
offline oracle-captured clips. `tools/check_native_audio.py` verifies the actual
game's submitted PCM against the 10-second idle reference, including underrun
and clipping checks. The suite's event-based WAV renderer remains an offline
approximation, not a recording of the running game. Shared APU channel stealing
and nonlinear music/SFX mixing are still not reproduced in the runtime.
The emulator core stays a local test oracle and is not embedded in the game.

The CPU-cycle carrier is deliberately treated as reference-only evidence, not
as part of the remake. Run `tools/parity/analyze_apu_cycles.py` to reproduce the
current ambiguity measurement: across the original five-movie analysis set, 187 of 404 identical
per-frame APU address/value templates occur on multiple absolute CPU schedules,
and 73 even use different spacing between writes. Values and order alone are
therefore insufficient to infer cycle-exact audio timing.
