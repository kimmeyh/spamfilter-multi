"""Unit tests for scripts/install-custom-mcp.py (F331).

No test runs npm or the real MCP server, and none writes the real ~/.claude.json: the configuration is always a file
in a temporary folder (--config-file), and the server folder is replaced by a temporary one where needed.
Run: python -I -m unittest discover -s scripts/tests -v

What these tests do NOT catch: that the real email-rule-tester server starts under the installed node (the
dry-run and live steps do that), that npm install succeeds on a machine with no network, and whether Claude Code
loads the registered server.
"""
from __future__ import annotations

import contextlib
import hashlib
import importlib.util
import io
import json
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
sys.path.insert(0, str(SCRIPTS.parent / ".claude" / "hooks" / "lib"))
import common  # noqa: E402


def load_module():
    spec = importlib.util.spec_from_file_location("install_custom_mcp", SCRIPTS / "install-custom-mcp.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


MOD = load_module()
REAL_SMOKE_TEST = MOD.smoke_test  # kept before setUp replaces MOD.smoke_test with a stub


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class InstallCustomMcpTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)
        self.config = self.dir / "claude.json"
        self.server_dir = self.dir / "server"
        self.server_dir.mkdir()
        (self.server_dir / "server.js").write_text("// test stand-in\n", encoding="utf-8")
        self.patches = [
            mock.patch.object(MOD, "MCP_DIR", self.server_dir),
            mock.patch.object(common, "find_tool", side_effect=lambda *names: f"C:/fake/{names[0]}"),
            mock.patch.object(MOD, "smoke_test", return_value=True),
        ]
        # npm is replaced by a stub that succeeds; the stub records each call so a test can check it
        self.npm_calls = mock.MagicMock(return_value=subprocess.CompletedProcess([], 0))
        self.patches.append(mock.patch.object(subprocess, "run", self.npm_calls))
        for patch in self.patches:
            patch.start()

    def tearDown(self):
        for patch in reversed(self.patches):
            patch.stop()
        self._tmp.cleanup()

    def run_main(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = MOD.main([*argv, "--config-file", str(self.config)])
        return code, out.getvalue(), err.getvalue()

    def backups(self) -> list[Path]:
        return sorted(p for p in self.dir.iterdir() if p.name.endswith(".bak"))

    def test_node_not_found_exits_1_and_writes_nothing(self):
        with mock.patch.object(common, "find_tool", return_value=None):
            code, _out, err = self.run_main("--dry-run")
        self.assertEqual(code, 1)
        self.assertIn("Node.js not found", err)
        self.assertFalse(self.config.exists())

    def test_missing_server_file_exits_1(self):
        (self.server_dir / "server.js").unlink()
        code, _out, err = self.run_main("--dry-run")
        self.assertEqual(code, 1)
        self.assertIn("MCP server file missing", err)

    def test_unparseable_config_exits_1_and_is_left_untouched(self):
        self.config.write_text("[1, 2", encoding="utf-8")
        before = digest(self.config)
        code, _out, err = self.run_main("--dry-run")
        self.assertEqual(code, 1)
        self.assertIn("not valid JSON", err)
        self.assertEqual(digest(self.config), before)

    def test_install_keeps_other_keys_and_writes_backup_first(self):
        self.config.write_text(json.dumps({"numStartups": 9, "mcpServers": {"keep": {"command": "k"}}}),
                               encoding="utf-8")
        original = self.config.read_bytes()
        code, _out, _err = self.run_main()
        self.assertEqual(code, 0)
        data = json.loads(self.config.read_text(encoding="utf-8"))
        self.assertEqual(data["numStartups"], 9)
        self.assertEqual(data["mcpServers"]["keep"], {"command": "k"})
        entry = data["mcpServers"]["email-rule-tester"]
        self.assertEqual(entry["command"], "C:/fake/node")
        self.assertEqual(entry["args"], [str(self.server_dir / "server.js")])
        backups = self.backups()
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), original)

    def test_dry_run_prints_change_and_writes_nothing(self):
        self.config.write_text(json.dumps({"numStartups": 9}), encoding="utf-8")
        before = digest(self.config)
        code, out, _err = self.run_main("--dry-run")
        self.assertEqual(code, 0)
        self.assertIn("[DRY RUN]", out)
        self.assertIn("email-rule-tester", out)
        self.assertEqual(digest(self.config), before)
        self.assertEqual(self.backups(), [])

    def test_dry_run_skips_npm_install(self):
        code, out, _err = self.run_main("--dry-run")
        self.assertEqual(code, 0)
        self.assertIn("Would run: npm install (skipped)", out)
        self.npm_calls.assert_not_called()

    def test_live_run_runs_npm_install_in_the_server_folder(self):
        code, _out, _err = self.run_main()
        self.assertEqual(code, 0)
        self.npm_calls.assert_called_once()
        args, kwargs = self.npm_calls.call_args
        self.assertEqual(args[0], ["C:/fake/npm", "install"])
        self.assertEqual(kwargs.get("cwd"), str(self.server_dir))

    def test_npm_missing_on_live_run_exits_1(self):
        def no_npm(*names):
            return None if names[0] == "npm" else f"C:/fake/{names[0]}"
        with mock.patch.object(common, "find_tool", side_effect=no_npm):
            code, _out, err = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("npm not found", err)
        self.assertFalse(self.config.exists())

    def test_smoke_test_sees_start_up_line(self):
        server = self.dir / "marker.py"
        server.write_text("import sys\nsys.stderr.write('Email Rule Tester MCP server running on stdio\\n')\n"
                          "sys.stderr.flush()\nsys.stdin.read()\n", encoding="utf-8")
        self.assertTrue(REAL_SMOKE_TEST(sys.executable, server, timeout=20.0))

    def test_smoke_test_reports_false_and_stops_a_silent_server(self):
        server = self.dir / "silent.py"
        server.write_text("import time\ntime.sleep(60)\n", encoding="utf-8")
        started = time.monotonic()
        self.assertFalse(REAL_SMOKE_TEST(sys.executable, server, timeout=1.0))
        self.assertLess(time.monotonic() - started, 20.0)


if __name__ == "__main__":
    unittest.main()
