"""Unit tests for scripts/setup-claude-mcp.py (F331).

Every test writes to a temporary folder through --config-file. No test touches the real ~/.claude.json.
Run: python -I -m unittest discover -s scripts/tests -v

What these tests do NOT catch: whether Claude Code reads the written file (a live check in a Claude session is
needed), whether the npm package @modelcontextprotocol/server-github still exists, and whether a real GITHUB_TOKEN
is accepted by GitHub.
"""
from __future__ import annotations

import contextlib
import hashlib
import importlib.util
import io
import json
import os
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
    spec = importlib.util.spec_from_file_location("setup_claude_mcp", SCRIPTS / "setup-claude-mcp.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


MOD = load_module()


def fake_find_tool(*names):
    """Stand-in for common.find_tool: every tool is found at a fake path."""
    return f"C:/fake/{names[0]}"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class SetupClaudeMcpTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)
        self.config = self.dir / "claude.json"
        self.env = mock.patch.dict(os.environ, {"GITHUB_TOKEN": "TESTTOKEN123"})
        self.env.start()
        self.find = mock.patch.object(common, "find_tool", side_effect=fake_find_tool)
        self.find.start()

    def tearDown(self):
        self.find.stop()
        self.env.stop()
        self._tmp.cleanup()

    def run_main(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = MOD.main([*argv, "--config-file", str(self.config)])
        return code, out.getvalue(), err.getvalue()

    def backups(self) -> list[Path]:
        return sorted(p for p in self.dir.iterdir() if p.name.endswith(".bak"))

    def test_no_server_selected_exits_1_and_writes_nothing(self):
        code, _out, err = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("No MCP servers selected", err)
        self.assertFalse(self.config.exists())

    def test_node_not_found_exits_1_and_writes_nothing(self):
        def no_node(*names):
            return None if names[0] == "node" else fake_find_tool(*names)
        with mock.patch.object(common, "find_tool", side_effect=no_node):
            code, _out, err = self.run_main("--install-github")
        self.assertEqual(code, 1)
        self.assertIn("Node.js not found", err)
        self.assertFalse(self.config.exists())

    def test_unparseable_config_exits_1_and_is_left_untouched(self):
        self.config.write_text("{ not json", encoding="utf-8")
        before = digest(self.config)
        code, _out, err = self.run_main("--install-github")
        self.assertEqual(code, 1)
        self.assertIn("not valid JSON", err)
        self.assertEqual(digest(self.config), before)
        self.assertEqual(self.backups(), [])

    def test_mcp_servers_not_an_object_exits_1(self):
        self.config.write_text(json.dumps({"mcpServers": ["x"]}), encoding="utf-8")
        code, _out, err = self.run_main("--install-github")
        self.assertEqual(code, 1)
        self.assertIn("is not a JSON object", err)

    def test_existing_keys_are_kept_and_backup_is_written_first(self):
        original = {"numStartups": 5, "mcpServers": {"other": {"command": "x"}}}
        self.config.write_text(json.dumps(original), encoding="utf-8")
        original_bytes = self.config.read_bytes()
        code, _out, _err = self.run_main("--install-github")
        self.assertEqual(code, 0)
        data = json.loads(self.config.read_text(encoding="utf-8"))
        self.assertEqual(data["numStartups"], 5)
        self.assertEqual(data["mcpServers"]["other"], {"command": "x"})
        self.assertEqual(data["mcpServers"]["github"]["env"]["GITHUB_TOKEN"], "TESTTOKEN123")
        backups = self.backups()
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), original_bytes)

    def test_dry_run_prints_change_and_writes_nothing(self):
        self.config.write_text(json.dumps({"numStartups": 1}), encoding="utf-8")
        before = digest(self.config)
        code, out, _err = self.run_main("--install-github", "--dry-run")
        self.assertEqual(code, 0)
        self.assertIn("[DRY RUN]", out)
        self.assertIn('"github"', out)
        self.assertEqual(digest(self.config), before)
        self.assertEqual(self.backups(), [])

    def test_dry_run_on_missing_file_creates_nothing(self):
        code, out, _err = self.run_main("--install-github", "--dry-run")
        self.assertEqual(code, 0)
        self.assertIn('"github"', out)
        self.assertFalse(self.config.exists())

    def test_second_run_is_a_no_op_with_no_new_backup(self):
        self.config.write_text(json.dumps({"numStartups": 1}), encoding="utf-8")
        self.run_main("--install-github")
        first = digest(self.config)
        code, out, _err = self.run_main("--install-github")
        self.assertEqual(code, 0)
        self.assertIn("No change needed", out)
        self.assertEqual(digest(self.config), first)
        self.assertEqual(len(self.backups()), 1)

    def test_placeholder_token_is_written_only_with_a_warning(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            code, out, _err = self.run_main("--install-github")
        self.assertEqual(code, 0)
        self.assertIn("GITHUB_TOKEN not set", out)
        data = json.loads(self.config.read_text(encoding="utf-8"))
        self.assertEqual(data["mcpServers"]["github"]["env"]["GITHUB_TOKEN"], "YOUR_GITHUB_TOKEN_HERE")

    def test_placeholder_options_change_nothing_and_say_so(self):
        code, out, _err = self.run_main("--install-flutter", "--install-yaml", "--install-regex")
        self.assertEqual(code, 0)
        self.assertIn("no MCP server exists", out)
        self.assertNotIn("Creating custom YAML", out)
        self.assertFalse(self.config.exists())


if __name__ == "__main__":
    unittest.main()
