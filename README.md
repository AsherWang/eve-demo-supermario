# Super Mario Bros. World 1-1 — EVEngine

Personal-study, ROM-data-driven reconstruction of NES World 1-1 in EVEngine.
The repository does not include a ROM. Runtime assets were extracted locally
from a user-provided ROM for this study build.

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

Open `local-parity/reports/index.html` for artifact, frame, state, event and
audio results. The current four movies pass the artifact contract and all
2,440 compared semantic-state frames, including HUD score/coin/time fields;
all four semantic event timelines pass as well. Strict RGB and PCM checks
intentionally remain red until the corresponding renderer and APU differences
are removed.
