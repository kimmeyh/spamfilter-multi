import 'package:flutter_test/flutter_test.dart';

import '../../../scripts/remove_ambiguous_tld_rules.dart';

/// F126 (Sprint 50, Issue #279): the selection matches ONLY the 4 legacy
/// ambiguous TLD-block body rows, by exact condition_body content; the
/// --apply gate (exactly kExpectedCount matches) is what makes the live run
/// abort-safe.
void main() {
  Map<String, Object?> row(int id, String name, String? body,
          {String category = 'body'}) =>
      {
        'id': id,
        'name': name,
        'condition_body': body,
        'pattern_category': category,
      };

  List<Map<String, Object?>> theFourRows() => [
        row(5865, r'/%\.nl/', r'["/%\\.nl/"]'),
        row(5866, r'/%\.ru/', r'["/%\\.ru/"]'),
        row(5867, r'/%\.store/', r'["/%\\.store/"]'),
        row(5868, r'/.*\.xyz', r'["/.*\\.xyz"]'),
      ];

  group('selectAmbiguousTldTargets (F126)', () {
    test('matches exactly the 4 legacy rows among decoys (AC-1, AC-4)', () {
      final rows = [
        // Decoys that a sloppy LIKE-match would catch:
        row(1, 'body_marmou.store', r'["(?:://|[/.])marmou\\.store"]'),
        row(2, 'tld_xyz', r'["\\.xyz$"]'),
        row(3, 'nl_exact', r'["/%\\.nl/x"]'), // superstring, not exact
        ...theFourRows(),
        // Same body but NOT body-category must not match:
        row(9, 'miscategorized', r'["/%\\.ru/"]', category: 'header_from'),
      ];
      final targets = selectAmbiguousTldTargets(rows);
      expect(targets.map((t) => t['id']),
          unorderedEquals([5865, 5866, 5867, 5868]));
    });

    test('the apply gate count is 4, so a partial match must abort (AC-4)',
        () {
      final threeOfFour = theFourRows().sublist(0, 3);
      final targets = selectAmbiguousTldTargets(threeOfFour);
      expect(targets.length, isNot(kExpectedCount),
          reason: 'main() aborts --apply when the selection differs from '
              'kExpectedCount; a 3-row match must trip that gate.');
    });

    test('post-apply state matches nothing -- idempotent re-run (AC-3)', () {
      final afterApply = [
        row(1, 'body_marmou.store', r'["(?:://|[/.])marmou\\.store"]'),
      ];
      expect(selectAmbiguousTldTargets(afterApply), isEmpty);
    });

    test('NULL condition_body rows are never selected', () {
      expect(selectAmbiguousTldTargets([row(7, 'null_body', null)]), isEmpty);
    });
  });
}
