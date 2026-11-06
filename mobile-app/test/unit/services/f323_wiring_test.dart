/// F323 (Sprint 83): call-site wiring read from source. Correct abstraction with
/// wrong wiring is a known defect class here (Sprint 73 IMP-3).
///
/// What these tests do NOT catch (one line each):
///   - that the closures behave: the fetcher, the pop-up cell and the rule
///     builders have behavior tests; this only proves the call sites pass them;
///   - a third caller of showEmailDetailPopup added later (the count gate below
///     fails then, so the new caller must be wired or listed).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _src(String p) => File(p).readAsStringSync();

void main() {
  final results = _src('lib/ui/screens/results_display_screen.dart');
  final review = _src('lib/ui/screens/no_rule_review_screen.dart');

  test('both pop-up callers pass a body loader and the safe-domain check', () {
    for (final s in [results, review]) {
      expect(s.contains('loadBody:'), isTrue);
      expect(s.contains('isSafeLinkDomain:'), isTrue);
    }
    expect(results.contains('PopupBodyFetcher()'), isTrue);
    expect(review.contains('PopupBodyFetcher()'), isTrue);
  });

  test('the Review screen rebuilds the message with the PROVIDER id', () {
    expect(review.contains('item.email.providerIdentifierValue'), isTrue);
    expect(review.contains("id: providerId"), isTrue);
  });

  test('only two files call showEmailDetailPopup', () {
    final callers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('showEmailDetailPopup('))
        .map((f) => f.path.replaceAll('\\', '/'))
        .where((p) => !p.endsWith('widgets/email_detail_popup.dart'))
        .toList()
      ..sort();
    expect(callers, [
      'lib/ui/screens/no_rule_review_screen.dart',
      'lib/ui/screens/results_display_screen.dart',
    ]);
  });

  test('both suggest() callers pass the per-method result', () {
    final scan = _src('lib/core/providers/email_scan_provider.dart');
    expect(scan.contains('authResult: AuthResultsParser.parse('), isTrue);
    expect(results.contains('authResult:'), isTrue);
  });

  // Sprint 83 7.7.1 pass-2 F7: the old name also claimed sender-shape rules.
  // They are sender rules (like Block Email), so they DO clear that sender's
  // conflicting safe-sender entry; only subject and body rules skip it.
  test('body rules never remove the sender safe senders', () {
    expect(results.contains("type != 'body'"), isTrue);
    expect(review.contains("request.type == 'body'"), isTrue);
    expect(results.contains("type != 'senderShape'"), isFalse);
    expect(review.contains("request.type == 'senderShape'"), isFalse);
  });
}
