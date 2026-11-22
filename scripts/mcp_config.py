"""Read, back up and write the user-level Claude Code MCP configuration (F331, Sprint 85).

Used by scripts/install-custom-mcp.py and scripts/setup-claude-mcp.py. Standard library only (ADR-0051).

The user-scope file is ~/.claude.json, top-level key "mcpServers" (Claude Code MCP documentation:
https://code.claude.com/docs/en/mcp). The PowerShell originals wrote ~/.claude/config.json, which Claude Code
does not read for MCP servers (F331 port review).

Rules every writer here follows:
  - an unparseable file (or one whose top level is not a JSON object) is an error; nothing is written;
  - every top-level key other than the ones a script sets is kept as it was;
  - before any write to an existing file, a timestamped copy is made next to it;
  - the write goes to a temporary file in the same folder, then replaces the original in one step.
"""
from __future__ import annotations

import json
import os
import shutil
import tempfile
from datetime import datetime
from pathlib import Path


class ConfigError(Exception):
    """The configuration file exists but cannot be used. Nothing was written."""


def default_config_path() -> Path:
    """The user-scope Claude Code configuration (~/.claude.json on every OS)."""
    return Path.home() / ".claude.json"


def load_config(path: Path) -> dict:
    """The parsed object at `path`, {} when the file does not exist, or raise ConfigError."""
    if not path.exists():
        return {}
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise ConfigError(f"cannot read {path}: {exc}") from exc
    if not text.strip():
        return {}
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ConfigError(f"{path} is not valid JSON (line {exc.lineno}, column {exc.colno}): {exc.msg}") from exc
    if not isinstance(data, dict):
        raise ConfigError(f"{path} must hold a JSON object at the top level")
    return data


def render(data: dict) -> str:
    """The text that is written: two-space indent, UTF-8, trailing newline."""
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def backup_path_for(path: Path, now: datetime | None = None) -> Path:
    stamp = (now or datetime.now()).strftime("%Y%m%d-%H%M%S")
    return path.with_name(f"{path.name}.{stamp}.bak")


def backup(path: Path, now: datetime | None = None) -> Path | None:
    """Copy `path` to a timestamped sibling. Returns the copy, or None when there is no file."""
    if not path.exists():
        return None
    target = backup_path_for(path, now)
    counter = 1
    while target.exists():  # two runs in the same second must not overwrite each other
        target = target.with_name(f"{target.stem}-{counter}{target.suffix}")
        counter += 1
    shutil.copy2(path, target)
    return target


def write_atomic(path: Path, text: str) -> None:
    """Write `text` to `path` through a temporary file in the same folder, then replace."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        os.replace(tmp_name, path)
    except BaseException:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


def diff_text(before: str, after: str, path: Path) -> str:
    """A unified diff of two JSON texts, labelled with the configuration path."""
    import difflib

    lines = difflib.unified_diff(
        before.splitlines(keepends=True), after.splitlines(keepends=True),
        fromfile=f"{path} (current)", tofile=f"{path} (after)")
    return "".join(lines)
