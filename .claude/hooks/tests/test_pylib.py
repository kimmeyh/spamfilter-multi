"""Tests for the shared Python hook layer and the pilot hooks (F321, Sprint 83, ADR-0051).

Standard library `unittest` only (no pytest, no new dependency). Run from the repo root:

    python .claude/hooks/tests/test_pylib.py            (Windows: python, Linux CI: python3)

Three groups:
  1. the shared layer (common.py, hooklib.py, mutation_lock.py);
  2. the pilot hooks end to end through a subprocess (stdin payload in, exit code and stderr out),
     including the Windows defect class: non-ASCII text while the console code page is cp1252;
  3. a REPLAY of every PowerShell-suite case for the pilot hooks (test-cases/staging-guard,
     heredoc-guard, commit-lock) through the Python `decide` functions. This is what makes the
     Linux CI run prove the hooks, not only the library. allow-* expects exit 0 and violation-*
     expects exit 2, the same rule run-test-cases.ps1 applies.

What these tests do NOT catch: a difference between PowerShell and Python regex behavior on an
input none of the 100-odd recorded cases contains; a hook registration typo in
.claude/settings.json (test_settings_registers_each_pilot_hook only checks the file names and the
command form, not that Claude Code runs them); and the live harness stdin framing, which only a
real tool call exercises.
"""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

HOOKS = Path(__file__).resolve().parent.parent
REPO = HOOKS.parent.parent
CASES = HOOKS / "test-cases"
sys.path.insert(0, str(HOOKS / "lib"))

import common  # noqa: E402
import hooklib  # noqa: E402
import mutation_lock  # noqa: E402


def load_hook(filename: str):
    """Import a hook file whose name has hyphens."""
    spec = importlib.util.spec_from_file_location(filename.replace("-", "_").replace(".py", ""),
                                                  HOOKS / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


_SAVED_PROJECT_DIR = None


def setUpModule():
    """Sprint 83 7.7.1 (code-reviewer pass 2 F2): in-process tests call mutation_lock and
    decide(), which prefer CLAUDE_PROJECT_DIR over the folder the test passes. With the
    variable set (a hook context, a dev shell), remove_lock(None) would delete the REAL repo's
    live locks. Clear it for the whole module; restore it afterwards."""
    global _SAVED_PROJECT_DIR
    _SAVED_PROJECT_DIR = os.environ.pop("CLAUDE_PROJECT_DIR", None)


def tearDownModule():
    if _SAVED_PROJECT_DIR is not None:
        os.environ["CLAUDE_PROJECT_DIR"] = _SAVED_PROJECT_DIR


def clean_env(**extra) -> dict:
    env = {k: v for k, v in os.environ.items() if k != "CLAUDE_PROJECT_DIR"}
    env.update(extra)
    return env


def run_hook(filename: str, stdin: bytes, **extra_env):
    done = subprocess.run([sys.executable, str(HOOKS / filename)], input=stdin,
                          capture_output=True, env=clean_env(**extra_env), timeout=60)
    return done.returncode, done.stdout.decode("utf-8", "replace"), done.stderr.decode("utf-8", "replace")


def write_lock(project: Path, file: str, created: datetime, bom: bool = False, raw: str | None = None):
    folder = project / ".claude" / "mutation-locks"
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / mutation_lock.safe_name(file)
    text = raw if raw is not None else json.dumps({
        "file": file, "reason": "test", "agent": "unit-test", "createdUtc": common.format_utc(created)})
    path.write_bytes((b"\xef\xbb\xbf" if bom else b"") + text.encode("utf-8"))
    return path


class CommonTests(unittest.TestCase):
    def test_normalize_path_backslash_to_slash(self):
        self.assertEqual(common.normalize_path("D:\\a\\b/c"), "D:/a/b/c")

    def test_parse_utc_powershell_o_format(self):
        got = common.parse_utc("2026-11-01T12:34:56.1234567Z")
        self.assertEqual(got, datetime(2026, 11, 1, 12, 34, 56, 123456, tzinfo=timezone.utc))

    def test_parse_utc_offset_is_converted(self):
        self.assertEqual(common.parse_utc("2026-11-01T12:00:00+02:00"),
                         datetime(2026, 11, 1, 10, 0, tzinfo=timezone.utc))

    def test_parse_utc_without_offset_is_utc(self):
        self.assertEqual(common.parse_utc("2026-11-01T12:00:00"),
                         datetime(2026, 11, 1, 12, 0, tzinfo=timezone.utc))

    def test_parse_utc_rejects_garbage(self):
        for bad in ("", "yesterday", None, "2026-13-45T99:99:99Z"):
            with self.assertRaises(ValueError):
                common.parse_utc(bad)

    def test_format_utc_round_trips_with_seven_digits(self):
        moment = datetime(2026, 11, 1, 1, 2, 3, 456789, tzinfo=timezone.utc)
        text = common.format_utc(moment)
        self.assertRegex(text, r"^2026-11-01T01:02:03\.\d{7}Z$")
        self.assertEqual(common.parse_utc(text), moment)

    def test_find_project_root_prefers_environment(self):
        with tempfile.TemporaryDirectory() as tmp:
            old = os.environ.get("CLAUDE_PROJECT_DIR")
            os.environ["CLAUDE_PROJECT_DIR"] = tmp
            try:
                self.assertEqual(common.find_project_root("/nonexistent"), Path(tmp))
            finally:
                if old is None:
                    del os.environ["CLAUDE_PROJECT_DIR"]
                else:
                    os.environ["CLAUDE_PROJECT_DIR"] = old

    def test_find_project_root_walks_up_to_git_or_claude(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            (root / ".git").mkdir()
            deep = root / "a" / "b"
            deep.mkdir(parents=True)
            old = os.environ.pop("CLAUDE_PROJECT_DIR", None)
            try:
                self.assertEqual(common.find_project_root(deep), root)
                (root / ".git").rmdir()
                (root / "a" / ".claude").mkdir()
                self.assertEqual(common.find_project_root(deep), root / "a")
            finally:
                if old is not None:
                    os.environ["CLAUDE_PROJECT_DIR"] = old


class HooklibTests(unittest.TestCase):
    def test_parse_payload_fails_open_to_empty_dict(self):
        for raw in ("", "   ", "not json", "[1, 2]", "42", "null", '"text"'):
            self.assertEqual(hooklib.parse_payload(raw), {}, raw)

    def test_parse_payload_reads_an_object(self):
        self.assertEqual(hooklib.command_of(hooklib.parse_payload(
            '{"tool_name":"Bash","tool_input":{"command":"git status"}}')), "git status")

    def test_command_of_ignores_other_shapes(self):
        self.assertEqual(hooklib.command_of({"tool_input": "x"}), "")
        self.assertEqual(hooklib.command_of({"tool_input": {"file_path": "a"}}), "")

    def test_run_allows_when_decide_raises(self):
        with tempfile.TemporaryDirectory() as tmp:
            script = Path(tmp) / "boom.py"
            script.write_text(
                "import sys\nsys.path.insert(0, %r)\nimport hooklib\n"
                "def decide(p):\n    raise RuntimeError('boom')\n"
                "hooklib.run('boom', decide)\n" % str(HOOKS / "lib"), encoding="utf-8")
            done = subprocess.run([sys.executable, str(script)], input=b"{}", capture_output=True, timeout=60)
        # 1, not 0: a non-blocking error whose note Claude Code shows (5.1.2 F6).
        # Exit 0 would hide the note; exit 2 would block the command.
        self.assertEqual(done.returncode, hooklib.HOOK_ERROR)
        self.assertEqual(hooklib.HOOK_ERROR, 1)
        self.assertIn(b"internal error, command allowed", done.stderr)


class PilotHookProcessTests(unittest.TestCase):
    HOOK_FILES = ("block-blind-staging.py", "block-heredoc-python-backslash.py",
                  "block-commit-during-mutation.py")

    def test_every_hook_fails_open_on_malformed_payloads(self):
        for hook in self.HOOK_FILES:
            for stdin in (b"", b"   \n", b"not json at all", b"[1,2,3]", b"\xff\xfe\x00bad bytes", b'{"tool_input":5}'):
                code, _out, _err = run_hook(hook, stdin)
                self.assertEqual(code, 0, f"{hook} stdin={stdin!r}")

    def test_blind_staging_blocks_with_non_ascii_text_under_cp1252(self):
        # Windows defect class: the console code page cannot encode the quoted command. The
        # block must still happen (exit 2), not turn into a Python crash (exit 1).
        payload = json.dumps({"tool_name": "Bash", "tool_input": {
            "command": "git add -A  # caf\u00e9 \u201cquoted\u201d"}}, ensure_ascii=False).encode("utf-8")
        code, _out, err = run_hook("block-blind-staging.py", payload,
                                   PYTHONUTF8="0", PYTHONIOENCODING="cp1252")
        self.assertEqual(code, 2, err)
        self.assertIn("[BLOCKED] Staging everything without looking first", err)
        self.assertIn("caf\u00e9", err)

    def test_blind_staging_reads_utf8_stdin_with_bom(self):
        payload = b"\xef\xbb\xbf" + json.dumps({"tool_name": "Bash", "tool_input": {
            "command": "git add ."}}).encode("utf-8")
        code, _out, _err = run_hook("block-blind-staging.py", payload)
        self.assertEqual(code, 2)

    def test_bypass_tokens_allow(self):
        cases = {"block-blind-staging.py": "git add -A # allow_blind_staging",
                 "block-heredoc-python-backslash.py": "python -c 'print(1)\\n' # allow_heredoc_backslash"}
        for hook, command in cases.items():
            payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}}).encode()
            self.assertEqual(run_hook(hook, payload)[0], 0, hook)

    def test_heredoc_hook_message_text_is_the_gate_text(self):
        command = "python - <<'EOF'\nprint('a\\nb')\nEOF"
        payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}}).encode()
        code, _out, err = run_hook("block-heredoc-python-backslash.py", payload)
        self.assertEqual(code, 2)
        self.assertIn("[BLOCKED] Python run from a heredoc whose body contains a backslash.", err)
        self.assertIn("allow_heredoc_backslash", err)

    def test_settings_registers_each_pilot_hook_in_python_form(self):
        settings = json.loads((REPO / ".claude" / "settings.json").read_text(encoding="utf-8"))
        commands = [h["command"] for group in settings["hooks"]["PreToolUse"] for h in group["hooks"]]
        for hook in self.HOOK_FILES:
            matching = [c for c in commands if hook in c]
            self.assertEqual(len(matching), 1, f"{hook} must be registered exactly once")
            self.assertTrue(matching[0].startswith('python "${CLAUDE_PROJECT_DIR}/.claude/hooks/'), matching[0])
            self.assertNotIn("\\", matching[0])
            self.assertTrue((HOOKS / hook).exists())
        self.assertFalse([c for c in commands if "block-blind-staging.ps1" in c
                          or "block-heredoc-python-backslash.ps1" in c
                          or "block-commit-during-mutation.ps1" in c], "old PowerShell registration remains")


class MutationLockTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.project = Path(self._tmp.name).resolve()
        (self.project / ".git").mkdir()

    def tearDown(self):
        self._tmp.cleanup()

    def test_safe_name_matches_the_powershell_rule(self):
        self.assertEqual(mutation_lock.safe_name('docs/A:B*C?"D<E>F|G\\H.md'), "docs_A_B_C__D_E_F_G_H.md.json")

    def test_new_info_remove_round_trip(self):
        mutation_lock.new_lock("lib/a.dart", "prove red", "agent-1", start=str(self.project))
        rows = mutation_lock.lock_info(str(self.project))
        self.assertEqual([r["file"] for r in rows], ["lib/a.dart"])
        self.assertEqual(rows[0]["agent"], "agent-1")
        self.assertIn(rows[0]["ageMinutes"], (0, 1))
        self.assertEqual(mutation_lock.remove_lock("lib/a.dart", str(self.project)), 1)
        self.assertEqual(mutation_lock.lock_info(str(self.project)), [])

    def test_remove_without_file_releases_every_lock(self):
        for name in ("a", "b", "c"):
            mutation_lock.new_lock(name, "r", start=str(self.project))
        self.assertEqual(mutation_lock.remove_lock(None, str(self.project)), 3)

    def test_age_is_computed_in_utc(self):
        now = datetime(2026, 11, 1, 12, 0, tzinfo=timezone.utc)
        mutation_lock.new_lock("a", "r", start=str(self.project), now=now - timedelta(minutes=47))
        rows = mutation_lock.lock_info(str(self.project), now=now)
        self.assertEqual(rows[0]["ageMinutes"], 47)

    def test_reads_a_powershell_written_lock_with_bom_and_seven_digits(self):
        write_lock(self.project, "x.md", datetime.now(timezone.utc) - timedelta(minutes=5), bom=True)
        self.assertEqual(mutation_lock.lock_info(str(self.project))[0]["ageMinutes"], 5)

    def test_unreadable_lock_does_not_hide_the_others(self):
        write_lock(self.project, "good.md", datetime.now(timezone.utc))
        write_lock(self.project, "bad.md", datetime.now(timezone.utc), raw="{not json")
        rows = {Path(r["file"]).name if r["ageMinutes"] is None else r["file"]: r
                for r in mutation_lock.lock_info(str(self.project))}
        self.assertEqual(rows["good.md"]["ageMinutes"], 0)
        bad = [r for r in rows.values() if r["ageMinutes"] is None]
        self.assertEqual(len(bad), 1)
        self.assertIn("unreadable lock file", bad[0]["reason"])

    def test_command_line_info_prints_json(self):
        mutation_lock.new_lock("cli.md", "r", start=str(self.project))
        done = subprocess.run([sys.executable, str(HOOKS / "lib" / "mutation_lock.py"), "info"],
                              capture_output=True, text=True, env=clean_env(CLAUDE_PROJECT_DIR=str(self.project)),
                              timeout=60)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(json.loads(done.stdout)[0]["file"], "cli.md")


class CommitGateTests(unittest.TestCase):
    """Behavior the replay below cannot show: the stale lock is deleted, the active one is not."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.project = Path(self._tmp.name).resolve()
        self.hook = load_hook("block-commit-during-mutation.py")

    def tearDown(self):
        self._tmp.cleanup()

    def payload(self, command="git commit -q -m x"):
        return {"tool_name": "Bash", "cwd": str(self.project), "tool_input": {"command": command}}

    def test_stale_lock_is_deleted_and_active_lock_survives_with_a_shared_name_prefix(self):
        stale = write_lock(self.project, "same-prefix", datetime.now(timezone.utc) - timedelta(minutes=60))
        active = write_lock(self.project, "same-prefix-two", datetime.now(timezone.utc))
        verdict = self.hook.decide(self.payload())
        self.assertEqual(verdict.code, 2)
        self.assertFalse(stale.exists())
        self.assertTrue(active.exists())
        self.assertIn("same-prefix-two", verdict.stderr)
        self.assertIn("Ignoring 1 stale lock(s)", verdict.stdout)

    def test_block_text_is_on_stderr_not_stdout(self):
        write_lock(self.project, "a.md", datetime.now(timezone.utc))
        verdict = self.hook.decide(self.payload())
        self.assertIn("[BLOCKED] A mutation-test lock is held.", verdict.stderr)
        self.assertNotIn("[BLOCKED]", verdict.stdout)

    def test_override_notice_is_plain_text_never_json(self):
        write_lock(self.project, "a.md", datetime.now(timezone.utc))
        verdict = self.hook.decide(self.payload("allow_mutation_commit git commit -m x"))
        self.assertEqual(verdict.code, 0)
        self.assertIn("Override token present", verdict.stdout)


class AgentWorkStatusTests(unittest.TestCase):
    """scripts/agent-work-status.py keeps the output format of the PowerShell script it replaced."""

    def run_status(self, scratch: Path, project: Path):
        done = subprocess.run(
            [sys.executable, str(REPO / "scripts" / "agent-work-status.py"), "--scratch-folder", str(scratch)],
            capture_output=True, env=clean_env(CLAUDE_PROJECT_DIR=str(project)), timeout=60)
        self.assertEqual(done.returncode, 0, done.stderr.decode("utf-8", "replace"))
        return done.stdout.decode("utf-8").splitlines()

    def test_every_task_state_and_the_lock_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            scratch = Path(tmp) / "scratch"
            project = Path(tmp) / "project"
            project.mkdir()
            (scratch / "a_not_started").mkdir(parents=True)
            for name, text in {
                    "b_empty": "\n\n",
                    "c_progress": "UNIT one: DONE\nUNIT two: STARTED\nLAST STEP: wrote two\n",
                    "d_finished": "UNIT one: DONE\nLAST STEP: x\nSTATUS: FINISHED\n",
                    "e_units_only": "UNIT only: STARTED\n"}.items():
                (scratch / name).mkdir()
                (scratch / name / "progress.md").write_text(text, encoding="utf-8")
            write_lock(project, "old.md", datetime.now(timezone.utc) - timedelta(minutes=75))
            lines = self.run_status(scratch, project)
        self.assertEqual(lines[0], f"Scratch folder: {scratch}")
        self.assertEqual(lines[1], "Agent tasks:")
        self.assertEqual(lines[2:7], [
            "  a_not_started: not started",
            "  b_empty: started, nothing saved",
            "  c_progress: in progress (1/2 unit(s) done) -- LAST STEP: wrote two",
            "  d_finished: finished (1 unit(s) done; time not recorded)",
            "  e_units_only: in progress (0/1 unit(s) done) -- UNIT only: STARTED"])
        self.assertEqual(lines[7], "Mutation locks:")
        self.assertRegex(lines[8], r"^  old\.md -- test \(agent unit-test, 7[45] min\) \[OVER 1 HOUR\]$")
        self.assertRegex(lines[9], r"^Sprint phase: (Sprint \S+: .+|unknown)$")

    def test_run_time_adds_up_runs_split_by_stops(self):
        """Sprint 83 retro IMP-4: a task split by usage-limit stops still has a total, and
        an unknown time is never reported as 0 (IMP-3)."""
        spec = importlib.util.spec_from_file_location("aws_rt", REPO / "scripts" / "agent-work-status.py")
        aws = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(aws)
        self.assertEqual(aws.run_time([
            "RUN STARTED 2026-11-05 01:00", "UNIT a: DONE", "RUN STOPPED 2026-11-05 01:40",
            "RUN STARTED 2026-11-05 06:00", "RUN STOPPED 2026-11-05 06:25"]), "run time 65 min")
        self.assertEqual(aws.run_time(["UNIT a: DONE"]), "time not recorded")
        self.assertEqual(aws.run_time([
            "RUN STARTED 2026-11-05 01:00", "RUN STARTED 2026-11-05 02:00",
            "RUN STOPPED 2026-11-05 02:10"]), "run time 10 min + 1 run(s) with no RUN STOPPED")
        self.assertTrue(aws.run_time(["RUN STARTED soon"]).startswith("run time unknown"))

    def test_default_lookup_finds_this_projects_newest_session_under_any_parent(self):
        """Sprint 83 7.7.1 (code-reviewer L-4, silent-failure-hunter L-1): sessions live under
        <temp>/claude/<hash>/<session>/scratchpad. The lookup must find the newest session of
        THIS project there, and never another project's newer session."""
        spec = importlib.util.spec_from_file_location("aws", REPO / "scripts" / "agent-work-status.py")
        aws = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(aws)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "claude"
            old = root / aws.PROJECT_SLUG / "old-session" / "scratchpad"
            mine = root / "b424hash" / "mine-session" / "scratchpad"
            other = root / "b424hash" / "other-project-session" / "scratchpad"
            for i, p in enumerate([old, mine, other]):
                p.mkdir(parents=True)
                t = 1_700_000_000 + i * 100
                os.utime(p, (t, t))
            aws.claude_temp_roots = lambda: [root]
            aws.project_session_ids = lambda: {"mine-session", "old-session"}
            self.assertEqual(aws.newest_scratchpad(), mine)
            aws.project_session_ids = lambda: set()
            self.assertEqual(aws.newest_scratchpad(), old)

    def test_no_locks_and_missing_scratch_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp) / "project"
            project.mkdir()
            lines = self.run_status(Path(tmp) / "missing", project)
        self.assertIn("  (scratch folder not found)", lines)
        self.assertIn("  none held", lines)


def replay_cases(test_case, hook_file: str, folder: str):
    """Run every recorded case in test-cases/<folder> through the hook's decide()."""
    module = load_hook(hook_file)
    files = sorted((CASES / folder).glob("*.json"))
    test_case.assertGreater(len(files), 5, f"no cases found in {folder}")
    with tempfile.TemporaryDirectory() as tmp:
        fixtures = {}
        now = datetime.now(timezone.utc)
        for key, make in {
                "LOCK_ACTIVE": lambda p: write_lock(p, "a.md", now),
                "LOCK_NONE": lambda p: (p / ".claude").mkdir(parents=True, exist_ok=True),
                "LOCK_STALE": lambda p: write_lock(p, "a.md", now - timedelta(minutes=60)),
                "LOCK_BAD": lambda p: write_lock(p, "a.md", now, raw="{broken")}.items():
            folder_path = Path(tmp) / key.lower()
            folder_path.mkdir()
            make(folder_path)
            fixtures[key] = str(folder_path).replace("\\", "/")
        for case in files:
            text = case.read_text(encoding="utf-8")
            for key, value in fixtures.items():
                text = text.replace("{{" + key + "}}", value)
            expected = 0 if case.stem.startswith("allow-") else 2
            with test_case.subTest(case=f"{folder}/{case.stem}"):
                verdict = module.decide(json.loads(text))
                test_case.assertEqual(verdict.code, expected)
                if expected == 2:
                    test_case.assertTrue(verdict.stderr.startswith("[BLOCKED]"), verdict.stderr[:60])


class ReplayTests(unittest.TestCase):
    def test_staging_guard_cases(self):
        replay_cases(self, "block-blind-staging.py", "staging-guard")

    def test_heredoc_guard_cases(self):
        replay_cases(self, "block-heredoc-python-backslash.py", "heredoc-guard")

    def test_commit_lock_cases(self):
        replay_cases(self, "block-commit-during-mutation.py", "commit-lock")


if __name__ == "__main__":
    unittest.main(verbosity=2)
