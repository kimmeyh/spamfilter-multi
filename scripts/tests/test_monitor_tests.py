"""Tests for mobile-app/scripts/monitor-tests.py (port of monitor-tests.ps1, Sprint 9 Task D, F334 Sprint 85).

The parsing functions are tested directly with the lines flutter's expanded reporter prints. One end-to-end
test runs main() against a fake flutter that prints a known transcript.

Run: python -I -m unittest discover -s scripts/tests -v

Test list and what each does NOT catch:
  test_green_run_line_is_parsed: "+N:" with no failure part is a progress line (the original's start regex
      needed "-N:", so a green run never reported slow tests). NOT caught: a reporter that prints a timestamp
      with a different width (the regex needs mm:ss).
  test_skip_and_failure_counts_both_parsed: "+5 ~1 -2:" gives skipped 1 and failed 2 (the original's fail
      regex missed it). NOT caught: a failure count on a line the expanded reporter prints without the colon.
  test_durations_come_from_flutter_clock_and_skip_load_and_summary: a test ends at the next event's time; the
      load step and the final summary are not tests. NOT caught: a test that flutter reports only at its end
      (the 1 second resolution then hides it).
  test_last_test_is_timed_by_the_summary: the last test is timed by the terminal line (the original never
      timed it). NOT caught: a run that ends with no summary line (the last test then has no duration).
  test_slow_tests_are_over_threshold_only_and_sorted: strictly greater than the threshold, slowest first.
      NOT caught: a test that takes exactly the threshold (it is not listed, which is the documented rule).
  test_final_counts_come_from_last_event: passed, skipped, failed from the last progress line.
      NOT caught: a run whose last line is a stale progress line from before a crash.
  test_partial_line_waits_for_newline: a line split across two reads is joined, and CRLF is stripped.
      NOT caught: a multi-byte UTF-8 character split across reads (it is held until its newline arrives).
  test_end_to_end_writes_full_log_and_reports_slow_test: main() with a fake flutter: the log has every line,
      the console shows the [SLOW] line and the summary, and the exit code is flutter's. NOT caught: a
      real flutter run's timing (the fake prints everything at once, so the live [SLOW] line is only checked
      for its text, not its timing).
  test_end_to_end_failure_exit_code_passes_through: flutter exit 1 -> the monitor exits 1.
      NOT caught: a flutter that never exits (the monitor waits; there is no timeout).
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
TOOL = REPO / "mobile-app" / "scripts" / "monitor-tests.py"
_spec = importlib.util.spec_from_file_location("monitor_tests_mod", TOOL)
tool = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(tool)

TRANSCRIPT = (
    "00:00 +0: loading test/unit/x_test.dart\n"
    "00:00 +0: group a test one\n"
    "00:04 +1: group a test two\n"
    "00:05 +2: All tests passed!\n"
)


class ParseTests(unittest.TestCase):
    def test_green_run_line_is_parsed(self) -> None:
        event = tool.parse_event("00:03 +7: group a test name")
        self.assertIsNotNone(event)
        self.assertEqual((event.elapsed, event.passed, event.failed), (3, 7, 0))
        self.assertEqual(event.name, "group a test name")

    def test_skip_and_failure_counts_both_parsed(self) -> None:
        event = tool.parse_event("01:10 +5 ~1 -2: some test")
        self.assertEqual((event.elapsed, event.passed, event.skipped, event.failed), (70, 5, 1, 2))

    def test_non_progress_line_is_not_an_event(self) -> None:
        self.assertIsNone(tool.parse_event("Building Windows app..."))


class DurationTests(unittest.TestCase):
    def events(self, text: str) -> list:
        return [tool.parse_event(line) for line in text.splitlines() if tool.parse_event(line)]

    def test_durations_come_from_flutter_clock_and_skip_load_and_summary(self) -> None:
        events = self.events(TRANSCRIPT)
        self.assertEqual(tool.durations(events), [("group a test one", 4), ("group a test two", 1)])

    def test_last_test_is_timed_by_the_summary(self) -> None:
        events = self.events("00:00 +0: a\n00:02 +1: b\n00:09 +2: All tests passed!\n")
        self.assertEqual(tool.durations(events), [("a", 2), ("b", 7)])

    def test_slow_tests_are_over_threshold_only_and_sorted(self) -> None:
        events = self.events("00:00 +0: a\n00:02 +1: b\n00:07 +2: c\n00:13 +3: d\n00:14 +4: All tests passed!\n")
        # durations: a 2, b 5, c 6, d 1 (the summary at 14 ends d)
        self.assertEqual(tool.slow_tests(events, 4), [("c", 6), ("b", 5)])
        self.assertEqual(tool.slow_tests(events, 5), [("c", 6)])

    def test_final_counts_come_from_last_event(self) -> None:
        events = self.events("00:00 +1: a\n00:01 +4 ~1 -2: Some tests failed.\n")
        self.assertEqual(tool.final_counts(events), (4, 1, 2))
        self.assertEqual(tool.final_counts([]), (0, 0, 0))


class ReadTests(unittest.TestCase):
    def test_partial_line_waits_for_newline(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "out.txt"
            path.write_bytes(b"00:01 +1: a\r\n00:02 +2: b")
            offset, pending, lines = tool.read_new_lines(path, 0, b"")
            self.assertEqual(lines, ["00:01 +1: a"])
            self.assertEqual(pending, b"00:02 +2: b")
            with path.open("ab") as handle:
                handle.write(b"\n")
            offset, pending, lines = tool.read_new_lines(path, offset, pending)
            self.assertEqual(lines, ["00:02 +2: b"])
            self.assertEqual(pending, b"")


class EndToEndTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        fake_flutter.install(self.tmp / "bin")
        self._env = mock.patch.dict(os.environ, {
            "PATH": str(self.tmp / "bin") + os.pathsep + os.environ.get("PATH", ""),
            "FAKE_FLUTTER_OUT": TRANSCRIPT,
            "FAKE_FLUTTER_RC": "0",
        })
        self._env.start()

    def tearDown(self) -> None:
        self._env.stop()
        self._tmp.cleanup()

    def test_end_to_end_writes_full_log_and_reports_slow_test(self) -> None:
        log = self.tmp / "monitor.txt"
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = tool.main(["--output", str(log), "--highlight-slow", "3"])
        self.assertEqual(code, 0)
        self.assertIn("loading test/unit/x_test.dart", log.read_text(encoding="utf-8"))
        out = buf.getvalue()
        self.assertIn("[SLOW] group a test one took 4s", out)
        self.assertIn("Passed: 2", out)
        self.assertNotIn("[SLOW] group a test two", out)

    def test_end_to_end_failure_exit_code_passes_through(self) -> None:
        log = self.tmp / "monitor-fail.txt"
        with mock.patch.dict(os.environ, {"FAKE_FLUTTER_RC": "1"}), contextlib.redirect_stdout(io.StringIO()):
            code = tool.main(["--output", str(log), "--no-progress"])
        self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()
