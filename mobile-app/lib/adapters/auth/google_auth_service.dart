/// Unified Google OAuth 2.0 authentication service.
///
/// ## Architecture
/// - Uses [google_sign_in] for consent + token acquisition on Android/iOS
/// - Uses browser-based OAuth with PKCE for Windows/macOS/Linux
/// - Stores tokens via [SecureCredentialsStore] (encrypted at rest, unified storage)
/// - UNIFIED STORAGE FIX: Single source of truth for all OAuth tokens and account persistence
///
/// ## No Client Secret
/// Native/installed apps are "public clients" and cannot securely store secrets.
/// This implementation uses:
/// - PKCE (Proof Key for Code Exchange) for desktop
/// - Native Google Sign-In SDK for mobile (handles security internally)
///
/// ## Scopes
/// Minimum required: `gmail.readonly` or `gmail.modify`
/// Use [requestAdditionalScopes] for incremental authorization.
///
/// ## google_sign_in 7.x API
/// This service uses the google_sign_in 7.x API which has:
/// - `GoogleSignIn.instance` singleton pattern
/// - Stream-based authentication events
/// - `authenticate()` for interactive sign-in
/// - `authorizationClient.authorizeScopes()` for scope requests
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart'
    as gsi_platform;
import 'package:my_email_spam_filter/core/services/background_mode_service.dart';
import 'package:my_email_spam_filter/core/services/diagnostic_logger.dart';
import 'package:my_email_spam_filter/adapters/auth/token_store.dart';
import 'package:my_email_spam_filter/adapters/storage/secure_credentials_store.dart';
import 'package:my_email_spam_filter/adapters/email_providers/gmail_windows_oauth_handler.dart';
import 'package:my_email_spam_filter/core/security/certificate_pinner.dart'
    show CertificatePinMismatchException;
import 'package:my_email_spam_filter/util/redact.dart';

/// Gmail API scopes.
///
/// **Declare only what is REQUESTED** (GP-4, Sprint 66). Google's OAuth
/// verification reviews the scopes an app declares, and every restricted scope
/// widens what a reviewer must assess and what the app must justify. Two
/// constants were removed here because nothing requested them:
///
/// - `readonly` (`gmail.readonly`) -- restricted, and redundant: `modify`
///   already covers reading. Zero usages.
/// - `send` (`gmail.send`) -- the app never sends mail. Declaring a send scope
///   on a spam filter invites exactly the question a reviewer should not have
///   to ask. Zero usages.
///
/// Removing them is not tidying: it is narrowing the verification surface
/// before submitting. Do not re-add a constant here speculatively -- add it
/// when a code path actually requests it.
class GmailScopes {
  /// Read and modify Gmail messages: the app deletes and moves mail, so
  /// read-only is insufficient.
  static const String modify = 'https://www.googleapis.com/auth/gmail.modify';

  /// User info email scope -- identifies WHICH account was authorised, so
  /// multi-account bookkeeping can attribute rules and scans correctly.
  static const String userInfoEmail = 'https://www.googleapis.com/auth/userinfo.email';

  /// The scopes actually requested. Must stay identical to the Windows
  /// handler's own list (`gmail_windows_oauth_handler.dart`) -- the two are
  /// separate declarations that today agree, and `test/policy/
  /// gmail_scope_parity_test.dart` is what keeps them agreeing (ADR-0042
  /// shared-behaviour parity).
  static const List<String> defaultScopes = [modify, userInfoEmail];
}

/// Authentication state for Gmail.
enum AuthState {
  /// Not authenticated, no stored tokens.
  unauthenticated,

  /// Has stored tokens, needs validation.
  storedCredentials,

  /// Fully authenticated with valid tokens.
  authenticated,

  /// Authentication in progress.
  authenticating,

  /// Token refresh in progress.
  refreshing,

  /// Authentication failed.
  error,
}

/// Result of authentication attempt.
class AuthResult {
  final bool success;
  final String? email;
  final String? accessToken;
  final String? errorMessage;
  final AuthState state;

  AuthResult({
    required this.success,
    this.email,
    this.accessToken,
    this.errorMessage,
    required this.state,
  });

  factory AuthResult.success(String email, String accessToken) => AuthResult(
        success: true,
        email: email,
        accessToken: accessToken,
        state: AuthState.authenticated,
      );

  factory AuthResult.failure(String message) => AuthResult(
        success: false,
        errorMessage: message,
        state: AuthState.error,
      );

  factory AuthResult.unauthenticated() => AuthResult(
        success: false,
        state: AuthState.unauthenticated,
      );
}

/// Google OAuth 2.0 authentication service.
///
/// Provides unified authentication flow across all platforms:
/// - Android/iOS: Native Google Sign-In SDK
/// - Windows/macOS/Linux: Browser-based OAuth with PKCE
///
/// ## Usage
/// ```dart
/// final authService = GoogleAuthService();
///
/// // Initialize and try silent sign-in
/// final result = await authService.initialize();
/// if (result.success) {
///   print('Signed in as: ${result.email}');
/// }
///
/// // Interactive sign-in
/// final signInResult = await authService.signIn();
///
/// // Get valid access token (auto-refreshes if needed)
/// final token = await authService.getValidAccessToken();
///
/// // Sign out
/// await authService.signOut();
/// ```
class GoogleAuthService {
  final SecureCredentialsStore _credStore;
  final List<String> _scopes;

  // google_sign_in 7.x uses singleton pattern
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;
  GoogleSignInAccount? _currentUser;
  AuthState _state = AuthState.unauthenticated;
  String? _currentAccountId;
  StreamSubscription<GoogleSignInAccount?>? _authSubscription;
  bool _isInitialized = false;

  GoogleAuthService({
    SecureCredentialsStore? credentialsStore,
    List<String>? scopes,
  })  : _credStore = credentialsStore ?? SecureCredentialsStore(),
        _scopes = scopes ?? GmailScopes.defaultScopes;

  /// Current authentication state.
  AuthState get state => _state;

  /// Current user email (if authenticated).
  String? get currentUserEmail => _currentUser?.email;

  /// Check if running on a platform with native Google Sign-In support.
  bool get _hasNativeSignIn => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Check if running on desktop platform.
  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Initialize the service and attempt silent sign-in.
  ///
  /// Call this on app startup to restore previous session.
  ///
  /// [accountId] - Optional email address of the specific Gmail account to initialize.
  ///               If not provided, uses the first saved account.
  Future<AuthResult> initialize({String? accountId}) async {
    _state = AuthState.storedCredentials;

    // Try to restore from stored tokens first
    final accounts = await _credStore.getSavedAccounts();
    if (accounts.isEmpty) {
      _state = AuthState.unauthenticated;
      return AuthResult.unauthenticated();
    }

    // Use provided accountId or fall back to first account
    final targetAccountId = accountId ?? accounts.first;

    // Verify the target account exists in saved accounts
    if (!accounts.contains(targetAccountId)) {
      Redact.logSafe('[Auth] Requested account $targetAccountId not found in saved accounts');
      _state = AuthState.unauthenticated;
      return AuthResult.unauthenticated();
    }

    _currentAccountId = targetAccountId;

    final result = await _attemptSilentSignIn(targetAccountId);

    // If silent sign-in failed and we're on Android, try native refresh
    if (!result.success && Platform.isAndroid) {
      Redact.logSafe('[Auth] Silent sign-in failed, attempting native refresh...');

      // Get tokens for native refresh (even if expired)
      final tokens = await _credStore.getGmailTokens(targetAccountId);
      if (tokens != null) {
        return await _refreshViaNativeSignIn(targetAccountId, tokens);
      }
    }

    return result;
  }

  /// Attempt silent sign-in / token refresh.
  Future<AuthResult> _attemptSilentSignIn(String accountId) async {
    final tokens = await _credStore.getGmailTokens(accountId);
    if (tokens == null) {
      _state = AuthState.unauthenticated;
      return AuthResult.unauthenticated();
    }

    // If token not expired, we're good
    if (!tokens.isExpired) {
      _state = AuthState.authenticated;
      Redact.logSafe('Silent sign-in success (valid token): ${Redact.email(tokens.email)}');
      return AuthResult.success(tokens.email, tokens.accessToken);
    }

    // Token expired, try refresh
    if (tokens.canRefresh) {
      _state = AuthState.refreshing;
      return await _refreshToken(accountId, tokens);
    }

    // No refresh token (e.g., web) - need interactive sign-in
    _state = AuthState.unauthenticated;
    Redact.logSafe('Token expired, no refresh token available');
    return AuthResult.unauthenticated();
  }

  /// Refresh access token using refresh token.
  Future<AuthResult> _refreshToken(String accountId, GmailTokens tokens) async {
    try {
      Redact.logSafe('Attempting token refresh for: ${Redact.email(tokens.email)}');

      if (_hasNativeSignIn) {
        // Use native Google Sign-In SDK for refresh
        AuthResult native;
        try {
          native = await _refreshViaNativeSignIn(accountId, tokens);
        } catch (e) {
          _renewalLog('native renewal threw ${DiagnosticLogger.describeError(e)}');
          native = AuthResult.failure('Session expired. Please sign in again.');
        }
        // Sprint 76 (Harold Q2 = 1): when native renewal fails on Android and
        // the browser sign-in left a refresh token, renew with it. Before,
        // that token was stored and never used, so every expiry asked the
        // user to sign in again ("I had to re-authenticate the gmail account
        // at least once today"). It needs no Activity, so it also works in a
        // background worker.
        if (shouldTryStoredRefreshToken(
            nativeSucceeded: native.success,
            isAndroid: Platform.isAndroid,
            hasRefreshToken: tokens.refreshToken?.isNotEmpty == true)) {
          return await _refreshViaStoredRefreshToken(accountId, tokens);
        }
        // 7.7.1 review (Sprint 76): the inner catch above stops a native
        // throw from reaching the outer catch -- the only place that left
        // `refreshing` -- so with no fallback the state stuck at refreshing.
        if (!native.success) _state = AuthState.unauthenticated;
        return native;
      } else if (_isDesktop) {
        // Use HTTP token refresh for desktop
        return await _refreshViaHttp(accountId, tokens);
      } else {
        // Web - try silent sign-in
        return await _refreshViaNativeSignIn(accountId, tokens);
      }
    } catch (e) {
      // Review (Sprint 75): logSafe is debug-only, so a release build kept
      // no trace of WHY renewal failed. Type and code carry no account data.
      Redact.logWarning('Token refresh failed: ${e.runtimeType}'
          '${e is PlatformException ? ' code=${e.code}' : ''}');
      _renewalLog('renewal threw ${DiagnosticLogger.describeError(e)}');
      // Sprint 74 MV (Harold Q1, 2026-09-27): a failed renewal NO LONGER
      // deletes the stored tokens -- here or in the four sites below. The
      // failure may be transient (no network, no Activity in a background
      // worker, Credential Manager briefly unavailable), and deleting turned
      // every such failure into "Error: Missing credentials" with Delete as
      // the only option (Fold8, 0.16.0). Keeping a token that really was
      // revoked costs one more failed attempt; deleting a good one costs the
      // account. Only signOut() deletes tokens.
      _state = AuthState.unauthenticated;
      return AuthResult.failure('Session expired. Please sign in again.');
    }
  }

  /// Refresh using native Google Sign-In (Android/iOS).
  /// 
  /// Uses google_sign_in 7.x API with stream-based authentication.
  Future<AuthResult> _refreshViaNativeSignIn(String accountId, GmailTokens tokens) async {
    try {
      // Initialize if needed
      await _ensureNativeSignInInitialized();

      // F239 R-1/R-2 (Sprint 75): ask for a token for THIS account's email
      // with no prompt. Google: an already-granted request returns the token
      // with no UI. Lightweight sign-in below needs an Activity (it fails
      // with NO_ACTIVITY in a WorkManager worker). Anything but a token falls
      // through to the existing path unchanged.
      //
      // OFF: the R-1 emulator spike FAILED on 2026-10-03 -- from a
      // WorkManager isolate the call returned NULL for an account that had
      // granted the scopes (ADR-0011). R-2 was approved only if the spike
      // passed, so it is not built. Backlog F246 (server-side token
      // exchange) replaces this route; the debug probe was removed.
      final directToken = noActivityRenewalEnabled
          ? await authorizeWithoutActivity(tokens.email)
          : null;
      if (directToken != null) {
        final newTokens = GmailTokens(
          accessToken: directToken,
          refreshToken: tokens.refreshToken,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          grantedScopes: _scopes,
          email: tokens.email,
        );
        await _credStore.saveGmailTokens(accountId, newTokens);
        _currentAccountId = accountId;
        _state = AuthState.authenticated;
        return AuthResult.success(tokens.email, directToken);
      }

      // Try lightweight authentication (silent sign-in)
      final user = await _googleSignIn.attemptLightweightAuthentication();

      if (user == null) {
        // Silent sign-in failed. Tokens are KEPT (Harold Q1, Sprint 74 MV --
        // see _refreshToken): this can be transient.
        // Sprint 76 (Harold: "I had to re-authenticate the gmail account at
        // least once today"): name the step that failed, and whether a
        // refresh token from the browser sign-in was sitting unused -- on
        // Android renewal never reads it (only the desktop HTTP path does).
        _renewalLog('native silent sign-in returned no account '
            '(stored refresh token: '
            '${tokens.refreshToken == null ? 'none' : 'present, not used on Android'})');
        _state = AuthState.unauthenticated;
        return AuthResult.unauthenticated();
      }

      // Review (Sprint 75, M-4): the SDK returns whichever Google account it
      // last signed in -- after a refused wrong-account Sign In Again, that
      // can be another account. Saving its token under THIS id would scan
      // the other mailbox with this account's rules. Save nothing.
      if (!isExpectedAccount(user.email, tokens.email)) {
        Redact.logWarning('Renewal returned a different Google account; '
            'nothing saved');
        _state = AuthState.unauthenticated;
        return AuthResult.unauthenticated();
      }

      _currentUser = user;

      // Get fresh access token via authorization
      final authorization = await user.authorizationClient.authorizationForScopes(_scopes);
      if (authorization == null) {
        // Tokens KEPT (Harold Q1, Sprint 74 MV -- see _refreshToken).
        _renewalLog('native authorizationForScopes returned no token');
        _state = AuthState.unauthenticated;
        return AuthResult.unauthenticated();
      }

      final newTokens = GmailTokens(
        accessToken: authorization.accessToken,
        refreshToken: tokens.refreshToken, // Keep existing refresh token
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        grantedScopes: _scopes,
        email: user.email,
      );

      await _credStore.saveGmailTokens(accountId, newTokens);
      _state = AuthState.authenticated;

      Redact.logSafe('Token refresh success: ${Redact.email(user.email)}');
      return AuthResult.success(user.email, authorization.accessToken);
    } catch (e) {
      Redact.logSafe('Native sign-in refresh failed: ${e.runtimeType}');
      rethrow;
    }
  }

  /// F239 R-2 (Sprint 75): whether Android renewal tries
  /// [authorizeWithoutActivity] first. False: the R-1 emulator spike FAILED
  /// (2026-10-03, ADR-0011), and R-2 was approved only if it passed (plan
  /// Open question 2). Do not enable without a new spike and a new approval.
  static bool noActivityRenewalEnabled = false;

  /// F239 (Sprint 75): test seam for [authorizeWithoutActivity].
  @visibleForTesting
  static Future<String?> Function(String email, List<String> scopes)?
      debugAuthorizeWithoutActivity;

  /// F239 R-1/R-2 (Sprint 75): an access token for [email]'s already-granted
  /// Gmail scopes, without any UI and without an Activity -- or null.
  ///
  /// Uses the platform interface because it accepts the account EMAIL;
  /// google_sign_in 7.2.0's instance-level client passes no account hint.
  /// Logs the outcome on one line tagged `[F239 spike]` (no address, no
  /// token), kept so a scope-matched retry of the spike (F246) can be read
  /// from logcat. No production path calls this while
  /// [noActivityRenewalEnabled] is false.
  Future<String?> authorizeWithoutActivity(String email) async {
    final authorize = debugAuthorizeWithoutActivity ??
        (String e, List<String> scopes) async {
          await _ensureNativeSignInInitialized();
          final data = await gsi_platform.GoogleSignInPlatform.instance
              .clientAuthorizationTokensForScopes(
            gsi_platform.ClientAuthorizationTokensForScopesParameters(
              request: gsi_platform.AuthorizationRequestDetails(
                scopes: scopes,
                userId: null,
                email: e,
                promptIfUnauthorized: false,
              ),
            ),
          );
          return data?.accessToken;
        };
    final where =
        BackgroundModeService.isBackgroundMode ? 'background' : 'foreground';
    try {
      final token = await authorize(email, _scopes);
      final passed = token != null && token.isNotEmpty;
      Redact.logWarning('[F239 spike] authorization without an Activity '
          '($where): ${passed ? 'PASS' : 'NULL (needs the user)'}');
      return passed ? token : null;
    } catch (e) {
      Redact.logWarning('[F239 spike] authorization without an Activity '
          '($where): ERROR ${e.runtimeType}'
          '${e is PlatformException ? ' code=${e.code}' : ''}');
      return null;
    }
  }

  /// Ensure google_sign_in is initialized (7.x API).
  Future<void> _ensureNativeSignInInitialized() async {
    if (_isInitialized) return;
    
    try {
      // On Android/iOS: Don't pass serverClientId - native SDK reads from google-services.json
      // On Desktop: Not used here (we use browser-based OAuth instead)
      // 
      // Note: Android OAuth client ID is configured in android/app/google-services.json
      // and is automatically used by the native Google Sign-In SDK
      await _googleSignIn.initialize(
        clientId: null,  // Let native SDKs use their platform-specific configs
        serverClientId: null,  // Android reads from google-services.json automatically
      );
      _isInitialized = true;
      Redact.logSafe('Google Sign-In initialized for ${Platform.operatingSystem}');
    } catch (e) {
      Redact.logSafe('Google Sign-In initialization failed: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Sprint 76 (Harold Q2 = 1): whether to fall back to the stored refresh
  /// token after native renewal.
  @visibleForTesting
  static bool shouldTryStoredRefreshToken({
    required bool nativeSucceeded,
    required bool isAndroid,
    required bool hasRefreshToken,
  }) =>
      !nativeSucceeded && isAndroid && hasRefreshToken;

  /// Test seam for [_refreshViaStoredRefreshToken]'s token call.
  @visibleForTesting
  static Future<String> Function(String refreshToken)? debugMobileRefresh;

  /// Renew with the refresh token the Android browser sign-in stored, using
  /// the Android OAuth client that issued it. Tokens are KEPT on failure
  /// (Harold Q1, Sprint 74 MV -- see _refreshToken).
  Future<AuthResult> _refreshViaStoredRefreshToken(
      String accountId, GmailTokens tokens) async {
    try {
      final refresh =
          debugMobileRefresh ?? GmailWindowsOAuthHandler.refreshAccessTokenMobile;
      final newAccessToken = await refresh(tokens.refreshToken!);
      if (newAccessToken.isEmpty) {
        _renewalLog('stored refresh token: Google returned no access token');
        _state = AuthState.unauthenticated;
        return AuthResult.failure('Session expired. Please sign in again.');
      }
      final newTokens = tokens.copyWith(
        accessToken: newAccessToken,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await _credStore.saveGmailTokens(accountId, newTokens);
      _currentAccountId = accountId;
      _state = AuthState.authenticated;
      _renewalLog('renewed with the stored refresh token');
      return AuthResult.success(tokens.email, newAccessToken);
    } catch (e) {
      _renewalLog('stored refresh token failed: ${DiagnosticLogger.describeError(e)}');
      _state = AuthState.unauthenticated;
      return AuthResult.failure('Session expired. Please sign in again.');
    }
  }

  /// Refresh using HTTP token endpoint (desktop platforms).
  Future<AuthResult> _refreshViaHttp(String accountId, GmailTokens tokens) async {
    if (tokens.refreshToken == null) {
      _state = AuthState.unauthenticated;
      return AuthResult.unauthenticated();
    }

    try {
      // Use existing Windows OAuth handler for token refresh
      final newAccessToken = await GmailWindowsOAuthHandler.refreshAccessToken(
        tokens.refreshToken!,
      );

      if (newAccessToken.isEmpty) {
        // Tokens KEPT (Harold Q1, Sprint 74 MV -- see _refreshToken).
        _state = AuthState.unauthenticated;
        return AuthResult.failure('Token refresh failed');
      }

      final newTokens = tokens.copyWith(
        accessToken: newAccessToken,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      await _credStore.saveGmailTokens(accountId, newTokens);
      _state = AuthState.authenticated;

      Redact.logSafe('Desktop token refresh success: ${Redact.email(tokens.email)}');
      return AuthResult.success(tokens.email, newAccessToken);
    } catch (e) {
      Redact.logSafe('Desktop token refresh failed: ${e.runtimeType}');
      // Tokens KEPT (Harold Q1, Sprint 74 MV -- see _refreshToken).
      _state = AuthState.unauthenticated;
      // SEC-8b (Sprint 77): since the pin now runs on every connection, a
      // refresh can fail because the pin refused the server. Say THAT, not
      // "session expired" -- signing in again would hit the same refusal.
      if (e is CertificatePinMismatchException) {
        return AuthResult.failure(CertificatePinMismatchException.userMessage);
      }
      return AuthResult.failure('Session expired. Please sign in again.');
    }
  }

  /// Interactive sign-in flow.
  ///
  /// Shows Google consent screen and stores tokens on success.
  ///
  /// F239 (Sprint 75): [expectedAccountId] is the "Sign In Again" path -- the
  /// user is repairing ONE existing account. If Google returns a different
  /// account, NOTHING is saved and the failure names both addresses. The check
  /// must come before `saveGmailTokens`, because saving also ADDS the account
  /// to the saved-account list (a stray second account otherwise).
  ///
  /// Sprint 77 final review: [confirmAdd] is the add-account question. It is
  /// called with the signed-in address, after the identity is known and
  /// BEFORE tokens are saved, only when [expectedAccountId] is null (an add,
  /// not a renewal). Returning false stops with "Sign-in cancelled" and
  /// saves nothing.
  Future<AuthResult> signIn({
    String? expectedAccountId,
    Future<bool> Function(String email)? confirmAdd,
  }) async {
    _state = AuthState.authenticating;

    try {
      if (_hasNativeSignIn) {
        return await _signInNative(
            expectedAccountId: expectedAccountId, confirmAdd: confirmAdd);
      } else if (_isDesktop) {
        return await _signInDesktop(
            expectedAccountId: expectedAccountId, confirmAdd: confirmAdd);
      } else {
        // Web fallback
        return await _signInNative(
            expectedAccountId: expectedAccountId, confirmAdd: confirmAdd);
      }
    } catch (e) {
      _state = AuthState.error;
      Redact.logSafe('Sign-in failed: ${e.runtimeType}');
      return AuthResult.failure('Sign-in failed: ${e.toString()}');
    }
  }

  /// Native Google Sign-In (Android/iOS).
  /// 
  /// Uses google_sign_in 7.x API with authenticate() method.
  /// On Android, uses browser-based OAuth as fallback if native fails.
  /// F239: true when [signedInEmail] is the account being repaired (case is
  /// ignored; Google may return a different case than was stored). Always
  /// true when no account is expected (a first-time add).
  @visibleForTesting
  static bool isExpectedAccount(String signedInEmail, String? expectedAccountId) =>
      expectedAccountId == null ||
      signedInEmail.trim().toLowerCase() ==
          expectedAccountId.trim().toLowerCase();

  static AuthResult _wrongAccount(String signedIn, String expected) =>
      AuthResult.failure('You signed in as $signedIn. To fix $expected, sign '
          'in with $expected.');

  Future<AuthResult> _signInNative({
    String? expectedAccountId,
    Future<bool> Function(String email)? confirmAdd,
  }) async {
    // F248 (Sprint 76): which step was running when it failed. On the Fold
    // (0.17.0) native sign-in failed AFTER the account pick and fell back to
    // the browser (F250); without this nobody can say which call threw.
    var step = 'initialize';
    try {
      await _ensureNativeSignInInitialized();

      Redact.logSafe('[Auth] Starting Gmail OAuth sign-in via GoogleAuthService...');

      // Use authenticate() for interactive sign-in (7.x API)
      step = 'authenticate';
      _currentUser = await _googleSignIn.authenticate();

      if (_currentUser == null) {
        _state = AuthState.unauthenticated;
        Redact.logSafe('[Auth] Gmail sign-in failed or was cancelled');
        _signInLog('native authenticate returned no user (cancelled)');
        return AuthResult.failure('Sign-in cancelled');
      }
      _signInLog('native authenticate ok: '
          '${Redact.email(_currentUser!.email)}');

      // Request authorization for scopes
      Redact.logSafe('[Auth] Got user, requesting Gmail API scopes...');
      step = 'authorizeScopes';
      final authorization = await _currentUser!.authorizationClient.authorizeScopes(_scopes);
      _signInLog('native authorizeScopes ok');

      final accountId = _currentUser!.email;
      // F239: refuse a different account BEFORE saving (saving adds it).
      if (!isExpectedAccount(accountId, expectedAccountId)) {
        _state = AuthState.unauthenticated;
        return _wrongAccount(accountId, expectedAccountId!);
      }
      // Sprint 77 final review: an ADD (no expected account) of an address
      // that is already saved asks before anything is saved. Renewal passes
      // expectedAccountId and is never asked.
      if (expectedAccountId == null &&
          confirmAdd != null &&
          !await confirmAdd(accountId)) {
        _state = AuthState.unauthenticated;
        return AuthResult.failure('Sign-in cancelled');
      }
      _currentAccountId = accountId;

      final tokens = GmailTokens(
        accessToken: authorization.accessToken,
        refreshToken: null, // Native SDK manages refresh internally
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        grantedScopes: _scopes,
        email: _currentUser!.email,
      );

      await _credStore.saveGmailTokens(accountId, tokens);
      _state = AuthState.authenticated;

      Redact.logSafe('Sign-in success: ${Redact.email(_currentUser!.email)}');
      return AuthResult.success(_currentUser!.email, authorization.accessToken);
    } catch (e) {
      _state = AuthState.error;
      Redact.logError('Native sign-in failed', e);
      _signInLog('native $step FAILED: ${DiagnosticLogger.describeError(e)}');

      // On Android, fall back to browser-based OAuth if native fails
      if (Platform.isAndroid) {
        Redact.logSafe('[Auth] Trying browser-based OAuth fallback on Android...');
        _signInLog('falling back to the browser sign-in');
        final fallback = await _signInDesktop(
            expectedAccountId: expectedAccountId,
            confirmAdd: confirmAdd); // Desktop method works for Android too
        if (fallback.success) {
          // F250 R-3 / F246: whether the browser path stored a refresh token
          // decides if Android background renewal could work on this path.
          final saved = await _credStore.getGmailTokens(fallback.email ?? '');
          // Review MEDIUM-4: getGmailTokens returns null on a READ failure
          // too, so "none" is not proof nothing was stored.
          _signInLog('browser sign-in succeeded (refresh token '
              '${saved == null ? 'unknown: tokens could not be read back' : saved.refreshToken == null ? 'NOT stored' : 'stored'})');
        } else {
          _signInLog('browser sign-in failed: '
              '${DiagnosticLogger.scrub(fallback.errorMessage ?? 'no message')}');
        }
        return fallback;
      }
      
      return AuthResult.failure('Sign-in failed: ${e.toString()}');
    }
  }

  /// F248: one Gmail sign-in record (fire-and-forget). Addresses must already
  /// be redacted by the caller.
  void _signInLog(String detail) => unawaited(DiagnosticLogger.log(
        kind: DiagnosticLogger.kindSignIn,
        context: 'gmail/sign-in',
        detail: detail,
      ));

  /// Sprint 76: why a token RENEWAL failed (no account data in the text).
  void _renewalLog(String detail) => unawaited(DiagnosticLogger.log(
        kind: DiagnosticLogger.kindSignIn,
        context: 'gmail/renewal',
        detail: detail,
      ));

  /// Desktop browser-based OAuth with PKCE.
  Future<AuthResult> _signInDesktop({
    String? expectedAccountId,
    Future<bool> Function(String email)? confirmAdd,
  }) async {
    try {
      // Use existing GmailWindowsOAuthHandler for browser-based OAuth
      final tokenResult = await GmailWindowsOAuthHandler.authenticateWithBrowser();

      if (tokenResult == null) {
        _state = AuthState.unauthenticated;
        return AuthResult.failure('Sign-in cancelled');
      }

      final accessToken = tokenResult['access_token'];
      final refreshToken = tokenResult['refresh_token'];
      final expiresInStr = tokenResult['expires_in'];

      if (accessToken == null || accessToken.isEmpty) {
        _state = AuthState.error;
        return AuthResult.failure('No access token received');
      }

      // Get user email from access token
      final email = await GmailWindowsOAuthHandler.getUserEmail(accessToken);
      final accountId = email;
      // F239: refuse a different account BEFORE saving (saving adds it).
      if (!isExpectedAccount(accountId, expectedAccountId)) {
        _state = AuthState.unauthenticated;
        return _wrongAccount(accountId, expectedAccountId!);
      }
      // Sprint 77 final review: an ADD (no expected account) of an address
      // that is already saved asks before anything is saved. Renewal passes
      // expectedAccountId and is never asked.
      if (expectedAccountId == null &&
          confirmAdd != null &&
          !await confirmAdd(accountId)) {
        _state = AuthState.unauthenticated;
        return AuthResult.failure('Sign-in cancelled');
      }
      _currentAccountId = accountId;

      // Calculate expiry
      final expiresIn = int.tryParse(expiresInStr ?? '3600') ?? 3600;
      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

      final tokens = GmailTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
        grantedScopes: _scopes,
        email: email,
      );

      await _credStore.saveGmailTokens(accountId, tokens);
      _state = AuthState.authenticated;

      Redact.logSafe('Desktop sign-in success: ${Redact.email(email)}');
      return AuthResult.success(email, accessToken);
    } catch (e) {
      _state = AuthState.error;
      Redact.logError('Desktop sign-in failed', e);
      if (e is CertificatePinMismatchException) {
        return AuthResult.failure(CertificatePinMismatchException.userMessage);
      }
      return AuthResult.failure('Sign-in failed: ${e.toString()}');
    }
  }

  /// Sign out and optionally revoke tokens.
  ///
  /// Removes stored tokens and optionally revokes server-side.
  /// SEC-12: Desktop platforms revoke tokens via Google's revoke endpoint.
  Future<void> signOut({bool revokeServerTokens = false}) async {
    try {
      if (_hasNativeSignIn && _isInitialized) {
        if (revokeServerTokens) {
          await _googleSignIn.disconnect();
        } else {
          await _googleSignIn.signOut();
        }
      } else if (revokeServerTokens && _currentAccountId != null) {
        // SEC-12: Desktop platforms - revoke token at Google endpoint
        await _revokeTokenAtGoogle(_currentAccountId!);
      }

      // Clear stored tokens for current account
      if (_currentAccountId != null) {
        await _credStore.deleteGmailTokens(_currentAccountId!);
      }

      _currentUser = null;
      _currentAccountId = null;
      _state = AuthState.unauthenticated;

      Redact.logSafe('Signed out and cleared tokens');
    } catch (e) {
      Redact.logSafe('Sign-out error: ${e.runtimeType}');
      // Still clear local tokens even if server revoke fails
      if (_currentAccountId != null) {
        await _credStore.deleteGmailTokens(_currentAccountId!);
      }
      _state = AuthState.unauthenticated;
    }
  }

  /// Revoke OAuth token at Google's revocation endpoint (SEC-12).
  ///
  /// Attempts to revoke the refresh token first (invalidates all associated
  /// access tokens), falling back to access token if no refresh token exists.
  /// Failures are logged but do not block the sign-out flow.
  Future<void> _revokeTokenAtGoogle(String accountId) async {
    try {
      final tokens = await _credStore.getGmailTokens(accountId);
      if (tokens == null) return;

      // Prefer revoking refresh token (invalidates all associated access tokens)
      final tokenToRevoke = tokens.refreshToken?.isNotEmpty == true
          ? tokens.refreshToken!
          : tokens.accessToken;

      if (tokenToRevoke.isEmpty) return;

      // SEC-12 / C2 fix: token in form-encoded body, not URL query string.
      // URLs are routinely logged by HTTP clients, proxies, and crash reporters.
      // Per RFC 7009 Section 2.1, token must be in request body.
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/revoke'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'token': tokenToRevoke},
      );

      if (response.statusCode == 200) {
        Redact.logSafe('Token revoked at Google endpoint');
      } else {
        Redact.logWarning('Token revocation returned HTTP ${response.statusCode}');
      }
    } catch (e) {
      // Do not block sign-out on revocation failure
      Redact.logWarning('Token revocation failed: ${e.runtimeType}');
    }
  }

  /// Disconnect Gmail - closes the current session.
  ///
  /// IMPORTANT: Only signs out the current account, does NOT delete other accounts' credentials.
  /// This is called after scans to close the IMAP/API connection.
  /// Use signOut() to clear only current account tokens, not ALL accounts.
  Future<void> disconnect() async {
    // Just sign out the current account (revokes its tokens)
    // Do NOT call clearAll() as that would delete ALL accounts' credentials
    await signOut(revokeServerTokens: true);
    Redact.logSafe('Gmail account disconnected (current session only)');
  }

  /// Get valid access token (refreshing if needed).
  ///
  /// Returns null if not authenticated or refresh fails.
  ///
  /// F239 (Sprint 75, R-5): the token is for [accountId] (or the account this
  /// service already serves) -- NEVER `accounts.first`. A fresh service with
  /// AOL saved first used to look up AOL's Gmail tokens and fail, or worse,
  /// serve another Gmail account's token.
  Future<String?> getValidAccessToken({String? accountId}) async {
    final target = accountId ?? _currentAccountId;
    if (target == null) {
      Redact.logSafe('[Auth] getValidAccessToken: no account given -- refusing '
          'to guess one');
      return null;
    }
    if (_state != AuthState.authenticated || _currentAccountId != target) {
      final result = await initialize(accountId: target);
      if (!result.success) return null;
    }

    final accounts = await _credStore.getSavedAccounts();
    if (!accounts.contains(target)) return null;

    final tokens = await _credStore.getGmailTokens(target);
    if (tokens == null) return null;

    if (tokens.isExpired) {
      final result = await _attemptSilentSignIn(target);
      return result.accessToken;
    }

    return tokens.accessToken;
  }

  /// Get current tokens (for external use).
  Future<GmailTokens?> getCurrentTokens() async {
    final accounts = await _credStore.getSavedAccounts();
    if (accounts.isEmpty) return null;
    return await _credStore.getGmailTokens(_currentAccountId ?? accounts.first);
  }

  /// Request additional scopes (incremental authorization).
  /// 
  /// Uses google_sign_in 7.x authorizationClient API.
  Future<AuthResult> requestAdditionalScopes(List<String> additionalScopes) async {
    if (!_hasNativeSignIn || _currentUser == null) {
      return AuthResult.failure('Incremental auth only supported on mobile');
    }

    try {
      // Use 7.x API for requesting additional scopes
      final authorization = await _currentUser!.authorizationClient.authorizeScopes(additionalScopes);

      // Update stored tokens with new scopes
      final accountId = _currentUser!.email;
      final existingTokens = await _credStore.getGmailTokens(accountId);

      final newTokens = GmailTokens(
        accessToken: authorization.accessToken,
        refreshToken: existingTokens?.refreshToken,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        grantedScopes: [..._scopes, ...additionalScopes],
        email: _currentUser!.email,
      );

      await _credStore.saveGmailTokens(accountId, newTokens);
      Redact.logSafe('Additional scopes granted');
      return AuthResult.success(_currentUser!.email, authorization.accessToken);
    } catch (e) {
      return AuthResult.failure('Failed to request scopes: ${e.toString()}');
    }
  }

  /// Dispose of resources.
  void dispose() {
    _authSubscription?.cancel();
  }
}
