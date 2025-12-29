# Windows Gmail OAuth - Quick Reference Card

## At a Glance

| Component | Value |
|-----------|-------|
| **Client Type** | Desktop Application |
| **Client ID** | `577022808534-****************************kcb.apps.googleusercontent.com` |
| **Client Secret** | `GOCSPX-**********************LSH6` |
| **Redirect URI** | `http://localhost:8080/oauth/callback` |
| **Flow** | Authorization Code + PKCE |
| **Scopes** | `gmail.modify`, `userinfo.email` |

---

## 3-Step Setup

### Step 1: Prepare Secrets File
**File:** `mobile-app/secrets.dev.json`

```json
{
  "WINDOWS_GMAIL_DESKTOP_CLIENT_ID": "577022808534-****************************kcb.apps.googleusercontent.com",
  "WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET": "GOCSPX-**********************LSH6",
  "GMAIL_REDIRECT_URI": "http://localhost:8080/oauth/callback"
}
```

**⚠️ Important:**
- Never commit to version control
- Must be in `.gitignore`

### Step 2: Build with Secrets
```powershell
cd mobile-app
.\scripts\build-windows.ps1
```

**This automatically:**
- Injects secrets from `secrets.dev.json`
- Builds the Windows app
- Runs the app in debug mode

### Step 3: Test OAuth Flow

1. Click "Sign in with Google"
2. Browser opens with Google login
3. User logs in and grants permissions
4. App receives tokens and saves them
5. User can access Gmail folders

---

## Success Indicators

### In Logs (Look for these)

✅ **Client secret loaded:**
```
!   Client Secret: (set, 35 chars)
```

✅ **Secret included in token exchange:**
```
💡 Including client_secret in token exchange
```

✅ **OAuth completed successfully:**
```
💡 OAuth flow completed successfully
[Auth] Desktop sign-in success: user@gmail.com
```

### In UI
- No error dialog appears
- App transitions to folder selection
- Gmail folders (Inbox, Spam, Trash) are listed

---

## Common Issues & Quick Fixes

### ❌ Error: "client_secret is missing"

**What went wrong:** Secret not injected at build time

**Fix:**
1. Verify `secrets.dev.json` exists and contains the secret
2. Run: `cd mobile-app && flutter clean`
3. Run: `.\scripts\build-windows.ps1`

### ❌ Error: "invalid_client"

**What went wrong:** Wrong client ID or client not enabled in Google Cloud

**Fix:**
1. Verify you're using the **Windows** client ID (not Android)
2. Check Google Cloud Console that the Desktop client is enabled
3. Confirm the secret is current (not expired)

### ❌ Port 8080 Already in Use

**What went wrong:** Another app is using port 8080

**Fix:**
```powershell
netstat -ano | findstr :8080
taskkill /PID <PID> /F
```

---

## OAuth Flow (Simplified)

```
1. User clicks "Sign in with Google"
   ↓
2. App generates PKCE code_challenge
   ↓
3. Browser opens Google login
   ↓
4. User logs in & grants permissions
   ↓
5. Google redirects to: http://localhost:8080/oauth/callback?code=...
   ↓
6. App's local server receives code
   ↓
7. App exchanges code for tokens (includes CLIENT_SECRET)
   ↓
8. Tokens stored securely (Windows Credential Manager)
   ↓
9. User can access Gmail folders & scan emails
```

---

## Code Implementation (Reference)

### Where the Secret is Read
**File:** `mobile-app/lib/adapters/email_providers/gmail_windows_oauth_handler.dart`

```dart
static const String _clientSecret = String.fromEnvironment(
  'WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET',  // Must match JSON key exactly!
  defaultValue: '',
);
```

### Where the Secret is Used
During token exchange to Google OAuth endpoint:

```dart
final requestBody = {
  'client_id': _clientId,
  'client_secret': _clientSecret,  // ← REQUIRED for token exchange
  'code': authCode,
  'code_verifier': _codeVerifier,  // PKCE
  'redirect_uri': _redirectUri,
  'grant_type': 'authorization_code',
};
```

---

## Environment Variables Injected

From `secrets.dev.json` to Dart code:

| JSON Key | Dart Code | Usage |
|----------|-----------|-------|
| `WINDOWS_GMAIL_DESKTOP_CLIENT_ID` | `String.fromEnvironment('WINDOWS_GMAIL_DESKTOP_CLIENT_ID')` | OAuth client ID |
| `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET` | `String.fromEnvironment('WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET')` | Token exchange |
| `GMAIL_REDIRECT_URI` | `String.fromEnvironment('GMAIL_REDIRECT_URI')` | OAuth callback |

**⚠️ Critical:** Names must match exactly (case-sensitive)

---

## Debug Commands

### Check Logs for Secret Status
```powershell
# Build and run with verbose output
flutter run -v --dart-define-from-file=secrets.dev.json
```

Look for:
- `Client Secret: (set, 35 chars)` → ✅ Injected correctly
- `Client Secret: (not set)` → ❌ Not found in environment

### Verify Secrets File
```powershell
cat mobile-app\secrets.dev.json | findstr "CLIENT_SECRET"
```

Should output:
```
"WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET": "GOCSPX-**********************LSH6"
```

---

## Compare: Windows vs Android

| Aspect | Windows | Android |
|--------|---------|---------|
| **Client Type** | Desktop | Web |
| **Client ID** | `...63vfth6d...` | `...0ejdbmo...` |
| **Secret Needed** | ✅ Yes | ✅ Yes |
| **Build Command** | `build-windows.ps1` | `build-with-secrets.ps1` |
| **Redirect URI** | localhost:8080 | Custom scheme |
| **Flow** | Manual browser + PKCE | flutter_appauth |

**Important:** Never mix client IDs between platforms!

---

## Full Documentation

For comprehensive details, see: [WINDOWS_GMAIL_OAUTH_SETUP.md](../mobile-app/WINDOWS_GMAIL_OAUTH_SETUP.md)

---

## TL;DR (Complete Checklist)

- [ ] `secrets.dev.json` exists with all 3 keys
- [ ] Ran `.\scripts\build-windows.ps1`
- [ ] Logs show `Client Secret: (set, 35 chars)`
- [ ] Can click "Sign in with Google" without error
- [ ] Browser opens Google login
- [ ] Logs show `OAuth flow completed successfully`
- [ ] User@gmail.com saved in app
- [ ] Can access Gmail folders
- [ ] Can scan for spam

✅ **Done!** Windows Gmail OAuth is working.
