"""Shared helpers for the Android helper scripts in this folder (F336, Sprint 86).

Used by run-emulator.py, start-emulator.py and capture-diagnostic-logs.py. Standard library only (ADR-0051).
Runs on Windows, Linux and macOS.

Rules every helper here follows:
  - A tool is resolved through ANDROID_HOME FIRST, then the PATH (CLAUDE.md, Sprint 67 IMP-3: this machine has two
    Android SDK installs, and the older one on the PATH has an emulator that cannot boot the current images).
  - adb is only ever pointed at an EMULATOR serial ("emulator-<port>"). A physical phone is never a target: the
    company policy blocks USB debugging on the phones, and a stray phone must not receive an install or a log capture.
  - A missing tool or a failing command is returned as a non-zero code with the reason as text. It never raises.

What this does NOT catch: whether the AVD image boots (the emulator decides that), and whether ANDROID_HOME points at
the SDK that owns the AVD (the AVD lives in ~/.android/avd; the emulator reports a mismatch itself).
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
import time
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
MOBILE_APP = SCRIPTS.parent
REPO = MOBILE_APP.parent
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
import common  # noqa: E402  (find_tool, configure_stdio: the shared ADR-0051 layer)

NOT_FOUND = 127
"""Exit code for a tool that is not installed or could not start (the shell convention)."""

AVD_NAME = re.compile(r"^[A-Za-z0-9._-]+$")

# Secrets-file key names the helper scripts read or write. ONE source (C1-1, Sprint 86 5.1.2): each must appear as a
# String.fromEnvironment('<name>' in mobile-app/lib, which test_android_helpers.SecretsKeyNameTests enforces. The app
# reads the WINDOWS_* names (gmail_windows_oauth_handler.dart); GMAIL_DESKTOP_CLIENT_ID is its legacy client-id fallback.
WINDOWS_CLIENT_ID_KEY = "WINDOWS_GMAIL_DESKTOP_CLIENT_ID"
LEGACY_CLIENT_ID_KEY = "GMAIL_DESKTOP_CLIENT_ID"
WINDOWS_CLIENT_SECRET_KEY = "WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET"
REDIRECT_URI_KEY = "GMAIL_REDIRECT_URI"
ANDROID_CLIENT_ID_KEY = "ANDROID_GMAIL_CLIENT_ID"
# A key older templates carried; no build reads it, so a value kept only there never reaches the app.
DEAD_SECRET_KEY = "GMAIL_OAUTH_CLIENT_SECRET"
SECRETS_KEYS_USED = (WINDOWS_CLIENT_ID_KEY, LEGACY_CLIENT_ID_KEY, WINDOWS_CLIENT_SECRET_KEY, REDIRECT_URI_KEY,
                     ANDROID_CLIENT_ID_KEY)
"""Every key a helper script touches that the app must read; the test checks each against mobile-app/lib."""


def say(text: str = "") -> None:
    print(text, flush=True)


def sleep(seconds: float) -> None:
    """Indirection so tests can run the wait loops without waiting."""
    time.sleep(seconds)


def sdk_tool(relative: str, *names: str) -> str | None:
    """A tool through ANDROID_HOME first (relative path without extension), then the PATH."""
    home = os.environ.get("ANDROID_HOME")
    if home:
        for suffix in ("", ".exe", ".bat"):
            candidate = Path(home) / (relative + suffix)
            if candidate.is_file():
                return str(candidate)
    return common.find_tool(*names)


def find_adb() -> str | None:
    return sdk_tool("platform-tools/adb", "adb")


def find_emulator() -> str | None:
    return sdk_tool("emulator/emulator", "emulator")


def run_capture(argv: list[str], cwd: Path | None = None, timeout: float | None = None,
                env: dict[str, str] | None = None) -> tuple[int, str]:
    """Run to completion, stdout and stderr merged. Never raises for a failing or missing command.

    A missing executable or a timeout returns NOT_FOUND with the reason as the text, so the caller reports it
    instead of treating an empty output as success.
    """
    try:
        done = subprocess.run(argv, cwd=str(cwd) if cwd else None, env=env, stdin=subprocess.DEVNULL,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return NOT_FOUND, f"could not run {argv[0]}: {exc}\n"
    return done.returncode, done.stdout.decode("utf-8", errors="replace")


def run_inherit(argv: list[str], cwd: Path | None = None, env: dict[str, str] | None = None) -> int:
    """Run with the console attached (output streams); return the exit code, NOT_FOUND when it cannot start."""
    try:
        return subprocess.run(argv, cwd=str(cwd) if cwd else None, env=env, stdin=subprocess.DEVNULL).returncode
    except OSError as exc:
        say(f"[ERROR] could not start {argv[0]}: {exc}")
        return NOT_FOUND


def detached_kwargs() -> dict:
    """Popen options that give a background process none of our handles."""
    kwargs: dict = {"stdin": subprocess.DEVNULL, "stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
    if os.name == "nt":
        kwargs["creationflags"] = 0x00000008 | 0x08000000  # DETACHED_PROCESS | CREATE_NO_WINDOW
    else:
        kwargs["start_new_session"] = True
    return kwargs


def parse_emulator_serials(devices_output: str) -> list[str]:
    """Serials of emulators in state 'device' from `adb devices` text. Offline, unauthorized and phone rows are skipped."""
    serials = []
    for line in devices_output.splitlines():
        parts = line.strip().split()
        if len(parts) >= 2 and parts[0].startswith("emulator-") and parts[1] == "device":
            serials.append(parts[0])
    return serials


def online_emulators(adb: str) -> tuple[list[str], str | None]:
    """(serials of online emulators, error text). The error is set when adb could not run or exited non-zero."""
    code, out = run_capture([adb, "devices"], timeout=30)
    if code != 0:
        return [], f"adb devices failed (exit {code}): {out.strip()[:200]}"
    return parse_emulator_serials(out), None


def list_avds(emulator: str) -> tuple[list[str], str | None]:
    """(AVD names, error text). stdout only, and only lines shaped like an AVD name (a warning line is not an AVD)."""
    try:
        done = subprocess.run([emulator, "-list-avds"], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                              stderr=subprocess.DEVNULL, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return [], f"could not list AVDs with {emulator}: {exc}"
    if done.returncode != 0:
        return [], f"{emulator} -list-avds failed (exit {done.returncode})"
    names = [line.strip() for line in done.stdout.decode("utf-8", errors="replace").splitlines()]
    return [name for name in names if AVD_NAME.match(name)], None


def emulator_env(sdk_root: str | None = None) -> dict[str, str]:
    """The child environment for the emulator: ANDROID_SDK_ROOT and ANDROID_HOME both point at the SDK that owns the AVD.

    Without ANDROID_SDK_ROOT the emulator panics with "Cannot find AVD system path" (Sprint 60). The parent
    environment is not changed.
    """
    env = dict(os.environ)
    root = sdk_root or os.environ.get("ANDROID_HOME")
    if root:
        env["ANDROID_SDK_ROOT"] = root
        env["ANDROID_HOME"] = root
    return env


def launch_emulator(emulator: str, avd: str, cold_boot: bool = False, sdk_root: str | None = None,
                    minimized: bool = False):
    """Start the emulator detached and return the Popen. Raises OSError when it cannot start.

    minimized: open the window minimized (Windows only; build-with-secrets.py uses it).
    """
    argv = [emulator, "-avd", avd]
    if cold_boot:
        argv.append("-no-snapshot-load")
    kwargs = detached_kwargs()
    if minimized and os.name == "nt":
        info = subprocess.STARTUPINFO()
        info.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        info.wShowWindow = 6  # SW_MINIMIZE
        kwargs["startupinfo"] = info
    return subprocess.Popen(argv, env=emulator_env(sdk_root), **kwargs)


def wait_for_boot(adb: str, serial: str, seconds: int = 360, interval: float = 2.0) -> bool:
    """True once sys.boot_completed reads 1 on THIS emulator serial; False when the time runs out.

    The original polled `adb shell getprop` with no serial and ignored a failing adb, so a dead adb looked like a
    slow boot until the loop ended. Here a failing getprop is just "not booted yet" and the end result is explicit.
    """
    for _ in range(max(1, int(seconds / interval))):
        code, out = run_capture([adb, "-s", serial, "shell", "getprop", "sys.boot_completed"], timeout=30)
        if code == 0 and out.strip() == "1":
            return True
        sleep(interval)
    return False
