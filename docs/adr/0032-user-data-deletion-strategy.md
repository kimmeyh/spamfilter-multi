# ADR-0032: User Data Deletion Strategy

## Status

Accepted

## Date

2026-02-15

## Context

Google Play policy (effective January 28, 2026) requires that apps allowing users to create accounts must also allow them to request account and data deletion. The deletion option must be discoverable both within the app and outside it (e.g., via a website or email process).

### What "Account" Means in This App

The app does not have traditional user accounts with username/password. Instead, users add email provider connections (Gmail OAuth, AOL IMAP, Yahoo IMAP, etc.). Each connection stores:

| Data Type | Storage | Per Account |
|-----------|---------|-------------|
| OAuth tokens (access + refresh) | flutter_secure_storage (encrypted) | Yes |
| IMAP credentials (app password) | flutter_secure_storage (encrypted) | Yes |
| Account email address | flutter_secure_storage | Yes |
| Account settings (folders, scan mode, frequency) | SQLite `account_settings` | Yes |
| Scan results (email metadata) | SQLite `scan_results` | Yes |
| Spam filter rules | SQLite `rules` | Shared (all accounts) |
| Safe sender patterns | SQLite `safe_senders` | Shared (all accounts) |
| App-wide settings | SQLite `app_settings` | Shared |

### Google Play Policy Requirements

1. **In-app deletion**: Accessible from within the app UI
2. **External deletion**: Accessible without opening the app (website, email, or other mechanism)
3. **Data removal**: Delete all associated user data (or clearly explain what is retained and why)
4. **Partial deletion**: If some data must be retained (security, legal, compliance), clearly inform the user
5. **Discoverable**: Users must be able to find the deletion option easily

### Google API Services User Data Policy

For Gmail OAuth connections specifically:
- Must be able to delete user data upon request
- Must revoke OAuth tokens when user deletes their account
- Must delete cached email data associated with the account

### Technical Considerations

**OAuth Token Revocation**:
- Gmail: Revoke via `https://oauth2.googleapis.com/revoke?token={token}`
- IMAP providers: No token revocation API (just delete stored credentials)
- Token revocation may fail (network issues, already revoked) - must handle gracefully

**Database Deletion**:
- SQLite `account_settings`: Delete rows matching `accountId`
- SQLite `scan_results`: Delete rows matching `account_id`
- Shared data (rules, safe_senders, app_settings): These are NOT per-account and should NOT be deleted when removing a single account

**Secure Storage Cleanup**:
- flutter_secure_storage: Delete all keys prefixed with account identifier
- Must be thorough (leftover tokens are a security risk)

**Background Scan Cleanup**:
- Cancel scheduled background scans for the deleted account
- Remove WorkManager tasks associated with the account
- Remove Task Scheduler entries (Windows) for the account

## Decision

**Scope B + External A**: Per-account deletion plus full data wipe option. External deletion via GitHub Pages form on myemailspamfilter.com.

### In-App Deletion

**Per-account deletion** (Settings > Account > "Remove Account"):
- Deletes credentials, account settings, and scan results for the selected account
- Shared data (rules, safe senders, app settings) is preserved
- App continues to work for remaining accounts

**Full data wipe** (Settings > Data Management > "Delete All Data"):
- Removes all accounts, credentials, settings, rules, safe senders, and scan history
- Resets app to fresh install state
- Requires confirmation dialog (irreversible)

### Per-Account Deletion Steps

1. Revoke OAuth tokens (Gmail: `https://oauth2.googleapis.com/revoke?token={token}`, IMAP: no API needed)
2. Delete all credentials from flutter_secure_storage for the account (keys prefixed with account identifier)
3. Delete `account_settings` rows matching `accountId` from SQLite
4. Delete `scan_results` and `email_actions` rows matching `account_id` from SQLite
5. Cancel background scan schedule for the account
6. Remove platform-specific scheduled tasks (Windows Task Scheduler, Android WorkManager)

### Full Wipe Steps

1. Execute per-account deletion for all accounts
2. Delete all rows from `rules`, `safe_senders`, `app_settings` tables
3. Delete SQLite database file
4. Clear all flutter_secure_storage entries
5. Remove all platform-specific scheduled tasks

### External Deletion Mechanism

- GitHub Pages form on myemailspamfilter.com
- Explains that all data is stored locally on the user's device (no server-side data exists)
- Instructs user to delete data via in-app mechanism or by uninstalling the app
- Provides contact email for support requests

### Key Points

- The app stores ALL data locally; there is no server-side data to delete
- Uninstalling the app effectively deletes all data (but Google still requires in-app mechanism)
- OAuth token revocation may fail (network issues, token already expired) -- handle gracefully, do not block deletion
- Rules and safe senders are shared across accounts and are NOT deleted during per-account deletion
- Background scan tasks must be cleaned up when an account is deleted
- flutter_secure_storage data persists across app reinstalls on some Android versions (linked to device encryption)

## Alternatives Considered

### Scope A: Per-Account Deletion Only
- **Description**: Delete individual email provider connections and their data. No full wipe option.
- **Pros**: Simpler implementation, closest to user expectation ("remove this email account")
- **Cons**: No way to reset app to fresh install state without uninstalling
- **Why Rejected**: Less complete; full wipe option adds minimal complexity and satisfies the "delete all data" use case

### Scope C: Full App Data Wipe Only
- **Description**: Single "Delete All Data" button that removes everything.
- **Pros**: Simplest implementation
- **Cons**: Frustrates users who only want to remove one email account; forces loss of rules and safe senders
- **Why Rejected**: Users expect per-account removal, not all-or-nothing

### External B: Dedicated Website with Deletion Form
- **Description**: Web form that accepts email and verification, developer processes manually.
- **Pros**: More professional appearance
- **Cons**: Requires manual processing by developer, ongoing effort
- **Why Rejected**: Overkill for a local-only app; all data is on the user's device

### External C: Email-Based Request
- **Description**: Provide support email, user emails to request deletion.
- **Pros**: Simplest external mechanism
- **Cons**: Slowest response time, manual processing
- **Why Rejected**: Same as External B; manual processing not needed when all data is local

### External D: In-App Self-Service Only
- **Description**: In-app deletion as primary mechanism, website documents how to use it.
- **Pros**: No external form needed
- **Cons**: May not satisfy Google's requirement for external accessibility of deletion
- **Why Rejected**: Risk of policy non-compliance; GitHub Pages form is low effort and removes ambiguity

## Consequences

### Positive
- Satisfies Google Play account deletion policy (both in-app and external mechanisms)
- Per-account deletion preserves shared data (rules, safe senders), matching user expectations
- Full wipe option available for users who want to reset completely
- GitHub Pages form is low-cost and easy to maintain

### Negative
- Per-account deletion requires careful data isolation to avoid orphaned credentials or background tasks
- GitHub Pages form needs maintenance (must stay accessible and accurate)
- OAuth token revocation is best-effort (network failures handled gracefully, not blocking)

### Neutral
- Uninstalling the app also deletes all data, but the policy requires an explicit in-app mechanism regardless
- flutter_secure_storage persistence across reinstalls on some Android versions means uninstall may not fully clear credentials on all devices

## References

- `mobile-app/lib/adapters/storage/secure_credentials_store.dart` - Credential storage
- `mobile-app/lib/core/storage/database_helper.dart` - SQLite database schema
- `mobile-app/lib/core/services/background_scan_manager.dart` - Background scan scheduling
- GP-11 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Account deletion feature description
- [Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy)
- ADR-0004 (Dual-Write Storage) - Data storage architecture
- ADR-0008 (Platform-Native Secure Credential Storage) - Credential storage
- ADR-0010 (Normalized Database Schema) - Database tables
- ADR-0013 (Per-Account Settings with Inheritance) - Account settings structure
