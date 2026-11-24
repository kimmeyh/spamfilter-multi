"""Start the Android emulator (pixel34_updated AVD) and leave it running (F336, Sprint 86; Python port of start-emulator.ps1).

Usage:
  python start-emulator.py                  start pixel34_updated
  python start-emulator.py --avd NAME       start a different AVD
  python start-emulator.py --cold-boot      add -no-snapshot-load (recovery for a corrupted quick-boot snapshot: a frozen
                                            stale frame, unclickable UI, adb "offline", or a silent exit; about 45 s)
  python start-emulator.py --sdk-root PATH  use another SDK (default: ANDROID_HOME)
  python start-emulator.py --force          start even when an emulator is already online

This ONLY starts the emulator. To put current code on it afterwards:
  python build-with-secrets.py --build-type debug --install-to-emulator

Why the SDK matters (Sprint 60): this machine has two Android SDKs. The AVD belongs to the one ANDROID_HOME points at,
and only ITS emulator.exe can boot it (the other prints "Can't find 'Linux version' string in kernel image file").
ANDROID_SDK_ROOT must point at the same SDK or the emulator panics with "Cannot find AVD system path". The script sets
both for the child process only. The netsimd.exe crash dialog that sometimes appears is a known benign sidecar failure:
click "Close program".

Defects found in the PowerShell original, and what the port does:
  - SDK root hardcoded to C:\\Android\\android-sdk: FIXED, default is ANDROID_HOME (--sdk-root still overrides).
  - Started a second emulator when one was already running: FIXED, reports the running one and exits 0 (--force starts anyway).
  - Never checked that the AVD exists: FIXED, an unknown name lists the real ones and exits 1.
  - Reported "Launched" without checking the process: FIXED, a process that exits within SETTLE_SECONDS is an exit 1
    (the Sprint 61 "exits silently on start" signature).
  - Start-Process of the emulator inherited the console: KEPT as a detached process, so the window can be closed.

Exit codes: 0 started, or an emulator is already online; 1 the emulator is missing, the AVD is unknown, or the process
exited at once; 2 a usage error (argparse).

What this does NOT catch: a boot that hangs after the process starts (use wait_for_boot in run-emulator.py or look at the
window), a corrupted snapshot that boots to a frozen frame (use --cold-boot), and the netsimd dialog.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import android_support as sup  # noqa: E402

DEFAULT_AVD = "pixel34_updated"
SETTLE_SECONDS = 3.0
"""How long the new process must stay alive before it is reported as started."""


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Start the Android emulator and leave it running.")
    parser.add_argument("--avd", default=DEFAULT_AVD, help=f"AVD name (default {DEFAULT_AVD})")
    parser.add_argument("--sdk-root", default=None, help="Android SDK folder (default: ANDROID_HOME)")
    parser.add_argument("--cold-boot", action="store_true", help="start with -no-snapshot-load")
    parser.add_argument("--force", action="store_true", help="start even when an emulator is already online")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    sup.common.configure_stdio()
    args = parse_args(argv)
    if args.sdk_root:
        os.environ["ANDROID_HOME"] = args.sdk_root
    emulator = sup.find_emulator()
    if not emulator:
        sup.say("[ERROR] emulator not found. Set ANDROID_HOME (or --sdk-root) to the Android SDK folder.")
        return 1
    sup.say(f"[emulator] Using {emulator}")

    adb = sup.find_adb()
    if adb and not args.force:
        serials, _ = sup.online_emulators(adb)
        if serials:
            sup.say(f"[emulator] An emulator is already online ({serials[0]}). Nothing to start. Use --force to start another.")
            return 0

    avds, error = sup.list_avds(emulator)
    if error:
        sup.say(f"[ERROR] {error}")
        return 1
    if args.avd not in avds:
        sup.say(f"[ERROR] AVD '{args.avd}' not found. Available: {', '.join(avds) if avds else '(none)'}")
        return 1

    sup.say(f"[emulator] Starting AVD '{args.avd}' ...")
    if args.cold_boot:
        sup.say("[emulator] Cold boot requested (-no-snapshot-load); expect about 45 s.")
    try:
        proc = sup.launch_emulator(emulator, args.avd, cold_boot=args.cold_boot, sdk_root=args.sdk_root)
    except OSError as exc:
        sup.say(f"[ERROR] could not start the emulator: {exc}")
        return 1
    try:
        code = proc.wait(timeout=SETTLE_SECONDS)  # returns at once when the process exits inside the window
    except subprocess.TimeoutExpired:
        code = None
    if code is not None:
        sup.say(f"[ERROR] The emulator process exited at once (exit {code}). Try --cold-boot, and check ANDROID_HOME.")
        return 1
    sup.say("[emulator] Launched. Boot takes about 30-60 s; check with: adb devices")
    sup.say("[emulator] If a netsimd.exe crash dialog appears, click 'Close program'. It is benign.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
