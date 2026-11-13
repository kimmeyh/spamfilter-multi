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
    return parser.parse_args(argv)


def select_files(root: Path, name_filter: str) -> list[Path]:
    """The *_test.dart files under root (any depth), sorted by full path ignoring case, then filtered."""
    files = sorted(root.rglob("*_test.dart"), key=lambda p: str(p).lower())
    if name_filter:
        pattern = f"*{name_filter.lower()}*"
        files = [f for f in files if fnmatch.fnmatchcase(f.name.lower(), pattern)]
    return files


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
    if not files:
        print("[WARNING] No integration_test *_test.dart files matched. Nothing to run.")
        return 0

    flutter = fs.find_flutter()
    if flutter is None:
        print("Error: flutter is not on PATH", file=sys.stderr)
        return 1

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
