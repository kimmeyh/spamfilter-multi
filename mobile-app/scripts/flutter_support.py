"""Shared helpers for the Flutter test runners in this folder (F334, Sprint 85).

Used by run-tests.py, run-integration-tests.py and monitor-tests.py. Standard library only (ADR-0051).
Runs on Windows, Linux and macOS.

Flutter on Windows is a batch shim (flutter.bat). find_flutter() uses shutil.which, which honors PATHEXT
and returns the .bat path. run_flutter() passes that path as a list with no shell: the Windows process
layer starts a .bat through cmd.exe, and no argument here needs shell quoting. The arguments are fixed
test paths and flags, so no value from a user reaches a shell.

The runners keep the FULL output of every flutter call in a log file and print only a trimmed part
(CLAUDE.md background-log rule). parse_counts() reads the final "+P ~S -F:" summary line, which the
expanded and compact reporters both print.
"""
from __future__ import annotations

import datetime
import re
import subprocess
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
MOBILE_APP = SCRIPTS.parent
REPO = MOBILE_APP.parent
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
import common  # noqa: E402  (find_tool, configure_stdio: the shared ADR-0051 layer)

# "00:03 +7 ~1 -2: All tests passed!" (expanded) or "+7 ~1 -2: Some tests failed." (compact).
# The skip and failure parts are optional; flutter prints them only when non-zero.
SUMMARY = re.compile(r"^(?:\d{2}:\d{2} )?\+(\d+)(?: ~(\d+))?(?: -(\d+))?: ", re.M)

NOT_FOUND = 127
"""Exit code used when flutter is not installed (the shell convention)."""


def find_flutter() -> str | None:
    """Path of the flutter command (flutter.bat on Windows), or None when it is not on PATH."""
    return common.find_tool("flutter")


def run_flutter(flutter: str, args: list[str], cwd: Path) -> tuple[int, str]:
    """Run flutter with args in cwd. Return (exit code, full output). Never raises for a failed test.

    stderr is merged into stdout so the log holds every line in the order it was printed. A launch
    failure returns NOT_FOUND with the reason as the text.
    """
    argv = [flutter, *args]
    try:
        done = subprocess.run(argv, cwd=str(cwd), stdin=subprocess.DEVNULL,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    except OSError as exc:  # missing file, not executable: report, do not crash the runner
        return NOT_FOUND, f"could not start {flutter}: {exc}\n"
    return done.returncode, done.stdout.decode("utf-8", errors="replace")


def parse_counts(text: str) -> tuple[int, int, int] | None:
    """(passed, skipped, failed) from the LAST summary line of a flutter run, or None when no line matches.

    None means the run printed no summary (for example, a compile error before any test started). The
    caller must not report that as zero passing tests.
    """
    last = None
    for match in SUMMARY.finditer(text):
        last = match
    if last is None:
        return None
    passed = int(last.group(1))
    skipped = int(last.group(2) or 0)
    failed = int(last.group(3) or 0)
    return passed, skipped, failed


def default_log_path(name: str) -> Path:
    """mobile-app/build/test-logs/<name>-<yyyymmdd-HHMMSS>.log (the build folder is gitignored)."""
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    return MOBILE_APP / "build" / "test-logs" / f"{name}-{stamp}.log"


def write_log(path: Path, text: str) -> None:
    """Write the full text as UTF-8, creating the folder. The log is the record; console output is a trim."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def tail(text: str, lines: int) -> str:
    """The last `lines` lines of text, for printing. The full text stays in the log file."""
    parts = text.splitlines()
    return "\n".join(parts[-lines:]) if lines > 0 else ""


__all__ = ["MOBILE_APP", "NOT_FOUND", "common", "default_log_path", "find_flutter", "parse_counts",
           "run_flutter", "tail", "write_log"]
