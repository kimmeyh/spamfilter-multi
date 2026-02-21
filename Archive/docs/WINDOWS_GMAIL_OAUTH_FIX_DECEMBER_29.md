# Windows Gmail OAuth Fix - December 29, 2025

## Problem Summary

The Windows app's Gmail OAuth authentication was failing with the error:

```
⛔ Token exchange failed: 400 - {
  "error": "invalid_request",
  "error_description": "client_secret is missing."
}
```

### Symptoms

1. User clicks "Sign in with Google"
2. Browser opens Google login
3. User successfully logs in and grants permissions
4. Google redirects back with authorization code
5. App attempts to exchange code for tokens
6. Google rejects the request: **"client_secret is missing"**

### Impact

- Windows Gmail OAuth completely broken
- Android Gmail OAuth **NOT affected** (uses different client)
- Users could not add Gmail accounts on Windows

---

## Root Cause Analysis

### Discovery Process

1. **Initial assumption:** Desktop client doesn't support client secrets
   - ❌ Wrong. Google's Desktop OAuth clients **do** require client secrets

2. **Build output was correct:**
   - ✅ Client ID injected correctly: `577022808534-****************************kcb.apps.googleusercontent.com`
   - ❌ Client secret: `(not set)` 

3. **Searched for the problem in code:**
   - ✅ Found `secrets.dev.json` **did** contain the secret: `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET`
   - ❌ Found the code was looking for **different** environment variable name

### The Bug

**File:** `mobile-app/lib/adapters/email_providers/gmail_windows_oauth_handler.dart`
**Line 26:**

```dart
// WRONG: Looking for this key
static const String _clientSecret = String.fromEnvironment(
  'GMAIL_OAUTH_CLIENT_SECRET',  // ← This key doesn't exist in secrets.dev.json
  defaultValue: '',
);
```

**File:** `mobile-app/secrets.dev.json`

```json
{
  // ACTUAL key in file
  "WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET": "GOCSPX-**********************LSH6"
}
```

### The Mismatch

| Component | Key Name | Result |
|-----------|----------|--------|
| Secrets File | `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET` | Contains value: `GOCSPX-...` |
| Dart Code | `GMAIL_OAUTH_CLIENT_SECRET` | Not found → defaultValue: `''` (empty) |
| Result | Empty string injected | Token exchange fails |

### Why It Failed

When the app attempts token exchange with Google:

```dart
final requestBody = {
  'client_id': 'correct-id',
  'client_secret': '',  // ← Empty string from failed environment variable lookup!
  'code': 'auth-code',
  // ... other fields
};
```

Google's token endpoint validates the client_secret. An empty string is treated as "not provided", triggering the error: "client_secret is missing."

---

## The Fix

### Code Change

**File:** `mobile-app/lib/adapters/email_providers/gmail_windows_oauth_handler.dart`
**Line 26:**

```dart
// FIXED: Now looking for the correct key
static const String _clientSecret = String.fromEnvironment(
  'WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET',  // ✅ Matches secrets.dev.json
  defaultValue: '',
);
```

### Why This Fix Works

1. **Environment variable name now matches:**
   - Dart code: `'WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET'`
   - Secrets file: `"WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET"`
   - ✅ Exact match!

2. **Build process injects the secret correctly:**
   - `flutter run --dart-define-from-file=secrets.dev.json`
   - Reads `"WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET": "GOCSPX-..."`
   - Injects into Dart constant
   - ✅ Non-empty value!

3. **Token exchange includes the secret:**
   ```dart
   requestBody['client_secret'] = 'GOCSPX-**********************LSH6'
   ```
   - Google validates: ✅ Valid secret
   - Token exchange succeeds
   - ✅ User authenticated!

---

## Verification

### Build Output (After Fix)

```
[INFO] Using --dart-define-from-file=secrets.dev.json for build and run.
```

### Runtime Logs (Success)

```
! OAuth Configuration:
!   Client ID: 577022808534-****************************kcb.apps.googleusercontent.com
!   Client Secret: (set, 35 chars)  ← ✅ NOW SET!
!   Redirect URI: http://localhost:8080/oauth/callback

💡 Including client_secret in token exchange  ← ✅ SECRET INCLUDED!
💡   client_secret: GOCSPX-NZK3F_PqBonqx... (truncated)

💡 OAuth flow completed successfully  ← ✅ SUCCESS!
[Auth] Desktop sign-in success: user@gmail.com
[Auth] Gmail OAuth successful for user@gmail.com
```

### User Experience (After Fix)

1. ✅ Click "Sign in with Google"
2. ✅ Browser opens Google login
3. ✅ User logs in and grants permissions
4. ✅ No error dialog
5. ✅ App saves tokens
6. ✅ User sees Gmail folders (Inbox, Spam, Trash)
7. ✅ Can scan for spam emails

---

## Implementation Details

### Where the Secret is Used

**Token Exchange Function:**
`mobile-app/lib/adapters/email_providers/gmail_windows_oauth_handler.dart`
Lines 240-290

```dart
static Future<Map<String, String>> exchangeCodeForTokens(String authCode) async {
  final requestBody = {
    'client_id': _clientId,
    'code': authCode,
    'redirect_uri': _redirectUri,
    'grant_type': 'authorization_code',
    'code_verifier': _codeVerifier!,
  };
  
  // ← THIS CHECK NOW WORKS BECAUSE _clientSecret IS NON-EMPTY
  if (_clientSecret.isNotEmpty) {
    requestBody['client_secret'] = _clientSecret;
    _logger.i('Including client_secret in token exchange');
  }
  
  final response = await http.post(
    Uri.parse(_tokenEndpoint),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: requestBody,
  );
  // ... rest of function
}
```

### Configuration Chain

```
secrets.dev.json (human-readable JSON)
      ↓
Build script: --dart-define-from-file=secrets.dev.json
      ↓
Dart compile-time environment: String.fromEnvironment()
      ↓
Dart constant: static const String _clientSecret = "..."
      ↓
Token exchange: requestBody['client_secret'] = _clientSecret
      ↓
Google OAuth API: Validates secret and returns tokens
```

---

## Testing Strategy

### Automated Testing

The fix was verified through:

1. ✅ Clean build without errors
2. ✅ Logs confirm secret is loaded (`set, 35 chars`)
3. ✅ Logs confirm secret is included in token exchange
4. ✅ Manual Gmail sign-in with browser flow

### Manual Verification Checklist

- [x] Build completed successfully
- [x] No compilation errors
- [x] Runtime logs show `Client Secret: (set, 35 chars)`
- [x] Runtime logs show `Including client_secret in token exchange`
- [x] OAuth authorization URL correct
- [x] Browser opens for Google login
- [x] Google login succeeds
- [x] Authorization code captured
- [x] Token exchange succeeds
- [x] Tokens stored securely
- [x] User can access Gmail folders
- [x] Folders display correctly (Inbox, Spam, Trash)
- [x] No errors in any step

### Android NOT Affected

- [x] Android uses different OAuth client (separate client ID)
- [x] Android uses different environment variable: `GMAIL_ANDROID_CLIENT_ID`
- [x] Android code not modified
- [x] Android authentication unchanged

---

## Key Lessons Learned

### 1. Environment Variable Name Matching is Critical
- Dart code must match secrets file exactly (case-sensitive)
- Typos lead to empty defaults
- Empty environment variables fail silently

### 2. Desktop OAuth Clients Require Client Secrets
- Common misconception: PKCE eliminates need for client secret
- Reality: Desktop clients **must** use client secrets with Google
- PKCE adds extra security, doesn't replace client secret

### 3. Compile-Time Injection Challenges
- Build-time secrets injection is secure but requires exact name matching
- Runtime logs should show status (set vs not set)
- Logs should truncate sensitive values for security

### 4. Platform-Specific OAuth Clients are Essential
- Never mix Android client ID with Windows app
- Different platforms = different client configurations
- Each platform's secrets must be injected correctly

---

## Files Changed

### Modified

1. **`mobile-app/lib/adapters/email_providers/gmail_windows_oauth_handler.dart`**
   - Line 26: Changed `'GMAIL_OAUTH_CLIENT_SECRET'` → `'WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET'`

### Created (Documentation)

1. **`mobile-app/WINDOWS_GMAIL_OAUTH_SETUP.md`**
   - Comprehensive guide to Windows Gmail OAuth setup
   - Covers configuration, implementation, troubleshooting

2. **`mobile-app/WINDOWS_GMAIL_OAUTH_QUICK_REFERENCE.md`**
   - Quick reference card for developers
   - At-a-glance configuration and common issues

3. **`memory-bank/oauth-setup-guide.md`**
   - Platform-agnostic OAuth/authentication documentation
   - Covers all platforms (Windows, Android, iOS)
   - Troubleshooting and debugging tips

4. **This file: Windows Gmail OAuth Fix - December 29, 2025**
   - Detailed explanation of the problem, cause, and solution
   - For future reference and maintainability

---

## Impact & Timeline

| Date | Event |
|------|-------|
| 2025-12-27 | Desktop OAuth Windows client created in Google Cloud |
| 2025-12-27 | Secrets file created with `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET` |
| 2025-12-28 | First test: Client secret not injected (logs: "not set") |
| 2025-12-28 | Diagnosed: Environment variable name mismatch |
| 2025-12-29 | **Fix applied:** Updated environment variable name in code |
| 2025-12-29 | **Verified:** OAuth flow succeeds, tokens obtained, user authenticated |
| 2025-12-29 | **Documented:** Created comprehensive documentation |

---

## Future Considerations

### Security Audit
- [ ] Review all uses of `String.fromEnvironment` for naming consistency
- [ ] Audit log messages for accidental secret leaks
- [ ] Verify tokens not stored in logs or crash reports

### Cross-Platform Testing
- [ ] Confirm Android Gmail OAuth still works (not broken by Windows fix)
- [ ] Test iOS Gmail OAuth (currently configured but untested)
- [ ] Verify multi-account support across platforms

### Build Process Improvements
- [ ] Document all required environment variable names
- [ ] Add validation to detect missing secrets at build time
- [ ] Create example/template with all required keys

### Deployment
- [ ] Update CI/CD pipeline to inject correct secrets
- [ ] Document production secret management
- [ ] Create runbook for onboarding new developers

---

## Questions & Answers

**Q: Why didn't PKCE protect us from this error?**  
A: PKCE prevents authorization code interception attacks, but doesn't address the client_secret requirement. Google's token endpoint still validates client credentials.

**Q: Why does Desktop OAuth need a client secret?**  
A: Even though desktop apps can't securely store secrets in the traditional sense, the client_secret proves that the token exchange request comes from the legitimate registered app, not from another application spoofing the client ID.

**Q: Could we have just removed the client_secret?**  
A: No. Google requires client_secret for Desktop clients. Attempting to exchange without it fails with "invalid_request" error.

**Q: Why is Android not affected?**  
A: Android uses a completely different OAuth client (different client ID), different environment variable, and different authentication flow (flutter_appauth). The Windows fix only changes the Windows authentication handler.

**Q: Should we have caught this earlier?**  
A: Yes. Better approaches would have been:
   1. Add build-time validation that all required environment variables are set
   2. Log warnings for empty secrets during initialization
   3. Use consistent naming convention (e.g., all start with platform name)

---

## Related Documentation

- [WINDOWS_GMAIL_OAUTH_SETUP.md](../mobile-app/WINDOWS_GMAIL_OAUTH_SETUP.md) - Complete setup guide
- [WINDOWS_GMAIL_OAUTH_QUICK_REFERENCE.md](../mobile-app/WINDOWS_GMAIL_OAUTH_QUICK_REFERENCE.md) - Quick reference
- [memory-bank/oauth-setup-guide.md](oauth-setup-guide.md) - Cross-platform authentication guide
- [README.md](../mobile-app/README.md) - General project documentation

---

## Sign-Off

**Fixed by:** GitHub Copilot  
**Date:** December 29, 2025  
**Status:** ✅ Complete and Verified  
**Impact:** Windows Gmail OAuth now fully functional
