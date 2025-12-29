# Gmail OAuth 2.0 Configuration Guide

## Overview

This app uses OAuth 2.0 for Gmail authentication following Google's best practices for native/public clients:

- **No client secret embedded** - Native apps are "public clients" and cannot securely store secrets
- **PKCE for desktop** - Proof Key for Code Exchange adds security to the authorization code flow
- **Native SDKs for mobile** - Android/iOS use Google Sign-In SDK for secure, native OAuth

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GoogleAuthService                        │
│  - Unified sign-in/sign-out/refresh across all platforms       │
│  - Manages AuthState (unauthenticated → authenticated)         │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
      ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
      │ Android/iOS   │ │ Windows/macOS │ │     Web       │
      │ google_sign_in│ │ Browser+PKCE  │ │ google_sign_in│
      └───────────────┘ └───────────────┘ └───────────────┘
                              │
                              ▼
      ┌───────────────────────────────────────────────────────────┐
      │                     SecureTokenStore                      │
      │  - Encrypted storage via flutter_secure_storage           │
      │  - Platform-native backends (Keychain, Keystore, etc.)   │
      └───────────────────────────────────────────────────────────┘
                              │
                              ▼
      ┌───────────────────────────────────────────────────────────┐
      │                       GmailClient                         │
      │  - Authenticated Gmail API wrapper                        │
      │  - Auto-refresh on 401                                    │
      └───────────────────────────────────────────────────────────┘
```

## Build-Time Configuration

### Flutter (--dart-define)

Pass the client ID at build time - **NEVER hardcode in source**:

```bash
# Development
flutter run --dart-define=GMAIL_DESKTOP_CLIENT_ID=YOUR_CLIENT_ID.apps.googleusercontent.com

# Release build
flutter build apk --dart-define=GMAIL_DESKTOP_CLIENT_ID=YOUR_CLIENT_ID.apps.googleusercontent.com

# Using secrets file (recommended)
flutter run --dart-define-from-file=secrets.dev.json
```

For CI/CD, use GitHub Secrets:

```yaml
# .github/workflows/build.yml
- run: flutter build apk --dart-define=GMAIL_DESKTOP_CLIENT_ID=${{ secrets.GMAIL_DESKTOP_CLIENT_ID }}
```

### Using secrets.dev.json (Recommended)

Create `mobile-app/secrets.dev.json` (gitignored):

```json
{
  "GMAIL_DESKTOP_CLIENT_ID": "YOUR_CLIENT_ID.apps.googleusercontent.com",
  "GMAIL_OAUTH_CLIENT_SECRET": ""
}
```

Then build with:
```bash
flutter run --dart-define-from-file=secrets.dev.json
```

### Android (Gradle)

1. Create `mobile-app/android/local.properties` (gitignored):
   ```properties
   # OAuth Configuration (DO NOT COMMIT)
   google.clientId=YOUR_CLIENT_ID.apps.googleusercontent.com
   google.webClientId=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
   ```

2. For Google Sign-In on Android, configure `google-services.json` from Firebase Console.

### iOS (xcconfig)

1. Create `mobile-app/ios/Flutter/Secrets.xcconfig` (gitignored):
   ```
   // OAuth Configuration (DO NOT COMMIT)
   GOOGLE_CLIENT_ID=YOUR_CLIENT_ID.apps.googleusercontent.com
   GOOGLE_REVERSED_CLIENT_ID=com.googleusercontent.apps.YOUR_CLIENT_ID
   ```

2. In `Info.plist`, add URL scheme for OAuth callback:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>$(GOOGLE_REVERSED_CLIENT_ID)</string>
           </array>
       </dict>
   </array>
   <key>GIDClientID</key>
   <string>$(GOOGLE_CLIENT_ID)</string>
   ```

### Web

Configure in `index.html`:
```html
<meta name="google-signin-client_id" content="YOUR_CLIENT_ID.apps.googleusercontent.com">
```

## Token Storage

Tokens are stored securely using platform-native encryption:

| Platform | Storage Backend | Encryption |
|----------|-----------------|------------|
| Android | EncryptedSharedPreferences | Android Keystore |
| iOS | Keychain Services | Hardware-backed |
| Windows | Windows Credential Manager | DPAPI |
| macOS | Keychain Services | Hardware-backed |
| Linux | libsecret | System keyring |

### What's Stored

```json
{
  "accessToken": "ya29...",
  "refreshToken": "1//...",
  "expiresAt": "2025-12-25T12:00:00.000Z",
  "grantedScopes": ["gmail.modify", "userinfo.email"],
  "email": "user@gmail.com"
}
```

## Token Lifecycle

```
┌──────────────────────────────────────────────────────────────────┐
│                        App Startup                                │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Load stored     │
                    │ tokens          │
                    └─────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
        ┌──────────┐   ┌──────────┐   ┌──────────┐
        │ No tokens│   │ Valid    │   │ Expired  │
        │          │   │ tokens   │   │ tokens   │
        └──────────┘   └──────────┘   └──────────┘
              │               │               │
              ▼               ▼               ▼
        ┌──────────┐   ┌──────────┐   ┌──────────┐
        │ Show     │   │ Use      │   │ Refresh  │
        │ Sign-In  │   │ directly │   │ token    │
        └──────────┘   └──────────┘   └──────────┘
                                              │
                              ┌───────────────┼───────────────┐
                              │                               │
                              ▼                               ▼
                        ┌──────────┐                   ┌──────────┐
                        │ Success  │                   │ Failed   │
                        │ (update) │                   │ (delete) │
                        └──────────┘                   └──────────┘
```

## Security Checklist

- [x] Client ID not hardcoded in source (uses `--dart-define`)
- [x] No client secret embedded in app (PKCE used for desktop)
- [x] Tokens never logged in plain text (use `Redact.token()`)
- [x] Tokens stored via flutter_secure_storage only
- [x] Example configs use placeholders only
- [x] Real values come from CI secrets / local untracked files
- [x] Token expiry handled with 5-minute buffer
- [x] 401 responses trigger automatic refresh
- [x] Failed refresh clears stored tokens

## Usage Examples

### Basic Sign-In

```dart
final authService = GoogleAuthService();

// Try silent sign-in on startup
final result = await authService.initialize();
if (result.success) {
  print('Already signed in as: ${result.email}');
} else {
  // Show sign-in UI
  final signInResult = await authService.signIn();
  if (signInResult.success) {
    print('Signed in as: ${signInResult.email}');
  }
}
```

### Using Gmail Client

```dart
final authService = GoogleAuthService();
final gmailClient = GmailClient(authService: authService);

// List inbox messages
final messages = await gmailClient.listMessages(
  query: 'in:inbox',
  maxResults: 20,
);

// Get full message
final message = await gmailClient.getMessage(messages.first.id);
print('Subject: ${message.subject}');
print('From: ${message.from}');

// Move to trash
await gmailClient.trashMessage(message.id);
```

### Disconnect Gmail

```dart
// For "Disconnect Gmail" settings button
await authService.disconnect();
// All tokens revoked and storage cleared
```

## Troubleshooting

### "401 Unauthorized" Errors

1. Check if client ID is correctly injected via `--dart-define`
2. Verify OAuth consent screen is configured in Google Cloud Console
3. Ensure correct scopes are requested

### "Token refresh failed"

1. User may have revoked access - prompt re-authentication
2. Check internet connectivity
3. Verify refresh token is stored (check `SecureTokenStore`)

### Desktop OAuth Not Working

1. Ensure port 8080 is available for loopback callback
2. Check browser can open for OAuth consent
3. Verify PKCE is being used (no client secret for desktop)

## Google Cloud Console Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create or select a project
3. Enable Gmail API
4. Configure OAuth consent screen
5. Create OAuth 2.0 credentials:
   - **Web application** - for web builds
   - **Android** - for Android builds (use SHA-1 fingerprint)
   - **iOS** - for iOS builds (use bundle ID)
   - **Desktop** - for Windows/macOS/Linux (use redirect URI `http://localhost:8080/oauth/callback`)

## Files Reference

| File | Purpose |
|------|---------|
| `lib/adapters/auth/token_store.dart` | Token storage interface |
| `lib/adapters/auth/secure_token_store.dart` | Encrypted storage implementation |
| `lib/adapters/auth/google_auth_service.dart` | Unified auth service |
| `lib/adapters/gmail/gmail_client.dart` | Gmail API wrapper |
| `lib/util/redact.dart` | Token redaction utilities |
| `lib/adapters/email_providers/gmail_windows_oauth_handler.dart` | Desktop OAuth handler |
