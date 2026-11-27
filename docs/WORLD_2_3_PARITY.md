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

Still missing: a common successful normal-entry original/remake movie, exact
death/reload phase and RNG continuity, every-frame pixel equality, complete
actor/OAM serialization in shared parity output, event/APU/device-audio gates,
and the route/branch review records. Seven reference screenshots were sampled;
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
