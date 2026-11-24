"""Run the mobile-app quality gate: `flutter analyze` then `flutter test`, one verdict (F344, Sprint 86).

Seven prompts used to spell this step out in prose, each with its own stale test count ("138+ tests"):
.claude/agents/build-validator.md, verify-app.md, oncall-guide.md and .claude/commands/commit-push-pr.md,
quick-commit.md, review-changes.md, test-and-fix.md. They now run this script, so the pass rule is written once:
    analyze  PASS only when flutter exits 0 AND prints "No issues found!" (or "0 issues"). Any issue, info
             level included, fails: the prompts say "must report 0 issues".
    tests    PASS only when flutter exits 0, a summary line was printed, at least one test passed and none failed.
             No summary line (a compile error before any test started) is a FAIL, never "0 failures".

Usage (from any folder; paths resolve from this script):
    python scripts/quality-gate.py                       # analyze, then the whole suite
    python scripts/quality-gate.py --skip-tests          # analyze only
    python scripts/quality-gate.py --skip-analyze        # tests only
    python scripts/quality-gate.py --test-file test/unit/rule_evaluator_test.dart     # one test file
    python scripts/quality-gate.py --log C:\\tmp\\gate.log --tail 60

Full output of every flutter call goes to a log file (default mobile-app/build/test-logs/quality-gate-<stamp>.log,
CLAUDE.md: persist in full, trim on read); the console shows the verdict lines and the last --tail lines of a
failed step. The last console line is `RESULT: PASS` or `RESULT: FAIL (<which steps>)`.

Exit codes: 0 every step that ran passed; 1 a step failed or printed no summary; 2 this script could not run
(flutter not installed, mobile-app folder missing, both steps skipped, bad arguments).

What this does NOT catch: a hung test run (there is no stall timer; use scripts/run-full-suite.py for the full
suite when a run may hang); a flaky test that passes this time; analyzer output in a format other than the two
summary shapes above (that is reported as "no summary", a FAIL, not guessed at); platform builds (this script
never builds Windows or Android; use build-windows.ps1 and build-with-secrets.py for that).
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS.parent / "mobile-app" / "scripts"))
import flutter_support as fs  # noqa: E402

ANALYZE_CLEAN = re.compile(r"No issues found!|^\s*0 issues? found", re.M | re.I)
ANALYZE_ISSUES = re.compile(r"^\s*(\d+) issues? found", re.M | re.I)


def judge_analyze(code: int, text: str) -> tuple[bool, str]:
    """(passed, one-line detail) for a `flutter analyze` run."""
    found = ANALYZE_ISSUES.search(text)
    if found and int(found.group(1)) > 0:
        return False, f"{found.group(1)} issue(s) found"
    if ANALYZE_CLEAN.search(text):
        if code != 0:
            return False, f"printed no issues but exited {code}"
        return True, "0 issues"
    return False, f"no summary line (exit {code}); the analyzer did not finish"


def judge_tests(code: int, text: str) -> tuple[bool, str]:
    """(passed, one-line detail) for a `flutter test` run."""
    counts = fs.parse_counts(text)
    if counts is None:
        return False, f"no summary line (exit {code}); no test ran, for example a compile error"
    passed, skipped, failed = counts
    detail = f"{passed} passed, {skipped} skipped, {failed} failed"
    if failed > 0:
        return False, detail
    if passed == 0:
        return False, detail + "; zero tests passed"
    if code != 0:
        return False, detail + f"; flutter exited {code}"
    return True, detail


def step(label: str, flutter: str, flutter_args: list[str], judge, log_path: Path, tail_lines: int) -> bool:
    code, text = fs.run_flutter(flutter, flutter_args, fs.MOBILE_APP)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(f"===== flutter {' '.join(flutter_args)} (exit {code}) =====\n{text}\n")
    if code == fs.NOT_FOUND:
        print(f"[FAIL] {label}: {text.strip()}")
        return False
    ok, detail = judge(code, text)
    print(f"[{'OK' if ok else 'FAIL'}] {label}: {detail}")
    if not ok:
        print(fs.tail(text, tail_lines))
    return ok


def parse_args(argv: list | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="flutter analyze + flutter test, one verdict.")
    parser.add_argument("--skip-analyze", action="store_true", help="do not run flutter analyze")
    parser.add_argument("--skip-tests", action="store_true", help="do not run flutter test")
    parser.add_argument("--test-file", metavar="PATH", help="run one test file, relative to mobile-app")
    parser.add_argument("--log", metavar="PATH", help="full output location (default: build/test-logs)")
    parser.add_argument("--tail", type=int, default=40, help="lines of a failed step to print (default: 40)")
    return parser.parse_args(argv)


def main(argv: list | None = None) -> int:
    fs.common.configure_stdio()
    args = parse_args(argv)
    if args.skip_analyze and args.skip_tests:
        print("quality-gate: both steps are skipped, so nothing would be checked", file=sys.stderr)
        return 2
    if not fs.MOBILE_APP.is_dir():
        print(f"quality-gate: mobile-app folder not found at {fs.MOBILE_APP}", file=sys.stderr)
        return 2
    flutter = fs.find_flutter()
    if flutter is None:
        print("quality-gate: flutter is not installed or not on PATH", file=sys.stderr)
        return 2
    log_path = Path(args.log) if args.log else fs.default_log_path("quality-gate")
    failed: list[str] = []
    if not args.skip_analyze and not step("analyze", flutter, ["analyze"], judge_analyze, log_path, args.tail):
        failed.append("analyze")
    if not args.skip_tests:
        targs = ["test", args.test_file] if args.test_file else ["test"]
        if not step("tests", flutter, targs, judge_tests, log_path, args.tail):
            failed.append("tests")
    print(f"Full output: {log_path}")
    print("RESULT: PASS" if not failed else f"RESULT: FAIL ({', '.join(failed)})")
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
