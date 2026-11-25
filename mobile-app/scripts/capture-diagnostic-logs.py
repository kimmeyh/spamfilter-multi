"""Capture adb logcat from the EMULATOR while you run a scan, then summarize the rule diagnostics (F336, Sprint 86; Python
port of capture-diagnostic-logs.ps1).

Usage:
  python capture-diagnostic-logs.py --action start                 clear logcat and start capturing in the background
  python capture-diagnostic-logs.py --action stop                  stop the capture and print the summary
  python capture-diagnostic-logs.py --action analyze --log-file F  summarize an existing log file
Options: --log-file PATH (start: where to write; stop and analyze: which file to read; stop defaults to the newest
diagnostic_bulk_mail_*.log), --log-dir DIR (default mobile-app/build/diagnostic-logs; build/ is gitignored).

The log and the process-id file (.logcat_pid) live in --log-dir, never in the current folder. The summary shows the
"=== SCAN DIAGNOSTICS ===" block, how many emails matched or did not match a rule, errors, migration messages, and the
"Rules loaded:" and "Safe senders loaded:" lines (a rule count below 40 is flagged).

Safety: adb is resolved through ANDROID_HOME first, and every adb call after detection uses `-s emulator-<port>`. A plugged-in
phone is never a capture target (company policy blocks USB debugging on the phones). With no online emulator the script exits 1.

Defects found in the PowerShell original, and what the port does:
  - adb came from the PATH (the older SDK on this machine) and the FIRST attached device was used, which could be a phone:
    FIXED, ANDROID_HOME first, emulators only, `-s <serial>`.
  - `-Action Stop` assigned to `$pid`, a read-only automatic variable in PowerShell, so Stop failed at that line, and it
    then ran the summary in a child `powershell -Command` that had no Write-Section function: the summary could not run.
    FIXED: one analysis function serves Stop and Analyze.
  - The pid file and the log were written to the current folder (not gitignored): FIXED, --log-dir under build/.
  - A stop of a process that was already gone was reported as success: KEPT as a warning with exit 0, because the goal (no
    capture running) holds; a pid file that cannot be read is an exit 1.
  - `adb logcat -c` and `adb wait-for-device` results were never checked, and wait-for-device had no limit: FIXED, a failing
    `logcat -c` is an exit 1 and there is no wait (no emulator means exit 1).
  - A hardcoded account name in the next-steps text: DROPPED (use whichever account you test).

Exit codes: 0 done; 1 adb or an online emulator is missing, logcat could not start or exited at once, there is no capture to
stop, a log file is missing or empty (0 bytes), the log holds no diagnostic marker at all, a capture id file already exists
at start, or the capture process cannot be stopped (PermissionError); 2 a usage error (argparse).

What this does NOT catch: a recycled process id (the stop kills whatever process now has the saved id; the id file lives
only while a capture runs, and the stop warns when the id is gone), logcat lines lost to the ring buffer size when a scan is
long, and diagnostics the app did not print (the summary says "No diagnostic block found").
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import signal
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import android_support as sup  # noqa: E402

PID_FILE = ".logcat_pid"
LOG_GLOB = "diagnostic_bulk_mail_*.log"
DIAG_MARK = "=== SCAN DIAGNOSTICS ==="
# The lines the app logs (rule_evaluator.dart, AppLogger.eval -> "[EVAL] ..." at debug level, so a debug build):
#   Email from <from> matched rule "<name>" (pattern: ...)
#   Email "<subject>" from <from> did not match any of <n> enabled rules or safe senders
# (C3-3, Sprint 86 5.1.2: the old check marks "✓ Email" / "✗ Email" are no longer printed anywhere in lib.)
# MATCHED_LITERAL / NOT_MATCHED_LITERAL are the fixed text the unit test finds in mobile-app/lib.
MATCHED_LITERAL = "matched rule"
NOT_MATCHED_LITERAL = "did not match any of"
MATCHED = re.compile(r"\[EVAL\] Email from .* " + MATCHED_LITERAL + r" \"")
NOT_MATCHED = re.compile(r"\[EVAL\] Email \".*\" from .* " + NOT_MATCHED_LITERAL + r" \d+ enabled rules")
ERRORS = re.compile(r"(ERROR|Exception|EXCEPTION|failed)")
MIGRATION = re.compile(r"(migration|Migration|YAML|Imported)")
RULES_LOADED = re.compile(r"Rules loaded: (\d+)")
MIN_RULES = 40
SETTLE_SECONDS = 1.0


def default_log_dir() -> Path:
    return sup.MOBILE_APP / "build" / "diagnostic-logs"


def stamp() -> str:
    return datetime.datetime.now().strftime("%H:%M:%S")


def status(text: str) -> None:
    sup.say(f"[{stamp()}] {text}")


def section(title: str) -> None:
    sup.say("")
    sup.say("=" * 70)
    sup.say(title)
    sup.say("=" * 70)


# ---- start / stop ---------------------------------------------------------------------------------------------

def do_start(log_dir: Path, log_file: Path | None) -> int:
    section("Starting Log Capture")
    adb = sup.find_adb()
    if not adb:
        status("ERROR: adb not found. Set ANDROID_HOME to the Android SDK folder.")
        return 1
    serials, error = sup.online_emulators(adb)
    if error:
        status(f"ERROR: {error}")
        return 1
    if not serials:
        status("ERROR: no online emulator. Start one (python start-emulator.py). Phones are never used.")
        return 1
    serial = serials[0]
    status(f"Using emulator {serial}" + (f" (first of {len(serials)})" if len(serials) > 1 else ""))

    log_dir.mkdir(parents=True, exist_ok=True)
    pid_path = log_dir / PID_FILE
    if pid_path.exists():
        status(f"ERROR: a capture may still be running ({pid_path} exists). Run --action stop first, or delete the file "
               "after you confirm no logcat process of this script is running.")
        return 1
    target = log_file or log_dir / f"diagnostic_bulk_mail_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    code, out = sup.run_capture([adb, "-s", serial, "logcat", "-c"], timeout=60)
    if code != 0:
        status(f"ERROR: adb logcat -c failed (exit {code}): {out.strip()[:200]}")
        return 1
    status(f"Starting log capture to: {target}")
    kwargs = sup.detached_kwargs()
    try:
        with open(target, "wb") as sink:
            kwargs["stdout"] = sink
            proc = subprocess.Popen([adb, "-s", serial, "logcat"], **kwargs)
    except OSError as exc:
        status(f"ERROR: could not start logcat: {exc}")
        return 1
    sup.sleep(SETTLE_SECONDS)
    if proc.poll() is not None:
        status(f"ERROR: logcat exited at once (exit {proc.returncode}).")
        return 1
    (log_dir / PID_FILE).write_text(json.dumps({"pid": proc.pid, "log": str(target), "serial": serial}), encoding="utf-8")
    status(f"Log capture started (process id {proc.pid}).")
    section("Next Steps")
    sup.say("1. In the app, open the account you test and choose 'Start Live Scan' (not Demo Scan).")
    sup.say("2. Select the folder and wait for the scan to finish (or about 20 emails).")
    sup.say("3. Run: python capture-diagnostic-logs.py --action stop")
    return 0


def windows_pid_alive(pid: int) -> bool:
    """True when a Windows process with this id exists and has not exited. Access denied on open counts as alive."""
    import ctypes
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.OpenProcess.restype = ctypes.c_void_p
    handle = kernel32.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
    if not handle:
        return ctypes.get_last_error() != 87  # 87 = no such process id
    try:
        code = ctypes.c_ulong()
        if not kernel32.GetExitCodeProcess(ctypes.c_void_p(handle), ctypes.byref(code)):
            return True
        return code.value == 259  # STILL_ACTIVE
    finally:
        kernel32.CloseHandle(ctypes.c_void_p(handle))


def stop_process(pid: int) -> bool:
    """True when a process was stopped; False when it was already gone (no such process).

    Any OTHER failure (PermissionError: the process exists and cannot be stopped) is raised, so do_stop reports it instead
    of calling a live capture "already gone" (C6-5, Sprint 86 5.1.2). A missing pid is ProcessLookupError on POSIX and
    OSError with winerror 87 (invalid parameter) on Windows.
    """
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        return False
    except PermissionError:
        # Windows also reports an EXITED process whose handle is still open elsewhere as access denied (WinError 5),
        # so ask the OS whether the process is alive before calling this a refusal.
        if os.name == "nt" and not windows_pid_alive(pid):
            return False
        raise
    except OSError as exc:
        if getattr(exc, "winerror", None) == 87:
            return False
        raise
    return True


def newest_log(log_dir: Path) -> Path | None:
    logs = sorted(log_dir.glob(LOG_GLOB), key=lambda p: p.stat().st_mtime, reverse=True)
    return logs[0] if logs else None


def do_stop(log_dir: Path, log_file: Path | None) -> int:
    section("Stopping Log Capture")
    pid_path = log_dir / PID_FILE
    if not pid_path.is_file():
        status("ERROR: no active log capture found. Start with: --action start")
        return 1
    try:
        info = json.loads(pid_path.read_text(encoding="utf-8"))
        pid = int(info["pid"])
    except (OSError, ValueError, KeyError, TypeError) as exc:
        status(f"ERROR: the capture id file {pid_path} is unreadable: {exc}")
        return 1
    try:
        stopped = stop_process(pid)
    except OSError as exc:
        status(f"ERROR: could not stop process {pid}: {exc}. The id file is kept; stop it by hand, then delete {pid_path}.")
        return 1
    if stopped:
        status(f"Log capture stopped (process id {pid}).")
    else:
        status(f"WARNING: process {pid} was already gone.")
    sup.sleep(0.5)
    try:
        pid_path.unlink()
    except OSError as exc:
        status(f"WARNING: could not delete {pid_path}: {exc}")
    chosen = log_file or (Path(info["log"]) if info.get("log") else newest_log(log_dir))
    if not chosen or not Path(chosen).is_file():
        status(f"ERROR: no log file found (looked for {LOG_GLOB} in {log_dir})")
        return 1
    status(f"Log file: {chosen}")
    return analyze(Path(chosen), brief=True)


# ---- analysis -------------------------------------------------------------------------------------------------

def read_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8", errors="replace").splitlines()


def analyze(path: Path, brief: bool) -> int:
    if not path.is_file():
        status(f"ERROR: log file not found: {path}")
        return 1
    if path.stat().st_size == 0:
        status(f"ERROR: the log file is empty (0 bytes): {path}. Nothing was captured (no scan ran, or logcat was cleared).")
        return 1
    lines = read_lines(path)
    section(f"Analyzing Log File: {path}")

    section("DIAGNOSTIC OUTPUT")
    marks = [i for i, line in enumerate(lines) if DIAG_MARK in line]
    if marks:
        for line in lines[marks[0]:marks[0] + 11]:
            sup.say(line)
    else:
        status("No diagnostic block found!")

    matched = [line for line in lines if MATCHED.search(line)]
    unmatched = [line for line in lines if NOT_MATCHED.search(line)]
    section("RULE MATCHING SUMMARY")
    status(f"Matched: {len(matched)} emails")
    status(f"No match: {len(unmatched)} emails")
    limit = 5 if brief else 10
    section(f"DETAILED MATCHES (first {limit})")
    if matched:
        for line in matched[:limit]:
            sup.say("  " + line)
        if len(matched) > limit:
            sup.say(f"  ... and {len(matched) - limit} more")
    else:
        sup.say("  (no matches found)")
    if not brief:
        section("SAMPLE NO-MATCHES (first 5)")
        if unmatched:
            for line in unmatched[:5]:
                sup.say("  " + line)
        else:
            sup.say("  (all emails matched)")

    section("ERRORS AND WARNINGS" if brief else "ERROR CHECK")
    errors = [line for line in lines if ERRORS.search(line)]
    if errors:
        status(f"Found {len(errors)} error/exception entries")
        for line in errors[:10] if brief else errors:
            sup.say("  " + line)
    else:
        status("No errors found")

    if brief:
        section("MIGRATION STATUS")
        migration = [line for line in lines if MIGRATION.search(line)]
        if migration:
            for line in migration:
                sup.say("  " + line)
        else:
            sup.say("No migration messages found (might be expected if not first run)")

    section("RULES STATUS")
    for line in lines:
        found = RULES_LOADED.search(line)
        if found:
            sup.say("  " + line)
            count = int(found.group(1))
            if count == 0:
                status("WARNING: No rules loaded! Migration may have failed.")
            elif count < MIN_RULES:
                status(f"WARNING: Only {count} rules loaded (expected {MIN_RULES}+)")
            else:
                status(f"Rules loaded: {count} (expected)")
            break
    else:
        sup.say("  (no 'Rules loaded:' line found)")
    section("SAFE SENDERS STATUS")
    for line in lines:
        if "Safe senders loaded:" in line:
            sup.say("  " + line)
            break
    else:
        sup.say("  (no 'Safe senders loaded:' line found)")
    sup.say("")
    if not (marks or matched or unmatched or any(RULES_LOADED.search(line) for line in lines)):
        status("ERROR: no diagnostic marker found (no SCAN DIAGNOSTICS block, no rule match or no-match line, no 'Rules "
               "loaded:' line). The scan may not have run, or the build is not a debug build ([EVAL] lines are debug level).")
        return 1
    return 0


def main(argv: list[str] | None = None) -> int:
    sup.common.configure_stdio()
    parser = argparse.ArgumentParser(description="Capture emulator logcat and summarize the rule diagnostics.")
    parser.add_argument("--action", choices=("start", "stop", "analyze"), default="start")
    parser.add_argument("--log-file", default=None)
    parser.add_argument("--log-dir", default=None)
    args = parser.parse_args(argv)
    log_dir = Path(args.log_dir) if args.log_dir else default_log_dir()
    log_file = Path(args.log_file) if args.log_file else None
    if args.action == "start":
        return do_start(log_dir, log_file)
    if args.action == "stop":
        return do_stop(log_dir, log_file)
    if log_file is None:
        status("ERROR: --action analyze needs --log-file.")
        return 1
    return analyze(log_file, brief=False)


if __name__ == "__main__":
    sys.exit(main())
