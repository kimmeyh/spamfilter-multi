# ADR-0029: Gmail API Scope and Verification Strategy

## Status

Proposed

## Date

2026-02-15

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

**TO BE DETERMINED** - This ADR captures the decision criteria. The decision will be made by the Product Owner.

### Options Under Consideration

#### Option A: Use `gmail.modify` (Current Approach)
- Request `gmail.modify` + `userinfo.email`
- Covers all app features (read, move, trash)
- Requires restricted scope verification + CASA audit
- Simplest implementation (no scope changes needed)

#### Option B: Incremental Authorization (`gmail.readonly` + Upgrade to `gmail.modify`)
- Start with `gmail.readonly` for scan/read-only mode
- Request `gmail.modify` only when user enables delete/move actions
- Both are restricted scopes (no reduction in verification requirements)
- More complex UX (two permission prompts)
- May demonstrate principle of least privilege to Google reviewers

#### Option C: Use `gmail.metadata` for Scan + `gmail.modify` for Actions
- Request `gmail.metadata` for scanning (headers only, no body)
- Request `gmail.modify` only when user enables delete/move
- Limitation: Body-text rules would not work in metadata-only mode
- Both are restricted (no verification benefit)

#### Option D: Avoid Gmail API Entirely (IMAP Only)
- Use IMAP with OAuth for Gmail accounts (scope: `mail.google.com`)
- `mail.google.com` is also restricted (broadest scope)
- Google may reject this during verification and require narrower scopes
- Would require rearchitecting Gmail adapter

### Decision Criteria

1. **Verification cost and timeline**: Which approach minimizes CASA assessment scope and cost?
2. **User experience**: How many permission prompts is acceptable?
3. **Feature completeness**: All scan modes (including body-text rules) must work
4. **Google reviewer perception**: Does incremental authorization demonstrate good faith?
5. **Annual renewal**: What is the ongoing cost commitment?
6. **Implementation complexity**: How much code changes are needed?
7. **Go/no-go decision**: Is the cost/effort justified for Play Store publication?

### Key Points

- ALL Gmail data access scopes (except `gmail.labels` and `gmail.send`) are restricted
- There is no way to access Gmail email content with a non-restricted scope
- Incremental authorization does not reduce the verification requirement (both scopes are restricted)
- The CASA audit evaluates the app's security practices, not just scope usage
- CASA assessment cost is a recurring annual expense
- The verification process is the longest lead-time item for Play Store publication (2-6 months)
- This decision may determine whether Play Store publication is financially viable
- Alternative: Publish on Play Store without Gmail support initially (AOL, Yahoo, generic IMAP only)

## Alternatives Considered

Analysis deferred until decision criteria are evaluated by Product Owner.

## Consequences

To be documented after decision is made.

## References

- `mobile-app/lib/adapters/auth/google_auth_service.dart` - Current scope configuration (lines 37-52)
- `mobile-app/lib/adapters/email_providers/gmail_api_adapter.dart` - Gmail API usage
- GP-4 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Feature description, tasks, and cost estimates
- [Choose Gmail API scopes](https://developers.google.com/workspace/gmail/api/auth/scopes) - Scope documentation
- [Restricted scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification) - Verification process
- [Google CASA assessment](https://appdefensealliance.dev/casa) - Security assessment program
- [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy) - Data handling requirements
- ADR-0011 (Desktop OAuth Loopback Redirect with PKCE) - Current OAuth architecture
