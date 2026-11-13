"""Tests for mobile-app/scripts/check-version-consistency.py (F333, Sprint 85; port of the .ps1).

Run: python -I -m unittest discover -s scripts/tests -v

Test list and what each does NOT catch:
  test_get_versions: both literal forms are read; a dependency version is not. NOT caught: a third
      literal form nobody has defined.
  test_self_test: --self-test prints the five PowerShell cases, exit 0. NOT caught: a case weakened in
      the script and here together.
  test_stale_literal_in_each_swept_dir: a stale literal in lib, windows/runner, scripts and test (and in
      .cpp and .ps1 files) exits 1 with "path:line found 'x'". NOT caught: a literal in an extension that
      is not swept (.py, .yaml); the Dart test has the same list.
  test_skipped_files_and_unswept_extensions: the gate's own files and a .py file are not flagged. NOT
      caught: a real file that happens to share a skipped name.
  test_all_match_passes: a consistent tree prints the [OK] line, exit 0. NOT caught: a tree with no
      literal at all (also passes).
  test_msix_version_rules: a missing or wrong msix_version fails with its own message. NOT caught: an
      msix_version outside msix_config (the regex reads the first line anywhere).
  test_missing_pubspec_or_version: no pubspec or no version line fails, never passes. NOT caught: a
      version line with a pre-release suffix such as 1.2.3-beta (the X.Y.Z prefix is read).
  test_line_numbers_with_crlf_and_odd_breaks: line numbers follow CR, LF and CRLF only. NOT caught: a
      file using a form feed as text (not a line break here).
  test_matches_dart_test_lane: regex, dirs and extensions equal the Dart test's. NOT caught: a change in
      how the Dart test applies its exclusions.
  test_real_app_is_consistent: the real mobile-app passes. NOT caught: a literal added later.
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
TOOL_PATH = REPO / "mobile-app" / "scripts" / "check-version-consistency.py"
DART_TEST = REPO / "mobile-app" / "test" / "policy" / "version_consistency_test.dart"

_spec = importlib.util.spec_from_file_location("check_version_consistency_mod", TOOL_PATH)
tool = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(tool)

PUBSPEC = "name: x\nversion: 1.2.3+4\nmsix_config:\n  msix_version: 1.2.3.0\n"


def run_main(argv: list[str]) -> tuple[int, str]:
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        code = tool.main(argv)
    return code, buf.getvalue()


def make_app(root: Path, pubspec: str = PUBSPEC, files: dict[str, str] | None = None) -> Path:
    (root / "pubspec.yaml").write_text(pubspec, encoding="utf-8")
    for rel, text in (files or {}).items():
        target = root / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(text.encode("utf-8"))
    return root


class LiteralTests(unittest.TestCase):
    def test_get_versions(self) -> None:
        self.assertEqual(tool.get_versions("a_v1.2.3.log b_v4.5.6.log"), ["1.2.3", "4.5.6"])
        self.assertEqual(tool.get_versions("'Version 1.2.3\\${suffix}'"), ["1.2.3"])
        self.assertEqual(tool.get_versions("// pkg v16.2.0 and sqlite3: 3.1.4"), [])
        self.assertEqual(tool.get_versions("version 1.2.3"), [])  # lower case is not the display form

    def test_self_test(self) -> None:
        code, out = run_main(["--self-test"])
        self.assertEqual(code, 0)
        lines = out.splitlines()
        self.assertEqual(lines[0], "[SELF-TEST] check-version-consistency.py")
        self.assertEqual(lines[-1], "[SELF-TEST] ALL PASSED")
        self.assertEqual(len([ln for ln in lines if ln.startswith("  [PASS]")]), 5)


class ScanTests(unittest.TestCase):
    def test_stale_literal_in_each_swept_dir(self) -> None:
        files = {
            "lib/a.dart": "const f = 'x_v0.1.0.log';\n",
            "windows/runner/main.cpp": 'auto n = L"y_v0.1.1.log";\n',
            "scripts/b.ps1": "$n = 'z_v0.1.2.log'\n",
            "test/c_test.dart": "expect(x, 'Version 0.1.3');\n",
        }
        with tempfile.TemporaryDirectory() as tmp:
            app = make_app(Path(tmp), files=files)
            code, out = run_main(["--app-root", str(app)])
        self.assertEqual(code, 1)
        self.assertIn("[FAIL] Version-literal mismatch(es) -- expected 1.2.3 (from pubspec.yaml):", out)
        for rel, version in (("a.dart", "0.1.0"), ("main.cpp", "0.1.1"), ("b.ps1", "0.1.2"),
                             ("c_test.dart", "0.1.3")):
            self.assertRegex(out, r"%s:1 found '%s'" % (re.escape(rel), re.escape(version)))
        self.assertIn("docs/STORE_RELEASE_PROCESS.md", out)

    def test_skipped_files_and_unswept_extensions(self) -> None:
        files = {
            "scripts/check-version-consistency.py": "x = 'Version 0.0.1'\n",
            "scripts/check-version-consistency.ps1": "x = 'Version 0.0.2'\n",
            "test/policy/version_consistency_test.dart": "x = 'Version 0.0.3'\n",
            "scripts/other.py": "x = 'Version 0.0.4'\n",
            "lib/data.yaml": "x: Version 0.0.5\n",
        }
        with tempfile.TemporaryDirectory() as tmp:
            app = make_app(Path(tmp), files=files)
            code, out = run_main(["--app-root", str(app)])
        self.assertEqual(code, 0, out)

    def test_all_match_passes(self) -> None:
        files = {"lib/a.dart": "'Version 1.2.3' and f_v1.2.3.log\n"}
        with tempfile.TemporaryDirectory() as tmp:
            app = make_app(Path(tmp), files=files)
            code, out = run_main(["--app-root", str(app)])
        self.assertEqual(code, 0)
        self.assertEqual(
            out.strip(),
            "[OK] All app-version literals match pubspec.yaml (1.2.3); msix_version tracks it (1.2.3.0).")

    def test_msix_version_rules(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            app = make_app(Path(tmp), pubspec="version: 1.2.3+4\nmsix_config:\n  msix_version: 1.2.2.0\n")
            code, out = run_main(["--app-root", str(app)])
            self.assertEqual(code, 1)
            self.assertIn("[FAIL] msix_version (1.2.2.0) must equal pubspec version + '.0' (1.2.3.0).", out)
            make_app(Path(tmp), pubspec="version: 1.2.3+4\n")
            code, out = run_main(["--app-root", str(app)])
            self.assertEqual(code, 1)
            self.assertIn("[FAIL] Could not find an 'msix_version: A.B.C.D' line in pubspec.yaml", out)

    def test_missing_pubspec_or_version(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            code, out = run_main(["--app-root", tmp])
            self.assertEqual(code, 1)
            self.assertIn("pubspec.yaml not found", out)
            make_app(Path(tmp), pubspec="name: x\n")
            code, out = run_main(["--app-root", tmp])
            self.assertEqual(code, 1)
            self.assertIn("[FAIL] Could not find a 'version: X.Y.Z' line in pubspec.yaml", out)

    def test_line_numbers_with_crlf_and_odd_breaks(self) -> None:
        text = "a\r\nb\rc\n\x0c ok\n'Version 9.9.9'\n"  # CRLF, CR, LF, then a form feed in text
        with tempfile.TemporaryDirectory() as tmp:
            app = make_app(Path(tmp), files={"lib/a.dart": text})
            code, out = run_main(["--app-root", str(app)])
        self.assertEqual(code, 1)
        self.assertIn("a.dart:5 found '9.9.9'", out)


class LaneSyncTests(unittest.TestCase):
    def test_matches_dart_test_lane(self) -> None:
        dart = DART_TEST.read_text(encoding="utf-8")
        regex = re.search(r"_versionLiteral = RegExp\(\s*r'(.*?)',?\s*\);", dart, re.DOTALL)
        dirs = re.search(r"_sweepDirs = \[(.*?)\];", dart, re.DOTALL)
        exts = re.findall(r"p\.endsWith\('(\.[a-z0-9]+)'\)", dart)
        self.assertIsNotNone(regex)
        self.assertIsNotNone(dirs)
        self.assertEqual(tool.VERSION_RE.pattern, regex.group(1))
        self.assertEqual(tool.SWEEP_DIRS, re.findall(r"'([^']+)'", dirs.group(1)))
        self.assertEqual(sorted(tool.SWEEP_EXTS), sorted(exts))

    def test_real_app_is_consistent(self) -> None:
        code, out = run_main([])
        self.assertEqual(code, 0, out)
        self.assertIn("[OK] All app-version literals match pubspec.yaml", out)


if __name__ == "__main__":
    unittest.main()
