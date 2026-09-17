import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/services/scan_coordinator.dart';

/// F220 (Sprint 70): backgrounding the app during a live scan wedged live
/// scanning until the app was restarted.
///
/// **Reported by Sean Jarvis (tester), 2026-09-17**: *"If doing a live scan and
/// putting app in background causes android to close network stack as intended
/// but livescan does not stop errors into a weird state where you cannot
/// livescan until app is restarted."*
///
/// **Why a restart was the ONLY escape.** Android tearing down an idle app's
/// sockets is correct OS behaviour. Nothing told the scan. It neither completed
/// nor failed, so `EmailScanner.scanInbox`'s `finally` never ran, so the
/// `ScanCoordinator` lease was never released -- and every later scan queued
/// FIFO behind a scan that could never finish. The coordinator is
/// process-global, so only a restart cleared it.
///
/// **The invariant these tests pin is the one that actually mattered**: a
/// released lease frees the coordinator for the next scan. The wedge was a held
/// lease, not a stalled socket -- so "does the next scan get through" is the
/// question, not "did the socket close".
void main() {
  setUp(ScanCoordinator.resetForTest);
  tearDown(ScanCoordinator.resetForTest);

  group('F220 lease release frees the coordinator', () {
    test('a released lease leaves the coordinator idle for the next scan',
        () async {
      final coordinator = ScanCoordinator.instance;

      final lease = await coordinator.acquire(
        scanType: 'manual',
        accountId: 'aol-test@example.com',
      );
      expect(coordinator.active, isNotNull,
          reason: 'a held lease must be visible as the active scan');

      coordinator.release(lease);

      expect(coordinator.active, isNull,
          reason: 'THIS is the wedge. If a lease is never released the '
              'coordinator stays occupied and every later scan queues behind '
              'a scan that will never finish.');

      // The real proof: the next scan acquires immediately rather than queueing.
      final next = await coordinator
          .acquire(scanType: 'manual', accountId: 'aol-test@example.com')
          .timeout(const Duration(seconds: 2));
      expect(next, isNotNull);
      coordinator.release(next);
    });

    test('an UNRELEASED lease blocks the next scan -- the defect itself',
        () async {
      // Pins the failure mode so the test suite documents what was wrong,
      // not only what is now right.
      final coordinator = ScanCoordinator.instance;

      await coordinator.acquire(
        scanType: 'manual',
        accountId: 'aol-test@example.com',
      );
      // Deliberately NOT released -- this is a scan wedged by backgrounding.

      // NOTE: the wait limit is passed to `acquire` as `waitLimit`, NOT
      // applied as an outer `Future.timeout`. An outer timeout fires on the
      // TEST's clock and would pass even if the coordinator granted the lease
      // immediately -- it would be proving that `Future.timeout` works. Using
      // the coordinator's own parameter means the TimeoutException can only
      // come from inside its queueing path.
      await expectLater(
        coordinator.acquire(
          scanType: 'manual',
          accountId: 'aol-test@example.com',
          waitLimit: const Duration(milliseconds: 300),
        ),
        throwsA(isA<TimeoutException>()),
        reason: 'with the lease still held the next scan cannot start -- '
            'exactly what the tester saw, and why only a restart helped',
      );
    });

    test('releasing by OWNER also frees the coordinator', () async {
      // The path a timeout uses. Owner-matched so a stale timeout cannot evict
      // a different live scan (Sprint 62 code review C-2).
      final coordinator = ScanCoordinator.instance;

      await coordinator.acquire(
        scanType: 'background',
        accountId: 'gmail-test@example.com',
      );
      expect(coordinator.active, isNotNull);

      coordinator.releaseActiveByOwner(
        scanType: 'background',
        accountId: 'gmail-test@example.com',
      );
      expect(coordinator.active, isNull);
    });

    test('releaseActiveByOwner does NOT evict a different scan', () async {
      final coordinator = ScanCoordinator.instance;

      await coordinator.acquire(
        scanType: 'manual',
        accountId: 'aol-test@example.com',
      );

      // A stale timeout for some OTHER scan must not free this one.
      coordinator.releaseActiveByOwner(
        scanType: 'background',
        accountId: 'gmail-test@example.com',
      );

      expect(coordinator.active, isNotNull,
          reason: 'owner-matching is what stops a timeout that fired for a '
              'queued scan from evicting the live one');
    });
  });

  group('F220 interrupted scan reports an actionable error', () {
    test('errorScan moves the provider out of scanning', () async {
      final provider = EmailScanProvider();
      provider.startScan(totalEmails: 10);
      expect(provider.status, ScanStatus.scanning);

      await provider.errorScan(
        'Scan stopped because the app was moved to the background.',
      );

      expect(provider.status, ScanStatus.error,
          reason: 'a scan left in `scanning` forever is what made Scan '
              'History untrustworthy');
      expect(provider.statusMessage, contains('background'),
          reason: 'the user must be told WHY it stopped -- a silent failure '
              'is what the tester actually experienced');
    });
  });
}
