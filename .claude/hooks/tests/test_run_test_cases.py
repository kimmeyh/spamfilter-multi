"""Tests for .claude/hooks/run-test-cases.py (F329, Sprint 85; AC-1).

The runner is a gate over every hook, so these tests feed it tiny FAKE hooks and fake case folders and check
each rule it applies: allow- expects exit 0 and no warning, violation- expects exit 2, warn- expects exit 0 and a
warning, an unknown prefix or a missing route folder is a failure (they were a silent SKIP), a hook that crashes
or hangs is a failure, and the fixture placeholders are filled with real git repos and real lock folders.
One test runs the REAL staging-guard route to show the runner and the recorded cases agree.

What these tests do NOT catch: a hook that behaves differently under the runner than under Claude Code (stdin
framing); a recorded case that is wrong in the same way as the hook (the runner trusts the case name); the
other seven real routes (the whole-suite count is compared by hand in the sprint plan, AC-1).
Run: python -I -m unittest discover -s .claude/hooks/tests -v
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

HOOKS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HOOKS / "lib"))
import common  # noqa: E402

spec = importlib.util.spec_from_file_location("run_test_cases", HOOKS / "run-test-cases.py")
rtc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rtc)

EXIT0 = "import sys\nsys.stdin.buffer.read()\nsys.exit(0)\n"
EXIT2 = "import sys\nsys.stdin.buffer.read()\nsys.exit(2)\n"
EXIT1 = "import sys\nsys.stdin.buffer.read()\nsys.exit(1)\n"
WARN0 = ("import sys, json\nsys.stdin.buffer.read()\n"
         "print(json.dumps({'hookSpecificOutput': {'additionalContext': 'careful'}}))\nsys.exit(0)\n")
WORD_ONLY0 = "import sys\nsys.stdin.buffer.read()\nprint('additionalContext')\nsys.exit(0)\n"  # not JSON: not a warning
HANG = "import sys, time\nsys.stdin.buffer.read()\ntime.sleep(60)\n"
# Exits 0 only when the placeholders were filled with real fixtures.
FIXTURE_CHECK = (
    "import json, os, subprocess, sys\n"
    "p = json.loads(sys.stdin.buffer.read().decode('utf-8'))\n"
    "mod, staged = p['repo_modified'], p['repo_staged']\n"
    "def porcelain(r):\n"
    "    return subprocess.run(['git', '-C', r, 'status', '--porcelain'], capture_output=True, text=True).stdout\n"
    "ok = porcelain(mod).startswith(' M docs/CODING_VELOCITY.md') and porcelain(staged).startswith('M  docs/CODING_VELOCITY.md')\n"
    "sys.exit(0 if ok else 1)\n"
)
# Reports the lock state of the four commit-lock placeholders and whether CLAUDE_PROJECT_DIR reached it.
LOCK_CHECK = (
    "import json, os, sys\n"
    "from datetime import datetime, timezone\n"
    "p = json.loads(sys.stdin.buffer.read().decode('utf-8'))\n"
    "if os.environ.get('CLAUDE_PROJECT_DIR'):\n"
    "    sys.exit(1)\n"
    "d = os.path.join(p['cwd'], '.claude', 'mutation-locks')\n"
    "kind = p['kind']\n"
    "have = os.path.isdir(d)\n"
    "if kind == 'NONE':\n"
    "    sys.exit(0 if not have else 1)\n"
    "raw = open(os.path.join(d, 'a.md.json'), encoding='utf-8').read()\n"
    "if kind == 'BAD':\n"
    "    try:\n        json.loads(raw)\n        sys.exit(1)\n    except ValueError:\n        sys.exit(0)\n"
    "t = datetime.strptime(json.loads(raw)['createdUtc'][:19], '%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc)\n"
    "age = (datetime.now(timezone.utc) - t).total_seconds() / 60\n"
    "sys.exit(0 if (age < 5 if kind == 'ACTIVE' else 55 < age < 65) else 1)\n"
)


class RunnerBase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.hooks = self.root / "hooks"
        self.cases = self.root / "cases"
        self.hooks.mkdir()
        self.cases.mkdir()

    def hook(self, name: str, body: str) -> None:
        (self.hooks / name).write_text(body, encoding="utf-8")

    def case(self, route: str, name: str, payload="{}") -> None:
        folder = self.cases / route if route else self.cases
        folder.mkdir(exist_ok=True)
        text = payload if isinstance(payload, str) else json.dumps(payload)
        (folder / f"{name}.json").write_text(text, encoding="utf-8")

    def run_suite(self, routes: dict, only=None):
        lines: list = []
        passed, failed = rtc.run_all(only, cases_dir=self.cases, hooks_dir=self.hooks, routes=routes,
                                     out=lines.append)
        return passed, failed, lines


class PrefixRuleTests(RunnerBase):
    def test_each_prefix_rule_passes_when_the_hook_agrees(self):
        self.hook("allow.py", EXIT0)
        self.hook("block.py", EXIT2)
        self.hook("warn.py", WARN0)
        self.case("", "allow-1")
        self.case("b", "violation-1")
        self.case("w", "warn-1")
        passed, failed, lines = self.run_suite({"": "allow.py", "b": "block.py", "w": "warn.py"})
        self.assertEqual((passed, failed), (3, 0), lines)
        self.assertIn("PASS b/violation-1 (exit 2)", lines)

    def test_violation_case_fails_when_the_hook_allows(self):
        self.hook("allow.py", EXIT0)
        self.case("", "violation-1")
        passed, failed, lines = self.run_suite({"": "allow.py"})
        self.assertEqual((passed, failed), (0, 1))
        self.assertIn("FAIL violation-1 (expected 2, got 0; warning printed: False)", lines)

    def test_allow_case_fails_when_the_hook_blocks(self):
        self.hook("block.py", EXIT2)
        self.case("", "allow-1")
        self.assertEqual(self.run_suite({"": "block.py"})[:2], (0, 1))

    def test_allow_case_fails_when_the_hook_crashes_exit_1(self):
        self.hook("crash.py", EXIT1)
        self.case("", "allow-1")
        passed, failed, lines = self.run_suite({"": "crash.py"})
        self.assertEqual((passed, failed), (0, 1))
        self.assertIn("got 1", lines[0])

    def test_warn_case_needs_a_json_warning(self):
        self.hook("quiet.py", EXIT0)
        self.hook("word.py", WORD_ONLY0)
        self.case("q", "warn-1")
        self.case("w", "warn-1")
        self.assertEqual(self.run_suite({"q": "quiet.py"}, None)[:2], (0, 1))
        self.assertEqual(self.run_suite({"w": "word.py"}, None)[:2], (0, 1), "the bare word is not a warning")

    def test_allow_case_fails_when_the_hook_prints_a_warning(self):
        self.hook("warn.py", WARN0)
        self.case("", "allow-1")
        self.assertEqual(self.run_suite({"": "warn.py"})[:2], (0, 1))

    def test_unknown_prefix_is_a_failure_not_a_skip(self):
        self.hook("allow.py", EXIT0)
        self.case("", "alow-typo")
        passed, failed, lines = self.run_suite({"": "allow.py"})
        self.assertEqual((passed, failed), (0, 1))
        self.assertTrue(lines[0].startswith("FAIL alow-typo (unknown prefix"), lines)

    def test_missing_route_folder_is_a_failure_and_missing_hook_is_a_runner_error(self):
        self.hook("allow.py", EXIT0)
        passed, failed, lines = self.run_suite({"nofolder": "allow.py"})
        self.assertEqual((passed, failed), (0, 1))
        self.assertIn("route folder missing", lines[0])
        with self.assertRaises(rtc.RunnerError):
            self.run_suite({"": "absent.py"})

    def test_unknown_only_route_is_a_runner_error_not_an_empty_pass(self):
        self.hook("allow.py", EXIT0)
        self.case("", "allow-1")
        with self.assertRaises(rtc.RunnerError) as caught:
            self.run_suite({"": "allow.py"}, ["staging-gaurd"])
        self.assertIn("unknown route(s): staging-gaurd", str(caught.exception))

    def test_route_folder_with_no_cases_is_a_failure(self):
        self.hook("allow.py", EXIT0)
        (self.cases / "empty").mkdir()
        passed, failed, lines = self.run_suite({"empty": "allow.py"})
        self.assertEqual((passed, failed), (0, 1))
        self.assertIn("route folder holds no cases", lines[0])

    def test_a_run_that_checked_nothing_exits_2_not_0(self):
        import contextlib
        import io
        with mock.patch.object(rtc, "run_all", return_value=(0, 0)), \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()) as err:
            self.assertEqual(rtc.main([]), 2)
        self.assertIn("no case ran", err.getvalue())

    def test_python_missing_from_path_is_a_runner_error(self):
        self.hook("allow.py", EXIT0)
        self.case("", "allow-1")
        with mock.patch.object(common, "find_tool", return_value=None):
            with self.assertRaises(rtc.RunnerError):
                self.run_suite({"": "allow.py"})

    def test_default_interpreter_is_python_on_path(self):
        self.hook("allow.py", EXIT0)
        self.case("", "allow-1")
        seen = []

        def spy(python, *args, **kwargs):
            seen.append(python)
            return 0, ""

        with mock.patch.object(rtc, "run_hook", spy), \
                mock.patch.object(common, "find_tool", return_value="PYTHON-FROM-PATH") as lookup:
            self.run_suite({"": "allow.py"})
        self.assertEqual(seen, ["PYTHON-FROM-PATH"], "not sys.executable")
        lookup.assert_called_once_with("python", "python3")

    def test_hook_that_hangs_is_a_failure(self):
        self.hook("hang.py", HANG)
        self.case("", "allow-1")
        with mock.patch.object(rtc, "CASE_TIMEOUT_SECONDS", 1):
            passed, failed, lines = self.run_suite({"": "hang.py"})
        self.assertEqual((passed, failed), (0, 1))
        self.assertIn("timed out", lines[0])

    def test_only_route_filters_and_top_level_ignores_subfolders(self):
        self.hook("allow.py", EXIT0)
        self.hook("block.py", EXIT2)
        self.case("", "allow-1")
        self.case("sub", "violation-1")
        self.assertEqual(self.run_suite({"": "allow.py", "sub": "block.py"}, ["(top)"])[:2], (1, 0))
        self.assertEqual(self.run_suite({"": "allow.py", "sub": "block.py"}, ["sub"])[:2], (1, 0))
        passed, failed, _ = self.run_suite({"": "allow.py", "sub": "block.py"})
        self.assertEqual((passed, failed), (2, 0), "the top level must not pick up the subfolder's case")

    def test_case_file_is_read_as_utf8_with_or_without_a_bom(self):
        self.hook("echo.py", "import sys\nd = sys.stdin.buffer.read().decode('utf-8')\nsys.exit(0 if 'caf\\u00e9' in d else 1)\n")
        (self.cases / "allow-1.json").write_bytes('{"t": "café"}'.encode("utf-8"))
        (self.cases / "allow-2.json").write_bytes(b"\xef\xbb\xbf" + '{"t": "café"}'.encode("utf-8"))
        self.assertEqual(self.run_suite({"": "echo.py"})[:2], (2, 0))


class FixtureTests(RunnerBase):
    def test_velocity_placeholders_are_real_git_repos_modified_and_staged(self):
        self.hook("fx.py", FIXTURE_CHECK)
        self.case("", "allow-1", {"repo_modified": "{{REPO_MODIFIED}}", "repo_staged": "{{REPO_STAGED}}"})
        self.assertEqual(self.run_suite({"": "fx.py"})[:2], (1, 0))

    def test_lock_placeholders_are_fresh_stale_bad_and_absent_and_the_project_dir_is_cleared(self):
        self.hook("lk.py", LOCK_CHECK)
        for kind in ("ACTIVE", "STALE", "BAD", "NONE"):
            self.case("commit-lock", f"allow-{kind.lower()}", {"kind": kind, "cwd": "{{LOCK_" + kind + "}}"})
        with mock.patch.dict(os.environ, {"CLAUDE_PROJECT_DIR": str(self.root)}):
            passed, failed, lines = self.run_suite({"commit-lock": "lk.py"})
        self.assertEqual((passed, failed), (4, 0), lines)

    def test_a_failed_fixture_git_call_stops_the_run(self):
        self.hook("allow.py", EXIT0)
        self.case("", "allow-1")
        with mock.patch.object(common, "git", return_value=(1, "")):
            with self.assertRaises(rtc.RunnerError):
                self.run_suite({"": "allow.py"})

    def test_fixture_locks_never_reach_the_project_dir_named_by_the_environment(self):
        """With CLAUDE_PROJECT_DIR naming a folder (in a hook context, the REAL repo), the fixture locks are
        still written inside the fixture projects, and the variable is put back afterwards."""
        real = self.root / "real_project"
        (real / ".claude").mkdir(parents=True)
        with mock.patch.dict(os.environ, {"CLAUDE_PROJECT_DIR": str(real)}):
            projects = rtc.build_lock_projects(self.root / "locks", "env")
            self.assertEqual(os.environ["CLAUDE_PROJECT_DIR"], str(real))
        self.assertFalse((real / ".claude" / "mutation-locks").exists())
        self.assertTrue((Path(projects["ACTIVE"]) / ".claude" / "mutation-locks" / "a.md.json").exists())

    def test_active_and_stale_fixture_locks_are_the_format_the_python_helper_writes(self):
        import mutation_lock
        projects = rtc.build_lock_projects(self.root / "locks", "fmt")
        for kind in ("ACTIVE", "STALE"):
            record = mutation_lock.read_lock(Path(projects[kind]) / ".claude" / "mutation-locks" / "a.md.json")
            self.assertEqual(set(record), {"file", "reason", "agent", "createdUtc"})
            self.assertEqual(record["agent"], "run-test-cases")

    def test_lock_projects_hold_the_documented_state(self):
        projects = rtc.build_lock_projects(self.root / "locks", "t")
        self.assertEqual(set(projects), {"ACTIVE", "STALE", "BAD", "NONE"})
        self.assertFalse((Path(projects["NONE"]) / ".claude" / "mutation-locks").exists())
        self.assertTrue((Path(projects["NONE"]) / ".claude").is_dir())
        stale = json.loads((Path(projects["STALE"]) / ".claude" / "mutation-locks" / "a.md.json").read_text())
        age = (common.utc_now() - common.parse_utc(stale["createdUtc"])).total_seconds() / 60
        self.assertTrue(59 < age < 62, age)


class RealRouteTests(unittest.TestCase):
    def test_real_staging_guard_route_passes_through_the_runner(self):
        lines: list = []
        passed, failed = rtc.run_all(["staging-guard"], out=lines.append)
        self.assertEqual(failed, 0, lines)
        self.assertEqual(passed, len(list((rtc.CASES_DIR / "staging-guard").glob("*.json"))))
        self.assertGreater(passed, 5)

    def test_every_recorded_case_name_has_a_known_prefix(self):
        for route in rtc.ROUTES:
            folder = rtc.CASES_DIR / route if route else rtc.CASES_DIR
            for case in folder.glob("*.json"):
                self.assertIsNotNone(rtc.expected_exit(case.stem), case)

    def test_routes_name_existing_hooks(self):
        for hook in rtc.ROUTES.values():
            self.assertTrue((HOOKS / hook).is_file(), hook)

    def test_every_case_folder_is_a_route(self):
        """A new test-cases/<folder> that no route names would never run."""
        folders = {p.name for p in rtc.CASES_DIR.iterdir() if p.is_dir() and p.name != "fixtures"}
        self.assertEqual(folders, {route for route in rtc.ROUTES if route})

    def test_command_line_exit_codes(self):
        import contextlib
        import io
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = rtc.main(["--only-route", "staging-guard"])
        self.assertEqual(code, 0)
        self.assertIn("Result: ", out.getvalue())

    def test_command_line_exit_code_1_for_a_failed_case_and_2_for_a_runner_error(self):
        import contextlib
        import io
        with mock.patch.object(rtc, "run_all", return_value=(3, 1)), \
                contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(rtc.main([]), 1)
        self.assertIn("Result: 3 passed, 1 failed, 4 total", out.getvalue())
        with mock.patch.object(rtc, "run_all", side_effect=rtc.RunnerError("boom")), \
                contextlib.redirect_stderr(io.StringIO()) as err:
            self.assertEqual(rtc.main([]), 2)
        self.assertIn("RUNNER ERROR: boom", err.getvalue())


if __name__ == "__main__":
    unittest.main()
