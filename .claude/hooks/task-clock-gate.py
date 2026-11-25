"""Task clock gates and automatic subagent clocking (F363, Sprint 86; register q2 = 1).

One hook file, registered for four events (see .claude/settings.json):

  PreToolUse  Edit|Write|NotebookEdit  R-3: BLOCK an edit to a file in the repo when no task clock is open.
  PreToolUse  Bash|PowerShell          R-4: BLOCK a `git commit` whose message has `Closes #<card>` for a task
                                       that is not finished, or names `Task <N>` for a task never started.
  PreToolUse  Agent                    R-2: START the clock of the task the prompt names (`Task <N>`).
  PostToolUse Agent                    R-2: a foreground run that completed STOPS its segment; a background run
                                       (status async_launched) records its agentId for SubagentStop.
  SubagentStop                         R-2: STOPS the segment of the background agent that finished. It fires
                                       again each time the agent stops after waiting on its own background
                                       work; a later stop moves the segment end forward (Sprint 86 Task 2).

Only during Phases 4-5 of an approved plan (current_sprint.status starts "Phase 4" or "Phase 5" and
plan_approved is true); outside that window every event is allowed and nothing is written.

Fail closed (R-7): when sprint_status.json or the ledger exists but cannot be read, the two GATES block with
"the check did not run" (an unreadable state is not a pass). The three clocking events never block; they
report the problem as a notice. A repo with no sprint_status.json is not a sprint repo: allowed.

Exempt from the edit gate (they are how a task is started, recorded or a broken state is fixed): the sprint
plan, the ledger, docs/CODING_VELOCITY.md, docs/DECISION_REGISTER.md, .claude/sprint_status.json, and any file
git ignores (scratch probes, build output). A file outside the repo (the session scratchpad) is not gated.

Facts relied on (https://code.claude.com/docs/en/hooks, read 2026-11-24 through a claude-code-guide agent):
the subagent tool is named `Agent`, its tool_input has `prompt` and `description`; PostToolUse tool_response
has `status` "completed" (foreground) or "async_launched" (background) and `agentId`; SubagentStop input has
`agent_id`; project hooks also fire for tool calls made inside subagents. Edit and Write carry
`tool_input.file_path`; NotebookEdit's field is UNVERIFIED, so both `file_path` and `notebook_path` are read.

What this does NOT catch: work on task B while task A's clock is open (the gate asks only that SOME task is
open); a background agent whose SubagentStop never fires (its segment stays open until `finish`); a task done
only in conversation (close-out check 3d-3 catches it); a tracked file written by a SHELL command (PowerShell
Set-Content, a Python script) rather than Edit/Write, which this hook does not see; an editor commit with no -m or
-F (it cannot run in this non-interactive harness); a `Closes #N` for a card in neither the plan header nor a task
heading (allowed with a notice naming the card); the MINUTES of an Agent launch that was denied or failed (its
segment stays open until `finish` and is counted; it no longer opens the edit gate for the main session, M-1).
Tests: .claude/hooks/test-cases/task-clock/ and
.claude/hooks/tests/test_task_clock.py.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import common  # noqa: E402
import hooklib  # noqa: E402
import task_clock as tc  # noqa: E402

EDIT_TOOLS = {"edit", "write", "notebookedit", "multiedit"}
SHELL_TOOLS = {"bash", "powershell"}
GIT_COMMIT = re.compile(r"\bgit\b[^\n;&|]*\bcommit\b", re.I)
# -F with a space, attached (-Fmsg.txt), or last in a combined short-flag group (-qF msg.txt); --file= / --file
# (Sprint 86 7.7.1 L1: the attached and combined forms were not read, so their `Closes #` went unchecked).
MESSAGE_FILE = re.compile(r"\bgit\b[^\n;&|]*?\bcommit\b[^\n;&|]*?\s(?:-[A-Za-z]*F\s*|--file(?:=|\s+))"
                          r"(\"([^\"]+)\"|'([^']+)'|(\S+))")
QUOTED_SPAN = re.compile(r"\"[^\"]*\"|'[^']*'")  # same spans common.strip_quoted empties
ASSIGNMENT = re.compile(r"(?:^|[\s;&])(?:\$)?([A-Za-z_]\w*)\s*=\s*(\"([^\"]*)\"|'([^']*)'|([^\s;&|]+))")
VARIABLE = re.compile(r"\$\{?([A-Za-z_]\w*)\}?")
GIT_BASH_PATH = re.compile(r"^/([A-Za-z])/(.*)$")
CLOSES = re.compile(r"\b(?:Closes|Fixes|Resolves)\s+#(\d+)", re.I)
START_HINT = "python scripts/task-clock.py start <task>"


def _exempt(root: Path, sprint: int) -> set:
    return {
        tc.plan_path(root, sprint).resolve(),
        tc.ledger_path(root, sprint).resolve(),
        (root / "docs" / "CODING_VELOCITY.md").resolve(),
        (root / "docs" / "DECISION_REGISTER.md").resolve(),
        (root / tc.STATUS_FILE).resolve(),
    }


def _did_not_run(what: str, problem: str) -> hooklib.Verdict:
    return hooklib.block(
        f"[BLOCKED] F363 task clock: {problem}, so the {what} check did not run (an unreadable state is not a "
        "pass, R-7). Fix the file named above; sprint_status.json and the ledger can always be edited.")


def _state(payload: dict):
    """(root, sprint, ledger) when the gates apply; None outside a sprint repo or outside Phases 4-5.
    Raises tc.LedgerError for a status file or ledger that exists but cannot be read."""
    root = tc.find_root(hooklib.cwd_of(payload) or None)
    if root is None:
        return None
    sprint = tc.active_sprint(tc.read_status(root))
    if sprint is None:
        return None
    return root, sprint, tc.load(root, sprint)


# --------------------------------------------------------------------------------------- edit gate (R-3)

def _edit_path(payload: dict) -> str:
    tool_input = payload.get("tool_input")
    if not isinstance(tool_input, dict):
        return ""
    return str(tool_input.get("file_path") or tool_input.get("notebook_path") or "")


def _ignored(root: Path, path: Path) -> bool:
    """True only when git says the path is ignored (exit 0). Any other answer (not ignored, no git) is False:
    an unknown file is gated, never waved through."""
    code, _out = common.git("-C", str(root), "check-ignore", "-q", "--", str(path), timeout=5)
    return code == 0


def _clock_covers(payload: dict, open_segments: list) -> bool:
    """True when an open segment covers this edit.

    Sprint 86 7.7.1 M-1: an agent segment with no agent_id is opened at the Agent PreToolUse, before the launch. A
    launch that is denied gets no PostToolUse ("Permission denials fire PreToolUse but not this event",
    https://code.claude.com/docs/en/hooks), so that segment can stay open with nothing running. It covers only an
    edit made INSIDE a subagent (the hook input then carries `agent_id`, same page), never a main-session edit, so
    the main session cannot inherit a dead launch's clock."""
    from_subagent = bool(payload.get("agent_id"))
    for _key, segment in open_segments:
        if from_subagent or not (segment.get("by") == "agent" and not segment.get("agent_id")):
            return True
    return False


def edit_gate(payload: dict) -> hooklib.Verdict:
    raw = _edit_path(payload)
    if not raw:
        return hooklib.allow()
    try:
        state = _state(payload)
    except tc.LedgerError as exc:
        return _did_not_run("edit", str(exc))
    if state is None:
        return hooklib.allow()
    root, sprint, ledger = state
    path = Path(raw)
    if not path.is_absolute():
        path = Path(hooklib.cwd_of(payload) or root) / path
    try:
        path = path.resolve()
        relative = path.relative_to(root.resolve())
    except (OSError, ValueError):
        return hooklib.allow()  # outside the repo (the session scratchpad): not a tracked file
    if relative.parts and relative.parts[0] == ".git":
        return hooklib.allow()
    if path in _exempt(root, sprint) or _ignored(root, path):
        return hooklib.allow()
    if _clock_covers(payload, tc.open_segments(ledger)):
        return hooklib.allow()
    finished = sorted(k for k, v in ledger["tasks"].items() if v.get("finished"))
    return hooklib.block(
        f"[BLOCKED] F363 task clock: Sprint {sprint} is in Phase 4-5 and no task clock is open, so this edit to "
        f"{relative.as_posix()} belongs to no task and its minutes would be lost (Sprint 85: six cards closed with "
        f"'0 min logged').\n\nStart the task first (the script reads the clock; never type a time):\n"
        f"    {START_HINT}\n\nFinished tasks: {', '.join(finished) or 'none'}. Exempt files (no task needed): the "
        "sprint plan, the task-clock ledger, CODING_VELOCITY.md, DECISION_REGISTER.md, sprint_status.json, "
        "git-ignored files.")


# --------------------------------------------------------------------------------------- commit gate (R-4)

def _message(cmd: str, cwd: str) -> str:
    """The commit message text: the command plus the -F file. Raises ValueError when the file cannot be read."""
    # The flag is looked for OUTSIDE quoted text only: the attached form (-Fmsg.txt) would otherwise read
    # "-Force" or "-First" inside a quoted -m message as a message file. Each quoted span is blanked to the
    # same length (its quote marks kept), so the match positions still index the original command.
    masked = QUOTED_SPAN.sub(lambda m: m.group(0)[0] + " " * (len(m.group(0)) - 2) + m.group(0)[-1], cmd)
    match = MESSAGE_FILE.search(masked)
    if not match:
        return cmd
    groups = [(match.start(i), match.end(i)) for i in (2, 3, 4)]
    path = next(cmd[s:e] for s, e in groups if s >= 0 and e > s)
    if path == "-":
        # Same fail-closed rule as an unreadable file: the hook cannot see what git will read from stdin.
        raise ValueError("the message is read from stdin (-F -), which this hook cannot read; write the message "
                         "to a file and use -F <file>")
    values = {m.group(1): next(g for g in (m.group(3), m.group(4), m.group(5)) if g is not None)
              for m in ASSIGNMENT.finditer(cmd)}
    unknown = [name for name in VARIABLE.findall(path) if name not in values]
    if unknown or "%" in path:
        raise ValueError(f"the message file {path} uses a variable this hook cannot expand "
                         f"({', '.join(unknown) or '%VAR%'}); set it in the same command or use a literal path")
    path = VARIABLE.sub(lambda m: values[m.group(1)], path)
    bash = GIT_BASH_PATH.match(path)
    if bash:
        path = f"{bash.group(1)}:/{bash.group(2)}"
    full = Path(path) if os.path.isabs(path) else Path(cwd) / path
    try:
        return cmd + "\n" + full.read_bytes().decode("utf-8-sig", errors="replace")
    except OSError as exc:
        raise ValueError(f"the message file {full} could not be read ({exc.strerror})") from exc


def commit_gate(payload: dict) -> hooklib.Verdict:
    cmd = hooklib.command_of(payload)
    if not GIT_COMMIT.search(common.strip_quoted(cmd)):
        return hooklib.allow()
    try:
        state = _state(payload)
    except tc.LedgerError as exc:
        return _did_not_run("commit", str(exc))
    if state is None:
        return hooklib.allow()
    root, sprint, ledger = state
    try:
        text = _message(cmd, hooklib.cwd_of(payload) or str(root))
    except ValueError as exc:
        return _did_not_run("commit", str(exc))
    try:
        cards = tc.card_map(tc.plan_path(root, sprint).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:  # ValueError: not UTF-8 (Sprint 86 7.7.1 L2; it escaped and allowed)
        return _did_not_run("commit", f"SPRINT_{sprint}_PLAN.md could not be read "
                                      f"({getattr(exc, 'strerror', None) or exc.__class__.__name__})")
    closes = list(dict.fromkeys(CLOSES.findall(text)))
    if closes and not cards:
        # An approved plan always lists its cards; none found means the format changed (Sprint 86 7.7.1 M2).
        return _did_not_run("commit", f"no 'Task N #card' pair or '(#card)' task heading was found in "
                                      f"SPRINT_{sprint}_PLAN.md")
    problems = []
    for card in closes:
        task = cards.get(card)
        if task is None:
            hooklib.notice(f"F363 task clock: 'Closes #{card}' names a card in neither the SPRINT_{sprint}_PLAN.md "
                           "header nor a task heading, so its task clock was not checked")
            continue
        if not ledger["tasks"].get(task, {}).get("finished"):
            problems.append(f"'Closes #{card}' closes Task {task}, which has no finish in the ledger. Run "
                            f"'python scripts/task-clock.py finish {task} --model \"<model>\"' first (it writes the "
                            "minutes into the plan and CODING_VELOCITY.md, so stage those with the commit).")
    for task in tc.task_refs(text, sprint):
        if not ledger["tasks"].get(task, {}).get("segments"):
            problems.append(f"the message names Task {task}, which was never started in the ledger. Its time cannot "
                            "be backdated; start it now and record the gap in the finish --note.")
    if not problems:
        return hooklib.allow()
    return hooklib.block("[BLOCKED] F363 task clock (commit gate):\n" + "\n".join(f"  - {p}" for p in problems))


# --------------------------------------------------------------------------------------- agent clocking (R-2)

def _agent_task(payload: dict, sprint: int) -> str | None:
    tool_input = payload.get("tool_input") if isinstance(payload.get("tool_input"), dict) else {}
    for field in ("description", "prompt"):
        refs = tc.task_refs(str(tool_input.get(field) or ""), sprint)
        if refs:
            return refs[0]
    return None


def agent_event(payload: dict) -> hooklib.Verdict:
    event = str(payload.get("hook_event_name") or "")
    try:
        state = _state(payload)
        if state is None:
            return hooklib.allow()
        root, sprint, ledger = state
        if event == "SubagentStop":
            agent_id = str(payload.get("agent_id") or "")
            task = ledger["agents"].get(agent_id) if agent_id else None
            if task and (tc.stop(ledger, task, agent_id=agent_id)
                         or tc.extend_agent_stop(ledger, task, agent_id)):
                tc.save(root, sprint, ledger)
            return hooklib.allow()
        task = _agent_task(payload, sprint)
        if task is None:
            return hooklib.allow()
        if event == "PostToolUse":
            response = payload.get("tool_response") if isinstance(payload.get("tool_response"), dict) else {}
            status = str(response.get("status") or "")
            agent_id = str(response.get("agentId") or "")
            pending = [seg for _k, seg in tc.open_segments(ledger, task)
                       if seg.get("by") == "agent" and not seg.get("agent_id")]
            if status == "async_launched" and agent_id:
                if pending:
                    pending[-1]["agent_id"] = agent_id
                ledger["agents"][agent_id] = task
            elif status == "async_launched":
                # Sprint 86 7.7.1 L3: closing the segment here would record 0 minutes for a background agent.
                hooklib.notice(f"F363 task clock: a background agent on Task {task} has no agentId; its segment "
                               "stays open until 'finish'")
            elif pending:
                pending[-1]["end"] = tc.now_text()
            tc.save(root, sprint, ledger)
            return hooklib.allow()
        # PreToolUse: open an agent segment (a second agent on the same task gets its own segment).
        entry = tc.task_entry(ledger, task)
        if entry.get("finished"):
            hooklib.notice(f"F363 task clock: Task {task} is already finished; this agent's time is not recorded")
            return hooklib.allow()
        entry["segments"].append({"start": tc.now_text(), "end": None, "by": "agent", "agent_id": None})
        tc.save(root, sprint, ledger)
        hooklib.notice(f"F363 task clock: Task {task} started for this agent")
        return hooklib.allow()
    except tc.LedgerError as exc:
        hooklib.notice(f"F363 task clock: {exc}; this agent's time was NOT recorded")
        return hooklib.allow()


def decide(payload: dict) -> hooklib.Verdict:
    event = str(payload.get("hook_event_name") or "PreToolUse")
    tool = hooklib.tool_name(payload).lower()
    if event == "SubagentStop" or tool == "agent":
        return agent_event(payload)
    if event != "PreToolUse":
        return hooklib.allow()
    if tool in EDIT_TOOLS:
        return edit_gate(payload)
    if tool in SHELL_TOOLS:
        return commit_gate(payload)
    return hooklib.allow()


if __name__ == "__main__":
    hooklib.run("task-clock-gate", decide)
