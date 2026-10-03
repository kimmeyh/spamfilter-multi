# ADR-0011: Desktop OAuth via Loopback Redirect with PKCE

## Status

Accepted

## Date

~2025-10 (project inception, PKCE added ~2026-01)

## Context

The spam filter needs Gmail OAuth authentication on both desktop (Windows, macOS, Linux) and mobile (Android, iOS) platforms. Each platform category has fundamentally different capabilities for handling OAuth redirect flows:

- **Mobile**: Native SDKs (Google Sign-In for Android, ASWebAuthenticationSession for iOS) handle the entire OAuth flow, including secure browser presentation, redirect capture, and token management
- **Desktop**: No native Google Sign-In SDK exists for Windows/macOS/Linux. The application must implement the OAuth flow manually, including launching a browser, capturing the authorization code callback, and exchanging it for tokens

OAuth security requirements add complexity:
- **PKCE (Proof Key for Code Exchange)**: Required by Google for public clients to prevent authorization code interception attacks
- **Client secret handling**: Desktop apps are "public clients" (the secret cannot truly be kept secret), but Google still requires it for certain client types
- **Token storage**: Desktop must explicitly manage refresh tokens (mobile SDKs handle this internally)

The application must support both platform categories with a unified interface while implementing platform-appropriate OAuth flows.

## Decision

Implement platform-branching OAuth with two distinct flows, unified behind `GmailWindowsOAuthHandler`:

### Desktop Flow (Windows, macOS, Linux)

1. **Generate PKCE challenge**: Create a 64-byte random code verifier and compute its SHA-256 S256 challenge
2. **Build authorization URL**: Include client ID, scopes (`gmail.modify`, `userinfo.email`), PKCE challenge, `access_type: offline` (for refresh token), and `prompt: consent`
3. **Launch system browser**: Open the authorization URL in the user's default browser via `url_launcher`
4. **Start local HTTP server**: Bind `HttpServer` to `localhost:8080` with a 5-minute timeout
5. **Capture callback**: Listen for the redirect to `http://localhost:8080/oauth/callback`, extract the authorization code from query parameters, and respond with an HTML success/error page
6. **Exchange code for tokens**: POST to Google's token endpoint with the authorization code, PKCE code verifier, client ID, and client secret (if available)
7. **Store tokens**: Save access token, refresh token, and expiry to `SecureCredentialsStore`
8. **Shutdown server**: Close the local HTTP server after capturing the code

### Mobile Flow (Android, iOS)

1. **Use `flutter_appauth`**: Delegate the entire flow to the native SDK
2. **Custom redirect scheme**: `com.googleusercontent.apps.<client_id>:/oauthredirect`
3. **Token management**: Native SDK manages refresh tokens internally; app stores access token only

### Build-Time Credential Injection

OAuth client credentials are injected at build time via `--dart-define-from-file=secrets.dev.json`, using `String.fromEnvironment()`:
- `WINDOWS_GMAIL_DESKTOP_CLIENT_ID` - Desktop OAuth client ID
- `WINDOWS_GMAIL_DESKTOP_CLIENT_SECRET` - Desktop OAuth client secret
- `GMAIL_REDIRECT_URI` - Configurable redirect URI (defaults to `http://localhost:8080/oauth/callback`)

## Alternatives Considered

### Embedded WebView for OAuth
- **Description**: Use a Flutter WebView widget to display the Google sign-in page within the application, intercepting the redirect URL to capture the authorization code
- **Pros**: No external browser needed; contained within the app; user stays in the application
- **Cons**: Google explicitly discourages and may block OAuth in embedded WebViews (security risk: app can access user credentials); WebView on desktop platforms is less mature; users cannot verify they are on the real Google domain; violates Google's OAuth security guidelines
- **Why Rejected**: Google's OAuth policies prohibit authentication in embedded WebViews for security reasons. Using the system browser ensures the user can verify the domain and leverage existing browser sessions/passwords

### System Browser Without Loopback Server
- **Description**: Open the system browser for OAuth but use a custom protocol handler (e.g., `spamfilter://callback`) instead of a local HTTP server to capture the redirect
- **Pros**: No port binding; no firewall concerns; simpler server-side logic
- **Cons**: Custom protocol handlers require OS-level registration (different per platform); registration may require elevated permissions on Windows; unreliable on Linux; Google may not accept custom schemes for desktop OAuth clients; harder to debug
- **Why Rejected**: Loopback redirect (`http://localhost`) is Google's recommended approach for desktop OAuth. It avoids the complexity and unreliability of custom protocol handlers across three desktop platforms. Google explicitly supports loopback redirects in their OAuth documentation

### Hardcoded Long-Lived Tokens
- **Description**: Generate a long-lived OAuth token through the Google Cloud Console and embed it in the application
- **Pros**: No OAuth flow needed; immediate access; simplest implementation
- **Cons**: Token expires (Google tokens have limited lifetime even for "offline" access); cannot support multiple users; token embedded in binary can be extracted; no refresh mechanism; violates OAuth security model
- **Why Rejected**: Hardcoded tokens are a fundamental security anti-pattern. They cannot support multiple users, expire without refresh capability, and expose credentials in the application binary

### Single OAuth Library for All Platforms
- **Description**: Use a single cross-platform OAuth library (e.g., `flutter_appauth`) for both mobile and desktop
- **Pros**: Unified code path; less platform-specific code; single dependency
- **Cons**: `flutter_appauth` desktop support was limited/experimental at decision time; desktop-specific requirements (loopback server, PKCE code verifier management) are not well-handled by mobile-focused libraries; different redirect URI requirements per platform
- **Why Rejected**: At the time of implementation, no single Flutter OAuth library provided production-quality support for both mobile native SDKs and desktop loopback redirects. The platform-branching approach uses the best tool for each platform category

## Consequences

### Positive
- **Google-compliant**: Follows Google's recommended OAuth flow for desktop applications (loopback redirect), avoiding policy violations that could result in app rejection or token revocation
- **PKCE security**: S256 code challenge prevents authorization code interception, even on shared machines where another process might monitor localhost traffic
- **No external dependencies for desktop**: The local HTTP server uses Dart's built-in `dart:io` HttpServer, requiring no additional native dependencies
- **Multi-account support**: Each OAuth flow produces account-specific tokens stored under the `{platform}-{email}` key scheme
- **Refresh token support**: Desktop flow explicitly requests `access_type: offline` and stores refresh tokens for session persistence across app restarts

### Negative
- **Port conflict risk**: If another application is using port 8080, the local server will fail to bind. There is no automatic port fallback (the redirect URI must match the registered OAuth client configuration)
- **Firewall interaction**: Some firewalls or security software may block the localhost HTTP server, preventing the OAuth callback from reaching the application
- **Platform-specific code paths**: Two distinct OAuth implementations must be maintained and tested independently, with different token storage and refresh strategies
- **5-minute timeout**: If the user takes longer than 5 minutes to complete the browser-based sign-in, the local server times out and the flow must be restarted
- **Browser dependency**: Desktop OAuth requires a working system browser; headless or minimal desktop environments may not have one

### Neutral
- **Client secret in desktop app**: Google requires a client secret for desktop OAuth clients, but desktop apps are "public clients" where the secret cannot truly be protected. The secret is injected at build time and present in the binary, which is accepted practice for desktop OAuth (the PKCE flow provides the actual security, not the client secret)
- **Redirect URI configuration**: The redirect URI defaults to `http://localhost:8080/oauth/callback` but can be overridden via build-time environment variable, providing flexibility for development and testing environments

## Amendment -- Sprint 75 (F239, Issue #442): renewal that needs the user

Six rules, identical on Windows and Android (ADR-0042):

1. **A token is always looked up for a named account.** `getValidAccessToken({accountId})` uses the
   account asked for, or the service's current account, and otherwise returns null. It used to fall
   back to `getSavedAccounts().first` -- a guess. Folder Selection creates a fresh service, so with
   an AOL account saved first it looked up AOL's Gmail tokens.
2. **A background scan never starts an interactive sign-in.** In the Windows worker the renewal
   fallback opened the system browser with nobody watching. `BackgroundModeService.isBackgroundMode`
   is now also set in the Android WorkManager isolate (`markBackgroundIsolate`), and the adapter
   checks it before any interactive path.
3. **When renewal needs the user, say so and keep everything.** The adapter throws
   `GmailSignInRequiredException` ("Gmail needs you to sign in again"), sets the per-account
   setting `gmail_sign_in_required`, and keeps the tokens (Sprint 74 rule). The account list then
   shows that text with a **Sign In Again** button, which re-runs sign-in for that account. A
   background scan maps the exception to a SKIP (`AccountScanOutcome.needsSignIn`): not counted as a
   failure, no notification, and no 2-6 minute busy retry, because only the user can fix it.
4. **Sign In Again accepts only the same account.** `signIn({expectedAccountId})` compares the
   returned address (case-insensitive) BEFORE saving tokens; a different Google account is refused
   with "You signed in as X. To fix Y, sign in with Y." Saving first would add the other account to
   the saved list. **Invariant this relies on**: a Gmail account id IS its email address -- both
   sign-in paths derive it from the signed-in email (`_signInNative`, `_signInDesktop`) -- so the
   flag, the token lookup and the expected-account check all use one key. A future
   `{platform}-{email}` Gmail id would break the check and must normalize first.
5. **Every path that needs the user does all of rule 3** -- including the Windows
   insufficient-scopes re-authorization in `fetchMessages`, which keeps the account id from
   `loadCredentials` because it has no credentials in hand.
6. **No network is not an expired sign-in.** Renewal swallows network errors into "Session
   expired", so the first Gmail call (`getProfile`) checks `GmailApiAdapter.isNetworkError` and
   fails as a `ConnectionException` without entering renewal. Otherwise an offline background scan
   flagged a healthy account.

**Known limits, not proven by tests:**
- The scan row is created by the claim before credentials load, so a sign-in skip still leaves a
  row with status `error` and the reason as its message. No `skipped` row status exists; adding one
  changes what a stored value means (Class 1) and was not done.
- On Android with no refresh token, a network failure during native renewal is indistinguishable
  from "needs the user", so the account can be flagged during an outage. The flag clears on the
  next successful connect, and Sign In Again also clears it.
- Renewing Android tokens WITHOUT an Activity (the R-1 capability spike) is not part of this
  amendment; if it passes it is recorded as a declared ADR-0042 platform exception.

## References

- `mobile-app/lib/adapters/email_providers/gmail_windows_oauth_handler.dart` - Desktop+mobile OAuth implementation (lines 1-377): loopback server (lines 193-237), PKCE (lines 364-375), platform branching (lines 81-90)
- `mobile-app/lib/adapters/auth/google_auth_service.dart` - Auth service with token refresh (lines 331-365), platform detection (lines 160-164)
- `mobile-app/secrets.dev.json.template` - Build-time credential template
- ADR-0008 (Platform-Native Secure Credential Storage) - Where OAuth tokens are stored after authentication
- `docs/OAUTH_SETUP.md` - Setup instructions for Gmail OAuth on Android and Windows
