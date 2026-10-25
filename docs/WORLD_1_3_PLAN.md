# World 1-3 implementation and acceptance plan

World 1-3 is loaded from verified ROM data as an offline build step. Runtime
play does not read the ROM or invoke Mesen. The accepted source ROM is
`roms/Super Mario Bros. (World).nes`, SHA-256
`f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de`.

## Source data

World 1 uses area pointer `$26`, area number `3`, and level number `2`.
`tools/extract_world13.py` locates the unique `L_GroundArea7` and
`E_GroundArea7` signatures and writes `scripts/generated/world13_data.nut`:

- area stream: CPU `$A6F3`, 85 bytes, SHA-256
  `8a46985bdc1d8db9e65bd064bc42fa7193301c00e8c038e97604a98014459e1e`
- enemy stream: CPU `$9F1F`, 29 bytes, SHA-256
  `01a58d4eea02b0e20c30659a75ea14a4278f4f24925e97183eb6c53a68929f4f`

`tools/parity/capture_world13_map.py` follows the ROM area parser at CPU
`$88AE` and captures the 160-by-13 metatile and collision buffers into
`scripts/generated/world13_map.nut`. The renderer and collision map therefore
share the same ROM identity. Two inherited tree-ledge columns at 80 and 81
cannot be reconstructed by loading page 5 directly; the forward page-4 parse
owns them. The capture manifest records these two continuation conflicts.

The generated map is SHA-256
`6726a96e34e81a7408d752fc7f9d658bde3bf3abbd125f2512240387757c8445`.
The extractor also writes 120 exact PNGs under `assets/world13/`: all ROM
overworld metatiles, six question-mark color rotations, the 48-by-8 platform,
Bullet Bill, and red Koopa, Paratroopa, and shell frames. The red enemies use
the shared Koopa/Paratroopa graphics indices 2/3 and 4/5 with sprite palette
entry 2; the shell uses indices 17/18 with the shell-specific OAM flips.
`assets/world13/manifest.json` records source addresses, palette bytes, and
stream hashes.

Rebuild and compare:

```powershell
python tools\extract_world13.py
python tools\parity\capture_world13_map.py
git diff --exit-code -- scripts/generated/world13_data.nut `
  scripts/generated/world13_map.nut assets/world13
```

## Runtime behavior

`startWorld13(g)` enters the main area at canonical X=40, Y=176 with frame
counter `$1a` (decimal 26), time 300, timer control 23, interval control 0,
color offset 1, and zero VRAM parser task/control. Normal stage entry preserves
score, coins, lives, big, and fire. `initializeWorld13Parity(g)` starts small
Mario for fixed-origin comparison while retaining the same canonical entrance.

The enemy stream produces eight active normal-mode objects: three Goombas and
five red Koopas, including two red Paratroopas. The two `$17` frenzy entries
carry the secondary-hard-mode bit and are not instantiated in a normal game.
Red Koopas retain the shared ledge-aware movement. Red Paratroopas do not walk:
they remain at their spawn X and use `ProcMoveRedPTroopa`/`ImposeGravity` with
the original byte-sized vertical speed, force, and dummy accumulators.

`world13EnemyTexture(g,e,visualState)` returns the exact red walking, winged,
and shell texture and returns null for normal enemies. Shared `drawEnemy`
should substitute that texture while retaining its existing positioning,
clipping, upside-down shell, and course-clear branches. A first stomp calls
`demoteWorld13Paratroopa(g,e)` before `enterKoopaShell`. A successful demotion
changes the ID to red Koopa `$03`, clears vertical state, faces Mario, and
resumes ordinary walking at `$08/$f8`; it must not enter shell state. Later
stomps of that red Koopa use the shared shell behavior.

The four platforms are decoded from `$25` and `$28` objects. The `$25` platform
uses `InitVertPlatform` plus `YMovingPlatform` and `ImposeGravity`; the three
`$28` platforms use the primary/secondary counter cycle and 1/16-pixel stepping
from `XMoveCntr_Platform` and `MoveWithXMCntrs`. The platform rider logic moves
Mario with the platform's actual pixel delta.

The ROM goal is at column 152 and the castle at column 155. World 1-3 sets
`flagX` and `castleX` for the shared flag, castle, course-clear, time-bonus, and
1-4 transition routines. The dedicated tile hook draws decorative metatiles
(including empty collision cells), defers the flag/castle artwork to the shared
renderer, and uses the decoded question-mark palette rotations.

## Parent integration contract

Load `scripts/generated/world13_data.nut`, `scripts/generated/world13_map.nut`,
and `scripts/world13.nut`. Call `loadWorld13Assets()` after shared assets load,
include `runWorld13SelfTest()` in startup tests, route stage 3 through
`startWorld13(g)`, and call `initializeWorld13Parity(g)` after entering the
stage for a level-3 parity movie. Shared rendering calls
`world13TileTexture(g,tx,ty,tile)` for every tile including `TILE_EMPTY`,
`drawWorld13Background(g)`, and `drawWorld13Actors(g,behind)` on both sides of
the tile pass. Shared simulation calls `updateWorld13Actors(g)` after
`updateGoombas(g,dt)`.

The red-enemy renderer hook belongs near the start of `drawEnemy`, after it has
computed `visualState` but before the shared branch picks a green texture.
Only the texture is replaced. Before a walking Koopa calls `enterKoopaShell`,
shared collision code should call `demoteWorld13Paratroopa(g,e)`; when it
returns true, award the source 400-point demotion result and follow the normal
stomp bounce path without entering the shell.

## Current evidence

Native data, entry, actor-count, hard-mode filtering, red texture selection,
Paratroopa 8.8 motion and first-stomp demotion, platform motion, rider,
decorative tile hook, shared red-Koopa shell behavior, and goal geometry checks
run in

```powershell
& 'D:/workspace/eve-demos/super-mario/.tools/evengine/eve-sdk/win32/bin/eve.exe' `
  run --no-window -r local-parity/world13-smoke/main.nut .
```

The result is `WORLD13_SELFTEST_OK`.

Against the parent ROM origin for World 1-3 idle, 120-frame state comparison
passes with the strict state comparison tool. Rendered frame 119 is identical
at channel tolerance zero. Rendered frame 0 currently differs in 143 pixels:
the shared renderer draws Mario, while the ROM origin frame has not transferred
that sprite to the visible frame. The shared render already suppresses Mario on
the level-1 parity origin frame; the corresponding integration needs to cover
the World 1-3 origin frame.

```powershell
python tools\parity\compare_states.py `
  --reference 'D:/workspace/eve-demos/super-mario/local-parity/reference/world-1-3-idle/state.jsonl' `
  --actual local-parity/world13-actual-idle-local/state.jsonl `
  --output local-parity/world13-idle-check-report
python tools\parity\compare_frames.py `
  --reference 'D:/workspace/eve-demos/super-mario/local-parity/reference/world-1-3-idle/frames' `
  --actual local-parity/world13-actual-idle-local/frames `
  --output local-parity/world13-idle-frame-report
```

## Acceptance status

World 1-3 is not yet marked strictly complete. A checked-in, fixed-input
whole-level movie from entrance through the flag/castle transition is still
required, followed by zero-tolerance artifact, every-frame image, state, event,
APU-write, and audio checks. The route must also exercise and review the moving
platforms and red Koopa/Paratroopa interactions. The frame-0 Mario presentation
gap must be closed by the shared parity render hook. Full-route evidence and
remaining actor-art differences will be recorded rather than waived.
