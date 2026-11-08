"""Tests for the shared Python hook layer and the pilot hooks (F321, Sprint 83, ADR-0051).

Standard library `unittest` only (no pytest, no new dependency). Run from the repo root:

    python .claude/hooks/tests/test_pylib.py            (Windows: python, Linux CI: python3)

Three groups:
  1. the shared layer (common.py, hooklib.py, mutation_lock.py);
  2. the pilot hooks end to end through a subprocess (stdin payload in, exit code and stderr out),
     including the Windows defect class: non-ASCII text while the console code page is cp1252;
  3. a REPLAY of every PowerShell-suite case for the ported hooks (test-cases/staging-guard,
     heredoc-guard, commit-lock; Sprint 84 F326: stash-guard, sprint-cards, velocity-warn; F327:
     closeout, the Stop hook, with gh stubbed so no case needs the network; F328: the top-level
     sprint-auto-advance cases) through
     the Python `decide` functions. This is what makes the
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
import time
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


def drain_notices() -> list:
    """The notices queued by hooklib.notice in this process, and forget them (5.1.2 F6)."""
    got = list(hooklib._PENDING)
    hooklib._PENDING.clear()
    hooklib._NOTICES_SEEN.clear()
    return got


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


    def test_run_notices_unreadable_input_but_still_allows(self):
        """5.1.2 F6-3. Does NOT catch a hook that ignores a parsed-but-wrong payload (a JSON object with
        the wrong keys); only input that is not a JSON object is noticed. Does not prove Claude Code
        displays the systemMessage; it pins the one-object JSON on stdout and exit 0."""
        for stdin in (b"not json", b"[1,2]", b"42"):
            code, out, err = run_hook("require-sprint-cards.py", stdin)
            self.assertEqual((code, err), (0, ""), stdin)
            text = json.loads(out)["systemMessage"]
            self.assertIn("[require-sprint-cards] input unreadable (", text, stdin)
        for stdin in (b"", b"  \n", b"{}"):
            code, out, err = run_hook("require-sprint-cards.py", stdin)
            self.assertEqual((code, out, err), (0, "", ""), stdin)

    def test_apply_notices_merges_into_one_json_object_or_the_block_reason(self):
        """5.1.2 F6-2/F6-3 merge rule. Does NOT catch a hook whose JSON stdout is nested differently from a
        top-level object; and PLAIN TEXT stdout (block-commit-during-mutation) gets the notice on stderr,
        which Claude Code does not show at exit 0, so that case is not made visible."""
        apply = hooklib.apply_notices
        self.assertEqual(apply(hooklib.allow(), []), hooklib.allow())
        self.assertEqual(json.loads(apply(hooklib.allow(), ["a", "b"]).stdout), {"systemMessage": "a; b"})
        own = json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": "w"}})
        merged = apply(hooklib.allow(stdout=own), ["n"])
        self.assertEqual(json.loads(merged.stdout), {"hookSpecificOutput": {
            "hookEventName": "PreToolUse", "additionalContext": "w"}, "systemMessage": "n"})
        self.assertEqual(len(merged.stdout.splitlines()), 1)
        again = apply(hooklib.allow(stdout=hooklib.system_message("old")), ["n"])
        self.assertEqual(json.loads(again.stdout), {"systemMessage": "old; n"})
        blocked = apply(hooklib.block("[BLOCKED] x"), ["n"])
        self.assertEqual((blocked.code, blocked.stderr, blocked.stdout), (2, "[BLOCKED] x\n\nNote: n", ""))
        text = apply(hooklib.allow(stdout="plain notes"), ["n"])
        self.assertEqual((text.stdout, text.stderr), ("plain notes", "Note: n"))

    def test_run_merges_a_notice_into_the_json_the_hook_prints(self):
        """5.1.2 F6-2 end to end. Does NOT catch a hook that prints several JSON lines; it pins one object."""
        with tempfile.TemporaryDirectory() as tmp:
            script = Path(tmp) / "jsonhook.py"
            script.write_text(
                "import sys\nsys.path.insert(0, %r)\nimport hooklib\n"
                "def decide(p):\n    hooklib.notice('gate skipped')\n"
                "    return hooklib.allow(stdout='{\"hookSpecificOutput\": {\"additionalContext\": \"w\"}}')\n"
                "hooklib.run('jsonhook', decide)\n" % str(HOOKS / "lib"), encoding="utf-8")
            done = subprocess.run([sys.executable, str(script)], input=b"{}", capture_output=True, timeout=60)
        self.assertEqual((done.returncode, done.stderr), (0, b""))
        body = json.loads(done.stdout.decode("utf-8"))
        self.assertEqual(body["systemMessage"], "gate skipped")
        self.assertEqual(body["hookSpecificOutput"]["additionalContext"], "w")

    def test_gh_failure_codes_name_the_reason(self):
        """5.1.2 F6-1. Does NOT catch a gh that exits non-zero for a reason of its own; that code passes
        through and is only worded as 'gh exit code N'."""
        import subprocess as sp
        real_run = sp.run
        self.addCleanup(setattr, sp, "run", real_run)
        for exc, code, words in ((FileNotFoundError("gh"), common.GH_NOT_FOUND, "not installed"),
                                 (sp.TimeoutExpired("gh", 1), common.GH_TIMEOUT, "timed out"),
                                 (OSError("boom"), 1, "exit code 1")):
            def boom(*a, _e=exc, **k):
                raise _e
            sp.run = boom
            got, out = common.gh("pr", "list")
            self.assertEqual((got, out), (code, ""))
            self.assertIn(words, common.gh_failure_reason(got))


class PilotHookProcessTests(unittest.TestCase):
    HOOK_FILES = ("block-blind-staging.py", "block-heredoc-python-backslash.py",
                  "block-commit-during-mutation.py", "block-carry-forward-stash.py",
                  "require-sprint-cards.py", "warn-commit-without-velocity.py")

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
                          or "block-commit-during-mutation.ps1" in c
                          or "block-carry-forward-stash.ps1" in c
                          or "require-sprint-cards.ps1" in c
                          or "warn-commit-without-velocity.ps1" in c], "old PowerShell registration remains")


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


def git_run(repo: Path, *args: str) -> None:
    subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True)


def make_velocity_repos(root: Path) -> dict:
    """Two throwaway git repos for the velocity-warn cases, as run-test-cases.ps1 builds them:
    one with docs/CODING_VELOCITY.md modified, one with it staged."""
    repos = {}
    for kind in ("MODIFIED", "STAGED"):
        repo = root / kind.lower()
        (repo / "docs").mkdir(parents=True)
        (repo / "mobile-app").mkdir()
        git_run(repo, "init", "-q")
        (repo / "docs" / "CODING_VELOCITY.md").write_text("v1", encoding="utf-8")
        (repo / "a.txt").write_text("a", encoding="utf-8")
        (repo / "mobile-app" / "keep.txt").write_text("k", encoding="utf-8")
        git_run(repo, "add", "-A")
        git_run(repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "-m", "init")
        (repo / "docs" / "CODING_VELOCITY.md").write_text("v2", encoding="utf-8")
        if kind == "STAGED":
            git_run(repo, "add", "docs/CODING_VELOCITY.md")
        repos[kind] = str(repo).replace("\\", "/")
    return repos


def warning_of(stdout: str):
    """The additionalContext text of a hookSpecificOutput JSON, or None (the runner's rule)."""
    if not stdout:
        return None
    try:
        return json.loads(stdout)["hookSpecificOutput"]["additionalContext"]
    except (ValueError, KeyError, TypeError):
        return None


REPO_POSIX = REPO.as_posix()
RECORDED_REPO = "D:/Data/Harold/github/spamfilter-multi"  # where the closeout cases name their fixtures


def replay_cases(test_case, hook_file: str, folder: str, stub_gh: bool = False):
    """Run every recorded case in test-cases/<folder> through the hook's decide().

    allow-* expects exit 0 and no warning; warn-* expects exit 0 and a warning; violation-* expects
    exit 2 and a [BLOCKED] message. The same rule run-test-cases.ps1 applies."""
    module = load_hook(hook_file)
    files = sorted((CASES / folder).glob("*.json"))
    test_case.assertGreater(len(files), 5, f"no cases found in {folder}")
    if stub_gh:
        # Closeout cases must not depend on the network or a signed-in gh: with no GitHub answer
        # check 3c skips (fails open), which is what every recorded case expects.
        test_case.addCleanup(setattr, common, "gh", common.gh)
        common.gh = lambda *args, **kwargs: (1, "")
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
        for key, value in make_velocity_repos(Path(tmp) / "repos").items():
            fixtures["REPO_" + key] = value
        for case in files:
            text = case.read_text(encoding="utf-8").replace(RECORDED_REPO, REPO_POSIX)
            for key, value in fixtures.items():
                text = text.replace("{{" + key + "}}", value)
            expected = 2 if case.stem.startswith("violation-") else 0
            with test_case.subTest(case=f"{folder}/{case.stem}"):
                verdict = module.decide(json.loads(text))
                test_case.assertEqual(verdict.code, expected)
                warning = warning_of(verdict.stdout)
                if case.stem.startswith("warn-"):
                    test_case.assertIsNotNone(warning, "a warn-* case must print a warning")
                if case.stem.startswith("allow-"):
                    test_case.assertIsNone(warning, "an allow-* case must print no warning")
                if expected == 2:
                    test_case.assertTrue(verdict.stderr.startswith("[BLOCKED"), verdict.stderr[:60])


class ReplayTests(unittest.TestCase):
    def test_staging_guard_cases(self):
        replay_cases(self, "block-blind-staging.py", "staging-guard")

    def test_heredoc_guard_cases(self):
        replay_cases(self, "block-heredoc-python-backslash.py", "heredoc-guard")

    def test_commit_lock_cases(self):
        replay_cases(self, "block-commit-during-mutation.py", "commit-lock")

    def test_stash_guard_cases(self):
        replay_cases(self, "block-carry-forward-stash.py", "stash-guard")

    def test_sprint_cards_cases(self):
        replay_cases(self, "require-sprint-cards.py", "sprint-cards")

    def test_velocity_warn_cases(self):
        replay_cases(self, "warn-commit-without-velocity.py", "velocity-warn")

    def test_closeout_cases(self):
        replay_cases(self, "verify-closeout-complete.py", "closeout", stub_gh=True)

    def test_sprint_auto_advance_cases(self):
        """F328: the top-level cases (folder ""), the contract for the Stop hook, 71 files at the port."""
        replay_cases(self, "sprint-auto-advance.py", "")


class PortedHookTests(unittest.TestCase):
    """Behavior the recorded cases do not state in full: the message text, the JSON shape, and
    the exception path (R-6). Each test names what it does NOT catch in its docstring."""

    def test_stash_block_message_is_the_gate_text(self):
        """Does NOT catch a changed wording in the second paragraph; the first line is pinned."""
        module = load_hook("block-carry-forward-stash.py")
        verdict = module.decide({"tool_input": {"command": "git stash push -m x"}})
        self.assertEqual(verdict.code, 2)
        self.assertTrue(verdict.stderr.startswith(
            "[BLOCKED] git stash is disallowed for branch carry-forward."))
        self.assertIn("re-run the command with the literal token allow_stash", verdict.stderr)

    def test_stash_bypass_token_in_raw_command_allows(self):
        """Does NOT catch a bypass token that is only inside a quoted string; the PowerShell hook
        also honored one there, so the port keeps that (parity), it is not a defect to fix here."""
        module = load_hook("block-carry-forward-stash.py")
        verdict = module.decide({"tool_input": {"command": "echo \"allow_stash\"; git stash"}})
        self.assertEqual(verdict.code, 0)

    def test_stash_heredoc_body_without_quotes_is_data(self):
        """A heredoc body that names `git stash` outside any quotes is data, not an invocation.
        The recorded allow-3 case quotes its text, so the single-quote pass removes it anyway and
        cannot tell whether the heredoc pass runs. Does NOT catch a heredoc with a different
        delimiter spelling (`<<EOF` versus `<<'EOF'`); the regex accepts both, not tested here."""
        module = load_hook("block-carry-forward-stash.py")
        command = "cat <<EOF\ngit stash push\nEOF"
        self.assertEqual(module.decide({"tool_input": {"command": command}}).code, 0)

    def test_stash_top_level_command_field_is_checked(self):
        """Does NOT catch a stash issued through a tool whose payload carries no command field."""
        module = load_hook("block-carry-forward-stash.py")
        self.assertEqual(module.decide({"command": "git stash"}).code, 2)

    def test_sprint_cards_block_names_the_missing_pr_and_cards(self):
        """Does NOT catch a sprint whose status file is valid but names a PR that does not exist
        on GitHub; the hook reads the file, not the remote."""
        module = load_hook("require-sprint-cards.py")
        status = {"github_issues": [], "current_sprint": {"number": 84, "plan_approved": True}}
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "status.json"
            path.write_text(json.dumps(status), encoding="utf-8")
            verdict = module.decide({"tool_input": {"command": "git commit -m x"},
                                     "status_path_override": str(path)})
        self.assertEqual(verdict.code, 2)
        self.assertIn("[BLOCKED] Sprint 84 is missing a Phase 3.3.1 deliverable: GitHub issue cards "
                      "(`github_issues` has no entry for this sprint) AND a draft PR (`pr_number` is null).",
                      verdict.stderr)

    def test_sprint_cards_count_only_the_current_sprint_entry(self):
        """Sprint 84 7.7.1 (Copilot HIGH): the real file keys cards by `sprint_<N>`; an entry for an
        EARLIER sprint must not satisfy the gate. Does NOT catch a current entry that names cards
        which do not exist on GitHub; the hook reads the file, not the remote."""
        module = load_hook("require-sprint-cards.py")
        has = module.current_sprint_has_cards
        self.assertFalse(has({"sprint_83": "Task 1 #540", "note": "x"}, 84))
        self.assertFalse(has({"sprint_84": "  "}, 84))
        self.assertFalse(has({"sprint_84": []}, 84))
        self.assertFalse(has({"sprint_84": "Task 1 #550"}, None))
        self.assertTrue(has({"sprint_83": "Task 1 #540", "sprint_84": "Task 0 #549"}, 84))
        self.assertTrue(has({"sprint_84": [549]}, "84"))
        self.assertTrue(has([901], 84))
        self.assertFalse(has([], 84))

    def test_sprint_cards_unreadable_status_fails_open(self):
        """Does NOT catch a status file that parses but holds the wrong values; that is the
        recorded cases' job."""
        module = load_hook("require-sprint-cards.py")
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "status.json"
            path.write_bytes(b"\xff\xfe not json")
            verdict = module.decide({"tool_input": {"command": "git commit -m x"},
                                     "status_path_override": str(path)})
        self.assertEqual(verdict.code, 0)

    def test_status_unreadable_notice_only_when_the_file_exists(self):
        """5.1.2 F6-2. Does NOT catch a status file that parses but holds the wrong shape, and does not
        prove Claude Code shows the systemMessage; it pins that the notice is queued for run()."""
        cards = load_hook("require-sprint-cards.py")
        advance = load_hook("sprint-auto-advance.py")
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "status.json"
            bad.write_bytes(b"\xff\xfe not json")
            cwd = Path(tmp) / "proj"
            (cwd / ".claude").mkdir(parents=True)
            (cwd / ".claude" / "sprint_status.json").write_bytes(b"{bad")
            for label, call in (
                    ("cards", lambda: cards.decide({"tool_input": {"command": "git commit -m x"},
                                                    "status_path_override": str(bad)})),
                    ("advance", lambda: advance.load_status(str(cwd)))):
                drain_notices()
                call()
                queued = drain_notices()
                self.assertEqual(len(queued), 1, label)
                self.assertIn("sprint_status.json unreadable (", queued[0], label)
                self.assertIn("; sprint gates skipped", queued[0], label)
            # A MISSING file is the normal non-sprint state: silent.
            drain_notices()
            cards.decide({"tool_input": {"command": "git commit -m x"},
                          "status_path_override": str(Path(tmp) / "absent.json")})
            advance.load_status(str(Path(tmp) / "nowhere"))
            self.assertEqual(drain_notices(), [])

    def test_velocity_warning_is_hook_specific_output_json(self):
        """Does NOT catch a warning that Claude Code fails to display for another reason; it pins
        the JSON shape the runner and Claude Code both read."""
        module = load_hook("warn-commit-without-velocity.py")
        with tempfile.TemporaryDirectory() as tmp:
            cwd = make_velocity_repos(Path(tmp))["MODIFIED"]  # fixed state: velocity modified, not staged
            verdict = module.decide({"tool_name": "Bash", "cwd": cwd,
                                     "tool_input": {"command": "git commit -m \"fix: x\" -m \"Closes #9\""}})
        self.assertEqual(verdict.code, 0)
        body = json.loads(verdict.stdout)
        self.assertEqual(body["hookSpecificOutput"]["hookEventName"], "PreToolUse")
        self.assertIn("CODING_VELOCITY", body["hookSpecificOutput"]["additionalContext"])

    def test_velocity_names_an_unexpandable_message_file(self):
        """Does NOT catch a -F path that is a real file under a different spelling; it pins only
        the warning text for a path with a shell variable in it."""
        module = load_hook("warn-commit-without-velocity.py")
        with tempfile.TemporaryDirectory() as tmp:
            cwd = make_velocity_repos(Path(tmp))["MODIFIED"]
            verdict = module.decide({"tool_name": "Bash", "cwd": cwd, "tool_input": {
                "command": "git add a.txt; git commit -F \"$SCRATCH/msg.txt\""}})
        self.assertIn("$SCRATCH/msg.txt (a variable the hook cannot expand)", warning_of(verdict.stdout) or "")

    def test_velocity_exception_is_reported_not_silent(self):
        """R-6: an exception inside the check must surface as a warning that the check did not run.
        Does NOT catch an exception raised before decide() is entered (hooklib.run covers that with
        exit 1); it does not prove git itself works on the Windows runner."""
        module = load_hook("warn-commit-without-velocity.py")
        real_git = common.git

        def broken_git(*args, **kwargs):
            raise RuntimeError("simulated git failure")

        module.common.git = broken_git
        try:
            verdict = module.decide({"tool_name": "Bash", "cwd": str(REPO),
                                     "tool_input": {"command": "git commit -m \"Closes #9\""}})
        finally:
            module.common.git = real_git
        self.assertEqual(verdict.code, 0)
        self.assertIn("did not run", warning_of(verdict.stdout) or "")
        self.assertIn("simulated git failure", warning_of(verdict.stdout) or "")

    # ---- verify-closeout-complete (F327) -------------------------------------------------------
    CLOSEOUT_MESSAGE = "Sprint 77 is fully closed out. Ready for the next sprint."

    def closeout_payload(self, fixture: str, **extra) -> dict:
        payload = {"cwd": str(CASES / "fixtures" / fixture), "branch_override": "feature/20261010_Sprint_77",
                   "dirty_zero_files_override": "", "skip_git_checks": True,
                   "last_assistant_message": self.CLOSEOUT_MESSAGE}
        payload.update(extra)
        return payload

    def test_closeout_crlf_plan_still_blocks_on_a_placeholder_executed_by(self):
        """R-2: the plan keeps its CRLF and BOM. A reader that left the carriage return in the value
        would call the seeded Executed-by line filled. Does NOT catch CRLF handling in checks other
        than 3d-3 (3d and 3d-2 are covered by their own LF fixtures)."""
        module = load_hook("verify-closeout-complete.py")
        plan = CASES / "fixtures" / "crlf-plan-sprint" / "docs" / "sprints" / "SPRINT_77_PLAN.md"
        raw = plan.read_bytes()
        self.assertTrue(raw.startswith(b"\xef\xbb\xbf") and b"\r\n" in raw, "fixture lost its CRLF or BOM")
        text = module.read_markdown(str(plan))
        self.assertIn("\r\n", text, "read_markdown must keep CRLF (text mode would hide it)")
        self.assertFalse(text.startswith("﻿"), "read_markdown must remove the BOM")
        verdict = module.decide(self.closeout_payload("crlf-plan-sprint"))
        self.assertEqual(verdict.code, 2)
        self.assertIn("1 task card(s) whose '**Executed-by**' line is still empty", verdict.stderr)
        self.assertNotIn("7.7.1 final code reviews", verdict.stderr)  # the CRLF 7.7.1 line itself parsed fine

    def test_closeout_block_names_check_text_and_bullets_each_violation(self):
        """Does NOT catch a changed wording inside a violation; the first line, the intro and the
        bypass paragraph are pinned."""
        module = load_hook("verify-closeout-complete.py")
        verdict = module.decide(self.closeout_payload("executed-by-empty-sprint"))
        self.assertEqual(verdict.code, 2)
        lines = verdict.stderr.splitlines()
        self.assertEqual(lines[0], "[BLOCKED by verify-closeout-complete hook]")
        self.assertIn("SPRINT_CHECKLIST.md artifacts contradict that:", verdict.stderr)
        self.assertTrue(any(line.startswith("  - SPRINT_77_PLAN.md has 1 task card(s) whose") for line in lines))
        self.assertIn("include 'allow_stop_hook_bypass', or state explicitly which item does not", verdict.stderr)

    def test_closeout_open_issues_block_only_after_the_pr_merged_and_gh_failure_fails_open(self):
        """Check 3c with fake git and gh answers. Does NOT catch the real gh JSON shape (state and
        mergedAt for an unmerged PR); the parity probe in the sprint plan covers that against live gh."""
        module = load_hook("verify-closeout-complete.py")
        real_git, real_gh = common.git, common.gh
        self.addCleanup(setattr, common, "git", real_git)
        self.addCleanup(setattr, common, "gh", real_gh)

        def fake_git(*args, **kwargs):
            if args[:2] == ("remote", "get-url"):
                return 0, "https://github.com/example/repo.git\n"
            if args[:2] == ("branch", "--show-current"):
                return 0, "feature/20261030_Sprint_81\n"
            return real_git(*args, **kwargs)

        def fake_gh(pr_state, issues):
            def run(*args, **kwargs):
                if args[:2] == ("pr", "list"):
                    return pr_state
                return issues
            return run

        payload = self.closeout_payload("improvement-review-present-sprint",
                                        branch_override="feature/20261030_Sprint_81")
        common.git = fake_git
        # Merged PR and an open card: blocks, naming the card.
        common.gh = fake_gh((0, '[{"state":"MERGED","mergedAt":"2026-11-01T00:00:00Z"}]'), (0, '[{"number":12}]'))
        verdict = module.decide(payload)
        self.assertEqual(verdict.code, 2)
        self.assertIn("GitHub issues labeled 'sprint' are still OPEN: #12.", verdict.stderr)
        # PR still open: the open card is the correct state.
        common.gh = fake_gh((0, '[{"state":"OPEN","mergedAt":null}]'), (0, '[{"number":12}]'))
        self.assertEqual(module.decide(payload).code, 0)
        # gh fails (not installed, offline, timeout): fail open.
        common.gh = fake_gh((1, ""), (1, ""))
        self.assertEqual(module.decide(payload).code, 0)
        # gh prints text that is not JSON: fail open.
        common.gh = fake_gh((0, "rate limited"), (0, "rate limited"))
        self.assertEqual(module.decide(payload).code, 0)

    def test_closeout_gh_failure_prints_a_notice_and_still_allows(self):
        """5.1.2 F6-1: a gh failure fails open WITH a systemMessage that check 3c did not run. Does NOT catch
        a git failure (no remote or branch), which still skips check 3c without a notice."""
        module = load_hook("verify-closeout-complete.py")
        real_git, real_gh = common.git, common.gh
        self.addCleanup(setattr, common, "git", real_git)
        self.addCleanup(setattr, common, "gh", real_gh)
        common.git = lambda *a, **k: (0, "feature/20261030_Sprint_81\n" if a[:1] == ("branch",)
                                      else "https://github.com/example/repo.git\n")
        payload = self.closeout_payload("improvement-review-present-sprint",
                                        branch_override="feature/20261030_Sprint_81")
        merged = (0, '[{"state":"MERGED","mergedAt":"2026-11-01T00:00:00Z"}]')
        cases = ((lambda *a, **k: (common.GH_NOT_FOUND, ""), "gh is not installed"),
                 (lambda *a, **k: (common.GH_TIMEOUT, ""), "gh timed out"),
                 (lambda *a, **k: (0, "rate limited") if a[:2] == ("pr", "list") else (0, ""), "unreadable gh output"),
                 (lambda *a, **k: merged if a[:2] == ("pr", "list") else (1, ""), "gh exit code 1"),
                 (lambda *a, **k: merged if a[:2] == ("pr", "list") else (0, "  "), "empty gh output"))
        for fake, words in cases:
            common.gh = fake
            drain_notices()
            verdict = module.decide(payload)
            self.assertEqual(verdict.code, 0, words)
            queued = drain_notices()
            self.assertEqual(len(queued), 1, words)
            shown = json.loads(hooklib.apply_notices(verdict, queued).stdout)["systemMessage"]
            self.assertIn("check 3c did not run: gh unavailable (", shown, words)
            self.assertIn(words, shown)
        # gh works and nothing is open: no notice.
        common.gh = lambda *a, **k: merged if a[:2] == ("pr", "list") else (0, "[]")
        drain_notices()
        verdict = module.decide(payload)
        self.assertEqual((verdict.code, verdict.stdout, drain_notices()), (0, "", []))

    def test_closeout_budget_used_up_makes_no_call_and_says_which_checks_did_not_run(self):
        """Sprint 84 retro q4: every git and gh call shares HOOK_BUDGET_SECONDS. With no time left no call
        is made, the hook still answers, and each skipped check is named. Does NOT catch a single call
        that ignores its timeout (subprocess enforces it, not this hook)."""
        module = load_hook("verify-closeout-complete.py")
        self.addCleanup(setattr, common, "git", common.git)
        self.addCleanup(setattr, common, "gh", common.gh)
        calls = []
        common.git = lambda *a, **k: calls.append(("git", a)) or (0, "")
        common.gh = lambda *a, **k: calls.append(("gh", a)) or (0, "[]")
        module.HOOK_BUDGET_SECONDS = 0
        payload = self.closeout_payload("improvement-review-present-sprint",
                                        branch_override="feature/20261030_Sprint_81",
                                        dirty_zero_files_override=None)
        drain_notices()
        verdict = module.decide(payload)
        queued = drain_notices()
        self.assertEqual(calls, [])
        self.assertIn(verdict.code, (0, 2))
        self.assertIn("check 3a-2 did not run: git status exit 124, the hook's 0 second time budget was used up",
                      queued)
        self.assertTrue(any(n.startswith("check 3c did not run: git (git remote get-url origin exit 124")
                            for n in queued), queued)
        # With the normal budget each call gets its own limit.
        module.HOOK_BUDGET_SECONDS = 15
        timeouts = []
        common.git = lambda *a, **k: timeouts.append(k.get("timeout")) or (0, "x\n")
        common.gh = lambda *a, **k: timeouts.append(k.get("timeout")) or (0, "[]")
        module.decide(payload)
        self.assertEqual(sorted(set(timeouts)), [module.GIT_CALL_TIMEOUT, module.GH_CALL_TIMEOUT])

    def test_closeout_gh_calls_run_at_the_same_time(self):
        """Sprint 84 retro q4: check 3c waits for the slower gh call, not the sum of both. Does NOT catch a
        slow git call before them (the budget test covers the total)."""
        module = load_hook("verify-closeout-complete.py")
        self.addCleanup(setattr, common, "git", common.git)
        self.addCleanup(setattr, common, "gh", common.gh)
        common.git = lambda *a, **k: (0, "feature/20261030_Sprint_81\n" if a[:1] == ("branch",)
                                      else "https://github.com/example/repo.git\n")

        def slow_gh(*args, **kwargs):
            time.sleep(1.0)
            if args[:2] == ("pr", "list"):
                return 0, '[{"state":"MERGED","mergedAt":"2026-11-01T00:00:00Z"}]'
            return 0, '[{"number":12}]'

        common.gh = slow_gh
        payload = self.closeout_payload("improvement-review-present-sprint",
                                        branch_override="feature/20261030_Sprint_81")
        started = time.monotonic()
        verdict = module.decide(payload)
        took = time.monotonic() - started
        self.assertIn("still OPEN: #12.", verdict.stderr)
        self.assertLess(took, 1.8, f"the two gh calls took {took:.2f} s, so they ran one after the other")

    def test_closeout_claim_and_mid_sprint_patterns(self):
        """Gate 2: a mid-sprint signal beats a claim; each claim shape fires; case does not matter.
        Does NOT catch a new phrasing nobody listed (the patterns are deliberately narrow)."""
        module = load_hook("verify-closeout-complete.py")
        for claim in ("The sprint is now complete.", "Close-out was finished.", "READY FOR THE NEXT SPRINT",
                      "All the checklist items are done.", "Everything through the post-merge section.",
                      "Sprint 77 is closed."):
            self.assertTrue(module.claims_closeout(claim), claim)
        for mid in ("Sprint status: the sprint is complete.", "Task 3 is blocked; the sprint is complete.",
                    "Stopping criterion 2 met; the sprint is complete.", "It remains blocked; sprint is done.",
                    "Still running. The sprint is complete."):
            self.assertFalse(module.claims_closeout(mid), mid)
        self.assertFalse(module.claims_closeout("Task 1 is complete."))

    def test_closeout_previous_summary_3b_and_velocity_rows_3b2(self):
        """Checks 3b and 3b-2 in a throwaway project. Does NOT catch a velocity row whose sprint column
        holds a different number with the same digits (for example 177 versus 77); the regex needs the
        cell to be exactly the sprint number between pipes."""
        module = load_hook("verify-closeout-complete.py")
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp)
            (project / ".claude").mkdir()
            (project / ".claude" / "sprint_status.json").write_text(
                json.dumps({"current_sprint": {"number": 77}}), encoding="utf-8")
            sprints = project / "docs" / "sprints"
            sprints.mkdir(parents=True)
            payload = self.closeout_payload("final-review-missing-sprint")
            payload["cwd"] = str(project)

            self.assertEqual(module.decide(payload).code, 0)  # nothing to complain about yet
            (sprints / "SPRINT_76_RETROSPECTIVE.md").write_text("retro", encoding="utf-8")
            verdict = module.decide(payload)
            self.assertEqual(verdict.code, 2)
            self.assertIn("docs/sprints/SPRINT_76_SUMMARY.md is missing (Phase 3.2.1 MANDATORY", verdict.stderr)
            (sprints / "SPRINT_76_SUMMARY.md").write_text("summary", encoding="utf-8")
            self.assertEqual(module.decide(payload).code, 0)

            velocity = project / "docs" / "CODING_VELOCITY.md"
            velocity.write_text("| F1 | 177 | DONE | 1 |\n| F2 | 77 | PLANNED | 1 |\n", encoding="utf-8")
            verdict = module.decide(payload)
            self.assertEqual(verdict.code, 2)
            self.assertIn("docs/CODING_VELOCITY.md has NO Actuals Log row for Sprint 77.", verdict.stderr)
            velocity.write_text("| F1 | 77 | done | 1 |\n", encoding="utf-8")  # case-insensitive, as -notmatch was
            self.assertEqual(module.decide(payload).code, 0)

    def test_closeout_status_age_3a(self):
        """Check 3a staleness: a LIVE status file older than 30 days is flagged; the same file under
        test-cases/fixtures/ is not. Does NOT catch a date format the parser rejects (that is skipped,
        as the PowerShell did)."""
        module = load_hook("verify-closeout-complete.py")
        status = {"_last_updated": "2020-01-01T00:00", "current_sprint": {"number": 77}}
        with tempfile.TemporaryDirectory() as tmp:
            for sub, expect_flag in (("live", True), ("test-cases/fixtures/x", False)):
                project = Path(tmp) / sub
                (project / ".claude").mkdir(parents=True)
                (project / ".claude" / "sprint_status.json").write_text(json.dumps(status), encoding="utf-8")
                payload = self.closeout_payload("final-review-missing-sprint")
                payload["cwd"] = str(project)
                verdict = module.decide(payload)
                self.assertEqual(" days old." in verdict.stderr, expect_flag, sub)
            fresh = Path(tmp) / "fresh"
            (fresh / ".claude").mkdir(parents=True)
            status["_last_updated"] = datetime.now().strftime("%Y-%m-%dT%H:%M")
            (fresh / ".claude" / "sprint_status.json").write_text(json.dumps(status), encoding="utf-8")
            payload = self.closeout_payload("final-review-missing-sprint")
            payload["cwd"] = str(fresh)
            self.assertNotIn(" days old.", module.decide(payload).stderr)

    def test_closeout_sweep_head_check_3e(self):
        """Check 3e with fake git answers (the recorded cases all set skip_git_checks). Does NOT catch
        the real `git log` range syntax; the parity probe ran that against this repo."""
        module = load_hook("verify-closeout-complete.py")
        real_git = common.git
        self.addCleanup(setattr, common, "git", real_git)
        sweep = "  - sweep-head: 0123abc\n"
        plan_text = ("- **5.1.2 F-PRECHECK**: ok\n- **5.1.5 WinWright sweep**: ok\n{sweep}"
                     "- **7.7.1 final code reviews**: 2026-10-10, done\n")
        status = {"current_sprint": {"number": 77, "plan_approved": True, "pr_number": 1}}

        def run(has_sweep_head, log=None, diffs=()):
            calls = []

            def fake_git(*args, **kwargs):
                calls.append(args)
                if args[0] == "log":
                    return log
                if args[0] == "diff":
                    return diffs[sum(1 for c in calls if c[0] == "diff") - 1]
                return real_git(*args, **kwargs)

            with tempfile.TemporaryDirectory() as tmp:
                project = Path(tmp)
                (project / ".claude").mkdir()
                (project / ".claude" / "sprint_status.json").write_text(json.dumps(status), encoding="utf-8")
                (project / "docs" / "sprints").mkdir(parents=True)
                (project / "docs" / "sprints" / "SPRINT_77_PLAN.md").write_text(
                    plan_text.format(sweep=sweep if has_sweep_head else ""), encoding="utf-8")
                payload = self.closeout_payload("final-review-missing-sprint", skip_git_checks=False)
                payload["cwd"] = str(project)
                common.git = fake_git
                return module.decide(payload), calls

        verdict, calls = run(True, log=(0, "a1 ui\nb2 ui\n"))
        self.assertEqual(verdict.code, 2)
        self.assertIn("sweep-head: 0123abc, but lib/ui commits exist AFTER it: 2 commit(s)", verdict.stderr)
        self.assertIn(("log", "--oneline", "0123abc..HEAD", "--", "mobile-app/lib/ui"), calls)
        # Sprint 84 7.7.1 finding 1: git exit 128 = "no such commit" is a VIOLATION, not a skip.
        verdict, _ = run(True, log=(128, ""))
        self.assertEqual(verdict.code, 2)
        self.assertIn("sweep-head: 0123abc, which is not a commit in this repo (git log exit 128)", verdict.stderr)
        # Any other git failure (could not launch, timeout) still fails open, but with a notice.
        drain_notices()
        self.assertEqual(run(True, log=(1, "a1 ui\n"))[0].code, 0)
        self.assertEqual([n for n in drain_notices() if "3e" in n], ["check 3e did not run: git log exit 1"])
        self.assertEqual(run(True, log=(0, ""))[0].code, 0)          # no newer UI commits
        verdict, _ = run(False, diffs=[(0, "mobile-app/lib/ui/x.dart\n")])
        self.assertEqual(verdict.code, 2)
        self.assertIn("records no 'sweep-head: <hash>' line", verdict.stderr)
        verdict, calls = run(False, diffs=[(1, ""), (0, "mobile-app/lib/ui/x.dart\n")])  # origin/develop missing
        self.assertEqual(verdict.code, 2)
        self.assertIn("develop...HEAD", [c[2] for c in calls if c[0] == "diff"])
        drain_notices()
        self.assertEqual(run(False, diffs=[(1, ""), (1, "")])[0].code, 0)
        queued = [n for n in drain_notices() if "3e" in n]  # finding 1: both diffs failed -> a notice, not silence
        self.assertEqual(len(queued), 1)
        self.assertIn("check 3e did not run: git diff", queued[0])
        self.assertEqual(run(False, diffs=[(0, "")])[0].code, 0)
        self.assertEqual([n for n in drain_notices() if "3e" in n], [])

    def closeout_project(self, tmp, number=77, plan=None, status_extra=None, current_extra=None):
        """A throwaway project with an approved-plan status file (and a plan when `plan` is text)."""
        project = Path(tmp)
        (project / ".claude").mkdir(parents=True, exist_ok=True)
        current = {"number": number, "plan_approved": True, "pr_number": 1}
        current.update(current_extra or {})
        body = {"current_sprint": current}
        body.update(status_extra or {})
        (project / ".claude" / "sprint_status.json").write_text(json.dumps(body), encoding="utf-8")
        if plan is not None:
            (project / "docs" / "sprints").mkdir(parents=True, exist_ok=True)
            (project / "docs" / "sprints" / f"SPRINT_{number}_PLAN.md").write_text(plan, encoding="utf-8")
        return project

    def test_closeout_missing_plan_file_is_one_violation_not_a_pass(self):
        """7.7.1 finding 3: an approved plan with no plan file used to pass 3d, 3d-2 and 3d-3 in silence.
        Does NOT catch a plan file that exists but is empty; the evidence checks report that themselves."""
        module = load_hook("verify-closeout-complete.py")
        with tempfile.TemporaryDirectory() as tmp:
            project = self.closeout_project(tmp)
            payload = self.closeout_payload("final-review-missing-sprint")
            payload["cwd"] = str(project)
            verdict = module.decide(payload)
            self.assertEqual(verdict.code, 2)
            self.assertEqual(verdict.stderr.count("SPRINT_77_PLAN.md is MISSING"), 1, verdict.stderr)
            # Plan not approved: the file is not owed yet, so no violation.
            project = self.closeout_project(Path(tmp) / "draft", current_extra={"plan_approved": False})
            payload["cwd"] = str(project)
            self.assertNotIn("is MISSING", module.decide(payload).stderr)

    def test_closeout_non_numeric_sprint_number_has_its_own_message(self):
        """7.7.1 finding 4. Does NOT catch a number that is numeric text such as "77"; that is accepted
        on purpose (the PowerShell [int] cast did the same)."""
        module = load_hook("verify-closeout-complete.py")
        with tempfile.TemporaryDirectory() as tmp:
            project = self.closeout_project(tmp, current_extra={"number": "seventy-seven"})
            payload = self.closeout_payload("final-review-missing-sprint")
            payload["cwd"] = str(project)
            verdict = module.decide(payload)
            self.assertEqual(verdict.code, 2)
            self.assertIn("current_sprint.number is 'seventy-seven', which is not a whole number", verdict.stderr)
            self.assertNotIn("not valid JSON", verdict.stderr)
            (project / ".claude" / "sprint_status.json").write_text("{bad", encoding="utf-8")
            self.assertIn("is not valid JSON", module.decide(payload).stderr)

    def test_closeout_git_failures_in_3a2_and_3c_are_noticed_not_silent(self):
        """7.7.1 findings 1 and 2: a failed `git status` (3a-2) and a missing remote or branch (3c) add notices;
        3c calls `git remote get-url` once. Does NOT catch a git that fails only for the sub-call after
        the first (the fakes answer every call of a kind alike)."""
        module = load_hook("verify-closeout-complete.py")
        real_git = common.git
        self.addCleanup(setattr, common, "git", real_git)
        calls = []

        def fake_git(*args, **kwargs):
            calls.append((args, kwargs))
            if args[:1] == ("status",):
                return 128, ""
            if args[:2] == ("remote", "get-url"):
                return answers["remote"]
            if args[:2] == ("branch", "--show-current"):
                return answers["branch"]
            return real_git(*args, **kwargs)

        answers = {"remote": (0, ""), "branch": (0, "feature/x\n")}
        with tempfile.TemporaryDirectory() as tmp:
            project = self.closeout_project(tmp)
            payload = self.closeout_payload("final-review-missing-sprint", dirty_zero_files_override=None)
            payload["cwd"] = str(project)
            common.git = fake_git
            for remote, branch, words in (((0, ""), (0, "feature/x\n"), "no origin URL"),
                                          ((128, ""), (0, "feature/x\n"), "git remote get-url origin exit 128"),
                                          ((0, "https://x/y.git\n"), (0, ""), "detached HEAD, no branch"),
                                          ((0, "https://x/y.git\n"), (128, ""), "git branch --show-current exit 128")):
                answers.update(remote=remote, branch=branch)
                calls.clear()
                drain_notices()
                module.decide(payload)
                queued = drain_notices()
                self.assertIn("check 3a-2 did not run: git status exit 128", queued, words)
                self.assertTrue(any("check 3c did not run: git (" in n and words in n for n in queued), (words, queued))
                self.assertEqual(sum(1 for args, _ in calls if args[:2] == ("remote", "get-url")), 1, words)
                for args, kw in calls:
                    if args[:2] in (("remote", "get-url"), ("branch", "--show-current")):
                        self.assertEqual(kw.get("timeout"), module.GIT_CALL_TIMEOUT, (words, args))

    def test_branch_lookup_failure_is_noticed_by_both_stop_hooks(self):
        """7.7.1 finding 6: a failed `git branch` was an empty branch name and the gate allowed silently. A
        detached HEAD (exit 0, empty output) stays silent. Does NOT catch a branch NAME git reports wrongly."""
        self.addCleanup(setattr, common, "git", common.git)
        for hook in ("verify-closeout-complete.py", "sprint-auto-advance.py"):
            module = load_hook(hook)
            payload = {"cwd": str(CASES / "fixtures" / "final-review-missing-sprint"),
                       "last_assistant_message": self.CLOSEOUT_MESSAGE}
            common.git = lambda *a, **k: (128, "")
            drain_notices()
            self.assertEqual(module.decide(payload).code, 0, hook)
            queued = drain_notices()
            self.assertEqual(len(queued), 1, (hook, queued))
            self.assertIn("git branch --show-current failed (exit 128)", queued[0], hook)
            common.git = lambda *a, **k: (0, "")
            self.assertEqual(module.decide(payload).code, 0, hook)
            self.assertEqual(drain_notices(), [], hook)

    def test_status_file_that_is_not_an_object_is_noticed(self):
        """7.7.1 finding 5. Does NOT catch a status file that is an object with no current_sprint; that is
        the normal state outside a sprint and stays silent."""
        cards = load_hook("require-sprint-cards.py")
        advance = load_hook("sprint-auto-advance.py")
        with tempfile.TemporaryDirectory() as tmp:
            listing = Path(tmp) / "status.json"
            listing.write_text("[1, 2]", encoding="utf-8")
            cwd = Path(tmp) / "proj"
            (cwd / ".claude").mkdir(parents=True)
            (cwd / ".claude" / "sprint_status.json").write_text("[1, 2]", encoding="utf-8")
            for label, call in (
                    ("cards", lambda: cards.decide({"tool_input": {"command": "git commit -m x"},
                                                    "status_path_override": str(listing)})),
                    ("advance", lambda: advance.load_status(str(cwd)))):
                drain_notices()
                call()
                queued = drain_notices()
                self.assertEqual(len(queued), 1, label)
                self.assertIn("is a JSON list, not an object; sprint gates skipped", queued[0], label)
            (cwd / ".claude" / "sprint_status.json").write_text("{}", encoding="utf-8")
            drain_notices()
            advance.load_status(str(cwd))
            self.assertEqual(drain_notices(), [])

    def test_velocity_empty_cwd_warns_when_the_commit_could_close_a_task(self):
        """7.7.1 finding 7. Does NOT catch a commit whose task reference lives only in a message file we
        cannot name (a -F path held in a variable); the -F form is warned about, a heredoc message is
        searched as command text."""
        module = load_hook("warn-commit-without-velocity.py")
        saved = os.environ.pop("CLAUDE_PROJECT_DIR", None)
        if saved is not None:
            self.addCleanup(os.environ.__setitem__, "CLAUDE_PROJECT_DIR", saved)
        for command in ('git commit -m "Closes #12"', 'git commit -m "Task 4 done"', "git commit -F msg.txt"):
            verdict = module.decide({"tool_name": "Bash", "tool_input": {"command": command}})
            warning = warning_of(verdict.stdout)
            self.assertIsNotNone(warning, command)
            self.assertIn("payload has no working directory", warning, command)
        self.assertEqual(module.decide({"tool_name": "Bash", "tool_input": {"command": 'git commit -m "fix"'}}).stdout, "")

    def test_stash_guard_read_only_form_never_hides_a_state_change(self):
        """7.7.1 finding 8. Does NOT catch `git --git-dir x stash` (a global option whose value is a
        separate word other than -C and -c); that form is not recognized."""
        module = load_hook("block-carry-forward-stash.py")

        def code(command):
            return module.decide({"tool_input": {"command": command}}).code
        for command in ("git stash list && git stash pop", "git stash show; git stash drop", "git -C somedir stash",
                        "git -C \"a b\" stash push", "git -c core.x=1 stash", "git --no-pager stash",
                        "git stash list | cat && git -C d stash apply"):
            self.assertEqual(code(command), 2, command)
        for command in ("git stash list", "git -C d stash show -p", "git stash list && git stash show",
                        "git log --grep stash", "git commit -m \"git -C d stash\"", "echo stash"):
            self.assertEqual(code(command), 0, command)

    def test_sprint_cards_gate_sees_commit_after_global_options(self):
        """7.7.1 finding 8. Does NOT catch a commit made through an alias (`git ci`) or a script."""
        module = load_hook("require-sprint-cards.py")
        status = CASES / "fixtures" / "status_approved_no_cards.json"
        for command in ("git -C somedir commit -m x", "git -c user.name=x commit -m x", "git --no-pager commit -m x",
                        "git add -A && git -C d commit -m x"):
            verdict = module.decide({"tool_input": {"command": command}, "status_path_override": str(status)})
            self.assertEqual(verdict.code, 2, command)
        for command in ("git -C d log", "git -C d status", "git log --grep commit", "gh issue create --title \"git -C d commit\""):
            verdict = module.decide({"tool_input": {"command": command}, "status_path_override": str(status)})
            self.assertEqual(verdict.code, 0, command)

    def test_internal_error_first_stderr_line_carries_the_essentials(self):
        """7.7.1 finding 9: Claude Code shows only the first stderr line of a hook error. Does NOT catch how
        Claude Code truncates a very long first line."""
        with tempfile.TemporaryDirectory() as tmp:
            script = Path(tmp) / "boom2.py"
            script.write_text(
                "import sys\nsys.path.insert(0, %r)\nimport hooklib\n"
                "def decide(p):\n    hooklib.notice('gate skipped')\n    hooklib.notice('second')\n"
                "    raise RuntimeError('line one\\nline two')\n"
                "hooklib.run('boom2', decide)\n" % str(HOOKS / "lib"), encoding="utf-8")
            done = subprocess.run([sys.executable, str(script)], input=b"{}", capture_output=True, timeout=60)
        lines = done.stderr.decode("utf-8").splitlines()
        self.assertEqual(done.returncode, hooklib.HOOK_ERROR)
        self.assertEqual(lines[0], "[boom2] internal error, command allowed: RuntimeError: line one line two; "
                                   "2 notice(s) follow")
        self.assertEqual(lines[1:], ["Note: gate skipped", "Note: second"])

    def test_closeout_unexpected_exception_is_a_visible_hook_error_not_a_pass(self):
        """R-6. The plan path is a FOLDER, so reading it raises OSError, which no check swallows.
        Expect exit 1 and the one-line notice, never exit 0 with no sign. Does NOT catch an exception
        inside hooklib.run's own handler."""
        status = {"current_sprint": {"number": 77, "plan_approved": True, "pr_number": 1}}
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp)
            (project / ".claude").mkdir()
            (project / ".claude" / "sprint_status.json").write_text(json.dumps(status), encoding="utf-8")
            (project / "docs" / "sprints" / "SPRINT_77_PLAN.md").mkdir(parents=True)
            payload = self.closeout_payload("final-review-missing-sprint")
            payload["cwd"] = str(project)
            code, _out, err = run_hook("verify-closeout-complete.py", json.dumps(payload).encode("utf-8"))
        self.assertEqual(code, hooklib.HOOK_ERROR, err)
        self.assertIn("[verify-closeout-complete] internal error", err)

    def test_closeout_malformed_payloads_and_non_sprint_branches_allow(self):
        """Does NOT catch a malformed payload that ALSO claims close-out; there is no such payload."""
        for stdin in (b"", b"not json", b"[1]", b'{"last_assistant_message": 5}'):
            self.assertEqual(run_hook("verify-closeout-complete.py", stdin)[0], 0, stdin)
        module = load_hook("verify-closeout-complete.py")
        self.assertEqual(module.decide(self.closeout_payload("final-review-missing-sprint",
                                                             branch_override="main")).code, 0)
        self.assertEqual(module.decide(self.closeout_payload(
            "final-review-missing-sprint",
            branch_override="feature/20261010_Sprint_77_allow_stop_hook_bypass")).code, 0)

    def test_settings_registers_the_closeout_stop_hook_in_python_form(self):
        """Does NOT catch Claude Code failing to run the command; it pins the registration text."""
        settings = json.loads((REPO / ".claude" / "settings.json").read_text(encoding="utf-8"))
        commands = [h["command"] for group in settings["hooks"]["Stop"] for h in group["hooks"]]
        matching = [c for c in commands if "verify-closeout-complete" in c]
        self.assertEqual(matching, ['python "${CLAUDE_PROJECT_DIR}/.claude/hooks/verify-closeout-complete.py"'])


FOOTERS = ("11/06/2026 12:40pm | Sprint 84 Phase 4 Execution",   # current format (Sprint 70 and later)
           "09/18/2026 12:22am | Phase 4.2 Testing Cycle (Per Task)",   # the format the Sprint 70 fix saw
           "9/8/2026 1:05PM | Sprint 70 Phase 5.3 Manual Validation",   # one-digit month, upper-case PM
           "11/06/2026 12:40pm")                                       # no phase half


class AutoAdvanceTests(unittest.TestCase):
    """F328: sprint-auto-advance.py (the Stop hook). The recorded cases pin the common shapes; these pin the
    shapes they do not: every gate on its own, the footer coupling (CLAUDE.md IMP-3, Sprint 70), the F193
    marker rules, the PowerShell value comparisons, and the exception path (R-6)."""

    ASK = "Task 2 is done. Want me to proceed to Task 3?"
    VEL_OK = "| Task 1 | 84 | DONE | x |\n"
    PLAN_OK = ("# Sprint 84 Plan\n\n**Status**: APPROVED\n\n"
               "- **5.1.2 F-PRECHECK**: 2026-11-01, all six clean\n"
               "- **5.1.5 WinWright sweep**: N/A -- no lib/ui change this sprint\n"
               "- **5.1.9 MV rehearsal**: ran every step on the build\n"
               "## Task 1 -- thing\n")

    def setUp(self):
        self.module = load_hook("sprint-auto-advance.py")
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def project(self, number=84, status="Phase 4 Execution", approved=True, plan=None, velocity=None,
                retro=False, status_file=True, plan_number=None, status_number=None):
        """A throwaway project folder; returns its path as text."""
        root = Path(self.tmp.name) / f"p{len(list(Path(self.tmp.name).iterdir()))}"
        (root / ".claude").mkdir(parents=True)
        (root / "docs" / "sprints").mkdir(parents=True)
        if status_file:
            current = {"number": status_number if status_number is not None else number, "status": status}
            if approved != "missing":
                current["plan_approved"] = approved
            (root / ".claude" / "sprint_status.json").write_text(json.dumps({"current_sprint": current}), encoding="utf-8")
        if plan is not None:
            (root / "docs" / "sprints" / f"SPRINT_{plan_number or number}_PLAN.md").write_bytes(plan.encode("utf-8"))
        if retro:
            (root / "docs" / "sprints" / f"SPRINT_{number}_RETROSPECTIVE.md").write_text("retro", encoding="utf-8")
        if velocity is not None:
            (root / "docs").mkdir(exist_ok=True)
            (root / "docs" / "CODING_VELOCITY.md").write_text(velocity, encoding="utf-8")
        return str(root)

    def decide(self, cwd, message, number=84, branch=None):
        return self.module.decide({"cwd": cwd, "last_assistant_message": message,
                                   "branch_override": branch or f"feature/20261105_Sprint_{number}"})

    # ---- Gate 1 / 1b / 1c ---------------------------------------------------------------------------
    def test_gate1_branch_rules(self):
        """Does NOT catch a branch the git call itself would report differently; branch_override replaces git."""
        cwd = self.project(plan=self.PLAN_OK)
        self.assertEqual(self.decide(cwd, self.ASK).code, 2)
        for branch in ("main", "develop", "feature/20261105_Sprint_84_extra", "feature/x_Sprint_84",
                       "feature/20261105_Sprint_84_allow_stop_hook_bypass"):
            self.assertEqual(self.decide(cwd, self.ASK, branch=branch).code, 0, branch)
        self.assertEqual(self.module.decide({"cwd": cwd, "last_assistant_message": self.ASK}).code, 0)  # git: not a repo

    def test_gate1b_window_opens_at_plan_approval(self):
        """Does NOT catch a plan whose Status line sits below line 20; the PowerShell read 20 lines too."""
        no_plan = self.project(plan=None)
        self.assertEqual(self.decide(no_plan, self.ASK).code, 0)                       # Phase 1: no plan file
        unapproved = self.project(approved=False, plan=self.PLAN_OK)
        self.assertEqual(self.decide(unapproved, self.ASK).code, 0)                    # status file: drafted
        for approved in ("false", 0):
            self.assertEqual(self.decide(self.project(approved=approved, plan=self.PLAN_OK), self.ASK).code, 0, approved)
        for approved in (True, None, "missing", 1):
            self.assertEqual(self.decide(self.project(approved=approved, plan=self.PLAN_OK), self.ASK).code, 2, approved)
        draft = "# Plan\n**Status**: DRAFT -- awaiting approval\n"
        self.assertEqual(self.decide(self.project(status_file=False, plan=draft), self.ASK).code, 0)   # plan line, no status file
        self.assertEqual(self.decide(self.project(plan=draft), self.ASK).code, 0)                      # status names THIS sprint as approved, the plan line still exempts
        # a status file naming ANOTHER sprint must not let a historical DRAFT line exempt this one
        self.assertEqual(self.decide(self.project(plan=draft, status_number=83), self.ASK).code, 2)
        late = "\n" * 25 + draft
        self.assertEqual(self.decide(self.project(status_file=False, plan=late), self.ASK).code, 2)

    def test_gate1c_window_closes_at_manual_validation_and_prose_does_not_close_it(self):
        """Does NOT catch a status string shaped unlike the listed ones; those fall through to the retro-file test."""
        closed = ("Phase 5.3 Manual Validation -- awaiting Harold", "Sprint 84 phase 7 retro", "CLOSE-OUT (Phase 7.7.5).",
                  "Sprint 69 NOT PLANNED, NOT APPROVED. Phase 8 Release Cycle", "Executing (Phase 5.3)", "completed",
                  "Sprint 84 Release Cycle")
        for status in closed:
            cwd = self.project(status=status, plan=self.PLAN_OK, velocity=self.VEL_OK)
            self.assertEqual(self.decide(cwd, self.ASK).code, 0, status)
        prose = ("Sprint 84 Phase 4 EXECUTION. Plan APPROVED with standing approval through Manual Validation.",
                 "Phase 4 Execution", "", "Executing (Phase 4)", "Executing (Phase 5.2)")
        for status in prose:
            # full evidence and velocity rows: a wrongly closed window would then ALLOW (F193 passes), so a 2 here
            # is the question gate alone, not the evidence gate blocking by accident
            cwd = self.project(status=status, plan=self.PLAN_OK, velocity=self.VEL_OK)
            self.assertEqual(self.decide(cwd, self.ASK).code, 2, status)
        self.assertEqual(self.decide(self.project(retro=True, plan=self.PLAN_OK), self.ASK).code, 0)   # retro file
        # a retro file of ANOTHER sprint (status names 83) exempts nothing
        other = self.project(status_number=83, plan=self.PLAN_OK)
        (Path(other) / "docs" / "sprints" / "SPRINT_84_RETROSPECTIVE.md").write_text("old", encoding="utf-8")
        self.assertEqual(self.decide(other, self.ASK).code, 2)

    # ---- F193 evidence gate -------------------------------------------------------------------------
    def mv(self, plan, number=84, velocity=VEL_OK, approved=True):
        cwd = self.project(number=number, status="Phase 5.3 Manual Validation", approved=approved, plan=plan, velocity=velocity)
        return self.decide(cwd, "Ready.", number=number)

    def test_f193_marker_rules(self):
        """Does NOT catch a marker recorded in a table row; the gate wants the bullet form, as the PowerShell did."""
        self.assertEqual(self.mv(self.PLAN_OK).code, 0)
        ok_empty_with_detail = self.PLAN_OK.replace("2026-11-01, all six clean", "\n  1. mirror sync: CLEAN")
        self.assertEqual(self.mv(ok_empty_with_detail).code, 0)
        bad = {
            "pending": self.PLAN_OK.replace("2026-11-01, all six clean", "PENDING"),
            "tbd": self.PLAN_OK.replace("2026-11-01, all six clean", "  tbd later"),
            "bare N/A": self.PLAN_OK.replace("N/A -- no lib/ui change this sprint", "N/A"),
            # The value is empty ONLY when the marker is the last line: anywhere else the greedy \s* after the colon
            # reads on into the NEXT line and captures that as the value (carried over unchanged from the
            # PowerShell). So the "indented detail follows" branch is reachable only at the end of the file too,
            # and ok_empty_with_detail above passes because (.*) captured the detail line, not through that branch.
            "empty value": self.PLAN_OK.replace("- **5.1.2 F-PRECHECK**: 2026-11-01, all six clean\n", "")
                           + "- **5.1.2 F-PRECHECK**:\n",
            "prose only": self.PLAN_OK.replace("- **5.1.2 F-PRECHECK**: 2026-11-01, all six clean", "The 5.1.2 F-PRECHECK was run."),
            "absent": self.PLAN_OK.replace("- **5.1.5 WinWright sweep**: N/A -- no lib/ui change this sprint\n", ""),
        }
        for name, plan in bad.items():
            verdict = self.mv(plan)
            self.assertEqual(verdict.code, 2, name)
            self.assertTrue(verdict.stderr.startswith("[BLOCKED by sprint-auto-advance -- F193 Phase 5 evidence gate]"))
        self.assertIn("5.1.2 F-PRECHECK", self.mv(bad["pending"]).stderr)
        self.assertIn("5.1.5 WinWright sweep", self.mv(bad["absent"]).stderr)
        self.assertEqual(self.mv(self.PLAN_OK.replace("N/A -- no lib/ui change", "n/a: no lib/ui change")).code, 0)

    def test_f193_sprint_thresholds_and_approval_scope(self):
        """Does NOT catch a sprint number above 99; the thresholds are plain integers."""
        no_rehearsal = "\n".join(line for line in self.PLAN_OK.splitlines() if "5.1.9" not in line) + "\n"
        self.assertEqual(self.mv(no_rehearsal, number=77).code, 0)    # 5.1.9 starts at Sprint 78
        v78 = self.mv(no_rehearsal, number=78)
        self.assertEqual(v78.code, 2)
        self.assertIn("5.1.9 MV rehearsal", v78.stderr)
        self.assertEqual(self.mv("# plan\n", number=62).code, 0)      # before Sprint 63 nothing is checked
        self.assertEqual(self.mv("# plan\n", number=63, approved=False).code, 0)   # not approved: the gate does not run
        self.assertEqual(self.mv("# plan\n", number=63).code, 2)

    def test_f193_velocity_rows_need_one_task_row_per_card(self):
        """Does NOT catch a row for the wrong sprint number inside the first column; the pattern keys on column 2."""
        plan = self.PLAN_OK + "## Task 2 -- other\n"
        rows = ("| planning | 84 | DONE | x |\n| Task 1 | 84 | DONE | x |\n")
        self.assertEqual(self.mv(plan, velocity=rows).code, 2)   # 1 task row (planning excluded), 2 cards
        message = self.mv(plan, velocity=rows).stderr
        self.assertIn("CODING_VELOCITY.md task actuals rows (1 found for Sprint 84, 2 needed", message)
        self.assertEqual(self.mv(plan, velocity=rows + "| Task 2 | 84 | MOVED | x |\n").code, 0)
        self.assertEqual(self.mv(plan, velocity=rows + "| Task 2 | 83 | DONE | x |\n").code, 2)
        self.assertEqual(self.mv(plan, number=84, velocity=None).code, 2)       # no velocity file at all: 0 rows
        self.assertEqual(self.mv(self.PLAN_OK, number=78, velocity=None).code, 0)   # before Sprint 79: not checked

    def test_f193_crlf_plan_keeps_working(self):
        """Does NOT catch a lone CR line ending; no plan in this repo uses one."""
        crlf = self.PLAN_OK.replace("\n", "\r\n")
        self.assertEqual(self.mv(crlf).code, 0)
        self.assertEqual(self.mv(crlf.replace("2026-11-01, all six clean", "PENDING")).code, 2)
        self.assertEqual(self.mv(crlf.replace("2026-11-01, all six clean", "\r\n  1. detail line")).code, 0)

    # ---- Gate 2 / 3 : the footer coupling ------------------------------------------------------------
    COMMITMENTS = ("Starting the sign-in fix now.", "I'll start the sign-in fix.", "Let me start the sign-in fix.",
                   "Next: F169, the dropdown.", "Up next is F169.", "F169 is next.", "Done, and next I will wire it.",
                   "On to the sign-in fix.", "Going to task 3.", "Now executing the fix.", "Run the suite now.",
                   "Time to start the fix.", "Done, which I will verify.")

    def test_every_commitment_form_is_still_caught_with_every_footer(self):
        """IMP-3 (Sprint 70): an END-ANCHORED pattern dies silently when the closing convention changes. Does NOT catch
        a footer shaped unlike the four tried here (the strip regex is the only code that knows the footer's shape)."""
        cwd = self.project(plan=self.PLAN_OK)
        for message in self.COMMITMENTS:
            self.assertEqual(self.decide(cwd, message).code, 2, "bare: " + message)
            for footer in FOOTERS:
                verdict = self.decide(cwd, f"Task 2 is done. {message}\n\n{footer}")
                self.assertEqual(verdict.code, 2, f"{message!r} + {footer!r}")

    def test_descriptive_and_copular_sentences_are_not_commitments(self):
        """Does NOT catch a descriptive sentence this list does not contain; the exclusion is the PowerShell list."""
        cwd = self.project(plan=self.PLAN_OK)
        for message in ("Starting the app was not required.", "The retry is continuing with the same backoff.",
                        "The count is reported next.", "The MSIX is ready to upload.", "It was proceeding with the fix.",
                        "Diagnostics are written to the log, and the count is reported next.", "Done."):
            for footer in ("", "\n\n" + FOOTERS[0]):
                self.assertEqual(self.decide(cwd, message + footer).code, 0, message)
        # FORM 6 lookbehind (six fixed-width lookbehinds in place of one .NET variable-width one)
        self.assertEqual(self.decide(cwd, "Continuing with the retry.").code, 2)
        for copula in ("is", "are", "was", "were", "been", "being"):
            self.assertEqual(self.decide(cwd, f"It {copula} continuing with the retry.").code, 0, copula)
        self.assertEqual(self.decide(cwd, "Insisting is continuing with the retry.").code, 0)

    def test_questions_phrases_and_the_whitelist(self):
        """Does NOT catch a procedural phrase absent from the 13 patterns; the list is carried over unchanged."""
        cwd = self.project(plan=self.PLAN_OK)
        self.assertEqual(self.decide(cwd, "Task 2 is done?").code, 2)
        # Sprint 84 (Harold Q2): the footer no longer hides a bare '?'. Does NOT catch a closing line shaped
        # unlike FOOTER (for example a footer with seconds), which still hides it.
        for footer in FOOTERS:
            self.assertEqual(self.decide(cwd, "Task 2 is done?\n\n" + footer).code, 2, footer)
        self.assertEqual(self.decide(cwd, "Is it done? Yes, it is done.\n\n" + FOOTERS[0]).code, 0)   # '?' mid-message only
        for phrase in ("Should I continue", "Which option is better", "Let me know if that works", "Is this OK",
                       "Do you want me to push", "What should I do", "Awaiting your approval", "or wait"):
            self.assertEqual(self.decide(cwd, phrase + ".").code, 2, phrase)
        for legit in ("Stopping criterion 2: blocked. Want me to proceed?", "The plan is ambiguous here. Should I proceed?",
                      "This would change the approved sprint scope. Should I proceed?", "Decision is yours. Which option?",
                      "Please provide retrospective feedback. Should I continue?", "Critical bug found. Should I stop?"):
            self.assertEqual(self.decide(cwd, legit).code, 0, legit)
        self.assertEqual(self.decide(cwd, "").code, 0)

    def test_block_messages_are_the_gate_text(self):
        """Does NOT catch a changed wording past the first line and the named fields; those are pinned."""
        cwd = self.project(plan=self.PLAN_OK)
        verdict = self.decide(cwd, self.ASK)
        self.assertEqual(verdict.stderr.splitlines()[0], "[BLOCKED by sprint-auto-advance hook]")
        self.assertIn("on branch 'feature/20261105_Sprint_84' (a sprint feature branch)", verdict.stderr)
        self.assertIn("Hook source: .claude/hooks/sprint-auto-advance.py", verdict.stderr)
        self.assertEqual(verdict.stdout, "")

    # ---- value comparisons and the exception path ------------------------------------------------------
    def test_powershell_value_comparisons(self):
        """Does NOT catch a JSON array or object as the value; PowerShell never equals a boolean either."""
        eq = self.module.ps_eq_bool
        for value, want, expected in ((True, True, True), (False, False, True), (True, False, False), (False, True, False),
                                      (1, True, True), (0, False, True), (2, True, False), ("False", False, True),
                                      ("true", True, True), ("yes", True, False), (None, False, False), (None, True, False),
                                      ([], False, False), ({}, True, False)):
            self.assertEqual(eq(value, want), expected, (value, want))
        self.assertEqual(self.module.ps_str(84.0), "84")
        self.assertEqual(self.module.ps_str(None), "")
        self.assertEqual(self.module.ps_str("84"), "84")

    def test_unexpected_exception_is_a_visible_hook_error_not_a_pass(self):
        """R-6. The plan path is a FOLDER: the Gate 1b read swallows that (the PowerShell catch), the F193 read
        does not, so the process exits 1 with the one-line notice. Does NOT catch an error inside hooklib.run."""
        cwd = self.project(status="Phase 5.3 Manual Validation", plan=None)
        (Path(cwd) / "docs" / "sprints" / "SPRINT_84_PLAN.md").mkdir()
        payload = {"cwd": cwd, "last_assistant_message": "x", "branch_override": "feature/20261105_Sprint_84"}
        code, _out, err = run_hook("sprint-auto-advance.py", json.dumps(payload).encode("utf-8"))
        self.assertEqual(code, hooklib.HOOK_ERROR, err)
        self.assertIn("[sprint-auto-advance] internal error", err)

    def test_malformed_input_and_status_files(self):
        """Does NOT catch a status file that parses but holds the wrong types; load_status treats it as 'not this sprint'."""
        for stdin in (b"", b"  ", b"not json", b"{}", b"[1]"):
            self.assertEqual(run_hook("sprint-auto-advance.py", stdin)[0], 0, stdin)
        self.assertEqual(self.module.decide({"last_assistant_message": 5, "branch_override": "main"}).code, 0)
        for text in ("{bad", "[]", '{"current_sprint": 5}', '{"current_sprint": {"number": [1]}}'):
            cwd = self.project(status_file=False, plan=self.PLAN_OK)
            (Path(cwd) / ".claude" / "sprint_status.json").write_text(text, encoding="utf-8")
            self.assertEqual(self.decide(cwd, self.ASK).code, 2, text)   # unreadable status: normal blocking resumes
        cwd = self.project(status_file=False, plan=self.PLAN_OK)
        (Path(cwd) / ".claude" / "sprint_status.json").write_bytes(
            b"\xef\xbb\xbf" + json.dumps({"current_sprint": {"number": 84, "plan_approved": False}}).encode("utf-8"))
        self.assertEqual(self.decide(cwd, self.ASK).code, 0)            # a BOM does not hide the file

    def test_settings_registers_the_auto_advance_stop_hook_in_python_form_with_its_timeout(self):
        """Does NOT catch Claude Code failing to run the command; it pins the registration text and timeout."""
        settings = json.loads((REPO / ".claude" / "settings.json").read_text(encoding="utf-8"))
        entries = [h for group in settings["hooks"]["Stop"] for h in group["hooks"] if "sprint-auto-advance" in h["command"]]
        self.assertEqual([e["command"] for e in entries],
                         ['python "${CLAUDE_PROJECT_DIR}/.claude/hooks/sprint-auto-advance.py"'])
        self.assertEqual(entries[0]["timeout"], 15)


if __name__ == "__main__":
    unittest.main(verbosity=2)
