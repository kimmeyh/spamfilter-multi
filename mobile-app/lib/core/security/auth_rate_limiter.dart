/// Per-account rate limiter for failed authentication attempts
/// (SEC-22, Sprint 33).
///
/// Policy:
/// - Attempts are counted within a rolling 1-hour window.
/// - After 10 failed attempts in that window the account is blocked for 1 hour.
/// - A successful authentication clears the counter.
/// - State is persisted in the `auth_rate_limit` table so it survives app
///   restarts.
///
/// The limiter intentionally exposes a small, side-effect-free decision API
/// (`checkBlock`) separate from the mutation calls (`recordFailure`,
/// `recordSuccess`) so callers can compose the check + action at the call site
/// without needing a mock.
library;

import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../util/redact.dart';
import '../storage/database_helper.dart';

/// Result of querying the limiter for an account's current status.
class AuthRateLimitStatus {
  /// Whether the account is currently blocked.
  final bool blocked;

  /// When the block expires (UTC, local-tz rendering is the UI's problem).
  /// `null` if the account is not blocked.
  final DateTime? blockedUntil;

  /// How many failures have accrued in the current rolling window.
  /// Never negative, always <= [AuthRateLimiter.maxAttempts].
  final int attempts;

  const AuthRateLimitStatus({
    required this.blocked,
    this.blockedUntil,
    required this.attempts,
  });

  static const AuthRateLimitStatus clear =
      AuthRateLimitStatus(blocked: false, attempts: 0);
}

/// Exception thrown when an authentication attempt is rejected by the
/// rate limiter before reaching the remote server.
class AuthRateLimitedException implements Exception {
  final String accountId;
  final DateTime blockedUntil;

  AuthRateLimitedException(this.accountId, this.blockedUntil);

  @override
  String toString() =>
      'AuthRateLimitedException(account: ${Redact.accountId(accountId)}, '
      'blockedUntil: $blockedUntil)';
}

/// Tracks failed authentication attempts per account and blocks sign-in
/// after [maxAttempts] failures within [windowDuration].
class AuthRateLimiter {
  /// Maximum failed attempts permitted inside the rolling window
  /// before the account is blocked.
  static const int maxAttempts = 10;

  /// Rolling window for counting failures.
  static const Duration windowDuration = Duration(hours: 1);

  /// How long a block lasts once triggered.
  static const Duration blockDuration = Duration(hours: 1);

  final DatabaseHelper _dbHelper;
  final DateTime Function() _clock;
  final Logger _logger = Logger();

  AuthRateLimiter(this._dbHelper, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// Inspect the current status for [accountId] without mutating state.
  ///
  /// Expired blocks are reported as `blocked: false` (they are cleared
  /// lazily the next time [recordFailure] or [recordSuccess] runs).
  Future<AuthRateLimitStatus> checkBlock(String accountId) async {
    final row = await _readRow(accountId);
    if (row == null) return AuthRateLimitStatus.clear;

    final now = _clock();
    final blockUntilMs = row['block_until'] as int?;
    final attempts = (row['attempts'] as int?) ?? 0;

    if (blockUntilMs != null) {
      final blockUntil = DateTime.fromMillisecondsSinceEpoch(blockUntilMs);
      if (now.isBefore(blockUntil)) {
        return AuthRateLimitStatus(
          blocked: true,
          blockedUntil: blockUntil,
          attempts: attempts,
        );
      }
    }

    // Window may have rolled over; if so, the effective attempt count is 0.
    final windowStartMs = row['window_start'] as int?;
    if (windowStartMs != null) {
      final windowStart = DateTime.fromMillisecondsSinceEpoch(windowStartMs);
      if (now.difference(windowStart) >= windowDuration) {
        return AuthRateLimitStatus.clear;
      }
    }

    return AuthRateLimitStatus(blocked: false, attempts: attempts);
  }

  /// Throws [AuthRateLimitedException] if the account is currently blocked.
  /// Otherwise returns normally. Does not mutate state.
  Future<void> assertNotBlocked(String accountId) async {
    final status = await checkBlock(accountId);
    if (status.blocked) {
      throw AuthRateLimitedException(accountId, status.blockedUntil!);
    }
  }

  /// Record a failed authentication attempt for [accountId] and, if this
  /// attempt crosses the threshold, mark the account blocked.
  ///
  /// Returns the status AFTER applying the failure (so callers can surface
  /// "you have N attempts left" messaging).
  Future<AuthRateLimitStatus> recordFailure(String accountId) async {
    final db = await _dbHelper.database;
    final now = _clock();
    final nowMs = now.millisecondsSinceEpoch;

    final row = await _readRow(accountId);

    // Start or continue the rolling window.
    int attempts;
    int windowStartMs;

    if (row == null) {
      attempts = 1;
      windowStartMs = nowMs;
    } else {
      final prevWindowStartMs = row['window_start'] as int? ?? nowMs;
      final prevWindowStart =
          DateTime.fromMillisecondsSinceEpoch(prevWindowStartMs);

      if (now.difference(prevWindowStart) >= windowDuration) {
        // Previous window elapsed; start fresh.
        attempts = 1;
        windowStartMs = nowMs;
      } else {
        attempts = ((row['attempts'] as int?) ?? 0) + 1;
        windowStartMs = prevWindowStartMs;
      }
    }

    int? blockUntilMs;
    if (attempts >= maxAttempts) {
      blockUntilMs = now.add(blockDuration).millisecondsSinceEpoch;
      _logger.w('Auth rate limit hit for ${Redact.accountId(accountId)}: '
          '$attempts failures in window, blocked until '
          '${DateTime.fromMillisecondsSinceEpoch(blockUntilMs)}');
    } else {
      _logger.i('Auth failure recorded for ${Redact.accountId(accountId)}: '
          '$attempts / $maxAttempts');
    }

    await db.insert(
      'auth_rate_limit',
      {
        'account_id': accountId,
        'window_start': windowStartMs,
        'attempts': attempts,
        'block_until': blockUntilMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return AuthRateLimitStatus(
      blocked: blockUntilMs != null,
      blockedUntil: blockUntilMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(blockUntilMs),
      attempts: attempts,
    );
  }

  /// Clear all counters and blocks for [accountId]. Call this after a
  /// successful authentication.
  Future<void> recordSuccess(String accountId) async {
    final db = await _dbHelper.database;
    final count = await db.delete(
      'auth_rate_limit',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
    if (count > 0) {
      _logger.d('Cleared auth rate limit counter for '
          '${Redact.accountId(accountId)}');
    }
  }

  Future<Map<String, Object?>?> _readRow(String accountId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'auth_rate_limit',
      where: 'account_id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }
}

