"""Run ONE timed battery-count arm on the Android EMULATOR (Sprint 77 R76-1, Issue #464; F332 Sprint 85).

Python port of the former mobile-app/scripts/r76_battery_arm.sh (ADR-0051). Standard library only.

Counts only (an emulator has no battery hardware, so it cannot measure energy): wakeups, alarms, jobs,
network bytes and CPU for the app UID, scans started (diagnostic log `trigger=` lines), and the longest
gap between scans. Sequence: set standby bucket, unplug battery, reset batterystats, snapshot
dumpsys alarm/jobscheduler, screen off, wait 2 minutes, force Doze idle, run the window (optionally posting
a debug-package notification every N minutes with `cmd notification post`, which posts as
com.android.shell -- accepted only by DEBUG builds, see MailNotificationPolicy.DEBUG_ONLY_PACKAGES), then
snapshot again and pull the diagnostic log. Leaves the device un-forced and un-plugged by a reset.

adb is used ONLY against the Android emulator in this project: company policy blocks USB debugging on the
phones. Do not point it at a device.

Usage:
  python mobile-app/scripts/r76_battery_arm.py <arm> <minutes> [cadence-minutes]
  python mobile-app/scripts/r76_battery_arm.py arm1 60 0

Arguments:
  arm               arm label, used for the output folder name (letters, digits, '.', '_', '-')
  minutes           window length in minutes (protocol: 60; shorter allowed, say so in the report)
  cadence-minutes   notification cadence in minutes (default 0 = none)

Environment:
  ANDROID_HOME      SDK root; adb is read from $ANDROID_HOME/platform-tools (adb.exe or adb). When that
                    is not set or holds no adb, adb is taken from PATH.
  PKG               app package (default com.myemailspamfilter.dev)
  DIAG_DIR          device folder with the diagnostic logs
                    (default /sdcard/Documents/MyEmailSpamFilter_Dev/diagnostics; F282)
  OUT_ROOT          output root (default ./r76_out); the run writes <OUT_ROOT>/<arm>/

Output: <OUT_ROOT>/<arm>/ with before_/after_ dumps, meta.txt and the pulled diag/ folder.

Exit codes:
  0  the run completed and every adb step succeeded
  1  the run completed but at least one adb step failed (each is named in meta.txt); the device
     is still restored (un-forced, battery reset, woken)
  2  usage error, adb not found, or no device answered before anything was changed

Requires: a running emulator with the DEV flavor installed and the diagnostic log ON.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
import common  # noqa: E402

DEFAULT_PKG = "com.myemailspamfilter.dev"
DEFAULT_DIAG_DIR = "/sdcard/Documents/MyEmailSpamFilter_Dev/diagnostics"
ARM_LABEL = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]*$")
EXIT_OK, EXIT_STEP_FAILED, EXIT_USAGE = 0, 1, 2


def find_adb() -> str | None:
    """adb under $ANDROID_HOME/platform-tools, else adb on PATH. None when neither exists."""
    android_home = os.environ.get("ANDROID_HOME")
    if android_home:
        for name in ("adb.exe", "adb"):
            candidate = Path(android_home) / "platform-tools" / name
            if candidate.is_file():
                return str(candidate)
    return shutil.which("adb")


class Arm:
    """One run. Every adb call goes through step(), so a failure is recorded, never silent."""

    def __init__(self, adb: str, out: Path, pkg: str, diag_dir: str, runner=None) -> None:
        self.adb = adb
        self.out = out
        self.pkg = pkg
        self.diag_dir = diag_dir
        self.failures: list[str] = []
        self.posted = 0
        self.meta = out / "meta.txt"
        # runner(args) -> (exit code, stdout). The tests inject an in-memory device for speed; the
        # default runs the adb executable.
        self.runner = runner if runner is not None else self._run_adb

    def _run_adb(self, args: list[str]) -> tuple[int, str]:
        proc = subprocess.run([self.adb, *args], capture_output=True, text=True, encoding="utf-8",
                              errors="replace", stdin=subprocess.DEVNULL, check=False)
        return proc.returncode, proc.stdout or ""

    def emit(self, line: str) -> None:
        """Print a line and append it to meta.txt (the shell's `tee -a meta.txt`)."""
        print(line)
        with self.meta.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")

    def step(self, args: list[str], label: str = "") -> tuple[int, str]:
        """Run `adb <args>`; return (exit code, stdout with CR removed). A non-zero code is recorded."""
        try:
            code, output = self.runner(args)
        except OSError as exc:
            self.failures.append(f"{' '.join(args)} ({exc})")
            return 1, ""
        if code != 0:
            self.failures.append(f"{' '.join(args)} (exit {code}{', ' + label if label else ''})")
        return code, output.replace("\r", "")

    def epoch(self) -> int | None:
        """The device clock in epoch seconds, or None when adb did not return a number."""
        code, text = self.step(["shell", "date", "+%s"])
        digits = text.strip()
        if code != 0 or not digits.isdigit():
            return None
        return int(digits)

    def snap(self, phase: str) -> None:
        """Dumps before or after the window (the shell's snap function)."""
        for name, args in (
            ("alarm", ["shell", "dumpsys", "alarm"]),
            ("jobscheduler", ["shell", "dumpsys", "jobscheduler"]),
            ("batterystats_pkg", ["shell", "dumpsys", "batterystats", self.pkg]),
            ("deviceidle", ["shell", "dumpsys", "deviceidle", "get", "deep"]),
        ):
            _code, text = self.step(args)
            (self.out / f"{phase}_{name}.txt").write_text(text, encoding="utf-8")
        # Per-UID bytes: netstats only flushes on a poll (default every 30 minutes), so force one.
        self.step(["shell", "cmd", "netstats", "poll"])
        _code, text = self.step(["shell", "dumpsys", "netstats", "detail"])
        (self.out / f"{phase}_netstats.txt").write_text(text, encoding="utf-8")


def run_arm(arm_name: str, minutes: int, cadence: int, adb: str, out_root: Path, pkg: str,
            diag_dir: str, sleep=None, runner=None) -> int:
    """The whole sequence. `sleep` and `runner` are injectable so the tests run without waiting and
    without a process per adb call; None means time.sleep and the adb executable."""
    if sleep is None:
        sleep = time.sleep
    out = out_root / arm_name
    out.mkdir(parents=True, exist_ok=True)
    arm = Arm(adb, out, pkg, diag_dir, runner)

    start = arm.epoch()
    if start is None:
        print("adb did not return a device time: no device or emulator answered. Nothing was changed.")
        return EXIT_USAGE
    arm.meta.write_text("", encoding="utf-8")
    arm.emit(f"{arm_name} start epoch={start} minutes={minutes} cadence={cadence}")

    arm.step(["shell", "am", "set-standby-bucket", pkg, "working_set"])
    arm.step(["shell", "dumpsys", "battery", "unplug"])
    arm.step(["shell", "dumpsys", "batterystats", "--reset"])
    arm.step(["shell", "input", "keyevent", "KEYCODE_HOME"])
    arm.snap("before")
    arm.step(["shell", "input", "keyevent", "KEYCODE_SLEEP"])
    sleep(120)
    _code, idle_text = arm.step(["shell", "dumpsys", "deviceidle", "force-idle"])
    for line in idle_text.splitlines():
        arm.emit(line)
    idle = arm.epoch()
    arm.emit(f"idle epoch={idle}")
    if idle is None:
        arm.failures.append("date after force-idle (no device time: window not timed)")
    else:
        end = idle + minutes * 60
        while True:
            now = arm.epoch()
            if now is None:
                arm.failures.append("date inside the window (window stopped early)")
                break
            if now >= end:
                break
            if cadence > 0:
                arm.posted += 1
                arm.step(["shell", "cmd", "notification", "post", "-t", f"r761 test {arm.posted}",
                          f"r761tag{arm.posted}", f"r761 body {arm.posted}"])
                arm.emit(f"posted {arm.posted} at {now}")
                wait = cadence * 60
            else:
                wait = 60
            # Never sleep past the window end: the shell slept a whole cadence and overshot (F332 defect).
            sleep(min(wait, end - now))

    arm.snap("after")
    arm.step(["shell", "dumpsys", "deviceidle", "unforce"])
    arm.step(["shell", "dumpsys", "battery", "reset"])
    _code, text = arm.step(["shell", "dumpsys", "batterystats", pkg])
    (out / "after_batterystats_full_pkg.txt").write_text(text, encoding="utf-8")
    _code, text = arm.step(["shell", "dumpsys", "batterystats", "--checkin", pkg])
    (out / "after_batterystats_checkin.txt").write_text(text, encoding="utf-8")

    # F282 (0.20.0+): the DEV export folder is Documents/MyEmailSpamFilter_Dev; pre-0.20.0 builds wrote
    # Documents/diagnostics_Dev. A failed pull is named, so a moved folder is not missed.
    diag = out / "diag"
    shutil.rmtree(diag, ignore_errors=True)
    code, _text = arm.step(["pull", diag_dir, str(diag)], label="diagnostic pull")
    if code != 0:
        arm.emit(f"WARNING: no diagnostic log pulled from {diag_dir}")

    after = arm.epoch()
    arm.emit(f"end epoch={after} notifications_posted={arm.posted}")
    arm.step(["shell", "input", "keyevent", "KEYCODE_WAKEUP"])
    for failure in arm.failures:
        arm.emit(f"FAILED adb step: {failure}")
    return EXIT_STEP_FAILED if arm.failures else EXIT_OK


def main(argv: list[str] | None = None) -> int:
    common.configure_stdio()
    parser = argparse.ArgumentParser(description="Run one timed battery-count arm on the Android emulator.")
    parser.add_argument("arm", help="arm label (folder name)")
    parser.add_argument("minutes", type=int, help="window length in minutes")
    parser.add_argument("cadence", type=int, nargs="?", default=0, help="notification cadence in minutes (0 = none)")
    args = parser.parse_args(argv)

    if not ARM_LABEL.match(args.arm):
        print(f"arm label {args.arm!r} must be a plain name (letters, digits, '.', '_', '-')")
        return EXIT_USAGE
    if args.minutes < 1:
        print("minutes must be at least 1")
        return EXIT_USAGE
    if args.cadence < 0:
        print("cadence must be 0 or more")
        return EXIT_USAGE
    adb = find_adb()
    if adb is None:
        print("adb not found: set ANDROID_HOME (platform-tools\\adb.exe) or put adb on PATH.")
        return EXIT_USAGE
    out_root = Path(os.environ.get("OUT_ROOT", "./r76_out"))
    pkg = os.environ.get("PKG", DEFAULT_PKG)
    diag_dir = os.environ.get("DIAG_DIR", DEFAULT_DIAG_DIR)
    return run_arm(args.arm, args.minutes, args.cadence, adb, out_root, pkg, diag_dir)


if __name__ == "__main__":
    sys.exit(main())
