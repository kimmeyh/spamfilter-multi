/// F233 (Sprint 72): exporting from a HISTORICAL scan view must write the rows
/// the user is looking at.
///
/// **The defect, confirmed from real device files.** Three of five CSVs pulled
/// off Harold's S24+ on 2026-09-21 were exactly 108 bytes -- the header row and
/// ZERO data rows -- while two had real rows. His observation named the cause:
/// *"The export may only be working if requested."* It is manual-only, fired by
/// the download icon, and it called `exportResultsToCSV()` with no argument, so
/// it read the PROVIDER's `_results` (the live session) while every DISPLAY
/// path on that screen selects `_historicalResults` when viewing a stored scan.
/// The export path was simply missing the historical branch the rest of the
/// screen already had, and it reported success regardless.
///
/// **What these tests do NOT catch** (CLAUDE.md IMP-1): they prove the provider
/// writes whatever rows it is handed, and that handing it none still yields a
/// header. They do NOT prove the SCREEN passes the right rows -- that wiring is
/// covered by the source assertion at the bottom, because driving the real
/// screen needs a live platform and a database.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/models/email_message.dart';
import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';

EmailActionResult _result(String id, String from) {
  return EmailActionResult(
    email: EmailMessage(
      id: id,
      from: from,
      subject: 'Subject $id',
      body: '',
      headers: const {},
      receivedDate: DateTime(2026, 9, 21, 12, 0),
      folderName: 'Inbox',
    ),
    action: EmailActionType.delete,
    success: true,
  );
}

void main() {
  group('F233: CSV export honours the rows it is given', () {
    test('THE BUG: historical rows must not produce a header-only file', () {
      final provider = EmailScanProvider();
      // The provider's own `_results` is EMPTY -- exactly the state when the
      // screen is showing a stored scan and no live scan ran this session.
      final historical = [
        _result('231203', 'a@example.com'),
        _result('231201', 'b@example.com'),
      ];

      final csv = provider.exportResultsToCSV(rows: historical);
      final lines = csv.trim().split('\n');

      expect(lines.length, 3,
          reason: 'THE ASSERTION THAT WAS MISSING: one header plus two data '
              'rows. Before the fix this produced a header alone -- the '
              '108-byte files pulled off the device.');
      expect(csv, contains('231203'));
      expect(csv, contains('a@example.com'));
    });

    test('an empty scan still yields a valid header', () {
      final provider = EmailScanProvider();
      final csv = provider.exportResultsToCSV(rows: const []);

      expect(csv.trim().split('\n'), hasLength(1),
          reason: 'a genuinely empty scan is not the same defect -- the header '
              'alone is correct when there is nothing to report');
      expect(csv, contains('Email ID'));
    });

    test('the app version is stamped when supplied (F229)', () {
      final provider = EmailScanProvider();
      final csv = provider.exportResultsToCSV(
        rows: [_result('1', 'x@example.com')],
        appVersion: '0.15.3',
      );

      expect(csv, contains('0.15.3'),
          reason: 'an export that cannot name the build that produced it is '
              'weak evidence, and this file is what a tester sends back');
      // The data rows must stay uniform for spreadsheet import.
      expect(csv, contains('"Scan Date"'));
    });

    test('no version row is written when none is supplied', () {
      final provider = EmailScanProvider();
      final csv = provider.exportResultsToCSV(rows: const []);

      expect(csv.contains('# MyEmailSpamFilter'), isFalse);
    });

    test('Email IDs survive export as bare integers', () {
      // Reading this column off the device is what FALSIFIED the F232 UID
      // hypothesis in one command. Keep it parseable.
      final provider = EmailScanProvider();
      final csv = provider.exportResultsToCSV(
        rows: [_result('231203', 'a@example.com')],
      );

      final dataLine =
          csv.trim().split('\n').last.replaceAll('"', '').split(',');
      expect(int.tryParse(dataLine.last), isNotNull,
          reason: 'a non-integer id here would have made the UID hypothesis '
              'unfalsifiable from an export');
    });
  });

  group('F233: the screen passes the displayed rows', () {
    test('_exportResults uses the same selector as every display path', () {
      final source =
          File('lib/ui/screens/results_display_screen.dart').readAsStringSync();

      expect(source.contains('rows: _currentResults()'), isTrue,
          reason: 'reusing the canonical selector is deliberate -- a second '
              'copy of that live-vs-historical logic is how the two drift '
              'apart again');
      expect(source.contains('exportResultsToCSV()'), isFalse,
          reason: 'the no-argument call is the defect; it must not return');
    });
  });
}
