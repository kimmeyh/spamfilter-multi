"""Tests for mobile-app/scripts/run-tests.py (port of run-tests.ps1, F334, Sprint 85).

Every test runs the runner against a FAKE flutter (scripts/tests/fake_flutter.py), so no test starts the
real SDK. The real-SDK pass-count check (AC-1) is recorded in the sprint plan, not here.

Run: python -I -m unittest discover -s scripts/tests -v

Test list and what each does NOT catch:
  test_one_file_runs_only_that_file_and_reports_counts: --file runs `flutter test <file>`, skips pub get and
      analyze, prints the counts. NOT caught: a count that the fake prints in a shape the parser misreads
      (covered in test_flutter_support.py).
  test_failed_run_exits_one_and_prints_tail: a failing run returns 1 and prints the last lines. NOT caught:
      a failure that flutter reports with exit 0 (the runner trusts the exit code, as the original did).
  test_pub_get_failure_stops_before_any_test: pub get exit 1 -> exit 1 and no `test` call. NOT caught:
      a pub get that succeeds but leaves the packages stale (flutter test resolves them again).
  test_all_runs_every_phase_file_even_after_a_failure: the seven phase files each run once, and a failure in
      the first does not stop the rest (as the original). NOT caught: a file that is listed but no longer
      exists on disk (the existence check is not part of this runner).
  test_analyze_failure_is_a_warning_not_a_failure: flutter analyze exit 1 -> a warning and exit 0 when the
      tests pass. NOT caught: analyze findings that the user never reads (they are printed, not counted).
  test_verbose_adds_global_flag_before_test: -v gives ["--verbose", "test", ...]. NOT caught: a flutter
      version that rejects the global flag (not exercised here).
  test_type_maps_to_folders_and_coverage: unit -> test/unit/, coverage -> --coverage. NOT caught: a new test
      folder that is added to the repo but not to the runner.
  test_missing_flutter_exits_one: flutter not on PATH -> exit 1 with a message. NOT caught: flutter on PATH
      that is a different SDK version than the .fvmrc pin (flutter_version_sync_test covers that).
  test_full_output_goes_to_log_and_console_is_trimmed: the log holds every line, the console only --tail lines.
      NOT caught: a log write that fails silently on a read-only folder (the write raises and the run fails).
  test_bad_type_exits_two: an unknown --type is an argparse error (exit 2). NOT caught: a valid type that
      runs the wrong files (see the mapping test).
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
TOOL = REPO / "mobile-app" / "scripts" / "run-tests.py"
_spec = importlib.util.spec_from_file_location("run_tests_mod", TOOL)
tool = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(tool)

PHASE_FILES = tool.PHASE1 + tool.PHASE2
ALL_PASS = "00:01 +5: All tests passed!\n"


class RunTestsCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        fake_flutter.install(self.tmp / "bin")
        self.calls = self.tmp / "calls.jsonl"
        self.log = self.tmp / "run.log"
        env = {"PATH": str(self.tmp / "bin") + os.pathsep + os.environ.get("PATH", ""),
               "FAKE_FLUTTER_CALLS": str(self.calls), "FAKE_FLUTTER_OUT": ALL_PASS, "FAKE_FLUTTER_RC": "0"}
        self._env = mock.patch.dict(os.environ, env)
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


class OneFileTests(RunTestsCase):
    def test_one_file_runs_only_that_file_and_reports_counts(self) -> None:
        code, out = self.run_main("--file", "test/unit/storage/app_paths_data_dir_test.dart")
        self.assertEqual(code, 0)
        self.assertEqual(self.argvs(), [["test", "test/unit/storage/app_paths_data_dir_test.dart"]])
        self.assertIn("exit 0: passed 5, skipped 0, failed 0", out)
        self.assertTrue(self.log.exists())

    def test_failed_run_exits_one_and_prints_tail(self) -> None:
        with mock.patch.dict(os.environ, {"FAKE_FLUTTER_RC": "1",
                                          "FAKE_FLUTTER_OUT": "00:02 +4 -1: Some tests failed.\n"}):
            code, out = self.run_main("--file", "test/unit/x_test.dart", "--tail", "5")
        self.assertEqual(code, 1)
        self.assertIn("passed 4, skipped 0, failed 1", out)
        self.assertIn("Some tests failed.", out)


class FlowTests(RunTestsCase):
    def test_pub_get_failure_stops_before_any_test(self) -> None:
        with mock.patch.dict(os.environ, {"FAKE_FLUTTER_RC_BY": '{"pub": 1}'}):
            code, _out = self.run_main("--type", "phase1")
        self.assertEqual(code, 1)
        self.assertEqual(self.argvs(), [["pub", "get"]])

    def test_all_runs_every_phase_file_even_after_a_failure(self) -> None:
        with mock.patch.dict(os.environ, {"FAKE_FLUTTER_RC_BY": '{"test": 1}'}):
            code, _out = self.run_main("--type", "all")
        self.assertEqual(code, 1)
        test_calls = [argv for argv in self.argvs() if argv and argv[0] == "test"]
        self.assertEqual(test_calls, [["test", path] for path in PHASE_FILES])

    def test_analyze_failure_is_a_warning_not_a_failure(self) -> None:
        with mock.patch.dict(os.environ, {"FAKE_FLUTTER_RC_BY": '{"analyze": 1}'}):
            code, out = self.run_main("--type", "phase2")
        self.assertEqual(code, 0)
        self.assertIn("[WARNING] flutter analyze reported issues", out)

    def test_verbose_adds_global_flag_before_test(self) -> None:
        self.run_main("--file", "test/unit/x_test.dart", "-v")
        self.assertEqual(self.argvs(), [["--verbose", "test", "test/unit/x_test.dart"]])

    def test_type_maps_to_folders_and_coverage(self) -> None:
        self.run_main("--type", "unit")
        self.run_main("--type", "coverage")
        self.assertEqual(self.argvs(), [["pub", "get"], ["analyze"], ["test", "test/unit/"],
                                        ["pub", "get"], ["analyze"], ["test", "--coverage"]])

    def test_missing_flutter_exits_one(self) -> None:
        empty = self.tmp / "empty"
        empty.mkdir()
        with mock.patch.dict(os.environ, {"PATH": str(empty)}):
            code, _out = self.run_main("--file", "test/unit/x_test.dart")
        self.assertEqual(code, 1)

    def test_full_output_goes_to_log_and_console_is_trimmed(self) -> None:
        lines = "".join(f"line {i}\n" for i in range(100))
        with mock.patch.dict(os.environ, {"FAKE_FLUTTER_OUT": lines + "00:01 +0 -1: Some tests failed.\n",
                                          "FAKE_FLUTTER_RC": "1"}):
            code, out = self.run_main("--file", "test/unit/x_test.dart", "--tail", "3")
        self.assertEqual(code, 1)
        self.assertIn("line 99", self.log.read_text(encoding="utf-8"))
        self.assertIn("line 0\n", self.log.read_text(encoding="utf-8"))
        self.assertNotIn("line 50", out)

    def test_bad_type_exits_two(self) -> None:
        with self.assertRaises(SystemExit) as caught, contextlib.redirect_stderr(io.StringIO()):
            tool.main(["--type", "nonsense"])
        self.assertEqual(caught.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
