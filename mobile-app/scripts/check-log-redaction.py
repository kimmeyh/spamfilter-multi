"""Logging-redaction enforcement gate (F102 Sprint 43, narrowed by F110; Python port F333 Sprint 85).

Fails (exit 1) when a log call in lib/ interpolates a raw SENSITIVE identifier (account id, token or
secret) without a Redact.* wrapper. This is the narrowed ADR-0030 "Logging & Redaction" invariant as an
automated check, so a new leak is caught at author or CI time and not at code review.

Narrowed rule (F110, Harold 2026-06-25): the invariant protects the app user's OWN identity, not
arbitrary correspondents.
  - Account ids stay strict ($accountId, $bgAccountId, $_backgroundAccountId, bare $account).
  - Tokens and secrets stay strict ($token, $accessToken, $refreshToken, $appPassword, $clientSecret).
  - Sender and recipient email addresses are allowed in the clear (a spammer's address IS the signal).
    The user's own address is masked at the call site with Redact.senderForLog.

Scope: lib/**/*.dart. Log sinks matched: _logger.i/d/w/e(...), Logger().i/d/w/e(...), and the headless
file logs _bgLog(...) and bgLog(...). A line is a violation when it is a log call that contains a raw
sensitive interpolation and does not contain "Redact." (redaction is applied inline).

Mirrors mobile-app/test/policy/log_redaction_test.dart. The regexes are the same text. One known
difference, kept from the PowerShell original: this script matches case-insensitively (PowerShell
-match), the Dart test matches case-sensitively.

Usage:
    python mobile-app/scripts/check-log-redaction.py                 scan lib/, exit 1 on a violation
    python mobile-app/scripts/check-log-redaction.py --self-test     offline self-test, no repo scan
    python mobile-app/scripts/check-log-redaction.py --lib-dir DIR   scan another folder (tests)

Exit codes:
    0  no violation (or all self-test cases passed)
    1  one or more violations, a failed self-test case, or the lib folder is missing
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent

# A log-sink call on the line.
LOG_CALL_RE = re.compile(
    r"(_logger\.(i|d|w|e)|Logger\(\)\.(i|d|w|e)|_bgLog|[^A-Za-z]bgLog)\s*\(", re.IGNORECASE)

# Raw SENSITIVE identifier interpolations. Negative lookaheads keep $accountIds (list) and
# $accountCount from matching. (?: ) groups are used so the alternation stays anchored by \b.
PII_RE = re.compile(
    r"\$\{?(accountId(?!s)|bgAccountId|_backgroundAccountId|account(?!Id|Ids|Count|s\b)"
    r"|accessToken|refreshToken|token|appPassword|clientSecret)\b", re.IGNORECASE)

LINE_SPLIT = re.compile(r"\r\n|\r|\n")  # same line breaks as .NET ReadAllLines

SELF_TEST_CASES = [
    ("_logger.i(for account $accountId)", True, "raw accountId in logger"),
    ("await _bgLog(account $accountId missing)", True, "raw accountId in bgLog"),
    ("_logger.w(token=$accessToken)", True, "raw token in logger"),
    ("_logger.d(x $emailAddress y)", False, "sender email now allowed (F110)"),
    ("await _bgLog(Phishing: $fromEmail failed)", False, "sender fromEmail now allowed (F110)"),
    ("await _bgLog(${Redact.senderForLog(from, u)})", False, "senderForLog ok"),
    ("_logger.i(${Redact.accountId(accountId)})", False, "redacted accountId ok"),
    ("_logger.d(Deleted email $emailId)", False, "emailId row id ok"),
    ("_logger.i(scans=$scans emails=$emails)", False, "counts ok"),
    ("final accountId = $accountId;", False, "not a log call ok"),
]


def is_violation(line: str) -> bool:
    """True when the line is a log call with a raw sensitive interpolation and no Redact."""
    if not LOG_CALL_RE.search(line):
        return False
    if re.search("Redact\\.", line, re.IGNORECASE):
        return False
    return bool(PII_RE.search(line))


def find_violations(lib_dir: Path) -> list[tuple[Path, int, str]]:
    """Scan every *.dart file under lib_dir. Returns (file, line number, stripped text) tuples."""
    found: list[tuple[Path, int, str]] = []
    for path in sorted(lib_dir.rglob("*.dart"), key=lambda p: str(p).lower()):
        if not path.is_file():
            continue
        text = path.read_bytes().decode("utf-8-sig", errors="replace")
        for number, line in enumerate(LINE_SPLIT.split(text), start=1):
            if is_violation(line):
                found.append((path, number, line.strip()))
    return found


def run_self_test() -> int:
    print("[SELF-TEST] check-log-redaction.py")
    passed = True
    for line, expect, name in SELF_TEST_CASES:
        ok = is_violation(line) == expect
        passed = passed and ok
        print("  [%s] %s" % ("PASS" if ok else "FAIL", name))
    if passed:
        print("[SELF-TEST] ALL PASSED")
        return 0
    print("[SELF-TEST] FAILURES")
    return 1


def main(argv: list[str] | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    parser = argparse.ArgumentParser(description="Logging-redaction enforcement gate (ADR-0030, F102).")
    parser.add_argument("--self-test", action="store_true", help="run the offline self-test and exit")
    parser.add_argument("--lib-dir", type=Path, default=SCRIPT_DIR.parent / "lib",
                        help="folder to scan (default: mobile-app/lib)")
    args = parser.parse_args(argv)

    if args.self_test:
        return run_self_test()

    if not args.lib_dir.is_dir():
        print("[FAIL] lib folder not found: %s" % args.lib_dir)
        return 1
    violations = find_violations(args.lib_dir)
    if violations:
        print("[FAIL] Logging-redaction violations (ADR-0030 'Logging & Redaction', F102):")
        for path, number, text in violations:
            print("  %s:%d" % (path, number))
            print("    %s" % text)
        print("")
        print("Wrap the identifier with Redact.accountId()/Redact.email()/Redact.token() "
              "(mobile-app/lib/util/redact.dart).")
        return 1
    print("[OK] No logging-redaction violations found.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
