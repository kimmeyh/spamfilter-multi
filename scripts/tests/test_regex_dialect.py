"""Tests for scripts/regex_dialect.py (F330, Sprint 85): the .NET-to-Python regex translation.

What these tests do NOT catch: they prove the translation table and the error split (NotChecked versus
RegexSyntaxError), not that Dart RegExp, the engine the app uses, accepts or matches a pattern the same way.
Run: python -I -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPTS))
import regex_dialect as rd  # noqa: E402


def matches(pattern: str, text: str) -> bool:
    compiled, _notes = rd.compile_net(pattern)
    return compiled.search(text) is not None


class TranslateTests(unittest.TestCase):
    def test_named_group_and_back_reference(self):
        self.assertTrue(matches(r"(?<n>a)\k<n>", "aa"))
        self.assertFalse(matches(r"^(?<n>a)\k<n>$", "ab"))

    def test_quoted_named_group(self):
        self.assertTrue(matches(r"(?'n'a)\k'n'", "aa"))

    def test_lookbehind_is_not_mistaken_for_a_named_group(self):
        self.assertTrue(matches(r"(?<=a)b", "ab"))
        self.assertFalse(matches(r"(?<!a)b", "ab"))

    def test_absolute_end_z_versus_z(self):
        self.assertFalse(matches(r"b\z", "ab\n"))  # \z is the very end only
        self.assertTrue(matches(r"b\Z", "ab\n"))   # \Z allows one final newline
        self.assertTrue(matches(r"b\z", "ab"))

    def test_leading_and_mid_pattern_ignore_case_flag_are_dropped(self):
        self.assertTrue(matches(r"(?i)abc", "ABC"))
        self.assertTrue(matches(r"a(?i)b", "aB"))  # Python 3.11+ would reject this unchanged

    def test_ignore_case_is_always_on(self):
        self.assertTrue(matches("abc", "xABCx"))

    def test_escape_e(self):
        self.assertTrue(matches(r"\e", "\x1b"))

    def test_class_with_leading_bracket_is_literal(self):
        self.assertTrue(matches(r"[]a]", "]"))
        self.assertTrue(matches(r"[^]a]", "b"))
        self.assertFalse(matches(r"^[^]a]$", "]"))

    def test_class_state_is_tracked_after_a_leading_bracket(self):
        # \G inside a class is not the "start of match" anchor, so it must reach re.compile (a syntax error there),
        # not be reported as NotChecked. If the leading ] ended the class early, \G would be seen outside it.
        with self.assertRaises(rd.RegexSyntaxError):
            rd.compile_net(r"[]\G]")
        with self.assertRaises(rd.RegexSyntaxError):
            rd.compile_net(r"[^]\G]")

    def test_z_inside_a_class_is_left_alone(self):
        self.assertEqual(rd.translate(r"[\z]"), r"[\z]")

    def test_scoped_flags_pass_through(self):
        self.assertTrue(matches(r"(?-i:a)B", "aB"))
        self.assertFalse(matches(r"(?-i:a)B", "AB"))


class NotCheckedTests(unittest.TestCase):
    def assert_not_checked(self, pattern: str):
        with self.assertRaises(rd.NotChecked, msg=pattern):
            rd.compile_net(pattern)

    def test_untranslatable_constructs_are_not_checked_never_syntax_errors(self):
        for pattern in (r"\p{L}+", r"\P{Lu}", r"(?s)a.b", r"(?m)^a", r"[a-z-[aeiou]]", r"\Gabc",
                        r"(?<a-b>x)", r"(?<n>a)(?<n>b)", r"(?n:a)"):
            self.assert_not_checked(pattern)

    def test_not_checked_is_a_different_type_from_a_syntax_error(self):
        self.assertFalse(issubclass(rd.NotChecked, rd.RegexSyntaxError))
        self.assertFalse(issubclass(rd.RegexSyntaxError, rd.NotChecked))


class SyntaxErrorTests(unittest.TestCase):
    def test_broken_patterns_raise_regex_syntax_error(self):
        for pattern in ("(?<bad", "[a-", "(", "a)", "*a", "abc\\", "(?<n>a"):
            with self.assertRaises(rd.RegexSyntaxError, msg=pattern):
                rd.compile_net(pattern)

    def test_error_text_is_kept(self):
        with self.assertRaises(rd.RegexSyntaxError) as ctx:
            rd.compile_net("(")
        self.assertIn("missing )", str(ctx.exception))


class WarningTests(unittest.TestCase):
    def test_python_warning_text_is_returned(self):
        _compiled, notes = rd.compile_net("[[a]")
        self.assertTrue(any("FutureWarning" in n for n in notes), notes)

    def test_clean_pattern_has_no_notes(self):
        self.assertEqual(rd.compile_net(r"^a@b\.com$")[1], [])

    def test_performance_shapes(self):
        self.assertEqual(len(rd.performance_warnings(".*.*x")), 1)
        self.assertEqual(len(rd.performance_warnings("(.+)*x")), 1)
        self.assertEqual(len(rd.performance_warnings("([a-z]+)*x")), 1)
        self.assertEqual(len(rd.performance_warnings("(.*+x)")), 1)
        self.assertEqual(rd.performance_warnings(r"^[^@\s]+@(?:[a-z0-9-]+\.)*example\.com$"), [])


if __name__ == "__main__":
    unittest.main()
