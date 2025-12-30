/// Token storage interface for Gmail OAuth 2.0 credentials.
///
/// ## Design Rationale
/// - **No client secret**: Native/public OAuth clients cannot securely store secrets.
///   Google's OAuth for installed apps uses PKCE instead.
/// - **Encrypted at rest**: All implementations must use platform-native secure storage
///   (Keychain on iOS, Keystore on Android, Credential Manager on Windows).
/// - **Multi-account support**: Users may have multiple Gmail accounts.
///
/// ## Token Lifecycle
/// 1. User authenticates interactively (one-time per device)
/// 2. Access token + refresh token stored securely
/// 3. On app startup, attempt silent sign-in / token refresh
/// 4. If refresh fails (revoked/expired), prompt re-authentication
///
/// ## Security Requirements
/// - NEVER log tokens in plain text
/// - NEVER persist in SharedPreferences, plain files, or localStorage
/// - Always use [SecureTokenStore] implementation
library;

import 'dart:async';

/// OAuth token bundle for Gmail authentication.
class GmailTokens {
  /// Access token for Gmail API calls. Short-lived (typically 1 hour).
  final String accessToken;

  /// Refresh token for obtaining new access tokens. Long-lived.
  /// May be null on web targets where refresh tokens aren't provided.
  final String? refreshToken;

  /// Token expiry timestamp. Null if unknown.
  final DateTime? expiresAt;

  /// OAuth scopes granted by the user.
  final List<String> grantedScopes;

  /// User's email address (for multi-account identification).
  final String email;

  GmailTokens({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    required this.grantedScopes,
    required this.email,
  });

  /// Check if access token is expired (with 5-minute buffer).
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!.subtract(const Duration(minutes: 5)));
  }

  /// Check if refresh is possible (has refresh token).
  bool get canRefresh => refreshToken != null && refreshToken!.isNotEmpty;

  /// Convert to JSON-safe map for storage.
  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt?.toIso8601String(),
        'grantedScopes': grantedScopes,
        'email': email,
      };

  /// Create from JSON map.
  factory GmailTokens.fromJson(Map<String, dynamic> json) => GmailTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String?,
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : null,
        grantedScopes: List<String>.from(json['grantedScopes'] ?? []),
        email: json['email'] as String,
      );

  /// Create a copy with updated fields.
  GmailTokens copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    List<String>? grantedScopes,
    String? email,
  }) {
    return GmailTokens(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      grantedScopes: grantedScopes ?? this.grantedScopes,
      email: email ?? this.email,
    );
  }
}

/// Abstract interface for secure token storage.
///
/// Implementations must encrypt tokens at rest using platform-native mechanisms.
abstract class TokenStore {
  /// Save Gmail tokens for an account.
  ///
  /// [accountId] should be unique per account (e.g., "gmail-user@gmail.com").
  Future<void> saveTokens(String accountId, GmailTokens tokens);

  /// Retrieve stored tokens for an account.
  ///
  /// Returns null if no tokens exist or storage is corrupted.
  Future<GmailTokens?> getTokens(String accountId);

  /// Delete tokens for an account (sign-out / disconnect).
  Future<void> deleteTokens(String accountId);

  /// List all accounts with stored tokens.
  Future<List<String>> listAccounts();

  /// Check if tokens exist for an account.
  Future<bool> hasTokens(String accountId);

  /// Clear all stored tokens (factory reset).
  Future<void> clearAll();
}
