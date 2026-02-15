# ADR-0033: Analytics and Crash Reporting Strategy

## Status

Proposed

## Date

2026-02-15

## Context

The app currently includes Firebase dependencies in `build.gradle.kts` but does NOT actively use them:

```kotlin
dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.7.0"))
    implementation("com.google.firebase:firebase-analytics")
}
```

Firebase Analytics is included because it was added during initial project setup for Google Sign-In configuration, but no Firebase initialization code exists in the Dart codebase. The `google-services.json` file is present for Firebase project configuration (needed for Google Sign-In on Android).

### Impact on Play Store Publication

This decision directly affects:

1. **Privacy Policy** (ADR-0030): Analytics must be disclosed if collected
2. **Data Safety Form** (GP-10): Must declare analytics data collection
3. **CASA Security Assessment** (ADR-0029): Auditors will review data handling
4. **User trust**: Users are increasingly privacy-conscious
5. **Production debugging**: Without crash reporting, production issues are invisible

### Current Logging Infrastructure

The app uses `logger: ^2.0.0` (Dart package) for all internal logging:
- `AppLogger` wrapper provides consistent formatting
- Logs written to console in debug mode
- Background scan logs written to CSV files (debug toggle in Sprint 15)
- No remote log collection

### Options Landscape

| Solution | Crash Reports | Analytics | Privacy Impact | Cost |
|----------|-------------|-----------|---------------|------|
| No telemetry | No | No | None | Free |
| Firebase Crashlytics only | Yes | No | Low | Free |
| Firebase Analytics + Crashlytics | Yes | Yes | Medium | Free |
| Sentry | Yes | Minimal | Low | Free tier |
| Self-hosted (none practical) | N/A | N/A | N/A | High |

### Privacy Implications

| Data | Crashlytics | Analytics | Both |
|------|------------|-----------|------|
| Crash stack traces | Yes | No | Yes |
| Device model | Yes | Yes | Yes |
| OS version | Yes | Yes | Yes |
| App version | Yes | Yes | Yes |
| Session duration | No | Yes | Yes |
| Screen views | No | Yes | Yes |
| Custom events | No | Optional | Optional |
| User ID | Optional | Optional | Optional |
| IP address | Temporary | Temporary | Temporary |

All Firebase data is sent to Google servers, which must be disclosed in privacy policy and Data Safety form.

## Decision

**TO BE DETERMINED** - This ADR captures the decision criteria. The decision will be made by the Product Owner.

### Options Under Consideration

#### Option A: Remove All Firebase (Zero Telemetry)
- Remove `firebase-bom` and `firebase-analytics` from `build.gradle.kts`
- Keep `google-services.json` (still needed for Google Sign-In)
- Simplest privacy disclosures
- No production crash visibility
- Align with app's privacy-focused positioning

#### Option B: Firebase Crashlytics Only (Crash Reports)
- Replace `firebase-analytics` with `firebase-crashlytics`
- Add Crashlytics Dart SDK (`firebase_crashlytics`)
- Initialize in `main.dart` with `FlutterError.onError` handler
- Crash reports sent to Firebase Console
- Must disclose in privacy policy and Data Safety form
- Enables production issue detection

#### Option C: Firebase Crashlytics + Minimal Analytics
- Crashlytics for crash reporting
- Analytics for basic metrics (daily active users, screen views)
- No custom event tracking
- More useful for product decisions
- More privacy disclosures required

#### Option D: Opt-In Crash Reporting
- Crashlytics included but disabled by default
- User enables in Settings ("Help improve this app")
- Most privacy-respectful approach
- Fewer crash reports (most users leave defaults)
- More complex implementation

### Decision Criteria

1. **Privacy alignment**: The app positions itself as privacy-focused (no backend, local processing)
2. **Production visibility**: Can production issues be detected and fixed without crash reporting?
3. **Privacy disclosure complexity**: Each data type collected adds privacy policy and Data Safety form complexity
4. **CASA audit impact**: Auditors evaluate all data collection and transmission
5. **User trust**: Privacy-conscious users may avoid apps with analytics
6. **Development value**: How often are crash reports actually useful?
7. **Google Sign-In dependency**: google-services.json is needed regardless of analytics decision

### Key Points

- The `google-services.json` file is needed for Google Sign-In on Android, independent of Firebase Analytics
- Firebase Analytics can be removed without affecting Google Sign-In
- If Firebase Analytics is kept in dependencies but never initialized, it should still be removed to avoid confusion during CASA audit
- The current CSV-based background scan logging provides local debugging capability
- User-reported issues (via email/GitHub) can partially substitute for crash reporting
- The app's privacy-focused nature (no backend, no data sharing) is a competitive differentiator
- Adding analytics could undermine the app's privacy messaging

## Alternatives Considered

Analysis deferred until decision criteria are evaluated by Product Owner.

## Consequences

To be documented after decision is made.

## References

- `mobile-app/android/app/build.gradle.kts` - Firebase dependencies (lines 49-53)
- `mobile-app/lib/util/app_logger.dart` - Current logging infrastructure
- `mobile-app/lib/core/services/background_scan_service.dart` - CSV debug logging
- GP-12 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Analytics decision feature
- ADR-0030 (Privacy and Data Governance Strategy) - Privacy policy implications
- [Firebase Crashlytics](https://firebase.google.com/docs/crashlytics) - Crash reporting service
- [Firebase Analytics](https://firebase.google.com/docs/analytics) - Analytics service
