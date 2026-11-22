"""Tests for .claude/hooks/status-footer.py (F329, Sprint 85; R-2).

The byte-for-byte comparison with the PowerShell original was run once, on the same inputs, before the original
was deleted (progress folder footer_proof_output.txt; recorded in the sprint plan). These tests keep the
expected strings of that comparison, so the output cannot drift later.

What these tests do NOT catch: the footer the user actually sees comes from the USER-level script in
C:\\Users\\<user>\\.claude\\scripts, which this repo does not own; a locale effect (the clock is built by hand,
and one test sets a non-English locale where the machine allows it); a status string form nobody has written yet.
Run: python -I -m unittest discover -s .claude/hooks/tests -v
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import locale
import os
import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest import mock

HOOKS = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("status_footer", HOOKS / "status-footer.py")
sf = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sf)

NOON_PLUS = datetime(2026, 9, 19, 13, 5)
NAME_MISSING = "[name missing -- start sprint_status.json status with 'Phase n.n <Name>']"


class ClockTests(unittest.TestCase):
    def test_twelve_hour_clock_edges(self):
        cases = {
            datetime(2026, 9, 19, 0, 5): "09/19/2026 12:05am",
            datetime(2026, 9, 19, 1, 15): "09/19/2026 1:15am",
            datetime(2026, 9, 19, 11, 59): "09/19/2026 11:59am",
            datetime(2026, 9, 19, 12, 0): "09/19/2026 12:00pm",
            datetime(2026, 1, 5, 13, 5): "01/05/2026 1:05pm",
            datetime(2026, 12, 31, 23, 59): "12/31/2026 11:59pm",
        }
        for moment, expected in cases.items():
            self.assertEqual(sf.clock_text(moment), expected)

    def test_clock_does_not_follow_the_locale(self):
        saved = locale.setlocale(locale.LC_ALL)
        self.addCleanup(locale.setlocale, locale.LC_ALL, saved)
        for name in ("de_DE.UTF-8", "German_Germany.1252", "tr_TR.UTF-8", "Turkish_Turkey.1254"):
            try:
                locale.setlocale(locale.LC_ALL, name)
            except locale.Error:
                continue
            self.assertEqual(sf.clock_text(NOON_PLUS), "09/19/2026 1:05pm", name)


class PhaseTests(unittest.TestCase):
    def test_phase_parsing(self):
        cases = {
            "Sprint 70 Phase 5.3 MANUAL VALIDATION -- awaiting Harold": "5.3 Manual Validation",
            "Phase 4 Execution (task 3 of 10)": "4 Execution",
            "Sprint 79 Phase 7 Sprint Review. Done": "7 Sprint Review",
            "Phase 6 PR 2 READY": "6 Pr 2 Ready",
            "Sprint 78 phase 3.7 plan approval pending": "3.7 plan approval pending",
            "  Phase 8.1 RELEASE CYCLE (develop merge)": "8.1 Release Cycle",
            "Phase 7.7 -- PR draft": "7.7 " + NAME_MISSING,
            "Phase 5.3": "5.3 " + NAME_MISSING,
            "Retrospective in progress": "unknown [start sprint_status.json status with 'Phase n.n <Name>']",
            "prose about Phase 5.3 Manual Validation later": "unknown [start sprint_status.json status with 'Phase n.n <Name>']",
        }
        for status, expected in cases.items():
            self.assertEqual(sf.phase_from_status(status), expected, status)

    def test_title_case_uses_ascii_rules_and_keeps_digits(self):
        self.assertEqual(sf.title_case("manual validation 2"), "Manual Validation 2")
        self.assertEqual(sf.title_case("5th gate"), "5th Gate")  # a word that starts with a digit keeps its letters


class FooterTests(unittest.TestCase):
    def project(self, status: object, number: object = 70) -> Path:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        (root / ".claude").mkdir()
        (root / ".claude" / "sprint_status.json").write_text(
            json.dumps({"current_sprint": {"number": number, "status": status}}), encoding="utf-8")
        return root

    def test_full_footer_from_the_status_file(self):
        root = self.project("Sprint 70 Phase 5.3 MANUAL VALIDATION -- x")
        self.assertEqual(sf.build_footer(root, NOON_PLUS), "09/19/2026 1:05pm | Sprint 70 Phase 5.3 Manual Validation")

    def test_overrides_win_and_a_single_override_leaves_the_other_to_the_file(self):
        root = self.project("Phase 5.3 Manual Validation")
        self.assertEqual(sf.build_footer(root, NOON_PLUS, "7.5 Sprint Retrospective", "99"),
                         "09/19/2026 1:05pm | Sprint 99 Phase 7.5 Sprint Retrospective")
        self.assertEqual(sf.build_footer(root, NOON_PLUS, phase="2.1 X"), "09/19/2026 1:05pm | Sprint 70 Phase 2.1 X")
        self.assertEqual(sf.build_footer(root, NOON_PLUS, sprint="12"),
                         "09/19/2026 1:05pm | Sprint 12 Phase 5.3 Manual Validation")

    def test_unusable_status_files_still_give_a_footer(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        unknown = "09/19/2026 1:05pm | phase unknown -- check .claude/sprint_status.json"
        self.assertEqual(sf.build_footer(root, NOON_PLUS), unknown, "no status file")
        (root / ".claude").mkdir()
        status = root / ".claude" / "sprint_status.json"
        for body in (b"{not json", b"[]", b'{"current_sprint": null}', b'{"current_sprint": "text"}', b""):
            status.write_bytes(body)
            self.assertEqual(sf.build_footer(root, NOON_PLUS), unknown, body)

    def test_bom_and_zero_number(self):
        root = self.project("Phase 5.3 Manual Validation")
        status = root / ".claude" / "sprint_status.json"
        status.write_bytes(b"\xef\xbb\xbf" + status.read_bytes())
        self.assertIn("Sprint 70 Phase 5.3", sf.build_footer(root, NOON_PLUS))
        zero = self.project("Phase 1.1 Refinement", number=0)
        self.assertEqual(sf.build_footer(zero, NOON_PLUS), "09/19/2026 1:05pm | Phase 1.1 Refinement")


class RootTests(unittest.TestCase):
    def test_project_dir_env_wins_even_without_a_status_file(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, {"CLAUDE_PROJECT_DIR": tmp}):
            self.assertEqual(sf.repo_root(Path.cwd()), Path(tmp))

    def test_walk_up_from_the_working_folder_finds_the_status_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / ".claude").mkdir()
            (root / ".claude" / "sprint_status.json").write_text("{}", encoding="utf-8")
            deep = root / "a" / "b"
            deep.mkdir(parents=True)
            with mock.patch.dict(os.environ):
                os.environ.pop("CLAUDE_PROJECT_DIR", None)
                self.assertEqual(sf.repo_root(deep), root)

    def test_falls_back_to_this_repo_when_nothing_is_found(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ):
            os.environ.pop("CLAUDE_PROJECT_DIR", None)
            self.assertEqual(sf.repo_root(Path(tmp)), HOOKS.parent.parent)


class CommandLineTests(unittest.TestCase):
    def test_main_prints_one_line_ending_with_a_newline(self):
        out = io.StringIO()
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, {"CLAUDE_PROJECT_DIR": tmp}), \
                contextlib.redirect_stdout(out):
            self.assertEqual(sf.main(["--phase", "7.5 Sprint Retrospective", "--sprint", "99"]), 0)
        line = out.getvalue()
        self.assertTrue(line.endswith(" | Sprint 99 Phase 7.5 Sprint Retrospective\n"), line)
        self.assertEqual(len(line.splitlines()), 1)

    def test_the_clock_is_read_each_run_not_carried_forward(self):
        with mock.patch.object(sf, "datetime") as fake, tempfile.TemporaryDirectory() as tmp, \
                mock.patch.dict(os.environ, {"CLAUDE_PROJECT_DIR": tmp}):
            fake.now.return_value = datetime(2030, 2, 3, 4, 9)
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                sf.main(["--phase", "1.1 X", "--sprint", "1"])
        self.assertTrue(out.getvalue().startswith("02/03/2030 4:09am | "), out.getvalue())


if __name__ == "__main__":
    unittest.main()
