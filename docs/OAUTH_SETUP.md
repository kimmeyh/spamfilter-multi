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
