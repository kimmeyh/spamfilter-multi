"""Tests for mobile-app/scripts/validate-content-manifest.py (F333, Sprint 85; port of the .ps1).

Run: python -I -m unittest discover -s scripts/tests -v

Test list and what each does NOT catch:
  test_consistent_tree_passes: a consistent tree prints the three [OK] lines (counts included), exit 0.
      NOT caught: a manifest with zero namespaces other than help.
  test_check1_missing_file: a key whose file is absent fails with the "[Check 1] ... missing file" text.
      NOT caught: a file that exists but is empty.
  test_check1_path_outside_content_dir_and_directory: a value with ".." or a folder named *.md fails.
      NOT caught: a symlink inside the folder that points outside (resolve() follows it, so it is
      reported as outside, but this test does not create one).
  test_check2_orphan_and_audit_log_exemption: an unreferenced .md fails, audit-log.md does not. NOT
      caught: an orphan with another extension.
  test_check2_duplicate_reference_and_duplicate_key: one file under two keys, and one key twice, both
      fail. NOT caught: the same file under two spellings that differ only by case.
  test_check3_enum_case_without_entry: a HelpSection case with no help.<case> entry fails; other
      namespaces do not satisfy it. NOT caught: an enum last case with no trailing comma (kept limit of
      the original regex).
  test_check3_unparseable_enum: no enum fails with the "[Check 3] Could not parse" text. NOT caught: an
      enum split by a brace inside a comment.
  test_unrecognized_manifest_line: a line that matches neither form is reported (the original ignored
      it). NOT caught: a valid-looking line with the wrong file extension that is meant as a data field.
  test_empty_and_missing_inputs: missing manifest, missing help_screen.dart, empty manifest, key before
      any namespace: exit 1, message on stderr. NOT caught: unreadable file permissions.
  test_verbose_prints_parse_lines: --verbose prints [parse] lines. NOT caught: their exact order.
  test_real_repo_manifest_is_consistent: the real repository passes. NOT caught: drift added later.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
TOOL_PATH = REPO / "mobile-app" / "scripts" / "validate-content-manifest.py"

_spec = importlib.util.spec_from_file_location("validate_content_manifest_mod", TOOL_PATH)
tool = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(tool)

MANIFEST = "# comment\n\nhelp:\n  alpha: help/alpha.md\n  beta: help/beta.md\nfaq:\n  one: faq/one.md\n"
ENUM = "enum HelpSection {\n  alpha,\n  beta,\n}\n"


def run_main(argv: list[str]) -> tuple[int, str, str]:
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        code = tool.main(argv)
    return code, out.getvalue(), err.getvalue()


def make_repo(root: Path, manifest: str = MANIFEST, enum: str = ENUM,
              md: tuple[str, ...] = ("help/alpha.md", "help/beta.md", "faq/one.md")) -> Path:
    content = root / "mobile-app" / "assets" / "content"
    content.mkdir(parents=True, exist_ok=True)
    (content / "manifest.yaml").write_text(manifest, encoding="utf-8")
    for rel in md:
        (content / rel).parent.mkdir(parents=True, exist_ok=True)
        (content / rel).write_text("text\n", encoding="utf-8")
    screens = root / "mobile-app" / "lib" / "ui" / "screens"
    screens.mkdir(parents=True, exist_ok=True)
    (screens / "help_screen.dart").write_text(enum, encoding="utf-8")
    return root


class ValidateTests(unittest.TestCase):
    def check(self, **kwargs) -> tuple[int, str, str]:
        with tempfile.TemporaryDirectory() as tmp:
            repo = make_repo(Path(tmp), **kwargs)
            return run_main(["--repo-root", str(repo)])

    def test_consistent_tree_passes(self) -> None:
        code, out, err = self.check()
        self.assertEqual(code, 0, out + err)
        self.assertEqual(out.splitlines(), [
            "[OK] Content manifest is consistent with disk and HelpSection enum",
            "     Manifest entries: 3",
            "     Content .md files: 3",
        ])

    def test_check1_missing_file(self) -> None:
        code, out, _ = self.check(md=("help/alpha.md", "faq/one.md"))
        self.assertEqual(code, 1)
        self.assertIn("[FAIL] 1 drift issue(s) found:", out)
        self.assertIn("  - [Check 1] Manifest entry 'help.beta' references missing file: help/beta.md", out)

    def test_check1_path_outside_content_dir_and_directory(self) -> None:
        manifest = MANIFEST + "  esc: ../outside.md\n"
        code, out, _ = self.check(manifest=manifest)
        self.assertEqual(code, 1)
        self.assertIn("[Check 1] Manifest entry 'faq.esc' points outside the content folder", out)
        with tempfile.TemporaryDirectory() as tmp:
            repo = make_repo(Path(tmp), manifest=MANIFEST + "  dirkey: faq/folder.md\n")
            (repo / "mobile-app" / "assets" / "content" / "faq" / "folder.md").mkdir()
            code, out, _ = run_main(["--repo-root", str(repo)])
        self.assertEqual(code, 1)
        self.assertIn("'faq.dirkey' references missing file: faq/folder.md", out)

    def test_check2_orphan_and_audit_log_exemption(self) -> None:
        code, out, _ = self.check(md=("help/alpha.md", "help/beta.md", "faq/one.md", "help/orphan.md",
                                      "audit-log.md"))
        self.assertEqual(code, 1)
        self.assertIn("[Check 2] Orphan content file (not in manifest): help/orphan.md", out)
        self.assertNotIn("audit-log.md", out)

    def test_check2_duplicate_reference_and_duplicate_key(self) -> None:
        code, out, _ = self.check(manifest=MANIFEST + "  two: faq/one.md\n")
        self.assertEqual(code, 1)
        self.assertIn("[Check 2] Duplicate manifest reference: faq/one.md referenced 2 times", out)
        code, out, _ = self.check(manifest=MANIFEST + "  one: faq/one.md\n")
        self.assertEqual(code, 1)
        self.assertIn("[Check 2] Duplicate manifest key: faq.one", out)

    def test_check3_enum_case_without_entry(self) -> None:
        code, out, _ = self.check(enum="enum HelpSection {\n  alpha,\n  beta,\n  one,\n}\n")
        self.assertEqual(code, 1)
        self.assertIn("[Check 3] HelpSection.one has no manifest entry under help: namespace", out)

    def test_check3_unparseable_enum(self) -> None:
        code, out, _ = self.check(enum="class X {}\n")
        self.assertEqual(code, 1)
        self.assertIn("[Check 3] Could not parse HelpSection enum from help_screen.dart", out)

    def test_unrecognized_manifest_line(self) -> None:
        code, out, _ = self.check(manifest=MANIFEST + "  quoted: 'faq/one.md'\n")
        self.assertEqual(code, 1)
        self.assertIn("[Parse] Unrecognized manifest line 8: quoted: 'faq/one.md'", out)

    def test_empty_and_missing_inputs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            code, _, err = run_main(["--repo-root", tmp])
            self.assertEqual(code, 1)
            self.assertIn("Manifest not found", err)
            repo = make_repo(Path(tmp))
            (repo / "mobile-app" / "lib" / "ui" / "screens" / "help_screen.dart").unlink()
            code, _, err = run_main(["--repo-root", str(repo)])
            self.assertEqual(code, 1)
            self.assertIn("help_screen.dart not found", err)
        code, _, err = self.check(manifest="# only a comment\n")
        self.assertEqual(code, 1)
        self.assertIn("Manifest is empty", err)
        code, _, err = self.check(manifest="  orphan: help/alpha.md\n")
        self.assertEqual(code, 1)
        self.assertIn("appears before any namespace heading", err)

    def test_verbose_prints_parse_lines(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = make_repo(Path(tmp))
            code, out, _ = run_main(["--repo-root", str(repo), "--verbose"])
        self.assertEqual(code, 0)
        self.assertIn("[parse] namespace: help", out)
        self.assertIn("[parse]   help.alpha -> help/alpha.md", out)
        self.assertIn("[parse] HelpSection cases found: 2", out)

    def test_real_repo_manifest_is_consistent(self) -> None:
        code, out, err = run_main([])
        self.assertEqual(code, 0, out + err)
        self.assertIn("[OK] Content manifest is consistent", out)


if __name__ == "__main__":
    unittest.main()
