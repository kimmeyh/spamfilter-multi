# ADR-0027: Android Release Signing Strategy

## Status

Proposed

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

**TO BE DETERMINED** - This ADR captures the decision criteria. The decision will be made by the Product Owner.

### Options Under Consideration

#### Option A: Keystore in Local File with Environment Variables
- Store keystore `.jks` file on local disk (outside repository)
- Reference via environment variables in `build.gradle.kts`
- `key.properties` file (gitignored) points to keystore location
- Similar to Flutter's recommended approach

#### Option B: Keystore Injected at Build Time (Like Secrets)
- Store keystore in a secure location (e.g., encrypted vault, cloud storage)
- Inject at build time via PowerShell script (similar to `build-with-secrets.ps1`)
- Keystore never persists on disk in the repository tree

#### Option C: GitHub Actions / CI-Based Signing
- Keystore stored as GitHub Actions secret (base64-encoded)
- Signing happens in CI/CD pipeline
- Local development uses debug keys; only CI produces release builds

### Decision Criteria

1. **Security**: Keystore and passwords must never be committed to version control
2. **Backup**: Keystore must be recoverable if the development machine is lost
3. **Integration**: Must work with existing PowerShell build scripts
4. **Play App Signing**: Whether to enroll (recommended by Google, adds safety net)
5. **CI/CD compatibility**: Should support future CI/CD pipeline integration
6. **Simplicity**: Developer should be able to produce release builds easily
7. **AAB vs APK**: Build scripts must produce AAB format for Play Store upload

### Key Points

- Play App Signing is mandatory for AAB uploads and strongly recommended
- With Play App Signing, Google manages the actual signing key; developer only needs upload key
- Upload key can be reset through Play Console if lost (unlike the app signing key)
- The existing `build-with-secrets.ps1` pattern (injecting from a JSON file) could be extended for signing
- AAB format results in smaller downloads (Google generates optimized APKs per device)
- Both APK (for testing) and AAB (for Play Store) builds may be needed

## Alternatives Considered

Analysis deferred until decision criteria are evaluated by Product Owner.

## Consequences

To be documented after decision is made.

## References

- `mobile-app/android/app/build.gradle.kts` - Current release signing config (lines 40-46)
- `mobile-app/scripts/build-apk.ps1` - Current APK build script
- `mobile-app/scripts/build-with-secrets.ps1` - Secrets injection pattern
- GP-2 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Feature description and tasks
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756) - Google documentation
- [Sign your app (Android Developers)](https://developer.android.com/studio/publish/app-signing) - Signing guide
- ADR-0017 (PowerShell Build Automation) - Build infrastructure context
