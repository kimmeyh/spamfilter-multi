/// Sprint 81 7.7.1 L-3: `hasValidImapUid` writes at most one diagnostic line
/// per context and folder per `kNoValidImapUidLogWindow`, so a server that
/// sends no UIDs for a large folder cannot rotate real events out of the log.
///
/// What these tests do NOT catch: the window itself is not advanced (it is
/// wall-clock time); the "N more skipped" text after a window is not
/// observed. They prove the repeat is suppressed, that a different folder or
/// context still writes, and that the gate still returns false every time.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/diagnostic_logger.dart';
import 'package:my_email_spam_filter/core/services/imap_uid.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('uid_log_window_');
    DiagnosticLogger.debugSetDir(tempDir.path);
    DiagnosticLogger.debugSetEnabled(true);
    debugResetNoValidImapUidLog();
  });

  tearDown(() async {
    DiagnosticLogger.debugSetDir(null);
    DiagnosticLogger.debugSetEnabled(null);
    debugResetNoValidImapUidLog();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<int> linesWritten() async {
    // The helper logs unawaited; give the writes time to land.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    var count = 0;
    await for (final entity in tempDir.list()) {
      if (entity is File) {
        count += 'no valid IMAP UID'
            .allMatches(await entity.readAsString())
            .length;
      }
    }
    return count;
  }

  test('500 marker messages in one folder and context write one line',
      () async {
    for (var i = 0; i < 500; i++) {
      expect(
          hasValidImapUid(kNoValidImapUid,
              folderName: 'Bulk', context: 'scan/persist-no-rule'),
          isFalse,
          reason: 'the gate must refuse the marker every time, logged or not');
    }
    expect(await linesWritten(), 1);
  });

  test('a different folder or context still writes its own line', () async {
    hasValidImapUid(kNoValidImapUid, folderName: 'Bulk', context: 'a');
    hasValidImapUid(kNoValidImapUid, folderName: 'Bulk', context: 'a');
    hasValidImapUid(kNoValidImapUid, folderName: 'Inbox', context: 'a');
    hasValidImapUid(kNoValidImapUid, folderName: 'Bulk', context: 'b');
    expect(await linesWritten(), 3);
  });

  test('a real UID passes and writes nothing', () async {
    expect(hasValidImapUid('42', folderName: 'Bulk', context: 'a'), isTrue);
    expect(await linesWritten(), 0);
  });
}
