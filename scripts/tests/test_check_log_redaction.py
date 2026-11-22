"""Tests for mobile-app/scripts/check-log-redaction.py (F333, Sprint 85; port of check-log-redaction.ps1).

Run: python -I -m unittest discover -s scripts/tests -v

Test list and what each does NOT catch:
  test_violation_detection: raw account id and token in a log call are violations; Redact., counts, row
      ids and non-log lines are not. NOT caught: a sink name the log-call regex has never listed.
  test_self_test_matches_original: --self-test prints the ten cases of the PowerShell -SelfTest and exits
      0. NOT caught: a case weakened in the script and in this expectation together.
  test_scan_reports_file_line_and_text: a violating file gives exit 1 with "path:line" and the trimmed
      text; CRLF files keep correct line numbers. NOT caught: a violation inside a file whose extension
      is not .dart.
  test_line_numbers_follow_cr_lf_crlf_only: a lone CR, CRLF and LF each end a line; a form feed does
      not. NOT caught: a Unicode line separator inside a string (not a break here either).
  test_match_is_case_insensitive_like_the_original: upper-case sink and variable still match (kept from
      PowerShell -match). NOT caught: the Dart lane, which is case-sensitive.
  test_clean_tree_exits_zero: a clean tree prints the [OK] line, exit 0. NOT caught: a tree with no
      .dart file at all (it also exits 0, by design).
  test_missing_lib_dir_fails: a missing folder exits 1, it never passes silently. NOT caught: an
      unreadable folder (permissions).
  test_invalid_utf8_does_not_crash: a file with bytes that are not UTF-8 is still scanned. NOT caught:
      a UTF-16 file (it is read as garbage and cannot match).
  test_regexes_match_dart_test_lane: the two regex texts equal the ones in
      mobile-app/test/policy/log_redaction_test.dart. NOT caught: a change to how the Dart test applies
      them (for example its file filter).
  test_real_repo_lib_has_no_violation: the real mobile-app/lib passes. NOT caught: a violation written
      after this test ran.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import re
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
TOOL_PATH = REPO / "mobile-app" / "scripts" / "check-log-redaction.py"
DART_TEST = REPO / "mobile-app" / "test" / "policy" / "log_redaction_test.dart"

_spec = importlib.util.spec_from_file_location("check_log_redaction_mod", TOOL_PATH)
tool = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(tool)


def run_main(argv: list[str]) -> tuple[int, str]:
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        code = tool.main(argv)
    return code, buf.getvalue()


class DetectionTests(unittest.TestCase):
    def test_violation_detection(self) -> None:
        bad = [
            "_logger.i('for account $accountId')",
            "_logger.w('x ${accountId} y')",
            "Logger().e('t=$refreshToken')",
            "await _bgLog('pw $appPassword')",
            "  bgLog('secret $clientSecret')",
            "_logger.d('bg $_backgroundAccountId')",
            "_logger.d('bare $account here')",
        ]
        good = [
            "_logger.i('list $accountIds')",
            "_logger.i('n=$accountCount')",
            "_logger.i('${Redact.accountId(accountId)}')",
            "_logger.d('email $emailId')",
            # By design a Redact. anywhere on the line exempts it (redaction is applied inline).
            "_logger.i('${Redact.token(t)} and $accountId')",
            "final token = $token;",
            "print('$accountId')",
        ]
        for line in bad:
            with self.subTest(line=line):
                self.assertTrue(tool.is_violation(line))
        for line in good:
            with self.subTest(line=line):
                self.assertFalse(tool.is_violation(line))

    def test_self_test_matches_original(self) -> None:
        code, out = run_main(["--self-test"])
        self.assertEqual(code, 0)
        lines = out.splitlines()
        self.assertEqual(lines[0], "[SELF-TEST] check-log-redaction.py")
        self.assertEqual(lines[-1], "[SELF-TEST] ALL PASSED")
        self.assertEqual(len([ln for ln in lines if ln.startswith("  [PASS]")]), 10)


class ScanTests(unittest.TestCase):
    def test_scan_reports_file_line_and_text(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lib = Path(tmp) / "lib"
            (lib / "core").mkdir(parents=True)
            (lib / "core" / "a.dart").write_bytes(
                b"void f() {\r\n  // ok\r\n  _logger.i('acct $accountId');\r\n}\r\n")
            (lib / "b.dart").write_text("_logger.i('${Redact.accountId(accountId)}');\n", encoding="utf-8")
            (lib / "note.txt").write_text("_logger.i('$accountId')\n", encoding="utf-8")
            code, out = run_main(["--lib-dir", str(lib)])
        self.assertEqual(code, 1)
        self.assertIn("[FAIL] Logging-redaction violations (ADR-0030 'Logging & Redaction', F102):", out)
        self.assertIn("a.dart:3", out)
        self.assertIn("    _logger.i('acct $accountId');", out)
        self.assertNotIn("b.dart", out)
        self.assertNotIn("note.txt", out)
        self.assertIn("Wrap the identifier with Redact.accountId()", out)

    def test_line_numbers_follow_cr_lf_crlf_only(self) -> None:
        text = b"a\rb\r\nc\n\x0c\n_logger.i('t=$token');\n"  # CR, CRLF, LF, then a form feed in text
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "x.dart").write_bytes(text)
            code, out = run_main(["--lib-dir", tmp])
        self.assertEqual(code, 1)
        self.assertIn("x.dart:5", out)

    def test_match_is_case_insensitive_like_the_original(self) -> None:
        self.assertTrue(tool.is_violation("_logger.i('t=$Token')"))
        self.assertTrue(tool.is_violation("_LOGGER.I('T=$TOKEN')"))  # both regexes ignore case

    def test_clean_tree_exits_zero(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "x.dart").write_text("_logger.i('n=$accountCount');\n", encoding="utf-8")
            code, out = run_main(["--lib-dir", tmp])
        self.assertEqual(code, 0)
        self.assertEqual(out.strip(), "[OK] No logging-redaction violations found.")

    def test_missing_lib_dir_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            code, out = run_main(["--lib-dir", str(Path(tmp) / "nope")])
        self.assertEqual(code, 1)
        self.assertIn("[FAIL] lib folder not found", out)

    def test_invalid_utf8_does_not_crash(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "x.dart").write_bytes(b"// \xff\xfe bad\n_logger.i('t=$token');\n")
            code, out = run_main(["--lib-dir", tmp])
        self.assertEqual(code, 1)
        self.assertIn("x.dart:2", out)


class LaneSyncTests(unittest.TestCase):
    def test_regexes_match_dart_test_lane(self) -> None:
        dart = DART_TEST.read_text(encoding="utf-8")
        call = re.search(r"_logCall = RegExp\(\s*r'(.*?)'\);", dart, re.DOTALL)
        pii = re.search(r"_pii = RegExp\(\s*r'(.*?)'\);", dart, re.DOTALL)
        self.assertIsNotNone(call, "_logCall not found in the Dart test")
        self.assertIsNotNone(pii, "_pii not found in the Dart test")
        self.assertEqual(tool.LOG_CALL_RE.pattern, call.group(1))
        self.assertEqual(tool.PII_RE.pattern, pii.group(1))

    def test_real_repo_lib_has_no_violation(self) -> None:
        code, out = run_main([])
        self.assertEqual(code, 0, out)
        self.assertIn("[OK] No logging-redaction violations found.", out)


if __name__ == "__main__":
    unittest.main()
