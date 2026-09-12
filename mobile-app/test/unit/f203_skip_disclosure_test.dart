import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';

/// F203 (Sprint 69): "Found N, evaluated 0" was unexplainable.
///
/// `email_scanner.dart` skips safe-sender emails that already sit in the
/// safe-sender folder -- "do not count, do not display, do not process". That
/// is CORRECT: the mail is already where it belongs. But the skip was
/// invisible, so a scan could fetch 40 emails, skip all 40, and report finding
/// nothing.
///
/// The fix is DISCLOSURE, not recounting. These tests pin both halves of that:
/// the skip is counted somewhere the UI can read, and it is NOT laundered into
/// `processedCount`.
void main() {
  group('F203 skipped-already-filed disclosure', () {
    test('starts at zero', () {
      final p = EmailScanProvider();
      expect(p.skippedAlreadyFiledCount, 0);
    });

    test('recording a skip increments the disclosure counter', () {
      final p = EmailScanProvider();
      p.recordSkippedAlreadyFiled();
      p.recordSkippedAlreadyFiled();
      p.recordSkippedAlreadyFiled();
      expect(p.skippedAlreadyFiledCount, 3);
    });

    test('a skip does NOT count as Processed -- R-4, the whole point', () {
      // Inflating Processed would make the screen tidier and the number
      // dishonest. These emails genuinely were not processed.
      final p = EmailScanProvider();
      final before = p.processedCount;
      p.recordSkippedAlreadyFiled();
      p.recordSkippedAlreadyFiled();
      expect(p.processedCount, before,
          reason: 'skipped emails are disclosed, never reclassified');
    });

    test('a skip does not inflate the action counters either', () {
      final p = EmailScanProvider();
      p.recordSkippedAlreadyFiled();
      expect(p.deletedCount, 0);
      expect(p.movedCount, 0);
      expect(p.safeSendersCount, 0,
          reason: 'the email was NOT acted on as a safe sender -- it was '
              'already filed, which is why it was skipped');
      expect(p.noRuleCount, 0);
      expect(p.errorCount, 0);
    });

    test('reset clears the counter -- a stale count would misreport the next '
        'scan', () {
      final p = EmailScanProvider();
      p.recordSkippedAlreadyFiled();
      expect(p.skippedAlreadyFiledCount, 1);
      p.reset();
      expect(p.skippedAlreadyFiledCount, 0);
    });
  });
}
