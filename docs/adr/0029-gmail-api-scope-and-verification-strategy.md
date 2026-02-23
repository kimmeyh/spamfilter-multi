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

**Phased approach**: Keep `gmail.modify` scope, defer CASA verification until financially viable.

### Phase 1: Unverified OAuth (Alpha/Beta Testing)
- Keep Gmail REST API with `gmail.modify` + `userinfo.email` scope (current implementation)
- Use Google Cloud Console in **Testing** mode (100 hand-picked test users)
- Accept 7-day refresh token expiry for testers
- No verification needed, no cost
- Purpose: validate OAuth flow, confirm Google Play setup, alpha/beta testing
- Option to move to "Published + Unverified" during beta for normal token lifetimes (still 100 user cap)

### Phase 2: Gmail App Passwords via IMAP (General Users)
- Gmail users beyond alpha/beta use app passwords with `GenericImapAdapter`
- Same IMAP path already used for AOL and Yahoo -- no new code needed
- No OAuth, no verification, no user caps, no token expiry
- Requires users to have 2FA enabled and create an app password manually
- Provides Gmail support without any Google verification requirements

### Phase 3: CASA Verification (ON HOLD)
- Pursue CASA verification when: (a) app has 2,500+ active Gmail IMAP users at $3 annually or yearly revenue exceeds $5,000 (covering annual CASA cost)
- Enables unlimited OAuth users with long-lived tokens and clean consent screen
- Estimated cost: $550-$8,000+/year depending on CASA tier
- Estimated timeline: 2-6 months from start to approval
- Annual renewal required

### Rationale

- ALL Gmail data access scopes are restricted -- there is no way to avoid CASA for OAuth
- The phased approach matches investment to revenue/user base
- Phase 1 proves the OAuth flow works (code is ready for Phase 3)
- Phase 2 provides Gmail support for all users without verification cost
- Phase 3 is a business decision triggered by concrete revenue metrics, not a technical decision
- No code changes needed between phases (all adapters already exist)

## Alternatives Considered

| Option | Verdict | Reason |
|--------|---------|--------|
| Option A: `gmail.modify` only (CASA required) | Partially adopted (Phase 1/3) | CASA cost not justified until app is viable |
| Option B: Incremental authorization | Rejected | Both scopes are restricted; adds UX complexity with no verification benefit |
| Option C: `gmail.metadata` + upgrade | Rejected | Body-text rules would not work; both scopes still restricted |
| Option D: IMAP with OAuth (`mail.google.com`) | Rejected | Broadest scope, hardest to justify to Google reviewers |

## Consequences

### Positive
- Zero upfront cost for Gmail support
- App can launch with Gmail support immediately (app passwords)
- OAuth infrastructure proven during alpha/beta, ready for CASA when triggered
- Clear financial trigger prevents premature investment

### Negative
- Alpha/beta Gmail testers experience 7-day token re-authentication (acceptable for testers)
- General users must manually create Gmail app passwords (less convenient than OAuth)
- Google may deprecate app passwords in the future (mitigated: CASA path is ready when needed)

### Neutral
- No code changes required for any phase transition
- F12 (Persistent Gmail Auth) is resolved: token lifetime is a verification status issue, not a code issue

## References

- `mobile-app/lib/adapters/auth/google_auth_service.dart` - Current scope configuration (lines 37-52)
- `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart` - Gmail API usage
- GP-4 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Feature description, tasks, and cost estimates
- [Choose Gmail API scopes](https://developers.google.com/workspace/gmail/api/auth/scopes) - Scope documentation
- [Restricted scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification) - Verification process
- [Google CASA assessment](https://appdefensealliance.dev/casa) - Security assessment program
- [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy) - Data handling requirements
- ADR-0011 (Desktop OAuth Loopback Redirect with PKCE) - Current OAuth architecture
