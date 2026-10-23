/// F298 (Sprint 80, #496) prevention gate, extended at PR #490 7.7.1: every
/// screen in lib/ui/ that writes rules or safe senders straight to storage
/// also reloads RuleSetProvider.
///
/// F298 fixed five such screens by hand. The 7.7.1 silent-failure review then
/// found two more that the hand search missed, because they wrote with raw
/// `db.insert('rules', ...)` and `DefaultRuleSetService.resetToDefaults()`
/// rather than the store methods: Manual Rule Create and Settings > Reset to
/// Defaults. This gate lists every write shape so the next screen cannot be
/// missed the same way.
///
/// What this gate does NOT catch: it works per FILE, so a file with one
/// reloading write and a second, non-reloading write passes; a write through a
/// helper in lib/core/ that the screen calls under another name; and whether
/// the reload actually runs (the f298_*_test.dart widget tests prove that).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Shapes that write the `rules` or `safe_senders` tables.
final List<RegExp> _writeShapes = [
  RegExp(r'''\.(insert|update|delete)\(\s*['"](rules|safe_senders)['"]'''),
  RegExp(r'\.(addRule|updateRule|deleteRule|addSafeSender|removeSafeSender|'
      r'saveRules|saveSafeSenders|resetToDefaults)\('),
  RegExp(r'YamlImportMerge\.merge'),
];

/// Shapes that reload RuleSetProvider from the database.
final RegExp _reload = RegExp(r'reloadRulesAfterWrite\(|reloadFromDatabase\(');

/// Files that write without a local reload, each with the reason it is safe.
/// The test below re-checks every reason that can be checked.
const Map<String, String> _exempt = {
  'lib/ui/screens/no_rule_review_screen.dart':
      'writes through RuleQuickActionService, which reloads after the write',
  'lib/ui/screens/email_detail_view.dart':
      'unreachable: nothing in lib/ constructs EmailDetailView',
};

String _rel(File f) => f.path.replaceAll('\\', '/');

void main() {
  test('every lib/ui/ file that writes rules or safe senders reloads '
      'RuleSetProvider', () {
    final missing = <String>[];
    for (final f in Directory('lib/ui')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final text = f.readAsStringSync();
      final writes = _writeShapes.any((re) => re.hasMatch(text));
      if (!writes || _reload.hasMatch(text)) continue;
      if (_exempt.containsKey(_rel(f))) continue;
      missing.add(_rel(f));
    }
    expect(missing, isEmpty,
        reason: 'these screens write rules or safe senders and never reload '
            'RuleSetProvider (call reloadRulesAfterWrite after the write): '
            '$missing');
  });

  test('the exemptions still hold', () {
    for (final path in _exempt.keys) {
      expect(File(path).existsSync(), isTrue,
          reason: '$path is gone: remove its exemption');
    }

    // no_rule_review_screen writes only through RuleQuickActionService ...
    final review =
        File('lib/ui/screens/no_rule_review_screen.dart').readAsStringSync();
    expect(review.contains('RuleQuickActionService'), isTrue);
    // ... and that service reloads after both of its writes.
    final service = File('lib/core/services/rule_quick_action_service.dart')
        .readAsStringSync();
    expect(_reload.allMatches(service).length, greaterThanOrEqualTo(2));

    // email_detail_view is constructed nowhere else in lib/.
    final callers = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (_rel(f).endsWith('email_detail_view.dart')) continue;
      if (RegExp(r'\bEmailDetailView\(').hasMatch(f.readAsStringSync())) {
        callers.add(_rel(f));
      }
    }
    expect(callers, isEmpty,
        reason: 'EmailDetailView is now reachable from $callers: its two '
            'writes (addSafeSender, addRule) need reloadRulesAfterWrite and '
            'the exemption must go');
  });
}
