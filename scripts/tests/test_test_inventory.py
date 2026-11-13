"""Tests for scripts/test-inventory.py (F350, Sprint 85): import parser, kind classification, tier rule,
workflow parsing, discovery and the reporter parser, each with failure-path cases.

Run: python -I -m unittest discover -s scripts/tests -v
What these tests do NOT catch: the real git history and gh output (the git and gh calls are not
replayed here), and whether a tier or "where it runs" value is the RIGHT judgment; they prove the
rules do what the docstring of the script says.
"""
from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
_spec = importlib.util.spec_from_file_location("test_inventory", REPO / "scripts" / "test-inventory.py")
inv = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(inv)

CI_SAMPLE = """\
name: CI
jobs:
  analyze-and-test:
    name: Analyze and Test
    runs-on: ubuntu-latest
    steps:
      - name: Python hook layer tests
        run: python3 .claude/hooks/tests/test_pylib.py
      - name: flutter test
        run: flutter test
  windows-build:
    name: Windows Build Verification
    runs-on: windows-latest
    steps:
      - run: flutter build windows --release
"""

IOS_SAMPLE = """\
name: iOS
jobs:
  ios-simulator:
    name: iOS Simulator tests
    runs-on: macos-26
    env:
      EXCLUDED_TESTS: 'skipped_test.dart'
    steps:
      - run: |
          for f in integration_test/*_test.dart; do
            name=$(basename "$f")
            [ "$name" = "screens_test.dart" ] && continue
            flutter test "$f" -d "${UDID}"
          done
  ios-simulator-screens:
    name: iOS Simulator screens
    runs-on: macos-26
    steps:
      - run: flutter test integration_test/screens_test.dart -d "${{ steps.sims.outputs.iphone_id }}"
"""


def make_tree(root: Path, files: dict[str, str]) -> None:
    for rel, text in files.items():
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")


class ImportParser(unittest.TestCase):
    def test_package_relative_helper_and_file_reads(self):
        text = (
            "import 'dart:io';\n"
            "import 'package:flutter_test/flutter_test.dart';\n"
            "import 'package:my_email_spam_filter/core/services/email_scanner.dart';\n"
            "import '../../lib/core/storage/settings_store.dart';\n"
            "import '../helpers/fake.dart';\n"
            "// import 'package:my_email_spam_filter/core/services/commented_out.dart';\n"
            "void main() { File('lib/core/services/read_only.dart'); }\n")
        got = inv.parse_dart_imports(text, "test/unit")
        self.assertEqual(got["lib_imports"], ["lib/core/services/email_scanner.dart",
                                              "lib/core/storage/settings_store.dart"])
        self.assertEqual(got["test_imports"], ["test/helpers/fake.dart"])
        self.assertEqual(got["lib_reads"], ["lib/core/services/read_only.dart"])

    def test_no_imports_gives_empty_lists(self):
        got = inv.parse_dart_imports("void main() {}\n", "test")
        self.assertEqual(got, {"lib_imports": [], "test_imports": [], "lib_reads": []})

    def test_read_of_an_imported_file_is_not_listed_twice(self):
        text = ("import 'package:my_email_spam_filter/a/b.dart';\n"
                "void main() { File('lib/a/b.dart'); }\n")
        got = inv.parse_dart_imports(text, "test")
        self.assertEqual(got["lib_reads"], [])


class KindClassification(unittest.TestCase):
    def test_kinds(self):
        c = inv.classify_kind
        self.assertEqual(c("mobile-app/test/policy/x_test.dart", "testWidgets(", "dart"), "policy")
        self.assertEqual(c("mobile-app/integration_test/x_test.dart", "", "dart"), "integration")
        self.assertEqual(c("mobile-app/test/integration/x_test.dart", "", "dart"), "integration")
        self.assertEqual(c("mobile-app/test/ui/x_test.dart", "  testWidgets('a', (t) async {});", "dart"), "widget")
        self.assertEqual(c("mobile-app/test/unit/x_test.dart", "test('a', () {});", "dart"), "unit")
        self.assertEqual(c("x.json", "", "winwright"), "winwright")
        self.assertEqual(c("x", "", "hook-case"), "hook-case")
        self.assertEqual(c("x.py", "", "python-unittest"), "python-unittest")

    def test_policy_wins_over_widget(self):
        self.assertEqual(inv.classify_kind("mobile-app/test/policy/w_test.dart", "testWidgets(", "dart"), "policy")


class TierRule(unittest.TestCase):
    def test_matrix(self):
        t = inv.tier_for
        expect = {("high", "high"): "high", ("high", "medium"): "high", ("high", "low"): "medium",
                  ("normal", "high"): "medium", ("normal", "medium"): "low", ("normal", "low"): "low"}
        for (impact, like), tier in expect.items():
            self.assertEqual(t(impact, like), tier, (impact, like))

    def test_likelihood_boundaries(self):
        self.assertEqual(inv.likelihood_of(inv.LIKELIHOOD_HIGH), "high")
        self.assertEqual(inv.likelihood_of(inv.LIKELIHOOD_HIGH - 1), "medium")
        self.assertEqual(inv.likelihood_of(inv.LIKELIHOOD_MEDIUM), "medium")
        self.assertEqual(inv.likelihood_of(inv.LIKELIHOOD_MEDIUM - 1), "low")
        self.assertEqual(inv.likelihood_of(0), "low")

    def test_high_impact_lib_paths(self):
        i = inv.impact_of_lib
        self.assertEqual(i("lib/adapters/email_providers/generic_imap_adapter.dart"), "deletes or moves mail")
        self.assertEqual(i("lib/adapters/auth/secure_token_store.dart"), "credentials")
        self.assertEqual(i("lib/core/services/scan_coordinator.dart"), "scan coordinator")
        self.assertEqual(i("lib/core/services/background_scan_core.dart"), "background workers")
        self.assertEqual(i("lib/core/services/android_background_scan_worker.dart"), "background workers")
        self.assertEqual(i("lib/core/storage/migration_manager.dart"), "database migrations")

    def test_unrelated_lib_paths_are_not_high_impact(self):
        for p in ("lib/core/models/rule_set.dart", "lib/ui/screens/help_screen.dart",
                  "lib/core/storage/database_helper.dart", "lib/core/utils/app_logger.dart"):
            self.assertIsNone(inv.impact_of_lib(p), p)


class GuardSummary(unittest.TestCase):
    def test_doc_comment_first_line(self):
        text = "import 'x';\n\n/// Policy gate (Sprint 59): strings.\n/// More.\nvoid main() {}\n"
        self.assertEqual(inv.guard_summary(text, "dart"), "Policy gate (Sprint 59): strings.")

    def test_ignore_for_file_is_skipped(self):
        text = "// ignore_for_file: avoid_print\n// Real purpose here\nvoid main() {}\n"
        self.assertEqual(inv.guard_summary(text, "dart"), "Real purpose here")

    def test_group_names_then_unknown(self):
        self.assertTrue(inv.guard_summary("void main() { group('Alpha', () {}); }", "dart").startswith("groups: Alpha"))
        self.assertTrue(inv.guard_summary("void main() { test('beta', () {}); }", "dart").startswith("tests: beta"))
        self.assertEqual(inv.guard_summary("void main() {}", "dart"), "unknown")

    def test_winwright_description_and_bad_json(self):
        good = json.dumps({"description": "First sentence. Second sentence."})
        self.assertEqual(inv.guard_summary(good, "winwright"), "First sentence.")
        self.assertEqual(inv.guard_summary("{not json", "winwright"), "unknown")
        self.assertEqual(inv.guard_summary("{}", "winwright"), "unknown")

    def test_python_docstring(self):
        self.assertEqual(inv.guard_summary('"""Does a thing.\n\nMore."""\n', "python-unittest"), "Does a thing.")
        self.assertEqual(inv.guard_summary("import os\n", "python-unittest"), "unknown")


class WorkflowParsing(unittest.TestCase):
    def setUp(self):
        self.jobs = list(inv.parse_workflow(CI_SAMPLE, "ci.yml").values()) + \
            list(inv.parse_workflow(IOS_SAMPLE, "ios.yml").values())

    def test_full_suite_only_in_the_analyze_job(self):
        full = [j["name"] for j in self.jobs if j["full_dart_suite"]]
        self.assertEqual(full, ["Analyze and Test"])

    def test_integration_loop_exclusions_and_moves(self):
        sim = next(j for j in self.jobs if j["name"] == "iOS Simulator tests")
        self.assertTrue(sim["integration_loop"])
        self.assertEqual(sim["excluded"], ["skipped_test.dart"])
        self.assertEqual(sim["moved"], ["screens_test.dart"])

    def test_where_it_runs_dart_unit_and_integration(self):
        unit = inv.where_it_runs("mobile-app/test/unit/a_test.dart", "dart", self.jobs)
        self.assertEqual(len(unit), 2)
        self.assertIn("ci-linux (ci.yml:Analyze and Test)", unit)
        norm = inv.where_it_runs("mobile-app/integration_test/normal_test.dart", "dart", self.jobs)
        self.assertIn("ios-simulator (ios.yml:iOS Simulator tests)", norm)
        screens = inv.where_it_runs("mobile-app/integration_test/screens_test.dart", "dart", self.jobs)
        self.assertEqual([r for r in screens if r.startswith("ios-simulator")],
                         ["ios-simulator (ios.yml:iOS Simulator screens)"])
        skipped = inv.where_it_runs("mobile-app/integration_test/skipped_test.dart", "dart", self.jobs)
        self.assertEqual([r for r in skipped if r.startswith("ios-simulator")], [])
        self.assertTrue(any(r.startswith("EXCLUDED") for r in skipped))

    def test_windows_build_job_runs_no_dart_test(self):
        runs = inv.where_it_runs("mobile-app/test/unit/a_test.dart", "dart", self.jobs)
        self.assertFalse(any("Windows Build" in r for r in runs))

    def test_hook_cases_and_winwright(self):
        hook = inv.where_it_runs(".claude/hooks/test-cases/staging-guard", "hook-case", self.jobs)
        self.assertTrue(any(r.startswith("ci-linux") for r in hook))
        ww = inv.where_it_runs("mobile-app/test/winwright/test_x.json", "winwright", self.jobs)
        self.assertEqual(len(ww), 1)
        self.assertTrue(ww[0].startswith("local only"))

    def test_empty_workflow_text(self):
        self.assertEqual(inv.parse_workflow("", "x.yml"), {})

    def test_platforms(self):
        runs = ["local: flutter test (Windows host)", "ci-linux (ci.yml:Analyze and Test)",
                "EXCLUDED in ios-simulator (ios.yml:x)"]
        self.assertEqual(inv.platforms_for(runs, "dart"), ["ci-linux", "windows-host"])


class Discovery(unittest.TestCase):
    def test_discovery_rule(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            make_tree(root, {
                "mobile-app/test/a_test.dart": "",
                "mobile-app/test/new_dir/deep/c_test.dart": "",
                "mobile-app/test/scratch/hidden_test.dart": "",
                "mobile-app/test/helpers/helper.dart": "",
                "mobile-app/test/not_a_testfile.dart": "",
                "mobile-app/integration_test/d_test.dart": "",
                "mobile-app/integration_test/helpers/app_harness.dart": "",
                "mobile-app/test/winwright/test_x.json": "{}",
                "mobile-app/test/winwright/README.md": "",
                "mobile-app/test/e2e/smoke.json": "{}",
                ".claude/hooks/test-cases/closeout/c1.json": "{}",
                ".claude/hooks/test-cases/closeout/c2.json": "{}",
                ".claude/hooks/test-cases/fixtures/f/x.json": "{}",
                ".claude/hooks/test-cases/top1.json": "{}",
                ".claude/hooks/test-cases/empty/readme.txt": "",
                ".claude/hooks/tests/test_pylib.py": "",
                ".claude/hooks/tests/helper_lib.py": "",
                "scripts/tests/test_one.py": "",
            })
            got = {a["path"]: a for a in inv.discover(root)}
            self.assertEqual(set(got), {
                "mobile-app/test/a_test.dart", "mobile-app/test/new_dir/deep/c_test.dart",
                "mobile-app/integration_test/d_test.dart", "mobile-app/test/winwright/test_x.json",
                "mobile-app/test/e2e/smoke.json", ".claude/hooks/test-cases/closeout",
                ".claude/hooks/test-cases", ".claude/hooks/tests/test_pylib.py", "scripts/tests/test_one.py"})
            self.assertEqual(got[".claude/hooks/test-cases/closeout"]["case_count"], 2)
            self.assertEqual(got[".claude/hooks/test-cases"]["case_count"], 1)

    def test_missing_folders_give_an_empty_list(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(inv.discover(Path(tmp)), [])

    def test_real_repo_lists_the_policy_test_and_every_dart_test(self):
        listed = {a["path"] for a in inv.discover()}
        self.assertIn("mobile-app/test/policy/test_inventory_coverage_test.dart", listed)
        on_disk = {p.relative_to(REPO).as_posix() for p in (REPO / "mobile-app" / "test").rglob("*_test.dart")
                   if "scratch" not in p.relative_to(REPO / "mobile-app" / "test").parts[:-1]}
        self.assertEqual(on_disk - listed, set())


class Helpers(unittest.TestCase):
    def test_fix_subject(self):
        for s in ("fix: a", "fix(F220): a", "Fix: a", "fix!: a", "fix the thing"):
            self.assertTrue(inv.FIX_SUBJECT.match(s), s)
        for s in ("fixture: a", "prefix: a", "docs: fix a", "feat: a", "fixes #1", "chore: fix"):
            self.assertFalse(inv.FIX_SUBJECT.match(s), s)

    def test_owner_of(self):
        self.assertEqual(inv.owner_of(".claude/hooks/test-cases/closeout/x.json"), ".claude/hooks/test-cases/closeout")
        self.assertEqual(inv.owner_of(".claude/hooks/test-cases/top.json"), ".claude/hooks/test-cases")
        self.assertEqual(inv.owner_of(".claude/hooks/test-cases/fixtures/a/x.json"),
                         ".claude/hooks/test-cases/fixtures/a/x.json")
        self.assertEqual(inv.owner_of("mobile-app/test/a_test.dart"), "mobile-app/test/a_test.dart")

    def test_reporter_output(self):
        lines = [
            {"type": "testStart", "test": {"id": 1, "name": "loading x_test.dart"}},
            {"type": "testDone", "testID": 1, "result": "success", "hidden": False},
            {"type": "testStart", "test": {"id": 2, "name": "a"}},
            {"type": "testDone", "testID": 2, "result": "success", "hidden": False},
            {"type": "testDone", "testID": 3, "result": "failure", "hidden": False},
            {"type": "testDone", "testID": 4, "result": "success", "skipped": True, "hidden": False},
            {"type": "done", "success": False},
        ]
        out = "\n".join(json.dumps(x) for x in lines) + "\nnot json at all\n[1, 2]\n"
        got = inv.parse_reporter_output(out)
        self.assertEqual((got["tests_passed"], got["tests_failed"], got["tests_skipped"], got["suite_success"]),
                         (1, 1, 1, False))
        self.assertEqual(inv.parse_reporter_output("")["tests_passed"], 0)

    def test_job_durations(self):
        view = {"jobs": [{"name": "J", "conclusion": "success", "startedAt": "2026-11-01T10:00:00Z",
                          "completedAt": "2026-11-01T10:08:00Z",
                          "steps": [{"name": "s", "conclusion": "success", "startedAt": "2026-11-01T10:00:10Z",
                                     "completedAt": "2026-11-01T10:01:10Z"},
                                    {"name": "never", "conclusion": "skipped", "startedAt": None, "completedAt": None}]}]}
        got = inv.job_durations(view)
        self.assertEqual(got[0]["seconds"], 480)
        self.assertEqual(got[0]["steps"][0]["seconds"], 60)
        self.assertIsNone(got[0]["steps"][1]["seconds"])
        self.assertEqual(inv.job_durations({}), [])

    def test_job_duration_is_none_for_a_skipped_or_backwards_job(self):
        def view(conclusion, start, end):
            return {"jobs": [{"name": "J", "conclusion": conclusion, "startedAt": start, "completedAt": end,
                              "steps": []}]}
        # skipped, even when the times look forward
        self.assertIsNone(inv.job_durations(view("skipped", "2026-11-01T10:00:00Z", "2026-11-01T10:05:00Z"))[0]["seconds"])
        # completedAt before startedAt on a job that was not skipped
        self.assertIsNone(inv.job_durations(view("failure", "2026-11-01T10:05:00Z", "2026-11-01T10:00:00Z"))[0]["seconds"])
        # a good job keeps its duration
        self.assertEqual(inv.job_durations(view("success", "2026-11-01T10:00:00Z", "2026-11-01T10:05:00Z"))[0]["seconds"], 300)


if __name__ == "__main__":
    unittest.main()
