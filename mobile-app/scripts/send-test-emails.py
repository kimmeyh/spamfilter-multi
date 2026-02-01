#!/usr/bin/env python3
"""
Test Email Sender for Spam Filter Testing

Generates and sends test emails to replenish test data after destructive testing.
Uses SMTP or email provider APIs to send sample spam and legitimate emails.

Usage:
    python send-test-emails.py --count 50 --spam-ratio 0.7
    python send-test-emails.py --dry-run

Requirements:
    pip install google-auth google-auth-oauthlib google-auth-httplib2 google-api-python-client

Author: Claude Sonnet 4.5
Date: February 1, 2026
Version: 1.0
"""

import argparse
import json
import random
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Tuple

# Spam email templates
SPAM_TEMPLATES = [
    {
        "subject": "URGENT: Your account will be closed!",
        "from_name": "Security Team",
        "from_email": "noreply@suspicious-bank.com",
        "body": "Dear customer, your account requires immediate verification. Click here to avoid suspension."
    },
    {
        "subject": "You've won $1,000,000!",
        "from_name": "Lottery Winner Notification",
        "from_email": "lottery@winner-notification.net",
        "body": "Congratulations! You are the lucky winner of our international lottery. Claim your prize now!"
    },
    {
        "subject": "Re: Invoice #12345",
        "from_name": "Billing Department",
        "from_email": "billing@fake-company.biz",
        "body": "Please review the attached invoice and make payment within 24 hours to avoid late fees."
    },
    {
        "subject": "Earn $5000/month working from home!",
        "from_name": "Work From Home Jobs",
        "from_email": "jobs@work-from-home.info",
        "body": "No experience required! Start earning today with our proven system. Limited spots available!"
    },
    {
        "subject": "Your package delivery failed",
        "from_name": "Delivery Service",
        "from_email": "delivery@not-real-ups.com",
        "body": "We attempted to deliver your package but no one was home. Click here to reschedule delivery."
    },
    {
        "subject": "Verify your email address now",
        "from_name": "Account Security",
        "from_email": "verify@phishing-site.ru",
        "body": "Your email account requires verification. Failure to verify will result in account termination."
    },
    {
        "subject": "Free trial: Premium membership",
        "from_name": "Premium Services",
        "from_email": "trial@spammy-service.com",
        "body": "Try our premium membership FREE for 30 days! No credit card required (but we'll ask later)."
    },
]

# Legitimate email templates
LEGITIMATE_TEMPLATES = [
    {
        "subject": "Weekly team meeting notes",
        "from_name": "Team Colleague",
        "from_email": "colleague@example.com",
        "body": "Hi team, here are the notes from today's meeting. Let me know if you have any questions."
    },
    {
        "subject": "Project update: Q1 2026",
        "from_name": "Project Manager",
        "from_email": "manager@company.com",
        "body": "Great progress on the project this quarter. See attached report for details."
    },
    {
        "subject": "Lunch next week?",
        "from_name": "Friend",
        "from_email": "friend@gmail.com",
        "body": "Hey! Want to grab lunch next week? Let me know what day works for you."
    },
    {
        "subject": "GitHub notification: New PR merged",
        "from_name": "GitHub",
        "from_email": "notifications@github.com",
        "body": "Pull request #112 has been successfully merged into develop branch."
    },
    {
        "subject": "Newsletter: Tech Weekly",
        "from_name": "Tech Weekly",
        "from_email": "newsletter@techweekly.com",
        "body": "This week's top stories: AI advances, new programming languages, and cloud security updates."
    },
    {
        "subject": "Conference registration confirmed",
        "from_name": "Conference Organizers",
        "from_email": "registration@devconf2026.com",
        "body": "Your registration for DevConf 2026 has been confirmed. See you there!"
    },
    {
        "subject": "Reminder: Doctor appointment tomorrow",
        "from_name": "Medical Office",
        "from_email": "appointments@medical-clinic.com",
        "body": "This is a reminder that you have an appointment tomorrow at 2:00 PM. Please arrive 10 minutes early."
    },
]


def generate_test_emails(count: int, spam_ratio: float) -> List[Dict]:
    """Generate test email data based on count and spam ratio."""
    spam_count = int(count * spam_ratio)
    legitimate_count = count - spam_count

    emails = []

    # Generate spam emails
    for i in range(spam_count):
        template = random.choice(SPAM_TEMPLATES)
        emails.append({
            "index": i + 1,
            "type": "SPAM",
            "from_name": template["from_name"],
            "from_email": template["from_email"],
            "subject": template["subject"],
            "body": template["body"],
            "timestamp": datetime.now().isoformat(),
        })

    # Generate legitimate emails
    for i in range(legitimate_count):
        template = random.choice(LEGITIMATE_TEMPLATES)
        emails.append({
            "index": spam_count + i + 1,
            "type": "LEGITIMATE",
            "from_name": template["from_name"],
            "from_email": template["from_email"],
            "subject": template["subject"],
            "body": template["body"],
            "timestamp": datetime.now().isoformat(),
        })

    # Shuffle to mix spam and legitimate
    random.shuffle(emails)

    return emails


def print_email_summary(emails: List[Dict]) -> None:
    """Print summary of generated emails."""
    spam_count = sum(1 for e in emails if e["type"] == "SPAM")
    legitimate_count = len(emails) - spam_count

    print("\n" + "=" * 60)
    print("Test Email Generator Summary")
    print("=" * 60)
    print(f"Total emails: {len(emails)}")
    print(f"Spam emails: {spam_count} ({spam_count / len(emails) * 100:.1f}%)")
    print(f"Legitimate emails: {legitimate_count} ({legitimate_count / len(emails) * 100:.1f}%)")
    print("=" * 60 + "\n")


def print_email_list(emails: List[Dict], limit: int = 10) -> None:
    """Print list of generated emails (limited to first N)."""
    print(f"First {min(limit, len(emails))} emails:\n")
    for email in emails[:limit]:
        type_label = f"[{email['type']}]".ljust(14)
        print(f"{email['index']:3d}. {type_label} {email['subject']}")
        print(f"     From: {email['from_name']} <{email['from_email']}>")
        print()

    if len(emails) > limit:
        print(f"... and {len(emails) - limit} more emails")


def save_to_json(emails: List[Dict], output_file: str) -> None:
    """Save email data to JSON file."""
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(emails, f, indent=2, ensure_ascii=False)
    print(f"\nEmail templates saved to: {output_file}")


def send_emails_gmail_api(emails: List[Dict], credentials_file: str) -> None:
    """Send emails using Gmail API (requires OAuth credentials)."""
    print("\n[TODO] Gmail API sending not yet implemented")
    print("\nTo implement Gmail API sending:")
    print("  1. Install: pip install google-api-python-client google-auth-oauthlib")
    print("  2. Load credentials from secrets.dev.json")
    print("  3. Create Gmail API service")
    print("  4. Use users.messages.send() to send each email")
    print("\nFor now, emails are saved to JSON file for manual creation.")


def send_emails_smtp(emails: List[Dict], credentials_file: str) -> None:
    """Send emails using SMTP (generic email providers)."""
    print("\n[TODO] SMTP sending not yet implemented")
    print("\nTo implement SMTP sending:")
    print("  1. Install: pip install smtplib (built-in Python)")
    print("  2. Load credentials from secrets.dev.json")
    print("  3. Connect to SMTP server (smtp.gmail.com:587, smtp.mail.yahoo.com:587, etc.)")
    print("  4. Send emails using smtplib.SMTP.sendmail()")
    print("\nFor now, emails are saved to JSON file for manual creation.")


def main():
    parser = argparse.ArgumentParser(
        description="Generate and send test emails for spam filter testing"
    )
    parser.add_argument(
        "--count",
        type=int,
        default=50,
        help="Number of test emails to generate (default: 50)"
    )
    parser.add_argument(
        "--spam-ratio",
        type=float,
        default=0.7,
        help="Percentage of emails that should be spam, 0.0-1.0 (default: 0.7)"
    )
    parser.add_argument(
        "--provider",
        choices=["gmail", "smtp"],
        default="gmail",
        help="Email provider: gmail (API) or smtp (generic) (default: gmail)"
    )
    parser.add_argument(
        "--credentials",
        type=str,
        default="../secrets.dev.json",
        help="Path to secrets.dev.json (default: ../secrets.dev.json)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be sent without actually sending"
    )
    parser.add_argument(
        "--output",
        type=str,
        default=None,
        help="Output JSON file (default: test-emails-YYYYMMDD-HHMMSS.json)"
    )

    args = parser.parse_args()

    # Validate arguments
    if not 0.0 <= args.spam_ratio <= 1.0:
        print("Error: --spam-ratio must be between 0.0 and 1.0")
        sys.exit(1)

    if args.count < 1 or args.count > 1000:
        print("Error: --count must be between 1 and 1000")
        sys.exit(1)

    # Generate test emails
    emails = generate_test_emails(args.count, args.spam_ratio)

    # Print summary
    print_email_summary(emails)
    print_email_list(emails, limit=10)

    # Save to JSON
    if args.output is None:
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        args.output = f"test-emails-{timestamp}.json"

    save_to_json(emails, args.output)

    # Send emails (if not dry run)
    if args.dry_run:
        print("\n[DRY RUN] No emails were actually sent.")
        print("\nTo send these emails, run without --dry-run:")
        print(f"  python send-test-emails.py --count {args.count} --spam-ratio {args.spam_ratio}")
    else:
        print("\n" + "=" * 60)
        print("Sending emails...")
        print("=" * 60)

        if args.provider == "gmail":
            send_emails_gmail_api(emails, args.credentials)
        else:
            send_emails_smtp(emails, args.credentials)

    print("\n" + "=" * 60)
    print("IMPORTANT: Email sending not fully implemented yet")
    print("=" * 60)
    print("\nManual alternative:")
    print(f"  1. Review templates in {args.output}")
    print("  2. Manually compose emails in your test email account")
    print("  3. Or implement Gmail API/SMTP sending in this script")
    print("\nUse the JSON file as a reference for creating test emails.")
    print()


if __name__ == "__main__":
    main()
