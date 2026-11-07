"""PreToolUse hook: block state-changing `git stash` and point to the carry-forward flow (F326, Sprint 84).

Python port of block-carry-forward-stash.ps1 (ADR-0051, F321 layer). Same interface: exit 0 allow,
exit 2 block (stderr to Claude), bypass token `allow_stash`, same message text. Enforces the Phase 6.6
carry-forward rule: create the next branch, then COMMIT the uncommitted files; never stash to carry
forward (Sprint 47 retro Proposal 3).

  - ALLOWS a command that does not invoke `git stash`, a command carrying the literal token
    `allow_stash`, and read-only `git stash list` / `git stash show`.
  - BLOCKS any other `git stash` form (bare `git stash`, push, save, pop, apply, drop, clear).
  - The text of quoted strings and heredoc bodies is data, not an invocation, so it is removed
    before the match (F130-S51 R-2). The bypass token is searched in the RAW command, as the
    PowerShell hook did.
  - An internal error ALLOWS the command and prints a note (hooklib.run).

Tests: .claude/hooks/test-cases/stash-guard/ (run-test-cases.ps1) and .claude/hooks/tests/test_pylib.py.
"""
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import hooklib  # noqa: E402

BYPASS = re.compile(r"allow_stash", re.I)
# Heredoc body: <<EOF ... EOF, <<'EOF' or <<"EOF" (any delimiter name). .NET Replace: case-sensitive.
HEREDOC = re.compile(r"<<-?\s*'?\"?([A-Za-z_][A-Za-z0-9_]*)'?\"?.*?^\s*\1\s*$", re.S | re.M)
SINGLE_QUOTED = re.compile(r"'[^']*'")
DOUBLE_QUOTED = re.compile(r'"[^"]*"')
READ_ONLY = re.compile(r"git\s+stash\s+(list|show)\b", re.I)
STATE_CHANGING = re.compile(r"git\s+stash\b", re.I)

MESSAGE = "\n".join([
    "[BLOCKED] git stash is disallowed for branch carry-forward.",
    "",
    "Sprint 47 retro Proposal 3 (Phase 6.6 carry-forward rule). Stashing to carry",
    "uncommitted work across a branch caused a file to appear reverted (Sprint",
    "46->47) and cost a recovery round.",
    "",
    "Use the DETERMINISTIC flow instead:",
    "  1. Create the next branch:   git checkout -b <next-branch>",
    "  2. COMMIT the uncommitted files on that branch -- they follow the branch.",
    "     Uncommitted changes are already carried by the working tree across a",
    "     git checkout -b; you do NOT need to stash them.",
    "",
    "If you have a genuine, Harold-sanctioned reason to stash (NOT carry-forward),",
    "re-run the command with the literal token allow_stash in it to bypass.",
    "",
    "Reference: memory feedback_follow_deterministic_process; SPRINT_EXECUTION_WORKFLOW.md Phase 6.6.",
])


def command_text(payload: dict) -> str:
    """tool_input.command, else a top-level command (the PowerShell hook read both)."""
    cmd = hooklib.command_of(payload)
    if not cmd and payload.get("command"):
        cmd = str(payload["command"])
    return cmd


def invocation_text(cmd: str) -> str:
    """The command with quoted spans and heredoc bodies replaced by a space."""
    scan = HEREDOC.sub(" ", cmd)
    scan = SINGLE_QUOTED.sub(" ", scan)
    return DOUBLE_QUOTED.sub(" ", scan)


def decide(payload: dict) -> hooklib.Verdict:
    cmd = command_text(payload)
    if not cmd.strip() or BYPASS.search(cmd):
        return hooklib.allow()
    scan = invocation_text(cmd)
    if READ_ONLY.search(scan):
        return hooklib.allow()
    if STATE_CHANGING.search(scan):
        return hooklib.block(MESSAGE)
    return hooklib.allow()


if __name__ == "__main__":
    hooklib.run("block-carry-forward-stash", decide)
