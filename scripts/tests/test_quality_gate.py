"""Tests for scripts/quality-gate.py (F344, Sprint 86).

Every run uses a FAKE flutter (scripts/tests/fake_flutter.py); no test starts the real SDK. The fake prints the
same text for every call, so end-to-end runs use --skip-tests or --skip-analyze to give each step its own output.

Run: python -I -m unittest discover -s scripts/tests -p "test_quality_gate*.py" -v

Test list and what each does NOT catch:
  test_analyze_clean_passes: "No issues found!" with exit 0 -> PASS. NOT caught: analyzer text in a new wording
      (that is the no-summary FAIL below, by design).
  test_analyze_issues_fail: "3 issues found." -> FAIL naming 3. NOT caught: an info-level issue the team accepts
      (the prompts say 0 issues, so it fails).
  test_analyze_with_no_summary_fails: a crash with no summary line is a FAIL, never a pass.
  test_tests_pass_needs_a_summary_and_a_pass: all-passed summary -> PASS. NOT caught: a skipped-only suite
      (passed 0 fails by design; a suite of only skips would need a new rule).
  test_tests_with_no_summary_fail: REAL FAILING INPUT (AC-2): flutter prints a compile error and no summary.
      Must exit 1 with "no summary line" visible, never report 0 failures.
  test_failed_tests_exit_one: "+4 -1" -> exit 1 and RESULT: FAIL (tests).
  test_flutter_missing_exits_two: REAL FAILING INPUT (AC-2): flutter not on PATH -> exit 2 and a stderr message.
  test_both_steps_skipped_exits_two: nothing would be checked -> exit 2.
  test_failed_summary_with_exit_zero_fails: a "-1" count fails the step on its own, exit code aside.
  test_test_file_runs_one_file: --test-file runs `flutter test <file>`. NOT caught: a file that does not exist
      (flutter itself reports it; the gate trusts the summary).
  test_both_steps_run_in_order_and_log_is_full: analyze then test, both in the log.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import fake_flutter  # noqa: E402

TOOL = HERE.parent / "quality-gate.py"
_spec = importlib.util.spec_from_file_location("quality_gate_mod", TOOL)
gate = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(gate)

CLEAN = "Analyzing mobile-app...\nNo issues found! (ran in 4.1s)\n"
ALL_PASS = "00:01 +5: All tests passed!\n"


class GateCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        fake_flutter.install(self.tmp / "bin")
        self.calls = self.tmp / "calls.jsonl"
        self.log = self.tmp / "gate.log"
        env = {"PATH": str(self.tmp / "bin") + os.pathsep + os.environ.get("PATH", ""),
               "FAKE_FLUTTER_CALLS": str(self.calls), "FAKE_FLUTTER_OUT": ALL_PASS, "FAKE_FLUTTER_RC": "0"}
        self._env = mock.patch.dict(os.environ, env)
        self._env.start()

    def tearDown(self) -> None:
        self._env.stop()
        self._tmp.cleanup()

    def run_main(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = gate.main([*argv, "--log", str(self.log)])
        return code, out.getvalue(), err.getvalue()

    def argvs(self) -> list:
        return [call["argv"] for call in fake_flutter.read_calls(self.calls)]


class AnalyzeTests(GateCase):
    def test_analyze_clean_passes(self) -> None:
        with mock.patch.dict(os.environ, {"FAKE_FLUTTER_OUT": CLEAN}):
            code, out, _ = self.run_main("--skip-tests")
        self.assertEqual(code, 0)
        self.assertIn("[OK] analyze: 0 issues", out)
        self.assertIn("RESULT: PASS", out)
        self.assertEqual(self.argvs(), [["analyze"]])

    def test_analyze_issues_fail(self) -> None:
        with mock.patch.dict(os.environ, {"FAKE_FLUTTER_OUT": "info - x\n3 issues found. (ran in 5s)\n",
                                          "FAKE_FLUTTER_RC": "1"}):
            code, out, _ = self.run_main("--skip-tests")
        self.assertEqual(code, 1)
        self.assertIn("[FAIL] analyze: 3 issue(s) found", out)
        self.assertIn("RESULT: FAIL (analyze)", out)

    def test_analyze_with_no_summary_fails(self) -> None:
        with mock.patch.dict(os.environ, {"FAKE_FLUTTER_OUT": "Unhandled exception\n", "FAKE_FLUTTER_RC": "1"}):
            code, out, _ = self.run_main("--skip-tests")
        self.assertEqual(code, 1)
        self.assertIn("no summary line", out)


class TestStepTests(GateCase):
    def test_tests_pass_needs_a_summary_and_a_pass(self) -> None:
        code, out, _ = self.run_main("--skip-analyze")
        self.assertEqual(code, 0)
        self.assertIn("[OK] tests: 5 passed, 0 skipped, 0 failed", out)

    def test_tests_with_no_summary_fail(self) -> None:
        with mock.patch.dict(os.environ, {"FAKE_FLUTTER_OUT": "lib/x.dart:3: Error: Expected ';'\n",
                                          "FAKE_FLUTTER_RC": "1"}):
            code, out, _ = self.run_main("--skip-analyze")
        self.assertEqual(code, 1)
        self.assertIn("no summary line", out)
        self.assertIn("RESULT: FAIL (tests)", out)
        self.assertNotIn("0 failed", out)

    def test_failed_tests_exit_one(self) -> None:
        with mock.patch.dict(os.environ, {"FAKE_FLUTTER_OUT": "00:02 +4 -1: Some tests failed.\n",
                                          "FAKE_FLUTTER_RC": "1"}):
            code, out, _ = self.run_main("--skip-analyze")
        self.assertEqual(code, 1)
        self.assertIn("4 passed, 0 skipped, 1 failed", out)

    def test_failed_summary_with_exit_zero_fails(self) -> None:
        # The summary alone must fail the step: a "-1" count is a failure even when flutter exits 0.
        with mock.patch.dict(os.environ, {"FAKE_FLUTTER_OUT": "00:02 +4 -1: Some tests failed.\n",
                                          "FAKE_FLUTTER_RC": "0"}):
            code, out, _ = self.run_main("--skip-analyze")
        self.assertEqual(code, 1)
        self.assertNotIn("flutter exited", out)
        self.assertIn("4 passed, 0 skipped, 1 failed", out)

    def test_test_file_runs_one_file(self) -> None:
        code, _out, _ = self.run_main("--skip-analyze", "--test-file", "test/unit/a_test.dart")
        self.assertEqual(code, 0)
        self.assertEqual(self.argvs(), [["test", "test/unit/a_test.dart"]])


class CannotRunTests(GateCase):
    def test_flutter_missing_exits_two(self) -> None:
        empty = self.tmp / "empty"
        empty.mkdir()
        with mock.patch.dict(os.environ, {"PATH": str(empty)}):
            code, _out, err = self.run_main()
        self.assertEqual(code, 2)
        self.assertIn("flutter is not installed", err)

    def test_both_steps_skipped_exits_two(self) -> None:
        code, _out, err = self.run_main("--skip-analyze", "--skip-tests")
        self.assertEqual(code, 2)
        self.assertIn("nothing would be checked", err)
        self.assertEqual(self.argvs(), [])


class BothStepsTests(GateCase):
    def test_both_steps_run_in_order_and_log_is_full(self) -> None:
        with mock.patch.dict(os.environ, {"FAKE_FLUTTER_OUT": CLEAN + ALL_PASS}):
            code, out, _ = self.run_main()
        self.assertEqual(code, 0)
        self.assertEqual(self.argvs(), [["analyze"], ["test"]])
        text = self.log.read_text(encoding="utf-8")
        self.assertIn("===== flutter analyze", text)
        self.assertIn("===== flutter test", text)
        self.assertIn("RESULT: PASS", out)


if __name__ == "__main__":
    unittest.main()
