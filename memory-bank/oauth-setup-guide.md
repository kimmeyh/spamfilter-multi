# OAuth & Email Authentication Setup Guide

## Overview

This document provides a comprehensive overview of email authentication methods in the Spam Filter Mobile app across all platforms.

---

## Platform-Specific Authentication

### Windows Desktop

**Email Providers:**
- Gmail (OAuth 2.0 with PKCE)
- AOL (IMAP with App Password)
- Outlook (deferred/future implementation)

**Gmail OAuth Details:**
- **Client Type:** Desktop Application
- **Authentication Flow:** Authorization Code + PKCE
- **Client Secret:** Required ✅
- **Redirect URI:** Loopback (`http://localhost:8080/oauth/callback`)
- **Documentation:** [WINDOWS_GMAIL_OAUTH_SETUP.md](../mobile-app/WINDOWS_GMAIL_OAUTH_SETUP.md)

**Key File:** `mobile-app/lib/adapters/email_providers/gmail_windows_oauth_handler.dart`

**Secrets Configuration:** `mobile-app/secrets.dev.json`
```json
{
  "WINDOWS_GMAIL_DESKTOP_CLIENT_ID": "577022808534-****************************kcb.apps.googleusercontent.com",
  "WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET": "GOCSPX-**********************LSH6"
}
```

### Android Mobile

**Email Providers:**
- Gmail (OAuth 2.0 via flutter_appauth)
- AOL (IMAP with App Password)

**Gmail OAuth Details:**
- **Client Type:** Web Application
- **Authentication Flow:** flutter_appauth (native Android authentication)
- **Client Secret:** Required ✅
- **Documentation:** 
  - [ANDROID_GMAIL_SIGNIN_QUICK_START.md](../mobile-app/ANDROID_GMAIL_SIGNIN_QUICK_START.md)
  - [ANDROID_GMAIL_SIGNIN_SETUP.md](../mobile-app/ANDROID_GMAIL_SIGNIN_SETUP.md)

**Key Files:** 
- `mobile-app/lib/adapters/auth/google_auth_service.dart`
- `mobile-app/android/app/google-services.json`

### iOS Mobile

**Gmail OAuth Details:**
- **Client Type:** Web Application
- **Authentication Flow:** flutter_appauth (native iOS authentication)
- **Status:** Currently configured, untested

---

## Critical Implementation Details

### Why Platform-Specific Client IDs?

Different OAuth clients are required for different platforms due to:

1. **Security Requirements:**
   - Desktop apps can't protect client secrets in the same way as backend servers
   - Desktop OAuth clients are designed specifically for native applications
   - Different token storage mechanisms per platform

2. **Platform Constraints:**
   - Desktop: Uses loopback redirect URI (localhost)
   - Android: Uses custom scheme redirect URI (e.g., `com.googleusercontent.apps.577022808534...`)
   - iOS: Uses custom scheme redirect URI

3. **OAuth Flow Differences:**
   - Desktop: Authorization Code + PKCE (browser-based)
   - Android/iOS: flutter_appauth handles native authentication

### Client Secret Requirement

**Contrary to common belief**, even PKCE flows require a client secret when using a Desktop OAuth client with Google. This is because:

1. Google Desktop clients are registered with secrets in the Cloud Console
2. The token exchange endpoint requires the client secret for validation
3. PKCE adds an additional security layer but does not eliminate the client secret requirement
4. The client secret proves that the exchange is from the legitimate app (not a spoofed request)

**Impact:** If `client_secret` is missing during token exchange, Google will reject with:
```
error: "invalid_request"
error_description: "client_secret is missing."
```

### Environment Variable Injection

Secrets are injected at **compile time** using `--dart-define-from-file`:

```powershell
flutter run --dart-define-from-file=secrets.dev.json
```

This converts JSON keys to Dart compile-time constants:

```dart
static const String _clientSecret = String.fromEnvironment(
  'WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET',  // Key name must match JSON
  defaultValue: '',
);
```

**Critical:** The environment variable name in Dart code must **match exactly** (case-sensitive) the JSON key in `secrets.dev.json`.

---

## Build & Deployment

### Development Build (with secrets injection)

**Windows:**
```powershell
cd mobile-app
.\scripts\build-windows.ps1
```

**Android:**
```powershell
cd mobile-app
.\scripts\build-with-secrets.ps1 -BuildType debug -InstallToEmulator
```

Both scripts:
1. Load `secrets.dev.json`
2. Inject secrets via `--dart-define-from-file`
3. Build the app
4. Run/install to device

### Production Build

For production releases, secrets must be injected via:
- Environment variables
- CI/CD pipeline secrets management
- Configuration management systems

**Never** commit `secrets.dev.json` to version control (should be in `.gitignore`)

---

## Token Storage & Refresh

### Secure Token Storage

All OAuth tokens are encrypted and stored using platform-specific secure storage:

**Windows:**
- Storage: Windows Credential Manager
- Encryption: Windows DPAPI

**Android:**
- Storage: Android Keystore
- Encryption: Hardware-backed or software encryption

**Implementation:** `mobile-app/lib/adapters/storage/secure_credentials_store.dart`

### Token Refresh

Refresh tokens are automatically used to obtain new access tokens when they expire:

```dart
Future<String> refreshAccessToken(String refreshToken) async {
  // Exchanges refresh_token for new access_token
  // Sends client_id, client_secret, refresh_token, grant_type
  // Returns new access_token (usually valid for 3599 seconds / ~1 hour)
}
```

---

## Security Checklist

- [ ] Client secrets never committed to version control
- [ ] `secrets.dev.json` in `.gitignore`
- [ ] Compile-time injection used (not runtime file loading)
- [ ] Sensitive values redacted in logs (truncated to first 20 chars)
- [ ] Tokens stored in secure, encrypted storage
- [ ] PKCE enabled for authorization code flow
- [ ] Proper token refresh before expiration
- [ ] Platform-specific OAuth clients used (not generic)

---

## Troubleshooting Guide

### Error: "client_secret is missing"

**Windows Gmail OAuth**

**Diagnosis:**
```
⛔ Token exchange failed: 400 - {
  "error": "invalid_request",
  "error_description": "client_secret is missing."
}
```

**Root Causes:**
1. `secrets.dev.json` missing the secret
2. Environment variable name mismatch
3. Stale build (old compiled app still running)

**Solution:**
1. Verify `mobile-app/secrets.dev.json` has: `"WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET": "GOCSPX-..."`
2. Verify Dart code reads: `String.fromEnvironment('WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET', ...)`
3. Rebuild with: `cd mobile-app && flutter clean && .\scripts\build-windows.ps1`

**Verification in logs:**
```
✅ Correct: !   Client Secret: (set, 35 chars)
❌ Wrong:   !   Client Secret: (not set)
```

### Error: "invalid_client"

**All Platforms**

**Diagnosis:**
```
⛔ Token exchange failed: 401 - {
  "error": "invalid_client"
}
```

**Root Causes:**
1. Wrong client ID (using Android client ID on Windows)
2. Client not enabled in Google Cloud Console
3. Client secret is incorrect/outdated

**Solution:**
1. Verify correct client ID for platform:
   - Windows: `577022808534-****************************kcb.apps.googleusercontent.com`
   - Android: `577022808534-****************************ga2.apps.googleusercontent.com`
2. Check Google Cloud Console: https://console.cloud.google.com/apis/credentials
3. Verify client is enabled and has a secret
4. If secret expired, reset it and update `secrets.dev.json`

### Error: "redirect_uri_mismatch"

**Windows Gmail OAuth**

**Diagnosis:**
```
⛔ Authorization URL rejected: redirect_uri_mismatch
```

**Root Causes:**
1. Desktop client has explicit redirect URI configured (shouldn't have any)
2. Loopback URI not recognized

**Solution:**
1. Go to Google Cloud Console → Credentials
2. Click on Desktop client
3. Remove any redirect URIs (Desktop clients use automatic loopback)
4. Ensure app uses: `http://localhost:8080/oauth/callback`

### Port 8080 Already in Use

**Windows**

**Symptom:**
```
⛔ Local OAuth callback server failed to start
Socket binding error on port 8080
```

**Solution:**
```powershell
# Find process using port 8080
netstat -ano | findstr :8080

# Kill process by PID
taskkill /PID <PID> /F

# Or close applications (Node.js dev servers, etc.)
```

---

## References & Documentation

### Primary Documentation
- **Windows Gmail OAuth:** [WINDOWS_GMAIL_OAUTH_SETUP.md](../mobile-app/WINDOWS_GMAIL_OAUTH_SETUP.md)
- **Android Gmail Sign-In Quick Start:** [ANDROID_GMAIL_SIGNIN_QUICK_START.md](../mobile-app/ANDROID_GMAIL_SIGNIN_QUICK_START.md)
- **Android Gmail Sign-In Detailed Guide:** [ANDROID_GMAIL_SIGNIN_SETUP.md](../mobile-app/ANDROID_GMAIL_SIGNIN_SETUP.md)

### External References
- [Google OAuth 2.0 for Desktop Applications](https://developers.google.com/identity/protocols/oauth2/native-app)
- [PKCE (RFC 7636)](https://tools.ietf.org/html/rfc7636)
- [Gmail API Authentication](https://developers.google.com/gmail/api/auth/about-auth)
- [flutter_appauth Documentation](https://pub.dev/packages/flutter_appauth)

### Implementation Files
- `mobile-app/lib/adapters/email_providers/gmail_windows_oauth_handler.dart`
- `mobile-app/lib/adapters/email_providers/gmail_oauth_handler.dart`
- `mobile-app/lib/adapters/auth/google_auth_service.dart`
- `mobile-app/lib/adapters/storage/secure_credentials_store.dart`

---

## Version History

| Date | Update | Platform | Status |
|------|--------|----------|--------|
| 2025-12-29 | Fixed Windows Gmail OAuth - client secret injection | Windows | ✅ Complete |
| 2025-12-28 | Verified Windows Desktop OAuth client configuration | Windows | ✅ Complete |
| 2025-12-22 | Created Android Gmail Sign-In guides | Android | ✅ Complete |
| 2025-12-15 | Initial implementation | All | ✅ Complete |

---

## Contact & Support

For issues or questions about authentication setup:
1. Check the relevant platform documentation above
2. Review the error message and troubleshooting section
3. Examine logs for specific error details
4. Verify Google Cloud Console configuration matches documentation
