# ADR-0029: Gmail API Scope and Verification Strategy

## Status

Accepted

## Date

2026-02-15 (proposed), 2026-02-22 (accepted)

## Context

The app uses Gmail API with OAuth 2.0 to access user email for spam filtering. The current implementation requests `gmail.modify` scope, which is classified by Google as a **restricted scope**. Any public app using restricted Gmail API scopes must complete Google's three-tier verification process, including a CASA (Cloud Application Security Assessment) by an approved third-party lab.

### Current OAuth Scope Usage

```dart
class GmailScopes {
  static const String readonly = 'https://www.googleapis.com/auth/gmail.readonly';
  static const String modify = 'https://www.googleapis.com/auth/gmail.modify';
  static const String userInfoEmail = 'https://www.googleapis.com/auth/userinfo.email';
  static const List<String> defaultScopes = [modify, userInfoEmail];
}
```

### Gmail API Scope Classification

| Scope | Classification | Access Level |
|-------|---------------|-------------|
| `gmail.labels` | Non-sensitive | Labels only |
| `gmail.send` | Sensitive | Send only |
| `gmail.readonly` | **Restricted** | Read all messages and metadata |
| `gmail.compose` | **Restricted** | Create/read/update drafts, send |
| `gmail.modify` | **Restricted** | All read/write except permanent delete |
| `gmail.metadata` | **Restricted** | Read metadata, labels, headers (not body) |
| `mail.google.com` | **Restricted** | Full mailbox access including IMAP |

### Google's Three-Tier Verification Process

**Tier 1: Brand Verification** (2-3 business days)
- Domain ownership verification via Google Search Console
- App name, logo, privacy policy URL, terms of service URL
- Authorized redirect URIs configuration

**Tier 2: Sensitive Scope Verification**
- Justification for each scope requested
- Up to 3 links to feature documentation
- Demonstration video of OAuth flow and scope usage
- Justification for why narrower scope is insufficient

**Tier 3: Restricted Scope Verification** (REQUIRED for this app)
- All Tier 1 and Tier 2 requirements
- CASA (Cloud Application Security Assessment) by approved third-party assessor
- Based on OWASP ASVS standard
- Must be renewed annually (every 12 months)

### CASA Assessment Details

| Aspect | Detail |
|--------|--------|
| Framework | OWASP ASVS standard |
| Tiers | Tier 1 (self-assessment), Tier 2 (lab scan), Tier 3 (full audit) |
| Approved Labs | TAC Security, Leviathan Security, DEKRA, Bishop Fox, Prescient Security |
| Cost (Tier 2) | $500-$1,800 per app |
| Cost (Tier 3) | $4,500-$8,000+ per app |
| Broader estimates | Some sources report $15,000-$75,000+ for full process |
| Timeline | 2-6 months from start to approval |
| Renewal | Annual |

### App Feature Requirements vs Scopes

The spam filter needs these Gmail capabilities:

| Feature | Minimum Scope Needed |
|---------|---------------------|
| Read email list (subjects, headers) | `gmail.readonly` or `gmail.metadata` |
| Read email body (for body-text rules) | `gmail.readonly` |
| Move email to trash | `gmail.modify` |
| Move email between folders/labels | `gmail.modify` |
| List folders/labels | `gmail.readonly` or `gmail.labels` |

### Unverified App Limitations

Without verification:
- App limited to 100 users
- OAuth consent screen shows "unverified app" warning
- Refresh tokens may expire after 7 days
- Not suitable for Play Store publication

## Decision

Phased approach that matches verification investment to app viability:

### Phase 1: Unverified OAuth for Alpha/Beta (Current)

Keep `gmail.modify` scope with unverified OAuth. Suitable for alpha/beta testing with hand-picked testers (up to 100 users in Testing mode).

- No code changes needed
- Refresh tokens expire after 7 days in Testing mode (testers must re-authenticate weekly)
- Consent screen shows "unverified app" warning (acceptable for testers)
- Existing `GmailApiAdapter` and `GoogleAuthService` infrastructure works as-is

### Phase 2: Gmail App Passwords via IMAP for General Users

Add Gmail app password support through the existing `GenericImapAdapter` IMAP path. This allows general users to use Gmail without OAuth verification.

- Users manually create Gmail app passwords (Google Account > Security > App passwords)
- Same IMAP path already used for AOL and Yahoo
- No restricted scope needed (no OAuth at all)
- Does not work for accounts with Advanced Protection enabled
- Requires in-app walkthrough for setup (see F12B)

### Phase 3: CASA Verification (On Hold)

Pursue CASA verification when: (a) app has 2,500+ active Gmail IMAP users at $3 annually, or (b) yearly revenue exceeds $5,000 (covering annual CASA cost).

- Enables unlimited OAuth users with long-lived refresh tokens
- Requires Tier 2 or Tier 3 CASA assessment ($500-$8,000+/yr)
- 2-6 months from start to approval
- Annual renewal required

### Key Points

- ALL Gmail data access scopes (except `gmail.labels` and `gmail.send`) are restricted
- There is no way to access Gmail email content with a non-restricted scope
- The CASA audit evaluates the app's security practices, not just scope usage
- CASA assessment cost is a recurring annual expense
- The verification process is the longest lead-time item for Play Store publication (2-6 months)
- Gmail app passwords provide a viable alternative that avoids CASA entirely

## Alternatives Considered

| Option | Verdict | Reason |
|--------|---------|--------|
| A: `gmail.modify` only (current) | Partially adopted (Phase 1) | Good for alpha/beta but limited to 100 users without CASA |
| B: Incremental authorization | Rejected | Both scopes are restricted; no verification benefit, more complex UX |
| C: `gmail.metadata` + `gmail.modify` | Rejected | Body-text rules would not work in metadata mode; both restricted |
| D: IMAP with OAuth (`mail.google.com`) | Rejected | Broadest scope, hardest to justify; Google may reject during verification |
| E: App passwords only (no OAuth) | Partially adopted (Phase 2) | Good for general users but worse UX than OAuth |

## Consequences

### Positive
- No upfront CASA cost (deferred until revenue justifies it)
- Alpha/beta testing can start immediately with existing OAuth infrastructure
- General users can use Gmail via app passwords (same flow as AOL/Yahoo)
- Revenue trigger ensures CASA investment is financially sustainable

### Negative
- Alpha/beta testers must re-authenticate weekly (7-day token expiry in Testing mode)
- General Gmail users must manually create app passwords (worse UX than OAuth)
- App password setup requires in-app walkthrough to guide users
- Google may deprecate app passwords in the future (already removed basic auth for Workspace)

### Neutral
- Existing `GmailApiAdapter` remains for OAuth path (no removal needed)
- New Gmail IMAP path reuses `GenericImapAdapter` (minimal new code)
- F12B feature needed for dual-auth UX and per-account auth method tracking
- CASA verification can be pursued later without architectural changes

## References

- `mobile-app/lib/adapters/auth/google_auth_service.dart` - Current scope configuration (lines 37-52)
- `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart` - Gmail API usage
- GP-4 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Feature description, tasks, and cost estimates
- [Choose Gmail API scopes](https://developers.google.com/workspace/gmail/api/auth/scopes) - Scope documentation
- [Restricted scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification) - Verification process
- [Google CASA assessment](https://appdefensealliance.dev/casa) - Security assessment program
- [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy) - Data handling requirements
- ADR-0011 (Desktop OAuth Loopback Redirect with PKCE) - Current OAuth architecture
