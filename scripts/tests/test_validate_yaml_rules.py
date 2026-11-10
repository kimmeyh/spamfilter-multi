"""Tests for scripts/validate-yaml-rules.py (F330, Sprint 85).

What these tests do NOT catch: they use small fixture files and one run over the repository's real rule
files; they do not prove the validator understands YAML beyond list items written as - 'x' or - "x" (it is a
text scan, see the module docstring), and a pattern that Python accepts but Dart rejects passes.
Run: python -I -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent
SCRIPT = SCRIPTS / "validate-yaml-rules.py"
spec = importlib.util.spec_from_file_location("validate_yaml_rules", SCRIPT)
vyr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vyr)

RULES_OK = "rules:\n- name: entire_0\n  conditions:\n    header:\n    - '@(?:[a-z0-9-]+\\.)*example\\.com$'\n    from: []\n"
SAFE_OK = "'safe_senders':\n- '^a@b\\.com$'\n- '^c@d\\.com$'\n"


class Base(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.dir = Path(self._tmp.name)

    def write(self, name: str, text: str, data: bytes | None = None) -> str:
        path = self.dir / name
        path.write_bytes(data if data is not None else text.encode("utf-8"))
        return str(path)

    def run_main(self, rules: str, safe: str | None = None, *extra: str) -> tuple[int, str]:
        argv = ["--rules-file", rules] + (["--safe-senders-file", safe] if safe else ["--safe-senders-file", str(self.dir / "absent.yaml")]) + list(extra)
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            code = vyr.main(argv)
        return code, buffer.getvalue()


class HappyPath(Base):
    def test_clean_files_pass(self):
        code, out = self.run_main(self.write("r.yaml", RULES_OK), self.write("s.yaml", SAFE_OK))
        self.assertEqual(code, 0, out)
        self.assertIn("Found 1 regex patterns, 1 valid", out)
        self.assertIn("Found 2 safe sender patterns, 2 valid", out)
        self.assertIn("[OK] All validations passed!", out)

    def test_banner_is_a_real_80_character_rule(self):
        _code, out = self.run_main(self.write("r.yaml", RULES_OK), self.write("s.yaml", SAFE_OK))
        self.assertIn("=" * 80, out)
        self.assertNotIn("= * 80", out)

    def test_names_and_non_regex_values_are_not_counted(self):
        text = "rules:\n- name: 'SpamAutoDeleteHeader'\n  enabled: 'True'\n  x:\n  - 'OR'\n  - 'plainword'\n"
        code, out = self.run_main(self.write("r.yaml", text), self.write("s.yaml", SAFE_OK))
        self.assertEqual(code, 0, out)
        self.assertIn("Found 0 regex patterns, 0 valid", out)

    def test_escaped_single_quote_is_decoded(self):
        text = "rules:\n- x:\n  - 'it''s@(a|b)\\.com'\n"
        code, out = self.run_main(self.write("r.yaml", text), self.write("s.yaml", SAFE_OK))
        self.assertEqual(code, 0, out)
        self.assertIn("Found 1 regex patterns, 1 valid", out)

    def test_escaped_quote_is_shown_decoded_in_an_error(self):
        code, out = self.run_main(self.write("r.yaml", "rules:\n- x:\n  - 'a''b('\n"), self.write("s.yaml", SAFE_OK))
        self.assertEqual(code, 1, out)
        self.assertIn("Invalid pattern: a'b( (in rules.yaml line 3)", out)

    def test_double_quoted_item_is_decoded_before_compiling(self):
        # In YAML "a\\.b" is the regex a\.b, which is valid; read raw it is a\\.b, also valid, so use a case where raw is INVALID.
        text = 'rules:\n- x:\n  - "a\\\\(b"\n'  # file holds: - "a\\(b"  -> decoded a\(b (valid); raw a\\(b is an unclosed group
        code, out = self.run_main(self.write("r.yaml", text), self.write("s.yaml", SAFE_OK))
        self.assertEqual(code, 0, out)
        self.assertIn("Found 1 regex patterns, 1 valid", out)

    def test_repository_rule_files_pass_from_any_folder(self):
        # AC-3: /validate-rules runs this with no arguments from the repository root; a folder without rules.yaml uses the repo copy.
        result = subprocess.run([sys.executable, "-I", str(SCRIPT)], cwd=self.dir, capture_output=True, text=True,
                                encoding="utf-8", timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("[OK] All validations passed!", result.stdout)


class FailurePaths(Base):
    def test_invalid_regex_fails_with_exit_1_and_a_line_number(self):
        text = "rules:\n- x:\n  - '^ok@x\\.com$'\n  - '(?<bad'\n"
        code, out = self.run_main(self.write("r.yaml", text), self.write("s.yaml", SAFE_OK))
        self.assertEqual(code, 1, out)
        self.assertIn("[REGEX ERROR] Invalid pattern: (?<bad (in rules.yaml line 4)", out)
        self.assertIn("Found 2 regex patterns, 1 valid", out)

    def test_invalid_safe_sender_fails(self):
        code, out = self.run_main(self.write("r.yaml", RULES_OK), self.write("s.yaml", "'safe_senders':\n- '(unclosed'\n"))
        self.assertEqual(code, 1, out)
        self.assertIn("safe_senders.yaml line 2", out)

    def test_pattern_starting_with_spam_is_still_checked(self):
        # The original skipped any value that STARTS with "Spam" (case-insensitive), hiding this broken pattern.
        code, out = self.run_main(self.write("r.yaml", "rules:\n- x:\n  - 'spam@(x'\n"), self.write("s.yaml", SAFE_OK))
        self.assertEqual(code, 1, out)

    def test_missing_rules_file_exits_1(self):
        code, out = self.run_main(str(self.dir / "nope.yaml"), self.write("s.yaml", SAFE_OK))
        self.assertEqual(code, 1)
        self.assertIn("[ERROR] File not found", out)

    def test_missing_rules_key_is_a_schema_error(self):
        code, out = self.run_main(self.write("r.yaml", "other:\n- 'a@b'\n"), self.write("s.yaml", SAFE_OK))
        self.assertEqual(code, 1)
        self.assertIn("[SCHEMA ERROR] rules.yaml missing 'rules' key", out)

    def test_missing_safe_senders_key_is_a_schema_error(self):
        code, out = self.run_main(self.write("r.yaml", RULES_OK), self.write("s.yaml", "other:\n- 'a@b'\n"))
        self.assertEqual(code, 1)
        self.assertIn("missing 'safe_senders' key", out)

    def test_tab_indentation_is_an_error_but_a_tab_inside_a_pattern_is_not(self):
        code, out = self.run_main(self.write("r.yaml", "rules:\n\t- x\n"), self.write("s.yaml", SAFE_OK))
        self.assertEqual(code, 1)
        self.assertIn("contains tabs", out)
        code, out = self.run_main(self.write("r2.yaml", "rules:\n- x:\n  - 'a\tb@c'\n"), self.write("s.yaml", SAFE_OK))
        self.assertEqual(code, 0, out)

    def test_undecodable_file_is_reported_not_raised(self):
        code, out = self.run_main(self.write("r.yaml", "", data=b"rules:\n- '\xff\xfe@x'\n"), self.write("s.yaml", SAFE_OK))
        self.assertEqual(code, 1, out)
        self.assertIn("[YAML ERROR] Failed to parse rules.yaml", out)


class WarningsAndNotes(Base):
    def test_missing_safe_senders_file_warns_and_is_not_all_passed(self):
        code, out = self.run_main(self.write("r.yaml", RULES_OK), None)
        self.assertEqual(code, 0)
        self.assertIn("[FILE WARNING]", out)
        self.assertNotIn("All validations passed", out)

    def test_duplicates_and_performance_shapes_warn_with_exit_0(self):
        text = "rules:\n- x:\n  - '(.*.*)x'\n"
        safe = "'safe_senders':\n- 'a@b'\n- 'a@b'\n"
        code, out = self.run_main(self.write("r.yaml", text), self.write("s.yaml", safe))
        self.assertEqual(code, 0, out)
        self.assertIn("[PERFORMANCE WARNING]", out)
        self.assertIn("[DUPLICATE WARNING] Found 1 duplicate patterns", out)

    def test_untranslatable_pattern_is_listed_as_not_checked_with_exit_0(self):
        code, out = self.run_main(self.write("r.yaml", "rules:\n- x:\n  - '\\p{L}+@x'\n"), self.write("s.yaml", SAFE_OK))
        self.assertEqual(code, 0, out)
        self.assertIn("[NOT CHECKED]", out)
        self.assertIn("Found 1 regex patterns, 0 valid, 1 not checked", out)
        self.assertNotIn("[REGEX ERROR]", out)

    def test_non_empty_flow_list_is_reported_as_not_read(self):
        code, out = self.run_main(self.write("r.yaml", "rules:\n- x:\n    header: ['a@b(']\n"), self.write("s.yaml", SAFE_OK))
        self.assertEqual(code, 0, out)
        self.assertIn("[YAML NOT READ] rules.yaml line 3", out)

    def test_empty_flow_list_is_not_reported(self):
        _code, out = self.run_main(self.write("r.yaml", RULES_OK), self.write("s.yaml", SAFE_OK))
        self.assertNotIn("NOT READ", out)

    def test_test_regex_option_does_not_claim_to_test(self):
        _code, out = self.run_main(self.write("r.yaml", RULES_OK), self.write("s.yaml", SAFE_OK), "--test-regex")
        self.assertIn("is not implemented", out)
        self.assertNotIn("feature available", out)


if __name__ == "__main__":
    unittest.main()
