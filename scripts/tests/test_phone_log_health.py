"""Tests for scripts/phone-log-health.py (F332, Sprint 85; port of phone-log-health.ps1).

The oracle for the report is the output of the ORIGINAL PowerShell script, run on the same fixtures
(AC-1). Those outputs are stored as expected_<fixture>.txt next to the fixtures.

Run: python -I -m unittest discover -s scripts/tests -v

Test list and what each does NOT catch:
  test_report_matches_original_powershell: AC-1. Exact text for the two Sprint 83/84 samples and the
      malformed log. NOT caught: a line the fixtures never exercise (the samples hold scan, error,
      unfinished and skip lines, but no interval-changed account).
  test_self_test_runs_all_checks: the built-in 14 checks pass. NOT caught: a check that was weakened in
      both implementations at the same time.
  test_single_account_flag_only_with_flag: the multi-account flag. NOT caught: a run that scans two
      accounts in sequence (the flag counts accounts, not overlap).
  test_since_window_with_no_scan_is_not_healthy: a window with no scan line exits 3, not "No flags.".
      NOT caught: a window that holds scan lines for the wrong account only.
  test_empty_log_is_not_healthy: a zero-line log exits 3. NOT caught: a log that is non-empty but
      holds only blank lines (it also exits 3, but this test does not name that case).
  test_unparseable_timestamp_is_not_recognized: a scan-shaped line with an impossible timestamp is not
      counted. NOT caught: a timestamp with a valid shape and a wrong date.
  test_crlf_and_utf8_logs_read_like_lf_ascii: CRLF line ends and a non-ASCII account name are read
      correctly (the PowerShell 5.1 original read UTF-8 as ANSI). NOT caught: a BOM at the start of a
      file (the first line then keeps the BOM and no scan line matches it).
  test_no_path_and_no_match_exit_codes: exit 2 without --path, exit 4 when no log matches (with the
      warning). NOT caught: a glob that matches a folder instead of files (folders are skipped).
  test_comma_separated_paths_are_split: "a.log,b.log" in one argument reads both files. NOT caught:
      a file name that contains a comma.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import tempfile
import unittest
from pathlib import Path

SCRIPTS_TESTS = Path(__file__).resolve().parent
REPO = SCRIPTS_TESTS.parent.parent
TOOL_PATH = REPO / "scripts" / "phone-log-health.py"
FIXTURES = SCRIPTS_TESTS / "fixtures" / "phone_log_health"

_spec = importlib.util.spec_from_file_location("phone_log_health_mod", TOOL_PATH)
tool = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(tool)


def run_main(argv: list[str]) -> tuple[int, str]:
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        code = tool.main(argv)
    return code, buf.getvalue()


class ReportTests(unittest.TestCase):
    def test_report_matches_original_powershell(self) -> None:
        """AC-1: each fixture's report equals the output of the original phone-log-health.ps1."""
        cases = (
            ("diag_sample_s84.log", 0),
            ("diag_sample_s83.log", 0),
            ("diag_malformed.log", 3),
        )
        for name, want_code in cases:
            with self.subTest(fixture=name):
                code, out = run_main(["--path", str(FIXTURES / name), "--interval-minutes", "15"])
                expected = (FIXTURES / f"expected_{name[:-4]}.txt").read_text(encoding="utf-8")
                self.assertEqual(out, expected)
                self.assertEqual(code, want_code)

    def test_self_test_runs_all_checks(self) -> None:
        """The built-in checks run and pass. The count matches the 14 of the PowerShell -SelfTest."""
        checks, failures = tool.run_self_test()
        self.assertEqual(failures, [])
        self.assertEqual(checks, 14)
        code, out = run_main(["--self-test"])
        self.assertEqual(code, 0)
        self.assertEqual(out.strip(), "SELFTEST PASS (14 checks)")

    def test_single_account_flag_only_with_flag(self) -> None:
        """Two accounts scanned: the flag appears only when --single-account is given."""
        sample = str(FIXTURES / "diag_sample_s84.log")
        _code, plain = run_main(["--path", sample])
        self.assertNotIn("accounts scanned in the background", plain)
        _code, single = run_main(["--path", sample, "--single-account"])
        self.assertIn("FLAG: 2 accounts scanned in the background", single)

    def test_since_window_with_no_scan_is_not_healthy(self) -> None:
        """A window after every scan line holds no scan: exit 3, never "No flags."."""
        code, out = run_main(["--path", str(FIXTURES / "diag_sample_s84.log"), "--since", "2030-01-01 00:00"])
        self.assertEqual(code, 3)
        self.assertIn("0 scan lines recognized", out)
        self.assertNotIn("No flags.", out)

    def test_empty_log_is_not_healthy(self) -> None:
        """A zero-line log exits 3 (F332 defect: the original printed "No flags." for it)."""
        with tempfile.TemporaryDirectory() as tmp:
            empty = Path(tmp) / "diag_empty.log"
            empty.write_bytes(b"")
            code, out = run_main(["--path", str(empty)])
        self.assertEqual(code, 3)
        self.assertNotIn("No flags.", out)

    def test_unparseable_timestamp_is_not_recognized(self) -> None:
        """A scan-shaped line whose timestamp does not parse is not counted (the original threw)."""
        line = ("[2026-13-45T99:00:00.000000] [SCAN] [scan/background] x***@example.com start -- "
                "platform=aol folders=3 daysBack=1")
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / "diag_bad_ts.log"
            log.write_text(line + "\n", encoding="utf-8")
            code, out = run_main(["--path", str(log)])
        self.assertEqual(code, 3)
        self.assertIn("0 scan lines recognized", out)

    def test_crlf_and_utf8_logs_read_like_lf_ascii(self) -> None:
        """CRLF endings and a non-ASCII account name: same counts as the LF sample, name carried over."""
        text = (FIXTURES / "diag_sample_s84.log").read_text(encoding="utf-8")
        accented = text.replace("acct1***@example.com", "üser***@example.com").replace("\n", "\r\n")
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / "diag_crlf.log"
            log.write_bytes(accented.encode("utf-8"))
            code, out = run_main(["--path", str(log)])
        expected = (FIXTURES / "expected_diag_sample_s84.txt").read_text(encoding="utf-8")
        self.assertEqual(code, 0)
        # The accented name sorts after the others, so compare the lines as a set, not in order.
        want = expected.replace("acct1***@example.com", "üser***@example.com")
        self.assertEqual(sorted(out.splitlines()), sorted(want.splitlines()))

    def test_no_path_and_no_match_exit_codes(self) -> None:
        """No --path is exit 2; a glob that matches nothing is named and exit 4."""
        code, out = run_main([])
        self.assertEqual(code, 2)
        self.assertIn("Give --path", out)
        code, out = run_main(["--path", str(FIXTURES / "no_such_*.log")])
        self.assertEqual(code, 4)
        self.assertIn("matched no file", out)
        self.assertIn("Health NOT checked", out)

    def test_comma_separated_paths_are_split(self) -> None:
        """Two logs in one argument: both are read and the header counts two."""
        both = f"{FIXTURES / 'diag_sample_s84.log'},{FIXTURES / 'diag_sample_s83.log'}"
        code, out = run_main(["--path", both])
        self.assertEqual(code, 0)
        self.assertIn("(2 log(s), interval 15 min)", out)


if __name__ == "__main__":
    unittest.main()
