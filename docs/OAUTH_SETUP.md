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
`AndroidManifest.xml` registers `<data android:scheme="${appAuthRedirectScheme}"/>`, and
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
