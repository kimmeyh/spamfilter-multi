# ADR-0027: Android Release Signing Strategy

## Status

Accepted -- IMPLEMENTED Sprint 64 (2026-08-28, Issue #373): gradle signingConfigs read the
four `-P` properties (env-var fallback) supplied by `build-with-secrets.ps1` from
`%USERPROFILE%\.myemailspamfilter\android-signing.json` (outside the repo, per Option B --
no key.properties); a Release task without them throws; `-Output aab` added for the Play
bundle; keystore material gitignore-banned and pinned by
`test/policy/android_signing_test.dart`.

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

## Upload Keystore Backup and Recovery (Sprint 64 retro IMP-3)

**Why this section exists**: the upload keystore is a single point of failure. Google Play
identifies the developer by the UPLOAD key on every submission. Losing it does not lose the
published app (Play App Signing holds the separate app signing key), but it does block every
future update until a key reset is requested from Google, which is a manual support process
measured in days.

**What must be backed up** (all three, together -- a keystore without its password is useless):

| Item | Location | Notes |
|------|----------|-------|
| Upload keystore | `%USERPROFILE%\.myemailspamfilter\upload-keystore.jks` | The private key. Irreplaceable. |
| Signing config | `%USERPROFILE%\.myemailspamfilter\android-signing.json` | Holds keystore path, alias `upload`, and the password. Plaintext by decision (Sprint 64 MV, Harold chose option 2: file lives outside the repo on a single-user machine). |
| Fingerprint record | This ADR, below | The verification value -- proves a restored keystore is the RIGHT one. |

**Identity of the current upload key** (public information, safe to record):

- Alias: `upload`
- SHA-256: `68:75:8B:9B:7B:EB:CE:0E:C3:EA:3F:A4:05:12:1F:0D:0A:9A:D8:35:01:62:67:5C:61:C3:4C:DA:AD:CD:49:58`
- Created: Sprint 64 (2026-08-28), OU "Information Technology", O "Kimmey Consulting", Ohio
- Verified identical on the keystore, the signed AAB (`keytool -printcert -jarfile`), and the
  signed APK (`apksigner verify --print-certs` -- note `keytool -jarfile` returns NOTHING for an
  APK, because APKs use signature scheme v2/v3 rather than the v1 JAR manifest).

**Backup procedure** (Harold-owned, off-machine):

1. Copy the whole `%USERPROFILE%\.myemailspamfilter\` directory to durable storage that is NOT
   this machine -- an encrypted archive in cloud storage, or a password manager's secure file
   attachment. Both files must travel together.
2. Never commit either file. `.gitignore` already covers `*.jks`, `*.keystore`, and
   `android-signing.json`, but the real protection is that they live outside the repository.
3. Re-verify the backup whenever the keystore is regenerated (it was regenerated once during the
   Sprint 64 ceremony, for a stronger password).

**Recovery verification** (run this after ANY restore, before trusting it):

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.myemailspamfilter\upload-keystore.jks" -alias upload
```

Compare the printed SHA-256 against the fingerprint above. A mismatch means the restored file is
a DIFFERENT key and Play will reject every upload signed with it.

**If the keystore is lost entirely**: request an upload key reset through Play Console support.
The published app survives because Google holds the app signing key under Play App Signing; only
the upload key needs replacing.

## References

- `mobile-app/android/app/build.gradle.kts` - Current release signing config (lines 40-46)
- `mobile-app/scripts/build-apk.ps1` - Current APK build script
- `mobile-app/scripts/build-with-secrets.ps1` - Secrets injection pattern
- GP-2 in `docs/ALL_SPRINTS_MASTER_PLAN.md` - Feature description and tasks
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756) - Google documentation
- [Sign your app (Android Developers)](https://developer.android.com/studio/publish/app-signing) - Signing guide
- ADR-0017 (PowerShell Build Automation) - Build infrastructure context
