# Whole-level acceptance inventory

`tools/parity/level_acceptance.py` reports whether each World 1-8 stage 1-4 has
enough local evidence for a whole-level acceptance claim. It never runs the
runtime and does not treat a case name, movie description, or passing summary as
proof of gameplay semantics.

The checked-in inventory at `tests/parity/level_acceptance.json` lists all 32
levels. It currently has no required acceptance movies, reviewed
entrance-to-transition or final-ending records, or reviewed branch matrices, so
every level remains pending. Existing short diagnostics are supplemental and do
not block a level once a full route is designated.

## Commands

```powershell
# Human-readable status
python tools\parity\level_acceptance.py --format markdown

# Machine-readable status
python tools\parity\level_acceptance.py --format json

# Write a report under ignored local-parity data
python tools\parity\level_acceptance.py `
  --format markdown `
  --output local-parity\reports\level-acceptance.md

# Use as an eventual strict gate
python tools\parity\level_acceptance.py --fail-on-pending
```

The command exits 0 after producing a valid report even when levels are pending.
`--fail-on-pending` changes the exit code to 1 after reporting, which lets CI
adopt it once complete-level evidence exists. Invalid inventory structure exits
2.

## Completion gates

A level is complete only when all of these checks pass:

1. Every `required_cases` movie is current and declares `"level_id"` equal to
   the inventory level id. A missing `capture_frames` in the movie means the
   full range `0..movie.frames-1`, matching `common.load_movie`.
2. Reference and actual manifests contain the SHA-256 of the current movie file
   and the current comparison frame count. The producer-specific fields are
   checked separately: reference manifests use `capture_frames`, `summary`, and
   `exit_code`; actual manifests use `captured_frames`, `state_rows`, and
   `event_rows`, which must match the actual frames and JSONL files.
3. The case summary reports all six gates and each detailed gate report passes:
   artifacts, frames, states, events, APU writes, and audio.
4. The frame report covers the exact sequence `range(movie.frames)` once, in
   ascending order, with `channel_tolerance == 0`, `max_mismatched_pixels == 0`,
   zero failed or missing frames, and every per-frame row marked as a match. Both
   sides must have the complete PNG set, and the report's normalized image hashes
   must match the real frame files.
5. A reviewer records the route case, entrance frame, and transition or final
   ending frame. The route case must be required by the level, pass all case
   evidence checks, and include the current movie SHA-256. Stages 1-3 and Worlds
   1-7 stage 4 use `transition`; World 8-4 uses `final-ending`.
6. The reviewer inventories the branch matrix and records an evidence description
   even when the reviewed result is zero branches. Each listed branch uses a
   required, fully passing case, a valid frame, and its current movie SHA-256.

A sampled required frame report or a passing `summary.json` by itself does not
satisfy these gates. Supplemental diagnostics are reported separately and do not
affect completion. Missing or stale evidence is listed in the JSON report and in
the reasons column of the Markdown report.

## Evidence records

Each inventory level supports these review fields:

```json
{
  "id": "1-1",
  "world": 1,
  "stage": 1,
  "required_cases": ["world-1-1-review"],
  "supplemental_cases": ["short-diagnostic"],
  "route_review": {
    "case": "world-1-1-review",
    "movie_sha256": "sha256-of-tests/parity/movies/world-1-1-review.json",
    "entrance_frame": 0,
    "exit_frame": 1800,
    "endpoint_kind": "transition",
    "reviewed_by": "reviewer-name",
    "reviewed_at": "2026-10-24T00:00:00Z",
    "evidence": "Describe the observed entrance and transition sequence."
  },
  "required_branches": ["warp-zone"],
  "branch_review": {
    "reviewed_by": "reviewer-name",
    "reviewed_at": "2026-10-24T00:00:00Z",
    "evidence": "Reviewed the complete branch scope for this movie.",
    "branches": [
      {
        "id": "warp-zone",
        "case": "world-1-1-review",
        "movie_sha256": "sha256-of-tests/parity/movies/world-1-1-review.json",
        "frame": 900,
        "evidence": "Describe the observed branch and resulting transition."
      }
    ]
  }
}
```

`capture_frames` is optional in the movie fixture. When it is present, it must
list every comparison frame for a required acceptance case. The two producers
have different manifest shapes; do not add reference-only run fields to actual
manifests.

`required_branches` is the reviewed scope for the level. The branch review must
match that scope exactly. A `null` matrix means branch coverage has not been
inventoried. An explicitly reviewed `[]` matrix is valid for a branchless level
when the branch review has reviewer, time, and evidence fields. Extra unlisted
branches are rejected so the scope and evidence stay aligned.

Route and branch review records include the movie SHA-256 they covered. Editing a
movie invalidates both its review provenance and its artifact manifests until
the evidence and review are rerun.

## Evidence limitation

This tool validates the presence and consistency of machine evidence plus the
shape of human review records. It cannot establish from metadata that a movie
actually begins at the intended level entrance, follows the claimed gameplay
route, triggers every required branch, or reaches the claimed transition or
ending. Those claims require a reviewer to inspect the replay and record the
specific route cases and frames. Until that review exists, the level stays
pending even if every automated gate passes.
