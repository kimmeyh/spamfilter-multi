"""Unit tests for scripts/start-test-imap-servers.py (F331).

No test starts GreenMail, WSL or Dovecot, and none downloads from the network. The live start, connect and stop
check (F331 AC-2) is run by hand and recorded in the progress notes, not here.
Run: python -I -m unittest discover -s scripts/tests -v

What these tests do NOT catch: that GreenMail binds and serves IMAP under a real java (the live AC-2 run does that),
the WSL Dovecot path (Windows only; not exercised here), the process search and kill in find_greenmail_pids and
kill_pid (they call powershell or ps and are checked by the live run), and the quoting of the WSL keepalive command.
"""
from __future__ import annotations

import contextlib
import hashlib
import importlib.util
import io
import socket
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
sys.path.insert(0, str(SCRIPTS.parent / ".claude" / "hooks" / "lib"))
import common  # noqa: E402


def load_module():
    spec = importlib.util.spec_from_file_location("start_test_imap_servers",
                                                  SCRIPTS / "start-test-imap-servers.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


MOD = load_module()


def free_port() -> int:
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


class PortTests(unittest.TestCase):
    def test_port_in_use_is_true_for_a_listening_socket(self):
        with socket.socket() as server:
            server.bind(("127.0.0.1", 0))
            server.listen(1)
            self.assertTrue(MOD.port_in_use(server.getsockname()[1]))

    def test_port_in_use_is_false_for_a_free_port(self):
        self.assertFalse(MOD.port_in_use(free_port()))

    def test_wait_for_port_gives_up_on_a_closed_port(self):
        self.assertFalse(MOD.wait_for_port(free_port(), tries=2, delay=0.01))

    def test_wait_for_port_succeeds_once_a_port_listens(self):
        with socket.socket() as server:
            server.bind(("127.0.0.1", 0))
            server.listen(1)
            self.assertTrue(MOD.wait_for_port(server.getsockname()[1], tries=2, delay=0.01))


class JarTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)
        self.payload = b"fake jar bytes"
        self.source = self.dir / "source.jar"
        self.source.write_bytes(self.payload)

    def tearDown(self):
        self._tmp.cleanup()

    def test_matching_checksum_writes_the_jar(self):
        sha_file = self.dir / "source.sha1"
        sha_file.write_text(hashlib.sha1(self.payload).hexdigest() + "  greenmail.jar\n", encoding="ascii")
        work = self.dir / "work"
        jar = MOD.ensure_jar(work, jar_url=self.source.as_uri(), sha_url=sha_file.as_uri())
        self.assertEqual(jar.read_bytes(), self.payload)

    def test_checksum_mismatch_fails_and_leaves_no_jar(self):
        sha_file = self.dir / "wrong.sha1"
        sha_file.write_text("0" * 40 + "\n", encoding="ascii")
        work = self.dir / "work"
        with self.assertRaises(MOD.StartError) as caught:
            MOD.ensure_jar(work, jar_url=self.source.as_uri(), sha_url=sha_file.as_uri())
        self.assertIn("checksum mismatch", str(caught.exception))
        self.assertFalse((work / MOD.JAR_NAME).exists())

    def test_existing_jar_is_reused_without_download(self):
        work = self.dir / "work"
        work.mkdir()
        (work / MOD.JAR_NAME).write_bytes(b"already here")
        unreachable = (self.dir / "missing.jar").as_uri()
        jar = MOD.ensure_jar(work, jar_url=unreachable, sha_url=unreachable)
        self.assertEqual(jar.read_bytes(), b"already here")


class StartGreenMailTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def test_busy_port_refuses_to_start_and_launches_nothing(self):
        with socket.socket() as holder:
            holder.bind(("127.0.0.1", 0))
            holder.listen(1)
            busy = holder.getsockname()[1]
            with mock.patch.object(subprocess, "Popen", side_effect=AssertionError("must not launch")):
                with self.assertRaises(MOD.StartError) as caught:
                    MOD.start_greenmail(self.dir, self.dir / "x.jar", "java", None, busy, False)
        self.assertIn("already in use", str(caught.exception))
        self.assertEqual(caught.exception.code, 1)

    def test_failed_keytool_stops_before_java_starts(self):
        # keytool is replaced by a stub that exits 2 (the code python itself returns for unknown options).
        # Popen is not patched here: subprocess.run calls Popen internally, so the java launch is checked
        # by the separate Popen patch below, which must never be reached.
        failed = subprocess.CompletedProcess([], 2)
        with mock.patch.object(subprocess, "run", return_value=failed), \
                mock.patch.object(subprocess, "Popen", side_effect=AssertionError("java must not launch")):
            with self.assertRaises(MOD.StartError) as caught:
                MOD.start_greenmail(self.dir, self.dir / "x.jar", "java", "C:/fake/keytool", free_port(), True)
        self.assertIn("keytool failed (exit 2)", str(caught.exception))


class MainTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def run_main(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = MOD.main([*argv, "--work-dir", str(self.dir)])
        return code, out.getvalue(), err.getvalue()

    def test_java_missing_exits_1_before_anything_is_stopped(self):
        def no_java(*names):
            return None if names[0] == "java" else f"C:/fake/{names[0]}"
        with mock.patch.object(common, "find_tool", side_effect=no_java), \
                mock.patch.object(MOD, "stop_greenmail", side_effect=AssertionError("must not stop")):
            code, _out, err = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("java not found", err)

    def test_busy_greenmail_port_exits_1_and_launches_nothing(self):
        (self.dir / MOD.JAR_NAME).write_bytes(b"jar")
        with socket.socket() as holder:
            holder.bind(("127.0.0.1", 0))
            holder.listen(1)
            busy = holder.getsockname()[1]
            with mock.patch.object(MOD, "GREENMAIL_PORT", busy), \
                    mock.patch.object(MOD, "stop_greenmail", return_value=[]), \
                    mock.patch.object(common, "find_tool", side_effect=lambda *n: f"C:/fake/{n[0]}"), \
                    mock.patch.object(subprocess, "Popen", side_effect=AssertionError("must not launch")):
                code, _out, err = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("already in use", err)

    def test_stop_option_stops_greenmail_and_exits_0(self):
        with mock.patch.object(MOD, "stop_greenmail", return_value=["Stopped GreenMail (pid 1)"]) as stop, \
                mock.patch.object(MOD, "stop_dovecot", return_value="Dovecot in WSL was not running.") as dov, \
                mock.patch.object(sys, "platform", "linux"):
            code, out, _err = self.run_main("--stop")
        self.assertEqual(code, 0)
        self.assertEqual(stop.call_count, 1)
        self.assertEqual(dov.call_count, 0)
        self.assertIn("Stopped GreenMail", out)


if __name__ == "__main__":
    unittest.main()
