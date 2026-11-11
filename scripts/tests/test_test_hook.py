"""Tests for scripts/test-hook.py (F329, Sprint 85).

Fake hooks (tiny .py files in a throwaway repo) exit 0, 2, 1 or hang, and echo what they received, so each
verdict, assertion and exit code of the probe is checked, including the Sprint 83 rule that a crashed hook is
never a success.

What these tests do NOT catch: a payload shape the real harness sends that this script does not (the fake hook
only echoes the fields the script builds); the PowerShell dispatch branch for a .ps1 hook (no .ps1 hook remains,
so the branch is checked only by its not-found message); behavior when `python` on PATH is a different
interpreter from the one running the tests.
Run: python -I -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("test_hook", SCRIPTS / "test-hook.py")
th = importlib.util.module_from_spec(spec)
spec.loader.exec_module(th)

ECHO = ("import sys\nd = sys.stdin.buffer.read().decode('utf-8')\nprint('GOT ' + d)\n"
        "sys.stderr.write('stderr-line\\n')\nsys.exit({code})\n")


@unittest.skipUnless(shutil.which("python"), "test-hook.py runs hooks with 'python' on PATH, as settings.json does")
class ProbeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name)
        (self.repo / ".claude" / "hooks").mkdir(parents=True)

    def hook(self, name: str, code: int = 0, body: str | None = None) -> None:
        (self.repo / ".claude" / "hooks" / name).write_text(body or ECHO.format(code=code), encoding="utf-8")

    def probe(self, *args: str):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = th.main(list(args), repo_root=self.repo)
        return code, out.getvalue()

    def test_allow_verdict_and_expect_allow_passes(self):
        self.hook("h.py", 0)
        code, out = self.probe("h.py", "--command", "git status", "--expect-allow")
        self.assertEqual(code, 0)
        self.assertIn("verdict : ALLOW", out)
        self.assertIn("PASS", out)

    def test_block_verdict_and_expect_block_passes(self):
        self.hook("h.py", 2)
        code, out = self.probe("h.py", "--command", "git stash", "--expect-block")
        self.assertEqual(code, 0)
        self.assertIn("verdict : BLOCK (exit 2)", out)

    def test_expect_block_fails_on_an_allowing_hook(self):
        self.hook("h.py", 0)
        code, out = self.probe("h.py", "--command", "x", "--expect-block")
        self.assertEqual(code, 1)
        self.assertIn("FAIL: expected BLOCK (exit 2), got ALLOW.", out)

    def test_expect_allow_fails_on_a_blocking_hook(self):
        self.hook("h.py", 2)
        self.assertEqual(self.probe("h.py", "--command", "x", "--expect-allow")[0], 1)

    def test_crashed_hook_is_never_a_block_and_never_a_success(self):
        self.hook("h.py", 1)
        code, out = self.probe("h.py", "--command", "x", "--expect-block")
        self.assertEqual(code, 1)
        self.assertIn("HOOK ERROR (exit 1, the command is ALLOWED)", out)
        self.assertEqual(self.probe("h.py", "--command", "x")[0], 1, "a crash fails even with no --expect switch")
        self.assertEqual(self.probe("h.py", "--command", "x", "--expect-allow")[0], 1)

    def test_diagnostic_output_is_printed_before_the_assertion_result(self):
        self.hook("h.py", 0)
        _, out = self.probe("h.py", "--command", "x", "--expect-block")
        self.assertLess(out.index("--- hook output ---"), out.index("FAIL:"))
        self.assertIn("  stderr-line", out)

    def test_payload_shapes(self):
        self.hook("h.py", 0)
        _, out = self.probe("h.py", "--command", "git status")
        got = json.loads(out.split("GOT ", 1)[1].splitlines()[0])
        self.assertEqual((got["tool_name"], got["tool_input"]["command"]), ("Bash", "git status"))
        _, out = self.probe("h.py", "--message", "Starting now.")
        got = json.loads(out.split("GOT ", 1)[1].splitlines()[0])
        self.assertEqual((got["hook_event_name"], got["last_assistant_message"]), ("Stop", "Starting now."))
        _, out = self.probe("h.py", "--json", '{"custom": 1}')
        self.assertIn('GOT {"custom": 1}', out)

    def test_non_ascii_command_reaches_the_hook_intact(self):
        self.hook("h.py", 0)
        _, out = self.probe("h.py", "--command", "echo café •")
        got = json.loads(out.split("GOT ", 1)[1].splitlines()[0])
        self.assertEqual(got["tool_input"]["command"], "echo café •")

    def test_cwd_is_reported_and_sent(self):
        self.hook("h.py", 0)
        fixture = self.repo / "fx"
        fixture.mkdir()
        _, out = self.probe("h.py", "--message", "m", "--cwd", str(fixture))
        self.assertIn(f"cwd     : {fixture.resolve()}", out)
        self.assertEqual(json.loads(out.split("GOT ", 1)[1].splitlines()[0])["cwd"], str(fixture.resolve()))

    def test_more_than_one_payload_switch_is_exit_2(self):
        self.hook("h.py", 0)
        code, out = self.probe("h.py", "--command", "a", "--message", "b")
        self.assertEqual(code, 2)
        self.assertIn("Supply only one", out)

    def test_no_payload_switch_is_exit_2(self):
        self.hook("h.py", 0)
        self.assertEqual(self.probe("h.py")[0], 2)

    def test_hook_not_found_is_exit_2(self):
        code, out = self.probe("absent.py", "--command", "x")
        self.assertEqual(code, 2)
        self.assertIn("Hook not found: absent.py", out)

    def test_hook_resolves_as_given_repo_relative_or_bare(self):
        self.hook("h.py", 0)
        absolute = str(self.repo / ".claude" / "hooks" / "h.py")
        for ref in (absolute, ".claude/hooks/h.py", "h.py"):
            self.assertEqual(self.probe(ref, "--command", "x", "--expect-allow")[0], 0, ref)

    def test_hook_that_hangs_is_exit_1(self):
        self.hook("h.py", body="import sys, time\nsys.stdin.buffer.read()\ntime.sleep(60)\n")
        with mock.patch.object(th, "HOOK_TIMEOUT_SECONDS", 1):
            code, out = self.probe("h.py", "--command", "x")
        self.assertEqual(code, 1)
        self.assertIn("ran past 1 seconds", out)

    def test_python_missing_from_path_is_exit_2(self):
        self.hook("h.py", 0)
        with mock.patch.object(th.shutil, "which", return_value=None):
            code, out = self.probe("h.py", "--command", "x")
        self.assertEqual(code, 2)
        self.assertIn('runs hooks with "python"', out)

    def test_a_real_hook_blocks_through_the_probe(self):
        real = io.StringIO()
        with contextlib.redirect_stdout(real):
            code = th.main(["block-carry-forward-stash.py", "--command", "git stash push -m wip", "--expect-block"])
        self.assertEqual(code, 0, real.getvalue())
        self.assertIn("[BLOCKED] git stash", real.getvalue())


class VerdictTests(unittest.TestCase):
    def test_verdict_words(self):
        self.assertEqual(th.verdict_of(0), "ALLOW")
        self.assertEqual(th.verdict_of(2), "BLOCK (exit 2)")
        self.assertEqual(th.verdict_of(3), "HOOK ERROR (exit 3, the command is ALLOWED)")


if __name__ == "__main__":
    unittest.main()
