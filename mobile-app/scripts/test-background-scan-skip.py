#!/usr/bin/env python3
"""Integration check for F243 (was BUG-S37-1): a background scan runs while the foreground UI is open
(port of test-background-scan-skip.ps1, Sprint 38 / Sprint 75 F243; Sprint 85 F334).

WINDOWS ONLY. It launches the Windows .exe, relies on the native single-instance mutex behavior of
windows/runner/main.cpp, stops processes by executable path, and reads %APPDATA%. On other systems it
exits 1 before doing anything.

What it asserts, with the foreground UI open:
    1a  the --background-scan process finishes within 90 seconds
    1b  the native probe logged "Foreground UI is running; background scan proceeds"
    1c  the Dart worker started ("=== Background scan started ===")
    1d  the launch was not deferred ("Background scan skipped" is absent)

Side-effect free: the launch names an account that does not exist, so the worker starts, finds no matching
account and exits without touching mail or the database. Whether a real scan proceeds past the per-account
claim is covered by the Dart tests (mv74_2_scan_heartbeat_test, f238_*) and Manual Validation.

Pre-condition: build-windows.ps1 has produced mobile-app\\dist\\dev\\MyEmailSpamFilter-Dev.exe (or, with
--environment prod, mobile-app\\dist\\prod\\MyEmailSpamFilter.exe).

Usage:
    python mobile-app/scripts/test-background-scan-skip.py               # dev build (default)
    python mobile-app/scripts/test-background-scan-skip.py --environment prod

Exit codes:
    0  all assertions passed
    1  setup failure (not Windows, the .exe is missing, pubspec.yaml has no version)
    2  an assertion failed (the fix is broken)
    2  argparse also uses 2 for an invalid argument
The leftover-process cleanup and the final stop match on the executable PATH, never on the image name, because
the production app uses the same image name and must not be stopped by a dev test.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
MOBILE_APP = SCRIPTS.parent
ACCOUNT = "f243-no-such-account@example.invalid"
PROCEEDS = "Foreground UI is running; background scan proceeds"
STARTED = "=== Background scan started ==="
SKIPPED = "Background scan skipped"
SW_SHOWMINIMIZED = 7


def derive_version(pubspec_text: str) -> str | None:
    """The app version (x.y.z) from the top-level `version:` line of pubspec.yaml, or None."""
    match = re.search(r"(?m)^version:\s*(\d+\.\d+\.\d+)", pubspec_text)
    return match.group(1) if match else None


def settings_for(environment: str, mobile_app: Path, appdata: str | None, version: str) -> dict:
    """Paths and names for one build variant (ADR-0035 and the Sprint 37 F52 layout)."""
    if environment == "dev":
        exe = mobile_app / "dist" / "dev" / "MyEmailSpamFilter-Dev.exe"
        data_sub, prefix = "MyEmailSpamFilter_Dev", "dev_"
    else:
        exe = mobile_app / "dist" / "prod" / "MyEmailSpamFilter.exe"
        data_sub, prefix = "MyEmailSpamFilter", ""
    log_dir = Path(appdata or "") / "MyEmailSpamFilter" / data_sub / "logs"
    return {"exe": exe, "log": log_dir / f"{prefix}background_scan_v{version}.log", "log_dir": log_dir}


def check_new_log_text(new_text: str, finished: bool) -> list[str]:
    """The failure messages for one background launch. An empty list means every assertion passed."""
    failures = []
    if not finished:
        failures.append("Test 1 assertion 1a FAILED: --background-scan still running after 90 s")
    if PROCEEDS not in new_text:
        failures.append("Test 1 assertion 1b FAILED: no 'background scan proceeds' line was logged")
    if STARTED not in new_text:
        failures.append("Test 1 assertion 1c FAILED: the Dart worker never started "
                        "(no '=== Background scan started ===')")
    if SKIPPED in new_text:
        failures.append("Test 1 assertion 1d FAILED: the launch was still deferred ('Background scan skipped')")
    return failures


class WindowsOps:
    """The process and window operations. Every one is replaceable in tests."""

    is_windows = os.name == "nt"

    def start_foreground(self, exe: Path) -> subprocess.Popen:
        info = subprocess.STARTUPINFO()
        info.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        info.wShowWindow = SW_SHOWMINIMIZED
        return subprocess.Popen([str(exe)], startupinfo=info)

    def start_background(self, exe: Path) -> subprocess.Popen:
        return subprocess.Popen([str(exe), "--background-scan", f"--account-id={ACCOUNT}"])

    def wait(self, proc: subprocess.Popen, seconds: float) -> bool:
        try:
            proc.wait(timeout=seconds)
            return True
        except subprocess.TimeoutExpired:
            return False

    def running_from(self, exe: Path) -> list[int]:
        """Process ids whose executable path is exe. Matches the path, not the image name."""
        env = dict(os.environ, BG_TEST_EXE=str(exe))
        command = "Get-Process | Where-Object { $_.Path -eq $env:BG_TEST_EXE } | ForEach-Object { $_.Id }"
        done = subprocess.run(["powershell", "-NoProfile", "-Command", command], env=env,
                              capture_output=True, text=True)
        return [int(line) for line in done.stdout.split() if line.strip().isdigit()]

    def stop_pid(self, pid: int) -> None:
        subprocess.run(["taskkill", "/PID", str(pid), "/F"], capture_output=True)


def _size(path: Path) -> int:
    return path.stat().st_size if path.exists() else 0


def run(environment: str, mobile_app: Path, appdata: str | None, ops, *, sleep=time.sleep, out=print) -> int:
    """Run the three-step check. Returns the exit code (0, 1 or 2). `ops` supplies the process calls."""
    if not ops.is_windows:
        out("[FAIL] this test needs Windows: it launches the Windows .exe and reads %APPDATA%")
        return 1
    pubspec = mobile_app / "pubspec.yaml"
    if not pubspec.exists():
        out(f"[FAIL] pubspec.yaml not found at {pubspec}")
        return 1
    version = derive_version(pubspec.read_text(encoding="utf-8"))
    if version is None:
        out(f"[FAIL] Could not parse version from {pubspec}")
        return 1
    paths = settings_for(environment, mobile_app, appdata, version)
    exe, log = paths["exe"], paths["log"]
    out(f"[Setup] F243 (was BUG-S37-1) integration test ({environment} variant)")
    out(f"  exe:      {exe}")
    out(f"  log file: {log}")
    if not exe.exists():
        out(f"Test exe not found at {exe}. Run scripts\\build-windows.ps1 -Environment {environment} first.")
        return 1
    if appdata is None:
        out("[FAIL] APPDATA is not set; the log location cannot be found")
        return 1

    paths["log_dir"].mkdir(parents=True, exist_ok=True)
    out("[Setup] Killing any leftover processes from this executable...")
    leftover = ops.running_from(exe)
    if leftover:
        for pid in leftover:
            ops.stop_pid(pid)
        sleep(2)

    failures: list[str] = []
    try:
        out("")
        out("[Test 1] Foreground UI running -> background scan must proceed (F243)")
        out("  Starting foreground UI...")
        foreground = ops.start_foreground(exe)
        sleep(5)
        if foreground.poll() is not None:
            failures.append(f"Foreground UI exited prematurely (exit code {foreground.returncode}). "
                            "Cannot run the UI-open test.")
        else:
            before = _size(log)
            out(f"  Launching --background-scan --account-id={ACCOUNT} (UI open)...")
            scan = ops.start_background(exe)
            finished = ops.wait(scan, 90)
            if not finished:
                ops.stop_pid(scan.pid)
            new_text = ""
            if log.exists():
                data = log.read_bytes()
                if len(data) > before:
                    new_text = data[before:].decode("utf-8", errors="replace")
            failures.extend(check_new_log_text(new_text, finished))
            out("  Stopping foreground UI...")
            ops.stop_pid(foreground.pid)
            sleep(2)
    finally:
        for pid in ops.running_from(exe):
            ops.stop_pid(pid)

    out("")
    out("[Summary]")
    if not failures:
        out("  All assertions PASSED. F243: background scans run with the UI open.")
        return 0
    out(f"  {len(failures)} assertion failure(s):")
    for failure in failures:
        out(f"  - {failure}")
    return 2


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Check that --background-scan runs with the Windows UI open.")
    parser.add_argument("--environment", choices=("dev", "prod"), default="dev",
                        help="which built executable to test (default: dev)")
    args = parser.parse_args(argv)
    if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    return run(args.environment, MOBILE_APP, os.environ.get("APPDATA"), WindowsOps())


if __name__ == "__main__":
    sys.exit(main())
