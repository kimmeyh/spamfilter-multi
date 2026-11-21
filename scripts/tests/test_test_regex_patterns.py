"""Tests for scripts/test-regex-patterns.py (F330, Sprint 85).

What these tests do NOT catch: the timing run is checked for its output shape and step numbering, not for
the measured number; nothing here proves a pattern behaves the same in Dart RegExp, the engine the app uses;
an interactive session is simulated with a StringIO, not a terminal.
Run: python -I -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("test_regex_patterns_script", SCRIPTS / "test-regex-patterns.py")
trp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(trp)


def run(argv: list[str], stdin: str = "") -> tuple[int, str]:
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer), mock.patch.object(sys, "stdin", io.StringIO(stdin)):
        try:
            code = trp.main(argv)
        except SystemExit as exc:  # argparse errors
            code = exc.code
    return code, buffer.getvalue()


class Matching(unittest.TestCase):
    def test_match_and_no_match_are_counted(self):
        code, out = run(["--pattern", r"^user@example\.com$", "--test-string", "USER@example.com"])
        self.assertEqual(code, 0)
        self.assertIn("[MATCH] USER@example.com", out)  # case-insensitive
        self.assertIn("Summary: 1 of 1 strings matched", out)

    def test_no_match_still_exits_0(self):
        code, out = run(["--pattern", "zzz", "--test-string", "abc"])
        self.assertEqual(code, 0)
        self.assertIn("[NO MATCH] abc", out)
        self.assertIn("Summary: 0 of 1 strings matched", out)

    def test_search_is_not_anchored(self):
        _code, out = run(["--pattern", "urgent", "--test-string", "this is urgent now"])
        self.assertIn("[MATCH]", out)

    def test_file_input_counts_every_line_including_blank(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "s.txt"
            path.write_bytes(b"\xef\xbb\xbfa@x.com\nnope\n\nb@x.com\n")
            code, out = run(["--pattern", r"@x\.com$", "--file", str(path)])
        self.assertEqual(code, 0)
        self.assertIn("Loaded 4 test strings", out)
        self.assertIn("Summary: 2 of 4 strings matched", out)
        self.assertIn("[MATCH] a@x.com", out)  # BOM removed

    def test_show_matches_prints_groups_and_blank_for_unmatched_group(self):
        _code, out = run(["--pattern", r"(a)|(b)", "--test-string", "a", "--show-matches"])
        self.assertIn("Group 1: a", out)
        self.assertIn("Group 2: \n", out)

    def test_dotnet_named_group_pattern_works(self):
        _code, out = run(["--pattern", r"(?<user>[a-z]+)@\k<user>\.com", "--test-string", "bob@bob.com"])
        self.assertIn("[MATCH]", out)

    def test_interactive_stdin_ends_on_blank_line(self):
        code, out = run(["--pattern", "a"], stdin="abc\nxyz\n   \nnever\n")  # a whitespace-only line also ends input
        self.assertEqual(code, 0)
        self.assertIn("Testing 2 string(s)", out)

    def test_closed_stdin_means_no_strings_not_a_crash(self):
        code, out = run(["--pattern", "a"], stdin="")
        self.assertEqual(code, 0)
        self.assertIn("[WARNING] No test strings provided", out)


class FailurePaths(unittest.TestCase):
    def test_invalid_pattern_exits_1(self):
        code, out = run(["--pattern", "(?<bad", "--test-string", "x"])
        self.assertEqual(code, 1)
        self.assertIn("[ERROR] Invalid regex pattern", out)
        self.assertNotIn("Testing 1 string", out)

    def test_missing_file_exits_1(self):
        code, out = run(["--pattern", "a", "--file", str(Path(tempfile.gettempdir()) / "no-such-file-f330.txt")])
        self.assertEqual(code, 1)
        self.assertIn("[ERROR] File not found", out)

    def test_untranslatable_pattern_exits_3_and_is_not_called_invalid(self):
        code, out = run(["--pattern", r"\p{L}+", "--test-string", "abc"])
        self.assertEqual(code, 3)
        self.assertIn("[NOT CHECKED]", out)
        self.assertNotIn("Invalid regex", out)

    def test_missing_pattern_is_a_usage_error(self):
        with contextlib.redirect_stderr(io.StringIO()):
            code, _out = run(["--test-string", "x"])
        self.assertEqual(code, 2)


class Warnings(unittest.TestCase):
    def test_backtracking_shape_warns_but_still_runs(self):
        code, out = run(["--pattern", "(.*.*)x", "--test-string", "ax"])
        self.assertEqual(code, 0)
        self.assertIn("[WARNING] Multiple .* in sequence", out)

    def test_clean_pattern_says_no_issues(self):
        _code, out = run(["--pattern", "abc", "--test-string", "abc"])
        self.assertIn("[OK] No obvious performance issues detected", out)

    def test_python_nested_set_warning_is_shown(self):
        _code, out = run(["--pattern", "[[a]", "--test-string", "a"])
        self.assertIn("FutureWarning", out)


class Suggestions(unittest.TestCase):
    def test_suggestion_is_single_quoted_yaml_with_apostrophes_doubled(self):
        _code, out = run(["--pattern", r"it's\.com$", "--test-string", "x"])
        self.assertIn(r"- 'it''s\.com$'", out)
        self.assertNotIn('"it', out)  # the original wrote double quotes, which turn \. into an invalid YAML escape

    def test_safe_senders_key_is_quoted_like_the_real_file(self):
        _code, out = run(["--pattern", "a", "--test-string", "x"])
        self.assertIn("'safe_senders':", out)


class Timing(unittest.TestCase):
    def test_performance_run_reports_an_average_and_four_steps(self):
        code, out = run(["--pattern", "abc", "--test-string", "abc", "--performance-test"])
        self.assertEqual(code, 0)
        self.assertIn("[3/4] Running performance test (1000 iterations)", out)
        self.assertIn("[4/4] Testing pattern matches", out)
        self.assertIn("Average time per match:", out)
        self.assertIn("[OK] Pattern is fast", out)

    def test_slow_pattern_branch(self):
        with mock.patch.object(trp, "performance_test", return_value=2.5):
            _code, out = run(["--pattern", "abc", "--test-string", "abc", "--performance-test"])
        self.assertIn("[WARNING] Pattern is slow (>1ms per match)", out)

    def test_without_the_flag_there_are_three_steps(self):
        _code, out = run(["--pattern", "abc", "--test-string", "abc"])
        self.assertIn("[3/3] Testing pattern matches", out)
        self.assertNotIn("performance test", out)


if __name__ == "__main__":
    unittest.main()
