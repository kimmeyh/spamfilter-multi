"""PreToolUse hook: WARN (never block) when a task-closing commit lacks its docs/CODING_VELOCITY.md row (F326, Sprint 84).

Python port of warn-commit-without-velocity.ps1 (Sprint 82 retro IMP-7; ADR-0051, F321 layer). Same
contract: exit 0 always, and the warning is written as JSON on stdout,
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": "..."}}, because Claude Code
shows the model only the JSON form of an exit-0 hook (code.claude.com/docs/en/hooks, read 2026-10-31).

  - Looks at Bash and PowerShell tool calls that run `git commit`.
  - When the commit message (the command text, plus the file named by -F) contains `Closes #N` or
    `Task N`, it checks that docs/CODING_VELOCITY.md is in the commit: already staged, or modified and
    staged by the same command (`git add -A` / `--all` / `-u` / `.`, a `commit -a`, or a named path).
  - A message file it cannot read, or git state it cannot read, is REPORTED in the warning ("the check
    did not run"), so a broken gate does not look like a passing one.
  - Any other exception is reported the same way (the first exception handler in decide()).

Tests: .claude/hooks/test-cases/velocity-warn/ (run-test-cases.py) and .claude/hooks/tests/test_pylib.py.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import common  # noqa: E402
import hooklib  # noqa: E402

VELOCITY = "docs/CODING_VELOCITY.md"
GIT_COMMIT = re.compile(r"\bgit\b[^\n;&|]*\bcommit\b", re.I)
# The -F file that belongs to the git commit itself (case-sensitive, as the .NET regex was).
MESSAGE_FILE = re.compile(
    r"\bgit\b[^\n;&|]*?\bcommit\b[^\n;&|]*?\s-F\s+(\"([^\"]+)\"|'([^']+)'|(\S+))")
GIT_BASH_PATH = re.compile(r"^/([A-Za-z])/(.*)$")
CLOSES_TASK = re.compile(r"\bCloses\s+#\d+|\bTask\s+\d+\b", re.I)
STAGES_ALL = [
    re.compile(r"\bgit\s+add\s+(-A\b|--all\b|-u\b|--update\b|\.(?=\s|$|[;&|]))", re.I),
    re.compile(r"\bgit\b[^\n;&|]*\bcommit\b[^\n;&|]*\s-[A-Za-z]*a", re.I),
    re.compile(r"\bgit\b[^\n;&|]*\bcommit\b[^\n;&|]*\s--all\b", re.I),
]
NAMES_VELOCITY = re.compile(r"\bgit\s+add\b[^\n;&|]*(CODING_VELOCITY\.md|\sdocs/?(?=\s|$|[;&|]))", re.I)


HTML_SENSITIVE = {"'": "\\u0027", "<": "\\u003c", ">": "\\u003e", "&": "\\u0026"}


def send_context(text: str) -> hooklib.Verdict:
    """The warning as the JSON form Claude Code delivers to the model (exit 0).

    Windows PowerShell 5.1 ConvertTo-Json (the hook this replaces) escapes ' < > & as \\uXXXX; the
    escaping is kept so the stdout bytes match (checked by the Sprint 84 parity probe)."""
    body = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": text}}
    encoded = json.dumps(body, separators=(",", ":"))
    for char, escape in HTML_SENSITIVE.items():
        encoded = encoded.replace(char, escape)
    return hooklib.allow(stdout=encoded)


def message_text(cmd: str, cwd: str):
    """The text searched for a task reference, and a note when a -F file could not be read."""
    text = cmd
    match = MESSAGE_FILE.search(cmd)
    if not match:
        return text, None
    path = next((g for g in (match.group(2), match.group(3), match.group(4)) if g), "")
    git_bash = GIT_BASH_PATH.match(path)
    if git_bash:
        path = f"{git_bash.group(1)}:\\{git_bash.group(2)}"
    if re.search(r"[$%]", path):
        return text, f"{path} (a variable the hook cannot expand)"
    if not os.path.isabs(path):
        path = os.path.join(cwd, path)
    if not os.path.exists(path):
        return text, f"{path} (not found)"
    with open(path, "rb") as handle:  # raises when the path is a folder: reported by decide()
        text += "\n" + handle.read().decode("utf-8-sig", errors="replace")
    return text, None


def velocity_in_commit(cmd: str, root: str, modified: bool) -> bool:
    """True when the velocity file is already staged, or this command stages it with the commit."""
    _rc, staged_out = common.git("-C", root, "diff", "--cached", "--name-only")
    if any(line.lower() == VELOCITY.lower() for line in staged_out.splitlines()):
        return True
    stages_all = any(p.search(cmd) for p in STAGES_ALL)
    return modified and (stages_all or bool(NAMES_VELOCITY.search(cmd)))


def check(payload: dict) -> hooklib.Verdict:
    tool = hooklib.tool_name(payload)
    if tool and tool.lower() not in ("bash", "powershell"):
        return hooklib.allow()
    cmd = hooklib.command_of(payload)
    if not cmd.strip() or not GIT_COMMIT.search(cmd):
        return hooklib.allow()

    cwd = hooklib.cwd_of(payload) or os.environ.get("CLAUDE_PROJECT_DIR", "")
    if not cwd.strip():
        # Sprint 84 7.7.1: with no working folder the message file and git state cannot be read. Say so when
        # the commit could be task-closing (its text names a task, or its message is in a -F file we cannot open).
        if CLOSES_TASK.search(cmd) or MESSAGE_FILE.search(cmd):
            return send_context(
                "[WARNING] Sprint 82 retro IMP-7: this commit may close a task, but the hook payload has no "
                "working directory (and CLAUDE_PROJECT_DIR is unset), so the CODING_VELOCITY check did not run. "
                "Confirm the velocity row is in the commit.")
        return hooklib.allow()

    text, unreadable = message_text(cmd, cwd)
    if not CLOSES_TASK.search(text):
        if unreadable:
            return send_context(
                "[WARNING] Sprint 82 retro IMP-7: the commit message file "
                f"{unreadable} could not be read, so the CODING_VELOCITY check did "
                "not run. If this commit closes a task, confirm its velocity row "
                "and Executed-by line are in it.")
        return hooklib.allow()

    rc, root_out = common.git("-C", cwd, "rev-parse", "--show-toplevel")
    root = root_out.strip()
    if rc != 0 or not root:
        return send_context(
            "[WARNING] Sprint 82 retro IMP-7: this commit closes a task, "
            f"but git state could not be read from '{cwd}', so the CODING_VELOCITY "
            "check did not run. Confirm the velocity row is in the commit.")

    _rc, status_out = common.git("-C", root, "status", "--porcelain", "--", VELOCITY)
    modified = any(line for line in status_out.splitlines())
    if velocity_in_commit(cmd, root, modified):
        return hooklib.allow()

    why = ("it is modified but this command does not stage it" if modified
           else "it has no change")
    return send_context(
        "[WARNING] Sprint 82 retro IMP-7: this commit closes a task "
        "('Closes #N' or 'Task N') but " + VELOCITY + " is not in it (" + why + "). "
        "CODING_VELOCITY.md Rule 4: record the actual minutes, and the card's "
        "Executed-by line, at task completion -- read the clock with Get-Date "
        "first (IMP-6). If this commit is only part of the task, ignore this.")


def decide(payload: dict) -> hooklib.Verdict:
    try:
        return check(payload)
    except Exception as exc:  # noqa: BLE001 - warn-only hook: say the check did not run (R-6)
        return send_context(
            "[WARNING] warn-commit-without-velocity.py failed: "
            f"{exc}. The CODING_VELOCITY check did not run.")


if __name__ == "__main__":
    hooklib.run("warn-commit-without-velocity", decide)
