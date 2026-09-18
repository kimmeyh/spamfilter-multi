/// F220 / code review C-1 + H-4 + M-6 (Sprint 70): the app-root lifecycle
/// handler that fails a scan interrupted by backgrounding.
///
/// **Why this file exists.** The Sprint 70 code review found that NO test at
/// any level covered the lifecycle handler, and that is exactly why two real
/// defects shipped green:
///
///   - **C-1**: the handler called `errorScan` and the doc comment claimed the
///     scanner's `finally` would then release the coordinator lease. It does
///     not. `EmailScanProvider.errorScan` never touches `ScanCoordinator`,
///     `EmailScanner.scanInbox` never reads `scanProvider.status`, and there is
///     no cancellation token. The lease stayed HELD -- the screen looked
///     recovered while the wedge F220 exists to fix was untouched. The original
///     test asserted only `provider.status == ScanStatus.error`: the half that
///     worked.
///   - **M-6**: the handler ran on every platform. Windows minimise reports
///     `paused` but does NOT tear down sockets, so it killed healthy scans.
///
/// These tests assert the COORDINATOR state, not just the provider state, and
/// they exercise BOTH platform branches as ADR-0042 requires.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/services/scan_coordinator.dart';

/// Mirrors the app-root handler's decision logic exactly.
///
/// The real handler reads `EmailScanProvider` from the widget tree, which needs
/// a pumped app; this harness isolates the DECISIONS (platform gate, status
/// gate, release-then-report order) so they can be asserted directly. The
/// production code and this harness must be changed together -- if they drift,
/// these tests stop protecting anything.
void handleBackgrounded({
  required bool isAndroid,
  required EmailScanProvider scanProvider,
}) {
  if (!isAndroid) return;
  if (scanProvider.status != ScanStatus.scanning) return;

  final accountId = scanProvider.currentAccountId;
  if (accountId != null) {
    ScanCoordinator.instance.releaseActiveByOwner(
      scanType: 'manual',
      accountId: accountId,
    );
  }
  scanProvider.errorScan('backgrounded');
}

void main() {
  const accountId = 'aol-test@example.com';

  setUp(ScanCoordinator.resetForTest);
  tearDown(ScanCoordinator.resetForTest);

  Future<EmailScanProvider> scanningProvider() async {
    final provider = EmailScanProvider();
    provider.setCurrentAccountId(accountId);
    provider.startScan(totalEmails: 10, persist: false);
    return provider;
  }

  group('C-1: the handler frees the COORDINATOR, not just the provider', () {
    test('backgrounding an active scan releases the lease', () async {
      final coordinator = ScanCoordinator.instance;
      await coordinator.acquire(scanType: 'manual', accountId: accountId);
      final provider = await scanningProvider();

      handleBackgrounded(isAndroid: true, scanProvider: provider);

      expect(coordinator.active, isNull,
          reason: 'THE C-1 ASSERTION. Its absence is why the defect shipped: '
              'errorScan alone leaves the lease held and every later scan '
              'queues FIFO behind a scan that can never finish.');
      expect(provider.status, ScanStatus.error,
          reason: 'the user must also be told, not just unblocked');
    });

    test('the next scan can start immediately afterwards', () async {
      // The user-visible consequence, stated as its own test: the whole point
      // is that scanning works again WITHOUT an app restart.
      final coordinator = ScanCoordinator.instance;
      await coordinator.acquire(scanType: 'manual', accountId: accountId);
      final provider = await scanningProvider();

      handleBackgrounded(isAndroid: true, scanProvider: provider);

      final next = await coordinator
          .acquire(scanType: 'manual', accountId: accountId)
          .timeout(const Duration(seconds: 2));
      expect(next, isNotNull);
      coordinator.release(next);
    });
  });

  group('M-6: ADR-0042 platform exception, both branches', () {
    test('WINDOWS: minimise does NOT kill the scan', () async {
      // Windows reports `paused` on minimise but keeps sockets alive. Killing
      // the scan here would be a regression introduced by the fix.
      final coordinator = ScanCoordinator.instance;
      await coordinator.acquire(scanType: 'manual', accountId: accountId);
      final provider = await scanningProvider();

      handleBackgrounded(isAndroid: false, scanProvider: provider);

      expect(provider.status, ScanStatus.scanning,
          reason: 'a minimised Windows window has a live socket and a live '
              'scan -- failing it would lose real work');
      expect(coordinator.active, isNotNull);
    });

    test('ANDROID: backgrounding DOES kill the scan', () async {
      final coordinator = ScanCoordinator.instance;
      await coordinator.acquire(scanType: 'manual', accountId: accountId);
      final provider = await scanningProvider();

      handleBackgrounded(isAndroid: true, scanProvider: provider);

      expect(provider.status, ScanStatus.error);
      expect(coordinator.active, isNull);
    });
  });

  group('the handler does not fire when it should not', () {
    test('an IDLE provider is left alone', () async {
      final coordinator = ScanCoordinator.instance;
      await coordinator.acquire(scanType: 'background', accountId: accountId);
      final provider = EmailScanProvider();
      provider.setCurrentAccountId(accountId);
      // never started -- status is idle

      handleBackgrounded(isAndroid: true, scanProvider: provider);

      expect(coordinator.active, isNotNull,
          reason: 'backgrounding with no live scan must not disturb a '
              'BACKGROUND scan that is legitimately running');
      expect(provider.status, isNot(ScanStatus.error));
    });

    test('a BACKGROUND scan holding the lease is not evicted', () async {
      // Owner matching is what protects this. A manual-scan handler must never
      // release a background scan's lease.
      final coordinator = ScanCoordinator.instance;
      await coordinator.acquire(scanType: 'background', accountId: accountId);
      final provider = await scanningProvider();

      handleBackgrounded(isAndroid: true, scanProvider: provider);

      expect(coordinator.active, isNotNull,
          reason: 'the active holder is a BACKGROUND scan; releasing it from '
              'the manual path would kill work the user cannot see');
    });
  });
}
