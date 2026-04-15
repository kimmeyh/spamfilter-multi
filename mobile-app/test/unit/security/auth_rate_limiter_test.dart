import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/security/auth_rate_limiter.dart';

import '../../helpers/database_test_helper.dart';

/// Tests for [AuthRateLimiter] (SEC-22, Sprint 33).
///
/// A controllable clock keeps tests deterministic; they do not wait
/// wall-clock hours to exercise window/block expiry.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseTestHelper testHelper;
  late AuthRateLimiter limiter;
  late DateTime now;
  const accountId = 'aol-user@aol.com';

  setUpAll(() {
    DatabaseTestHelper.initializeFfi();
  });

  setUp(() async {
    testHelper = DatabaseTestHelper();
    await testHelper.setUp();
    now = DateTime(2026, 1, 1, 12, 0, 0);
    limiter = AuthRateLimiter(testHelper.dbHelper, clock: () => now);
  });

  tearDown(() async {
    await testHelper.tearDown();
  });

  group('checkBlock', () {
    test('returns clear status when no prior record exists', () async {
      final status = await limiter.checkBlock(accountId);
      expect(status.blocked, isFalse);
      expect(status.attempts, 0);
      expect(status.blockedUntil, isNull);
    });
  });

  group('recordFailure', () {
    test('increments attempts within the rolling window', () async {
      await limiter.recordFailure(accountId);
      now = now.add(const Duration(minutes: 5));
      final status = await limiter.recordFailure(accountId);
      expect(status.attempts, 2);
      expect(status.blocked, isFalse);
    });

    test('blocks after 10 failures within the window', () async {
      for (var i = 0; i < AuthRateLimiter.maxAttempts - 1; i++) {
        final s = await limiter.recordFailure(accountId);
        expect(s.blocked, isFalse, reason: 'attempt ${i + 1} should not block');
      }
      final finalStatus = await limiter.recordFailure(accountId);
      expect(finalStatus.attempts, AuthRateLimiter.maxAttempts);
      expect(finalStatus.blocked, isTrue);
      expect(
        finalStatus.blockedUntil!
            .difference(now)
            .inMinutes,
        closeTo(AuthRateLimiter.blockDuration.inMinutes, 1),
      );
    });

    test('starts a fresh window when prior window has elapsed', () async {
      // Accumulate some failures
      for (var i = 0; i < 5; i++) {
        await limiter.recordFailure(accountId);
      }
      // Move the clock past the rolling window
      now = now.add(AuthRateLimiter.windowDuration + const Duration(minutes: 1));
      final status = await limiter.recordFailure(accountId);
      expect(status.attempts, 1,
          reason: 'new window should reset to 1');
      expect(status.blocked, isFalse);
    });
  });

  group('assertNotBlocked', () {
    test('does not throw when account is not blocked', () async {
      await expectLater(
          limiter.assertNotBlocked(accountId), completes);
    });

    test('throws AuthRateLimitedException when account is blocked', () async {
      for (var i = 0; i < AuthRateLimiter.maxAttempts; i++) {
        await limiter.recordFailure(accountId);
      }
      await expectLater(
        limiter.assertNotBlocked(accountId),
        throwsA(isA<AuthRateLimitedException>()),
      );
    });

    test('stops throwing once the block expires', () async {
      for (var i = 0; i < AuthRateLimiter.maxAttempts; i++) {
        await limiter.recordFailure(accountId);
      }
      // Inside the block window: throws
      now = now.add(const Duration(minutes: 30));
      await expectLater(
        limiter.assertNotBlocked(accountId),
        throwsA(isA<AuthRateLimitedException>()),
      );

      // After the block expires: does not throw
      now = now.add(const Duration(hours: 1, minutes: 1));
      await expectLater(
          limiter.assertNotBlocked(accountId), completes);
    });
  });

  group('recordSuccess', () {
    test('clears the counter so future attempts start from zero', () async {
      // 9 failures (one shy of block)
      for (var i = 0; i < 9; i++) {
        await limiter.recordFailure(accountId);
      }
      await limiter.recordSuccess(accountId);

      final status = await limiter.recordFailure(accountId);
      expect(status.attempts, 1,
          reason: 'post-success failure counter resets to 1');
      expect(status.blocked, isFalse);
    });

    test('is a no-op when no counter exists for the account', () async {
      await expectLater(limiter.recordSuccess(accountId), completes);
    });
  });

  group('persistence', () {
    test('block survives limiter re-instantiation (same DB)', () async {
      for (var i = 0; i < AuthRateLimiter.maxAttempts; i++) {
        await limiter.recordFailure(accountId);
      }

      // New instance over the same DB helper -- simulates app restart.
      final limiter2 =
          AuthRateLimiter(testHelper.dbHelper, clock: () => now);
      final status = await limiter2.checkBlock(accountId);
      expect(status.blocked, isTrue);
    });

    test('per-account isolation', () async {
      const other = 'aol-someone.else@aol.com';
      for (var i = 0; i < AuthRateLimiter.maxAttempts; i++) {
        await limiter.recordFailure(accountId);
      }
      final thisStatus = await limiter.checkBlock(accountId);
      final otherStatus = await limiter.checkBlock(other);
      expect(thisStatus.blocked, isTrue);
      expect(otherStatus.blocked, isFalse);
      expect(otherStatus.attempts, 0);
    });
  });
}
