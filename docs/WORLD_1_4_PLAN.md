# World 1-4 implementation and evidence

## Scope

World 1-4 is implemented in an isolated worktree at branch `codex/world-1-4`
from `a1c6c49`. The checked-in module owns only the World 1-4 scripts, generated
map/stream data, castle assets, extraction and capture tools, its deterministic
movie, and this plan. Shared player physics, rendering, audio, parity tooling, and
stage routing remain parent-owned integration points.

The module exports the agreed interface:

- `startWorld14(g)`
- `updateWorld14Actors(g)`
- `drawWorld14Actors(g, behind)`
- `loadWorld14Assets()`
- `runWorld14SelfTest()`
- `updateWorld14Transition(g)` (returns `true` while consuming castle-clear state)
- `world14TileTexture(g, tx, ty, tile)`
- `drawWorld14Background(g)` (no-op; the shared castle renderer supplies black)

`world14.nut` loads `scripts/generated/world14_data.nut` and
`scripts/generated/world14_map.nut` itself. The parent only needs to load the
module and call `loadWorld14Assets()` after the shared asset load.

## ROM data and behavior

The verified ROM SHA-256 is
`f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de`.
ROM and Mesen are offline evidence tools only; neither is used by the game at
runtime.

The area and enemy streams come from `L_CastleArea1` and `E_CastleArea1`.
`tools/parity/capture_world14_map.py` captures the ROM parser's completed
metatile columns, and `tools/extract_world14.py` writes the generated NUT data
and castle image assets. The map is 160 columns wide. The raised entrance starts
Mario at X 40, canonical Y 80, with the canonical 300 second castle timer.

Implemented rules include:

- ROM metatiles for castle walls, lava, bridge, axe, chain, and decorative tiles.
- Firebar motion indexed by `FirebarPosLookupTbl`, `FirebarTblOffsets`, mirror
  data, per-enemy speed, direction, and the 16.8-bit rotation state.
- Podoboo and lava damage, Bowser body collision, five-hit Bowser state, mouth
  flips, movement, eight-entry flame interval table, and left-moving flames.
- Axe-triggered automatic bridge collapse in SMBDIS order: axe, chain, then the
  thirteen bridge columns from `$98` through `$80`, once every four frames.
- Bowser fall state after the final bridge section and end-castle music after he
  passes the original vertical threshold.
- Toad/mushroom-retainer rescue at the ROM object position. The first message is
  `THANK YOU MARIO!`; the continuation is `BUT OUR PRINCESS IS IN ANOTHER
  CASTLE!`. There is no princess entity or `princess_rescued` event in 1-4.
- Fifty points per converted timer interval, with the timer-tick sound on the
  original four-frame cadence. There is no fixed 5000-point Toad award.

World 2-1 is not implemented. The module ends at an explicit `worldComplete`
state after rescue and displays `WORLD 2-1 PENDING`; this bounded endpoint is not
a claim that the original World 2 transition is complete.

## Audio provenance

The checked-in WAV files are offline 2A03 captures, not synthesized notes. All
are 48 kHz stereo PCM16. `assets/world14/audio-manifest.json` records the ROM,
Mesen, origin-state and reference hashes.

| Asset | Semantic queue | Emulated frames | Matching references |
| --- | --- | ---: | ---: |
| `castle_theme.wav` | area music, `$FB=$08` | 10820 | 2 |
| `castle_fast.wav` | hurry castle music, `$FB=$08`, adder 8 | 3600 | 2 |
| `castle_clear.wav` | end-castle music, `$FC=$08` | 480 | 2 |
| `bowser_fire.wav` | Bowser flame, `$FD=$02` | 90 | 2 |
| `bowser_fall.wav` | Bowser fall, `$FE=$80` | 90 | 2 |

The parent runtime asset list must include `castle_theme`, `castle_fast`,
`castle_clear`, `bowser_fire`, and `bowser_fall`, and map hurry castle music to
`castle_fast`.

## Deterministic route

`tests/parity/movies/world-1-4-route.json` contains 2400 input frames and requests
all 2400 comparison images. It starts at the normal raised entrance and ends with
a stable bounded completion state. The controller route was timed against the
exact ROM firebar rotation; the earlier sine approximation is deliberately gone.

The final host replay produced 2400 states and 2400 PNGs with no player-death
events. Important frames are:

| Event | Frame |
| --- | ---: |
| Axe touched | 1641 |
| Bowser fall cue | 1709 |
| Victory walk begins | 1774 |
| Toad saved | 1966 |
| Bounded `worldComplete` | 2199 |
| Final captured frame | 2399 |

At frame 2399 the host state is `worldComplete`, timer 0, score 11600, lives 3.
The score is the original 50-point-per-timer-interval conversion from the initial
300 second timer to zero.

## Commands

```powershell
$env:EVE_EXE='D:/workspace/eve-demos/super-mario/.tools/evengine/eve-sdk/win32/bin/eve.exe'

python tools/parity/run_actual.py `
  --movie tests/parity/movies/world-1-4-route.json `
  --output local-parity/actual/world14-route-candidate `
  --project . --timeout 240

python tools/parity/run_case.py `
  --rom 'roms/Super Mario Bros. (World).nes' `
  --movie tests/parity/movies/world-1-4-route.json `
  --artifacts local-parity/strict-world14
```

The full replay invokes `runWorld14SelfTest()` during startup. Direct source
startup also exercises the self-test through the parent integration.

## Strict acceptance status

This is a functional, deterministic host route, not a strict whole-level pass.
Strict completion requires all six gates in `docs/LEVEL_ACCEPTANCE.md` and a
reviewed transition into World 2-1. World 2 is unavailable, so the current route
must remain marked pending. The all-frame ROM reference and six-gate comparison
must be rerun after final integration; any mismatch remains failed evidence and
must not be removed by loosening tolerances or sampling frames.

Known review areas still requiring strict evidence are firebar frame equivalence,
Bowser movement and flame cadence, castle question-block animation, Toad palette
and OAM presentation, runtime APU channel stealing/mixing, and the missing real
World 2-1 transition.
