# World 2-3 diagnostic status

Strict whole-level acceptance is **not achieved**. Normal-entry gameplay succeeds,
and the parent has independently confirmed the 2-3 to 2-4 transition without deaths.

The committed LF movie `world-2-3-normal-clear.json` has 2243 frames and SHA-256
`df405fd199ea8cdeca7e9017480648e8fbd772bbbb1a668d9c73abe767ce1d84`.
Earlier local capture used the byte-equivalent CRLF movie, whose SHA-256 was
`aa7309e39b10819f04bb558ca76a35c30adbf0737829674942f65cb74d610a19`.
Those old manifests are not current strict-gate evidence. The isolated motion
fixture explicitly retains both hashes and the capture's CRLF provenance.

## Verified stage behavior

- 244 columns extracted from the original forward parser, with verified tail.
- Original bridge collisions, coins, power-up block, flag and castle settlement.
- Secondary-hard-mode commands consume parser passes even when no enemy spawns.
- The `$0f,$8a` enemy pair has its page bit set; it is an original green Cheep at
  row `$f`, not an absolute page-select instruction. This actor has its own ID,
  palette and movement; it is not disguised as a flying fish or World 1-3 enemy.
- Flying fish remain alive horizontally offscreen until their vertical erasure.
- Slot X fractions and Y dummy registers survive reuse. A final horizontal step
  occurs before the vertical helper erases an actor below the screen.
- Page-7 checkpoint at camera X=1792; persistent score, coins and lives retained.
- 2727 exact horizontal/vertical ROM register pairs and 18 spawn tuples pass.
- Normal fixed route still completes with three lives after these corrections.

## Successful original comparison route

`world-2-3-original-clear-candidate.json` is independently verified despite its
historical candidate name. Its 2132-frame LF movie SHA-256 is
`701e38be5635173e6e88807121dbd738721488949d8bb69cf562a4fcc56a7f50`.
The original reaches flag contact at frame 1563 and transitions to 2-4 at frame
2103 with all three lives. The remake with the captured-reference entrance
initializer reaches the same flag frame and natural settlement at frame 2101.
Every compared semantic field matches for frames 0..2101. The full state gate
still fails at the subsequent shared transition in this pre-integration baseline.

All five fish slots, including identity and ten movement/state fields, match for
all 2132 frames: 10660 slot snapshots, 2942 active snapshots, zero mismatches.
The end-of-stream sixth-slot frenzy timer side effect was required for this.
`tests/fixtures/world23_route_evidence.json` preserves the reports and trace hashes.
This route uses fixed inputs after the entrance initializer, with no teleports,
invulnerability, state injections, or altered collisions during play.

The ordinary runtime and captured ROM entrance have different RNG/frame phases.
Keep `world-2-3-normal-clear.json` for normal `startLevel` gameplay; use the new
movie and `initializeWorld23Parity` for reference-origin comparisons.

## Origin comparison and remaining failures

`initializeWorld23Parity(g)` is a test-origin initializer only. It sets the
captured frame-counter phase, interval timer and RNG bytes before replay begins.
Do not invoke it mid-route or for ordinary `startLevel` gameplay. The standard
parity adapter performs its usual frame-zero increment after this initializer.

With that origin and the failed-original movie, player motion and all three
flying-fish slots match through the lethal contact at comparison frame 776.
Player X first diverges at frame 1010; Y first diverges at frame 985, during
death/reload. The original movie's maximum X is 1722 and it loses two lives.
Matching a failed route is a useful diagnostic, not whole-level acceptance.

Still missing: exact next-stage/death/reload phases and campaign RNG continuity,
every-frame pixel equality, complete
actor/OAM serialization in shared parity output, event/APU/device-audio gates,
and the route/branch review records. Only selected reference screenshots were sampled;
they cannot satisfy the all-frame gate. No acceptance thresholds were changed.

## Reproduce

```powershell
python -m unittest discover -s tests/parity -p test_world23_data.py
python tools/run_world23_regressions.py --output local-parity/world23-regressions
python tools/parity/run_world23_simulation.py --movie tests/parity/movies/world-2-3-normal-clear.json --output local-parity/world23-route
python tools/parity/run_world23_simulation.py --movie tests/parity/movies/world-2-3-normal-clear.json --output local-parity/world23-origin --reference-origin
python tools/parity/run_world23_reference.py --movie tests/parity/movies/world-2-3-normal-clear.json --output local-parity/world23-reference
```

The reference tool locks `<git-common-dir>/../local-parity/gpu-capture.lock`;
`SMB_GPU_CAPTURE_LOCK` can override it. It removes only its own token-bearing lock.
The CPU adapter supplies dispatch hooks for the pre-integration base and never
patches player, actor or terrain state during the route. Parent owns production
shared integration and the independent gameplay runner.

## Follow-up after shared pipeline integration

CPU replay on integrated main still agrees through frame 2101; frame 2102
incorrectly loads 2-4 immediately. ROM final physics remains in 2-3 on 2102,
selects 2-4 on 2103, clears scroll/fractions on 2104, initializes on 2105.
The parent owns staged shared transition and serializer corrections.

Defeated fish now select ROM base animation and vertical flip: the blank top
row stays in place while the bottom two tile rows swap and flip. Generated
assets retain both original palettes and horizontal directions. Presentation
uses the same prepared/display delay as live fish; motion remains unchanged.
This source-derived correction is not yet an all-frame visual acceptance claim.

The 2132-frame parent baseline (`world-2-3-strict-full`, movie SHA
`7bbf4305b111c50c4f6c68f83ab90972aa6f73ad035b01de2e2c1a2aea347635`)
has 267 image mismatches: 238 before frame 2102 and 29 during loading.
Fish now register six native OAM cells and use whole-cell edge clipping plus
shuffled OAM offsets. Parent must enable the shared collect/mask render path
for World 2-3. Two local capture attempts failed before replay with Vulkan
`vkEnumerateInstanceExtensionProperties returned VK_INCOMPLETE(5)`; neither
is visual validation evidence.

The raw origin interval divider is 1 (both captured traces), corrected from 0.
Death reload now clears scroll/fractions on pass 2, initializes area on pass 3,
keeps RNG across area reset, advances it through loading, and uses the live
21-frame divider for the seven-tick lives screen. Shared requirements:
- Include World 2-3 in the sprite-Y>=768 death-exit condition.
- Freeze both timer banks during death and reload passes 0/2, as for World 2-1.
- Serialize death-load mode boundary using world23.lifeScreenEnd+16.
CPU diagnostics with temporary shared hooks match first death exit at 1007,
life loss 1008, initialization 1010, entrance 1177, control 1178. Second-life
contact still diverges at 1659; shared power-up differences begin at 742 and
an extra coin appears during death at 837. These are unresolved, not passes.
