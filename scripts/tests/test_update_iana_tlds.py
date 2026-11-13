"""Tests for mobile-app/scripts/update_iana_tlds.py (F333, Sprint 85; replaces the .ps1 and the .sh).

No test touches the network or the tracked iana_tlds.dart: the list comes from a local fixture file and
the output goes to a temp folder.

Run: python -I -m unittest discover -s scripts/tests -v

Test list and what each does NOT catch:
  test_output_matches_original_format: the generated Dart text equals the layout the PowerShell script
      wrote (header lines, one-line Set literal, sorted, lowercase, trailing newline), except the
      "Update procedure" line. NOT caught: the live IANA file format changing.
  test_sorted_deduplicated_lowercase: input in mixed case, unsorted, with a duplicate and CRLF line ends
      gives a sorted unique lowercase list by code point (xn-- entries included). NOT caught: a TLD with
      a non-ASCII letter (IANA publishes the xn-- form).
  test_dry_run_writes_nothing: --dry-run prints version and count and creates no file. NOT caught: a
      dry run against the live URL.
  test_bad_lists_leave_output_untouched: an HTML page, an empty body, a too-short list and a bad TLD
      line each exit 1 with an [ERROR] line, and an existing output file keeps its bytes. NOT caught: a
      list that is long enough, well formed and wrong.
  test_unreadable_source_and_output: a missing source file and an output folder that does not exist
      exit 1. NOT caught: a network timeout (needs a socket).
  test_real_tracked_file_still_has_the_layout: the tracked iana_tlds.dart still has the layout the
      script writes (same sections, a Set literal). NOT caught: the TLD content.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import re
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
TOOL_PATH = REPO / "mobile-app" / "scripts" / "update_iana_tlds.py"
TRACKED = REPO / "mobile-app" / "lib" / "core" / "utils" / "iana_tlds.dart"

_spec = importlib.util.spec_from_file_location("update_iana_tlds_mod", TOOL_PATH)
tool = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(tool)

VERSION = "# Version 2026010100, Last Updated Thu Jan  1 07:07:01 2026 UTC"


def make_list(count: int = 600, version: str = VERSION, crlf: bool = False) -> str:
    names = ["AAA%d" % i for i in range(count)]
    body = "\n".join([version] + names) + "\n"
    return body.replace("\n", "\r\n") if crlf else body


def run_main(argv: list[str]) -> tuple[int, str]:
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        code = tool.main(argv)
    return code, buf.getvalue()


class GenerateTests(unittest.TestCase):
    def test_output_matches_original_format(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            src = Path(tmp) / "list.txt"
            out_file = Path(tmp) / "iana_tlds.dart"
            src.write_text(make_list(), encoding="utf-8")
            code, out = run_main(["--source", str(src), "--output", str(out_file)])
            text = out_file.read_bytes().decode("utf-8")
        self.assertEqual(code, 0, out)
        lines = text.split("\n")
        self.assertEqual(lines[0], "/// Valid IANA top-level domains (TLDs).")
        self.assertEqual(lines[2], "/// Source: https://data.iana.org/TLD/tlds-alpha-by-domain.txt")
        self.assertEqual(lines[3], "/// Version 2026010100, Last Updated Thu Jan  1 07:07:01 2026 UTC")
        self.assertEqual(lines[5], "/// Update procedure: re-run mobile-app/scripts/update_iana_tlds.py and commit.")
        self.assertEqual(lines[6], "/// All TLDs stored lowercase. Lookup is O(1) via Set.")
        self.assertEqual(lines[7:9], ["library;", ""])
        self.assertTrue(lines[11].startswith('const Set<String> kIanaTlds = {"aaa0","aaa1","aaa10"'))
        self.assertTrue(lines[11].endswith('"aaa99"};'))
        self.assertEqual(lines[12], "")
        self.assertTrue(text.endswith("};\n"))
        self.assertNotIn("\r", text)
        self.assertIn("[INFO] 600 TLDs", out)
        self.assertIn("[OK] Wrote", out)

    def test_sorted_deduplicated_lowercase(self) -> None:
        names = ["ZZZ", "com", "COM", "XN--P1AI", "net", "xn--80ao21a", "a1", "Org"] + ["T%d" % i for i in range(600)]
        text = "\r\n".join([VERSION] + names) + "\r\n"
        version, tlds = tool.parse_list(text)
        self.assertEqual(version, VERSION)
        self.assertEqual(tlds, sorted(set(n.lower() for n in names)))
        self.assertEqual(tlds.count("com"), 1)
        self.assertLess(tlds.index("xn--80ao21a"), tlds.index("xn--p1ai"))

    def test_dry_run_writes_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            src = Path(tmp) / "list.txt"
            out_file = Path(tmp) / "never.dart"
            src.write_text(make_list(crlf=True), encoding="utf-8")
            code, out = run_main(["--source", str(src), "--output", str(out_file), "--dry-run"])
            existed = out_file.exists()
        self.assertEqual(code, 0)
        self.assertFalse(existed)
        self.assertIn("[INFO] # Version 2026010100", out)
        self.assertIn("[INFO] 600 TLDs", out)
        self.assertIn("Dry run: nothing written", out)


class RejectTests(unittest.TestCase):
    def test_bad_lists_leave_output_untouched(self) -> None:
        bad = {
            "html": ("<html>\n<body>503 Service Unavailable</body>\n</html>\n", "First line is not IANA"),
            "empty": ("", "Unexpected response (got 0 lines)"),
            "one line": (VERSION + "\n", "Unexpected response (got 1 lines)"),
            "too short": (make_list(count=10), "Only 10 TLDs"),
            "bad tld": (make_list().replace("AAA5\n", "not a tld!\n"), "Not a TLD"),
            "no version comment": (make_list(version="Version 2026010100"), "First line is not IANA"),
        }
        for name, (content, message) in bad.items():
            with self.subTest(case=name), tempfile.TemporaryDirectory() as tmp:
                src = Path(tmp) / "list.txt"
                out_file = Path(tmp) / "iana_tlds.dart"
                src.write_text(content, encoding="utf-8")
                out_file.write_bytes(b"ORIGINAL")
                code, out = run_main(["--source", str(src), "--output", str(out_file)])
                self.assertEqual(code, 1, out)
                self.assertIn("[ERROR] " + message, out)
                self.assertEqual(out_file.read_bytes(), b"ORIGINAL")

    def test_unreadable_source_and_output(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            code, out = run_main(["--source", str(Path(tmp) / "missing.txt")])
            self.assertEqual(code, 1)
            self.assertIn("[ERROR] Failed to download IANA TLD list:", out)
            src = Path(tmp) / "list.txt"
            src.write_text(make_list(), encoding="utf-8")
            code, out = run_main(["--source", str(src), "--output", str(Path(tmp) / "no" / "dir" / "x.dart")])
            self.assertEqual(code, 1)
            self.assertIn("[ERROR] Could not write", out)


class TrackedFileTests(unittest.TestCase):
    def test_real_tracked_file_still_has_the_layout(self) -> None:
        text = TRACKED.read_bytes().decode("utf-8").replace("\r\n", "\n")
        self.assertTrue(text.startswith("/// Valid IANA top-level domains (TLDs).\n"))
        self.assertIn("library;\n", text)
        # The tracked file was written by the old .sh (a line break before the semicolon); the Python
        # script writes the .ps1 layout (no break). Both are one Set literal.
        self.assertTrue(re.search(r'const Set<String> kIanaTlds = \{"[a-z0-9-]+"(,"[a-z0-9-]+")+\}\n?;\n$', text))


if __name__ == "__main__":
    unittest.main()
