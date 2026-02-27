# ADR-0030: Privacy and Data Governance Strategy

## Status

Accepted

## Date

2026-02-15 (proposed), 2026-02-24 (accepted)

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

Four sub-decisions made for privacy and data governance:

### 1. Privacy Policy Hosting: Dedicated Website (`myemailspamfilter.com`)

Host the privacy policy on the app domain registered per ADR-0026.

| Page | URL | Purpose |
|------|-----|---------|
| Privacy Policy | `myemailspamfilter.com/privacy` | Required by Play Store and Google API User Data Policy |
| Account Deletion | `myemailspamfilter.com/delete` | Required by Play Store (Jan 28, 2026 policy) |
| App Landing Page | `myemailspamfilter.com` | Play Store developer profile link |

**Hosting method**: GitHub Pages with custom domain (free hosting, versioned in repository).

### 2. Analytics and Data Collection: Zero Telemetry

Remove Firebase Analytics dependency entirely. No crash reporting, no usage analytics, no telemetry of any kind.

**Privacy statement**: "We do not collect, transmit, or store any data on our servers. All data remains on your device."

**Implementation**:
- Remove `firebase-analytics` from `android/app/build.gradle.kts` dependencies
- Keep `google-services.json` (still needed for Google Sign-In on Android)
- Firebase BOM may still be needed for Google Sign-In; only remove analytics-specific dependencies

**Rationale**: The app has no backend server. Zero telemetry is the cleanest privacy story and simplifies the Data Safety form and privacy policy significantly. Crash reporting can be added later (ADR-0033) if production debugging becomes a real problem.

### 3. Data Retention: Indefinite Local Storage (User-Controlled Deletion)

Scan results retained on-device indefinitely until the user deletes them. No automatic cleanup.

**Privacy statement**: "Scan results are stored locally on your device until you delete them."

**Rationale**: Already implemented. User has full control via account deletion in the app. Time-based retention (Option B) is a nice-to-have but not needed for launch.

### 4. Account Deletion: In-App + Web Page

**In-app**: Delete button in account management screen that removes:
- Credentials from `SecureCredentialsStore`
- Scan history from SQLite (`scan_results`, `email_actions` for that account)
- Account settings from SQLite (`account_settings` for that account)
- Account record from SQLite (`accounts` table)

**External (web)**: Page at `myemailspamfilter.com/delete` explaining:
- All data is stored locally on the user's device
- No data is stored on any server
- To delete data, open the app and go to Account Management > Delete Account
- If the app is uninstalled, all local data is automatically removed by the OS

**Rationale**: Since there is no backend server, there is no server-side data to delete. The web page satisfies the Google Play requirement for an external deletion mechanism while being honest about the local-only architecture.

### Legal Review: Template-Based Approach

Use an open-source privacy policy generator as the starting template, then customize for:
- Google API Services User Data Policy compliance (Gmail-specific requirements)
- GDPR and CCPA disclosure requirements
- Local-only data processing model
- Zero telemetry declaration

**Recommended template tools** (in order of preference):
1. [App Privacy Policy Generator](https://app-privacy-policy-generator.firebaseapp.com/) (nisrulz) - free, open source, supports "No Tracking" mode
2. [Privacy Policy for No Data Collection](https://www.privacypolicygenerator.info/privacy-policy-no-data-collection/) - template specifically for apps that do not collect data
3. [ArthurGareginyan/privacy-policy-template](https://github.com/ArthurGareginyan/privacy-policy-template) - Markdown/TXT template, easy to customize

**Customization required**: Template output must be augmented with:
- Google API Services User Data Policy compliance section (prohibited uses, minimum scope, no human access)
- Specific disclosure of data types from the Context section of this ADR (credentials stored encrypted, email content transient, etc.)
- Account deletion instructions

**Note**: No attorney on the team. Templates provide reasonable legal coverage for indie apps. Professional legal review can be added later if the app scales.

## Alternatives Considered

| Sub-Decision | Option Chosen | Alternatives Rejected | Reason |
|-------------|--------------|----------------------|--------|
| Hosting | B: Dedicated website | A: GitHub Pages (no custom domain), C: Third-party generator (hosted on their domain) | Domain already registered (ADR-0026); multi-purpose site |
| Analytics | A: Zero telemetry | B: Crash reporting only, C: Full analytics | Simplest privacy story; no backend means no server-side debugging anyway |
| Retention | A: Indefinite local | B: Time-based (configurable), C: Session-based | Already implemented; user controls deletion; time-based is future nice-to-have |
| Legal review | Template-based | Attorney review | Cost-effective for indie app; can add legal review later if needed |

## Consequences

### Positive
- Strongest possible privacy position ("we never see your data")
- Simplest Data Safety form (declare minimal data collection)
- No ongoing analytics costs or privacy disclosure maintenance
- Account deletion is straightforward (local data only)
- Privacy policy hosted on owned domain with full control

### Negative
- No crash reporting means production issues are harder to diagnose (users must report bugs manually)
- Template-based privacy policy may not cover all edge cases (mitigated: can add legal review later)
- Must maintain privacy policy page when app features change

### Neutral
- Firebase Analytics dependency removal is a code task (GP-12 / ADR-0033)
- Account deletion feature (GP-11 / ADR-0032) is implementation work for a future sprint
- Privacy policy must be written and published before Play Store submission (GP-5)

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
