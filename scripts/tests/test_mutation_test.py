"""Tests for scripts/mutation-test.py (F329, Sprint 85; AC-2).

Every case builds a throwaway repo (a folder holding `.claude/`, a small `mod.py` and a check script) and runs
the real `run_mutations` / `main` against it with the CLAUDE_PROJECT_DIR variable removed, so a lock is written
inside the throwaway repo and the real `.claude/mutation-locks/` is never touched.

What these tests do NOT catch: a Flutter check (`test` specs run `flutter test`, which is not installed on every
runner; the code path that builds that command is covered only by the not-found branch); a mutant that is red
for a reason that is not a compile error; Windows `cmd.exe` quoting of a command that holds many quotes (the
checks here use one quoted interpreter path and a script name).
Run: python -I -m unittest discover -s scripts/tests -v
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("mutation_test", SCRIPTS / "mutation-test.py")
mt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mt)

MOD = "def f():\n    return 1\n"
# The check exits 1 when f() is not 1, and leaves a marker so a test can tell the check RAN. It also records
# whether the mutation lock existed while it ran.
CHECK = (
    "import os, sys\n"
    "open('ran.marker', 'a').write('x')\n"
    "locks = os.path.join('.claude', 'mutation-locks')\n"
    "open('lock_seen.marker', 'a').write(str(len(os.listdir(locks)) if os.path.isdir(locks) else 0) + ',')\n"
    "import mod\n"
    "sys.exit(0 if mod.f() == 1 else 1)\n"
)


class MutationTestBase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name)
        (self.repo / ".claude").mkdir()
        (self.repo / "mod.py").write_bytes(MOD.encode("utf-8"))
        (self.repo / "check.py").write_text(CHECK, encoding="utf-8")
        env = mock.patch.dict(os.environ)
        env.start()
        self.addCleanup(env.stop)
        os.environ.pop("CLAUDE_PROJECT_DIR", None)
        self.command = f'"{sys.executable}" check.py'

    def spec(self, **over):
        base = {"name": "M1", "file": "mod.py", "find": "return 1", "replace": "return 2", "command": self.command}
        base.update(over)
        return base

    def run_one(self, **over):
        return mt.run_mutations([self.spec(**over)], self.repo)

    def lock_files(self):
        folder = self.repo / ".claude" / "mutation-locks"
        return sorted(p.name for p in folder.glob("*.json")) if folder.is_dir() else []


class VerdictTests(MutationTestBase):
    def test_killed_and_file_restored_byte_for_byte_and_lock_released(self):
        before = (self.repo / "mod.py").read_bytes()
        lines, ok = self.run_one()
        self.assertEqual(lines, ["M1: KILLED"])
        self.assertTrue(ok)
        self.assertEqual((self.repo / "mod.py").read_bytes(), before)
        self.assertEqual(self.lock_files(), [])

    def test_lock_is_held_while_the_check_runs(self):
        self.run_one()
        # ran twice: once for the baseline (no lock), once for the mutant (one lock)
        self.assertEqual((self.repo / "lock_seen.marker").read_text(), "0,1,")

    def test_survived_when_the_check_never_looks(self):
        (self.repo / "check.py").write_text("import sys\nsys.exit(0)\n", encoding="utf-8")
        lines, ok = self.run_one()
        self.assertEqual(lines, ["M1: SURVIVED"])
        self.assertFalse(ok)

    def test_baseline_fails_when_the_check_is_red_on_unchanged_code(self):
        (self.repo / "check.py").write_text("open('ran.marker', 'a').write('x')\nimport sys\nsys.exit(1)\n",
                                            encoding="utf-8")
        lines, ok = self.run_one()
        self.assertEqual(lines, ["M1: BASELINE FAILS (the check fails on unchanged code) -- not run"])
        self.assertFalse(ok)
        self.assertEqual((self.repo / "ran.marker").read_text(), "x", "only the baseline run happened")
        self.assertEqual((self.repo / "mod.py").read_text(), MOD)

    def test_baseline_false_skips_the_baseline(self):
        (self.repo / "check.py").write_text("import sys\nsys.exit(1)\n", encoding="utf-8")
        lines, _ = self.run_one(baseline=False)
        self.assertEqual(lines, ["M1: KILLED"])

    def test_check_that_cannot_start_is_not_run_never_killed(self):
        # Sprint 85 5.1.2 L1: with "baseline": false a missing command used to read KILLED.
        for code in (127, 9009):
            (self.repo / "check.py").write_text(f"import sys\nsys.exit({code})\n", encoding="utf-8")
            lines, ok = self.run_one(baseline=False)
            self.assertEqual(len(lines), 1)
            self.assertTrue(lines[0].startswith("M1: NOT RUN -- the check did not start"), lines[0])
            self.assertFalse(ok)
            self.assertEqual((self.repo / "mod.py").read_text(), MOD)
        with mock.patch.object(mt.subprocess, "Popen", side_effect=OSError("no such program")):
            lines, ok = self.run_one(baseline=False)
        self.assertTrue(lines[0].startswith("M1: NOT RUN"), lines[0])
        self.assertFalse(ok)

    def test_baseline_runs_once_per_distinct_check(self):
        specs = [self.spec(name="A"), self.spec(name="B")]
        mt.run_mutations(specs, self.repo)
        self.assertEqual((self.repo / "ran.marker").read_text(), "xxx", "1 baseline + 2 mutants")

    def test_python_syntax_error_mutant_is_invalid_and_the_check_is_not_run(self):
        lines, ok = self.run_one(replace="return (")
        self.assertEqual(len(lines), 1)
        self.assertTrue(lines[0].startswith("M1: INVALID -- the mutant did not compile (SyntaxError"), lines[0])
        self.assertFalse(ok)
        self.assertFalse((self.repo / "ran.marker").exists(), "an invalid mutant must not reach the check")
        self.assertEqual(self.lock_files(), [])

    def test_compile_error_in_check_output_is_invalid_not_killed(self):
        (self.repo / "check.py").write_text(
            "import sys\nif open('mod.py').read().count('return 2'):\n"
            "    print('SyntaxError: invalid syntax')\n    sys.exit(1)\n", encoding="utf-8")
        lines, ok = self.run_one()
        self.assertTrue(lines[0].startswith("M1: INVALID -- the mutant did not compile (SyntaxError:"), lines[0])
        self.assertFalse(ok)

    def test_dart_compile_error_in_output_is_invalid(self):
        (self.repo / "check.py").write_text(
            "import sys\nif 'return 2' in open('mod.py').read():\n"
            "    print('lib/x.dart:12:3: Error: Expected a value')\n    sys.exit(1)\n", encoding="utf-8")
        lines, _ = self.run_one()
        self.assertIn("INVALID", lines[0])

    def test_timeout_is_not_counted_killed(self):
        (self.repo / "check.py").write_text(
            "import sys, time\nif 'return 2' in open('mod.py').read():\n    time.sleep(60)\n", encoding="utf-8")
        lines, ok = self.run_one(timeout=2)
        self.assertTrue(lines[0].startswith("M1: TIMED OUT"), lines[0])
        self.assertFalse(ok)
        self.assertEqual((self.repo / "mod.py").read_text(), MOD)
        self.assertEqual(self.lock_files(), [])


class StaleBytecodeGuardTests(MutationTestBase):
    """A same-size mutant written in the same second as its source can hide behind a stale .pyc. Two defenses
    (no bytecode written during a run, and a mutant mtime moved forward) each get a test, because either alone
    already makes the verdict tests pass and a mutation of one would otherwise survive."""

    def test_the_check_runs_with_bytecode_writing_off(self):
        seen = {}
        real = mt.subprocess.Popen

        def spy(*args, **kwargs):
            seen.update(kwargs.get("env") or {})
            return real(*args, **kwargs)

        # A mutation run of THIS test file (mutation-test mutating itself) already sets the variable for the
        # test process; remove it so the check below proves invoke_check sets it, not that it was inherited.
        os.environ.pop("PYTHONDONTWRITEBYTECODE", None)
        with mock.patch.object(mt.subprocess, "Popen", spy):
            mt.invoke_check(self.spec(), self.repo)
        self.assertEqual(seen.get("PYTHONDONTWRITEBYTECODE"), "1")

    def test_the_mutant_mtime_is_moved_two_seconds_past_the_original(self):
        path = self.repo / "mod.py"
        before = path.stat().st_mtime_ns
        mt.mutate_file(path, b"x = 1\n")
        self.assertGreaterEqual(path.stat().st_mtime_ns, before + 2_000_000_000)
        self.assertEqual(path.read_bytes(), b"x = 1\n")


class KillTreeTests(unittest.TestCase):
    """The timeout kill, per platform. The POSIX branch cannot run for real on the Windows dev machine, so it is
    checked by patching os.name: this proves WHICH call is made, not that Linux then ends the group (unverified)."""

    def test_posix_kills_the_whole_process_group(self):
        proc = mock.Mock(pid=4242)
        with mock.patch.object(mt.os, "name", "posix"), mock.patch.object(mt.os, "killpg", create=True) as killpg:
            mt.kill_tree(proc)
        killpg.assert_called_once_with(4242, getattr(mt.signal, "SIGKILL", 9))
        proc.kill.assert_not_called()

    def test_posix_falls_back_to_killing_the_shell_when_the_group_is_gone(self):
        proc = mock.Mock(pid=4242)
        with mock.patch.object(mt.os, "name", "posix"), \
                mock.patch.object(mt.os, "killpg", create=True, side_effect=ProcessLookupError()):
            mt.kill_tree(proc)
        proc.kill.assert_called_once_with()

    def test_the_check_gets_its_own_session_on_posix_and_not_on_windows(self):
        for name, expected in (("posix", True), ("nt", False)):
            with self.subTest(os_name=name):
                fake = mock.Mock()
                fake.communicate.return_value = (b"", None)
                fake.returncode = 0
                with mock.patch.object(mt.os, "name", name), \
                        mock.patch.object(mt.subprocess, "Popen", return_value=fake) as popen:
                    mt.invoke_check({"command": "x"}, Path("."))
                self.assertIs(popen.call_args.kwargs["start_new_session"], expected)

    def test_windows_uses_the_taskkill_tree_helper(self):
        proc = mock.Mock(pid=4242)
        with mock.patch.object(mt.os, "name", "nt"), mock.patch.object(mt.common, "_kill_tree") as tree:
            mt.kill_tree(proc)
        tree.assert_called_once_with(proc)


class AnchorTests(MutationTestBase):
    def test_anchor_matching_zero_or_two_times_is_not_run(self):
        lines, ok = self.run_one(find="return 9")
        self.assertEqual(lines, ["M1: ANCHOR MATCHED 0 TIMES -- not run"])
        (self.repo / "mod.py").write_text("return 1\nreturn 1\n", encoding="utf-8")
        lines, _ = self.run_one()
        self.assertEqual(lines, ["M1: ANCHOR MATCHED 2 TIMES -- not run"])
        self.assertFalse(ok)
        self.assertFalse((self.repo / "ran.marker").exists())

    def test_missing_file_and_missing_check_are_reported(self):
        self.assertEqual(self.run_one(file="nope.py")[0], ["M1: FILE NOT FOUND (nope.py) -- not run"])
        spec = self.spec()
        del spec["command"]
        lines, ok = mt.run_mutations([spec], self.repo)
        self.assertEqual(lines, ["M1: spec has neither 'test' nor 'command' -- not run"])
        self.assertFalse(ok)

    def test_lf_anchor_matches_a_crlf_file_and_crlf_is_restored(self):
        crlf = b"def f():\r\n    return 1\r\n"
        (self.repo / "mod.py").write_bytes(crlf)
        lines, _ = self.run_one(find="def f():\n    return 1", replace="def f():\n    return 2")
        self.assertEqual(lines, ["M1: KILLED"])
        self.assertEqual((self.repo / "mod.py").read_bytes(), crlf)

    def test_bom_is_preserved_through_mutation_and_restore(self):
        bom = b"\xef\xbb\xbf" + MOD.encode("utf-8")
        (self.repo / "mod.py").write_bytes(bom)
        seen = []
        real = mt.invoke_check

        def spy(spec, repo):
            seen.append((repo / "mod.py").read_bytes())
            return real(spec, repo)

        with mock.patch.object(mt, "invoke_check", spy):
            lines, _ = self.run_one()
        self.assertEqual(lines, ["M1: KILLED"])
        self.assertTrue(seen[-1].startswith(b"\xef\xbb\xbf"), "the mutant keeps the BOM")
        self.assertEqual((self.repo / "mod.py").read_bytes(), bom)

    def test_non_ascii_text_round_trips(self):
        text = "def f():\n    return 1  # café •\n"
        (self.repo / "mod.py").write_bytes(text.encode("utf-8"))
        lines, _ = self.run_one(find="return 1  # café •", replace="return 2  # café •")
        self.assertEqual(lines, ["M1: KILLED"])
        self.assertEqual((self.repo / "mod.py").read_bytes(), text.encode("utf-8"))

    def test_file_that_is_not_utf8_is_not_run(self):
        (self.repo / "mod.py").write_bytes(b"return 1 \xff\xfe\n")
        lines, ok = self.run_one()
        self.assertEqual(lines, ["M1: NOT UTF-8 (mod.py) -- not run"])
        self.assertFalse(ok)


class RestoreFailureTests(MutationTestBase):
    def test_restore_failure_keeps_the_lock_reports_everything_and_stops(self):
        specs = [self.spec(name="A"), self.spec(name="B")]
        with mock.patch.object(mt, "restore", return_value=False):
            lines, ok = mt.run_mutations(specs, self.repo)
        self.assertFalse(ok)
        self.assertEqual(lines[0], "A: KILLED", "the verdict reached before the restore failure is kept")
        self.assertTrue(lines[1].startswith("A: RESTORE FAILED"), lines)
        self.assertEqual(len(lines), 2, "later mutations are not run")
        self.assertEqual(self.lock_files(), ["mod.py.json"], "the lock stays HELD")

    def test_restore_helper_detects_a_file_that_does_not_read_back_equal(self):
        path = self.repo / "mod.py"
        self.assertTrue(mt.restore(path, b"abc"))
        with mock.patch.object(Path, "read_bytes", return_value=b"other"):
            self.assertFalse(mt.restore(path, b"abc"))


class CommandLineTests(MutationTestBase):
    def run_main(self, spec_obj):
        spec_path = self.repo / "spec.json"
        spec_path.write_text(json.dumps(spec_obj), encoding="utf-8")
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = mt.main([str(spec_path), "--repo", str(self.repo)])
        return code, out.getvalue(), err.getvalue()

    def test_sample_spec_is_killed_exit_0(self):
        code, out, _ = self.run_main([self.spec()])
        self.assertEqual((code, out.strip()), (0, "M1: KILLED"))

    def test_single_object_spec_is_accepted(self):
        self.assertEqual(self.run_main(self.spec())[0], 0)

    def test_survivor_gives_exit_1(self):
        (self.repo / "check.py").write_text("import sys\nsys.exit(0)\n", encoding="utf-8")
        self.assertEqual(self.run_main([self.spec()])[0], 1)

    def test_empty_spec_is_an_error_not_a_pass(self):
        code, out, err = self.run_main([])
        self.assertEqual(code, 1)
        self.assertIn("nothing was tested", err)

    def test_unreadable_spec_is_exit_2(self):
        (self.repo / "bad.json").write_text("{not json", encoding="utf-8")
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            self.assertEqual(mt.main([str(self.repo / "bad.json"), "--repo", str(self.repo)]), 2)

    def test_spec_with_a_utf8_bom_is_read(self):
        (self.repo / "bom.json").write_bytes(b"\xef\xbb\xbf" + json.dumps([self.spec()]).encode("utf-8"))
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(mt.main([str(self.repo / "bom.json"), "--repo", str(self.repo)]), 0)


if __name__ == "__main__":
    unittest.main()
