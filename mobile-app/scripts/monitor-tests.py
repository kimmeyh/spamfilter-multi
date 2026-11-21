#!/usr/bin/env python3
"""Run `flutter test` in mobile-app with live progress, slow-test detection and a full log (port of
monitor-tests.ps1, Sprint 9 Task D, F334 Sprint 85).

Usage:
    python mobile-app/scripts/monitor-tests.py                       # all tests; log test-monitor-<stamp>.txt
    python mobile-app/scripts/monitor-tests.py --output my-tests.txt --highlight-slow 10
    python mobile-app/scripts/monitor-tests.py test/unit/app_paths_test.dart   # targets after the options
    python mobile-app/scripts/monitor-tests.py --no-progress         # only errors and the summary

The flutter process runs in mobile-app (the original ran in the current folder, so it failed from the
repository root). Every line of flutter output goes to the log file as it is written. The console shows
progress lines (unless --no-progress), lines that look like errors, slow tests and the summary.

Durations: the expanded reporter prefixes each line with the elapsed time (mm:ss, one-second steps). A
test runs from its line to the next line, so durations come from flutter's clock, not from the poll loop
(the original measured the time between polls, and never timed the last test). Resolution is one second.

Exit codes:
    the flutter test exit code (0 when all tests passed)
    2  invalid arguments (argparse); 1 when flutter is not installed or mobile-app is missing
"""
from __future__ import annotations

import argparse
import datetime
import re
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import flutter_support as fs  # noqa: E402

# "00:05 +3 ~1 -2: group test name" (expanded reporter). The skip and failure parts are optional.
EVENT = re.compile(r"^(\d{2}):(\d{2}) \+(\d+)(?: ~(\d+))?(?: -(\d+))?: (.*)$")
ERROR_WORDS = re.compile(r"Error|Exception|Failed")
TERMINAL_NAMES = ("All tests passed!", "Some tests failed.")


class Event:
    """One expanded-reporter progress line: elapsed seconds, the text, and the counts on that line."""

    def __init__(self, elapsed: int, name: str, passed: int, skipped: int, failed: int) -> None:
        self.elapsed = elapsed
        self.name = name
        self.passed = passed
        self.skipped = skipped
        self.failed = failed

    @property
    def is_terminal(self) -> bool:
        return self.name.startswith(TERMINAL_NAMES)

    @property
    def is_load_step(self) -> bool:
        return self.name.startswith("loading ")


def parse_event(line: str) -> Event | None:
    """The Event for a progress line, or None for any other line (no progress prefix)."""
    match = EVENT.match(line.rstrip("\r\n"))
    if match is None:
        return None
    minutes, seconds = int(match.group(1)), int(match.group(2))
    return Event(minutes * 60 + seconds, match.group(6), int(match.group(3)),
                 int(match.group(4) or 0), int(match.group(5) or 0))


def durations(events: list[Event]) -> list[tuple[str, int]]:
    """(name, seconds) for every test that has a following event. A test ends where the next event starts.

    The load step ("loading ...") and the terminal summary are not tests. The last test is timed by the
    terminal event, which is why the original's missing last-test timing is fixed here.
    """
    result = []
    for prev, cur in zip(events, events[1:]):
        if prev.is_load_step or prev.is_terminal:
            continue
        result.append((prev.name, cur.elapsed - prev.elapsed))
    return result


def slow_tests(events: list[Event], threshold: int) -> list[tuple[str, int]]:
    """The tests whose duration is MORE than threshold seconds, slowest first."""
    slow = [(name, secs) for name, secs in durations(events) if secs > threshold]
    return sorted(slow, key=lambda item: item[1], reverse=True)


def final_counts(events: list[Event]) -> tuple[int, int, int]:
    """(passed, skipped, failed) from the last event, or zeros when no event was seen."""
    if not events:
        return 0, 0, 0
    last = events[-1]
    return last.passed, last.skipped, last.failed


def read_new_lines(path: Path, offset: int, pending: bytes) -> tuple[int, bytes, list[str]]:
    """Read bytes past offset; return (new offset, unfinished bytes, complete lines decoded as UTF-8)."""
    try:
        with open(path, "rb") as handle:
            handle.seek(offset)
            data = handle.read()
    except OSError:
        return offset, pending, []
    offset += len(data)
    buf = pending + data
    if b"\n" not in buf:
        return offset, buf, []
    complete, _, rest = buf.rpartition(b"\n")
    lines = [raw.rstrip(b"\r").decode("utf-8", errors="replace") for raw in complete.split(b"\n")]
    return offset, rest, lines


def parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run flutter test with live progress and a full log.")
    parser.add_argument("targets", nargs="*", help="test paths passed to flutter test (default: all)")
    parser.add_argument("--output", metavar="PATH", help="log file (default: test-monitor-<stamp>.txt here)")
    parser.add_argument("--highlight-slow", type=int, default=5, metavar="SECONDS",
                        help="report tests longer than this (default: 5)")
    parser.add_argument("--no-progress", action="store_true", help="do not print progress lines")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    fs.common.configure_stdio()
    args = parse_args(argv)
    mobile = fs.MOBILE_APP
    if not mobile.is_dir():
        print("Error: mobile-app directory not found", file=sys.stderr)
        return 1
    flutter = fs.find_flutter()
    if flutter is None:
        print("Error: flutter is not on PATH", file=sys.stderr)
        return 1

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    out_path = Path(args.output) if args.output else Path.cwd() / f"test-monitor-{stamp}.txt"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    print("========================================")
    print("Flutter Test Monitor")
    print("========================================")
    print(f"Output File: {out_path}")
    print(f"Highlight Slow: > {args.highlight_slow} seconds")
    print("========================================")
    print("")

    started = time.monotonic()
    argv_flutter = [flutter, "test", "--reporter", "expanded", *args.targets]
    with open(out_path, "wb") as sink:
        proc = subprocess.Popen(argv_flutter, cwd=str(mobile), stdin=subprocess.DEVNULL,
                                stdout=sink, stderr=subprocess.STDOUT)
    print(f"Test execution started (PID: {proc.pid})")
    print("Monitoring output...")
    print("")

    events: list[Event] = []
    offset, pending = 0, b""
    while True:
        done = proc.poll() is not None
        offset, pending, lines = read_new_lines(out_path, offset, pending)
        for line in lines:
            _handle_line(line, events, args)
        if done:
            break
        time.sleep(0.5)
    if pending:  # a last line without a newline
        _handle_line(pending.decode("utf-8", errors="replace"), events, args)
    exit_code = proc.wait()

    passed, skipped, failed = final_counts(events)
    total = passed + skipped + failed
    slow = slow_tests(events, args.highlight_slow)
    duration = time.monotonic() - started
    print("")
    print("========================================")
    print("Test Execution Complete")
    print("========================================")
    print(f"Duration: {round(duration, 2)} seconds")
    print(f"Total Tests: {total}")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
    print(f"Skipped: {skipped}")
    print(f"Exit Code: {exit_code}")
    print("")
    if slow:
        print(f"Slow Tests (> {args.highlight_slow} seconds):")
        for name, secs in slow:
            print(f"  - {name}: {secs}s")
        print("")
    print(f"Full output saved to: {out_path}")
    print("========================================")
    return exit_code


def _handle_line(line: str, events: list[Event], args: argparse.Namespace) -> None:
    """Show one line as it arrives: progress (unless --no-progress), errors, and slow tests as they end."""
    event = parse_event(line)
    if event is not None:
        if events and not events[-1].is_load_step and not events[-1].is_terminal:
            secs = event.elapsed - events[-1].elapsed
            if secs > args.highlight_slow:
                print(f"[SLOW] {events[-1].name} took {secs}s")
        events.append(event)
        if not args.no_progress:
            print(line)
    elif ERROR_WORDS.search(line):
        print(f"!! {line}")


if __name__ == "__main__":
    sys.exit(main())
