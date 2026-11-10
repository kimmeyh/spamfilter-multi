"""Summarize background-scan health from the app's diagnostic logs (diag_*.log).

Python port of the former scripts/phone-log-health.ps1 (F332, Sprint 85; ADR-0051). Runs on
Windows, Linux and macOS with the standard library only. Read-only: it reads files and prints.

For each account it prints:
  - background starts, and outcomes (completed / error / refused / other)
  - starts that never reached an outcome (unfinished)
  - "skip" lines, and the worker triggers seen (doze-alarm, periodic, test, ...)
  - completed scans per hour and the median gap between starts
and a FLAG line for each problem:
  - more scans per hour than the interval allows (x1.5): double scheduling
  - unfinished scans, errors
  - with --single-account: more than one account scanning in the background

Usage:
  python scripts/phone-log-health.py --path <diag_*.log> [more logs or globs]
  python scripts/phone-log-health.py --path <diag_*.log> --since "2026-10-13 01:00" --single-account
  python scripts/phone-log-health.py --self-test

Options:
  --path PATH [PATH ...]   one or more diag_*.log files; globs and comma-separated lists are accepted
  --interval-minutes N     FALLBACK background interval (default 15). Each account's own interval is read
                           from its worker skip lines ("(interval 240m; doze alarm)") when the log has one,
                           and that wins.
  --since TIME             only lines at or after this time (YYYY-MM-DD HH:MM[:SS])
  --single-account         flag when more than one account scanned in the background
  --self-test              run built-in sample logs and assert the flags

Exit codes:
  0  report printed (flags or "No flags.")
  1  --self-test failed
  2  usage error (no --path and no --self-test, or a bad --since)
  3  the logs have lines but no background scan line was recognized: the log format changed, or no
     background scan ran. Health NOT checked. (Also used for logs with no lines at all.)
  4  no diagnostic log file matched --path. Health NOT checked.
"""
from __future__ import annotations

import argparse
import glob
import os
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
import common  # noqa: E402

# Patterns. Python re is case-sensitive by default, like [regex]::Match in the PowerShell original.
# ADR-0051 rule 4: the PowerShell -match was case-insensitive; these are not, and the tags are upper case.
SCAN_RX = re.compile(
    r"^\[(?P<ts>[0-9T:.\-]+)\] \[SCAN\] \[scan/background\] (?P<acct>\S+) (?P<ev>start|outcome|skip) --\s*(?P<rest>.*)$"
)
TRIGGER_RX = re.compile(
    r"^\[(?P<ts>[0-9T:.\-]+)\] \[SCAN\] \[worker/android\] start (?P<acct>\S+) trigger=(?P<trig>[a-z-]+)"
)
INTERVAL_RX = re.compile(r"\[worker/android\] account (?P<acct>\S+) skipped: .*\(interval (?P<min>\d+)m")

NO_PATH_MESSAGE = "Give --path <diag_*.log> or --self-test."


def ps_num(value: float | int) -> str:
    """Render a number the way the PowerShell report did: 6 not 6.0, 14.9 not 14.90000001."""
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return format(value, ".15g")


def parse_ts(text: str) -> datetime | None:
    """The log timestamp, or None when it does not parse. (The PowerShell threw here.)"""
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        return None


class _Account:
    def __init__(self, last: datetime) -> None:
        self.starts: list[datetime] = []
        self.outcomes: dict[str, int] = {}
        self.skips = 0
        self.triggers: dict[str, int] = {}
        self.unfinished = 0
        self.unfinished_at: list[datetime] = []
        # Open is a STACK of start times. Two isolates can scan one account at once; the second is
        # refused at its claim and ends FIRST, so the scans nest and an outcome closes the NEWEST open
        # start. A start that never finishes stays at the bottom with its own timestamp.
        self.open: list[datetime] = []
        self.last = last


class Health:
    def __init__(self, lines: list[str], flags: list[str], accounts: int, recognized: int) -> None:
        self.lines = lines
        self.flags = flags
        self.accounts = accounts
        self.recognized = recognized


def get_health(lines: list[str], interval: int, since: datetime | None = None,
               one_account: bool = False) -> Health:
    acc: dict[str, _Account] = {}
    intervals: dict[str, set[int]] = {}
    recognized = 0
    for line in lines:
        iv = INTERVAL_RX.search(line)
        if iv:
            intervals.setdefault(iv.group("acct"), set()).add(int(iv.group("min")))
        m = SCAN_RX.match(line)
        t = TRIGGER_RX.match(line)
        if not m and not t:
            continue
        hit = m if m else t
        ts = parse_ts(hit.group("ts"))
        if ts is None:
            continue  # not a recognized line: the M-1 check reports the log when nothing else matches
        if since and ts < since:
            continue
        # Counted only inside the window: a window with no scan line must not read as "No flags.".
        recognized += 1
        a = hit.group("acct")
        if a not in acc:
            acc[a] = _Account(ts)
        r = acc[a]
        if ts > r.last:
            r.last = ts
        if t:
            k = t.group("trig")
            r.triggers[k] = r.triggers.get(k, 0) + 1
            continue
        ev = m.group("ev")
        if ev == "start":
            r.starts.append(ts)
            r.open.append(ts)
        elif ev == "outcome":
            kind = re.split(r"\s+", m.group("rest"))[0]
            r.outcomes[kind] = r.outcomes.get(kind, 0) + 1
            if r.open:
                r.open.pop()
        elif ev == "skip":
            r.skips += 1

    log_end = max((r.last for r in acc.values()), default=None)
    out: list[str] = []
    flags: list[str] = []
    scanning = 0
    for a in sorted(acc, key=lambda s: (s.lower(), s)):
        r = acc[a]
        # A start still unpaired more than 30 minutes before the log ends never finished.
        for o in r.open:
            if (log_end - o).total_seconds() / 60 > 30:
                r.unfinished += 1
                r.unfinished_at.append(o)
        n = len(r.starts)
        if n > 0:
            scanning += 1
        completed = r.outcomes.get("completed", 0)
        errors = r.outcomes.get("error", 0)
        hours = 0.0
        median = None
        if n >= 2:
            hours = (r.starts[n - 1] - r.starts[0]).total_seconds() / 3600
            gaps = sorted((r.starts[i] - r.starts[i - 1]).total_seconds() / 60 for i in range(1, n))
            median = gaps[len(gaps) // 2]
        # N scans across a span hold N-1 intervals: two scans 240 minutes apart are 0.25/hour, not 0.5.
        per_hour = round((completed - 1) / hours, 2) if hours >= 1 and completed >= 2 else None
        out_text = " ".join(f"{k}={r.outcomes[k]}" for k in sorted(r.outcomes))
        trig_text = " ".join(f"{k}={r.triggers[k]}" for k in sorted(r.triggers))
        # The account's own interval (from its skip lines) wins over the fallback. When it changed inside
        # the window, the SHORTEST one is used: the rate check must not flag a window that was faster for
        # part of its length.
        own = a in intervals
        iv_val = min(intervals[a]) if own else interval
        if not own:
            iv_text = f"interval {iv_val}m (assumed)"
        elif len(intervals[a]) > 1:
            joined = "/".join(str(x) for x in sorted(intervals[a]))
            iv_text = f"interval {joined}m (log, changed; checked at {iv_val}m)"
        else:
            iv_text = f"interval {iv_val}m (log)"
        per_hour_text = ps_num(per_hour) if per_hour is not None else "-"
        median_text = ps_num(round(median, 1)) if median is not None else "-"
        out.append(
            f"{a}: starts={n} {out_text} unfinished={r.unfinished} skips={r.skips} | "
            f"triggers {trig_text or 'none'} | {per_hour_text}/hour, median gap {median_text} min | {iv_text}"
        )
        allowed = 1.5 * 60 / iv_val
        if per_hour is not None and per_hour > allowed:
            flags.append(
                f"FLAG: {a} completed {ps_num(per_hour)} scans/hour; a {iv_val}-minute interval allows about "
                f"{ps_num(round(60 / iv_val, 1))}. Double scheduling? (MV-7 class)"
            )
        if r.unfinished > 0:
            at = ", ".join(x.strftime("%m-%d %H:%M:%S") for x in sorted(r.unfinished_at)[:3])
            flags.append(f"FLAG: {a} has {r.unfinished} scan(s) that started and never reached an outcome "
                         f"(first: {at}).")
        if errors > 0:
            flags.append(f"FLAG: {a} has {errors} scan error(s).")
    if one_account and scanning > 1:
        flags.append(f"FLAG: {scanning} accounts scanned in the background; a single-account run needs exactly one.")
    return Health(out, flags, scanning, recognized)


# ---------------------------------------------------------------- self test

def run_self_test() -> tuple[int, list[str]]:
    """The built-in checks (the 14 of the PowerShell -SelfTest). Returns (checks run, failures)."""
    base = datetime(2026, 10, 13, 1, 0, 0)
    failures: list[str] = []
    checks = 0

    def add_scan(bucket: list[str], when: datetime, acct: str, trigger: str, outcome: str | None) -> None:
        ts = when.strftime("%Y-%m-%dT%H:%M:%S.%f")
        bucket.append(f"[{ts}] [SCAN] [worker/android] start {acct} trigger={trigger}")
        bucket.append(f"[{ts}] [SCAN] [scan/background] {acct} start -- platform=aol folders=3 daysBack=1")
        if outcome:
            bucket.append(f"[{ts}] [SCAN] [scan/background] {acct} outcome -- {outcome} found=1")

    def check(ok: bool, message: str) -> None:
        nonlocal checks
        checks += 1
        if not ok:
            failures.append(message)

    sample: list[str] = []
    # d@x: scanned by BOTH triggers, about every 7.5 minutes for 3 hours.
    for i in range(24):
        add_scan(sample, base + timedelta(minutes=i * 7.5), "d***@x.com",
                 "periodic" if i % 2 else "doze-alarm", "completed")
    # c@x: every 15 minutes, one error.
    for i in range(12):
        add_scan(sample, base + timedelta(minutes=i * 15 + 1), "c***@x.com", "periodic",
                 "error IEa: test" if i == 3 else "completed")
    # Unfinished: one start with no outcome, two hours before the log ends.
    add_scan(sample, base + timedelta(minutes=30), "u***@x.com", "periodic", None)
    add_scan(sample, base + timedelta(minutes=45), "u***@x.com", "periodic", "completed")
    lines = sorted(sample)

    h = get_health(lines, 15)
    f = "\n".join(h.flags)
    check(re.search(r"d\*\*\*@x\.com completed [0-9.]+ scans/hour", f) is not None, "double scheduling not flagged")
    check(re.search(r"c\*\*\*@x\.com completed", f) is None, "clean 15-minute account flagged as double")
    check(re.search(r"c\*\*\*@x\.com has 1 scan error", f) is not None, "error not flagged")
    check(re.search(r"u\*\*\*@x\.com has 1 scan\(s\) that started and never", f) is not None,
          "unfinished scan not flagged")
    check("accounts scanned in the background" not in f, "single-account flag raised without one-account mode")
    h1 = get_health(lines, 15, one_account=True)
    check("3 accounts scanned in the background" in "\n".join(h1.flags), "multi-account run not flagged")
    clean = [ln.replace("error IEa: test", "completed") for ln in lines if re.search(r"c\*\*\*@x\.com", ln)]
    h2 = get_health(clean, 15, one_account=True)
    check(len(h2.flags) == 0, f"clean single-account log raised {len(h2.flags)} flag(s): {'; '.join(h2.flags)}")
    # Two scans of one account overlap: the second is refused, then the first completes.
    o = [
        "[2026-10-13T02:00:00.000000] [SCAN] [scan/background] o***@x.com start -- a",
        "[2026-10-13T02:00:01.000000] [SCAN] [scan/background] o***@x.com start -- b",
        "[2026-10-13T02:00:02.000000] [SCAN] [scan/background] o***@x.com outcome -- refused",
        "[2026-10-13T02:00:09.000000] [SCAN] [scan/background] o***@x.com outcome -- completed found=1",
        "[2026-10-13T03:00:00.000000] [SCAN] [scan/background] o***@x.com start -- c",
        "[2026-10-13T03:00:05.000000] [SCAN] [scan/background] o***@x.com outcome -- completed found=0",
    ]
    h3 = get_health(o, 15)
    check("never reached" not in "\n".join(h3.flags), "overlapping refused scan counted as unfinished")
    h4 = get_health(["garbage line",
                     "[2026-10-13T02:00:00.000000] [SCAN] [scan/renamed] x start -- a"], 15)
    check(h4.recognized == 0, f"unparseable lines counted as recognized ({h4.recognized})")
    check(h.recognized >= 1, "sample scan lines not counted as recognized")
    # Per-account interval from skip lines (Sprint 79). f@x runs every 6 minutes and its log says 5m: healthy,
    # even with a 15-minute fallback. y@x runs every 7.5 minutes and its log says 15m: double, even with a
    # 5-minute fallback.
    pa: list[str] = []
    for i in range(30):
        add_scan(pa, base + timedelta(minutes=i * 6), "f***@x.com", "doze-alarm", "completed")
    for i in range(24):
        add_scan(pa, base + timedelta(minutes=i * 7.5), "y***@x.com", "periodic", "completed")
    pa.append("[2026-10-13T01:01:00.000000] [SCAN] [worker/android] account f***@x.com skipped: "
              "a scan started 60s ago (interval 5m; doze alarm)")
    pa.append("[2026-10-13T01:02:00.000000] [SCAN] [worker/android] account y***@x.com skipped: "
              "a scan started 120s ago (interval 15m; doze alarm)")
    pl = sorted(pa)
    f5 = "\n".join(get_health(pl, 15).flags)
    check(re.search(r"f\*\*\*@x\.com completed", f5) is None, "account logged at 5m flagged against the 15m fallback")
    f6 = "\n".join(get_health(pl, 5).flags)
    check(re.search(r"y\*\*\*@x\.com completed [0-9.]+ scans/hour; a 15-minute", f6) is not None,
          "account logged at 15m not flagged under a 5m fallback")
    # g@x: exactly two scans, one 240-minute interval apart, its log says 240m.
    g: list[str] = []
    add_scan(g, base, "g***@x.com", "periodic", "completed")
    add_scan(g, base + timedelta(minutes=240), "g***@x.com", "periodic", "completed")
    g.append("[2026-10-13T01:15:00.000000] [SCAN] [worker/android] account g***@x.com skipped: "
             "a scan started 900s ago (interval 240m; doze alarm)")
    f7 = "\n".join(get_health(sorted(g), 15).flags)
    check(re.search(r"g\*\*\*@x\.com completed", f7) is None, "two scans one 240m interval apart flagged as double")
    # h@x: every 5 minutes for 2 hours (log says 5m), then the interval became 240m. One window: no flag.
    hh: list[str] = []
    for i in range(24):
        add_scan(hh, base + timedelta(minutes=i * 5), "h***@x.com", "doze-alarm", "completed")
    add_scan(hh, base + timedelta(minutes=360), "h***@x.com", "periodic", "completed")
    hh.append("[2026-10-13T01:01:00.000000] [SCAN] [worker/android] account h***@x.com skipped: "
              "a scan started 60s ago (interval 5m; doze alarm)")
    hh.append("[2026-10-13T07:15:00.000000] [SCAN] [worker/android] account h***@x.com skipped: "
              "a scan started 900s ago (interval 240m; doze alarm)")
    f8 = "\n".join(get_health(sorted(hh), 15).flags)
    check(re.search(r"h\*\*\*@x\.com completed", f8) is None,
          "interval changed 5m -> 240m inside the window flagged as double")
    return checks, failures


# ---------------------------------------------------------------- command line

def read_log_lines(path: Path) -> list[str]:
    """The file's lines. UTF-8 explicitly (Windows PowerShell 5.1 read these as ANSI, F332 defect);
    CR is removed the way Get-Content removed it."""
    data = path.read_bytes().decode("utf-8", errors="replace")
    pieces = data.split("\n")
    if pieces and pieces[-1] == "":
        pieces.pop()  # the newline that ends the last line is not a line of its own
    return [ln[:-1] if ln.endswith("\r") else ln for ln in pieces]


def expand_paths(paths: list[str]) -> tuple[list[Path], list[str]]:
    """Each --path entry, comma-split and globbed. Returns (files unique by name, warnings)."""
    warnings: list[str] = []
    found: list[Path] = []
    for raw in paths:
        for item in (p for p in raw.split(",") if p):
            if os.path.isfile(item):
                hits = [Path(item)]
            else:
                hits = [Path(p) for p in sorted(glob.glob(item)) if os.path.isfile(p)]
            if not hits:
                warnings.append(f"WARNING: --path '{item}' matched no file; it is NOT in this check.")
            found.extend(hits)
    found.sort(key=lambda p: p.name.lower())
    unique: list[Path] = []
    seen: set[str] = set()
    for p in found:
        if p.name.lower() not in seen:
            seen.add(p.name.lower())
            unique.append(p)
    return unique, warnings


def parse_since(text: str) -> datetime:
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M"):
        try:
            return datetime.strptime(text, fmt)
        except ValueError:
            continue
    raise argparse.ArgumentTypeError(f"not a time: {text!r} (use YYYY-MM-DD HH:MM)")


def main(argv: list[str] | None = None) -> int:
    common.configure_stdio()
    parser = argparse.ArgumentParser(description="Summarize background-scan health from diag_*.log files.")
    parser.add_argument("--path", nargs="+", default=None, metavar="PATH")
    parser.add_argument("--interval-minutes", type=int, default=15)
    parser.add_argument("--since", type=parse_since, default=None)
    parser.add_argument("--single-account", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)

    if args.self_test:
        checks, failures = run_self_test()
        if not failures:
            print(f"SELFTEST PASS ({checks} checks)")
            return 0
        print("SELFTEST FAIL:")
        for item in failures:
            print(f"  - {item}")
        return 1

    if not args.path:
        print(NO_PATH_MESSAGE)
        return 2

    files, warnings = expand_paths(args.path)
    for w in warnings:
        print(w)
    if not files:
        print("No diagnostic logs found. Health NOT checked.")
        return 4

    lines: list[str] = []
    for fi in files:
        lines.extend(read_log_lines(fi))
    res = get_health(lines, args.interval_minutes, args.since, args.single_account)
    since_text = f", since {args.since:%Y-%m-%d %H:%M:%S}" if args.since else ""
    print(f"--- background scan health ({len(files)} log(s), interval {args.interval_minutes} min{since_text}) ---")
    for ln in res.lines:
        print(ln)
    # 7.7.1 silent-failure M-1: unparseable input must never read as healthy. If the logs have lines but
    # none is a scan line, the format changed (a renamed tag) or no background scan ran. An empty log
    # gives the same answer: no evidence of health.
    if res.recognized == 0:
        print(f"WARNING: 0 scan lines recognized in {len(files)} log(s) -- log format changed, or no "
              f"background scan ran. Health NOT checked.")
        return 3
    if not res.flags:
        print("No flags.")
    else:
        for ln in res.flags:
            print(ln)
    return 0


if __name__ == "__main__":
    sys.exit(main())
