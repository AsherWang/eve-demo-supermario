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
- The victory message state follows `PrintVictoryMessages`: four added to the
  secondary counter each frame, carry into the primary counter every 64 frames,
  and primary value four sets the six-interval `WorldEndTimer`. The first text
  remains through primary value one, and the second text begins at primary two.
- Fifty points per converted timer interval, with the timer-tick sound on the
  original four-frame cadence. There is no fixed 5000-point Toad award.

World 2-1 is not implemented. The module ends at an explicit `worldComplete`
state after rescue, retaining the original thank-you messages; this bounded endpoint is not
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

## Original-ROM clear route

`tests/parity/movies/world-1-4-original-clear.json` is the original-ROM clear
movie. Its SHA-256 is
`52ab981fd1df3c10618f96fbada68f7f2e2804ab0c8afe017f85c72484dbdef3`.
It has 2400 input frames represented by 36 non-overlapping input sections and
requests every frame `0..2399` for capture. The replay starts from the normal
World 1-4 raised entrance: small Mario at `x=40`, `y=80`, three lives, and a
300-second timer. The 600-frame controller bootstrap enters the level; frame 0
of the movie is the first normal-play frame after that entrance.

The full original-ROM replay completed without death or player damage. All 2400
decoded states have three lives, no state enters death subroutine `11`, and the
semantic event trace contains no `player_death` event. The former ROM deaths at
frames 789 and 1393 are absent. The verified events are:

| Event | Frame |
| --- | ---: |
| Normal World 1-4 control begins | 0 |
| Axe converts `OperMode` from 1 to 2 | 1863 |
| Bridge blast effects begin | 1864 |
| Last bridge blast effect | 1920 |
| Bowser fall cue | 1920 |
| Victory walk reaches retainer, `OperMode_Task=3` | 2178 |
| Second thank-you message, `PrimaryMsgCounter=2` | 2306 |
| Final verified frame | 2399 |

The blast events occur at frames 1864, 1868, 1872, 1876, 1880, 1884, 1888,
1892, 1896, 1900, 1904, 1908, 1912, 1916, and 1920. At frame 2399, ROM state is
`OperMode=2`, `OperMode_Task=3`, and `GameEngineSubroutine=8`. Mario is healthy
and small at `x=2431`, `y=176`, with three lives and timer 223. Both Toad/retainer
thank-you messages have been displayed. This establishes the normal entrance,
axe transition, complete bridge collapse, Bowser fall, retainer arrival, and
message sequence as one uninterrupted original-ROM run.

The route corrections from the failed 2400-frame candidate were: move the first
firebar jump from 750 to 790; move the second firebar jump from 1450 to 1480;
move the Bowser-approach jump from 1595 to 1660; add jumps at 1760 and 1820 to
cross Bowser and reach the axe; and continue right+B through frame 2200.

The official Mesen reference directory is
`local-parity/original-14-evidence/official-reference`. It contains 2400 RAM
snapshots, 2400 decoded states, 2400 captured PNGs, semantic audio/event traces,
the origin state, manifest, and `verification.json`. Continuous-video proof
compares the state replay with an uninterrupted run: all 2400 states and all APU
writes match, and all 2400 frames were captured. This is an original-ROM result;
it does not establish the six-gate host parity result described below.

## Host route evidence

`tests/parity/movies/world-1-4-route.json` remains the host-implementation route
and its recorded comparison artifacts remain failed evidence. A host replay of
that movie reached a bounded `worldComplete` state at frame 2399, but the same
controller route makes the original ROM die at frames 789 and 1393. That host
result therefore cannot be presented as an original no-death reference and its
early physics mismatches remain unresolved.

## Commands

Regenerate the complete original-ROM reference and its continuous-video proof
from this worktree:

```powershell
python tools/parity/run_reference.py `
  --rom 'roms/Super Mario Bros. (World).nes' `
  --movie tests/parity/movies/world-1-4-original-clear.json `
  --output local-parity/original-14-evidence/official-reference `
  --mesen-agent 'D:/workspace/eve-demos/super-mario/.tools/mesen/mesen-agent.exe'

python tools/parity/extract_reference_state.py `
  --input local-parity/original-14-evidence/official-reference/ram-trace.jsonl `
  --output local-parity/original-14-evidence/official-reference/state.jsonl

python tools/parity/extract_reference_events.py `
  --queues local-parity/original-14-evidence/official-reference/audio-queues.jsonl `
  --ram-trace local-parity/original-14-evidence/official-reference/ram-trace.jsonl `
  --output local-parity/original-14-evidence/official-reference/events-semantic.jsonl

python local-parity/verify_original_14.py
```

The verifier checks the normal entrance, 2400 captured frames, no death routine,
constant three lives, axe/Bowser/retainer/message events, final ROM state, and
the continuous state-and-APU equality proof. It writes
`local-parity/original-14-evidence/official-reference/verification.json`.

The older host-only route can be regenerated without changing the shared
implementation:

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

To reproduce the checked-in PCM without using a runtime emulator:

```powershell
python tools/extract_world14.py `
  --rom 'roms/Super Mario Bros. (World).nes' `
  --origin-state 'D:/workspace/eve-demos/super-mario/local-parity/reference/world-1-4-idle/origin.mss' `
  --mesen 'D:/workspace/eve-demos/super-mario/.tools/mesen/mesen-agent.exe' `
  --audio-work local-parity/world14-audio-verify
```

This reconstruction produced the same five WAV hashes in the manifest and two
matching captures per clip. Nothing from this extraction path is loaded by the
game: runtime playback uses the checked-in PCM files.

## Strict acceptance status

The original-ROM movie clears World 1-4 without death, but the host
implementation is not a strict whole-level pass. Strict completion requires all
six gates in `docs/LEVEL_ACCEPTANCE.md` and a reviewed transition into World 2-1.
World 2 is unavailable, so the host route remains pending. The original movie is
the full-level reference input for the required host replay; it is not a claim
that the six host gates pass. Any mismatch remains failed evidence and must not
be removed by loosening tolerances or sampling frames.

Known review areas still requiring strict evidence are firebar frame equivalence,
Bowser movement and flame cadence, castle question-block animation, Toad palette
and OAM presentation, runtime APU channel stealing/mixing, and the missing real
World 2-1 transition.

The latest all-frame strict probe of the host route remains failed evidence. It
mismatches player vertical physics at frame 29 and horizontal physics at frame
39, before castle actors can be compared. That route makes the ROM enter its
death routine at frames 789 and 1393 while the host route survives. Its APU
stream reached 766 exact frames of 2400, and its audio correlation was 0.618849
with mean absolute PCM error 0.022511. The new original-clear movie removes the
ROM-side deaths on its own replay but still requires a matching host replay and a
fresh six-gate comparison. These failures must remain visible until the shared
player physics and rendering parity are resolved and the full comparison passes.


## Integration replay follow-up

The original-clear movie was replayed against the integration checkout for all
2400 frames in `local-parity/original14/actual/first`. Using the current state
extractor, player X/Y match through frame 1761. The host queues player death at
1761 from Bowser at X 2124; the ROM Bowser is near X 2188. Position diverges at
1762. This is a concrete boss motion error rather than an invalid reference
route. BowserControl adds its signed movement byte independently of facing,
and skips horizontal movement while its mouth is open. The host previously
subtracted positive speed when facing left and continued movement with its
mouth open. These rules have been corrected; the second integration replay completed without death and reached
the retainer sequence. Random movement range, vertical motion and flame cadence still require
strict evidence. The third replay also preserves all three lives. The axe now triggers on a
downward foot probe at frame 1863, matching the ROM; the old body-overlap test
triggered at 1811 and teleported Mario to the axe. Player X/Y now match through
1985, with the first difference at 1986 when the ROM starts victory movement.
The host still needs exact Bowser vertical motion/fall timing and the shared
player physics during victory walking. State and event gates remain failed.
The earlier failed route remains historical evidence.


## Ending presentation fixes (2026-10-28)

The castle transition returned before the common player presentation queue and
animation update, leaving the displayed Mario pose at the axe while logical X
continued walking. The victory walk also advanced X without gravity or floor
collision. It now uses shared automatic player movement, refreshes the shared
OAM presentation queue, animates walking, and stops beside Toad on the room floor.

InitRetainerObj fixes Y to $b8 (184), irrespective of the enemy-stream row.
The Toad canvas now uses OAM palette 2 and mirrored right-hand CHR columns.
Its sprites are drawn in front of background tiles, preserving the last foot
scanline. Victory messages use the ROM HUD font at nametable positions $2548,
$25c5 and $2605, including room scroll. The first message stays when the second
arrives; the enlarged substitute font and development placeholder were removed.

`runWorld14SelfTest()` now drives the complete simulateFixed path for small,
big and fire Mario through walking, landing, rescue and the stationary endpoint.
It checks final X 2431, feet Y 208, camera-relative X 126, sprite-origin Y 176,
preserved powers, Toad Y 184 and changing walk animation. A separate 2800-frame
host replay extends the existing input route with neutral frames through the
stationary endpoint. This is a presentation regression, not a new claim of
strict whole-level ROM equivalence. Bowser and complete victory timing remain
pending as described above.


The final 2800-frame replay is `local-parity/world14-ending-fix/final`.
It reaches `worldComplete` with three lives and no death, Mario at canonical
(2431,176). At its stationary endpoint, pixel comparisons of all three message
regions and the complete 16x24 Toad region match original-ROM frame 2399.
`local-parity/world14-ending-fix/verification.json` records those scoped checks;
this does not imply the entire scene or timing passes strict parity.

## World 2 continuation (2026-10-28)

The current source replaces the stationary World 1 endpoint with a normal
World 2-1 load after the rescue text delay, retaining score, coins, lives and
powers. The previous endpoint capture above remains historical presentation
evidence. The new `world-1-4-to-world-2-1.json` host replay runs 2800 frames,
enters World 2-1 at frame 2496, retains three lives and has no death.
Small/big/fire transition behavior is covered by the simulation regression.
This does not resolve the existing strict Bowser and victory-timing differences.
