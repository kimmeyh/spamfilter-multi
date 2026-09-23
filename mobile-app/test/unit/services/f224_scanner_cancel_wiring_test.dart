/// F224 (Sprint 73): the scanner side of cancellation.
///
/// **Why these are source assertions.** Driving `scanInbox` to a batch
/// boundary needs a live platform adapter, credentials and a database; the
/// existing scanner tests that do this are integration-shaped and slow. The
/// PROPERTIES that make cancellation correct are structural -- where the check
/// sits, and which catch blocks it is allowed to pass through -- so they are
/// pinned structurally, with each assertion naming the defect it prevents.
///
/// **What these do NOT catch** (CLAUDE.md IMP-1): they prove the check point
/// and the rethrow are PRESENT and correctly ordered. They cannot prove the
/// scan actually stops, that the IMAP session closed, or how long the stop
/// takes -- worst case is one m=20 batch, which only a device run measures.
/// See f224_scan_cancel_test.dart for the lease behaviour.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String scanner;

  setUpAll(() {
    scanner = File('lib/core/services/email_scanner.dart').readAsStringSync();
  });

  group('F224: the cooperative check point', () {
    test('THE CHECK: batchSink throws when a cancel is pending', () {
      expect(scanner.contains('ScanCoordinator.instance.isCancelRequested'),
          isTrue);
      expect(scanner.contains('throw const ScanCancelledException()'), isTrue);
    });

    test('it sits INSIDE batchSink, which every platform path feeds', () {
      // batchSink is the one funnel: the IMAP path streams into it via
      // onBatch, and Gmail/demo/mock are sliced through it below. A check
      // anywhere else would cover one platform and silently miss the others.
      final sinkIdx = scanner.indexOf('Future<void> batchSink(');
      final checkIdx =
          scanner.indexOf('ScanCoordinator.instance.isCancelRequested');
      final evalIdx = scanner.indexOf('await evaluateBatch(batch);');

      expect(sinkIdx, greaterThan(-1));
      expect(checkIdx, greaterThan(sinkIdx),
          reason: 'the check must be inside the sink');
      expect(checkIdx, lessThan(evalIdx),
          reason: 'check BEFORE evaluating -- a cancelled scan should not '
              'spend work on a batch it is about to discard');
    });

    test('the check precedes the progress counter', () {
      // Otherwise a cancelled batch would be counted as scanned, and the
      // partial count recorded at AC-4 would overstate what really happened.
      final checkIdx =
          scanner.indexOf('ScanCoordinator.instance.isCancelRequested');
      final countIdx = scanner.indexOf('folderCount += batch.length;');
      expect(checkIdx, lessThan(countIdx));
    });
  });

  group('F224: the exception must reach the teardown', () {
    test('THE DEFECT THIS PREVENTS: cancel escapes the per-folder catch', () {
      // The per-folder `catch (e, st)` logs a fetch failure, records it, and
      // CONTINUES to the next folder -- correct for a bad folder, and
      // catastrophic for a cancel, which would be swallowed, counted as a
      // folder error, and followed by scanning every remaining folder. The
      // button would appear to do nothing.
      final onCancel = scanner.indexOf('} on ScanCancelledException {');
      final genericCatch = scanner.indexOf('} catch (e, st) {');

      expect(onCancel, greaterThan(-1),
          reason: 'a typed handler must come before the generic catch');
      expect(onCancel, lessThan(genericCatch),
          reason: 'Dart matches catch clauses in order -- a generic catch '
              'placed first would swallow the cancellation');
      expect(scanner.contains('rethrow;'), isTrue);
    });

    test('AC-4: a cancel is recorded as cancelled, NOT as a failure', () {
      // errorScan hardcodes a "Scan failed: " prefix and files the row under
      // `error` beside real mail-server problems. Telling the user their own
      // deliberate action failed is the F228 class of lie.
      expect(scanner.contains('await scanProvider.cancelScan();'), isTrue);

      final cancelIdx = scanner.indexOf('await scanProvider.cancelScan();');
      final errorIdx = scanner.indexOf('await scanProvider.errorScan(msg);');
      expect(cancelIdx, lessThan(errorIdx),
          reason: 'the cancellation handler must be reached first');
    });

    test('the lease release and disconnect stay in the finally', () {
      // The whole design rests on this: cancellation adds NO teardown path,
      // because `finally` already runs on a throw. If either line ever leaves
      // the finally, a cancelled scan leaks its lease or its socket.
      final finallyIdx = scanner.indexOf('} finally {');
      final releaseIdx =
          scanner.indexOf('ScanCoordinator.instance.release(scanLease);');
      final disconnectIdx = scanner.indexOf('await platform.disconnect();');

      expect(finallyIdx, greaterThan(-1));
      expect(releaseIdx, greaterThan(finallyIdx));
      expect(disconnectIdx, greaterThan(finallyIdx));
    });
  });
}
