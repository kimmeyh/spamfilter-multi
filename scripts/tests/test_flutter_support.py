"""Tests for mobile-app/scripts/flutter_support.py (F334, Sprint 85): the summary parser and the fake-flutter path.

Run: python -I -m unittest discover -s scripts/tests -v

The summary parser is the oracle for the runners' pass counts (AC-1), so its cases are the lines flutter prints.

Test list and what each does NOT catch:
  test_expanded_summary_reads_passed_skipped_failed: "+P ~S -F" with the timestamp prefix. NOT caught: a
      reporter that prints the counts in another order (none is known).
  test_last_summary_wins: two summary lines (a progress line, then the final one). NOT caught: a run whose
      final line is missing and whose last progress line is stale.
  test_compact_reporter_without_timestamp: the line with no mm:ss prefix. NOT caught: a test NAME that begins
      with "+3: " (the parser reads the line's START only, so such a name is not a summary).
  test_no_summary_is_none_not_zero: a compile error has no summary line, so the result is None. NOT caught: a
      run that prints a summary and also a compile error (the summary still counts).
  test_missing_flutter_returns_not_found: a flutter path that does not exist returns NOT_FOUND. NOT caught:
      a flutter that starts and then hangs (no timeout is set on the call).
  test_run_flutter_merges_stderr_and_keeps_exit_code: stdout and stderr land in one text, exit code kept.
      NOT caught: interleaving order between the two streams (they are merged by the OS, not by this code).
"""
from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
SUPPORT = REPO / "mobile-app" / "scripts" / "flutter_support.py"
sys.path.insert(0, str(Path(__file__).resolve().parent))

_spec = importlib.util.spec_from_file_location("flutter_support_mod", SUPPORT)
fs = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(fs)


class SummaryParserTests(unittest.TestCase):
    def test_expanded_summary_reads_passed_skipped_failed(self) -> None:
        text = "00:01 +1: a\n00:02 +4 ~1 -2: Some tests failed.\n"
        self.assertEqual(fs.parse_counts(text), (4, 1, 2))

    def test_last_summary_wins(self) -> None:
        text = "00:01 +1: first\n00:05 +9: All tests passed!\n"
        self.assertEqual(fs.parse_counts(text), (9, 0, 0))

    def test_compact_reporter_without_timestamp(self) -> None:
        self.assertEqual(fs.parse_counts("+7: All tests passed!\n"), (7, 0, 0))

    def test_no_summary_is_none_not_zero(self) -> None:
        self.assertIsNone(fs.parse_counts("Error: Compilation failed.\n"))


class RunFlutterTests(unittest.TestCase):
    def test_missing_flutter_returns_not_found(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            code, text = fs.run_flutter(str(Path(tmp) / "no-such-flutter"), ["test"], Path(tmp))
        self.assertEqual(code, fs.NOT_FOUND)
        self.assertIn("could not start", text)

    def test_run_flutter_merges_stderr_and_keeps_exit_code(self) -> None:
        # The current Python stands in for flutter: it writes to both streams and exits 3.
        argv_script = "import sys; print('out'); print('err', file=sys.stderr); sys.exit(3)"
        with tempfile.TemporaryDirectory() as tmp:
            code, text = _run_python(argv_script, Path(tmp))
        self.assertEqual(code, 3)
        self.assertIn("out", text)
        self.assertIn("err", text)


def _run_python(script: str, cwd: Path) -> tuple[int, str]:
    """Run `python -c script` through run_flutter, so the stdout and stderr merge is what is tested."""
    return fs.run_flutter(sys.executable, ["-c", script], cwd)


if __name__ == "__main__":
    unittest.main()
