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
import 'package:google_sign_in/google_sign_in.dart';
import 'package:spam_filter_mobile/adapters/auth/token_store.dart';
import 'package:spam_filter_mobile/adapters/storage/secure_credentials_store.dart';
import 'package:spam_filter_mobile/adapters/email_providers/gmail_windows_oauth_handler.dart';
import 'package:spam_filter_mobile/util/redact.dart';

/// Gmail API scopes.
class GmailScopes {
  /// Read-only access to Gmail messages and settings.
  static const String readonly = 'https://www.googleapis.com/auth/gmail.readonly';

  /// Full access to Gmail (read, send, delete, manage).
  static const String modify = 'https://www.googleapis.com/auth/gmail.modify';

  /// Send email only.
  static const String send = 'https://www.googleapis.com/auth/gmail.send';

  /// User info email scope.
  static const String userInfoEmail = 'https://www.googleapis.com/auth/userinfo.email';

  /// Default scopes for spam filter (need to read and modify/delete).
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

  // Client ID injected via --dart-define
  // Prefer WINDOWS_GMAIL_DESKTOP_CLIENT_ID on Windows, fallback to GMAIL_DESKTOP_CLIENT_ID
  static const String _clientId = String.fromEnvironment(
    'WINDOWS_GMAIL_DESKTOP_CLIENT_ID',
    defaultValue: String.fromEnvironment('GMAIL_DESKTOP_CLIENT_ID', defaultValue: ''),
  );

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
  Future<AuthResult> initialize() async {
    _state = AuthState.storedCredentials;

    // Try to restore from stored tokens first
    final accounts = await _credStore.getSavedAccounts();
    if (accounts.isEmpty) {
      _state = AuthState.unauthenticated;
      return AuthResult.unauthenticated();
    }

    // Try silent sign-in for first account
    final accountId = accounts.first;
    _currentAccountId = accountId;

    final result = await _attemptSilentSignIn(accountId);

    // If silent sign-in failed and we're on Android, try native refresh
    if (!result.success && Platform.isAndroid) {
      Redact.logSafe('[Auth] Silent sign-in failed, attempting native refresh...');

      // Get tokens for native refresh (even if expired)
      final tokens = await _credStore.getGmailTokens(accountId);
      if (tokens != null) {
        return await _refreshViaNativeSignIn(accountId, tokens);
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
        return await _refreshViaNativeSignIn(accountId, tokens);
      } else if (_isDesktop) {
        // Use HTTP token refresh for desktop
        return await _refreshViaHttp(accountId, tokens);
      } else {
        // Web - try silent sign-in
        return await _refreshViaNativeSignIn(accountId, tokens);
      }
    } catch (e) {
      Redact.logSafe('Token refresh failed: ${e.runtimeType}');
      // Refresh failed - tokens may be revoked
      await _credStore.deleteGmailTokens(accountId);
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

      // Try lightweight authentication (silent sign-in)
      final user = await _googleSignIn.attemptLightweightAuthentication();

      if (user == null) {
        // Silent sign-in failed, tokens may be revoked
        await _credStore.deleteGmailTokens(accountId);
        _state = AuthState.unauthenticated;
        return AuthResult.unauthenticated();
      }

      _currentUser = user;

      // Get fresh access token via authorization
      final authorization = await user.authorizationClient.authorizationForScopes(_scopes);
      if (authorization == null) {
        await _credStore.deleteGmailTokens(accountId);
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
        await _credStore.deleteGmailTokens(accountId);
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
      await _credStore.deleteGmailTokens(accountId);
      _state = AuthState.unauthenticated;
      return AuthResult.failure('Session expired. Please sign in again.');
    }
  }

  /// Interactive sign-in flow.
  ///
  /// Shows Google consent screen and stores tokens on success.
  Future<AuthResult> signIn() async {
    _state = AuthState.authenticating;

    try {
      if (_hasNativeSignIn) {
        return await _signInNative();
      } else if (_isDesktop) {
        return await _signInDesktop();
      } else {
        // Web fallback
        return await _signInNative();
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
  Future<AuthResult> _signInNative() async {
    try {
      await _ensureNativeSignInInitialized();

      Redact.logSafe('[Auth] Starting Gmail OAuth sign-in via GoogleAuthService...');

      // Use authenticate() for interactive sign-in (7.x API)
      _currentUser = await _googleSignIn.authenticate();
      
      if (_currentUser == null) {
        _state = AuthState.unauthenticated;
        Redact.logSafe('[Auth] Gmail sign-in failed or was cancelled');
        return AuthResult.failure('Sign-in cancelled');
      }

      // Request authorization for scopes
      Redact.logSafe('[Auth] Got user, requesting Gmail API scopes...');
      final authorization = await _currentUser!.authorizationClient.authorizeScopes(_scopes);
      
      final accountId = 'gmail-${_currentUser!.email}';
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
      
      // On Android, fall back to browser-based OAuth if native fails
      if (Platform.isAndroid) {
        Redact.logSafe('[Auth] Trying browser-based OAuth fallback on Android...');
        return await _signInDesktop(); // Desktop method works for Android too
      }
      
      return AuthResult.failure('Sign-in failed: ${e.toString()}');
    }
  }

  /// Desktop browser-based OAuth with PKCE.
  Future<AuthResult> _signInDesktop() async {
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
      final accountId = 'gmail-$email';
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
      return AuthResult.failure('Sign-in failed: ${e.toString()}');
    }
  }

  /// Sign out and optionally revoke tokens.
  ///
  /// Removes stored tokens and optionally revokes server-side.
  Future<void> signOut({bool revokeServerTokens = false}) async {
    try {
      if (_hasNativeSignIn && _isInitialized) {
        if (revokeServerTokens) {
          await _googleSignIn.disconnect();
        } else {
          await _googleSignIn.signOut();
        }
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
  Future<String?> getValidAccessToken() async {
    if (_state != AuthState.authenticated) {
      final result = await initialize();
      if (!result.success) return null;
    }

    final accounts = await _credStore.getSavedAccounts();
    if (accounts.isEmpty) return null;

    final accountId = _currentAccountId ?? accounts.first;
    final tokens = await _credStore.getGmailTokens(accountId);
    if (tokens == null) return null;

    if (tokens.isExpired) {
      final result = await _attemptSilentSignIn(accountId);
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
      final accountId = 'gmail-${_currentUser!.email}';
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
