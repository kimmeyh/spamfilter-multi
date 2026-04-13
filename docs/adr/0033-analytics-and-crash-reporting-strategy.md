# ADR-0033: Analytics and Crash Reporting Strategy

## Status

Accepted

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

**Option A: Zero telemetry.** Remove all Firebase Analytics dependencies. No crash reporting, no analytics, no remote data collection of any kind. Keep `google-services.json` for Google Sign-In only.

### Implementation

- Remove `firebase-analytics` from `build.gradle.kts` dependencies
- Remove `firebase-bom` if no other Firebase services depend on it (verify before removing)
- Keep `google-services.json` (required for Google Sign-In on Android)
- Keep `apply plugin: 'com.google.gms.google-services'` (needed for `google-services.json` processing)
- No Crashlytics, no analytics, no remote logging of any kind

### Debugging Strategy Without Remote Telemetry

- **Local logging**: AppLogger with keyword-based filtering (EMAIL, RULES, EVAL, DB, AUTH, SCAN, ERROR, PERF, UI, DEBUG)
- **Background scan logs**: CSV-based debug logging to local file (Sprint 15)
- **User-reported issues**: GitHub Issues and support email
- **Development testing**: Debug builds with verbose console logging

### Key Points

- The `google-services.json` file is needed for Google Sign-In on Android, independent of Firebase Analytics
- Firebase Analytics can be removed without affecting Google Sign-In
- Removing unused `firebase-analytics` dependency eliminates a code smell that would raise questions during CASA audit
- The app's privacy-focused nature (no backend, no data sharing) is a competitive differentiator that would be undermined by analytics

## Alternatives Considered

### Option B: Firebase Crashlytics Only
- **Description**: Replace `firebase-analytics` with `firebase-crashlytics`. Initialize in `main.dart` with `FlutterError.onError` handler. Crash reports sent to Firebase Console.
- **Pros**: Enables production issue detection, low implementation effort
- **Cons**: Requires privacy disclosures in privacy policy and Data Safety form, sends data to Google servers
- **Why Rejected**: Undermines the app's privacy-focused positioning; privacy disclosures add complexity for minimal benefit at current scale

### Option C: Firebase Crashlytics + Minimal Analytics
- **Description**: Crashlytics for crash reporting plus basic analytics (daily active users, screen views, no custom events).
- **Pros**: Most useful for product decisions (user counts, feature usage)
- **Cons**: Most privacy disclosures required, sends the most data to Google servers
- **Why Rejected**: Directly contradicts the app's local-only, no-telemetry messaging

### Option D: Opt-In Crash Reporting
- **Description**: Include Crashlytics but disabled by default. User enables in Settings ("Help improve this app").
- **Pros**: Most privacy-respectful approach to crash reporting, user has control
- **Cons**: Implementation complexity (Settings UI, consent management, conditional initialization), most users leave defaults so few crash reports received
- **Why Rejected**: Implementation complexity not justified for minimal benefit; can be added later if user base grows and crash visibility becomes essential

## Consequences

### Positive
- Simplest possible privacy disclosures (no data collection to disclose)
- Fully aligns with the app's privacy-focused competitive positioning
- No CASA audit complications from analytics or crash reporting data
- Smaller APK/AAB size without Firebase Analytics dependency
- No dependency on Firebase Console for production monitoring

### Negative
- No remote visibility into production crashes (rely entirely on user reports via GitHub Issues and email)
- Cannot proactively detect issues that users do not report
- No usage metrics for product decisions (feature adoption, user counts)

### Neutral
- Can revisit this decision if user base grows and crash reporting becomes essential (Option D is a natural evolution path)
- Current local logging infrastructure (AppLogger, CSV background scan logs) provides adequate debugging for development and local testing

## References

- `mobile-app/android/app/build.gradle.kts` - Firebase dependencies (lines 49-53)
- `mobile-app/lib/util/app_logger.dart` - Current logging infrastructure
- `mobile-app/lib/core/services/background_scan_service.dart` - CSV debug logging
- GP-12 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Analytics decision feature
- ADR-0030 (Privacy and Data Governance Strategy) - Privacy policy implications
- [Firebase Crashlytics](https://firebase.google.com/docs/crashlytics) - Crash reporting service
- [Firebase Analytics](https://firebase.google.com/docs/analytics) - Analytics service
