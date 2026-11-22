#!/usr/bin/env python3
"""Run the mobile-app Flutter test suite (port of run-tests.ps1, F334, Sprint 85).

Usage (from any folder; paths resolve from this script):
    python mobile-app/scripts/run-tests.py                       # all: each phase 1 and phase 2 file
    python mobile-app/scripts/run-tests.py --type unit           # flutter test test/unit/
    python mobile-app/scripts/run-tests.py --type coverage       # flutter test --coverage
    python mobile-app/scripts/run-tests.py --file test/unit/storage/app_paths_data_dir_test.dart
    python mobile-app/scripts/run-tests.py --type phase1 -v      # adds flutter's global --verbose
    python mobile-app/scripts/run-tests.py --log C:\\tmp\\run.log  # full output location

Types (the original -TestType values): all, phase1, phase2, unit, integration, coverage.
--file runs one test file and reports its pass count (pub get and analyze are skipped in that mode;
flutter test resolves dependencies by itself).

Full output of every flutter call goes to a log file (default mobile-app/build/test-logs/run-tests-<stamp>.log).
The console shows the per-run counts and the last --tail lines of each run.

Exit codes:
    0  every test run passed (analyze findings are printed as a warning and do not fail the run)
    1  a test run failed, flutter pub get failed, mobile-app was not found, or flutter is not installed
    2  invalid arguments (argparse)
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import flutter_support as fs  # noqa: E402

PHASE1 = [
    "test/unit/pattern_compiler_test.dart",
    "test/unit/safe_sender_list_test.dart",
    "test/integration/yaml_loading_test.dart",
    "test/integration/end_to_end_workflow_test.dart",
]
PHASE2 = [
    "test/unit/app_paths_test.dart",
    "test/unit/secure_credentials_store_test.dart",
    "test/unit/email_scan_provider_test.dart",
]
TYPES = ("all", "phase1", "phase2", "unit", "integration", "coverage")


def parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the mobile-app Flutter test suite.")
    parser.add_argument("--type", choices=TYPES, default="all", help="which tests to run (default: all)")
    parser.add_argument("--file", metavar="PATH", help="run one test file, relative to mobile-app")
    parser.add_argument("-v", "--verbose", action="store_true", help="pass flutter's global --verbose flag")
    parser.add_argument("--log", metavar="PATH", help="write the full output here (default: build/test-logs)")
    parser.add_argument("--tail", type=int, default=40, help="lines of each run to print (default: 40)")
    return parser.parse_args(argv)


def runs_for(args: argparse.Namespace) -> list[tuple[str, list[str]]]:
    """(label, flutter test arguments) for each run, in the original script's order."""
    if args.file:
        return [(args.file, ["test", args.file])]
    if args.type == "all":
        return [(path, ["test", path]) for path in PHASE1 + PHASE2]
    if args.type == "phase1":
        return [(path, ["test", path]) for path in PHASE1]
    if args.type == "phase2":
        return [(path, ["test", path]) for path in PHASE2]
    if args.type == "unit":
        return [("test/unit/", ["test", "test/unit/"])]
    if args.type == "integration":
        return [("test/integration/", ["test", "test/integration/"])]
    return [("coverage", ["test", "--coverage"])]


def main(argv: list[str] | None = None) -> int:
    fs.common.configure_stdio()
    args = parse_args(argv)
    mobile = fs.MOBILE_APP
    if not mobile.is_dir():
        print("Error: mobile-app directory not found", file=sys.stderr)
        return 1
    flutter = fs.find_flutter()
    if flutter is None:
        print("Error: flutter is not on PATH", file=sys.stderr)
        return 1
    log_path = Path(args.log) if args.log else fs.default_log_path("run-tests")
    prefix = ["--verbose"] if args.verbose else []

    full_log: list[str] = []
    if not args.file:
        print("Checking dependencies (flutter pub get)...")
        code, text = fs.run_flutter(flutter, ["pub", "get"], mobile)
        full_log.append(f"== flutter pub get (exit {code})\n{text}")
        if code != 0:
            print(fs.tail(text, args.tail))
            fs.write_log(log_path, "\n".join(full_log))
            print(f"Full output: {log_path}")
            return 1
        print("Running code analysis (flutter analyze)...")
        code, text = fs.run_flutter(flutter, ["analyze"], mobile)
        full_log.append(f"== flutter analyze (exit {code})\n{text}")
        if code != 0:
            print("[WARNING] flutter analyze reported issues (see the log)")

    results: list[tuple[str, int, tuple[int, int, int] | None]] = []
    for label, flutter_args in runs_for(args):
        print(f"[RUN] {label}")
        code, text = fs.run_flutter(flutter, prefix + flutter_args, mobile)
        full_log.append(f"== flutter {' '.join(prefix + flutter_args)} (exit {code})\n{text}")
        counts = fs.parse_counts(text)
        results.append((label, code, counts))
        if counts is None:
            verdict = "no summary line"
        else:
            verdict = f"passed {counts[0]}, skipped {counts[1]}, failed {counts[2]}"
        print(f"  exit {code}: {verdict}")
        if code != 0:
            print(fs.tail(text, args.tail))

    fs.write_log(log_path, "\n".join(full_log))
    print(f"Full output: {log_path}")

    total = [c for _, _, c in results if c is not None]
    print("")
    print("Summary: " + ", ".join(
        f"{label} {'ok' if code == 0 else 'FAILED'}" for label, code, _ in results))
    if total:
        print(f"Totals: passed {sum(c[0] for c in total)}, skipped {sum(c[1] for c in total)}, "
              f"failed {sum(c[2] for c in total)}")
    return 0 if all(code == 0 for _, code, _ in results) else 1


if __name__ == "__main__":
    sys.exit(main())
