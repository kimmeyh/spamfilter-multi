"""PreToolUse hook: block Python run from a heredoc (or inline -c) whose text has a backslash.

Python port (F321 pilot, Sprint 83, ADR-0051) of block-heredoc-python-backslash.ps1. Same
interface: exit 0 allow, exit 2 block (stderr to Claude), bypass token `allow_heredoc_backslash`,
same message text. Enforces CLAUDE.md IMP-3 (Sprint 72):

  - BLOCKS `python|python3|py ... <<EOF ... EOF` whose body has a backslash (Bash tool);
  - BLOCKS `python -c "..."` / `py -3 -c '...'` whose program text has a backslash, in the Bash
    AND the PowerShell tool (Sprint 82 retro IMP-5); an escaped quote inside a double-quoted
    program (\\" in Bash, `" in PowerShell) is shell quoting, not program text;
  - BLOCKS any heredoc whose body has a DOUBLE backslash (Sprint 75 retro IMP-2 b);
  - BLOCKS a bare `cat > file` with no input, which waits on stdin until timeout (IMP-2 a);
  - ALLOWS everything else, including a heredoc with no backslash and `cat > f <<EOF`.

Port notes: every regex here was case-sensitive in the PowerShell original ([regex]::new), except
the `cat > file` segment test (-match, insensitive), which carries re.I. An internal error ALLOWS
the command (hooklib.run), with a note on stderr.
Tests: .claude/hooks/test-cases/heredoc-guard/ (run-test-cases.ps1) and
.claude/hooks/tests/test_pylib.py.
"""
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import hooklib  # noqa: E402

BYPASS = re.compile(r"allow_heredoc_backslash", re.I)

# python -c "..." and its flag variants (versioned name, -X/-W with a value, combined flags -Ic).
INLINE = re.compile(
    r"""(?:^|[\s;&|(/\\])(?:python(?:\d+(?:\.\d+)?)?|py)(?:\.exe)?(?:\s+(?:-[XW]\s+\S+|-[A-Za-z0-9]+))*?\s+-[A-Za-z]*c\s+([$@]?)(["'])""")

# Every heredoc opener line, and a Python interpreter token on that line (before or after <<).
OPENER = re.compile(r"""^[^\n]*?<<-?\s*(['"]?)([A-Za-z_][A-Za-z0-9_]*)\1[^\n]*$""", re.M)
PYTHON_TOKEN = re.compile(r"(?:^|[\s;&|(/\\])(?:python3?|py)(?:\.exe)?(?=\s|$|[;&|)])")
CAT_REDIRECT = re.compile(r"""^\s*cat\s*>{1,2}\s*("[^"]*"|'[^']*'|[^\s<|]+)(\s+2>(&1|\S+))?\s*$""", re.I)
SEGMENT_SPLIT = re.compile(r"(?:\r?\n|;|&&|\|\|)")

INLINE_MESSAGE = """[BLOCKED] Python run inline (-c) with a backslash in the program text.

CLAUDE.md IMP-3 (Sprint 72; inline form enforced from the Sprint 82 retro,
IMP-5): Python reads the backslashes as escapes (and in double quotes the
shell reads them first), so the program that runs is not the one written --
an anchor with \\n or \\\\ silently stops matching.

Do this instead:
  1. Write the script to a FILE in the scratchpad with the Write tool.
  2. Run it by path:  python -I "<scratchpad>/script.py"
  3. The script asserts its anchors matched before writing.

If the backslash is genuinely safe here, re-run with the literal token
allow_heredoc_backslash in the command."""

CAT_MESSAGE = """[BLOCKED] `cat` with an output redirect and NO input waits on stdin forever:
  {seg}

Sprint 75 retro IMP-2: this hung a command until timeout twice. Write the file
with the Write tool, or give cat its input (a heredoc, < file, or a pipe)."""

DOUBLE_MESSAGE = """[BLOCKED] A heredoc body contains a DOUBLE backslash (\\\\).

Sprint 75 retro IMP-2: a JSON spec written through a heredoc lost every \\\\
(it became \\) and the file no longer parsed. Write the file with the Write
tool instead. If the backslashes are genuinely safe, re-run with the literal
token allow_heredoc_backslash in the command."""

HEREDOC_MESSAGE = """[BLOCKED] Python run from a heredoc whose body contains a backslash.

CLAUDE.md IMP-3 (Sprint 72; enforced from the Sprint 74 retro, IMP-6):
backslashes in a heredoc'd Python program pass through the shell AND Python
and come out changed -- a '\\n' meant for a Dart string became a real line
break (Sprint 74), and an edit printed "inserted" while changing nothing
(Sprint 72).

Do this instead:
  1. Write the script to a FILE in the scratchpad with the Write tool.
  2. Run it by path:  python "<scratchpad>/script.py"
  3. The script asserts its anchors matched before writing.

If the backslash is genuinely safe here, re-run with the literal token
allow_heredoc_backslash in the command."""


def _closing(delim: str, text: str):
    """The line that closes a heredoc opened with `delim`, searched in `text`, or None."""
    return re.search(r"^\s*" + re.escape(delim) + r"\s*$", text, re.M)


def inline_program_has_backslash(cmd: str, tool: str) -> bool:
    esc = "`" if tool.lower() == "powershell" else "\\"
    for m in INLINE.finditer(cmd):
        quote = m.group(2)
        start = m.end()
        i = start
        if m.group(1) == "@":
            # PowerShell here-string: it ends at the quote followed by @.
            i = cmd.find(quote + "@", start)
            if i < 0:
                i = len(cmd)
        while i < len(cmd):
            if cmd[i] == quote and not (quote == '"' and i > start and cmd[i - 1] == esc):
                break
            i += 1
        program = cmd[start:i]
        if quote == '"':
            program = program.replace(esc + '"', "")
        if "\\" in program:
            return True
    return False


def cat_without_input(cmd: str):
    """The first `cat > file` command segment with no input, or None. Heredoc BODIES are text,
    not commands (PR #448 review), so they are removed before the segments are split."""
    scan = []
    pos = 0
    for m in OPENER.finditer(cmd):
        if m.start() < pos:
            continue
        body_start = m.end()
        scan.append(cmd[pos:body_start])
        end = _closing(m.group(2), cmd[body_start:])
        pos = body_start + end.start() if end else len(cmd)
    scan.append(cmd[pos:])
    for seg in SEGMENT_SPLIT.split("".join(scan)):
        if CAT_REDIRECT.match(seg):
            return seg
    return None


def decide(payload: dict) -> hooklib.Verdict:
    tool = hooklib.tool_name(payload)
    if tool and tool.lower() not in ("bash", "powershell"):
        return hooklib.allow()
    cmd = hooklib.command_of(payload)
    if not cmd.strip() or BYPASS.search(cmd):
        return hooklib.allow()

    if inline_program_has_backslash(cmd, tool):
        return hooklib.block(INLINE_MESSAGE)

    # The heredoc and bare-cat checks below are Bash shapes only.
    if tool.lower() == "powershell":
        return hooklib.allow()

    seg = cat_without_input(cmd)
    if seg is not None:
        return hooklib.block(CAT_MESSAGE.format(seg=seg.strip()))

    for m in OPENER.finditer(cmd):
        rest = cmd[m.end():]
        close = _closing(m.group(2), rest)
        body = rest[:close.start()] if close else rest
        if not PYTHON_TOKEN.search(m.group(0)):
            # ANY heredoc: a DOUBLE backslash in the body comes out as one. Single backslashes
            # (a Windows path in a commit message) stay allowed.
            if "\\\\" in body:
                return hooklib.block(DOUBLE_MESSAGE)
            continue
        if "\\" in body:
            return hooklib.block(HEREDOC_MESSAGE)
    return hooklib.allow()


if __name__ == "__main__":
    hooklib.run("block-heredoc-python-backslash", decide)
