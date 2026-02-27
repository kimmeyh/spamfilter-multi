# ADR-0020: Demo Mode with Synthetic Emails

## Status

Accepted

## Date

~2026-02 (Sprint 14)

## Context

New users evaluating the spam filter face a friction point: they must configure an email account (OAuth credentials, app passwords) before they can see the app in action. This creates a chicken-and-egg problem:

- Users want to evaluate the app's rule matching before investing time in setup
- Testing rules against live email requires a connected account
- Developers need to test UI components and scan workflows without modifying real mailboxes
- Demonstrations to potential users should not require their email credentials

The app needs a way to simulate a complete scan workflow with realistic email data, without connecting to any email server.

## Decision

Implement a `MockEmailProvider` backed by `MockEmailData` that generates 55 synthetic emails across 5 categories, providing a complete scan experience without any email account configuration.

### Email Categories

| Category | Count | Purpose |
|----------|-------|---------|
| Obvious Spam | 15 | Lottery scams, phishing, pharma, casino, tech support |
| Marketing/Promotional | 15 | Retail promotions, newsletters, travel, streaming |
| Legitimate Business | 10 | GitHub notifications, project tools, HR, IT |
| Personal | 10 | Family, friends, order confirmations, bills |
| No Rule Match | 5 | Legitimate senders that intentionally match no rule |

### MockEmailProvider Implementation

- **Implements `SpamFilterPlatform`**: Same interface as Gmail and IMAP adapters
- **Simulated delays**: Configurable `_operationDelayMs` parameter creates realistic UI progress timing
- **Action logging**: All operations (delete, move, mark as read) are logged to `_actionLog` for verification
- **Folder support**: Provides 5 demo folders (INBOX, Promotions, Spam, Junk, Trash)
- **Folder filtering**: Respects the folder selection UI - only returns emails from selected folders
- **No network**: Zero network calls; works completely offline

### Synthetic Email Design

Each email has realistic fields:
- **From addresses**: Domain names match the spam category (e.g., `winner@lottery-scam.com`, `noreply@github.com`)
- **Subjects**: Characteristic spam patterns (ALL CAPS, urgency, monetary claims) vs. legitimate subjects
- **Bodies**: Brief content matching the category
- **Headers**: `From` header set for rule evaluation
- **Timestamps**: Staggered over the last 24 hours for realistic date distribution
- **IDs**: Sequential `demo-001` through `demo-055` for easy identification

### Integration Point

`MockEmailProvider` is registered in `PlatformRegistry` with platformId `demo`. The user selects "Demo Account" from the account picker to activate demo mode.

## Alternatives Considered

### Require Live Email for All Testing
- **Description**: No demo mode; users must configure a real email account before using the app
- **Pros**: Tests against real data; validates the entire pipeline including network and auth; no synthetic data to maintain
- **Cons**: High friction for new users; developers must use real email for UI testing; cannot demonstrate without credentials; slows iteration during rule tuning
- **Why Rejected**: The friction of requiring account setup before evaluation was a significant barrier to adoption. Demo mode removes this barrier entirely

### Recorded IMAP Sessions (Replay)
- **Description**: Record real IMAP sessions and replay them during demo mode, providing authentic email data
- **Pros**: Maximally realistic; captures real email patterns; includes actual headers and structure
- **Cons**: Privacy concerns (recorded emails contain personal information); recording mechanism adds complexity; replayed data becomes stale over time; must anonymize before shipping; legal concerns with distributing real email content
- **Why Rejected**: Privacy and legal concerns with shipping real email data (even anonymized) outweigh the realism benefit. Synthetic emails with carefully designed spam patterns provide sufficient realism for evaluation

### Shared Test Email Account
- **Description**: Create a dedicated test email account pre-populated with spam and legitimate emails; users connect to this shared account for testing
- **Pros**: Real email infrastructure; tests OAuth flow; realistic data
- **Cons**: Shared account credentials would be in the app or documentation (security risk); account could be compromised or modified by any user; email content changes over time; requires internet; account maintenance burden; provider may suspend for unusual access patterns
- **Why Rejected**: A shared email account creates security, maintenance, and reliability problems. Any user can modify the account's content, and the account itself becomes a single point of failure

## Consequences

### Positive
- **Zero-friction evaluation**: Users can experience the complete scan workflow (mode selection, folder selection, progress, results) without any account setup
- **Deterministic testing**: The 55 synthetic emails produce consistent, reproducible results for testing and development
- **Category coverage**: All five categories ensure that rules, safe senders, and "no match" scenarios are all exercised
- **Developer productivity**: UI development and testing does not require network access or email credentials
- **Demonstration ready**: Product demos can be conducted with any device, anywhere, without email account access

### Negative
- **Maintenance burden**: The 55 synthetic emails must be updated as rule patterns evolve; new rule types may need corresponding demo emails
- **Not fully realistic**: Synthetic emails lack the variety, complexity, and edge cases of real email (encoding issues, attachments, multilingual content, deeply nested forwarding)
- **False confidence risk**: Rules that work well against synthetic emails may not work as well against real-world spam, which is more varied and adversarial

### Neutral
- **Action logging without side effects**: `MockEmailProvider` logs all actions (delete, move) but does not actually perform them, since there is no real mailbox. This is useful for verifying rule behavior but means demo mode cannot test the actual delete/move codepath

## References

- `mobile-app/lib/core/services/mock_email_data.dart` - 55 synthetic emails across 5 categories (lines 9-638)
- `mobile-app/lib/adapters/email_providers/mock_email_provider.dart` - MockEmailProvider implementing SpamFilterPlatform (lines 14-100)
- ADR-0002 (Adapter Pattern) - MockEmailProvider implements the same interface as live providers
- ADR-0006 (Four Scan Modes) - Demo mode works with all scan modes
