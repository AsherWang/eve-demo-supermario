# World 2-1 implementation plan

Updated 2026-10-28. The main-route runtime prototype and 1-4 to 2-1 transition
are implemented. Bonus destinations and strict whole-level acceptance remain pending.

## Verified offline data

- ROM SHA-256: `f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de`.
- `World2Areas[0]` selects area pointer `$28`.
- `L_GroundArea9`: CPU `$a7cd`, 101 bytes including header and terminator.
- `E_GroundArea9`: CPU `$9f51`, 43 bytes, including two three-byte area links.
- Main map: 212 columns, 13 metatile/collision rows per column. Flag column 200.
- Item inventory includes the hidden 1-UP, star, multi-coin brick and a vine
  brick at column 83 / screen row 5. The two raw links are `$fe,$2b,$20` and
  `$fe,$42,$20`; destination and return behavior still require runtime review.

Generated streams and map are in `scripts/generated/world21_data.nut` and
`scripts/generated/world21_map.nut`. Provenance and item locations are recorded
in `assets/world21/manifest.json` and `assets/world21/map-manifest.json`.
No ROM, emulator or save state is used by the game runtime.

## Rebuild

```powershell
python tools/extract_world21.py
python tools/parity/capture_world21_map.py
```

The map generator uses the verified ROM's RenderAreaGraphics callback. It
parses forward continuously, keeping the offline fixture player above terrain
after the normal entrance finishes. That fixture is for static data extraction,
not an input movie or gameplay evidence. It never changes map or parser RAM.

Checkpoint-only captures miss object continuations, including the question row
at columns 79..82. The active area is identified by its data base `$a7cf` rather
than AreaPointer: AreaPointer changes when a destination link is parsed even
while Mario remains in the main area. The final six columns beyond the scroll
lock are captured from the last checkpoint, with all six preceding columns
200..205 required to match the continuous capture before merging the tail.
The generator fails on missing columns or differing overlap, and records hashes.

## Runtime and acceptance work

- [x] Introduce explicit world/stage identity while keeping existing World 1
  loaders and regressions stable. Do not overload stage number 1 as World 1-1.
- [ ] Define a small level descriptor for map, enemy stream, item locations,
  entry, goal, checkpoint, music and palette. Keep mutable area state separate.
- [ ] Implement the 2-1 main route: enemies, pipes, group spawns, jumping green
  Paratroopas and jumpspring behavior. Reuse shared movement/collision rules.
- [ ] Implement vine growth/climbing, cloud-area return, underground-area
  return, and correct destination/return links. Do not substitute a mushroom
  for the vine reward or label inaccessible branches complete.
- [x] Connect 1-4 to 2-1 and preserve score, coins, lives and powers. Reset the
  area timer, HUD and music correctly; cover death and restart in World 2.
- [x] Extend reference/bootstrap and actual replay selection with world/stage
  fields. Existing World 1 movies retain their present meaning and hashes.
- [ ] Establish a fixed-input normal-entrance whole-route movie and separate
  branch movies; compare artifact/state/event/all images/APU/audio gates.
- [ ] Review route/branches and register evidence in the level inventory only
  after the corresponding acceptance requirements pass.

0.0.7 contains the World 1 fixes. It does not include playable World 2-1.

## Runtime verification record

The source prototype loads the verified map and enemy stream, including jumping
green Paratroopas, piranhas, a working spring and growing vine. F5 selects 2-1.
Vine climbing, cloud and underground destinations/returns remain unimplemented;
pipe entry is disabled for this stage rather than entering a World 1 bonus room.
2-2 is unavailable; R at the 2-1 settlement restarts 2-1.

- Ten simulation regression groups pass via `python tools/run_world1_regressions.py`.
  These include checkpoint/new-life reset and small/big/fire cross-world retention.
- `world-2-1-idle.json`: all 120 frames pass artifact, state, event, image,
  APU and detection-side audio gates. Reports: `local-parity/world21-runtime/reports/idle-final`.
- `world-2-1-main-host-route.json`: 3116 host frames reach settlement with
  three lives and no death. The same input fails in the ROM, with deaths at
  754, 1393 and 2018. First Y difference is frame 643 and first X difference
  frame 649. Reports: `local-parity/world21-runtime/reports/main-route`.
- The earlier `world-2-1-route-candidate.json` remains failed evidence in
  `local-parity/world21-runtime/reports/route`; it is not an acceptance movie.
- `world-1-4-to-world-2-1.json`: 2800 actual frames, no death, three lives,
  enters World 2-1 at frame 2496 and finishes in playing state with score 11150.
  Capture: `local-parity/world21-runtime/actual/world-transition`.

Next: resolve the first movement divergence, then complete branch destinations
and record same-input full-route six-gate acceptance. Opening gates and host
playability do not mark the level complete in the 32-level inventory.


## Data validation record

Repeated captures generated the same map SHA-256:
`5d48f7e51e7ebe0256d7baafdbbce65196ed418d4ae4c27851fa3b7f8ba3cbb2`.
Both metatile and collision arrays contain 212 complete 13-row columns.
Columns 79..82 retain the question-block continuation, and column 200 contains
the expected flagpole metatiles. The extraction tool rejects a wrong ROM hash
before writing outputs. Local validation is saved in
`local-parity/world21-data-check.json`; individual parser captures and tail
agreement are retained in `local-parity/world21-map-final`.
