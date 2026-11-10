"""Validate the YAML rule files of the spam filter (F330, Sprint 85; port of validate-yaml-rules.ps1).

Checks rules.yaml and rules_safe_senders.yaml for: tabs in indentation, the required top-level key
(`rules`, `safe_senders`), regex patterns that do not compile, patterns with a known catastrophic
backtracking shape, and duplicate safe-sender patterns.

This is a TEXT scan, as the PowerShell original was, not a YAML parser. It reads list items written as
`- 'pattern'` or `- "pattern"`. The repository's rule files use only that shape (checked 2026-11-10: 1824 and
426 single-quoted items, no double-quoted item, no other list item, no non-empty flow list). A non-empty flow
list (`key: ['a']`) is reported as a warning ("not read") instead of being skipped silently.

Regexes are compiled with Python `re` through scripts/regex_dialect.py. The app runs the patterns with Dart
RegExp, so this is a syntax check, not proof. A construct the helper cannot translate is reported as
"[NOT CHECKED]" (listed, never an error).

Usage:
    python scripts/validate-yaml-rules.py [--rules-file PATH] [--safe-senders-file PATH] [--test-regex]

Defaults: ./rules.yaml and ./rules_safe_senders.yaml when they exist in the current folder; otherwise the
files of this repository, mobile-app/assets/rules/. A path given on the command line that does not exist is
an error for rules.yaml (exit 1) and a warning for the safe-senders file.

Exit codes: 0 no errors (warnings and not-checked patterns allowed); 1 any error, or rules.yaml not found.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / ".claude" / "hooks" / "lib"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import common  # noqa: E402
import regex_dialect  # noqa: E402

RULE_FILES_DIR = REPO / "mobile-app" / "assets" / "rules"
RULE = "=" * 80
SINGLE_ITEM = re.compile(r"^[ \t]*-[ \t]*'((?:[^']|'')+)'", re.M)
DOUBLE_ITEM = re.compile(r'^[ \t]*-[ \t]*"((?:[^"\\]|\\.)+)"', re.M)
FLOW_LIST = re.compile(r"""^[ \t]*(?:-[ \t]*)?[\w'"]+[ \t]*:[ \t]*\[[ \t]*[^\]\s]""", re.M)
LEADING_TAB = re.compile(r"^ *\t", re.M)
# Values that are not regexes: a boolean/operator word, or a rule name (SpamAuto..., Spam..., Email...).
NOT_A_PATTERN = re.compile(r"(?:True|False|OR|AND|(?:SpamAuto|Spam|Email)[\w -]*)", re.I)
LOOKS_LIKE_REGEX = re.compile(r"[@\[\]\.\*\+\?\(\)\^\$\\]")
SAMPLE_HEADERS = [
    "user@example.com",
    "John Doe <user@example.com>",
    "noreply@mail.example.com",
    "support+ticket123@subdomain.example.co.uk",
]


def _line_of(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def extract_items(text: str) -> list[tuple[int, str]]:
    """List items (line number, decoded value): single-quoted first, then double-quoted, as the original did."""
    items: list[tuple[int, str]] = []
    for m in SINGLE_ITEM.finditer(text):
        items.append((_line_of(text, m.start()), m.group(1).replace("''", "'")))
    for m in DOUBLE_ITEM.finditer(text):
        value = re.sub(r"\\(.)", lambda e: e.group(1) if e.group(1) in '\\"' else "\\" + e.group(1), m.group(1))
        items.append((_line_of(text, m.start()), value))
    return items


class Report:
    """Everything the run found, in the order found."""

    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.not_checked: list[str] = []

    def check_pattern(self, pattern: str, context: str) -> str:
        """Compile one pattern. Returns "valid", "invalid" or "unchecked"; records what was found."""
        try:
            _compiled, notes = regex_dialect.compile_net(pattern)
        except regex_dialect.NotChecked as exc:
            self.not_checked.append(f"[NOT CHECKED] {pattern} (in {context}) - {exc}")
            return "unchecked"
        except regex_dialect.RegexSyntaxError as exc:
            self.errors.append(f"[REGEX ERROR] Invalid pattern: {pattern} (in {context}) - {exc}")
            return "invalid"
        for _ in regex_dialect.performance_warnings(pattern):
            self.warnings.append(f"[PERFORMANCE WARNING] Pattern may cause catastrophic backtracking: {pattern} (in {context})")
        for note in notes:
            self.warnings.append(f"[PATTERN WARNING] {note}: {pattern} (in {context})")
        return "valid"


def _read(path: Path) -> str:
    return path.read_bytes().decode("utf-8-sig")


def _count_line(found: int, valid: int, unchecked: int, noun: str) -> str:
    extra = f", {unchecked} not checked" if unchecked else ""
    return f"  [OK] Found {found} {noun}, {valid} valid{extra}"


def validate_rules(path: Path, report: Report) -> int:
    """Section 1. Returns 1 when the file is missing (the caller exits), else 0."""
    print("[1/3] Validating rules.yaml...")
    if not path.exists():
        print(f"  [ERROR] File not found: {path}")
        return 1
    try:
        text = _read(path)
        if LEADING_TAB.search(text):
            report.errors.append("[YAML ERROR] rules.yaml contains tabs - YAML requires spaces for indentation")
        if not re.search(r"""^['"]?rules['"]?:""", text, re.M):
            report.errors.append("[SCHEMA ERROR] rules.yaml missing 'rules' key")
        for m in FLOW_LIST.finditer(text):
            report.warnings.append(f"[YAML NOT READ] rules.yaml line {_line_of(text, m.start())}: a flow list with items is not read by this validator")
        found = valid = unchecked = 0
        for line, pattern in extract_items(text):
            if NOT_A_PATTERN.fullmatch(pattern) or not LOOKS_LIKE_REGEX.search(pattern):
                continue
            found += 1
            result = report.check_pattern(pattern, f"rules.yaml line {line}")
            valid += result == "valid"
            unchecked += result == "unchecked"
        print(_count_line(found, valid, unchecked, "regex patterns"))
    except (OSError, UnicodeDecodeError) as exc:
        report.errors.append(f"[YAML ERROR] Failed to parse rules.yaml: {exc}")
    return 0


def validate_safe_senders(path: Path, report: Report) -> None:
    """Section 2."""
    print("[2/3] Validating rules_safe_senders.yaml...")
    if not path.exists():
        print(f"  [WARNING] File not found: {path}")
        report.warnings.append(f"[FILE WARNING] rules_safe_senders.yaml not found: {path}")
        return
    try:
        text = _read(path)
        if LEADING_TAB.search(text):
            report.errors.append("[YAML ERROR] rules_safe_senders.yaml contains tabs")
        if not re.search(r"""^['"]?safe_senders['"]?:""", text, re.M):
            report.errors.append("[SCHEMA ERROR] rules_safe_senders.yaml missing 'safe_senders' key")
        for m in FLOW_LIST.finditer(text):
            report.warnings.append(f"[YAML NOT READ] rules_safe_senders.yaml line {_line_of(text, m.start())}: a flow list with items is not read by this validator")
        items = extract_items(text)
        valid = unchecked = 0
        for line, pattern in items:
            result = report.check_pattern(pattern, f"safe_senders.yaml line {line}")
            valid += result == "valid"
            unchecked += result == "unchecked"
        print(_count_line(len(items), valid, unchecked, "safe sender patterns"))
        duplicates = len(items) - len({p for _line, p in items})
        if duplicates:
            report.warnings.append(f"[DUPLICATE WARNING] Found {duplicates} duplicate patterns in safe_senders.yaml")
    except (OSError, UnicodeDecodeError) as exc:
        report.errors.append(f"[YAML ERROR] Failed to parse rules_safe_senders.yaml: {exc}")


def resolve_default(name: str) -> Path:
    """./name when it exists in the current folder, else the repository's copy under mobile-app/assets/rules."""
    here = Path(name)
    return here if here.exists() else RULE_FILES_DIR / name


def main(argv: list[str] | None = None) -> int:
    common.configure_stdio()
    parser = argparse.ArgumentParser(description="Validate rules.yaml and rules_safe_senders.yaml.")
    parser.add_argument("--rules-file", help="path to rules.yaml (default: ./rules.yaml, else mobile-app/assets/rules/rules.yaml)")
    parser.add_argument("--safe-senders-file", help="path to rules_safe_senders.yaml (same default rule)")
    parser.add_argument("--test-regex", action="store_true", help="list the sample headers (sample matching is not implemented)")
    args = parser.parse_args(argv)
    rules = Path(args.rules_file) if args.rules_file else resolve_default("rules.yaml")
    safe = Path(args.safe_senders_file) if args.safe_senders_file else resolve_default("rules_safe_senders.yaml")

    print(RULE)
    print("YAML Rules Validation")
    print(RULE)
    print()
    report = Report()
    if validate_rules(rules, report):
        return 1
    validate_safe_senders(safe, report)

    if args.test_regex:
        print("[3/3] Testing regex patterns against sample email headers...")
        print("  Sample headers:")
        for header in SAMPLE_HEADERS:
            print(f"    - {header}")
        print()
        print("  [INFO] Matching patterns against these samples is not implemented; use scripts/test-regex-patterns.py")
    else:
        print("[3/3] Skipping regex testing (use --test-regex to enable)")

    print()
    print(RULE)
    print("Validation Summary")
    print(RULE)
    print()
    if not (report.errors or report.warnings or report.not_checked):
        print("[OK] All validations passed!")
        return 0
    for title, lines in (("Errors", report.errors), ("Warnings", report.warnings), ("Not checked", report.not_checked)):
        if lines:
            print(f"{title}: {len(lines)}")
            for line in lines:
                print(f"  {line}")
            print()
    return 1 if report.errors else 0


if __name__ == "__main__":
    sys.exit(main())
