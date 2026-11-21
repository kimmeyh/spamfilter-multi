"""Regenerate mobile-app/lib/core/utils/iana_tlds.dart from the IANA TLD list.

Python port (F333, Sprint 85) of update_iana_tlds.ps1 and update_iana_tlds.sh; this one script replaces
both and runs on Windows, Linux and macOS.

IANA refreshes the list periodically (new gTLDs, retirements). Re-run this script when adding domain
validation features or when users report a real TLD being rejected as unknown.

The downloaded text is validated before anything is written: the first line must be IANA's "# Version ..."
comment, every other line must be a TLD ([a-z0-9-] after lowercasing), and there must be at least
MIN_TLDS of them. A bad download (an HTML error page, a cut-off list) leaves the output file untouched.
TLDs are lowercased, de-duplicated and sorted by code point, so the output is the same on every OS and
locale.

Usage:
    python mobile-app/scripts/update_iana_tlds.py                       download and overwrite iana_tlds.dart
    python mobile-app/scripts/update_iana_tlds.py --dry-run             download, validate, print, write nothing
    python mobile-app/scripts/update_iana_tlds.py --source FILE_OR_URL  read this list instead of IANA's
    python mobile-app/scripts/update_iana_tlds.py --output PATH         write to another file (tests)

After a real run: flutter analyze, and
    flutter test test/unit/utils/domain_validation_test.dart

Exit codes:
    0  success (or a successful --dry-run)
    1  download failed, the text failed validation, or the output file could not be written
"""
from __future__ import annotations

import argparse
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_OUTPUT = SCRIPT_DIR.parent / "lib" / "core" / "utils" / "iana_tlds.dart"
IANA_URL = "https://data.iana.org/TLD/tlds-alpha-by-domain.txt"
MIN_TLDS = 500  # IANA lists about 1440; far fewer means a bad download
TLD_RE = re.compile(r"[a-z0-9-]+")
TIMEOUT_SECONDS = 30


class IanaListError(Exception):
    """The downloaded text is not a usable IANA TLD list."""


def fetch_text(source: str) -> str:
    """Reads the list from a URL (http, https, file) or from a local file path."""
    if re.match(r"^[a-z][a-z0-9+.-]+://", source, re.IGNORECASE):
        request = urllib.request.Request(source, headers={"User-Agent": "update_iana_tlds.py"})
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            return response.read().decode("utf-8", errors="replace")
    return Path(source).read_bytes().decode("utf-8", errors="replace")


def parse_list(text: str) -> tuple[str, list[str]]:
    """Returns (version comment line, sorted unique lowercase TLDs). Raises IanaListError."""
    lines = [line.strip() for line in re.split(r"\r?\n", text) if line.strip() != ""]
    if len(lines) < 2:
        raise IanaListError("Unexpected response (got %d lines)" % len(lines))
    version_line = lines[0]
    if not version_line.startswith("#"):
        raise IanaListError("First line is not IANA's '# Version ...' comment: %r" % version_line[:80])
    tlds = set()
    for line in lines[1:]:
        tld = line.lower()
        if not TLD_RE.fullmatch(tld):
            raise IanaListError("Not a TLD: %r" % line[:80])
        tlds.add(tld)
    if len(tlds) < MIN_TLDS:
        raise IanaListError("Only %d TLDs; expected at least %d (truncated download?)"
                            % (len(tlds), MIN_TLDS))
    return version_line, sorted(tlds)


def build_dart(version_line: str, tlds: list[str], source: str) -> str:
    """The text of iana_tlds.dart for a parsed list."""
    set_literal = "{" + ",".join('"%s"' % tld for tld in tlds) + "}"
    version_comment = re.sub(r"^# ", "", version_line)
    return (
        "/// Valid IANA top-level domains (TLDs).\n"
        "///\n"
        "/// Source: %s\n"
        "/// %s\n"
        "///\n"
        "/// Update procedure: re-run mobile-app/scripts/update_iana_tlds.py and commit.\n"
        "/// All TLDs stored lowercase. Lookup is O(1) via Set.\n"
        "library;\n"
        "\n"
        "/// IANA-registered TLDs (lowercase). Used by DomainValidation to reject\n"
        "/// invalid TLDs like 'com444' or 'whatevericanthinkof'.\n"
        "const Set<String> kIanaTlds = %s;\n"
    ) % (source, version_comment, set_literal)


def main(argv: list[str] | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    parser = argparse.ArgumentParser(description="Regenerate iana_tlds.dart from the IANA TLD list.")
    parser.add_argument("--source", default=IANA_URL, help="URL or file to read (default: IANA)")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="file to write")
    parser.add_argument("--dry-run", action="store_true", help="validate and report, write nothing")
    args = parser.parse_args(argv)

    print("[INFO] Fetching IANA TLD list from %s ..." % args.source)
    try:
        text = fetch_text(args.source)
    except (urllib.error.URLError, OSError, ValueError) as error:
        print("[ERROR] Failed to download IANA TLD list: %s" % error)
        return 1
    try:
        version_line, tlds = parse_list(text)
    except IanaListError as error:
        print("[ERROR] %s" % error)
        return 1
    print("[INFO] %s" % version_line)
    print("[INFO] %d TLDs" % len(tlds))

    if args.dry_run:
        print("[OK] Dry run: nothing written (would write %s)" % args.output)
        return 0
    content = build_dart(version_line, tlds, IANA_URL)
    try:
        args.output.write_bytes(content.encode("utf-8"))
    except OSError as error:
        print("[ERROR] Could not write %s: %s" % (args.output, error))
        return 1
    print("[OK] Wrote %s" % args.output)
    print("[INFO] Run 'flutter analyze' and 'flutter test test/unit/utils/domain_validation_test.dart' "
          "to verify.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
