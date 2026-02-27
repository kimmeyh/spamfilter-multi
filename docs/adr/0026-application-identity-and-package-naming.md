# ADR-0026: Application Identity and Package Naming

## Status

Accepted

## Date

2026-02-15 (proposed), 2026-02-23 (accepted)

## Context

The app currently uses the Flutter default development identity:
- **Application ID**: `com.example.spamfiltermobile` (in `build.gradle.kts`)
- **Namespace**: `com.example.spamfiltermobile`
- **App label**: `spamfilter_mobile` (in `AndroidManifest.xml`)
- **MSIX identity**: `SpamFilterMulti` (in `pubspec.yaml`)

Google Play Store requires a unique application ID that:
- Cannot start with `com.example` (reserved for development)
- Must be globally unique across all Play Store apps
- Cannot be changed after first publication (permanent identifier)
- Should follow reverse-domain naming convention (e.g., `com.company.appname`)

The application ID also affects:
- OAuth redirect URI scheme (currently tied to `com.googleusercontent.apps.[client-id]`, which is independent)
- Firebase project configuration (`google-services.json` references package name)
- Credential storage keys (flutter_secure_storage uses package name for isolation)
- MSIX identity on Windows
- Any future iOS/macOS bundle identifiers

The user-facing app name (`android:label`) appears on the home screen, in the app drawer, in the Play Store listing, and in system settings. It should be user-friendly, memorable, and accurately describe the app.

## Decision

### Application Identity

| Property | Current (Development) | Production |
|----------|----------------------|------------|
| **Domain** | N/A | `myemailspamfilter.com` |
| **Application ID** | `com.example.spamfiltermobile` | `com.myemailspamfilter` |
| **Namespace** | `com.example.spamfiltermobile` | `com.myemailspamfilter` |
| **App Name** | `spamfilter_mobile` | `MyEmailSpamFilter` |
| **MSIX Identity** | `SpamFilterMulti` | `MyEmailSpamFilter` |

### Domain Selection

`myemailspamfilter.com` was selected because:
- Available for registration (checked 2026-02-23)
- `.com` TLD is most recognizable and trusted by users
- Name is descriptive and memorable ("My Email Spam Filter")
- Supports Google OAuth brand verification (domain ownership required)
- Will host privacy policy (ADR-0030), account deletion page, and app landing page

Domain registration tracked in Issue #166 (spike).

### Migration Impact

| System | Change Required | Risk |
|--------|----------------|------|
| Android `build.gradle.kts` | Update `applicationId` and `namespace` | Low (build-time) |
| Android `AndroidManifest.xml` | Update `android:label` | Low (build-time) |
| Windows `pubspec.yaml` | Update `msix_config` identity | Low (build-time) |
| Firebase Console | Re-register app with new package name, download new `google-services.json` | Medium (manual step) |
| flutter_secure_storage | New keystore alias (existing debug credentials lost) | Low (development only) |
| OAuth redirect URI | No change needed (tied to OAuth client ID, not package name) | None |
| SQLite database | No change needed (schema is package-independent) | None |

### Key Points

- The OAuth redirect URI scheme is tied to the Google Cloud OAuth client ID, NOT the application ID, so changing the application ID does not break OAuth flows
- Firebase Console must be reconfigured for the new package name (download new `google-services.json`)
- flutter_secure_storage on Android uses the package name for keystore alias isolation
- Any existing debug installations will be treated as a different app after ID change

## Alternatives Considered

| Option | Rejected | Reason |
|--------|----------|--------|
| `com.kimmeyh.spamfilter` (personal domain) | Yes | Ties app identity to personal name; less professional |
| `com.spamfiltermulti.app` | Yes | "multi" is internal terminology, not user-facing |
| `dev.harold.spamfilter` | Yes | `.dev` TLD less recognizable; ties to personal name |
| `myspamfilter.com` | Yes | Domain taken (registered since 2003) |
| `myspamfilter.app` | Yes | `.app` TLD less recognizable than `.com`; `.com` available as `myemailspamfilter.com` |

## Consequences

### Positive
- Professional, descriptive app identity that matches user mental model ("My Email Spam Filter")
- `.com` domain available and supports all Google verification requirements
- Domain serves multiple purposes: privacy policy hosting, brand verification, app landing page
- Clean reverse-domain application ID (`com.myemailspamfilter`)

### Negative
- Annual domain registration cost (~$12-20/year)
- Firebase Console reconfiguration required (manual step during GP-1 implementation)
- Existing debug installations on test devices will not upgrade (treated as different app)

### Neutral
- Application ID is permanent after Play Store publication (cannot be changed)
- All platforms (Android, Windows, iOS, macOS, Linux) will use consistent identity
- OAuth flows are unaffected by the identity change

## References

- `mobile-app/android/app/build.gradle.kts` - Current `applicationId` and `namespace` (line 11, 28)
- `mobile-app/android/app/src/main/AndroidManifest.xml` - Current `android:label` (line 3)
- `mobile-app/pubspec.yaml` - MSIX configuration (lines 77-86)
- GP-1 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Feature description and tasks
- [Android Application ID](https://developer.android.com/build/configure-app-module#set-application-id) - Google documentation
