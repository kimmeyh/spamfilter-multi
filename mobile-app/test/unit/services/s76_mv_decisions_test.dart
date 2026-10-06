/// Sprint 76 Manual Validation decisions (Harold, 2026-10-05: "q1 1 q2 1 q3 2
/// ... q4 fix all 5"): the pure rules behind each fix, plus a real
/// multi-isolate test of the diagnostic log's locked append.
///
/// What this does NOT catch: Gmail accepting the new label change and Google
/// accepting the Android refresh (both need the live services -- Fold
/// validation); WorkManager's KEEP behavior (device; pinned by a source gate in
/// f252_worker_trigger_line_test); whether Android shared storage honors file
/// locks (the append falls back to a single unlocked write there).
library;

import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/adapters/auth/google_auth_service.dart';
import 'package:my_email_spam_filter/adapters/email_providers/gmail_api_adapter.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart'
    show ScanStatus;
import 'package:my_email_spam_filter/core/services/background_scan_core.dart';
import 'package:my_email_spam_filter/core/services/diagnostic_logger.dart';
import 'package:my_email_spam_filter/core/services/email_scanner.dart';
import 'package:my_email_spam_filter/ui/screens/scan_progress_screen.dart';

void main() {
  group('Q4.1 Gmail move labels', () {
    test('a safe-sender rescue from Spam adds INBOX and removes SPAM, never '
        'both adding and removing INBOX', () {
      final l = GmailApiAdapter.moveLabels(
          sourceFolder: 'SPAM', targetFolder: 'INBOX');
      expect(l.add, ['INBOX']);
      expect(l.remove, containsAll(['SPAM', 'UNREAD']));
      expect(l.remove, isNot(contains('INBOX')),
          reason: 'Gmail 400: Cannot both add and remove the same label');
    });

    test('a move out of the Inbox to another label keeps the old behavior', () {
      final l = GmailApiAdapter.moveLabels(
          sourceFolder: 'INBOX', targetFolder: 'Label_9');
      expect(l.add, ['Label_9']);
      expect(l.remove.toSet(), {'INBOX', 'UNREAD'});
    });

    test('a custom-label source is not removed by name', () {
      final l = GmailApiAdapter.moveLabels(
          sourceFolder: 'Unwanted', targetFolder: 'INBOX');
      expect(l.remove, isNot(contains('Unwanted')));
      expect(l.remove, isNot(contains('INBOX')));
    });
  });

  group('Gmail incremental fetch resolves a custom label to its ID', () {
    test('system labels pass through; a custom label name does not', () {
      for (final id in ['INBOX', 'SPAM', 'TRASH', 'CATEGORY_PROMOTIONS']) {
        expect(GmailApiAdapter.isSystemLabelId(id), isTrue, reason: id);
      }
      for (final name in ['Unwanted', 'SPAMFILTER', 'Label_123']) {
        expect(GmailApiAdapter.isSystemLabelId(name), isFalse, reason: name);
      }
    });

    test('history.list is given the resolved ID, not the folder name', () {
      // SOURCE-TEXT VERIFIED: the call needs a live Gmail API; the 0.17.4 Fold
      // log showed 400 "Invalid label value in query" for "Unwanted".
      final src = File('lib/adapters/email_providers/gmail_api_adapter.dart')
          .readAsStringSync();
      expect(src.contains('final labelId = await _labelIdFor(folderForLabel);'),
          isTrue);
      expect(src.contains('labelId: folderForLabel,'), isFalse);
    });
  });

  group('Q4.2 a scan that fetched nothing', () {
    test('every existing folder failed -> nothing fetched', () {
      expect(scanFetchedNothing(folders: 3, missing: 0, failed: 3), isTrue);
      expect(scanFetchedNothing(folders: 3, missing: 1, failed: 2), isTrue);
    });
    test('a partial failure, or only missing folders, is not "nothing"', () {
      expect(scanFetchedNothing(folders: 3, missing: 0, failed: 2), isFalse);
      expect(scanFetchedNothing(folders: 2, missing: 2, failed: 0), isFalse);
      expect(scanFetchedNothing(folders: 3, missing: 0, failed: 0), isFalse);
    });
  });

  group('Q4.3 the diagnostic log append is whole lines across isolates', () {
    test('four isolates appending at once leave no fragment', () async {
      final dir = await Directory.systemTemp.createTemp('s76_lock_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}diag.log';
      await Future.wait([
        for (var w = 0; w < 4; w++)
          Isolate.run(() async {
            final f = File(path);
            for (var i = 0; i < 150; i++) {
              await DiagnosticLogger.appendLocked(
                  f, '[w$w] line $i ${'x' * 200}\n');
            }
          }),
      ]);
      final lines = File(path).readAsLinesSync();
      expect(lines.length, 600);
      final whole = RegExp(r'^\[w[0-3]\] line \d+ x{200}$');
      expect(lines.where((l) => !whole.hasMatch(l)), isEmpty,
          reason: 'the 0.17.2 Fold log had fragments such as a lone "m"');
      expect(File('$path.lock').existsSync(), isFalse,
          reason: 'the mutex is released after every line');
    });

    test('a stale lock left by a dead writer is broken and the line written',
        () async {
      final dir = await Directory.systemTemp.createTemp('s76_stale_');
      addTearDown(() => dir.delete(recursive: true));
      final log = File('${dir.path}${Platform.pathSeparator}diag.log');
      final lock = File('${log.path}.lock')..createSync();
      lock.setLastModifiedSync(DateTime.now().subtract(const Duration(minutes: 1)));
      final savedWait = DiagnosticLogger.lockWait;
      DiagnosticLogger.lockWait = const Duration(milliseconds: 50);
      addTearDown(() => DiagnosticLogger.lockWait = savedWait);

      await DiagnosticLogger.appendLocked(log, 'after a crash\n');
      expect(log.readAsStringSync(), 'after a crash\n');
      expect(lock.existsSync(), isFalse);
    });

    test('a lock held by a live writer delays, but never loses, the line',
        () async {
      final dir = await Directory.systemTemp.createTemp('s76_held_');
      addTearDown(() => dir.delete(recursive: true));
      final log = File('${dir.path}${Platform.pathSeparator}diag.log');
      final lock = File('${log.path}.lock')..createSync(); // fresh: not stale
      final savedWait = DiagnosticLogger.lockWait;
      DiagnosticLogger.lockWait = const Duration(milliseconds: 50);
      addTearDown(() => DiagnosticLogger.lockWait = savedWait);

      await DiagnosticLogger.appendLocked(log, 'still written\n');
      expect(log.readAsStringSync(), 'still written\n');
      expect(lock.existsSync(), isTrue,
          reason: 'another writer\'s live lock is not deleted');
    });
  });

  group('Q4.4 the progress screen does not reset a running scan', () {
    test('running and paused scans are left alone', () {
      expect(shouldResetScanState(ScanStatus.scanning), isFalse);
      expect(shouldResetScanState(ScanStatus.paused), isFalse);
    });
    test('finished and idle scans reset as before', () {
      expect(shouldResetScanState(ScanStatus.completed), isTrue);
      expect(shouldResetScanState(ScanStatus.idle), isTrue);
      expect(shouldResetScanState(ScanStatus.error), isTrue);
    });
    test('both reset sites use the rule', () {
      // SOURCE-TEXT VERIFIED: initState's post-frame callback and the
      // RouteAware didPopNext need a navigator; the gate pins both guards.
      final src =
          File('lib/ui/screens/scan_progress_screen.dart').readAsStringSync();
      expect(
          'if (shouldResetScanState(scanProvider.status)) scanProvider.reset();'
              .allMatches(src)
              .length,
          2);
      expect(RegExp(r'^\s*scanProvider\.reset\(\);', multiLine: true)
          .hasMatch(src), isFalse,
          reason: 'no unguarded reset left');
    });
  });

  group('Q2 Android renewal falls back to the stored refresh token', () {
    test('only after native renewal failed, on Android, with a token', () {
      expect(
          GoogleAuthService.shouldTryStoredRefreshToken(
              nativeSucceeded: false, isAndroid: true, hasRefreshToken: true),
          isTrue);
      expect(
          GoogleAuthService.shouldTryStoredRefreshToken(
              nativeSucceeded: true, isAndroid: true, hasRefreshToken: true),
          isFalse);
      expect(
          GoogleAuthService.shouldTryStoredRefreshToken(
              nativeSucceeded: false, isAndroid: false, hasRefreshToken: true),
          isFalse,
          reason: 'desktop has its own HTTP refresh path');
      expect(
          GoogleAuthService.shouldTryStoredRefreshToken(
              nativeSucceeded: false, isAndroid: true, hasRefreshToken: false),
          isFalse);
    });

    test('the mobile refresh uses the Android client, not the desktop one', () {
      // SOURCE-TEXT VERIFIED: AppAuth's token call needs a device.
      final src = File(
              'lib/adapters/email_providers/gmail_windows_oauth_handler.dart')
          .readAsStringSync();
      final start = src.indexOf('static Future<String> refreshAccessTokenMobile');
      final end = src.indexOf('static Future<String> refreshAccessToken(', start);
      final body = src.substring(start, end);
      expect(body.contains('_androidClientId'), isTrue);
      expect(body.contains('_clientSecret'), isFalse);
      expect(body.contains('refreshToken: refreshToken'), isTrue);
    });
  });

  group('Q3 five-minute spacing, never a skip', () {
    final now = DateTime(2026, 10, 5, 12, 0, 0);
    test('a scan 2 minutes after the last one waits the other 3', () {
      expect(
          BackgroundScanCore.spacingWaitFor(
              lastCompletedAt: now.subtract(const Duration(minutes: 2)),
              now: now),
          const Duration(minutes: 3));
    });
    test('no wait after 5 minutes, with no history, or a future timestamp', () {
      expect(
          BackgroundScanCore.spacingWaitFor(
              lastCompletedAt: now.subtract(const Duration(minutes: 5)),
              now: now),
          Duration.zero);
      expect(BackgroundScanCore.spacingWaitFor(lastCompletedAt: null, now: now),
          Duration.zero);
      expect(
          BackgroundScanCore.spacingWaitFor(
              lastCompletedAt: now.add(const Duration(minutes: 1)), now: now),
          Duration.zero);
    });
    test('spacing plus busy retry never exceeds 6 minutes', () {
      expect(
          BackgroundScanCore.cappedBusyWait(const Duration(minutes: 5),
              alreadyWaited: const Duration(minutes: 4)),
          const Duration(minutes: 2));
      expect(
          BackgroundScanCore.cappedBusyWait(const Duration(minutes: 3),
              alreadyWaited: Duration.zero),
          const Duration(minutes: 3));
      expect(
          BackgroundScanCore.cappedBusyWait(const Duration(minutes: 3),
              alreadyWaited: const Duration(minutes: 6)),
          Duration.zero);
    });
  });
}
