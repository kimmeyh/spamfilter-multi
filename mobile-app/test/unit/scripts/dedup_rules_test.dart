import 'package:flutter_test/flutter_test.dart';

import '../../../scripts/dedup_rules.dart';

/// F121 (Sprint 49): dedup analyzer -- groups rules by full functional
/// content, keeps the lowest id per group, removes the rest. Comparison is on
/// RAW column strings (no JSON decode -- an undecodable condition can never be
/// misclassified; BUG-DECODE discipline).
void main() {
  Map<String, Object?> row(int id,
          {String? header,
          String? body,
          int enabled = 1,
          int actionDelete = 1,
          int order = 30}) =>
      {
        'id': id,
        'enabled': enabled,
        'is_local': 1,
        'execution_order': order,
        'condition_type': 'OR',
        'condition_from': null,
        'condition_header': header,
        'condition_subject': null,
        'condition_body': body,
        'action_delete': actionDelete,
        'action_move_to_folder': null,
        'action_assign_category': null,
        'exception_from': null,
        'exception_header': null,
        'exception_subject': null,
        'exception_body': null,
        'pattern_category': header != null ? 'header_from' : 'body',
        'pattern_sub_type': 'entire_domain',
        'source_domain': 'x.com',
      };

  group('analyzeDuplicates (F121)', () {
    test('content-identical rules dedup to the lowest id (the _2/_3 '
        'triple-import class)', () {
      final a = analyzeDuplicates([
        row(10, header: r'["@x\\.com$"]'),
        row(25, header: r'["@x\\.com$"]'), // the _2 copy
        row(31, header: r'["@x\\.com$"]'), // the _3 copy
      ]);
      expect(a.keeperIds, [10]);
      expect(a.removalIds, unorderedEquals([25, 31]));
      expect(a.keeperIds.length + a.removalIds.length, a.total);
    });

    test('differing ACTION is not a duplicate', () {
      final a = analyzeDuplicates([
        row(1, header: r'["@x\\.com$"]', actionDelete: 1),
        row(2, header: r'["@x\\.com$"]', actionDelete: 0),
      ]);
      expect(a.removalIds, isEmpty);
    });

    test('differing enabled/order is not a duplicate', () {
      final a = analyzeDuplicates([
        row(1, header: r'["@x\\.com$"]', enabled: 1),
        row(2, header: r'["@x\\.com$"]', enabled: 0),
        row(3, header: r'["@x\\.com$"]', order: 40),
      ]);
      expect(a.removalIds, isEmpty);
    });

    test('undecodable condition_body is compared as a raw string -- '
        'identical garbage dedups, distinct garbage survives', () {
      final a = analyzeDuplicates([
        row(1, body: '[not valid json'),
        row(2, body: '[not valid json'),
        row(3, body: '[different garbage'),
      ]);
      expect(a.keeperIds, unorderedEquals([1, 3]));
      expect(a.removalIds, [2]);
    });

    test('reconciliation always holds: keepers + removals == total', () {
      final a = analyzeDuplicates([
        for (var i = 1; i <= 9; i++)
          row(i, header: '["@dom${i % 3}.com\$"]'),
      ]);
      expect(a.keeperIds.length + a.removalIds.length, a.total);
      expect(a.keeperIds.length, 3);
      expect(a.removalIds.length, 6);
    });
  });
}
