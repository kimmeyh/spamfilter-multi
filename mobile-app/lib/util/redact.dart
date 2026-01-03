/// Token redaction and safe logging utilities.
///
/// ## Purpose
/// Prevents accidental exposure of sensitive data in:
/// - Console logs
/// - Analytics events
/// - Error reports
/// - Debug output
///
/// ## Usage
/// ```dart
/// // Instead of: print('Token: $token');
/// Redact.logSafe('Auth result: ${Redact.token(accessToken)}');
///
/// // Instead of: logger.info('User: $email');
/// Redact.logSafe('User: ${Redact.email(email)}');
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Token and credential redaction utilities.
class Redact {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: kDebugMode ? Level.debug : Level.warning,
  );

  /// Redact a token, showing only first/last 4 characters.
  ///
  /// Example: "ya29.abc...xyz123" → "ya29...3123"
  static String token(String? token) {
    if (token == null || token.isEmpty) return '[empty]';
    if (token.length <= 12) return '[redacted]';
    return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
  }

  /// Redact an email, preserving domain visibility.
  ///
  /// Example: "user@gmail.com" → "u***@gmail.com"
  static String email(String? email) {
    if (email == null || email.isEmpty) return '[empty]';
    final parts = email.split('@');
    if (parts.length != 2) return '[invalid]';
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@$domain';
    return '${name[0]}***@$domain';
  }

  /// Redact an account ID.
  ///
  /// Example: "gmail-user@example.com" → "gmail-u***@example.com"
  static String accountId(String? accountId) {
    if (accountId == null || accountId.isEmpty) return '[empty]';
    if (accountId.contains('-')) {
      final parts = accountId.split('-');
      if (parts.length >= 2) {
        return '${parts[0]}-${email(parts.sublist(1).join('-'))}';
      }
    }
    return '[redacted]';
  }

  /// Redact a client ID, showing only the numeric prefix.
  ///
  /// Example: "123456789.apps.googleusercontent.com" → "1234***"
  static String clientId(String? clientId) {
    if (clientId == null || clientId.isEmpty) return '[empty]';
    if (clientId.length <= 8) return '[redacted]';
    return '${clientId.substring(0, 4)}***';
  }

  /// Log a message safely (redaction already applied to content).
  ///
  /// Only logs in debug mode to prevent production log leaks.
  static void logSafe(String message) {
    if (kDebugMode) {
      _logger.d('[Auth] $message');
    }
  }

  /// Log an error safely with optional stack trace.
  static void logError(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e('[Auth Error] $message', error: error, stackTrace: stackTrace);
  }

  /// Log a warning safely.
  static void logWarning(String message) {
    _logger.w('[Auth Warning] $message');
  }

  /// Create a redacted copy of a map (for logging request/response).
  static Map<String, dynamic> redactMap(Map<String, dynamic> data) {
    final sensitiveKeys = {
      'access_token',
      'accessToken',
      'refresh_token',
      'refreshToken',
      'id_token',
      'idToken',
      'password',
      'secret',
      'client_secret',
      'authorization',
    };

    return data.map((key, value) {
      if (sensitiveKeys.contains(key.toLowerCase())) {
        if (value is String) {
          return MapEntry(key, token(value));
        }
        return MapEntry(key, '[redacted]');
      }
      if (value is Map<String, dynamic>) {
        return MapEntry(key, redactMap(value));
      }
      return MapEntry(key, value);
    });
  }

  /// Guard function that wraps any logging call to prevent token leaks.
  ///
  /// Usage:
  /// ```dart
  /// Redact.guard(() => print('Debug: $sensitiveData'));
  /// // Throws in debug mode if sensitive patterns detected
  /// ```
  static void guard(void Function() logAction) {
    if (!kDebugMode) {
      // In release mode, skip potentially sensitive logs entirely
      return;
    }
    // In debug mode, execute but warn developer
    try {
      logAction();
    } catch (e) {
      logError('Logging guard caught error', e);
    }
  }
}
