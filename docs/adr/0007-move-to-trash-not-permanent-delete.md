# ADR-0007: Move-to-Trash, Not Permanent Delete

## Status

Accepted

## Date

~2026-02-01 (Sprint 11, Issue #9 fix)

## Context

When the spam filter identifies an email matching a "delete" rule, it must decide how to remove that email from the user's inbox. There are two fundamental approaches:

1. **Permanent deletion**: Remove the email from the server entirely (cannot be recovered)
2. **Move to trash**: Move the email to the Trash/Deleted Items folder (recoverable until trash is emptied)

The project learned the importance of this decision through a production incident. Issue #9 documented a bug where readonly mode enforcement was bypassed, resulting in **526 emails being permanently deleted** during what the user believed was a safe, read-only scan. The original implementation used permanent deletion for the "delete" action, which meant there was no recovery path.

This incident established a clear principle: **automated email filtering must be recoverable by default**.

Different email providers implement deletion differently:
- **Gmail**: Has a dedicated `trash()` API and a separate permanent `delete()` API; trash is auto-emptied after 30 days
- **IMAP (AOL, Yahoo, iCloud)**: Move to a Trash/Deleted folder via `UID MOVE`; permanent deletion requires `UID STORE +Flags \Deleted` followed by `EXPUNGE`

## Decision

All "delete" actions move emails to the trash folder instead of permanently deleting them. The implementation differs by provider but the behavior is consistent:

**Gmail** (`GmailApiAdapter`):
- Uses `users.messages.trash()` API which moves to Gmail's Trash label
- For custom target folders, uses `users.messages.modify()` to add the target label and remove INBOX/UNREAD labels
- The permanent `users.messages.delete()` API is never called
- Batch operations use `batchModify` to add TRASH label (not `batchDelete` which is permanent)

**IMAP** (`GenericIMAPAdapter`):
- Uses `UID MOVE` to move messages to the configured trash folder (default: "Trash")
- The `UID STORE +Flags \Deleted` + `EXPUNGE` sequence (permanent deletion) is never used
- Batch operations use `UID MOVE` with sequence sets

**Configurable target folder**: Users can configure `deletedRuleFolder` per account to specify where "deleted" emails go (e.g., a custom "SpamFilter/Deleted" folder instead of Trash). If not configured, the provider default is used (Gmail: TRASH label, IMAP: Trash folder).

## Alternatives Considered

### Permanent Deletion
- **Description**: Use provider APIs to permanently remove emails (Gmail `delete()`, IMAP `STORE \Deleted` + `EXPUNGE`)
- **Pros**: Cleaner - no accumulation in trash; user does not need to empty trash; more storage-efficient
- **Cons**: No recovery path if a rule is wrong or if the scan mode is bypassed (as happened in Issue #9); user must fully trust their rules before running; accidental deletion is catastrophic; no audit trail of what was removed
- **Why Rejected**: The Issue #9 incident (526 emails permanently lost) proved that automated systems must be recoverable. Even well-tested rules can have edge cases, and users need the ability to review and recover filtered emails

### Soft Delete Flag (Mark Only)
- **Description**: Mark emails with a custom flag or label but leave them in their original folder
- **Pros**: Most reversible option; emails stay in place; easy to "undo" by removing the flag
- **Cons**: Does not actually remove spam from the inbox; users still see flagged emails; defeats the primary purpose of spam filtering (removing unwanted emails from view); flag support varies by IMAP server
- **Why Rejected**: Users expect a spam filter to remove emails from their inbox, not just tag them. Leaving flagged spam in the inbox provides a poor user experience

### Move to Custom Quarantine Folder
- **Description**: Always move to a dedicated "SpamFilter/Quarantine" folder (not the standard Trash)
- **Pros**: Separates spam-filtered emails from manually deleted emails; clear audit trail; does not interfere with user's normal trash usage
- **Cons**: Requires creating custom folders on every provider (some IMAP servers restrict folder creation); custom folders may not auto-purge like Trash does; users must manually manage the quarantine folder
- **Why Rejected**: Not rejected entirely - the `deletedRuleFolder` configuration option supports this use case. However, the default is Trash because it is universally supported, users understand it, and most providers auto-purge trash after 30 days

## Consequences

### Positive
- **Recoverability**: Users can review and restore emails that were incorrectly filtered by checking their Trash folder
- **Audit trail**: The Trash folder serves as a log of what the spam filter removed, allowing users to verify rule accuracy
- **Incident mitigation**: Even if a scan mode bug occurs (like Issue #9), emails can be recovered from Trash before it is auto-purged
- **User confidence**: Users are more willing to try aggressive rules knowing that mistakes are recoverable
- **Provider compatibility**: Trash folders are universally supported across all email providers

### Negative
- **Trash accumulation**: Automated filtering can fill the Trash folder with hundreds of emails per scan, making it harder for users to find their own manually deleted emails
- **Auto-purge dependency**: Recovery depends on the provider's trash retention policy (Gmail: 30 days, IMAP servers: varies). If users do not check Trash within the retention window, emails are still lost
- **Not truly deleted**: Some users may want permanent deletion for privacy/security reasons (e.g., phishing emails they do not want lingering in Trash). The current design does not support this preference

### Neutral
- **Configurable target**: The `deletedRuleFolder` setting allows users to redirect filtered emails to a custom folder instead of Trash, providing flexibility for users who want quarantine-style behavior. This mitigates the trash accumulation concern but requires manual configuration

## References

- `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart` - Gmail delete implementation (lines 289-318: single message, lines 958-972: batch)
- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart` - IMAP delete implementation (lines 439-448: single message, lines 646-648: batch)
- `mobile-app/lib/adapters/email_providers/spam_filter_platform.dart` - `setDeletedRuleFolder()` interface (lines 66-74)
- `mobile-app/test/integration/email_scanner_readonly_mode_test.dart` - Regression test preventing Issue #9 recurrence
- GitHub Issue #9 - Readonly mode bypass (526 emails permanently deleted)
- `CHANGELOG.md` - "CRITICAL: Change IMAP delete to move-to-trash instead of permanent delete"
