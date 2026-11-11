"""PreToolUse hook: block staging EVERYTHING unless the same command ran `git status` first.

Python port (F321 pilot, Sprint 83, ADR-0051) of block-blind-staging.ps1. Same interface:
exit 0 allow, exit 2 block (stderr to Claude), bypass token `allow_blind_staging`, same message.
Enforces the CLAUDE.md rule "Don't stage a commit without looking at what you are staging"
(Sprint 52 IMP-4; enforced from Sprint 76 retro IMP-4, after a `git add -A` ran before the status
check and swept a 0* working file into a version-bump commit with no mention).

  - ALLOWS staging named paths, any command that runs `git status` BEFORE its `git add -A`,
    `--all` or `.`, and any command carrying the bypass token.
  - BLOCKS `git add -A`, `--all`, `.` (also `./`, `:/`, `-u`, `--update`, combined flags such as
    `-fA`), and `git commit -a` / `-am` / `--all`, with no earlier `git status` in the command.
  - Text inside quotes is ignored, so a commit message that MENTIONS `git add -A` is not blocked;
    a command handed to a shell in quotes (`bash -c "..."`) is unwrapped and checked.
  - A `git status` whose output is thrown away (`> $null`, `> /dev/null`, `| Out-Null`) does not
    count as looking.
  - An internal error ALLOWS the command (hooklib.run), with a note on stderr.

Port notes (regex differences from PowerShell/.NET): -match is case-insensitive in PowerShell,
-cmatch is not, so each pattern below carries re.I only where the original was insensitive; Python
3.11+ rejects an inline (?i) that is not at the start of the pattern, so those became flags.
Tests: .claude/hooks/test-cases/staging-guard/ (run-test-cases.py) and
.claude/hooks/tests/test_pylib.py.
"""
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import common  # noqa: E402
import hooklib  # noqa: E402

BYPASS = re.compile(r"allow_blind_staging", re.I)

# A command handed to a shell in quotes: bash -c "...", powershell -Command '...'.
SHELL_WRAP = re.compile(
    r"""\b(?:bash|sh|pwsh|powershell)(?:\.exe)?\b[^"'\r\n;|&]*?\s-(?:c|Command)\s+(?:"([^"]*)"|'([^']*)')""",
    re.I)
QUOTED = re.compile(r"\"[^\"]*\"|'[^']*'")

# `git` (any case, optional .exe) plus global options, then the subcommand.
GIT_PREFIX = r"\bgit(?:\.exe)?(?:\s+(?:-[Cc]\s+\S+|--?[A-Za-z][\w-]*(?:=\S+)?))*\s+"
SEGMENT = r"([^;&|\r\n]*)"
ADD = re.compile(GIT_PREFIX + r"add\b" + SEGMENT, re.I)
COMMIT = re.compile(GIT_PREFIX + r"commit\b" + SEGMENT, re.I)
STATUS = re.compile(GIT_PREFIX + r"status\b" + SEGMENT, re.I)

ADD_ALL_SHORT = re.compile(r"^-[A-Za-z]*[Au][A-Za-z]*$")      # case-sensitive (-cmatch)
ADD_ALL_LONG = re.compile(r"^--(?:all|update)$", re.I)
WHOLE_TREE = re.compile(r"^(?:\.|\./|:/)$")
COMMIT_ALL_SHORT = re.compile(r"^-[A-Za-z]*a[A-Za-z]*$")      # case-sensitive (-cmatch)
COMMIT_ALL_LONG = re.compile(r"^--all$", re.I)
OUTPUT_DISCARDED = re.compile(r">\s*(?:\$null|/dev/null|nul)\b", re.I)
PIPED_TO_NULL = re.compile(r"^\s*\|\s*Out-Null\b", re.I)


def _unwrap(match: "re.Match[str]") -> str:
    return " " + (match.group(1) or "") + (match.group(2) or "") + " "


def find_stage_all(text: str):
    """The first `git add`/`git commit` match that stages everything, or None."""
    for m in ADD.finditer(text):
        for tok in re.split(r"\s+", m.group(1)):
            if ADD_ALL_SHORT.match(tok) or ADD_ALL_LONG.match(tok) or WHOLE_TREE.match(tok):
                return m
    for m in COMMIT.finditer(text):
        for tok in re.split(r"\s+", m.group(1)):
            if COMMIT_ALL_SHORT.match(tok) or COMMIT_ALL_LONG.match(tok):
                return m
    return None


def status_seen_before(code: str, add_start: int) -> bool:
    """True when a `git status` runs earlier in the command AND its output is not discarded."""
    for st in STATUS.finditer(code):
        if st.start() >= add_start:
            break
        rest = st.group(1)
        tail = code[st.end():]
        if OUTPUT_DISCARDED.search(rest) or PIPED_TO_NULL.search(tail):
            continue
        return True
    return False


def block_message(add_text: str) -> str:
    return (
        "[BLOCKED] Staging everything without looking first:\n"
        f"  {add_text}\n"
        "\n"
        "CLAUDE.md (Sprint 52 IMP-4; enforced from the Sprint 76 retro, IMP-4): run\n"
        "`git status --short` FIRST and account for every entry -- in Sprint 76 a\n"
        "`git add -A` before the status check swept Harold's 0* working file into a\n"
        "version-bump commit with no mention.\n"
        "\n"
        "Do this instead, in ONE command:\n"
        "  git status --short; git add -A; git commit ...\n"
        "or stage the paths you mean by name.\n"
        "\n"
        "If staging everything unseen is genuinely intended, re-run with the literal\n"
        "token allow_blind_staging in the command.")


def decide(payload: dict) -> hooklib.Verdict:
    tool = hooklib.tool_name(payload)
    if tool and tool.lower() not in ("bash", "powershell"):
        return hooklib.allow()
    cmd = hooklib.command_of(payload)
    if not cmd.strip() or BYPASS.search(common.strip_quoted(cmd)):
        return hooklib.allow()

    unwrapped = SHELL_WRAP.sub(_unwrap, cmd)
    code = QUOTED.sub('""', unwrapped)
    add = find_stage_all(code)
    if add is None:
        return hooklib.allow()
    if status_seen_before(code, add.start()):
        return hooklib.allow()
    return hooklib.block(block_message(add.group(0)))


if __name__ == "__main__":
    hooklib.run("block-blind-staging", decide)
