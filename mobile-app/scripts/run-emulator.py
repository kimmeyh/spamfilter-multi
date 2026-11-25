"""Start the Android emulator if none is running, then install a release APK or run the app (F336, Sprint 86; Python
port of run-emulator.ps1).

Usage:
  python run-emulator.py                        start an emulator if needed, then `flutter run` on it (debug)
  python run-emulator.py --install-release-apk  install the built release APK and start the app
  python run-emulator.py --apk PATH             the APK to install (default build/app/outputs/flutter-apk/app-dev-release.apk)
  python run-emulator.py --avd NAME             AVD to start when none is running (default pixel34_updated)
  python run-emulator.py --package-id ID        app id to start after the install (default com.myemailspamfilter.dev)
  python run-emulator.py --project-path PATH    the Flutter project (default: mobile-app)

For the usual flow (build with secrets, install, start) use build-with-secrets.py --install-to-emulator. This script is
for putting an ALREADY BUILT APK on the emulator, or for `flutter run` against it.

Defects found in the PowerShell original, and what the port does:
  - adb and flutter came from the PATH, which on this machine can select the older SDK: FIXED, adb and the emulator come
    from ANDROID_HOME first (android_support.sdk_tool).
  - `adb kill-server` on every run stopped the adb other tools were using: FIXED, only `adb start-server` runs.
  - `adb wait-for-device` and `getprop` with no serial: FIXED, every adb call after detection uses `-s <emulator serial>`,
    so a plugged-in phone is never a target (company policy blocks USB debugging on the phones).
  - `flutter emulators --launch pixel34`: the default id was a stale AVD name. FIXED, the AVD is launched through
    emulator.exe, default pixel34_updated (the validated AVD, same as start-emulator.py), and is checked against
    `emulator -list-avds`.
  - The package id com.example.spamfilter_mobile and apk name app-release.apk were from before the flavors (Sprint 37+):
    FIXED, defaults are the dev flavor id and app-dev-release.apk (build-with-secrets.py artifact_path); both are options.
  - A failed install printed a warning and returned exit 0, and its logcat filter used -SimpleMatch with a "|" pattern that
    matches nothing: FIXED, exit 1, and the filter is a real regular expression over the last logcat lines.
  - `flutter run --no-build-macos` is a macOS flag and has no meaning here: DROPPED. `flutter run -d <serial>` targets the emulator.
  - A boot that never finished only printed a warning: FIXED, it is an exit 1.

Exit codes: 0 done; 1 a missing tool, an unknown AVD, no emulator, a boot timeout, a failed install or app start; flutter's
own exit code when `flutter run` fails; 2 a usage error (argparse).

What this does NOT catch: an app that installs and starts but crashes at once (look at the emulator or `adb logcat`), a
stale APK (the script installs the file it is given), and a hung `flutter run` (it streams until you stop it).
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import android_support as sup  # noqa: E402

DEFAULT_AVD = "pixel34_updated"
DEFAULT_PACKAGE = "com.myemailspamfilter.dev"
DEFAULT_APK = "build/app/outputs/flutter-apk/app-dev-release.apk"
LOG_PATTERN = re.compile(r"ActivityManager|AndroidRuntime|E/flutter|FATAL|Exception")
BOOT_SECONDS = 360
APPEAR_SECONDS = 120


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Start the emulator if needed, then install an APK or flutter run.")
    parser.add_argument("--project-path", default=str(sup.MOBILE_APP))
    parser.add_argument("--avd", default=DEFAULT_AVD)
    parser.add_argument("--install-release-apk", action="store_true")
    parser.add_argument("--apk", default=None, help=f"APK to install (default {DEFAULT_APK} under the project)")
    parser.add_argument("--package-id", default=DEFAULT_PACKAGE)
    return parser.parse_args(argv)


def ensure_emulator(adb: str, emulator: str | None, avd: str) -> str | None:
    """The serial of an online emulator, starting one when none is online. None after a reported failure."""
    sup.say("[adb] Starting the adb server (an adb already running is left alone)...")
    sup.run_capture([adb, "start-server"], timeout=60)
    serials, error = sup.online_emulators(adb)
    if error:
        sup.say(f"[ERROR] {error}")
        return None
    if serials:
        sup.say(f"[emulator] Using the running emulator {serials[0]}")
        return serials[0]
    if not emulator:
        sup.say("[ERROR] No emulator is running and the emulator tool was not found. Set ANDROID_HOME to the Android SDK folder.")
        return None
    avds, error = sup.list_avds(emulator)
    if error:
        sup.say(f"[ERROR] {error}")
        return None
    if avd not in avds:
        sup.say(f"[ERROR] AVD '{avd}' not found. Available: {', '.join(avds) if avds else '(none)'}")
        return None
    sup.say(f"[emulator] Launching AVD '{avd}' ...")
    try:
        proc = sup.launch_emulator(emulator, avd)
    except OSError as exc:
        sup.say(f"[ERROR] could not start the emulator: {exc}")
        return None
    adb_error_shown = False
    for tick in range(APPEAR_SECONDS // 2):
        sup.sleep(2)
        serials, error = sup.online_emulators(adb)
        if serials:
            return serials[0]
        exited = sup.emulator_exit_report(proc)
        if exited:  # Sprint 86 7.7.1 M6: stop at once with the cause, not after the full wait
            sup.say(f"[ERROR] {exited}")
            return None
        if error and not adb_error_shown:  # 7.7.1 L10: a failing adb is not "no emulator yet"
            sup.say(f"[WARNING] adb devices failed: {error}")
            adb_error_shown = True
        if tick % 5 == 0:
            sup.say(f"  Still waiting for the emulator... ({tick * 2}s)")
    sup.say(f"[ERROR] The emulator did not appear in adb within {APPEAR_SECONDS} s.")
    return None


def install_and_start(adb: str, serial: str, apk: Path, package: str) -> int:
    sup.say(f"[adb] Installing {apk}")
    code, out = sup.run_capture([adb, "-s", serial, "install", "-r", str(apk)], timeout=600)
    sup.say(out.strip())
    if code != 0 or "Success" not in out:
        sup.say(f"[ERROR] APK install failed (exit {code}). Recent logcat lines of interest:")
        _, log = sup.run_capture([adb, "-s", serial, "logcat", "-d", "-t", "400"], timeout=60)
        for line in [ln for ln in log.splitlines() if LOG_PATTERN.search(ln)][-30:]:
            sup.say("  " + line)
        return 1
    sup.say(f"[adb] Starting the app ({package})...")
    code, out = sup.run_capture([adb, "-s", serial, "shell", "monkey", "-p", package,
                                 "-c", "android.intent.category.LAUNCHER", "1"], timeout=60)
    sup.say(out.strip())
    if code != 0 or "No activities found" in out or "monkey aborted" in out:
        sup.say(f"[ERROR] The app did not start (exit {code}). Is the package id '{package}' the installed flavor?")
        return 1
    return 0


def flutter_run_argv(flutter: str, serial: str) -> list[str]:
    """`flutter run` for the DEV flavor. android/app/build.gradle.kts defines flavors dev and prod and pubspec.yaml has no
    default-flavor, so a run without --flavor has no variant to pick (C1-3, Sprint 86 5.1.2). The flag pair mirrors
    run-integration-tests.py and build-with-secrets.py flavor_args. No secrets are injected (as in run-integration-tests.py):
    the app has no ANDROID_GMAIL_CLIENT_ID, so Gmail sign-in is off; use build-with-secrets.py --run for a credentialed run."""
    return [flutter, "run", "--no-pub", "-d", serial, "--flavor", "dev", "--dart-define=APP_ENV=dev"]


def main(argv: list[str] | None = None) -> int:
    sup.common.configure_stdio()
    args = parse_args(argv)
    adb = sup.find_adb()
    if not adb:
        sup.say("[ERROR] adb not found. Set ANDROID_HOME to the Android SDK folder.")
        return 1
    project = Path(args.project_path)
    serial = ensure_emulator(adb, sup.find_emulator(), args.avd)
    if not serial:
        return 1
    sup.say(f"[emulator] Waiting for boot to complete on {serial}...")
    if not sup.wait_for_boot(adb, serial, seconds=BOOT_SECONDS):
        sup.say(f"[ERROR] {serial} did not finish booting in {BOOT_SECONDS} s.")
        return 1
    sup.say("[emulator] Boot complete.")
    sup.say(f"Project: {project}")

    flutter_run = flutter_run_argv(str(Path(sup.common.find_tool("flutter") or "flutter")), serial)
    if args.install_release_apk:
        apk = Path(args.apk) if args.apk else project / DEFAULT_APK
        if apk.is_file():
            return install_and_start(adb, serial, apk, args.package_id)
        sup.say(f"[WARNING] APK not found at {apk}. Running a debug build with flutter run instead.")
    return sup.run_inherit(flutter_run, cwd=project)


if __name__ == "__main__":
    sys.exit(main())
