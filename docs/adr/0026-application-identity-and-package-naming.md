# ADR-0026: Application Identity and Package Naming

## Status

Proposed

## Date

2026-02-15

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

**TO BE DETERMINED** - This ADR captures the decision criteria. The decision will be made by the Product Owner.

### Options Under Consideration

#### Option A: Branded Name with Personal Domain
- Application ID: `com.[personal-domain].[appname]`
- Example: `com.kimmeyh.spamfilter`
- Requires: Domain ownership for brand verification

#### Option B: App-Specific Domain
- Application ID: `com.[app-specific-domain].app`
- Example: `com.spamfiltermulti.app`
- Requires: Registering a new domain

#### Option C: Generic Developer Name
- Application ID: `dev.[developer-name].[appname]`
- Example: `dev.harold.spamfilter`
- Does not require domain registration

### Decision Criteria

1. **Permanence**: Application ID cannot change after publication
2. **Brand verification**: Google OAuth requires domain ownership for brand verification
3. **Cross-platform consistency**: Should work as Android package name, iOS bundle ID, Windows MSIX identity
4. **User perception**: User-facing app name should be professional and descriptive
5. **SEO/discoverability**: Play Store listing name helps users find the app
6. **Character limits**: Play Store title max 30 characters

### Key Points

- The OAuth redirect URI scheme is tied to the Google Cloud OAuth client ID, NOT the application ID, so changing the application ID does not break OAuth flows
- Firebase Console must be reconfigured for the new package name (download new `google-services.json`)
- flutter_secure_storage on Android uses the package name for keystore alias isolation
- Any existing debug installations will be treated as a different app after ID change

## Alternatives Considered

Analysis deferred until decision criteria are evaluated by Product Owner.

## Consequences

To be documented after decision is made.

## References

- `mobile-app/android/app/build.gradle.kts` - Current `applicationId` and `namespace` (line 11, 28)
- `mobile-app/android/app/src/main/AndroidManifest.xml` - Current `android:label` (line 3)
- `mobile-app/pubspec.yaml` - MSIX configuration (lines 77-86)
- GP-1 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Feature description and tasks
- [Android Application ID](https://developer.android.com/build/configure-app-module#set-application-id) - Google documentation
