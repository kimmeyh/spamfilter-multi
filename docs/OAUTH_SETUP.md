# OAuth Setup Guide

Complete guide for setting up Gmail OAuth authentication on Windows Desktop and Android platforms.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Android Setup](#android-setup)
4. [Windows Desktop Setup](#windows-desktop-setup)
5. [Secrets Configuration](#secrets-configuration)
6. [Troubleshooting](#troubleshooting)

---

## Overview

The Spam Filter app uses Google OAuth 2.0 to authenticate with Gmail accounts. Different platforms require different OAuth client configurations:

| Platform | Client Type | Client Secret | Authentication Flow |
|----------|-------------|---------------|---------------------|
| **Android** | Web Application | Required | flutter_appauth (native) |
| **Windows** | Desktop Application | Required | Authorization Code + PKCE |

---

## Prerequisites

### Google Cloud Project
- Firebase project: `spamfilter-multi`
- Gmail API enabled
- OAuth consent screen configured

### Local Files (Never Commit)
- `mobile-app/secrets.dev.json` - OAuth credentials
- `mobile-app/android/app/google-services.json` - Firebase config (Android only)

---

## Android Setup

### Step 1: Extract SHA-1 Fingerprint

```powershell
cd mobile-app\android
.\get_sha1.bat
```

Copy the SHA-1 value (format: `XX:XX:XX:XX:...`)

### Step 2: Register in Firebase Console

1. Open https://console.firebase.google.com/
2. Select project: `spamfilter-multi`
3. Go to Project Settings (gear icon)
4. Scroll to "Your apps" section
5. Find your Android app
6. Click "Add fingerprint"
7. Paste the SHA-1 value and save

### Step 3: Download google-services.json

1. In Firebase Console, click "Download google-services.json"
2. Save to: `mobile-app/android/app/google-services.json`

### Step 4: Build and Test

```powershell
cd mobile-app/scripts
.\build-with-secrets.ps1 -BuildType debug -InstallToEmulator -StartEmulator
```

### Step 5: Enable the Custom URI scheme on the Android OAuth client (F211, REQUIRED)

**Without this, Google Sign-In fails for EVERY user with `Error 400: invalid_request`** and,
under "error details", the actual cause:

> Custom URI scheme is not enabled for your Android client.

This blocked all Google Sign-In on the 0.15.0 closed test and was reported 2026-09-10 by the
project's first external tester. The app-password path still worked, which is why it went
unnoticed through a full sprint of validation on accounts that already had app passwords.

**Why it happens**: Google now disables Custom URI schemes BY DEFAULT on newly-created Android
OAuth clients, because the scheme can be claimed by another app on the device (app
impersonation). This app uses `flutter_appauth`, which is built on exactly that mechanism:
The redirect scheme is registered by `flutter_appauth`'s own bundled manifest (via
`RedirectUriReceiverActivity`), fed by the `appAuthRedirectScheme` manifestPlaceholder that
`build.gradle.kts` derives from the Android client id. Our `AndroidManifest.xml` deliberately does
NOT register it -- see F227 below. And
`android/app/build.gradle.kts` derives that placeholder from the client id prefix.

**The fix is entirely in the Google Cloud Console. No code change, no rebuild, no new release.**

1. Open https://console.cloud.google.com/apis/credentials
2. Select the project used for this app.
3. Under **OAuth 2.0 Client IDs**, open the **Android** client whose id matches
   `ANDROID_GMAIL_CLIENT_ID` in `secrets.prod.json` / `secrets.dev.json`.
   **Match on the ID, never on the name.** This project has a client called
   "spamfilter-multi Android OAuth Client ID" whose Type is **Web application**, which is not
   the one you want.
4. Open the **Advanced Settings** section of that client's configuration page.
5. Enable the **Custom URI scheme** method.
6. Save.

**Then check the other two fields on that same page.** An Android OAuth client is bound to a
package name AND a certificate fingerprint, and the scheme setting is worth nothing if either
is wrong. Found 2026-09-11: this project's client had BOTH wrong, which is the likelier root
cause of F211 than the scheme setting was.

7. **Package name** must equal `applicationId` in `android/app/build.gradle.kts` --
   `com.myemailspamfilter`. It read `com.example.spamfiltermobile`, the unedited Flutter
   template default, left behind when the app was renamed.
8. **SHA-1 certificate fingerprint** must be the **Play App Signing** certificate for any
   build installed from Play, NOT your local keystore. Google re-signs the app with its own
   key, so the fingerprint Google sees at sign-in is Play's. Get it from Play Console ->
   your app -> **Protected with Play** -> **App signing** -> **App signing key certificate**
   (Google moved this out of "App integrity" in 2026).
   - Keep the debug fingerprint as well. A client accepts multiple, and the debug one is what
     lets local debug builds sign in.
   - The value found here was `F6:CF:21:...:8F:17`, which is `~/.android/debug.keystore` --
     so the client was configured for a local debug build of an app that no longer exists
     under that name.

**WHICH CLIENT THE PLAY BUILD ACTUALLY USES** (settled by Harold, 2026-09-14):

`build-with-secrets.ps1` passes `--dart-define-from-file=secrets.dev.json` for EVERY build
including release, and `secrets.prod.json` does not exist in the dev worktree at all -- so a Play
bundle is always built with the DEV worktree credentials. The two worktrees hold DIFFERENT Android
client ids (dev `577022808534-0ejd...`, prod `577022808534-v94j...`).

Harold confirmed the dev client (`0ejd`) is correct and is what ships: it is what 0.15.0 shipped
with, and it is the client the F211 console fixes are being applied to. **Do not fix this by
pointing the Play build at the prod worktree secrets** -- that would apply the F211 repairs to one
client while shipping another.

Recorded because the Play release process does not state which secrets file it uses, and the
mismatch looks like a defect until you know it is deliberate.

**STATUS 2026-09-16: ALL THREE CONSOLE FIELDS ARE CORRECT AND SAVED.** Harold opened the client
page and every value was already right on load -- package name `com.myemailspamfilter`, SHA-1
`3B:C2:42:...:33:92` (the Play App Signing key), Custom URI scheme enabled. A form loads from the
server, so those are the persisted values, not unsaved edits.

**What this does NOT yet prove**: that sign-in works. The client page's "Last used date" and its
pending-deletion warning are HISTORICAL -- neither updates until a real request matches the
client. Only a successful sign-in closes this out.

**Two conditions must BOTH hold before a test means anything:**

1. **The test account must be a listed test user.** Publishing status is **Testing**, so only
   accounts on the Audience page can sign in at all. An unlisted account fails with a DIFFERENT
   error and sends the diagnosis the wrong way. Add it at
   `console.cloud.google.com/auth/audience` -> Test users -> Add users.
2. **The build must be installed FROM PLAY.** The SHA-1 now registered is the Play App Signing
   key, so only a Play-installed build presents it. A local debug build presents the debug
   fingerprint and will fail regardless.

**OPEN ANOMALY, unproven, recorded so it is not rediscovered**: the **Data Access** page shows
ALL THREE scope tables EMPTY -- no `gmail.modify`, no `userinfo.email` -- while the app requests
both in code (`google_auth_service.dart:57,61`). That is not a normal configuration and is a
plausible second cause of the `Error 400: invalid_request`. It has NOT been shown to cause the
failure; it is a candidate sitting alongside the two confirmed misconfigurations. **If sign-in
still fails after propagation, look here next.**

**Cost question, settled 2026-09-16.** Harold's concern was a $5,000/year verification fee. The
console says otherwise: Verification Center reads *"Verification is not required since your app
is configured with a Testing publishing status."* The $5,000 figure is CASA Tier 2, which
attaches to **restricted** scopes (`https://mail.google.com/`). This app requests
**`gmail.modify`**, which Google classifies as **sensitive** -- OAuth verification on publish, a
review rather than a paid third-party security audit. **The real constraint is the 100-user
LIFETIME cap in Testing**, which at 12 testers is not close, but would need resolving before Play
production.

**THE TWO FINGERPRINTS FOR THIS PROJECT** (recorded 2026-09-11 so nobody has to hunt again):

| Which | SHA-1 | Used by | Goes in the OAuth client? |
|---|---|---|---|
| **App signing key** (Classical) | `3B:C2:42:60:27:14:4F:7F:AD:6E:10:D1:5E:DF:42:8F:E2:01:33:92` | what Google sees when ANY Play-installed build requests sign-in | **YES -- this one** |
| Upload key | `C3:A5:47:E0:E9:26:B4:30:DF:62:CC:2D:55:1A:88:4C:C8:43:2C:31` | signing the bundle before upload; never leaves the build pipeline | NO |
| Local debug keystore | `F6:CF:21:00:94:7A:D9:4E:8A:E9:25:66:5F:8F:20:DB:55:15:8F:17` | `~/.android/debug.keystore`, local debug builds only | only for a separate `.dev` client |

**THE UPLOAD KEY IS THE TRAP, and it nearly cost a cycle here.** Both fingerprints live on the
same Play Console page, but the upload key is displayed as plain text while the app signing key
is hidden behind a copy button in the "App signing key / Classical key" panel at the TOP. The
visible one is the wrong one. Entering it would have produced a sign-in that still failed, after
Google's multi-hour propagation window, with nothing to distinguish "wrong fingerprint" from
"fix did not work".

The rule that disambiguates them: **Play RE-SIGNS the app**, so only the app signing key reaches
Google at sign-in time. The upload key proves to Google that a bundle came from you.

Ignore the **Post-quantum cryptography key** column -- it is a Google beta, and OAuth client
registration expects the classical fingerprint.

These are NOT secrets -- a certificate fingerprint is public by design, which is why recording
them here is safe and why they belong in the repo rather than in a chat transcript.

Found via Play Console -> **Protected with Play** -> **Play Store protection** -> *Protect app
signing key* -> **Manage Play app signing**. (Google has moved this twice: it was under "App
integrity", and before that under "Setup > App signing".) The same page shows *Releases signed
by Play*, which is the confirmation that Google re-signs the app and therefore that the Play
fingerprint -- never the local one -- is what Google sees at sign-in.

**How to tell this has been wrong all along**: the client page shows a **Last used date** and,
after six months of no matching requests, a warning that the client will be deleted. A client
that the shipped app has never successfully reached shows exactly that. Read those two fields
as evidence, not decoration.

**Dev builds need their own client.** `build.gradle.kts:119` appends `.dev` to the
applicationId, so `com.myemailspamfilter.dev` is a DIFFERENT package and one OAuth client
cannot serve both. Google Sign-In in a dev build requires a second Android client registered
against the `.dev` package and the debug fingerprint.

**Changes take 5 minutes to a few hours to take effect** (Google's own stated range), so a
failure immediately after saving is not proof the fix did not work.

**Verify as a TESTER, not as yourself**: sign in with a Google account that has NEVER authorised
this app. An account with prior consent can succeed while every new user still fails -- that is
precisely how this defect survived undetected.

**Why no repo change is needed**: `build.gradle.kts` computes
`appAuthRedirectScheme` from whatever client id the secrets file supplies
(`resolvedClientId.substringBefore(".")`). Enabling the setting on the EXISTING client leaves
the id unchanged, so the manifest, the build and the published package are all untouched. A
change of client id would be a different matter -- it would require a rebuild and a new Play
submission.

**Known future risk, recorded so it is not rediscovered under pressure**: Google describes
Custom URI schemes as the legacy path and recommends the Google Identity Services for Android
SDK instead, stating "In the future, we may disallow Custom URI scheme methods." No cutoff date
has been published. This is not urgent today, but it is a standing migration item rather than a
permanent solution.

Sources: [Improving user safety in OAuth flows through new OAuth Custom URI scheme
restrictions](https://developers.googleblog.com/improving-user-safety-in-oauth-flows-through-new-oauth-custom-uri-scheme-restrictions/),
[OAuth 2.0 for Mobile & Desktop Apps](https://developers.google.com/identity/protocols/oauth2/native-app).

### Android Emulator Requirements

The emulator MUST use a Google APIs image (not AOSP):
- [OK] `Google APIs ARM64 v8a`
- [OK] `Google Play ARM64 v8a`
- [FAIL] `Android Open Source Project ARM64 v8a` (No Google Services)

Check in Android Studio → Virtual Device Manager → Edit device → System image.

---

## Windows Desktop Setup

### Step 1: Google Cloud Console Configuration

1. Go to https://console.cloud.google.com/apis/credentials
2. Find or create a Desktop Application OAuth client
3. Note the Client ID and Client Secret
4. No redirect URI configuration needed (uses loopback)

### Step 2: Configure secrets.dev.json

```json
{
  "WINDOWS_GMAIL_DESKTOP_CLIENT_ID": "YOUR_CLIENT_ID.apps.googleusercontent.com",
  "WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET": "GOCSPX-YOUR_SECRET",
  "GMAIL_REDIRECT_URI": "http://localhost:8080/oauth/callback"
}
```

### Step 3: Build and Test

```powershell
cd mobile-app/scripts
.\build-windows.ps1
```

---

## Secrets Configuration

### File: `mobile-app/secrets.dev.json`

Create from template:
```powershell
cp mobile-app/secrets.dev.json.template mobile-app/secrets.dev.json
```

Required fields:
```json
{
  "WINDOWS_GMAIL_DESKTOP_CLIENT_ID": "...",
  "WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET": "...",
  "GMAIL_REDIRECT_URI": "http://localhost:8080/oauth/callback",
  "AOL_EMAIL": "your-aol-email@aol.com",
  "AOL_APP_PASSWORD": "your-aol-app-password"
}
```

### How Secrets Are Injected

Build scripts use `--dart-define-from-file` to inject secrets at compile time:
```powershell
flutter run --dart-define-from-file=secrets.dev.json
```

---

## Troubleshooting

### Android: Google Sign-In fails with `null_intent` (F219, Sprint 70)

**Status (2026-09-18): CODE FIX APPLIED, DEVICE VERIFICATION STILL OPEN.** The manifest change is
committed and gated by a test. AC-1 and AC-2 are MANUAL on a Play-installed build and have NOT yet
been performed -- no Android device was attached during implementation. **Do not treat this entry
as a confirmed fix until the device checks below pass.**

**Cause**: `android:taskAffinity=""` on `MainActivity` in `AndroidManifest.xml`.

`net.openid.appauth.RedirectUriReceiverActivity` carries the OAuth redirect intent filter (scheme
`${appAuthRedirectScheme}`), declared by `flutter_appauth` in its own bundled manifest. **F227
(Sprint 70) REMOVED the duplicate filter that `MainActivity` used to carry** -- two activities
claiming one scheme made Android show a chooser instead of delivering the callback. `MainActivity`
now declares only MAIN/LAUNCHER. An
EMPTY task affinity means the activity belongs to no task, so when the browser fires the redirect,
Android has no task to route it back into. The intent never arrives, and `flutter_appauth` reports
the missing intent as `null_intent`.

**Where the line came from**: nothing deliberate. `git log -S taskAffinity` places it in
"Initialize Android project structure" -- the Flutter Android template default. There was no
original intent to protect, which is why removal was safe to consider at all.

**Which Android sign-in path this affects, and a correction worth recording.** The sprint card
named `flutter_appauth` as the suspect library. That is right, but not the whole picture:
`google_auth_service.dart` tries NATIVE `google_sign_in` 7.x FIRST and falls back to the
`flutter_appauth` browser flow only when the native attempt throws (`_signInNative` catch block,
Android only). So `null_intent` is a FALLBACK-path failure. A native-path failure looks different
and is diagnosed separately -- do not assume every Android sign-in failure is this bug.

**Fix**: remove the attribute. Do NOT set an explicit value.

The upstream `flutter_appauth` threads show both remedies with neither stated as canonical, so the
choice was made on this app's facts: `build.gradle.kts` sets `applicationIdSuffix ".dev"`, so dev
and prod are SEPARATE installed apps. Removing the attribute gives each build Android's default
affinity, which is its own `applicationId`, keeping the two in separate tasks automatically. A
hardcoded explicit affinity would collapse dev and prod into one task, trading an OAuth bug for a
side-by-side-install bug.

**Regression gate**: `test/policy/f219_task_affinity_test.dart` fails the build if the attribute
returns. It strips XML comments before searching, because the manifest's own rationale comment
quotes the attribute it removed. The gate is mutation-verified: reintroducing the line turns it
red.

**Blast radius, and the MANUAL checks that remain (AC-2)**: task affinity governs EVERY activity
launch, not only OAuth. These three must be re-verified on a device, and they are the part most
likely to be skipped:

1. Launcher start (cold start from the app icon)
2. Return from recents (background the app, reopen from the recents switcher)
3. Deep links (`app_links` is a dependency)

Plus AC-1: a listed test user completes Google Sign-In on a **Play-installed** build with no app
password.

**If device testing shows this was NOT the fix**: say so here explicitly and revert the manifest
change rather than leaving a changed line that did nothing. The next candidate on the list is the
Google Cloud Console **Data Access** page listing NO scopes while the app requests `gmail.modify`
and `userinfo.email` -- recorded as a candidate, not a finding.

### Android: "Sign in was cancelled"

**Cause**: SHA-1 fingerprint not registered in Firebase Console.

**Solution**:
1. Run `get_sha1.bat` to extract fingerprint
2. Add to Firebase Console → Project Settings → Your apps → Add fingerprint
3. Download fresh `google-services.json`
4. Clean rebuild: `flutter clean && flutter pub get`

### Android: "Access blocked ... Error 400: invalid_request" on Google Sign-In

**Cause**: the Custom URI scheme method is disabled on the Android OAuth client. Tap "error
details" on the Google screen to confirm -- it reads "Custom URI scheme is not enabled for your
Android client."

**Solution**: Android Setup Step 5 above. Console-only; no rebuild. Allow up to a few hours for
the change to propagate, and verify with a Google account that has never authorised the app.

**Workaround while waiting**: an app password works and is unaffected by this setting.

### Android: "Google Play Services not available"

**Cause**: Emulator using AOSP image without Google Services.

**Solution**: Create new emulator with "Google APIs" or "Google Play" system image.

### Windows: "client_secret is missing"

**Cause**: `secrets.dev.json` missing or incomplete.

**Solution**:
1. Verify `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET` is set in `secrets.dev.json`
2. Rebuild with `.\build-windows.ps1`

### Windows: "invalid_client"

**Cause**: Wrong client ID or client not enabled.

**Solution**:
1. Verify client ID matches Google Cloud Console
2. Check client is enabled (not disabled/deleted)
3. Try resetting the client secret in Google Cloud Console

### Windows: Port 8080 already in use

**Cause**: Another process using the OAuth callback port.

**Solution**:
```powershell
netstat -ano | findstr :8080
taskkill /PID <PID> /F
```

---

## Security Checklist

- [ ] `secrets.dev.json` in `.gitignore` (never commit)
- [ ] `google-services.json` in `.gitignore` (never commit)
- [ ] Client secrets not in code comments or logs
- [ ] OAuth tokens stored in secure storage (Keychain/Keystore)

---

## References

- [Google OAuth 2.0 for Desktop Apps](https://developers.google.com/identity/protocols/oauth2/native-app)
- [Firebase Console](https://console.firebase.google.com/)
- [Google Cloud Credentials](https://console.cloud.google.com/apis/credentials)
