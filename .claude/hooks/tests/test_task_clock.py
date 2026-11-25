"""Tests for the F363 task clock (Sprint 86): lib/task_clock.py, task-clock-gate.py, scripts/task-clock.py and
close-out check 3d-3 (check_task_clock in verify-closeout-complete.py).

Every gate is tested in both directions (it BLOCKS what it should and ALLOWS what it should), and every
fail-closed path is tested with a real unreadable file (R-7).

What these tests do NOT catch: whether Claude Code actually delivers the Agent PostToolUse `status` and
SubagentStop `agent_id` fields as documented (read from the hooks reference, not observed; the first Sprint 86
agent run is the live check); the hook registration in .claude/settings.json (the hook suite runs the file
directly); a commit message reached through a shell form the -F parser does not know.
Run: python -I -m unittest discover -s .claude/hooks/tests -v
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path

HOOKS = Path(__file__).resolve().parent.parent
REPO = HOOKS.parent.parent
sys.path.insert(0, str(HOOKS / "lib"))
import task_clock as tc  # noqa: E402


def _load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


gate = _load("task_clock_gate", HOOKS / "task-clock-gate.py")
cli = _load("task_clock_cli", REPO / "scripts" / "task-clock.py")
closeout = _load("verify_closeout_complete", HOOKS / "verify-closeout-complete.py")

PLAN = """# Sprint 86 Plan

**Cards**: Task 1 #579, Task 2 #568.

## Tasks

### Task 1 -- F362: Store every question (Priority 34)

**Executed-by**: (at completion)
**Est-Effort**: 45-60m

### Task 2 -- F307: Remove the page (Priority 36)

**Executed-by**: (at completion)
**Est-Effort**: 45-75m

## Execution order
"""

VELOCITY = """# Velocity

## Coverage Ledger

| Item | Sprint | Status | Est-Effort | Est-Wall | Act-Effort | Act-Wall | Notes |
|------|--------|--------|-----------|----------|-----------|----------|-------|
| Task 0: old (#1) | 85 | DONE | 10 | 10 | 5 | 5 | x |

## Next
"""


def make_repo(root: Path, status: str = "Phase 4 Sprint Execution", approved: bool = True) -> Path:
    (root / ".claude").mkdir(parents=True, exist_ok=True)
    (root / "docs" / "sprints").mkdir(parents=True, exist_ok=True)
    (root / ".claude" / "sprint_status.json").write_text(json.dumps(
        {"current_sprint": {"number": 86, "status": status, "plan_approved": approved}}), encoding="utf-8")
    (root / "docs" / "sprints" / "SPRINT_86_PLAN.md").write_text(PLAN, encoding="utf-8")
    (root / "docs" / "CODING_VELOCITY.md").write_text(VELOCITY, encoding="utf-8")
    (root / "mobile-app" / "lib").mkdir(parents=True, exist_ok=True)
    return root


def edit_payload(root: Path, rel: str = "mobile-app/lib/a.dart") -> dict:
    return {"hook_event_name": "PreToolUse", "tool_name": "Edit", "cwd": str(root),
            "tool_input": {"file_path": str(root / rel)}}


def run_cli(*argv):
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        code = cli.main(list(argv))
    return code, out.getvalue()


class RepoCase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = make_repo(Path(self._tmp.name))

    def tearDown(self):
        self._tmp.cleanup()

    def ledger(self):
        return tc.load(self.root, 86)


class LibTests(unittest.TestCase):
    def test_minutes_is_union_rounded_up(self):
        t0 = datetime(2026, 11, 24, 1, 0, 0)
        entry = {"segments": [
            {"start": tc.now_text(t0), "end": tc.now_text(t0 + timedelta(minutes=10)), "by": "main"},
            {"start": tc.now_text(t0 + timedelta(minutes=5)), "end": tc.now_text(t0 + timedelta(minutes=12)),
             "by": "agent"},
            {"start": tc.now_text(t0 + timedelta(minutes=20)), "end": tc.now_text(t0 + timedelta(minutes=20, seconds=1)),
             "by": "main"}]}
        self.assertEqual(tc.minutes(entry), 13)  # 12 overlapping + 1 s rounded up

    def test_task_refs_ignore_other_sprints(self):
        self.assertEqual(tc.task_refs("Sprint 85 Task 3 and Task 4, Sprint 86 Task 5, Task 4", 86), ["4", "5"])
        self.assertEqual(tc.task_refs("Tasks 10 and 11", 86), [])

    def test_card_map_reads_header_only(self):
        self.assertEqual(tc.card_map(PLAN), {"579": "1", "568": "2"})

    def test_active_window(self):
        base = {"current_sprint": {"number": 86, "plan_approved": True, "status": "Phase 5.3 Manual Validation"}}
        self.assertEqual(tc.active_sprint(base), 86)
        base["current_sprint"]["status"] = "Phase 7 Retrospective"
        self.assertIsNone(tc.active_sprint(base))
        base["current_sprint"].update(status="Phase 4 Sprint Execution", plan_approved=False)
        self.assertIsNone(tc.active_sprint(base))


class MalformedLedgerTests(RepoCase):
    """C6-6: a ledger that parses as JSON but holds a bad segment must raise LedgerError in `load`, so every
    reader (edit gate, commit gate, close-out check) blocks instead of crashing into an allow.
    What these do NOT catch: a bad `agents` map value (only its type is checked)."""

    BAD_LEDGERS = {
        "non-dict segment": {"1": {"segments": ["x"], "finished": None}},
        "missing start": {"1": {"segments": [{"end": None}], "finished": None}},
        "bad start text": {"1": {"segments": [{"start": "yesterday", "end": None}], "finished": None}},
        "bad end text": {"1": {"segments": [{"start": "2026-11-24T01:00:00", "end": "soon"}], "finished": None}},
        "bad finished text": {"1": {"segments": [], "finished": "done"}},
        "non-string start": {"1": {"segments": [{"start": 5, "end": None}], "finished": None}},
    }

    def write(self, tasks):
        tc.ledger_path(self.root, 86).write_text(json.dumps({"sprint": 86, "tasks": tasks, "agents": {}}),
                                                 encoding="utf-8")

    def test_load_rejects_each_malformed_shape(self):
        for name, tasks in self.BAD_LEDGERS.items():
            with self.subTest(name):
                self.write(tasks)
                with self.assertRaises(tc.LedgerError):
                    tc.load(self.root, 86)

    def test_edit_gate_blocks_on_malformed_segment(self):
        self.write(self.BAD_LEDGERS["non-dict segment"])
        verdict = gate.decide(edit_payload(self.root))
        self.assertEqual(verdict.code, 2)
        self.assertIn("did not run", verdict.stderr)

    def test_valid_ledger_still_loads(self):
        self.write({"1": {"segments": [{"start": "2026-11-24T01:00:00", "end": None, "by": "main",
                                        "agent_id": None}], "finished": None}})
        self.assertEqual(len(tc.load(self.root, 86)["tasks"]["1"]["segments"]), 1)

    def test_save_failure_leaves_no_temp_file_and_raises_ledger_error(self):
        import os
        from unittest import mock
        with mock.patch.object(os, "replace", side_effect=OSError("boom")):
            with self.assertRaises(tc.LedgerError):
                tc.save(self.root, 86, tc.empty_ledger(86))
        self.assertEqual(list(tc.ledger_path(self.root, 86).parent.glob("*.tmp")), [])

    def test_save_mkdir_failure_is_ledger_error(self):
        blocker = self.root / "docs2"
        blocker.write_text("file", encoding="utf-8")
        with mock_ledger_dir(blocker / "sub"):
            with self.assertRaises(tc.LedgerError):
                tc.save(self.root, 86, tc.empty_ledger(86))


def mock_ledger_dir(directory: Path):
    from unittest import mock
    return mock.patch.object(tc, "ledger_path", lambda root, sprint: directory / "L.json")


class EditGateTests(RepoCase):
    def test_blocks_with_no_open_task(self):
        verdict = gate.decide(edit_payload(self.root))
        self.assertEqual(verdict.code, 2)
        self.assertIn("task-clock.py start", verdict.stderr)

    def test_allows_after_start(self):
        self.assertEqual(run_cli("start", "1", "--root", str(self.root))[0], 0)
        self.assertEqual(gate.decide(edit_payload(self.root)).code, 0)

    def test_blocks_again_after_finish(self):
        run_cli("start", "1", "--root", str(self.root))
        run_cli("finish", "1", "--model", "Haiku agent", "--root", str(self.root))
        self.assertEqual(gate.decide(edit_payload(self.root)).code, 2)

    def test_exempt_files_and_outside_repo_allowed(self):
        for rel in ("docs/sprints/SPRINT_86_PLAN.md", "docs/CODING_VELOCITY.md", ".claude/sprint_status.json",
                    "docs/sprints/SPRINT_86_TASK_CLOCK.json", "docs/DECISION_REGISTER.md"):
            self.assertEqual(gate.decide(edit_payload(self.root, rel)).code, 0, rel)
        outside = {"hook_event_name": "PreToolUse", "tool_name": "Write", "cwd": str(self.root),
                   "tool_input": {"file_path": str(Path(tempfile.gettempdir()) / "scratch.py")}}
        self.assertEqual(gate.decide(outside).code, 0)

    def test_outside_phase_window_allowed(self):
        make_repo(self.root, status="Phase 7 Retrospective")
        self.assertEqual(gate.decide(edit_payload(self.root)).code, 0)

    def test_unreadable_ledger_blocks(self):
        tc.ledger_path(self.root, 86).write_text("{not json", encoding="utf-8")
        verdict = gate.decide(edit_payload(self.root))
        self.assertEqual(verdict.code, 2)
        self.assertIn("did not run", verdict.stderr)

    def test_unreadable_status_blocks(self):
        (self.root / ".claude" / "sprint_status.json").write_text("[1, 2", encoding="utf-8")
        self.assertEqual(gate.decide(edit_payload(self.root)).code, 2)

    def test_notebook_path_field_read(self):
        payload = {"hook_event_name": "PreToolUse", "tool_name": "NotebookEdit", "cwd": str(self.root),
                   "tool_input": {"notebook_path": str(self.root / "mobile-app" / "n.ipynb")}}
        self.assertEqual(gate.decide(payload).code, 2)


class CommitGateTests(RepoCase):
    def commit(self, message_file_text=None, inline=""):
        cmd = f'git commit -m "{inline}"'
        if message_file_text is not None:
            path = self.root / "msg.txt"
            path.write_text(message_file_text, encoding="utf-8")
            cmd = f'S="{self.root.as_posix()}"; git commit -q -F "$S/msg.txt"'
        return gate.decide({"hook_event_name": "PreToolUse", "tool_name": "Bash", "cwd": str(self.root),
                            "tool_input": {"command": cmd}})

    def test_closes_before_finish_blocks(self):
        run_cli("start", "1", "--root", str(self.root))
        verdict = self.commit("feat: x\n\nCloses #579\n")
        self.assertEqual(verdict.code, 2)
        self.assertIn("finish 1", verdict.stderr)

    def test_closes_after_finish_allowed(self):
        run_cli("start", "1", "--root", str(self.root))
        run_cli("finish", "1", "--model", "Haiku agent", "--root", str(self.root))
        self.assertEqual(self.commit("feat: x\n\nCloses #579\n").code, 0)

    def test_task_never_started_blocks(self):
        self.assertEqual(self.commit(inline="Sprint 86 Task 2: progress").code, 2)

    def run_cmd(self, cmd):
        return gate.decide({"hook_event_name": "PreToolUse", "tool_name": "Bash", "cwd": str(self.root),
                            "tool_input": {"command": cmd}})

    def test_long_file_forms_are_read(self):
        # Before the fix only `-F <file>` was read, so a Closes in a --file message was never seen (allowed).
        (self.root / "msg.txt").write_text("feat: x\n\nCloses #579\n", encoding="utf-8")
        run_cli("start", "1", "--root", str(self.root))
        for cmd in ("git commit --file=msg.txt", "git commit --file msg.txt", "git commit -F msg.txt"):
            with self.subTest(cmd):
                verdict = self.run_cmd(cmd)
                self.assertEqual(verdict.code, 2)
                self.assertIn("finish 1", verdict.stderr)

    def test_flag_like_words_in_message_text_are_not_message_files(self):
        # A message that mentions -Force, -File or -First must not be read as `-F <file>` (false block).
        for cmd in ('git commit -m "docs: use Remove-Item -Force -Recurse"', 'git commit -m "x -Filter y"',
                    'git commit -m "x -First 3"'):
            with self.subTest(cmd):
                self.assertEqual(self.run_cmd(cmd).code, 0)

    def test_message_from_stdin_blocks_with_file_hint(self):
        for cmd in ("git commit -F - < msg.txt", "git commit --file=- < msg.txt"):
            with self.subTest(cmd):
                verdict = self.run_cmd(cmd)
                self.assertEqual(verdict.code, 2)
                self.assertIn("stdin", verdict.stderr)

    def test_other_card_and_other_sprint_allowed(self):
        self.assertEqual(self.commit("docs: Closes #12345; see Sprint 85 Task 2\n").code, 0)

    def test_unexpandable_message_file_blocks(self):
        verdict = gate.decide({"hook_event_name": "PreToolUse", "tool_name": "Bash", "cwd": str(self.root),
                               "tool_input": {"command": 'git commit -F "$UNSET_DIR/m.txt"'}})
        self.assertEqual(verdict.code, 2)
        self.assertIn("did not run", verdict.stderr)

    def test_missing_message_file_blocks(self):
        verdict = gate.decide({"hook_event_name": "PreToolUse", "tool_name": "Bash", "cwd": str(self.root),
                               "tool_input": {"command": "git commit -F nothere.txt"}})
        self.assertEqual(verdict.code, 2)

    def test_non_commit_allowed(self):
        verdict = gate.decide({"hook_event_name": "PreToolUse", "tool_name": "Bash", "cwd": str(self.root),
                               "tool_input": {"command": "git status --short"}})
        self.assertEqual(verdict.code, 0)


class AgentClockTests(RepoCase):
    def agent(self, event, description="Sprint 86 Task 2 -- F307", response=None, agent_id=None):
        payload = {"hook_event_name": event, "tool_name": "Agent", "cwd": str(self.root),
                   "tool_input": {"description": description, "prompt": "do it"}}
        if response is not None:
            payload["tool_response"] = response
        if agent_id is not None:
            payload = {"hook_event_name": "SubagentStop", "cwd": str(self.root), "agent_id": agent_id}
        return gate.decide(payload)

    def test_pre_starts_and_foreground_post_stops(self):
        self.assertEqual(self.agent("PreToolUse").code, 0)
        self.assertEqual(len(tc.open_segments(self.ledger(), "2")), 1)
        self.agent("PostToolUse", response={"status": "completed", "agentId": "a1"})
        self.assertEqual(tc.open_segments(self.ledger(), "2"), [])

    def test_background_stops_at_subagent_stop(self):
        self.agent("PreToolUse")
        self.agent("PostToolUse", response={"status": "async_launched", "agentId": "bg1"})
        self.assertEqual(len(tc.open_segments(self.ledger(), "2")), 1)
        self.assertEqual(self.ledger()["agents"], {"bg1": "2"})
        self.agent("SubagentStop", agent_id="other")
        self.assertEqual(len(tc.open_segments(self.ledger(), "2")), 1)
        self.agent("SubagentStop", agent_id="bg1")
        self.assertEqual(tc.open_segments(self.ledger(), "2"), [])

    def test_a_later_subagent_stop_moves_the_end_forward(self):
        """Sprint 86 Task 2: SubagentStop fired at an interim pause (87 of 150 min) and the final stop was
        ignored. Does NOT catch an agent whose LAST stop never fires (its segment ends at the interim stop)."""
        self.agent("PreToolUse")
        self.agent("PostToolUse", response={"status": "async_launched", "agentId": "bg1"})
        self.agent("SubagentStop", agent_id="bg1")
        ledger = self.ledger()
        segment = ledger["tasks"]["2"]["segments"][-1]
        segment["end"] = "2026-11-24T01:00:00"   # the interim stop, well in the past
        tc.save(self.root, 86, ledger)
        self.agent("SubagentStop", agent_id="bg1")
        moved = self.ledger()["tasks"]["2"]["segments"][-1]["end"]
        self.assertGreater(tc.parse_time(moved), tc.parse_time("2026-11-24T01:00:00"))
        ledger = self.ledger()
        ledger["tasks"]["2"]["finished"] = "2026-11-24T02:00:00"
        ledger["tasks"]["2"]["segments"][-1]["end"] = "2026-11-24T01:30:00"
        tc.save(self.root, 86, ledger)
        self.agent("SubagentStop", agent_id="bg1")
        self.assertEqual(self.ledger()["tasks"]["2"]["segments"][-1]["end"], "2026-11-24T01:30:00",
                         "a finished task is not extended")

    def test_agent_without_task_ref_writes_nothing(self):
        self.agent("PreToolUse", description="Claude Code hook payload facts")
        self.assertFalse(tc.ledger_path(self.root, 86).exists())

    def test_agent_never_blocks_on_unreadable_ledger(self):
        tc.ledger_path(self.root, 86).write_text("{", encoding="utf-8")
        verdict = self.agent("PreToolUse")
        self.assertEqual(verdict.code, 0)


class CliTests(RepoCase):
    def test_finish_writes_plan_velocity_status(self):
        run_cli("start", "2", "--root", str(self.root))
        code, out = run_cli("finish", "2", "--model", "Haiku agent", "--note", "R-1 audit ok", "--root",
                            str(self.root))
        self.assertEqual(code, 0, out)
        self.assertNotIn("FAIL", out)
        plan = (self.root / "docs" / "sprints" / "SPRINT_86_PLAN.md").read_text(encoding="utf-8")
        self.assertRegex(plan, r"### Task 2 --[^#]*\*\*Executed-by\*\*: Haiku agent -- 1 min \(task clock ")
        self.assertIn("**Executed-by**: (at completion)", plan)  # Task 1 untouched
        velocity = (self.root / "docs" / "CODING_VELOCITY.md").read_text(encoding="utf-8")
        self.assertIn("| Task 2: F307: Remove the page (#568) | 86 | DONE | 45-75 | 45-75 | 1 | 1 |", velocity)
        self.assertLess(velocity.index("| Task 2: F307"), velocity.index("## Next"))
        status = json.loads((self.root / ".claude" / "sprint_status.json").read_text(encoding="utf-8"))
        self.assertEqual(status["current_sprint"]["task_status"]["2"], "DONE")

    def test_finish_without_start_fails(self):
        code, out = run_cli("finish", "1", "--model", "x", "--root", str(self.root))
        self.assertEqual(code, 1)
        self.assertIn("no start", out)

    def test_finish_without_executed_by_line_leaves_ledger_unfinished(self):
        plan = tc.plan_path(self.root, 86)
        plan.write_text(PLAN.replace("**Executed-by**: (at completion)\n**Est-Effort**: 45-75m", "**Est-Effort**: 45-75m"),
                        encoding="utf-8")
        run_cli("start", "2", "--root", str(self.root))
        code, out = run_cli("finish", "2", "--model", "x", "--root", str(self.root))
        self.assertEqual(code, 1)
        self.assertIn("no '**Executed-by**' line", out)
        self.assertIsNone(self.ledger()["tasks"]["2"]["finished"])
        self.assertEqual(len(tc.open_segments(self.ledger(), "2")), 1)

    def test_start_of_finished_task_refused(self):
        run_cli("start", "1", "--root", str(self.root))
        run_cli("finish", "1", "--model", "x", "--root", str(self.root))
        self.assertEqual(run_cli("start", "1", "--root", str(self.root))[0], 1)

    def test_start_of_task_with_no_card_refused(self):
        code, out = run_cli("start", "99", "--root", str(self.root))
        self.assertEqual(code, 1)
        self.assertIn("no '### Task 99 --' card", out)
        self.assertFalse(tc.ledger_path(self.root, 86).exists())

    def test_finish_with_missing_velocity_header_writes_nothing(self):
        # C6-7: the refusal comes BEFORE the ledger, plan or status are touched.
        (self.root / "docs" / "CODING_VELOCITY.md").write_text("# Velocity\n", encoding="utf-8")
        run_cli("start", "1", "--root", str(self.root))
        plan_before = tc.plan_path(self.root, 86).read_text(encoding="utf-8")
        status_before = (self.root / ".claude" / "sprint_status.json").read_text(encoding="utf-8")
        code, out = run_cli("finish", "1", "--model", "x", "--root", str(self.root))
        self.assertEqual(code, 1)
        self.assertIn("Coverage Ledger header", out)
        self.assertIsNone(self.ledger()["tasks"]["1"]["finished"])
        self.assertEqual(tc.plan_path(self.root, 86).read_text(encoding="utf-8"), plan_before)
        self.assertEqual((self.root / ".claude" / "sprint_status.json").read_text(encoding="utf-8"), status_before)

    def test_unreadable_ledger_exit_2(self):
        tc.ledger_path(self.root, 86).write_text("[", encoding="utf-8")
        self.assertEqual(run_cli("status", "--root", str(self.root))[0], 2)

    def test_real_process_missing_root_exit_2(self):
        with tempfile.TemporaryDirectory() as empty:
            done = subprocess.run([sys.executable, str(REPO / "scripts" / "task-clock.py"), "status", "--root",
                                   empty], capture_output=True, text=True,
                                  env={"PATH": "", "SYSTEMROOT": __import__("os").environ.get("SYSTEMROOT", "")})
        self.assertEqual(done.returncode, 2, done.stderr)


class CloseoutTests(RepoCase):
    def violations(self):
        found = []
        status = json.loads((self.root / ".claude" / "sprint_status.json").read_text(encoding="utf-8"))
        closeout.check_task_clock(status, str(self.root), 86, found)
        return found

    def test_sprint85_text_blocks(self):
        plan = tc.plan_path(self.root, 86)
        plan.write_text(PLAN.replace("**Executed-by**: (at completion)",
                                     "**Executed-by**: Opus main session -- actual minutes not recorded, 0 min logged"),
                        encoding="utf-8")
        self.assertTrue(self.violations())

    def test_clocked_cards_pass(self):
        for task in ("1", "2"):
            run_cli("start", task, "--root", str(self.root))
            run_cli("finish", task, "--model", "Haiku agent", "--root", str(self.root))
        self.assertEqual(self.violations(), [])

    def test_wrong_minutes_block(self):
        for task in ("1", "2"):
            run_cli("start", task, "--root", str(self.root))
            run_cli("finish", task, "--model", "Haiku agent", "--root", str(self.root))
        plan = tc.plan_path(self.root, 86)
        plan.write_text(plan.read_text(encoding="utf-8").replace("-- 1 min", "-- 45 min", 1), encoding="utf-8")
        self.assertTrue(any("ledger total" in v for v in self.violations()))

    def test_not_recorded_blocks_even_with_matching_minutes(self):
        # Kills the surviving mutant: the line names the right ledger total AND admits a gap.
        for task in ("1", "2"):
            run_cli("start", task, "--root", str(self.root))
            run_cli("finish", task, "--model", "Haiku agent", "--note", "lead time not recorded", "--root",
                    str(self.root))
        self.assertTrue(any("not recorded" in v for v in self.violations()))

    def clocked_with(self, executed_by_for_task_1: str):
        for task in ("1", "2"):
            run_cli("start", task, "--root", str(self.root))
            run_cli("finish", task, "--model", "Haiku agent", "--root", str(self.root))
        plan = tc.plan_path(self.root, 86)
        text = plan.read_text(encoding="utf-8")
        start = text.index("**Executed-by**:", text.index("### Task 1"))
        end = text.index("\n", start)
        plan.write_text(text[:start] + "**Executed-by**: " + executed_by_for_task_1 + text[end:], encoding="utf-8")

    def test_register_decision_excuses_gap(self):
        (self.root / "docs").mkdir(exist_ok=True)
        (self.root / "docs" / "DECISION_REGISTER.md").write_text(
            "# Decision register\n\n### d9. Task 1 minutes not recorded, accepted\n", encoding="utf-8")
        self.clocked_with("not recorded, accepted in register d9")
        self.assertEqual(self.violations(), [])

    def test_register_decision_missing_from_the_register_does_not_excuse_gap(self):
        # Sprint 86 7.7.1 L6: naming a decision is not enough; it must exist in docs/DECISION_REGISTER.md.
        self.clocked_with("not recorded, accepted in register d9")
        self.assertTrue(any("not in docs/DECISION_REGISTER.md" in v for v in self.violations()))

    def test_bare_d_number_does_not_excuse_gap(self):
        # C6-8: "d9" without "register" is not the explicit form.
        self.clocked_with("not recorded, see d9")
        self.assertTrue(any("Task 1" in v and "not recorded" in v for v in self.violations()))

    def test_register_decision_does_not_skip_start_finish_checks(self):
        # C6-8: the register form excuses only the 0 min / not recorded text; an unclocked card still fails.
        plan = tc.plan_path(self.root, 86)
        plan.write_text(PLAN.replace("**Executed-by**: (at completion)",
                                     "**Executed-by**: not recorded, accepted in register d9"), encoding="utf-8")
        self.assertTrue(any("no start in the ledger" in v for v in self.violations()))

    def test_register_decision_does_not_excuse_wrong_minutes(self):
        self.clocked_with("Haiku agent -- 999 min, register d9")
        self.assertTrue(any("ledger total" in v for v in self.violations()))

    def test_unreadable_ledger_is_violation(self):
        tc.ledger_path(self.root, 86).write_text("{", encoding="utf-8")
        self.assertTrue(any("did not run" in v for v in self.violations()))

    def test_before_sprint_86_not_checked(self):
        found = []
        closeout.check_task_clock({"current_sprint": {"plan_approved": True}}, str(self.root), 85, found)
        self.assertEqual(found, [])


if __name__ == "__main__":
    unittest.main()
