# World 2-3 bridge course

Playable implementation and fixed normal-entry route are complete. Strict acceptance remains pending: the same fixed route fails in the original ROM.

## Shared integration contract

- Increase `TILE_STRIDE` from 214 to at least 244: the ROM bridge course flag is at column 225.
- Load `scripts/world23.nut`, which loads its own generated data/map, and call `loadWorld23Assets`.
- Register `{world=2,stage=3,load=function(g){startWorld23(g);}}` in `LEVEL_DATA`.
- Dispatch `isWorld23(g)` to `drawWorld23Background`, `world23TileTexture`, `updateWorld23Actors`, `drawWorld23Actors`, and `updateWorld23DeathReload`.
- Guard World 1-3-specific actor/tile hooks with `g.world==1`; generic flag settlement remains shared.
- Transition 2-2 completion to 2-3 and 2-3 completion to 2-4 when the latter is registered.
- World 2-3 checkpoint is page 7, from World 2's `$65,$70` halfway-page table.

Stage-owned files only will be committed. Any temporary shared hooks used for verification will be listed separately.

## Current validation

`tests/parity/movies/world-2-3-normal-clear.json` has 2243 frames and SHA-256
`aa7309e39b10819f04bb558ca76a35c30adbf0737829674942f65cb74d610a19`.
The parent normal-entry runner passes with three lives, no death, and natural
`levelComplete` at frame 2213 (runner includes initial state as frame 0).
The local baseline lacks registered 2-4, so next-stage transition awaits parent integration.
No route-time position, immunity, enemy, or tile patches are used.

Original continuous-boot replay starts at detected frame 67 and produces all
2243 state rows. It fails this movie: furthest X=1722, minimum lives=1, no flag
or next-stage transition. This is a failed comparison, not acceptance evidence.
The seven sampled reference PNGs are diagnostic only; all-frame rendering,
event/APU/device-audio comparison and reviewer records remain outstanding.

Map extraction uses a separate explicitly manipulated offline parser fixture;
that fixture is NOT counted as gameplay. Map manifest records hashes and the
verified continuation overlap. The runtime contains no emulator dependency.
