import 'package:flutter_test/flutter_test.dart';

import '../../../scripts/repair_safe_sender_types.dart';
import 'package:my_email_spam_filter/core/storage/safe_sender_database_store.dart';

/// F123 (Sprint 50, Issue #281): safe-sender pattern_type repair.
///
/// The script cannot import SafeSenderDatabaseStore (Flutter import chain),
/// so it carries a MIRROR of determinePatternType. The first group pins the
/// mirror to the store implementation (F-PRECHECK class (a): mirror sync) --
/// if either side changes alone, this suite fails.
void main() {
  group('determinePatternTypeMirror == SafeSenderDatabaseStore (mirror sync)',
      () {
    const battery = [
      // The observed Harold row (0.5.6 validation): exact-email regex.
      r'^13prhks2302206@live\.com$',
      r'^13cxlcy2302206@live\.com$',
      // Entire-domain (subdomain wildcard) house pattern.
      r'^[^@\s]+@(?:[a-z0-9-]+\.)*trusted\.com$',
      // Exact-domain anchored regex (no wildcard).
      r'^[^@\s]+@olivegarden\.com$',
      // Plain (non-regex) forms.
      '@insightfinancialassociates.com',
      'user@example.com',
      // Edge cases.
      '',
      'no-at-sign-plain',
      r'.*\.xyz',
    ];

    for (final pattern in battery) {
      test('agree on ${pattern.isEmpty ? "<empty>" : pattern}', () {
        expect(determinePatternTypeMirror(pattern),
            SafeSenderDatabaseStore.determinePatternType(pattern));
      });
    }
  });

  group('computeSafeSenderTypeRepairs (F123)', () {
    Map<String, Object?> row(int id, String pattern, String type) =>
        {'id': id, 'pattern': pattern, 'pattern_type': type};

    test('the observed class: exact-email pattern stored as subdomain is '
        'repaired to email (AC-2)', () {
      final repairs = computeSafeSenderTypeRepairs([
        row(469, r'^13prhks2302206@live\.com$', 'subdomain'),
      ]);
      expect(repairs, hasLength(1));
      expect(repairs.single.to, 'email');
    });

    test('subdomain-wildcard pattern stored as domain is repaired to '
        'subdomain (the 297-row class)', () {
      final repairs = computeSafeSenderTypeRepairs([
        row(11, r'^[^@\s]+@(?:[a-z0-9-]+\.)*5hourenergy\.com$', 'domain'),
      ]);
      expect(repairs.single.to, 'subdomain');
    });

    test('consistent rows are untouched (AC-3)', () {
      final repairs = computeSafeSenderTypeRepairs([
        row(1, r'^[^@\s]+@(?:[a-z0-9-]+\.)*trusted\.com$', 'subdomain'),
        row(2, 'user@example.com', 'email'),
        row(3, '@example.com', 'domain'),
      ]);
      expect(repairs, isEmpty);
    });

    test("stored 'custom' is a user-explicit choice and never repaired", () {
      final repairs = computeSafeSenderTypeRepairs([
        row(5, r'^13prhks2302206@live\.com$', 'custom'),
      ]);
      expect(repairs, isEmpty);
    });

    test("a pattern recomputing to 'unknown' never degrades a labeled row",
        () {
      final repairs = computeSafeSenderTypeRepairs([
        row(6, 'no-at-sign-plain', 'domain'),
      ]);
      expect(repairs, isEmpty);
    });
  });
}
