# Windows Gmail OAuth Setup - Complete Guide

## Overview

The Spam Filter Mobile app uses Google OAuth 2.0 with PKCE (Proof Key for Code Exchange) to authenticate with Gmail accounts on Windows. This document explains the complete setup, configuration, and troubleshooting process.

---

## Architecture

### Platform-Specific OAuth Clients

The app uses **different OAuth clients** for different platforms:

| Platform | Client Type | Uses Client Secret | Flow |
|----------|-------------|-------------------|------|
| **Windows** | Desktop Application | ✅ Yes (Required) | Authorization Code + PKCE |
| **Android** | Web Application | ✅ Yes | flutter_appauth (native) |
| **iOS** | Web Application | ✅ Yes | flutter_appauth (native) |

### Why Platform-Specific Clients?

**Windows Desktop Application:**
- Google OAuth Desktop client specifically designed for native desktop apps
- Client ID: `577022808534-****************************kcb.apps.googleusercontent.com`
- Has a client secret (required by Google for desktop clients with credentials)
- Uses PKCE for added security

**Android/iOS Web Application:**
- Different client ID for mobile platforms
- Designed for use with flutter_appauth library
- Client ID: `577022808534-****************************ga2.apps.googleusercontent.com`

---

## Required Configuration

### 1. Google Cloud Project Setup

#### Desktop Client Credentials (for Windows)

1. **Go to** Google Cloud Console:
   - URL: https://console.cloud.google.com/apis/credentials

2. **Find the Desktop client:**
   - Name: "Windows Desktop App OAuth Client"
   - Client ID: `577022808534-****************************kcb.apps.googleusercontent.com`
   - Type: Desktop Application

3. **Verify client secret is enabled:**
   - Click on the client name
   - Confirm: Status = "Enabled"
   - Confirm: Client secret exists (shown as masked, e.g., `****LSH6`)

4. **Verify redirect URI:**
   - No URI configuration needed for Desktop clients (uses loopback address)
   - The app uses: `http://localhost:8080/oauth/callback`

### 2. Secrets Configuration

#### File: `mobile-app/secrets.dev.json`

The app reads OAuth credentials from compile-time environment variables injected from this file:

```json
{
  "_comment": "Web Application OAuth credentials for browser and WebView flows",
  "_note": "Web Application client with redirect URIs configured in Google Cloud Console",
  "GMAIL_REDIRECT_URI": "http://localhost:8080/oauth/callback",
  "WINDOWS_GMAIL_DESKTOP_CLIENT_ID": "577022808534-****************************kcb.apps.googleusercontent.com",
  "WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET": "GOCSPX-**********************LSH6"
}
```

**Critical Fields:**

- `WINDOWS_GMAIL_DESKTOP_CLIENT_ID`: The OAuth client ID for Windows desktop
- `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET`: The OAuth client secret from Google Cloud Console
- `GMAIL_REDIRECT_URI`: Loopback redirect URI for OAuth callback

**⚠️ Important:**
- Never commit `secrets.dev.json` to version control
- The secret should never be exposed in logs or shared
- Environment variable names must match exactly in the Dart code

#### Where Secrets Are Injected

The build script `mobile-app/scripts/build-windows.ps1` uses `--dart-define-from-file` to inject these values:

```powershell
flutter run --profile --dart-define-from-file=secrets.dev.json
```

This converts JSON keys to Dart environment variables at compile time.

---

## Code Implementation

### File: `lib/adapters/email_providers/gmail_windows_oauth_handler.dart`

#### Constants Initialization

```dart
// OAuth 2.0 Configuration - injected at build time via --dart-define
static const String _clientId = String.fromEnvironment(
  'WINDOWS_GMAIL_DESKTOP_CLIENT_ID',
  defaultValue: String.fromEnvironment('GMAIL_DESKTOP_CLIENT_ID', defaultValue: 'YOUR_CLIENT_ID.apps.googleusercontent.com'),
);
static const String _clientSecret = String.fromEnvironment(
  'WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET',
  defaultValue: '',
);
static const String _redirectUri = String.fromEnvironment(
  'GMAIL_REDIRECT_URI',
  defaultValue: 'http://localhost:8080/oauth/callback',
);
```

**Key Points:**
1. `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET` is read from the environment (injected from secrets.dev.json)
2. If not found, defaults to empty string (causes OAuth failure)
3. Environment variable **name must match exactly** in both Dart code and secrets file

#### Token Exchange (Critical Step)

The token exchange includes the client secret:

```dart
static Future<Map<String, String>> exchangeCodeForTokens(String authCode) async {
  // ... setup ...
  
  final requestBody = {
    'client_id': _clientId,
    'code': authCode,
    'redirect_uri': _redirectUri,
    'grant_type': 'authorization_code',
    'code_verifier': _codeVerifier!,  // PKCE
  };
  
  // Add client_secret if available (REQUIRED for Desktop clients)
  if (_clientSecret.isNotEmpty) {
    requestBody['client_secret'] = _clientSecret;
    _logger.i('Including client_secret in token exchange');
  }
  
  // Send to Google OAuth token endpoint
  final response = await http.post(
    Uri.parse(_tokenEndpoint),  // https://oauth2.googleapis.com/token
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: requestBody,
  );
  
  // ... response handling ...
}
```

**⚠️ Critical:** If `client_secret` is missing or empty, Google will reject the token exchange with:
```
error: "invalid_request"
error_description: "client_secret is missing."
```

---

## OAuth Flow (Step-by-Step)

### 1. Authorization Request

User clicks "Sign in with Google" on Windows app.

```
GET https://accounts.google.com/o/oauth2/v2/auth
  ?client_id=577022808534-****************************kcb.apps.googleusercontent.com
  &redirect_uri=http://localhost:8080/oauth/callback
  &response_type=code
  &scope=https://www.googleapis.com/auth/gmail.modify+https://www.googleapis.com/auth/userinfo.email
  &access_type=offline
  &prompt=consent
  &code_challenge=<PKCE_CHALLENGE>
  &code_challenge_method=S256
```

**PKCE Details:**
- `code_challenge`: SHA256 hash of a random 128-character code verifier
- `code_challenge_method`: S256 (SHA256 hash)
- Prevents authorization code interception attacks

### 2. User Authorization

User logs in to their Google account and grants permissions.

Google redirects to the loopback address with authorization code:

```
GET http://localhost:8080/oauth/callback?code=4/0ATX87lMO6O1CrMG...&state=...
```

### 3. Token Exchange

The app's local server receives the code and exchanges it for tokens:

```
POST https://oauth2.googleapis.com/token
Content-Type: application/x-www-form-urlencoded

client_id=577022808534-****************************kcb.apps.googleusercontent.com
&client_secret=GOCSPX-**********************LSH6
&code=4/0ATX87lMO6O1CrMG...
&redirect_uri=http://localhost:8080/oauth/callback
&grant_type=authorization_code
&code_verifier=<ORIGINAL_VERIFIER>
```

**Response (on success):**

```json
{
  "access_token": "ya29.a0AfH6SMBx...",
  "expires_in": 3599,
  "refresh_token": "1//0gU7...",
  "scope": "https://www.googleapis.com/auth/gmail.modify https://www.googleapis.com/auth/userinfo.email",
  "token_type": "Bearer"
}
```

### 4. Token Storage

Tokens are encrypted and stored locally using `SecureCredentialsStore`:

```dart
await SecureCredentialsStore.saveCredentials(
  accountId: 'kimmeyh@gmail.com',
  accessToken: tokens['access_token'],
  refreshToken: tokens['refresh_token'],
  platformId: 'gmail',
  // ... other fields
);
```

---

## Troubleshooting

### Error: "client_secret is missing"

**Cause:** The `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET` environment variable is empty or missing from the build.

**Solution:**

1. **Verify secrets file exists:**
   ```bash
   cat mobile-app/secrets.dev.json
   ```
   Should contain: `"WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET": "GOCSPX-..."`

2. **Verify environment variable name matches exactly:**
   - Secrets file: `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET`
   - Dart code: `String.fromEnvironment('WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET', ...)`
   - Must match exactly (case-sensitive)

3. **Rebuild the app:**
   ```powershell
   .\scripts\build-windows.ps1
   ```
   This re-injects secrets from `secrets.dev.json`

4. **Check logs for secret status:**
   Look for: `Client Secret: (set, 35 chars)` (or `not set`)

### Error: "invalid_client"

**Cause:** Client ID doesn't match the OAuth credentials registered in Google Cloud.

**Solution:**

1. Verify you're using the correct Windows Desktop client ID
2. Check Google Cloud Console: https://console.cloud.google.com/apis/credentials
3. Find client: `577022808534-****************************kcb.apps.googleusercontent.com`
4. Confirm it's enabled and has a client secret

### Error: "redirect_uri_mismatch"

**Cause:** The redirect URI doesn't match what's registered in Google Cloud.

**Note:** Desktop clients don't have redirect URI configuration in Google Cloud. The app uses the loopback address `http://localhost:8080/oauth/callback` which is automatically allowed for desktop clients.

**Solution:**

1. Don't add redirect URIs to the desktop client in Google Cloud
2. Ensure app is using: `http://localhost:8080/oauth/callback`
3. Verify `secrets.dev.json` has correct URI

### Port 8080 Already in Use

**Cause:** Another process is using port 8080 during OAuth callback.

**Solution:**

1. Kill process using port 8080:
   ```powershell
   Get-Process | Where-Object {$_.Name -like "*node*"} | Stop-Process
   # Or identify and close specific applications
   ```

2. Or modify the redirect URI to use a different port (requires Google Cloud configuration change)

---

## Build and Run

### Development Build (Debug)

```powershell
cd mobile-app
.\scripts\build-windows.ps1
```

This:
1. Runs `flutter clean`
2. Injects secrets from `secrets.dev.json`
3. Builds Windows app (Debug)
4. Runs the app in debug mode
5. Outputs logs to console

### Production Build (Release)

```powershell
cd mobile-app
flutter build windows --release --dart-define-from-file=secrets.dev.json
```

---

## Testing

### Manual Testing Checklist

1. ✅ Build succeeds with no errors
2. ✅ Logs show: `Client Secret: (set, 35 chars)`
3. ✅ Logs show: `Using WINDOWS_GMAIL_DESKTOP_CLIENT_ID for Windows Gmail OAuth`
4. ✅ User can click "Sign in with Google"
5. ✅ Browser opens with Google login
6. ✅ User logs in and grants permissions
7. ✅ App receives authorization code
8. ✅ Logs show: `Including client_secret in token exchange`
9. ✅ Logs show: `OAuth flow completed successfully`
10. ✅ Tokens are saved to secure storage
11. ✅ User can access Gmail folders and scan emails

### Key Log Messages (Success)

```
! OAuth Configuration:
!   Client ID: 577022808534-****************************kcb.apps.googleusercontent.com
!   Client Secret: (set, 35 chars)
!   Redirect URI: http://localhost:8080/oauth/callback
💡   Using WINDOWS_GMAIL_DESKTOP_CLIENT_ID for Windows Gmail OAuth.

💡 Including client_secret in token exchange
💡 OAuth flow completed successfully
[Auth] Desktop sign-in success: kimmeyh@gmail.com
[Auth] Gmail OAuth successful for kimmeyh@gmail.com
```

---

## Security Considerations

### Client Secret Protection

1. **Never commit to version control:**
   - `secrets.dev.json` is in `.gitignore`
   - Only commit `secrets.dev.example.json`

2. **Compile-time injection:**
   - Secrets are injected into the app binary at build time
   - Not stored in app resources or configuration files
   - Only loaded into memory when needed

3. **Runtime logs:**
   - Logs truncate sensitive values: `GOCSPX-NZK3F_...`
   - Full secret is never logged

4. **Secure token storage:**
   - Access tokens and refresh tokens stored using Windows Credential Manager
   - Encrypted on disk

### PKCE Flow Benefits

1. **Authorization code interception prevention:**
   - Even if authorization code is intercepted, attacker can't exchange it without code_verifier
   - Only the app knows the original random code_verifier

2. **Replay attack prevention:**
   - Each flow generates unique code_challenge and code_verifier

3. **Required for desktop and mobile apps:**
   - Recommended even when client_secret is present
   - Provides additional security layer

---

## Comparison: Windows vs Android Gmail Auth

| Aspect | Windows | Android |
|--------|---------|---------|
| OAuth Client Type | Desktop Application | Web Application |
| Client ID | `577022808534-63vfth6d...` | `577022808534-0ejdbmo...` |
| Has Client Secret | ✅ Yes (Required) | ✅ Yes (Required) |
| Flow | Authorization Code + PKCE | flutter_appauth native |
| Redirect URI | Loopback (localhost:8080) | Custom scheme |
| Token Storage | Secure (Windows Credential Manager) | Secure (Android Keystore) |
| Platform Detection | Automatic in handler | Automatic in handler |

**Important:** Never mix client IDs between platforms. Each platform uses its own registered OAuth client.

---

## References

- [Google OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [PKCE (RFC 7636)](https://tools.ietf.org/html/rfc7636)
- [Google Desktop App OAuth](https://developers.google.com/identity/protocols/oauth2/native-app)
- [Gmail API Scopes](https://developers.google.com/gmail/api/auth/scopes)

---

## Support and Debugging

For detailed logs during development:

```powershell
# Build and run with verbose logging
flutter run -v --dart-define-from-file=secrets.dev.json
```

Look for messages containing:
- `OAuth Configuration:`
- `Including client_secret in token exchange`
- `OAuth flow completed successfully`
- `Desktop sign-in success`

If encountering issues:
1. Check logs for the exact error message
2. Verify `secrets.dev.json` contains all required fields
3. Verify Google Cloud Console has desktop client enabled with secret
4. Rebuild with `flutter clean` first
5. Check port 8080 availability
