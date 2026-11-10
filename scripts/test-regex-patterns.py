"""Test a regex pattern against sample strings before it goes into a rule file (F330, Sprint 85).

Port of test-regex-patterns.ps1. Checks that the pattern compiles (case-insensitive, as the app applies
rules), warns about known catastrophic-backtracking shapes, optionally times the pattern, and reports
which test strings match (an unanchored search, as the original `Match` did).

The pattern is compiled with Python `re` through scripts/regex_dialect.py (the .NET-to-Python
differences are listed there). The app runs rules with Dart RegExp, so a pass here is a syntax and
behavior check, not proof. No engine offers a timeout, so a truly catastrophic pattern can hang the
timing run; press Ctrl+C.

Usage:
    python scripts/test-regex-patterns.py --pattern "^user@example\\.com$" --test-string user@example.com
    python scripts/test-regex-patterns.py --pattern "..." --file test-emails.txt [--show-matches]
    python scripts/test-regex-patterns.py --pattern "..." --performance-test
A pattern that starts with "-" must be written --pattern=-x. With no --test-string and no --file, test
strings are read from standard input, one per line; a blank line or end of input finishes.

Exit codes: 0 done (also when nothing matched, and when no test string was given); 1 invalid pattern or
missing --file; 3 the pattern uses a construct this tool cannot translate (not a syntax error).
"""
from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import common  # noqa: E402
import regex_dialect  # noqa: E402

RULE = "=" * 80
PERF_STRINGS = [
    "user@example.com",
    "John Doe <user@example.com>",
    "noreply@mail.example.com",
    "This is a very long email subject with lots of text to test performance issues",
    "urgent: please respond immediately to this email about your account",
]
ITERATIONS = 1000


def yaml_single(text: str) -> str:
    """A YAML single-quoted scalar (the repository's export style): quotes doubled."""
    return "'" + text.replace("'", "''") + "'"


def performance_test(regex) -> float:
    """Average milliseconds per match over PERF_STRINGS x ITERATIONS."""
    total = 0.0
    for text in PERF_STRINGS:
        started = time.perf_counter()
        for _ in range(ITERATIONS):
            regex.search(text)
        total += time.perf_counter() - started
    return total * 1000 / (len(PERF_STRINGS) * ITERATIONS)


def read_stdin_strings() -> list[str]:
    print("  Enter test strings (one per line, blank line to finish):")
    strings: list[str] = []
    while True:
        try:
            line = input("  Test string: ")
        except EOFError:
            break
        if not line.strip():
            break
        strings.append(line)
    return strings


def main(argv: list[str] | None = None) -> int:
    common.configure_stdio()
    parser = argparse.ArgumentParser(description="Test a regex pattern against sample strings.")
    parser.add_argument("--pattern", required=True, help="regex pattern to test")
    parser.add_argument("--test-string", default="", help="one string to test the pattern against")
    parser.add_argument("--file", default="", help="file of test strings, one per line")
    parser.add_argument("--show-matches", action="store_true", help="print capture groups of each match")
    parser.add_argument("--performance-test", action="store_true", help="time the pattern (1000 matches per sample)")
    args = parser.parse_args(argv)
    pattern = args.pattern
    steps = 4 if args.performance_test else 3

    print(RULE)
    print("Regex Pattern Tester")
    print(RULE)
    print()
    print(f"[1/{steps}] Validating regex pattern...")
    print(f"Pattern: {pattern}")
    print()
    try:
        regex, notes = regex_dialect.compile_net(pattern)
    except regex_dialect.NotChecked as exc:
        print(f"  [NOT CHECKED] Pattern cannot be tested here: {exc}")
        return 3
    except regex_dialect.RegexSyntaxError as exc:
        print(f"  [ERROR] Invalid regex pattern: {exc}")
        return 1
    print("  [OK] Pattern is valid")
    for note in notes:
        print(f"  [WARNING] {note}")

    print(f"[2/{steps}] Checking for performance issues...")
    found = regex_dialect.performance_warnings(pattern)
    for text in found:
        print(f"  [WARNING] {text}")
    if not found:
        print("  [OK] No obvious performance issues detected")
    print()

    if args.performance_test:
        print(f"[3/{steps}] Running performance test ({ITERATIONS} iterations)...")
        average = performance_test(regex)
        print(f"  Average time per match: {round(average, 4)} ms")
        if average > 1:
            print("  [WARNING] Pattern is slow (>1ms per match)")
            print("  This may cause performance issues with large email volumes")
        elif average > 0.1:
            print("  [OK] Pattern performance is acceptable")
        else:
            print("  [OK] Pattern is fast")
        print()

    print(f"[{steps}/{steps}] Testing pattern matches...")
    if args.file:
        path = Path(args.file)
        if not path.exists():
            print(f"  [ERROR] File not found: {args.file}")
            return 1
        strings = path.read_bytes().decode("utf-8-sig", errors="replace").splitlines()
        print(f"  Loaded {len(strings)} test strings from {args.file}")
    elif args.test_string:
        strings = [args.test_string]
    else:
        strings = read_stdin_strings()
    if not strings:
        print("  [WARNING] No test strings provided")
        return 0

    print()
    print(f"Testing {len(strings)} string(s):")
    print()
    matched = 0
    for text in strings:
        match = regex.search(text)
        if match:
            matched += 1
            print(f"  [MATCH] {text}")
            if args.show_matches and regex.groups > 0:
                print("    Capture groups:")
                for number, value in enumerate(match.groups(), start=1):
                    print(f"      Group {number}: {'' if value is None else value}")
        else:
            print(f"  [NO MATCH] {text}")

    print()
    print(RULE)
    print(f"Summary: {matched} of {len(strings)} strings matched")
    print(RULE)
    print()
    print("Usage Suggestions:")
    print()
    print("Add to rules.yaml:")
    print("  - name: 'MyRule'")
    print("    conditions:")
    print("      type: 'OR'")
    print("      header:")
    print(f"      - {yaml_single(pattern)}")
    print()
    print("Add to rules_safe_senders.yaml:")
    print("  'safe_senders':")
    print(f"  - {yaml_single(pattern)}")
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
