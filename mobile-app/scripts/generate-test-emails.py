#!/usr/bin/env python3
"""Generate test-email data for spam filter testing (port of generate-test-emails.ps1, F334, Sprint 85).

Use it to plan replacement test mail after a manual validation that deleted or moved messages.

Usage:
    python mobile-app/scripts/generate-test-emails.py --count 100 --spam-ratio 0.8
    python mobile-app/scripts/generate-test-emails.py --dry-run
    python mobile-app/scripts/generate-test-emails.py --email-provider Yahoo --output C:\\tmp\\emails.json

What it does: the templates and the generator come from send-test-emails.py (reused, not copied). The script
prints a summary and the first 10 emails. Without --dry-run it writes the generated data as JSON
(test-emails-<stamp>.json in the current folder unless --output is given).

What it does NOT do: it never sends mail. Sending is not implemented in send-test-emails.py either (the
send_emails_* functions only print TODO text), so this script prints "NOT SENT" and exits 0 after writing the file.
Use a dedicated test account only, never a personal one.

Parameters (same names as the original, in kebab case):
    --email-provider  Gmail | AOL | Yahoo | Outlook (default: Gmail). Gmail selects the Gmail API path; the others
                      select the generic SMTP path. Both paths are unimplemented.
    --count           1 to 1000 (default: 50)
    --spam-ratio      0.0 to 1.0 (default: 0.7)
    --credentials     path to secrets.dev.json. Read by nothing yet; kept for parity with the original.
    --dry-run         print what would be generated; write no file

Exit codes:
    0  the data was generated (and written unless --dry-run)
    2  invalid arguments (count or spam ratio out of range, unknown provider; argparse)
"""
from __future__ import annotations

import argparse
import datetime
import importlib.util
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("send_test_emails", SCRIPTS / "send-test-emails.py")
send = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(send)

PROVIDERS = ("Gmail", "AOL", "Yahoo", "Outlook")


def count_in_range(text: str) -> int:
    value = int(text)
    if not 1 <= value <= 1000:
        raise argparse.ArgumentTypeError("must be between 1 and 1000")
    return value


def ratio_in_range(text: str) -> float:
    value = float(text)
    if not 0.0 <= value <= 1.0:
        raise argparse.ArgumentTypeError("must be between 0.0 and 1.0")
    return value


def parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate test emails for spam filter testing (not sent).")
    parser.add_argument("--email-provider", choices=PROVIDERS, default="Gmail",
                        help="provider; Gmail uses the Gmail API path, the rest use SMTP (default: Gmail)")
    parser.add_argument("--count", type=count_in_range, default=50, help="emails to generate, 1-1000 (default: 50)")
    parser.add_argument("--spam-ratio", type=ratio_in_range, default=0.7,
                        help="share of spam, 0.0-1.0 (default: 0.7)")
    parser.add_argument("--credentials", default="../secrets.dev.json",
                        help="path to secrets.dev.json (read by nothing yet; default: ../secrets.dev.json)")
    parser.add_argument("--dry-run", action="store_true", help="print the plan; write no file")
    parser.add_argument("--output", metavar="PATH", help="JSON file (default: test-emails-<stamp>.json here)")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    spam_count = int(args.count * args.spam_ratio)
    legitimate_count = args.count - spam_count

    print("======================================")
    print("Test Email Generator for Spam Filter")
    print("======================================")
    print("")
    print("Configuration:")
    print(f"  Provider: {args.email_provider}")
    print(f"  Total emails: {args.count}")
    print(f"  Spam emails: {spam_count} ({int(args.spam_ratio * 100)}%)")
    print(f"  Legitimate emails: {legitimate_count}")
    print(f"  Dry run: {args.dry_run}")
    print("")

    emails = send.generate_test_emails(args.count, args.spam_ratio)
    send.print_email_summary(emails)
    send.print_email_list(emails, limit=10)

    if args.dry_run:
        print("[DRY RUN] No file was written and no emails were sent.")
        print("To write the data, run without --dry-run.")
        return 0

    output = args.output or f"test-emails-{datetime.datetime.now().strftime('%Y%m%d-%H%M%S')}.json"
    send.save_to_json(emails, output)
    print("")
    if args.email_provider == "Gmail":
        send.send_emails_gmail_api(emails, args.credentials)
    else:
        send.send_emails_smtp(emails, args.credentials)
    print("")
    print("NOT SENT: no email was sent. Use the JSON file as the source for test mail you create by hand.")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
