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

## Verified host gameplay (2026-11-28)

`tests/parity/movies/world-2-4-host-route.json` contains 1813 fixed-input frames.
SHA256: `c701ccd97cd8e3f4c2db5dba9abf77a4a8a359849033835b89417e6a36ef3b13`.
The independent parent `run_gameplay_route.py` passes: normal startLevel(2,4),
x=40/body-y=96, small Mario, three lives, no death or life loss. First natural
worldComplete is frame 1549; final x=2431/body-y=192, still world2/stage4.
Stage diagnostic replay records axe frame912, victory walk1041, retainer1166,
worldComplete1548 (diagnostic frame0 is the unadvanced entrance).
Focused mechanics tests cover both fire-defeated and live Bowser axe clear,
zero checkpoint at entrance/page6/page8, progress retention, and fatal lava.
They are explicit setup tests and **not** route evidence.

Commands (after parent hooks):

```powershell
python tests/parity/test_world24_data.py
python tools/parity/run_world24_simulation.py --movie tests/parity/movies/world-2-4-host-route.json --output local-parity/world24-route-host --require-clear --self-test
python tools/parity/run_gameplay_route.py --movie tests/parity/movies/world-2-4-host-route.json --output local-parity/world24-gameplay-route
```

## Original evidence and known failures

The 32-frame `world-2-4-entrance` diagnostic produced all 32 reference frames,
with identical continuous-video states and APU writes. It is supplemental.
The host full route **fails in the original**: missed late pit at about x1764,
then life lost at frame1063. It must not be labeled a successful original route.
Full comparison and a separate successful original route are being investigated.
No acceptance inventory, tolerances, or gate definitions were changed.
Original transition into 3-1 is unavailable in the host; worldComplete is bounded.
Actor allocation/RNG phase, Podoboo motion, firebars, Bowser and shared player
physics/render/audio still require strict per-frame comparison.

## Geometry extraction

`capture_world24_map.py` runs one forward ROM parser traversal. Page backloading
was rejected after a conflicting continuation at column48. Its collision-free
fixture is explicitly geometry extraction, never gameplay-route evidence.
The game loads only generated arrays and PNG assets; ROM/Mesen are offline.
`extract_world24.py` regenerates stage assets and references existing castle audio.
All graphical captures claim the shared GPU lock atomically and release only
the matching owner token. `.tools`, `roms` and reference source remain read-only.
