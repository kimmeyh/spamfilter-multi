/// Sprint 78 7.7.1 (Copilot, two comments; silent-failure L-1): two comments
/// in the deletion paths named their prevention gate
/// `f283_r7_deletion_coverage_test` -- a test that never existed. The real
/// gate is `r76_4_content_history_policy_test` (group "R7"). A comment that
/// names a missing gate tells the next reader the path is guarded and sends
/// them looking for nothing (CLAUDE.md, Sprint 70 IMP-2: verify the mechanism
/// a comment asserts).
///
/// This gate: every BACKTICKED test name in a `lib/` comment
/// (`` `name_test` `` or `` `name_test.dart` ``) must exist as a file under
/// `test/`.
///
/// SOURCE-TEXT VERIFIED: this test reads `lib/` and `test/` file names on
/// purpose; it guards a citation, not behavior.
///
/// What this does NOT catch: a test cited without backticks, a citation of
/// the right file with a wrong group name, or a test that exists but no longer
/// checks what the comment says.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Backticked names that are not test files, each with a reason.
const _notTestFiles = <String, String>{
  'integration_test': 'the Flutter integration_test package and directory',
};

void main() {
  final cite = RegExp(r'`([a-z0-9_]+_test)(?:\.dart)?`');

  test('the matcher self-checks', () {
    expect(cite.firstMatch('// prevention: `foo_bar_test` fails')?.group(1),
        'foo_bar_test');
    expect(cite.firstMatch('// see `foo_test.dart`')?.group(1), 'foo_test');
    expect(cite.hasMatch('// the rule_test screen'), isFalse);
  });

  test('every backticked test cited in a lib/ comment exists under test/', () {
    expect(Directory('lib').existsSync(), isTrue,
        reason: 'run this test from the mobile-app/ directory');
    final testNames = <String>{
      for (final f in Directory('test').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart'))
          f.uri.pathSegments.last.replaceAll('.dart', ''),
    };
    final missing = <String>[];
    var cited = 0;
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final s = lines[i].trimLeft();
        if (!(s.startsWith('//') || s.startsWith('*'))) continue;
        for (final m in cite.allMatches(s)) {
          final name = m.group(1)!;
          if (_notTestFiles.containsKey(name)) continue;
          cited++;
          if (!testNames.contains(name)) {
            missing.add('${f.path}:${i + 1} cites `$name`, which does not '
                'exist under test/');
          }
        }
      }
    }
    expect(cited, greaterThan(0),
        reason: 'no citation found at all -- the matcher or the scan is broken');
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}
