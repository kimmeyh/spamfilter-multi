#!/usr/bin/env python3
"""Show the 20 most recent scan_results rows from the app database (port of check_scans.ps1, F334, Sprint 85).

Usage:
    python mobile-app/scripts/check_scans.py                    # Windows dev database (default)
    python mobile-app/scripts/check_scans.py --environment prod # Windows production database
    python mobile-app/scripts/check_scans.py --db C:\\path\\spam_filter.db

Default database (Windows): %APPDATA%\\MyEmailSpamFilter\\MyEmailSpamFilter_Dev\\spam_filter.db for dev and
%APPDATA%\\MyEmailSpamFilter\\MyEmailSpamFilter\\spam_filter.db for prod (ADR-0035; lib/adapters/storage/app_paths.dart).
The original read the pre-Sprint-19 folder %APPDATA%\\com.example\\spam_filter_mobile, which no current build writes.

The database is opened read-only (SQLite URI mode=ro). The running app keeps it in WAL mode, and this tool must
never write to it. Columns are printed separated by "|", the same layout as the sqlite3 command-line tool.
started_at and completed_at are milliseconds since the epoch (scan_result_store.dart), so they are shown as local time.

Exit codes:
    0  the report was printed, or the database was not found (the original also exited 0 here)
    1  the query failed (for example, the scan_results table is missing) or APPDATA is not set without --db
    2  invalid arguments (argparse)
"""
from __future__ import annotations

import argparse
import os
import sqlite3
import sys
from pathlib import Path

QUERY = (
    "SELECT id, account_id, scan_type, scan_mode, "
    "datetime(started_at/1000, 'unixepoch', 'localtime') as started, "
    "datetime(completed_at/1000, 'unixepoch', 'localtime') as completed, "
    "total_emails, processed_count, deleted_count, status, folders_scanned "
    "FROM scan_results ORDER BY started_at DESC LIMIT {limit};"
)


def default_db(environment: str) -> Path | None:
    """The Windows app database for the environment, or None when APPDATA is not set."""
    appdata = os.environ.get("APPDATA")
    if not appdata:
        return None
    folder = "MyEmailSpamFilter_Dev" if environment == "dev" else "MyEmailSpamFilter"
    return Path(appdata) / "MyEmailSpamFilter" / folder / "spam_filter.db"


def open_readonly(db: Path) -> sqlite3.Connection:
    """A connection that cannot write: SQLite URI mode=ro. Every read in this tool goes through it."""
    return sqlite3.connect(db.resolve().as_uri() + "?mode=ro", uri=True)


def query_rows(db: Path, limit: int) -> list[tuple]:
    """Run the report query read-only. Raises sqlite3.Error on failure (the caller reports it)."""
    connection = open_readonly(db)
    try:
        return connection.execute(QUERY.format(limit=int(limit))).fetchall()
    finally:
        connection.close()


def format_row(row: tuple) -> str:
    """One row as the sqlite3 command-line tool prints it: values joined by '|', NULL as an empty field."""
    return "|".join("" if value is None else str(value) for value in row)


def parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Show recent scan_results rows from the app database.")
    parser.add_argument("--environment", choices=("dev", "prod"), default="dev",
                        help="which Windows database to read when --db is not given (default: dev)")
    parser.add_argument("--db", metavar="PATH", help="database file to read (overrides --environment)")
    parser.add_argument("--limit", type=int, default=20, help="rows to show (default: 20)")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.db:
        db: Path | None = Path(args.db)
    else:
        db = default_db(args.environment)
        if db is None:
            print("APPDATA is not set; pass --db PATH", file=sys.stderr)
            return 1
    if not db.exists():
        print(f"Database not found at: {db}")
        return 0

    print(f"Database found: {db}")
    print(f"Query: {QUERY.format(limit=args.limit)}")
    print("")
    try:
        rows = query_rows(db, args.limit)
    except sqlite3.Error as exc:
        print(f"Query failed: {exc}", file=sys.stderr)
        return 1
    for row in rows:
        print(format_row(row))
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
