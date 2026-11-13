"""Content manifest validator (Sprint 38 F85, ADR-0038; Python port F333 Sprint 85).

Validates mobile-app/assets/content/manifest.yaml against the .md files on disk and the HelpSection enum
in mobile-app/lib/ui/screens/help_screen.dart. The drift checks (ADR-0038):
    1. Every key in the manifest resolves to an existing .md file (inside assets/content/).
    2. Every .md file under assets/content/ (except audit-log.md, which is meta-documentation) is
       referenced by exactly one key, and no key is declared twice.
    3. Every HelpSection enum case has an entry in the manifest under the help: namespace.

The manifest is a flat two-level file, parsed with a small regex reader (no YAML library):
    namespace:
      key: relative/path.md
A non-comment, non-blank line that matches neither form is reported as a parse failure (the original
ignored such lines silently).

Usage:
    python mobile-app/scripts/validate-content-manifest.py [--verbose] [--repo-root DIR]

Exit codes:
    0  manifest is consistent with disk and Dart source (prints "[OK] ..." and two counts)
    1  one or more drift issues (printed to stdout as "[FAIL] N drift issue(s) found:"), or the
       manifest or help_screen.dart is missing or empty (message on stderr)
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent

NAMESPACE_RE = re.compile(r"^([a-zA-Z_]+):\s*$")
ENTRY_RE = re.compile(r"^\s+([a-zA-Z_][a-zA-Z0-9_]*):\s*(.+\.md)\s*$")
ENUM_RE = re.compile(r"enum HelpSection \{(.+?)\}", re.DOTALL)
CASE_RE = re.compile(r"^\s*([a-zA-Z][a-zA-Z0-9]*)\s*,", re.MULTILINE)
LINE_SPLIT = re.compile(r"\r?\n")


def _read_text(path: Path) -> str:
    return path.read_bytes().decode("utf-8-sig", errors="replace")


def parse_manifest(text: str, verbose: bool = False) -> tuple[dict[str, str], list[str]]:
    """Returns ({"namespace.key": "relative/path.md"}, parse failures)."""
    entries: dict[str, str] = {}
    failures: list[str] = []
    namespace: str | None = None
    for number, line in enumerate(LINE_SPLIT.split(text), start=1):
        if re.match(r"^\s*#", line) or re.match(r"^\s*$", line):
            continue
        ns_match = NAMESPACE_RE.match(line)
        if ns_match:
            namespace = ns_match.group(1)
            if verbose:
                print("[parse] namespace: %s" % namespace)
            continue
        entry_match = ENTRY_RE.match(line)
        if entry_match:
            if namespace is None:
                raise ValueError("Manifest key '%s' appears before any namespace heading"
                                 % entry_match.group(1))
            key = "%s.%s" % (namespace, entry_match.group(1))
            if key in entries:
                failures.append("[Check 2] Duplicate manifest key: %s (line %d)" % (key, number))
            entries[key] = entry_match.group(2).strip()
            if verbose:
                print("[parse]   %s -> %s" % (key, entry_match.group(2)))
            continue
        failures.append("[Parse] Unrecognized manifest line %d: %s" % (number, line.strip()))
    return entries, failures


def validate(content_dir: Path, entries: dict[str, str], help_dart: str,
             verbose: bool = False) -> tuple[list[str], int]:
    """Runs checks 1 to 3. Returns (failures, number of content .md files)."""
    failures: list[str] = []

    # Check 1: every key resolves to an existing .md file inside the content folder.
    root = content_dir.resolve()
    for key, rel in entries.items():
        target = (content_dir / rel).resolve()
        if root != target and root not in target.parents:
            failures.append("[Check 1] Manifest entry '%s' points outside the content folder: %s"
                            % (key, rel))
        elif not target.is_file():
            failures.append("[Check 1] Manifest entry '%s' references missing file: %s" % (key, rel))

    # Check 2: every .md file (except audit-log.md) is referenced; no path is referenced twice.
    md_files = sorted(p.relative_to(content_dir).as_posix()
                      for p in content_dir.rglob("*.md") if p.is_file() and p.name != "audit-log.md")
    referenced = set(entries.values())
    for rel in md_files:
        if rel not in referenced:
            failures.append("[Check 2] Orphan content file (not in manifest): %s" % rel)
    counts: dict[str, int] = {}
    for rel in entries.values():
        counts[rel] = counts.get(rel, 0) + 1
    for rel, count in counts.items():
        if count > 1:
            failures.append("[Check 2] Duplicate manifest reference: %s referenced %d times" % (rel, count))

    # Check 3: every HelpSection case has a help.<case> entry.
    enum_match = ENUM_RE.search(help_dart)
    if not enum_match:
        failures.append("[Check 3] Could not parse HelpSection enum from help_screen.dart")
    else:
        cases = CASE_RE.findall(enum_match.group(1))
        for case in cases:
            if ("help.%s" % case) not in entries:
                failures.append("[Check 3] HelpSection.%s has no manifest entry under help: namespace"
                                % case)
        if verbose:
            print("[parse] HelpSection cases found: %d" % len(cases))
    return failures, len(md_files)


def main(argv: list[str] | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    parser = argparse.ArgumentParser(description="Validate the content manifest (ADR-0038).")
    parser.add_argument("-v", "--verbose", action="store_true", help="print parse details")
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT,
                        help="repository root (default: two folders above this script)")
    args = parser.parse_args(argv)

    content_dir = args.repo_root / "mobile-app" / "assets" / "content"
    manifest_path = content_dir / "manifest.yaml"
    help_path = args.repo_root / "mobile-app" / "lib" / "ui" / "screens" / "help_screen.dart"
    if not manifest_path.is_file():
        print("Manifest not found: %s" % manifest_path, file=sys.stderr)
        return 1
    if not help_path.is_file():
        print("help_screen.dart not found: %s" % help_path, file=sys.stderr)
        return 1

    try:
        entries, failures = parse_manifest(_read_text(manifest_path), args.verbose)
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 1
    if not entries:
        print("Manifest is empty -- no namespace/key entries parsed", file=sys.stderr)
        return 1

    more, md_count = validate(content_dir, entries, _read_text(help_path), args.verbose)
    failures.extend(more)
    if not failures:
        print("[OK] Content manifest is consistent with disk and HelpSection enum")
        print("     Manifest entries: %d" % len(entries))
        print("     Content .md files: %d" % md_count)
        return 0
    print("[FAIL] %d drift issue(s) found:" % len(failures))
    for failure in failures:
        print("  - %s" % failure)
    return 1


if __name__ == "__main__":
    sys.exit(main())
