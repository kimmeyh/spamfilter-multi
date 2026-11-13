"""Tests for mobile-app/scripts/check_scans.py (port of check_scans.ps1, F334, Sprint 85).

Each test builds a small scan_results table in a temp database with the columns the app writes
(database_helper.dart), then runs the report against it.

Run: python -I -m unittest discover -s scripts/tests -v

Test list and what each does NOT catch:
  test_report_prints_rows_newest_first_with_local_times: rows sorted by started_at descending, epoch
      milliseconds converted, NULL shown as an empty field. NOT caught: a timezone other than the test
      machine's (the conversion uses 'localtime', so the expected text is computed the same way).
  test_database_is_opened_read_only: a write through the tool's connection is refused. NOT caught: a write
      path added later that opens the file without the ro URI (the test covers the function it names).
  test_missing_database_reports_and_exits_zero: the original's "Database not found" path. NOT caught: a
      database that exists but is empty (no scan_results table).
  test_missing_table_is_a_query_failure_exit_one: a database without scan_results -> exit 1 with the reason.
      NOT caught: a locked database (SQLite then waits or reports "database is locked" as an error).
  test_default_path_is_the_current_dev_folder_not_com_example: the default location is
      %APPDATA%\\MyEmailSpamFilter\\MyEmailSpamFilter_Dev\\spam_filter.db, not the Sprint 18 com.example folder.
      NOT caught: an APPDATA value that differs from the real Windows profile (only the path shape is checked).
  test_prod_default_and_missing_appdata: prod uses the MyEmailSpamFilter folder; no APPDATA -> None.
      NOT caught: a path with a trailing space in APPDATA.
  test_limit_applies: --limit 2 shows two rows. NOT caught: a non-integer limit (argparse rejects it, exit 2).
"""
from __future__ import annotations

import contextlib
import datetime
import importlib.util
import io
import os
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parent.parent.parent
TOOL = REPO / "mobile-app" / "scripts" / "check_scans.py"
_spec = importlib.util.spec_from_file_location("check_scans_mod", TOOL)
tool = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(tool)

SCHEMA = (
    "CREATE TABLE scan_results (id INTEGER PRIMARY KEY AUTOINCREMENT, account_id TEXT NOT NULL, "
    "scan_type TEXT NOT NULL, scan_mode TEXT NOT NULL, started_at INTEGER NOT NULL, completed_at INTEGER, "
    "total_emails INTEGER NOT NULL, processed_count INTEGER NOT NULL, deleted_count INTEGER NOT NULL, "
    "status TEXT NOT NULL, folders_scanned TEXT NOT NULL)"
)


def make_db(path: Path, rows: list[tuple]) -> None:
    connection = sqlite3.connect(path)
    connection.execute(SCHEMA)
    connection.executemany(
        "INSERT INTO scan_results (account_id, scan_type, scan_mode, started_at, completed_at, total_emails, "
        "processed_count, deleted_count, status, folders_scanned) VALUES (?,?,?,?,?,?,?,?,?,?)", rows)
    connection.commit()
    connection.close()


class ReportTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.db = self.tmp / "spam_filter.db"
        # started_at is epoch milliseconds; 1_700_000_000_000 ms is 2023-11-14 22:13:20 UTC.
        make_db(self.db, [
            ("acct-a", "background", "readOnly", 1_700_000_000_000, None, 10, 10, 0, "complete", "INBOX"),
            ("acct-b", "manual", "delete", 1_700_000_500_000, 1_700_000_900_000, 5, 5, 2, "complete", "INBOX|Spam"),
        ])

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def run_main(self, *argv: str) -> tuple[int, str]:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = tool.main(list(argv))
        return code, buf.getvalue()

    def test_report_prints_rows_newest_first_with_local_times(self) -> None:
        code, out = self.run_main("--db", str(self.db))
        self.assertEqual(code, 0)
        lines = [line for line in out.splitlines() if "|" in line and not line.startswith("Query")]
        self.assertEqual(len(lines), 2)
        self.assertTrue(lines[0].startswith("2|acct-b|manual|delete|"), lines[0])
        self.assertTrue(lines[1].startswith("1|acct-a|background|readOnly|"), lines[1])
        # started_at is shown in the machine's local time, computed the same way SQLite's localtime does
        local_start = datetime.datetime.fromtimestamp(1_700_000_000).strftime("%Y-%m-%d %H:%M:%S")
        self.assertEqual(lines[1], f"1|acct-a|background|readOnly|{local_start}||10|10|0|complete|INBOX")

    def test_database_is_opened_read_only(self) -> None:
        connection = tool.open_readonly(self.db)  # the tool's own connection, not a test-made one
        try:
            with self.assertRaises(sqlite3.OperationalError):
                connection.execute("DELETE FROM scan_results")
        finally:
            connection.close()
        # and the report itself still works through the same URI form
        self.assertEqual(len(tool.query_rows(self.db, 20)), 2)

    def test_missing_database_reports_and_exits_zero(self) -> None:
        code, out = self.run_main("--db", str(self.tmp / "absent.db"))
        self.assertEqual(code, 0)
        self.assertIn("Database not found at:", out)

    def test_missing_table_is_a_query_failure_exit_one(self) -> None:
        empty = self.tmp / "empty.db"
        sqlite3.connect(empty).close()
        with contextlib.redirect_stderr(io.StringIO()) as err:
            code, _out = self.run_main("--db", str(empty))
        self.assertEqual(code, 1)
        self.assertIn("Query failed", err.getvalue())

    def test_default_path_is_the_current_dev_folder_not_com_example(self) -> None:
        with mock.patch.dict(os.environ, {"APPDATA": str(self.tmp)}):
            path = tool.default_db("dev")
        self.assertEqual(path, self.tmp / "MyEmailSpamFilter" / "MyEmailSpamFilter_Dev" / "spam_filter.db")
        self.assertNotIn("com.example", str(path))

    def test_prod_default_and_missing_appdata(self) -> None:
        with mock.patch.dict(os.environ, {"APPDATA": str(self.tmp)}):
            self.assertEqual(tool.default_db("prod"),
                             self.tmp / "MyEmailSpamFilter" / "MyEmailSpamFilter" / "spam_filter.db")
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertIsNone(tool.default_db("dev"))

    def test_limit_applies(self) -> None:
        self.assertEqual(len(tool.query_rows(self.db, 1)), 1)
        code, out = self.run_main("--db", str(self.db), "--limit", "1")
        self.assertEqual(code, 0)
        self.assertEqual(len([line for line in out.splitlines() if line[:1].isdigit()]), 1)


if __name__ == "__main__":
    unittest.main()
