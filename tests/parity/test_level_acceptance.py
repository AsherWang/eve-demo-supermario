from __future__ import annotations

import contextlib
import hashlib
import io
import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from tools.parity.level_acceptance import collect_acceptance, main


class LevelAcceptanceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.case_id = "world-1-1-route"
        self.inventory_path = self.root / "tests" / "parity" / "level_acceptance.json"

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _write_json(self, relative: str, value: object) -> Path:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
        return path

    def _write_inventory(
        self,
        *,
        required: list[str] | None = None,
        supplemental: list[str] | None = None,
        with_review: bool = True,
        route_sha: str | None = None,
        branch_sha: str | None = None,
        branches: list[str] | None = None,
        branch_reviewed: bool = True,
    ) -> None:
        required_cases = [self.case_id] if required is None else required
        branch_scope = ["secret"] if branches is None else branches
        levels = []
        for world in range(1, 9):
            for stage in range(1, 5):
                level_id = f"{world}-{stage}"
                target = level_id == "1-1"
                route_review = None
                branch_review = None
                if target and with_review and required_cases:
                    route_review = {
                        "case": required_cases[0],
                        "movie_sha256": route_sha,
                        "entrance_frame": 0,
                        "exit_frame": 2,
                        "endpoint_kind": "transition",
                        "reviewed_by": "test-reviewer",
                        "reviewed_at": "2026-10-24T00:00:00Z",
                        "evidence": "Reviewed full replay from entrance to transition.",
                    }
                if target and with_review and branch_reviewed and required_cases:
                    branch_review = {
                        "reviewed_by": "test-reviewer",
                        "reviewed_at": "2026-10-24T00:00:00Z",
                        "evidence": "Reviewed the complete branch scope for this movie.",
                        "branches": [
                            {
                                "id": name,
                                "case": required_cases[0],
                                "movie_sha256": branch_sha,
                                "frame": 1,
                                "evidence": f"Reviewed branch {name} and its outcome.",
                            }
                            for name in branch_scope
                        ],
                    }
                levels.append(
                    {
                        "id": level_id,
                        "world": world,
                        "stage": stage,
                        "required_cases": required_cases if target else [],
                        "supplemental_cases": (
                            supplemental if target and supplemental is not None else []
                        ),
                        "route_review": route_review,
                        "required_branches": branch_scope if target else [],
                        "branch_review": branch_review,
                    }
                )
        self._write_json(
            "tests/parity/level_acceptance.json",
            {"schema": "smb-level-acceptance-inventory-v1", "levels": levels},
        )

    def _frame_sha(self, frame: int) -> str:
        image = Image.new("RGB", (256, 240), (frame * 20, 40, 80))
        return hashlib.sha256(image.tobytes()).hexdigest()

    def _write_case_evidence(self, *, level_id: str = "1-1") -> str:
        movie_path = self._write_json(
            f"tests/parity/movies/{self.case_id}.json",
            {
                "schema": "smb-parity-movie-v1",
                "name": self.case_id,
                "level_id": level_id,
                "frames": 3,
                "inputs": [],
            },
        )
        movie_sha = hashlib.sha256(movie_path.read_bytes()).hexdigest()
        for side in ("reference", "actual"):
            frame_dir = self.root / "local-parity" / side / self.case_id / "frames"
            frame_dir.mkdir(parents=True, exist_ok=True)
            for frame in range(3):
                Image.new("RGB", (256, 240), (frame * 20, 40, 80)).save(
                    frame_dir / f"frame-{frame:06d}.png"
                )
        actual_dir = self.root / "local-parity" / "actual" / self.case_id
        actual_dir.mkdir(parents=True, exist_ok=True)
        (actual_dir / "state.jsonl").write_text(
            "".join(json.dumps({"frame": frame}) + "\n" for frame in range(3)),
            encoding="utf-8",
        )
        (actual_dir / "events.jsonl").write_text(
            json.dumps({"frame": 0, "sequence": 0}) + "\n", encoding="utf-8"
        )
        self._write_json(
            f"local-parity/reference/{self.case_id}/manifest.json",
            {
                "schema": "smb-parity-artifact-v1",
                "producer": "mesen-agent-reference",
                "created_utc": "2026-10-24T00:00:00Z",
                "rom_sha256": "a" * 64,
                "movie": self.case_id,
                "movie_sha256": movie_sha,
                "comparison_frames": 3,
                "capture_frames": [0, 1, 2],
                "exit_code": 0,
                "summary": {"event": "summary", "ok": True, "frames_executed": 3},
            },
        )
        self._write_json(
            f"local-parity/actual/{self.case_id}/manifest.json",
            {
                "schema": "smb-parity-artifact-v1",
                "producer": "evengine-remake",
                "created_utc": "2026-10-24T00:00:00Z",
                "movie": self.case_id,
                "movie_sha256": movie_sha,
                "comparison_frames": 3,
                "captured_frames": 3,
                "state_rows": 3,
                "event_rows": 1,
            },
        )
        checks = {
            gate: {"passed": True, "exit_code": 0}
            for gate in ("artifacts", "frames", "states", "events", "apu", "audio")
        }
        self._write_json(
            f"local-parity/reports/{self.case_id}/summary.json",
            {
                "schema": "smb-parity-case-summary-v1",
                "case": self.case_id,
                "passed": True,
                "checks": checks,
                "reports": {},
            },
        )
        self._write_json(
            f"local-parity/reports/{self.case_id}/artifact-report.json",
            {
                "schema": "smb-parity-artifact-validation-v1",
                "passed": True,
                "movie": self.case_id,
                "movie_sha256": movie_sha,
                "comparison_frames": 3,
                "capture_frames": [0, 1, 2],
                "checks": {
                    "reference_frames": {"missing": [], "extra": []},
                    "actual_frames": {"missing": [], "extra": []},
                    "actual_timeline": {"rows": 3, "invalid_rows": 0},
                    "actual_events": {"rows": 1, "invalid_rows": 0},
                },
                "errors": [],
            },
        )
        self._write_json(
            f"local-parity/reports/{self.case_id}/report.json",
            {
                "schema": "smb-parity-report-v1",
                "passed": True,
                "logical_size": [256, 240],
                "channel_tolerance": 0,
                "max_mismatched_pixels": 0,
                "compared_frames": 3,
                "failed_frames": 0,
                "missing_frames": 0,
                "frames": [
                    {
                        "frame": frame,
                        "status": "match",
                        "mismatched_pixels": 0,
                        "mismatch_ratio": 0.0,
                        "mean_absolute_channel_error": 0.0,
                        "max_channel_error": 0,
                        "reference_sha256": self._frame_sha(frame),
                        "actual_sha256": self._frame_sha(frame),
                    }
                    for frame in range(3)
                ],
            },
        )
        self._write_json(
            f"local-parity/reports/{self.case_id}/state-report.json",
            {
                "passed": True,
                "compared_frames": 3,
                "missing_frames": 0,
                "fields": [{"field": "player.x", "mismatch_frames": 0}],
            },
        )
        for gate in ("event", "apu", "audio"):
            self._write_json(
                f"local-parity/reports/{self.case_id}/{gate}-report.json",
                {"passed": True},
            )
        return movie_sha

    def _report(self) -> dict:
        return collect_acceptance(self.root, self.inventory_path)

    def test_complete_accepts_real_producer_shapes_and_ignores_samples(self) -> None:
        movie_sha = self._write_case_evidence()
        self._write_inventory(
            route_sha=movie_sha,
            branch_sha=movie_sha,
            supplemental=["short-diagnostic-with-no-artifacts"],
        )
        movie = json.loads(
            (self.root / "tests" / "parity" / "movies" / f"{self.case_id}.json").read_text()
        )
        self.assertNotIn("capture_frames", movie)
        actual_manifest = json.loads(
            (
                self.root / "local-parity" / "actual" / self.case_id / "manifest.json"
            ).read_text(encoding="utf-8")
        )
        self.assertNotIn("summary", actual_manifest)
        self.assertNotIn("exit_code", actual_manifest)
        self.assertNotIn("capture_frames", actual_manifest)
        report = self._report()
        self.assertEqual(report["summary"], {"total": 32, "complete": 1, "pending": 31})
        level = report["levels"][0]
        self.assertEqual(level["status"], "complete")
        self.assertEqual(level["supplemental_cases"], ["short-diagnostic-with-no-artifacts"])

    def test_checked_in_inventory_lists_all_levels_and_none_complete(self) -> None:
        repository = Path(__file__).resolve().parents[2]
        report = collect_acceptance(
            repository, repository / "tests" / "parity" / "level_acceptance.json"
        )
        self.assertEqual(report["summary"], {"total": 32, "complete": 0, "pending": 32})
        self.assertEqual(
            [level["id"] for level in report["levels"]],
            [f"{world}-{stage}" for world in range(1, 9) for stage in range(1, 5)],
        )

    def test_missing_movie_returns_reasons_without_unbound_frame_report(self) -> None:
        self._write_inventory(required=["missing-route"], supplemental=["short-diagnostic"])
        level = self._report()["levels"][0]
        self.assertEqual(level["status"], "pending")
        self.assertTrue(any("movie is missing" in reason for reason in level["reasons"]))

    def test_movie_level_id_mismatch_is_rejected(self) -> None:
        movie_sha = self._write_case_evidence(level_id="1-2")
        self._write_inventory(route_sha=movie_sha, branch_sha=movie_sha)
        reasons = self._report()["levels"][0]["reasons"]
        self.assertIn(f"case {self.case_id}: movie level_id must be 1-1", reasons)

    def test_stale_review_provenance_is_rejected(self) -> None:
        movie_sha = self._write_case_evidence()
        self._write_inventory(route_sha="f" * 64, branch_sha=movie_sha)
        reasons = self._report()["levels"][0]["reasons"]
        self.assertIn("route review provenance is stale for the current movie hash", reasons)

    def test_branch_review_provenance_is_bound_to_the_movie_hash(self) -> None:
        movie_sha = self._write_case_evidence()
        self._write_inventory(route_sha=movie_sha, branch_sha="f" * 64)
        reasons = self._report()["levels"][0]["reasons"]
        self.assertIn(
            "branch secret provenance is stale for the current movie hash", reasons
        )

    def test_actual_manifest_capture_count_mismatch_is_rejected(self) -> None:
        movie_sha = self._write_case_evidence()
        self._write_inventory(route_sha=movie_sha, branch_sha=movie_sha)
        path = self.root / "local-parity" / "actual" / self.case_id / "manifest.json"
        manifest = json.loads(path.read_text(encoding="utf-8"))
        manifest["captured_frames"] = 2
        path.write_text(json.dumps(manifest), encoding="utf-8")
        reasons = self._report()["levels"][0]["reasons"]
        self.assertIn(
            f"case {self.case_id}: actual manifest captured_frames does not match its frame files",
            reasons,
        )

    def test_stale_manifest_hash_is_rejected_even_when_summary_passes(self) -> None:
        movie_sha = self._write_case_evidence()
        self._write_inventory(route_sha=movie_sha, branch_sha=movie_sha)
        path = self.root / "local-parity" / "actual" / self.case_id / "manifest.json"
        manifest = json.loads(path.read_text(encoding="utf-8"))
        manifest["movie_sha256"] = "e" * 64
        path.write_text(json.dumps(manifest), encoding="utf-8")
        reasons = self._report()["levels"][0]["reasons"]
        self.assertIn(
            f"case {self.case_id}: actual manifest is stale for the current movie hash",
            reasons,
        )

    def test_malformed_evidence_fails_closed(self) -> None:
        movie_sha = self._write_case_evidence()
        self._write_inventory(route_sha=movie_sha, branch_sha=movie_sha)
        path = self.root / "local-parity" / "reference" / self.case_id / "manifest.json"
        path.write_text("{", encoding="utf-8")
        level = self._report()["levels"][0]
        self.assertEqual(level["status"], "pending")
        self.assertTrue(
            any("reference manifest cannot be read as JSON" in reason for reason in level["reasons"])
        )

    def test_frame_report_hash_must_match_real_images(self) -> None:
        movie_sha = self._write_case_evidence()
        self._write_inventory(route_sha=movie_sha, branch_sha=movie_sha)
        path = self.root / "local-parity" / "actual" / self.case_id / "frames" / "frame-000001.png"
        Image.new("RGB", (256, 240), (255, 255, 255)).save(path)
        reasons = self._report()["levels"][0]["reasons"]
        self.assertIn(
            f"case {self.case_id}: frame 1 actual hash does not match its image",
            reasons,
        )

    def test_sampled_required_frame_report_is_rejected(self) -> None:
        movie_sha = self._write_case_evidence()
        self._write_inventory(route_sha=movie_sha, branch_sha=movie_sha)
        path = self.root / "local-parity" / "reports" / self.case_id / "report.json"
        report = json.loads(path.read_text(encoding="utf-8"))
        report["frames"] = [report["frames"][0], report["frames"][2]]
        path.write_text(json.dumps(report), encoding="utf-8")
        reasons = self._report()["levels"][0]["reasons"]
        self.assertTrue(any("must contain each frame" in reason for reason in reasons))

    def test_extra_malformed_frame_row_is_rejected_without_crashing(self) -> None:
        movie_sha = self._write_case_evidence()
        self._write_inventory(route_sha=movie_sha, branch_sha=movie_sha)
        path = self.root / "local-parity" / "reports" / self.case_id / "report.json"
        report = json.loads(path.read_text(encoding="utf-8"))
        report["frames"].append(None)
        path.write_text(json.dumps(report), encoding="utf-8")
        level = self._report()["levels"][0]
        self.assertEqual(level["status"], "pending")
        self.assertTrue(any("must contain each frame" in reason for reason in level["reasons"]))

    def test_explicit_zero_branch_review_is_distinct_from_missing_matrix(self) -> None:
        movie_sha = self._write_case_evidence()
        self._write_inventory(route_sha=movie_sha, branch_sha=movie_sha, branches=[])
        self.assertEqual(self._report()["levels"][0]["status"], "complete")

        inventory = json.loads(self.inventory_path.read_text(encoding="utf-8"))
        inventory["levels"][0]["required_branches"] = None
        self.inventory_path.write_text(json.dumps(inventory), encoding="utf-8")
        reasons = self._report()["levels"][0]["reasons"]
        self.assertIn("branch coverage matrix has not been inventoried", reasons)

    def test_cli_exposes_json_markdown_and_pending_gate(self) -> None:
        self._write_inventory(required=[], supplemental=["diagnostic-sampled"])
        json_output = io.StringIO()
        with contextlib.redirect_stdout(json_output):
            self.assertEqual(main(["--root", str(self.root), "--format", "json"]), 0)
        self.assertEqual(json.loads(json_output.getvalue())["summary"]["pending"], 32)

        markdown_output = io.StringIO()
        with contextlib.redirect_stdout(markdown_output):
            self.assertEqual(main(["--root", str(self.root), "--format", "markdown"]), 0)
        self.assertIn("| 8-4 | pending |", markdown_output.getvalue())

        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(
                main(["--root", str(self.root), "--format", "json", "--fail-on-pending"]),
                1,
            )


if __name__ == "__main__":
    unittest.main()
