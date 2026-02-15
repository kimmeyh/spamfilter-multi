# ADR-0032: User Data Deletion Strategy

## Status

Proposed

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

**TO BE DETERMINED** - This ADR captures the decision criteria. The decision will be made by the Product Owner.

### Options Under Consideration

#### Deletion Scope

##### Option A: Per-Account Deletion Only
- Delete individual email provider connections and their data
- Shared data (rules, safe senders) remains
- App continues to work for remaining accounts
- Closest to what users expect ("remove this email account")

##### Option B: Per-Account + Full Wipe Option
- Per-account deletion (Option A) for individual accounts
- Plus "Delete All Data" option that removes everything
- Resets app to fresh install state
- Satisfies both per-account and full deletion use cases

##### Option C: Full App Data Wipe Only
- Single "Delete All Data" button
- Removes all accounts, settings, rules, safe senders
- Simplest implementation
- May frustrate users who only want to remove one account

#### External Deletion Mechanism

##### Option A: GitHub Pages Form
- Simple form on GitHub Pages site
- User provides email address
- Instructions to self-delete via app, or contact developer
- Low cost, easy to maintain

##### Option B: Dedicated Website with Deletion Form
- Web form that accepts email and verification
- Developer receives request and processes manually
- More professional but requires manual processing

##### Option C: Email-Based Request
- Provide support email address
- User emails to request deletion
- Manual processing by developer
- Simplest external mechanism but slowest response

##### Option D: In-App Self-Service Only (with Documentation)
- Provide in-app deletion as primary mechanism
- Website explains how to delete data via the app
- Argue that since all data is local, uninstalling the app also deletes data
- May not fully satisfy Google's requirement for external accessibility

### Decision Criteria

1. **Policy compliance**: Must satisfy Google Play account deletion requirement
2. **User expectation**: Users expect "remove account" not "wipe everything"
3. **Data safety**: Must not leave orphaned tokens or credentials
4. **Implementation complexity**: Per-account deletion requires careful data isolation
5. **External mechanism effort**: Website vs email vs GitHub Pages
6. **Shared data handling**: Rules and safe senders are shared, not per-account
7. **Reversibility**: Should deletion be confirmed and irreversible?

### Key Points

- The app stores ALL data locally; there is no server-side data to delete
- Uninstalling the app effectively deletes all data (but Google still requires in-app mechanism)
- OAuth token revocation is important but may fail (token already expired, network issue)
- Rules and safe senders are shared across accounts and should not be deleted when removing one account
- Background scan tasks must be cleaned up when an account is deleted
- The "external deletion" requirement can potentially be satisfied by documentation explaining that all data is local and can be deleted by removing the account in-app or uninstalling
- flutter_secure_storage data persists across app reinstalls on some Android versions (linked to device encryption)

## Alternatives Considered

Analysis deferred until decision criteria are evaluated by Product Owner.

## Consequences

To be documented after decision is made.

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
