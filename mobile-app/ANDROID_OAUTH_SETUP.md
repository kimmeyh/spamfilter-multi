# Android OAuth Setup Guide

This guide explains how to configure the Android app to use the same Desktop OAuth credentials as the Windows app, enabling Gmail sign-in via WebView or Manual Token Entry.

## Quick Start

### 1. Get Your Desktop OAuth Client Secret

Your desktop client JSON is missing the `client_secret`. To get it:

1. Go to [Google Cloud Console - Credentials](https://console.cloud.google.com/apis/credentials)
2. Find your Desktop app client: `577022808534-v94j401b6hvllehkp70pheo4b0injrc1`
3. Click the client name to view details
4. Copy the **Client Secret** (or download the JSON again - it should include the secret)

### 2. Configure Secrets File

```powershell
# Navigate to mobile-app directory
cd mobile-app

# Edit secrets.dev.json and add your client_secret
notepad secrets.dev.json
```

Update the file:
```json
{
  "GMAIL_DESKTOP_CLIENT_ID": "577022808534-v94j401b6hvllehkp70pheo4b0injrc1.apps.googleusercontent.com",
  "GMAIL_OAUTH_CLIENT_SECRET": "YOUR_ACTUAL_CLIENT_SECRET_HERE",
  "GMAIL_REDIRECT_URI": "http://localhost:8080/oauth/callback"
}
```

### 3. Build and Install APK

```powershell
# Build with secrets injected
.\scripts\build-with-secrets.ps1 -InstallToEmulator

# Or just build (no install)
.\scripts\build-with-secrets.ps1
```

This injects the OAuth credentials at compile time so they're available on Android.

### 4. Sign In on Android

In the Android emulator app, you now have three working options:

#### Option A: WebView OAuth (Recommended for Android)
1. Click **"Sign in with WebView"**
2. Sign in with your Gmail account
3. Grant permissions
4. App will save tokens automatically

#### Option B: Manual Token Entry
1. Get fresh tokens from OAuth Playground:
   - Visit: https://developers.google.com/oauthplayground/
   - Click gear ⚙️ → Check "Use your own OAuth credentials"
   - Enter your Client ID and Secret from `secrets.dev.json`
   - Select scopes: `gmail.modify` and `userinfo.email`
   - Authorize and exchange code for tokens
   - Copy Access Token and Refresh Token

2. In Android app, click **"Manual Token Entry"**
3. Paste tokens and submit
4. App validates and saves them

#### Option C: Native GoogleSignIn (May not work in emulator)
- The "Try Native GoogleSignIn" button uses Android's native flow
- Requires Google account in emulator and SHA-1 configured
- Often fails in emulators; use WebView/Manual instead

## Reusing Windows Authentication

Since both Windows and Android now use the same Desktop OAuth client, you can transfer tokens:

### Get Fresh Tokens for Transfer

```powershell
# Run the export helper (guides you through OAuth Playground)
.\scripts\export-tokens-for-android.ps1 -Email "your.email@gmail.com"
```

This script explains how to:
1. Use OAuth Playground with your Desktop credentials
2. Obtain access and refresh tokens
3. Paste them into Android's Manual Token Entry

### Why Transfer Works
- Both platforms use the same Desktop OAuth client (`577022808534...`)
- Tokens are client-specific, so they work on any platform
- Refresh token enables long-term access without re-authentication

## Troubleshooting

### "invalid_client" Error
- Ensure `secrets.dev.json` has the correct `client_secret`
- Rebuild with `.\scripts\build-with-secrets.ps1` to inject secrets
- Verify the Desktop client allows `http://localhost:8080/oauth/callback`

### "Token validation failed"
- For Manual Entry: use tokens from OAuth Playground with YOUR credentials
- Ensure you selected the correct scopes (gmail.modify + userinfo.email)
- Check token hasn't expired (access tokens expire in ~1 hour)

### Native GoogleSignIn Still Fails
- Expected in emulators without proper Google Play Services
- Use WebView or Manual Token Entry instead
- Native works better on real devices with configured SHA-1

## Security Notes

- `secrets.dev.json` is gitignored - **NEVER commit it**
- Client secret is injected at build time, not stored as plain text at runtime
- Tokens are stored in Android Keystore (encrypted)
- For production: use environment variables or CI/CD secret management

## Files Reference

- `secrets.dev.json` - Your OAuth credentials (gitignored)
- `secrets.dev.json.template` - Template with placeholders
- `scripts/build-with-secrets.ps1` - Build script that injects secrets
- `scripts/export-tokens-for-android.ps1` - Helper for token transfer
- `lib/adapters/email_providers/gmail_windows_oauth_handler.dart` - OAuth implementation

## Next Steps

After successful sign-in:
1. Select folders to scan
2. Configure spam rules
3. Run the email scan

The authentication persists across app restarts via secure storage.
