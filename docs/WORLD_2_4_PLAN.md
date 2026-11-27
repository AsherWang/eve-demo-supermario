# World 2-4 implementation and evidence

Playable implementation with verified host route; strict acceptance remains pending. Branch `codex/world24-development`.

## Integration contract

Load `scripts/world24.nut` after world13; call `loadWorld24Assets()` after shared assets.
Add `{world=2,stage=4,load=function(g){startWorld24(g);}}` to LEVEL_DATA.
Dispatch `isWorld24(g)` to `updateWorld24Actors`, `updateWorld24Transition`,
`drawWorld24Background`, `drawWorld24Actors`, `world24TileTexture`, and
`world24Assets.hudCoins` before the World 1-4 equivalents.
Keep the existing animation/presentation/frame-counter block after transition handling.
Call `updateWorld24DeathReload(g)` before generic `g.level>=3` death routing.
Generic resetRound world=2 dispatch may use the new stage registry.
The castle has **no midpoint** (World2 HalfwayPageNybbles $65,$70, stage4=0).
Do not use the generic World2 page6 death checkpoint.
The bounded `worldComplete` endpoint preserves world=2, level=4 and Toad text;
3-1 is not implemented and strict transition acceptance must remain pending.

## ROM identity

World2Areas[4]=$62 -> CastleArea3; L stream CPU $a28f, 115 bytes;
E stream CPU $9db0, 47 bytes. Shared with 5-4, excluding hard-mode objects.
The normal stream includes two Podoboos, six short firebars, two small lifts,
a horizontal bridge platform, a Bowser-flame generator, Bowser and Toad.

## Verified gameplay and original evidence (2026-11-28)

The updated mechanics use ROM player/platform/flame/Bowser collision boxes,
32-pixel horizontal platforms, parser-boundary activation, enemy slot reuse,
Podoboo gravity and interval timers, and Bowser/flame RNG timing. The initial
seven-byte RNG state is taken from the verified normal castle origin.

Two fixed-input fixtures serve different producer timelines:

- `world-2-4-host-route.json`: 1812 frames, SHA256
  `5f9b459663c51bea244c586c9f01ae795c458bfcf43d42ff504b51197b7616a2`.
  Independent parent `run_gameplay_route.py` calls normal startLevel(2,4),
  advances input frame zero, and passes with no deaths/life loss. Entrance is
  x40/body-y96, small Mario, three lives. Natural worldComplete first appears
  at output frame1554, x2431/body-y192, still World2/stage4.
  Evidence: `local-parity/world24-gameplay-route-v3/summary.json`.
  Stage runner `--normal-start` also passes (its output starts after the first
  input, hence axe911, victory1047, rescue1171, complete1553).
- `world-2-4-original-clear.json`: 2800 frames, SHA256
  `71e117e31349a1e0e8856b87de5816c3331ef12296bf3862bee21db91323a849`.
  Original normal entrance through axe1094, retainer1433 and next World3-1
  at1807, no deaths or life loss. All 2800 PNGs/RAM/APU rows are captured.
  Continuous cold-boot replay matches saved-origin states and APU writes.
  Evidence: `local-parity/world24-original-clear-reference/verification.json`
  and `continuous-video/proof.json` in that directory.
  Host parity-timeline replay also clears: axe1094, victory1241, rescue1355,
  bounded worldComplete1737. Player x/y match the original through1242.

The parity producer displays the saved entrance on frame zero before advancing.
The normal-start producer advances input zero immediately. The original-clear
fixture is not advertised as passing the independent normal-start host runner;
use the separate host-route fixture for that test. No route writes player state
mid-run. Origin construction/geometry fixtures are separate from route replay.
All newly generated movie/provenance files explicitly use LF newlines.

Focused mechanics tests cover live and fire-defeated Bowser axe completion,
zero checkpoint at entrance/page6/page8, progress retention, fatal lava,
small-lift side collision, the central flame hitbox, and unchanged time/score
during castle messages. These use explicit
setup and are not route evidence. Five ROM/data integrity tests pass.

Commands (with parent hooks and its independent runner):

```powershell
python tests/parity/test_world24_data.py
python tools/parity/run_world24_simulation.py --normal-start --movie tests/parity/movies/world-2-4-host-route.json --output local-parity/world24-host-v3 --require-clear --self-test
python tools/parity/run_gameplay_route.py --movie tests/parity/movies/world-2-4-host-route.json --output local-parity/world24-gameplay-route-v3
python tools/parity/run_world24_simulation.py --movie tests/parity/movies/world-2-4-original-clear.json --output local-parity/world24-original-motion-host-v3 --require-clear --self-test
python tools/parity/verify_world24_reference.py --movie tests/parity/movies/world-2-4-original-clear.json --reference local-parity/world24-original-clear-reference
```

## Strict failures and remaining work

Formal acceptance remains pending; no acceptance inventory or tolerance changed.
`tests/parity/world24_evidence_summary.json` records existing evidence paths and
hashes, not approval. Full unmodified comparison reports are under
`local-parity/world24-original-comparison-v3-reports/`:

- States FAIL across 2800 frames, zero missing. Player x/y first differ at1243;
  other fields, including actors, differ earlier. Host parity serializer needs
  World24 actor and victory operation-mode/task dispatch; shared serializer
  changes remain parent-owned. Mode2 must describe the actual ending state.
- Events FAIL at tolerance0; bridge blast events are one frame early.
- Modeled host APU FAIL: first write-stream/end-register mismatch593;
  1049/2800 exact write-stream frames, 593 matching end-register frames.
  This uses the shared offline APU model, not a native-output audio capture.
- Current full native frames and waveform comparison are pending parent capture.
  The stage actual wrapper alone does not establish correct origin: shared main
  must dispatch PARITY_START_WORLD=2/PARITY_START_LEVEL=4 to startLevel(2,4),
  and the resulting first state must be checked before interpreting captures.
- Original transitions to 3-1 at1807; host preserves World2/stage4 worldComplete
  because 3-1 is not implemented. This intentionally fails strict transition.
  Branch review and all six acceptance gates remain required.

The first commit's 1813-frame host movie and its failed original late-pit replay
are superseded; their old captures do not match the current host movie hash.
The old partial native capture under `local-parity/world24-strict/actual` is
incomplete and is not evidence for the updated mechanics. Parent owns current
native capture; do not queue duplicate graphical runs.

## Ending diagnosis

NES `game/modes.asm:handler_print_victory_messages` does not call
AwardGameTimerPoints; this profile preserves time and score during castle text.
The inherited timer-to-score bonus has been removed. The original-clear host
still clears with the same milestones; the score/time comparison now matches
until the original initializes 3-1.

The original RAM shows task0/1/2 cycles at1242..1250 while Mario's foot remains
in the axe row, followed by normal victory walking. `handler_player_victory_walk`
uses destination page9, disables right input at page9+x$60 (2400), then lets
friction stop Mario at2429. It independently scrolls 1.5 pixels/frame until
camera2304, entering message task3 at1433. Current host instead auto-walks to
2431 and ties camera position to the player, explaining the earlier rescue.
This requires a faithful axe/block-buffer and victory camera implementation;
no per-movie waits or coordinate patches were introduced.

The messages reach primary counter4 at1689, dispatch task4 at1690, and the
ROM's shared 21-frame interval timer expires at1807. Current host uses a fixed
126-frame end wait; exact remaining timer phase is another known mismatch.
Parent's serializer should report actual task phases, not force ROM frame
numbers. These discrepancies are documented, not accepted or suppressed.

## Geometry extraction

`capture_world24_map.py` runs one forward ROM parser traversal. Page backloading
was rejected after a conflicting continuation at column48. Its collision-free
fixture is explicitly geometry extraction, never gameplay-route evidence.
The game loads only generated arrays and PNG assets; ROM/Mesen are offline.
`extract_world24.py` regenerates stage assets and references existing castle audio.
All graphical captures claim the shared GPU lock atomically and release only
the matching owner token. `.tools`, `roms` and reference source remain read-only.
