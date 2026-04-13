# ADR-0027: Android Release Signing Strategy

## Status

Accepted

## Date

2026-02-15

## Context

The app currently uses the Flutter debug signing key for release builds:

```kotlin
release {
    // TODO: Add your own signing config for the release build.
    // Signing with the debug keys for now, so `flutter run --release` works.
    signingConfig = signingConfigs.getByName("debug")
}
```

This is unsuitable for Google Play Store publication because:
- Debug keys are auto-generated and unique per development machine
- Debug-signed apps cannot be uploaded to the Play Store
- The debug keystore has no meaningful security (well-known password `android`)

Google Play requires:
- **Android App Bundle (AAB)** format (not APK) for new app submissions
- **Play App Signing** enrollment (Google manages the app signing key)
- An **upload key** (developer-created) to sign the AAB before uploading to Play Console

The signing key strategy has long-term consequences:
- If the upload key is lost, it can be reset through Play Console
- If Play App Signing is not enrolled and the signing key is lost, the app CANNOT be updated (must publish as a new app)
- The keystore file must be securely stored and backed up
- The keystore should NEVER be committed to version control

### Current Build Infrastructure

The project uses PowerShell scripts for builds:
- `build-apk.ps1` - Builds APK
- `build-with-secrets.ps1` - Builds with secrets injection via `--dart-define-from-file`
- `build-windows.ps1` - Windows build

The signing configuration must integrate with this PowerShell build infrastructure, potentially using the same secrets injection pattern as `secrets.dev.json`.

## Decision

**Option B: Build-time keystore injection via PowerShell script**, extending the existing `build-with-secrets.ps1` pattern. Enroll in Google Play App Signing. Build AAB format for Play Store, APK for local testing.

### Implementation Details

- Keystore `.jks` file stored in a secure location outside the repository (e.g., encrypted vault, cloud storage backup)
- PowerShell build script injects keystore path, alias, and passwords at build time
- `key.properties` file is NOT used (avoids persistent credential file on disk in repo tree)
- Signing config in `build.gradle.kts` reads from environment variables or `--dart-define` parameters
- Play App Signing enrollment required (Google manages the app signing key; developer manages the upload key)
- Upload key can be reset via Play Console if lost

### Build Outputs

- **APK**: For local testing and emulator deployment (`build-with-secrets.ps1 -BuildType debug`)
- **AAB**: For Google Play Store upload (release builds only)

### Key Points

- Play App Signing is mandatory for AAB uploads and strongly recommended
- With Play App Signing, Google manages the actual signing key; developer only needs upload key
- The existing `build-with-secrets.ps1` pattern (injecting from a JSON file) is extended for signing
- AAB format results in smaller downloads (Google generates optimized APKs per device)
- Both APK (for testing) and AAB (for Play Store) builds are needed

## Alternatives Considered

### Option A: Keystore in Local File with Environment Variables
- **Description**: Store `.jks` on local disk, reference via `key.properties` (gitignored) and environment variables in `build.gradle.kts`. Follows Flutter's recommended approach.
- **Pros**: Simple setup, well-documented by Flutter team
- **Cons**: Keystore file persists on disk, `key.properties` could accidentally be committed despite gitignore
- **Why Rejected**: Less secure than build-time injection; the project already uses a secrets injection pattern that avoids persistent credential files

### Option C: GitHub Actions / CI-Based Signing
- **Description**: Keystore stored as GitHub Actions secret (base64-encoded). Only CI produces release builds; local development uses debug keys.
- **Pros**: Most secure (keystore never on developer machine), scalable for teams
- **Cons**: No CI/CD pipeline exists yet, adds infrastructure dependency, cannot produce release builds locally
- **Why Rejected**: Premature given current single-developer workflow and no CI/CD pipeline

## Consequences

### Positive
- Consistent with the existing secrets injection pattern (`build-with-secrets.ps1`), reducing cognitive overhead
- Keystore never persists in the repository tree, eliminating accidental commit risk
- Play App Signing enrollment adds a safety net (upload key can be reset if lost)
- Supports future CI/CD integration (environment variables work in both local and CI contexts)

### Negative
- Build script complexity increases (must handle signing parameters in addition to secrets)
- Keystore must be accessible to the build machine (secure backup strategy required)
- Developer must remember to provide signing parameters for release builds

### Neutral
- Both APK and AAB build targets are needed (testing vs Play Store), adding two output formats to maintain

## References

- `mobile-app/android/app/build.gradle.kts` - Current release signing config (lines 40-46)
- `mobile-app/scripts/build-apk.ps1` - Current APK build script
- `mobile-app/scripts/build-with-secrets.ps1` - Secrets injection pattern
- GP-2 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Feature description and tasks
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756) - Google documentation
- [Sign your app (Android Developers)](https://developer.android.com/studio/publish/app-signing) - Signing guide
- ADR-0017 (PowerShell Build Automation) - Build infrastructure context
