"""Tests for mobile-app/scripts/run-integration-tests.py (port of run-integration-tests.ps1, F99 / F334, Sprint 85).

Uses the real integration_test folder for selection (read only) and a fake flutter for every run.

Run: python -I -m unittest discover -s scripts/tests -v

Test list and what each does NOT catch:
  test_select_is_case_insensitive_wildcard_on_file_name: "lifecycle" matches a file whose name has it in any
      case; sorted by full path ignoring case. NOT caught: a file in a nested folder whose name matches but
      whose folder name is also matched (only the file name is tested).
  test_no_match_exits_zero_with_warning: no file matched -> exit 0 and no flutter call (the original's
      behavior). NOT caught: a typo in the name that the user did not notice (the warning is the only signal).
  test_one_flutter_process_per_file: every selected file gets its own `flutter test <file>` call, run in
      mobile-app. NOT caught: a file that flutter silently skips (the runner trusts the exit code).
  test_failed_file_makes_the_run_fail_and_is_listed: exit 1 and the failed file's name in the summary.
      NOT caught: a file that fails but whose name the fake does not report (the run still reports by exit code).
  test_all_pass_exits_zero: every file passes -> exit 0 and the OK line.
  test_missing_flutter_exits_one: flutter not on PATH -> exit 1, no call. NOT caught: a flutter that starts
      but cannot run tests (its exit code is then the signal).
  test_log_holds_all_files_output: the full output of each file is in the log file. NOT caught: output that
      flutter writes to a file of its own rather than stdout.
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

REPO = HERE.parent.parent
TOOL = REPO / "mobile-app" / "scripts" / "run-integration-tests.py"
_spec = importlib.util.spec_from_file_location("run_integration_tests_mod", TOOL)
tool = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(tool)


class SelectTests(unittest.TestCase):
    def test_select_is_case_insensitive_wildcard_on_file_name(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "b").mkdir()
            (root / "b" / "Rule_LIFECYCLE_test.dart").write_text("", encoding="utf-8")
            (root / "a_lifecycle_test.dart").write_text("", encoding="utf-8")
            (root / "other_test.dart").write_text("", encoding="utf-8")
            (root / "lifecycle_helper.dart").write_text("", encoding="utf-8")  # not a *_test.dart
            names = [f.name for f in tool.select_files(root, "lifecycle")]
        self.assertEqual(names, ["a_lifecycle_test.dart", "Rule_LIFECYCLE_test.dart"])

    def test_select_without_filter_returns_every_test_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "x_test.dart").write_text("", encoding="utf-8")
            (root / "y.dart").write_text("", encoding="utf-8")
            self.assertEqual([f.name for f in tool.select_files(root, "")], ["x_test.dart"])


class MainTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        fake_flutter.install(self.tmp / "bin")
        self.calls = self.tmp / "calls.jsonl"
        self.log = self.tmp / "it.log"
        self._env = mock.patch.dict(os.environ, {
            "PATH": str(self.tmp / "bin") + os.pathsep + os.environ.get("PATH", ""),
            "FAKE_FLUTTER_CALLS": str(self.calls),
            "FAKE_FLUTTER_OUT": "00:01 +2: All tests passed!\n",
            "FAKE_FLUTTER_RC": "0",
        })
        self._env.start()

    def tearDown(self) -> None:
        self._env.stop()
        self._tmp.cleanup()

    def run_main(self, *argv: str) -> tuple[int, str]:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = tool.main([*argv, "--log", str(self.log)])
        return code, buf.getvalue()

    def argvs(self) -> list[list[str]]:
        return [call["argv"] for call in fake_flutter.read_calls(self.calls)]

    def test_no_match_exits_zero_with_warning(self) -> None:
        code, out = self.run_main("--name", "no_such_integration_file_zz")
        self.assertEqual(code, 0)
        self.assertIn("No integration_test *_test.dart files matched", out)
        self.assertEqual(self.argvs(), [])

    def test_one_flutter_process_per_file(self) -> None:
        code, _out = self.run_main("--name", "lifecycle")
        self.assertEqual(code, 0)
        argvs = self.argvs()
        self.assertGreaterEqual(len(argvs), 1)
        for argv in argvs:
            self.assertEqual(argv[0], "test")
            self.assertEqual(len(argv), 2)
            self.assertTrue(argv[1].startswith("integration_test/"), argv)
            self.assertIn("lifecycle", argv[1].lower())

    def test_failed_file_makes_the_run_fail_and_is_listed(self) -> None:
        with mock.patch.dict(os.environ, {"FAKE_FLUTTER_RC": "1",
                                          "FAKE_FLUTTER_OUT": "00:03 +1 -1: Some tests failed.\n"}):
            code, out = self.run_main("--name", "lifecycle")
        self.assertEqual(code, 1)
        self.assertIn("[FAIL]", out)
        self.assertIn("  - rule_lifecycle_test.dart", out)

    def test_all_pass_exits_zero(self) -> None:
        code, out = self.run_main("--name", "lifecycle")
        self.assertEqual(code, 0)
        self.assertIn("[OK] all integration_test files passed.", out)

    def test_missing_flutter_exits_one(self) -> None:
        empty = self.tmp / "empty"
        empty.mkdir()
        with mock.patch.dict(os.environ, {"PATH": str(empty)}):
            code, _out = self.run_main("--name", "lifecycle")
        self.assertEqual(code, 1)
        self.assertEqual(self.argvs(), [])

    def test_log_holds_all_files_output(self) -> None:
        self.run_main("--name", "lifecycle")
        text = self.log.read_text(encoding="utf-8")
        self.assertIn("== flutter test integration_test/", text)
        self.assertIn("All tests passed!", text)


if __name__ == "__main__":
    unittest.main()
