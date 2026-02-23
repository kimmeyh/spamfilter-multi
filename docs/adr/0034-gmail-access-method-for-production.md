# ADR-0034: Gmail Access Method for Production

## Status

Accepted

## Date

2026-02-15 (proposed), 2026-02-22 (accepted)

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

**Dual-path approach**: Gmail REST API OAuth for alpha/beta testers, Gmail app passwords via IMAP for general users. CASA verification deferred until financially viable.

### Chosen Approach: Option D (Dual Path) with Phased Rollout

**Phase 1 - Alpha/Beta**: Gmail REST API with OAuth (unverified, `gmail.modify` scope)
- Current `GmailApiAdapter` used as-is, no code changes
- Google Cloud Console in Testing mode (100 hand-picked test users)
- 7-day token expiry acceptable for testers
- Validates OAuth flow and Google Play Store setup

**Phase 2 - General Availability**: Gmail app passwords via IMAP
- Gmail users configure app passwords in Google Account settings
- Uses existing `GenericImapAdapter` (same as AOL/Yahoo) -- no new code needed
- No OAuth, no verification, no user caps, no token expiry concerns
- Setup: Google Account > Security > 2-Step Verification > App Passwords
- Requires 2FA enabled on Google account

**Phase 3 - ON HOLD**: Full OAuth after CASA verification
- Pursue CASA verification when: (a) app has 2,500+ active Gmail IMAP users at $3 annually or yearly revenue exceeds $5,000 (covering annual CASA cost)
- Upgrades Gmail users from app passwords to seamless OAuth sign-in
- No code changes needed (OAuth path already proven in Phase 1)

### Rationale

- Dual path is the only approach that provides Gmail support at launch without CASA cost
- Both code paths (`GmailApiAdapter` and `GenericImapAdapter`) already exist and are tested
- Phase 1 proves OAuth works, Phase 2 provides broad Gmail access, Phase 3 is a business trigger
- Gmail app passwords may be deprecated by Google eventually, but CASA path will be ready
- This approach does NOT exclude Gmail users (Option E rejected for this reason)

## Alternatives Considered

| Option | Verdict | Reason |
|--------|---------|--------|
| Option A: REST API + CASA now | Rejected | CASA cost ($550-$8,000+/yr) not justified before revenue |
| Option B: Incremental scopes | Rejected | Both scopes restricted; UX complexity with no verification benefit |
| Option C: App passwords only | Partially adopted (Phase 2) | Provides GA Gmail support without CASA |
| Option D: Dual path | **Adopted** | Best balance of UX, cost, and time to market |
| Option E: No Gmail | Rejected | Excludes largest email provider; unnecessary given app password path |

## Consequences

### Positive
- Gmail support available from day one (app passwords in Phase 2)
- Zero upfront CASA cost
- OAuth infrastructure validated during alpha/beta (Phase 1)
- Clear, measurable trigger for CASA investment (revenue-based)
- No new code needed for any phase -- all adapters already exist

### Negative
- General users must manually create Gmail app passwords (less convenient than OAuth)
- App password setup requires 2FA enabled (increasingly common but still a requirement)
- Does not work for Google accounts with Advanced Protection enabled (edge case)

### Neutral
- Google may deprecate app passwords in the future -- mitigated by having CASA-ready OAuth path
- ADR-0029 and this ADR share the same phased approach (decisions are consistent)
- F12 (Persistent Gmail Auth) is resolved: not a code problem, but a verification status issue

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
