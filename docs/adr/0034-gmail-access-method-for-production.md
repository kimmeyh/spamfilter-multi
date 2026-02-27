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

**Option D adopted (Dual Path)** with phased rollout matching ADR-0029:

### Path 1: Gmail REST API with OAuth (Alpha/Beta Testers)

Keep the existing `GmailApiAdapter` with `gmail.modify` scope for alpha/beta testers. Limited to 100 users in Testing mode. Testers accept weekly re-authentication (7-day token expiry) and "unverified app" warning.

- No code changes to existing Gmail adapter
- Existing `GoogleAuthService` handles token refresh
- Suitable for development, testing, and early adopter feedback

### Path 2: Gmail via IMAP with App Passwords (General Users)

Add Gmail as an IMAP provider option using the existing `GenericImapAdapter`. Users create Gmail app passwords and enter them in the app, same flow as AOL and Yahoo.

**Gmail IMAP settings**:
- Server: `imap.gmail.com`
- Port: 993
- Security: SSL/TLS
- Authentication: App password

**Implementation**: Add Gmail IMAP configuration to `PlatformRegistry` (new `.gmailImap()` factory or similar). The app must track which auth method (OAuth vs app password) is used per Gmail account.

### Path 3: Full OAuth (After CASA Verification)

When CASA verification is completed (trigger: 2,500+ users or $5K/yr revenue per ADR-0029), OAuth becomes available for all users with long-lived tokens. At that point, app passwords remain as a fallback option.

## Alternatives Considered

| Option | Verdict | Reason |
|--------|---------|--------|
| A: Gmail REST API only (`gmail.modify`) | Partially adopted (Path 1) | Good for alpha/beta but requires CASA for general use |
| B: Incremental scopes | Rejected | No verification benefit (both scopes restricted), more complex UX |
| C: App passwords only | Partially adopted (Path 2) | Good for general users but worse UX; risk of future deprecation |
| D: Dual path | **Adopted** | Best balance of coverage and cost; matches phased ADR-0029 strategy |
| E: No Gmail support | Rejected | Gmail is dominant provider; excluding it limits app utility significantly |

## Consequences

### Positive
- Gmail support available at launch (via app passwords) without CASA verification
- Alpha/beta testers get premium OAuth experience
- No upfront CASA cost
- Reuses existing `GenericImapAdapter` for Gmail IMAP (minimal new code)
- All scan and delete features work via both paths

### Negative
- Two Gmail auth paths to maintain (OAuth + IMAP)
- General users must manually create app passwords (in-app walkthrough needed, see F12B)
- App passwords do not work for Google accounts with Advanced Protection
- Google may deprecate app passwords in the future
- Per-account auth method tracking adds complexity to account management

### Neutral
- `GmailApiAdapter` and `GenericImapAdapter` both remain (no removal)
- F12B feature implements the dual-auth UX, walkthroughs, and account tracking
- Migration from app password to OAuth is seamless when CASA is completed (user just re-authenticates)

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
