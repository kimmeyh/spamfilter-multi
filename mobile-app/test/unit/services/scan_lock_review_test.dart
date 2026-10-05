/// Sprint 74 Manual Validation, Phase 5.1.1 review of the per-account scan
/// lock (Harold Q4: "scans cannot run forever").
///
/// Finding 1: a timeout force-released a scan's lease and closed its row, but
/// the scan kept running -- its cancel check read `_active`, which by then
/// belonged to the NEXT scan. The account lock was free while the old scan
/// still held its mail-server session.
///
/// Finding 2: a lock that could not be CHECKED (a database error) was mapped
/// to a background SKIP, which the workers count as success.
///
/// What these tests do NOT catch: the scanner actually reaching its next
/// batch boundary after a revoke (that needs a live, slow mail server), and
/// the revoked scan's skipped provider calls -- `scanInbox` cannot be driven
/// to a timeout without one. The coordinator half is proven here; the
/// scanner half is its source-level call site.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/background_scan_core.dart';
import 'package:my_email_spam_filter/core/services/scan_coordinator.dart';
import 'package:my_email_spam_filter/core/storage/scan_result_store.dart';

void main() {
  setUp(ScanCoordinator.resetForTest);

  group('finding 1 -- a force-released scan is told to stop', () {
    test('releaseActiveByOwner marks the released scan cancelled + revoked',
        () async {
      final c = ScanCoordinator.instance;
      final zombie =
          await c.acquire(scanType: 'manual', accountId: 'acct-a');
      c.releaseActiveByOwner(scanType: 'manual', accountId: 'acct-a');
      expect(zombie.info.cancelRequested, isTrue,
          reason: 'before the fix the released scan never saw a cancel');
      expect(zombie.info.revoked, isTrue);
      expect(() => c.throwIfCancelled(zombie),
          throwsA(isA<ScanCancelledException>()));
      expect(zombie.info.stopReason, 'timed out',
          reason: 'Sprint 76: the default reason is the timeout path');
    });

    test('Sprint 76: the stop reason is the FIRST one set -- a later revoke '
        'does not overwrite the user\'s stop', () async {
      // What this does NOT catch: a call site passing the wrong reason text;
      // the F220 and F238 texts are pinned by f220_lifecycle_handler_test
      // and f248_scan_diagnostic_log_test respectively.
      final c = ScanCoordinator.instance;
      final lease = await c.acquire(scanType: 'manual', accountId: 'acct-a');
      c.requestCancel(accountId: 'acct-a', reason: 'user tapped Stop');
      c.releaseActiveByOwner(
          scanType: 'manual',
          accountId: 'acct-a',
          reason: 'app moved to the background (F220)');
      expect(lease.info.stopReason, 'user tapped Stop');
    });

    test('the NEXT scan is not stopped by the old scan\'s cancel, and the old '
        'scan is stopped even though it is no longer active', () async {
      final c = ScanCoordinator.instance;
      final zombie =
          await c.acquire(scanType: 'manual', accountId: 'acct-a');
      final nextFuture = c.acquire(scanType: 'background', accountId: 'acct-a');
      c.releaseActiveByOwner(scanType: 'manual', accountId: 'acct-a');
      final next = await nextFuture;

      expect(identical(c.active, next.info), isTrue);
      expect(() => c.throwIfCancelled(next), returnsNormally,
          reason: 'the next scan must run');
      expect(() => c.throwIfCancelled(zombie),
          throwsA(isA<ScanCancelledException>()),
          reason: 'the unscoped check read the NEXT scan\'s flag, so the '
              'zombie could never stop');
    });

    test('a normal release does not revoke', () async {
      final c = ScanCoordinator.instance;
      final lease = await c.acquire(scanType: 'manual', accountId: 'acct-a');
      c.release(lease);
      expect(lease.info.revoked, isFalse);
      expect(lease.info.cancelRequested, isFalse);
    });

    test('the scanner checks ITS OWN lease and leaves the provider alone '
        'once revoked (source wiring)', () {
      final src =
          File('lib/core/services/email_scanner.dart').readAsStringSync();
      expect(src.contains('ScanCoordinator.instance.throwIfCancelled(scanLease)'),
          isTrue);
      expect(src.contains('if (scanLease.info.revoked) {'), isTrue,
          reason: 'completeScan must be skipped for a revoked scan');
      expect(
          RegExp(r'revoked != true\) \{\s+await scanProvider\.cancelScan\(\);')
              .hasMatch(src),
          isTrue);
      expect(
          RegExp(r'revoked != true\) \{\s+await scanProvider\.errorScan\(msg\);')
              .hasMatch(src),
          isTrue);
    });
  });

  group('finding 2 -- an unverifiable lock is a failure, not a skip', () {
    ScanResult holder() => ScanResult(
          accountId: 'acct-a',
          scanType: 'background',
          scanMode: 'readOnly',
          startedAt: 0,
          totalEmails: 0,
          status: 'in_progress',
        );

    test('held by another scan -> skip', () {
      expect(
          BackgroundScanCore.isSkipRefusal(ScanAccountBusyException(holder())),
          isTrue);
    });

    test('database error -> NOT a skip (rethrown, counted as a failure)', () {
      expect(
          BackgroundScanCore.isSkipRefusal(ScanAccountBusyException
              .unverifiable(Exception('database is locked (code 5)'))),
          isFalse);
    });

    test('the unverifiable exception still carries "database is locked" for '
        'the Windows worker retry', () {
      final e = ScanAccountBusyException.unverifiable(
          Exception('database is locked (code 5)'));
      expect(e.toString(), contains('database is locked'));
    });
  });
}
