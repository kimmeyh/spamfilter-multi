#!/usr/bin/env python3
"""Run the Flutter integration_test E2E suite, one flutter process per file (port of
run-integration-tests.ps1, F99 / F334, Sprint 85).

Why one process per file: the app's process-wide singletons (DatabaseHelper, the fire-and-forget
RuleSetProvider.initialize() tail) bleed across files in one `flutter test integration_test/` process.
Within a file, testWidgets share one process and reset through the harness (see docs/TESTING_STRATEGY.md).

Usage:
    python mobile-app/scripts/run-integration-tests.py                     # every *_test.dart under integration_test
    python mobile-app/scripts/run-integration-tests.py --test-name lifecycle  # files whose name contains "lifecycle"
    python mobile-app/scripts/run-integration-tests.py --name lifecycle       # same (original alias -Name)

    python mobile-app/scripts/run-integration-tests.py --android-emulator  # F359: android_*_test.dart on the emulator

--android-emulator starts the AVD (--avd, default pixel34_updated) through ANDROID_HOME when no emulator is online,
leaves it running, runs each android_*_test.dart with `-d <emulator serial> --flavor dev --reporter json`, and prints
one line per case. It exits 1 when a case fails, when no case passed, or when no emulator can be started. A phone is
never a target. The default run (no flag) never starts an emulator; it runs android_phone_paths_test.dart on the host
like any other file, where only the lock cases run and the Android-only cases are skipped.

The name filter is a case-insensitive "*name*" wildcard match on the file name (PowerShell -like semantics).
Full output of each file goes to one log (default mobile-app/build/test-logs/run-integration-tests-<stamp>.log).

Exit codes:
    0  every selected file passed, or no file matched (a warning is printed, as in the original)
    1  at least one file failed, integration_test was not found, or flutter is not installed
    2  invalid arguments (argparse)
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import flutter_support as fs  # noqa: E402


def parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run integration_test/*_test.dart, one flutter process per file.")
    parser.add_argument("--test-name", "--name", dest="test_name", default="",
                        help="only files whose name contains this text (case-insensitive wildcard match)")
    parser.add_argument("--log", metavar="PATH", help="write the full output here (default: build/test-logs)")
    parser.add_argument("--tail", type=int, default=30, help="lines of a failed file to print (default: 30)")
    parser.add_argument("--android-emulator", action="store_true",
                        help="F359: run only the Android phone-path file(s) (android_*_test.dart) on an emulator, "
                             "started through ANDROID_HOME when none runs and left running; per-case results")
    parser.add_argument("--avd", default="pixel34_updated", help="AVD to start for --android-emulator")
    return parser.parse_args(argv)


def select_files(root: Path, name_filter: str) -> list[Path]:
    """The *_test.dart files under root (any depth), sorted by full path ignoring case, then filtered."""
    files = sorted(root.rglob("*_test.dart"), key=lambda p: str(p).lower())
    if name_filter:
        pattern = f"*{name_filter.lower()}*"
        files = [f for f in files if fnmatch.fnmatchcase(f.name.lower(), pattern)]
    return files


def parse_case_results(text: str) -> list[tuple[str, str]]:
    """(case name, "passed" | "failed" | "skipped") for each test case in a `flutter test --reporter json` run.

    Reads the package:test JSON events (one object per line): testStart gives the name, testDone the result. Lines
    that are not JSON (build output) are ignored. A hidden loading pseudo-test is not a case. An empty list means no
    case ran, which the caller must NOT treat as a pass.
    """
    names: dict[int, str] = {}
    results: list[tuple[str, str]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if not isinstance(event, dict):
            continue
        if event.get("type") == "testStart":
            test = event.get("test") or {}
            names[test.get("id")] = test.get("name", "?")
        elif event.get("type") == "testDone" and not event.get("hidden"):
            name = names.get(event.get("testID"), "?")
            if event.get("skipped"):
                status = "skipped"
            elif event.get("result") == "success":
                status = "passed"
            else:
                status = "failed"
            results.append((name, status))
    return results


def failure_messages(text: str) -> list[str]:
    """First line of each `error` event and each print that names a failure, for the console (the log has all)."""
    out: list[str] = []
    for line in text.splitlines():
        if not line.startswith("{"):
            continue
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if isinstance(event, dict) and event.get("type") == "error":
            out.append(str(event.get("error", "")).strip().splitlines()[0][:300])
    return out


def run_on_emulator(args: argparse.Namespace, mobile: Path, files: list[Path]) -> int:
    """F359: run the Android phone-path files on an emulator. Starts one through ANDROID_HOME when none is running
    and LEAVES IT RUNNING. Returns 1 when any case fails, when no case passed, or when the emulator or flutter is
    missing (a run that checked nothing is not a pass).
    """
    flutter = fs.find_flutter()
    if flutter is None:
        print("Error: flutter is not on PATH", file=sys.stderr)
        return 1
    serial = ensure_android_emulator(args.avd)
    if not serial:
        print("[ERROR] No emulator is available. Nothing was run.")
        return 1
    print(f"Emulator: {serial} (left running when the run ends)")
    failed_cases: list[str] = []
    passed = skipped = 0
    full_log: list[str] = []
    for f in files:
        rel = f.relative_to(mobile).as_posix()
        print("------------------------------------------")
        print(f"[RUN] {f.name} on {serial}")
        code, text = fs.run_flutter(
            flutter, ["test", rel, "-d", serial, "--flavor", "dev", "--dart-define=APP_ENV=dev",
                      "--reporter", "json"], mobile)
        full_log.append(f"== flutter test {rel} -d {serial} (exit {code})\n{text}")
        cases = parse_case_results(text)
        for name, status in cases:
            print(f"  [{status.upper()}] {name}")
            if status == "passed":
                passed += 1
            elif status == "skipped":
                skipped += 1
            else:
                failed_cases.append(f"{f.name}: {name}")
        if code != 0:
            print(f"[FAIL] {f.name} (exit {code})")
            for message in failure_messages(text):
                print(f"  error: {message}")
            if not any(s == "failed" for _, s in cases):
                failed_cases.append(f"{f.name}: flutter exit {code} with no failed case")
                print(fs.tail(text, args.tail))
        elif not cases:
            failed_cases.append(f"{f.name}: no case ran")
            print(f"[FAIL] {f.name}: flutter exited 0 but no case ran")
    log_path = Path(args.log) if args.log else fs.default_log_path("run-integration-tests-android")
    fs.write_log(log_path, "\n".join(full_log))
    print("")
    print(f"Android emulator summary: passed {passed}, skipped {skipped}, failed {len(failed_cases)}")
    for item in failed_cases:
        print(f"  - {item}")
    print(f"Full output: {log_path}")
    if failed_cases or passed == 0:
        if not failed_cases:
            print("[FAIL] no case passed")
        return 1
    print("[OK] all Android emulator cases passed.")
    return 0


def ensure_android_emulator(avd: str) -> str | None:
    """Serial of an online, booted emulator, starting the AVD through ANDROID_HOME when none is online.

    Reuses run-emulator.py (F336): adb and the emulator come from ANDROID_HOME first, adb only targets an
    emulator serial, never a phone. None after a reported failure.
    """
    import importlib.util

    spec = importlib.util.spec_from_file_location("run_emulator_mod", Path(__file__).resolve().parent / "run-emulator.py")
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    adb = mod.sup.find_adb()
    if not adb:
        print("[ERROR] adb not found. Set ANDROID_HOME to the Android SDK folder.")
        return None
    serial = mod.ensure_emulator(adb, mod.sup.find_emulator(), avd)
    if not serial:
        return None
    if not mod.sup.wait_for_boot(adb, serial, seconds=mod.BOOT_SECONDS):
        print(f"[ERROR] {serial} did not finish booting in {mod.BOOT_SECONDS} s.")
        return None
    return serial


def main(argv: list[str] | None = None) -> int:
    fs.common.configure_stdio()
    args = parse_args(argv)
    mobile = fs.MOBILE_APP
    it_dir = mobile / "integration_test"
    if not it_dir.is_dir():
        print(f"integration_test directory not found at {it_dir}", file=sys.stderr)
        return 1

    print("==========================================")
    print("Flutter integration_test E2E suite (F99)")
    print("==========================================")
    print(f"App dir: {mobile}")
    print("Isolation: per-test temp DB (dev DB never touched)")
    print("")

    files = select_files(it_dir, args.test_name)
    if args.android_emulator:
        files = [f for f in files if f.name.startswith("android_")]
    if not files:
        # Sprint 85 7.7.1 L6: a run that checked nothing is not a pass (a misspelled --name used to exit 0).
        print("[ERROR] No integration_test *_test.dart files matched. Nothing was run.")
        return 1

    flutter = fs.find_flutter()
    if flutter is None:
        print("Error: flutter is not on PATH", file=sys.stderr)
        return 1

    if args.android_emulator:
        return run_on_emulator(args, mobile, files)

    print(f"Running {len(files)} integration_test file(s), one process each:")
    for f in files:
        print(f"  {f.name}")
    print("")

    failed: list[str] = []
    full_log: list[str] = []
    for f in files:
        rel = f.relative_to(mobile).as_posix()
        print("------------------------------------------")
        print(f"[RUN] {f.name}")
        code, text = fs.run_flutter(flutter, ["test", rel], mobile)
        full_log.append(f"== flutter test {rel} (exit {code})\n{text}")
        if code != 0:
            failed.append(f.name)
            print(f"[FAIL] {f.name} (exit {code})")
            print(fs.tail(text, args.tail))
        else:
            print(f"[PASS] {f.name}")

    log_path = Path(args.log) if args.log else fs.default_log_path("run-integration-tests")
    fs.write_log(log_path, "\n".join(full_log))

    print("")
    print("==========================================")
    print("integration_test summary")
    print("==========================================")
    print(f"Total files: {len(files)}")
    print(f"Passed: {len(files) - len(failed)}")
    print(f"Failed: {len(failed)}")
    for name in failed:
        print(f"  - {name}")
    print(f"Full output: {log_path}")
    if failed:
        return 1
    print("[OK] all integration_test files passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
