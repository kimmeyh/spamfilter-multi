"""Read or set the Windows screen reader system flag so Flutter builds its semantics tree (F336, Sprint 86; Python port of
enable-screen-reader-flag.ps1).

Usage:
  python enable-screen-reader-flag.py status    print "Screen reader flag: True" or "False"
  python enable-screen-reader-flag.py enable    set the flag (the default action), then read it back
  python enable-screen-reader-flag.py disable   clear the flag, then read it back

This sets SPI_SETSCREENREADER through SystemParametersInfoW. It does NOT start a screen reader. WinWright needs the flag on
before it can read the Flutter UI tree (docs/WINWRIGHT_SELECTORS.md; run-winwright-tests.ps1 calls "enable" first).

Decision: ported, not left in PowerShell. The original compiled a C# class with Add-Type on every run only to call one
user32 function. Python reaches the same function through ctypes with no compile step, and the call can be tested.

Defects found in the PowerShell original, and what the port does:
  - The return value of SystemParametersInfo was ignored inside IsEnabled, so a failed read looked like "False": FIXED, a
    failed call raises, and the script prints the Win32 error and exits 1.
  - `enable` printed the return value but still ended with exit 0 when the flag did not turn on: FIXED, exit 1 when the flag
    read back after "enable" is not True (or after "disable" is not False).
  - An unknown action did nothing and exited 0: FIXED, argparse rejects it (exit 2).
  - `disable` printed "Screen reader flag disabled: <current value>", which read as "disabled: True" while enabled: the text is
    now "Screen reader flag after disable: <value>".
  - A native memory block (AllocHGlobal) held the read result: replaced by a ctypes int, nothing to free.
  - Windows only: on another OS the script exits 1 with a message.

Exit codes: 0 done; 1 the flag did not reach the requested state, a Win32 call failed, or the OS is not Windows; 2 a usage
error (argparse).

What this does NOT catch: whether a given app reacted to the flag (a running Flutter app may need a restart or a moment, which
is why the WinWright runner waits 2 s after "enable"), and a locked workstation (the flag still sets; the runner checks the
lock separately).
"""
from __future__ import annotations

import argparse
import ctypes
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import android_support as sup  # noqa: E402

SPI_GETSCREENREADER = 0x0046
SPI_SETSCREENREADER = 0x0047
SPIF_SENDCHANGE = 0x0002


def load_user32():
    """user32 with a typed SystemParametersInfoW, or raises OSError when it is not Windows."""
    if os.name != "nt":
        raise OSError("the screen reader flag exists only on Windows")
    user32 = ctypes.WinDLL("user32", use_last_error=True)
    user32.SystemParametersInfoW.argtypes = [ctypes.c_uint, ctypes.c_uint, ctypes.c_void_p, ctypes.c_uint]
    user32.SystemParametersInfoW.restype = ctypes.c_bool
    return user32


def spi(user32, action: int, param: int, pointer, flags: int) -> None:
    """Call SystemParametersInfoW and raise OSError with the Win32 error when it returns FALSE."""
    if not user32.SystemParametersInfoW(action, param, pointer, flags):
        raise ctypes.WinError(ctypes.get_last_error())


def is_enabled(user32) -> bool:
    value = ctypes.c_int(0)
    spi(user32, SPI_GETSCREENREADER, 0, ctypes.byref(value), 0)
    return value.value != 0


def set_enabled(user32, on: bool) -> None:
    spi(user32, SPI_SETSCREENREADER, 1 if on else 0, None, SPIF_SENDCHANGE)


def run(action: str, user32=None) -> int:
    try:
        user32 = user32 or load_user32()
        if action == "status":
            sup.say(f"Screen reader flag: {is_enabled(user32)}")
            return 0
        if action == "enable":
            sup.say(f"Before: {is_enabled(user32)}")
            set_enabled(user32, True)
            sup.sleep(1)
            after = is_enabled(user32)
            sup.say(f"After: {after}")
            return 0 if after else 1
        set_enabled(user32, False)
        sup.sleep(1)
        after = is_enabled(user32)
        sup.say(f"Screen reader flag after disable: {after}")
        return 1 if after else 0
    except OSError as exc:
        sup.say(f"[ERROR] {exc}")
        return 1


def main(argv: list[str] | None = None) -> int:
    sup.common.configure_stdio()
    parser = argparse.ArgumentParser(description="Read or set the Windows screen reader system flag.")
    parser.add_argument("action", nargs="?", choices=("status", "enable", "disable"), default="enable")
    return run(parser.parse_args(argv).action)


if __name__ == "__main__":
    sys.exit(main())
