"""OS-agnostic helpers shared by the repo's Python hooks and scripts (F321, Sprint 83).

ADR-0051 records why this layer exists and what it deliberately leaves out. It holds ONLY
what the pilot hooks and scripts needed, measured by grepping the PowerShell they replace:

    stdio encoding     UTF-8 in and out on every OS (Windows defaults to the console code page)
    project root       CLAUDE_PROJECT_DIR, else walk up from a start folder
    path normalizing   one spelling for comparisons (Windows backslash versus POSIX slash)
    git calls          subprocess, never raising
    gh calls           subprocess, never raising (F327, Sprint 84: the first hook that needs GitHub)
    UTC time           parsing the ISO 8601 text the lock files hold, and the current time
    tool lookup        the first of several command names that is installed

Standard library only. Add a helper here only when a second converted file needs it.
"""
from __future__ import annotations

import os
import re
import sys
from typing import TYPE_CHECKING

if TYPE_CHECKING:  # heavy modules are imported inside the functions that use them: a hook starts on every tool call
    from datetime import datetime
    from pathlib import Path

# Exit codes the Claude Code hook contract defines: 0 = allow, 2 = block (stderr goes to Claude).
ALLOW = 0
BLOCK = 2


def configure_stdio() -> None:
    """Make stdout and stderr UTF-8 and never raise on an unencodable character.

    Windows Python defaults to the console code page (cp1252). A block message that quotes a
    command with a non-ASCII character (a curly quote in a commit message) would then raise
    UnicodeEncodeError, Python would exit 1, and Claude Code treats exit 1 as non-blocking, so
    the block would be lost. errors='replace' keeps the message and the exit code.
    """
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:  # noqa: BLE001 - a stream without reconfigure is left as is
            pass


def read_stdin_text() -> str:
    """Read all of stdin as UTF-8 text. Reads BYTES so the console code page never applies.

    Undecodable bytes become U+FFFD rather than raising, so one odd character cannot make a
    hook fail open on a payload that holds a real violation. A leading BOM is removed.
    """
    try:
        data = sys.stdin.buffer.read()
    except Exception:  # noqa: BLE001
        return ""
    return data.decode("utf-8", errors="replace").lstrip("\ufeff")


_QUOTED_SPAN = re.compile(r"\"[^\"]*\"|'[^']*'")


def strip_quoted(text: str) -> str:
    """The command with every "..." and '...' span emptied. Sprint 83 7.7.1 (silent-failure-hunter
    L-7): every hook looks for its bypass token in THIS text, so a token that only appears inside
    a quoted commit message or string never disarms a guard (block-commit-during-mutation already
    worked this way; block-blind-staging and block-heredoc-python-backslash did not)."""
    return _QUOTED_SPAN.sub('""', text)


# Sprint 84 7.7.1 (finding 8): `git -C <dir> stash` and `git -c k=v commit` name the subcommand AFTER
# global options, so `git\s+stash` missed them. Options tolerated between `git` and the subcommand:
# `-C <dir>`, `-c <k=v>` (the argument may have been emptied by quote stripping, so it is optional),
# and flags such as `--no-pager` or `--git-dir=x`. A word that is not an option ends the run, so
# `git log --grep stash` does NOT read as a stash call.
_GIT_GLOBAL_OPTIONS = r"(?:\s+(?:-[Cc](?:\s+\S+)?|--?[A-Za-z][\w-]*(?:=\S+)?))*"


def git_subcommand_regex(subcommand: str, *, trailing: str = r"\b") -> re.Pattern:
    """Compiled, case-insensitive pattern for `git [global options] <subcommand>`; `trailing` follows it."""
    return re.compile(r"\bgit" + _GIT_GLOBAL_OPTIONS + r"\s+" + subcommand + trailing, re.IGNORECASE)


def normalize_path(text: str) -> str:
    """One spelling for comparisons: forward slashes. Windows hands back backslashes."""
    return text.replace("\\", "/")


def find_project_root(start: str | os.PathLike | None = None) -> Path:
    """The project root on any OS.

    Order: CLAUDE_PROJECT_DIR when set and present; else walk up from `start` (default: the
    process working folder) to the first folder holding `.git` (a folder, or a file in a
    worktree) or a `.claude` folder; else `start` itself. This is the lookup order
    the PowerShell mutation-lock (retired in F329) used (environment first, then walk up from the working folder).
    """
    from pathlib import Path

    env = os.environ.get("CLAUDE_PROJECT_DIR")
    if env and Path(env).exists():
        return Path(env)
    here = Path(start) if start else Path.cwd()
    try:
        here = here.resolve()
    except OSError:
        pass
    for candidate in (here, *here.parents):
        if (candidate / ".git").exists() or (candidate / ".claude").is_dir():
            return candidate
    return here


TIMEOUT = 124
"""Exit code git() and gh() return when a call ran past its own time limit."""


def _kill_tree(proc) -> None:
    """Kill a process and every process it started. Never raises."""
    import subprocess

    try:
        if os.name == "nt":
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True,
                           timeout=3, check=False)
        proc.kill()
    except Exception:  # noqa: BLE001
        pass


def _run(argv: list, cwd, timeout: int) -> tuple[int, str]:
    """Run a program and return (exit code, stdout); (TIMEOUT, "") when it runs past `timeout`.

    On a timeout the WHOLE process tree is killed. subprocess.run kills only the direct child and
    then waits with no limit, so a grandchild that holds the output pipe kept the caller waiting:
    a 2 second timeout took 11 seconds through the Git for Windows launcher, which starts the real
    git as a child (Sprint 84 improvement review H-1). Raises FileNotFoundError when the program is
    not installed; the callers map it."""
    import subprocess

    proc = subprocess.Popen(argv, cwd=str(cwd) if cwd else None, stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, encoding="utf-8", errors="replace")
    try:
        out, _err = proc.communicate(timeout=timeout)
        return proc.returncode, out
    except subprocess.TimeoutExpired:
        _kill_tree(proc)
        try:
            proc.communicate(timeout=1)
        except Exception:  # noqa: BLE001 - the pipes may stay open if the kill failed; do not wait again
            pass
        return TIMEOUT, ""


def git(*args: str, cwd: str | os.PathLike | None = None, timeout: int = 15) -> tuple[int, str]:
    """Run git and return (exit code, stdout). Never raises: a hook that crashes because git is
    missing or slow is worse than one that declines to check. TIMEOUT (124) when the call ran past
    `timeout` (the process tree is killed); 1 for any launch failure."""
    try:
        return _run(["git", *args], cwd, timeout)
    except Exception:  # noqa: BLE001
        return 1, ""


def gh(*args: str, cwd: str | os.PathLike | None = None, timeout: int = 8) -> tuple[int, str]:
    """Run the GitHub CLI and return (exit code, stdout). Never raises, same shape as git().

    A missing gh, a network failure, a timeout and a non-zero exit all return a non-zero code, so
    the caller can fail OPEN: a close-out check that needs GitHub declines to check when GitHub is
    unreachable (F327; verify-closeout-complete.ps1 swallowed the same cases with `catch { }`).
    The default timeout is 8 seconds per call; on a timeout the process tree is killed (see _run). A
    hook that makes several calls keeps its own total budget: the close-out hook shares one 15 second
    budget across its git and gh calls and has a watchdog that ends it at 17 seconds (Sprint 84 retro q4).

    Sprint 84 5.1.2 F6-1: the failure code tells the caller WHY, so it can print a notice that the
    check did not run: GH_NOT_FOUND (127) when gh is not installed, GH_TIMEOUT (124) when it timed
    out, 1 for any other launch failure; gh's own non-zero exit code passes through unchanged.
    """
    try:
        return _run(["gh", *args], cwd, timeout)
    except FileNotFoundError:
        return GH_NOT_FOUND, ""
    except Exception:  # noqa: BLE001
        return 1, ""


GH_NOT_FOUND = 127
GH_TIMEOUT = TIMEOUT


def gh_failure_reason(code: int) -> str:
    """Words for a non-zero gh() code, for a 'check did not run' notice."""
    if code == GH_NOT_FOUND:
        return "gh is not installed"
    if code == GH_TIMEOUT:
        return "gh timed out"
    return f"gh exit code {code}"


def find_tool(*names: str) -> str | None:
    """The path of the first command in `names` found on PATH, else None."""
    import shutil

    for name in names:
        found = shutil.which(name)
        if found:
            return found
    return None


def utc_now() -> datetime:
    from datetime import datetime, timezone

    return datetime.now(timezone.utc)


_ISO = re.compile(
    r"^\s*(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:[.,](\d+))?)?\s*"
    r"(Z|[+-]\d{2}(?::?\d{2})?)?\s*$", re.IGNORECASE)


def parse_utc(text: object) -> datetime:
    """Parse ISO 8601 text to an aware UTC datetime. Raises ValueError when it is not one.

    Accepts the PowerShell 'o' form the old lock files hold (seven fraction digits, trailing Z),
    an explicit offset (+02:00), and text with no offset (taken as UTC, the behavior of the
    DateTimeOffset.Parse call this replaces). Python 3.9 and 3.10 fromisoformat reject several
    of these forms, so this parser does not depend on the interpreter version.
    """
    from datetime import datetime, timedelta, timezone

    m = _ISO.match(str(text))
    if not m:
        raise ValueError(f"not an ISO 8601 timestamp: {text!r}")
    year, month, day, hour, minute = (int(m.group(i)) for i in range(1, 6))
    second = int(m.group(6) or 0)
    micro = int((m.group(7) or "0")[:6].ljust(6, "0"))
    moment = datetime(year, month, day, hour, minute, second, micro, tzinfo=timezone.utc)
    zone = m.group(8)
    if zone and zone.upper() != "Z":
        sign = 1 if zone[0] == "+" else -1
        digits = zone[1:].replace(":", "")
        offset = timedelta(hours=int(digits[:2]), minutes=int(digits[2:4] or 0))
        moment = moment - sign * offset
    return moment


def format_utc(moment: datetime) -> str:
    """ISO 8601 UTC with seven fraction digits and a trailing Z, byte-compatible with the
    PowerShell ToString('o') text the old lock files carried."""
    from datetime import timezone

    moment = moment.astimezone(timezone.utc)
    return moment.strftime("%Y-%m-%dT%H:%M:%S.%f") + "0Z"
