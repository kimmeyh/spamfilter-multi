# ADR-0034: Gmail Access Method for Production

## Status

Proposed

## Date

2026-02-15

## Context

The app currently supports two methods for accessing email:

1. **Gmail REST API** (`googleapis` package): Used for Gmail accounts, authenticated via Google Sign-In OAuth
2. **IMAP** (`enough_mail` package): Used for AOL, Yahoo, and generic IMAP providers, authenticated via app passwords

For Gmail accounts specifically, the current architecture uses the Gmail REST API exclusively (not IMAP). This choice has implications for Google's OAuth scope verification process, which is required before the app can be published on the Play Store.

### Current Gmail Implementation

```dart
// GmailApiAdapter uses Gmail REST API
class GmailApiAdapter implements EmailProvider {
  // Uses gmail.modify scope for full read/write access
  // Reads messages via messages.list() and messages.get()
  // Moves to trash via messages.trash()
  // Lists labels via labels.list()
}
```

### OAuth Scope Implications

| Access Method | Required Scope | Classification | Verification |
|--------------|---------------|---------------|-------------|
| Gmail REST API (current) | `gmail.modify` | Restricted | CASA audit required |
| Gmail REST API (read-only) | `gmail.readonly` | Restricted | CASA audit required |
| Gmail REST API (metadata only) | `gmail.metadata` | Restricted | CASA audit required |
| IMAP via OAuth | `mail.google.com` | Restricted | CASA audit required |
| IMAP via app password | N/A (no OAuth) | N/A | No verification |

**Critical observation**: ALL methods that access Gmail email content require a restricted scope and CASA audit. There is no way to avoid restricted scope verification when accessing Gmail email data.

### IMAP vs REST API Trade-offs

| Factor | Gmail REST API | IMAP with OAuth |
|--------|---------------|-----------------|
| Scope needed | `gmail.modify` | `mail.google.com` (broadest) |
| Scope granularity | Can request readonly or modify separately | Only one scope (full access) |
| Google reviewer perception | More granular = better | Broadest scope = harder to justify |
| Batch operations | Native batch API support | IMAP sequence sets |
| Rate limiting | API quota limits (250 units/sec) | No explicit rate limits |
| Connection management | HTTP/REST (stateless) | TCP connection (stateful) |
| Offline headers | Metadata available without full download | Must fetch from server |
| Move to trash | `messages.trash()` dedicated method | IMAP MOVE command |
| Library maturity | `googleapis` (Google-maintained) | `enough_mail` (community) |
| Error handling | Structured API errors | IMAP response codes |

### Gmail App Password Alternative

Gmail users can create app passwords (under Google Account > Security > App passwords) for IMAP access without OAuth. This would:
- Avoid restricted scope verification entirely
- Require users to manually create and enter app passwords
- Not support Google accounts with Advanced Protection enabled
- Provide a worse user experience than OAuth sign-in
- Be consistent with how AOL and Yahoo already work in the app

### Production Gmail OAuth Token Behavior

Token behavior differs based on app verification status:
- **Unverified app**: Refresh tokens expire after 7 days; limited to 100 users
- **Verified app**: Refresh tokens are long-lived (months to years)
- **App verification** requires restricted scope verification for Gmail scopes

## Decision

**TO BE DETERMINED** - This ADR captures the decision criteria. The decision will be made by the Product Owner.

### Options Under Consideration

#### Option A: Keep Gmail REST API with `gmail.modify` (Current)
- No code changes needed
- `gmail.modify` scope covers read + label + move + trash
- Must complete restricted scope verification + CASA audit
- Most granular scope that covers all features

#### Option B: Gmail REST API with Incremental Scopes
- Start with `gmail.readonly` for scanning
- Upgrade to `gmail.modify` when user enables delete/move actions
- Both are restricted (same verification requirement)
- Demonstrates "principle of least privilege" to Google reviewers
- More complex UX (two permission prompts at different times)

#### Option C: IMAP with Gmail App Passwords (No OAuth)
- Users manually create Gmail app passwords
- Same IMAP path as AOL/Yahoo
- No OAuth verification needed at all
- Worst user experience (manual app password creation)
- Does not work for accounts with Advanced Protection

#### Option D: Dual Path (OAuth for Verified, App Password for Unverified)
- Ship initially with app password support for Gmail (like AOL/Yahoo)
- Add OAuth sign-in after completing verification process
- Allows earlier Play Store launch
- Most complex to implement and maintain

#### Option E: Launch Without Gmail Support
- Publish on Play Store with AOL, Yahoo, and generic IMAP only
- Add Gmail support after completing OAuth verification
- Fastest path to Play Store
- Excludes the largest email provider

### Decision Criteria

1. **Time to market**: How quickly can the app be published on Play Store?
2. **User experience**: OAuth sign-in vs manual app password for Gmail users
3. **Verification cost and timeline**: $500-$8,000+ annually, 2-6 months initial
4. **Feature completeness**: All scan and delete features must work
5. **User base**: Gmail is the dominant email provider (users will expect it)
6. **Maintenance**: Annual CASA renewal commitment
7. **Alternative providers**: App already supports AOL, Yahoo, generic IMAP without OAuth

### Key Points

- There is no non-restricted scope that allows reading Gmail message content
- The CASA audit requirement applies regardless of which restricted scope is chosen
- `gmail.modify` is the most appropriate single scope for the app's functionality
- Gmail app passwords require manual user setup (less user-friendly than OAuth)
- Google may deprecate app passwords in the future (they have already removed basic auth for Workspace)
- The app could launch without Gmail support and add it later (phased approach)
- This decision is closely tied to ADR-0029 (scope strategy) and has financial implications
- IMAP with OAuth (`mail.google.com`) is the broadest scope and hardest to justify during verification

## Alternatives Considered

Analysis deferred until decision criteria are evaluated by Product Owner.

## Consequences

To be documented after decision is made.

## References

- `mobile-app/lib/adapters/auth/google_auth_service.dart` - Gmail OAuth implementation (scopes at lines 37-52)
- `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart` - Gmail REST API adapter
- `mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart` - IMAP adapter (used for AOL/Yahoo)
- GP-14 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Gmail access method feature
- ADR-0002 (Adapter Pattern) - Provider-agnostic interface
- ADR-0011 (Desktop OAuth Loopback Redirect) - Current OAuth architecture
- ADR-0029 (Gmail API Scope and Verification Strategy) - Scope verification process
- [Gmail API scopes](https://developers.google.com/workspace/gmail/api/auth/scopes)
- [IMAP OAuth for Gmail](https://developers.google.com/workspace/gmail/imap/xoauth2-protocol)
- [Google app passwords](https://support.google.com/accounts/answer/185833)
