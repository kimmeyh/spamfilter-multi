"""Tests for mobile-app/scripts/generate-test-emails.py (port of generate-test-emails.ps1, F334, Sprint 85).

The generator and the templates come from send-test-emails.py; these tests cover this script's own logic:
argument ranges, the spam/legitimate split, the dry-run and write behavior, the provider path choice, and
that nothing is sent. The send_* functions are replaced with recorders, so no network call can happen.

Run: python -I -m unittest discover -s scripts/tests -v

Test list and what each does NOT catch:
  test_split_uses_truncation_like_the_original: count 10 at ratio 0.75 -> 7 spam and 3 legitimate. NOT caught:
      a ratio that is not exact in binary (0.7 * 10 = 7.000000000000001 in some paths; int() truncates).
  test_count_and_ratio_ranges_are_argparse_errors: 0 or 1001 emails, a ratio of 1.5 -> exit 2. NOT caught:
      a non-numeric value that argparse accepts (it does not; the float and int parsers reject it).
  test_dry_run_writes_no_file_and_sends_nothing: no JSON file and no send call. NOT caught: a dry run that
      writes to a folder other than the one the test looks in.
  test_write_creates_json_and_reports_not_sent: a JSON file with one entry per email and the NOT SENT line.
      NOT caught: a JSON file with the right count but wrong field types (the test checks counts and keys).
  test_gmail_uses_api_path_others_use_smtp: the provider selects the send function. NOT caught: a provider
      that is later implemented (the test asserts which path is taken, not that it sends).
  test_templates_are_the_shared_set_without_dollar_interpolation: the subjects keep "$1,000,000" and
      "$5000" intact (PowerShell read them as variables). NOT caught: a new template with a "$" that is
      not one of the two known strings.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parent.parent.parent
SCRIPTS = REPO / "mobile-app" / "scripts"
TOOL = SCRIPTS / "generate-test-emails.py"


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


tool = load("generate_test_emails_mod", TOOL)
send = tool.send  # the reused module, loaded once by the tool


class GenerateTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.sent: list[str] = []
        self._patches = [
            mock.patch.object(send, "send_emails_gmail_api", side_effect=lambda e, c: self.sent.append("gmail")),
            mock.patch.object(send, "send_emails_smtp", side_effect=lambda e, c: self.sent.append("smtp")),
        ]
        for patch in self._patches:
            patch.start()

    def tearDown(self) -> None:
        for patch in self._patches:
            patch.stop()
        self._tmp.cleanup()

    def run_main(self, *argv: str) -> tuple[int, str]:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = tool.main(list(argv))
        return code, buf.getvalue()

    def test_split_uses_truncation_like_the_original(self) -> None:
        out_file = self.tmp / "split.json"
        code, out = self.run_main("--count", "10", "--spam-ratio", "0.75", "--output", str(out_file))
        self.assertEqual(code, 0)
        self.assertIn("Spam emails: 7 (75%)", out)
        self.assertIn("Legitimate emails: 3", out)
        data = json.loads(out_file.read_text(encoding="utf-8"))
        self.assertEqual(sum(1 for e in data if e["type"] == "SPAM"), 7)

    def test_count_and_ratio_ranges_are_argparse_errors(self) -> None:
        for argv in (["--count", "0"], ["--count", "1001"], ["--spam-ratio", "1.5"]):
            with self.subTest(argv=argv), self.assertRaises(SystemExit) as caught, \
                    contextlib.redirect_stderr(io.StringIO()):
                tool.main(argv)
            self.assertEqual(caught.exception.code, 2)

    def test_dry_run_writes_no_file_and_sends_nothing(self) -> None:
        out_file = self.tmp / "dry.json"
        code, out = self.run_main("--dry-run", "--count", "5", "--output", str(out_file))
        self.assertEqual(code, 0)
        self.assertFalse(out_file.exists())
        self.assertEqual(self.sent, [])
        self.assertIn("[DRY RUN]", out)

    def test_write_creates_json_and_reports_not_sent(self) -> None:
        out_file = self.tmp / "emails.json"
        code, out = self.run_main("--count", "4", "--spam-ratio", "0.5", "--output", str(out_file))
        self.assertEqual(code, 0)
        data = json.loads(out_file.read_text(encoding="utf-8"))
        self.assertEqual(len(data), 4)
        self.assertEqual(set(data[0]), {"index", "type", "from_name", "from_email", "subject", "body", "timestamp"})
        self.assertIn("NOT SENT", out)

    def test_gmail_uses_api_path_others_use_smtp(self) -> None:
        self.run_main("--count", "2", "--output", str(self.tmp / "g.json"), "--email-provider", "Gmail")
        self.run_main("--count", "2", "--output", str(self.tmp / "y.json"), "--email-provider", "Yahoo")
        self.assertEqual(self.sent, ["gmail", "smtp"])

    def test_templates_are_the_shared_set_without_dollar_interpolation(self) -> None:
        subjects = [t["subject"] for t in send.SPAM_TEMPLATES]
        self.assertIn("You've won $1,000,000!", subjects)
        self.assertIn("Earn $5000/month working from home!", subjects)


if __name__ == "__main__":
    unittest.main()
