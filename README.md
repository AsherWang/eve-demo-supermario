# Super Mario Bros. World 1-1 — EVEngine

Personal-study, ROM-data-driven reconstruction of NES World 1-1 in EVEngine.
The repository does not include a ROM. Runtime assets were extracted locally
from a user-provided ROM for this study build.

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
- ROM-data-driven ground, star, death, course-clear and Game Over music
- EVEngine OpenAL effects; remaining non-ROM SFX are explicitly tracked as approximate
- Startup regression suite covering layout, objects, movement and state changes

## Controls

- Move: arrow keys or A/D
- Run / fireball: X or Left Shift
- Jump: Z or Space
- Enter pipe: Down while standing on the World 1-1 warp pipe
- Reset (or restart after Game Over): R

## Run from source

Install EVEngine v0.6.0 (or make its executable available on `PATH`), then run:

```powershell
eve run
```

## Rebuild local audio

```powershell
python tools\generate_audio.py
python tools\render_smb_rom_music.py --rom 'C:\path\to\Super Mario Bros. (World).nes' --output assets\audio
```

The music renderer rejects missing, duplicate, or unknown ROM structures rather
than guessing. It writes a provenance manifest beside the WAV files.

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
python tools\parity\run_suite.py `
  --rom 'C:\path\to\Super Mario Bros. (World).nes' `
  --reuse-reference
```

Open `local-parity/reports/index.html` for artifact, frame, state, event, APU
and audio results. The current seven movies pass the artifact contract, all
4,260 compared semantic-state frames, all semantic events, every sampled RGB
frame, and the complete per-frame `$4000-$4017` APU write stream (controller
and DMA registers excluded). The APU model is seeded from reference frame 0,
then driven only by the remake's events and state. Strict comparison PCM is
also sample-exact: the ROM/Mesen replay supplies the original CPU-cycle
schedule and 2A03 mixer, while every injected APU register value comes from
the independent remake-side model.

This green test result does not mean the shipped EVEngine audio path is yet
cycle-exact. The interactive runtime still mixes pre-rendered music and
independent SFX WAVs; replacing that path with a streaming 2A03-compatible
backend remains separate implementation work. The emulator core stays a
local test oracle and is not embedded in the game.

The CPU-cycle carrier is deliberately treated as reference-only evidence, not
as part of the remake. Run `tools/parity/analyze_apu_cycles.py` to reproduce the
current ambiguity measurement: across the original five-movie analysis set, 187 of 404 identical
per-frame APU address/value templates occur on multiple absolute CPU schedules,
and 73 even use different spacing between writes. Values and order alone are
therefore insufficient to infer cycle-exact audio timing.
