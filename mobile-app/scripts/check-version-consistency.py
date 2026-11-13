"""Version-consistency enforcement gate (Sprint 44 retro IMP-1; Python port F333 Sprint 85).

Mirrors mobile-app/test/policy/version_consistency_test.dart. Fails (exit 1) when an app-version literal
under lib/, windows/runner/, scripts/ or test/ does not match the canonical `version:` in pubspec.yaml,
or when msix_version is not that version plus ".0" (F159, Sprint 60).

Why: app version literals are embedded as log-filename tokens (..._v0.5.4.log) and the Settings
version-display string (Version 0.5.4), in Dart and in C++ (windows/runner/main.cpp). A version bump must
update every one. The Sprint 43 bump missed main.cpp and shipped a stale filename.

Recognized literal forms (narrow, so dependency versions in comments are not matched):
    _v<MAJOR>.<MINOR>.<PATCH>.log        scan-log filename token
    Version <MAJOR>.<MINOR>.<PATCH>      Settings version-display string

Swept extensions: .dart .cpp .cc .h .ps1 (the same list as the Dart test; a .py file is not swept by
either, so keep the two lists in step if one changes). The gate's own files are skipped because they
hold stale-version fixture strings on purpose.

Usage:
    python mobile-app/scripts/check-version-consistency.py               scan, exit 1 on a mismatch
    python mobile-app/scripts/check-version-consistency.py --self-test   offline self-test, no scan
    python mobile-app/scripts/check-version-consistency.py --app-root DIR  scan another app folder (tests)

Exit codes:
    0  all literals match (or all self-test cases passed)
    1  a mismatch, a missing pubspec version or msix_version line, or a failed self-test case
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent

# Matches the two app-version literal forms. Case-sensitive, like [regex]::Matches in the original.
VERSION_RE = re.compile(r"_v(\d+\.\d+\.\d+)\.log|Version\s(\d+\.\d+\.\d+)")
SWEEP_DIRS = ["lib", "windows/runner", "scripts", "test"]
SWEEP_EXTS = {".dart", ".cpp", ".cc", ".h", ".ps1"}
# Files that hold stale-version fixture strings on purpose.
SKIP_NAMES = {"check-version-consistency.py", "check-version-consistency.ps1",
              "version_consistency_test.dart"}
LINE_SPLIT = re.compile(r"\r\n|\r|\n")  # same line breaks as .NET ReadAllLines

SELF_TEST_CASES = [
    ("background_scan_v0.5.3.log", True, "stale log token"),
    ("background_scan_v0.5.4.log", False, "matching log token"),
    ("Version 0.5.4", False, "matching display"),
    ("Version 0.5.3", True, "stale display"),
    ("// flutter_local_notifications v16.2.0 ...", False, "dependency version ignored"),
]


def get_versions(line: str) -> list[str]:
    """Every app-version literal found on the line."""
    return [m.group(1) or m.group(2) for m in VERSION_RE.finditer(line)]


def find_mismatches(app_root: Path, canonical: str) -> list[tuple[Path, int, str, str]]:
    """Returns (file, line number, found version, stripped line) for each stale literal."""
    found: list[tuple[Path, int, str, str]] = []
    for sweep in SWEEP_DIRS:
        folder = app_root / sweep
        if not folder.is_dir():
            continue
        for path in sorted(folder.rglob("*"), key=lambda p: str(p).lower()):
            if not path.is_file() or path.suffix.lower() not in SWEEP_EXTS or path.name in SKIP_NAMES:
                continue
            text = path.read_bytes().decode("utf-8-sig", errors="replace")
            for number, line in enumerate(LINE_SPLIT.split(text), start=1):
                for version in get_versions(line):
                    if version != canonical:
                        found.append((path, number, version, line.strip()))
    return found


def run_self_test() -> int:
    print("[SELF-TEST] check-version-consistency.py")
    canonical = "0.5.4"
    passed = True
    for line, expect_mismatch, name in SELF_TEST_CASES:
        mismatch = any(v != canonical for v in get_versions(line))
        ok = mismatch == expect_mismatch
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
    parser = argparse.ArgumentParser(description="App-version literal consistency gate.")
    parser.add_argument("--self-test", action="store_true", help="run the offline self-test and exit")
    parser.add_argument("--app-root", type=Path, default=SCRIPT_DIR.parent,
                        help="the mobile-app folder (default: the parent of this script's folder)")
    args = parser.parse_args(argv)

    if args.self_test:
        return run_self_test()

    app_root: Path = args.app_root
    pubspec_path = app_root / "pubspec.yaml"
    if not pubspec_path.is_file():
        print("[FAIL] pubspec.yaml not found: %s" % pubspec_path)
        return 1
    pubspec = pubspec_path.read_bytes().decode("utf-8-sig", errors="replace")
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)", pubspec, re.MULTILINE | re.IGNORECASE)
    if not match:
        print("[FAIL] Could not find a 'version: X.Y.Z' line in pubspec.yaml")
        return 1
    canonical = match.group(1)

    violations = find_mismatches(app_root, canonical)
    if violations:
        print("[FAIL] Version-literal mismatch(es) -- expected %s (from pubspec.yaml):" % canonical)
        for path, number, version, text in violations:
            print("  %s:%d found '%s'" % (path, number, version))
            print("    %s" % text)
        print("")
        print("Update each literal to match pubspec.yaml. See the version checklist in "
              "docs/STORE_RELEASE_PROCESS.md.")
        return 1

    # F159 (Sprint 60): msix_version must track the pubspec version as X.Y.Z.0.
    msix_match = re.search(r"^[ \t]*msix_version:\s*(\d+\.\d+\.\d+\.\d+)", pubspec,
                           re.MULTILINE | re.IGNORECASE)
    if not msix_match:
        print("[FAIL] Could not find an 'msix_version: A.B.C.D' line in pubspec.yaml "
              "(msix_config moved? update this check).")
        return 1
    msix = msix_match.group(1)
    if msix != canonical + ".0":
        print("[FAIL] msix_version (%s) must equal pubspec version + '.0' (%s.0). Bump both together."
              % (msix, canonical))
        return 1

    print("[OK] All app-version literals match pubspec.yaml (%s); msix_version tracks it (%s)."
          % (canonical, msix))
    return 0


if __name__ == "__main__":
    sys.exit(main())
