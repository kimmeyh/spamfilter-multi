# ADR-0030: Privacy and Data Governance Strategy

## Status

Proposed

## Date

2026-02-15

## Context

Google Play Store requires a publicly accessible privacy policy for all apps. Additionally, the Google API Services User Data Policy imposes strict requirements on apps that access Gmail data. The app must also comply with GDPR (EU), CCPA (California), and other regional data protection regulations.

### Data the App Handles

| Data Type | How Used | Where Stored | Encrypted at Rest | Shared |
|-----------|----------|-------------|-------------------|--------|
| Email address | Account identification, login | flutter_secure_storage | Yes | No |
| OAuth access tokens | Gmail API authentication | flutter_secure_storage | Yes | No |
| OAuth refresh tokens | Token renewal | flutter_secure_storage | Yes | No |
| IMAP app passwords | IMAP authentication | flutter_secure_storage | Yes | No |
| Email headers (from, subject) | Spam rule evaluation | In-memory only (transient) | N/A | No |
| Email body content | Body-text rule evaluation | In-memory only (transient) | N/A | No |
| Scan result metadata | Results display, history | SQLite database | No | No |
| Spam filter rules | Email evaluation | SQLite database + YAML | No | No |
| Safe sender patterns | Whitelist evaluation | SQLite database + YAML | No | No |
| App settings | Configuration | SQLite database | No | No |
| Account settings | Per-account config | SQLite database | No | No |

### Key Privacy Characteristics

The app has several privacy-favorable characteristics:
- **No backend server**: All processing is local on the user's device
- **No data transmission**: No user data is sent to any server (only to email providers for authentication)
- **No analytics**: Firebase Analytics is included in dependencies but NOT initialized or used
- **No advertising**: No ad SDKs
- **No third-party tracking**: No tracking pixels, no user profiling
- **Transient email access**: Email content is processed in-memory and never persisted

### Google API Services User Data Policy Requirements

For apps using Gmail API (restricted scopes):
- Data use limited to practices explicitly disclosed in privacy policy
- Prohibited uses: selling data, serving ads based on email content, credit assessment, surveillance
- Must request minimum scopes necessary (least privilege)
- Human access to user data prohibited except with explicit consent
- Must delete user data upon request
- Must support account deletion (Google Play policy, effective Jan 28, 2026)

### Privacy Policy Hosting Requirements

- Must be on a publicly accessible, non-geofenced URL
- Cannot be a PDF or editable by users
- Must be linked in Play Console and in-app
- Must be consistent with Data Safety form declarations
- Must comprehensively disclose all data handling

### Account Deletion Requirement (Effective Jan 28, 2026)

If the app allows users to create accounts, it must:
- Provide in-app account deletion
- Provide deletion accessible outside the app (website or other mechanism)
- Delete associated data when account is deleted
- If retaining data, clearly inform users why

## Decision

**TO BE DETERMINED** - This ADR captures the decision criteria. The decision will be made by the Product Owner.

### Options Under Consideration

#### Privacy Policy Hosting

##### Option A: GitHub Pages
- Free hosting via GitHub Pages
- URL: `https://[username].github.io/spamfilter-multi/privacy`
- Versioned in repository alongside code
- Easy to update

##### Option B: Dedicated Website
- Custom domain (e.g., `spamfiltermulti.com`)
- Full control over presentation
- Can also host app landing page, data deletion form
- Cost: $12-$20/year for domain + hosting

##### Option C: Third-Party Privacy Policy Generator
- Services like Termly, TermsFeed, Iubenda
- Template-based generation
- Auto-hosted on their domain
- Cost: $0-$10/month

#### Analytics and Data Collection

##### Option A: Zero Telemetry
- Remove Firebase Analytics entirely
- No crash reporting
- Simplest privacy disclosure ("we collect no data beyond what you provide")
- Hardest to debug production issues

##### Option B: Crash Reporting Only
- Firebase Crashlytics (crash reports + stack traces)
- No usage analytics
- Must disclose in privacy policy and Data Safety form
- Helpful for production stability

##### Option C: Full Analytics
- Firebase Analytics + Crashlytics
- Usage patterns, feature adoption, retention
- Most useful for product decisions
- Most complex privacy disclosures

#### Data Retention

##### Option A: Indefinite Local Storage
- Scan results retained until user deletes
- No automatic cleanup
- Simplest implementation

##### Option B: Time-Based Retention
- Auto-delete scan results after N days
- Configurable retention period in settings
- Privacy-friendly

##### Option C: Session-Based
- Scan results cleared on each new scan
- Minimal data retention
- Most privacy-friendly but least useful

### Decision Criteria

1. **Legal compliance**: Must satisfy GDPR, CCPA, Google API User Data Policy
2. **Google verification**: Privacy policy quality affects OAuth verification outcome
3. **User trust**: Transparency about data handling builds trust
4. **Maintenance**: Privacy policy must be updated when app features change
5. **Cost**: Hosting and legal review costs
6. **CASA audit alignment**: Privacy practices evaluated during security assessment
7. **Data minimization**: Less data collected = simpler compliance

### Key Points

- The app's local-only processing model is a significant privacy advantage
- The Google API Services User Data Policy has specific prohibitions for Gmail data
- Account deletion must be available both in-app and externally (website/email)
- Firebase Analytics dependency should be resolved (either use it and disclose, or remove it)
- The privacy policy is needed before submitting for Gmail OAuth verification (GP-4/ADR-0029)
- The Data Safety form must be consistent with the privacy policy
- GDPR requires disclosure of on-device data storage in privacy policy
- No attorney is on the team; legal review approach must be decided

## Alternatives Considered

Analysis deferred until decision criteria are evaluated by Product Owner.

## Consequences

To be documented after decision is made.

## References

- GP-5 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Feature description and tasks
- GP-10 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Data Safety form requirements
- GP-11 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Account deletion requirements
- [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy)
- [Google Play Data Safety form](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
- ADR-0004 (Dual-Write SQLite + YAML) - Data storage architecture
- ADR-0008 (Platform-Native Secure Credential Storage) - Credential encryption
- ADR-0010 (Normalized Database Schema) - Database structure
