/// F245 (Sprint 77, ADR-0045) prevention gate: `UnmatchedEmailStore.
/// upsertUnmatchedEmails` is the ONLY code that writes `unmatched_emails`.
///
/// A second writer would re-create the duplicate-row defect: the account-scoped
/// identity match lives in the upsert, and there is deliberately no UNIQUE
/// index to catch a bypass (Q18).
///
/// What this gate does NOT catch: a writer that builds its SQL from pieces so
/// the table name never appears next to `insert`, or a write through a raw
/// `execute`. It proves the plain shapes are gone; the behavior tests in
/// `test/unit/storage/f245_no_rule_upsert_test.dart` prove the helper works.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exactly one insert into unmatched_emails exists in lib/, inside the '
      'upsert helper', () {
    final insertCall =
        RegExp(r'''\.insert\(\s*['"]unmatched_emails['"]''');
    final insertSql = RegExp(
        r'INSERT\s+(OR\s+\w+\s+)?INTO\s+unmatched_emails',
        caseSensitive: false);

    final hits = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final text = f.readAsStringSync();
      for (final re in [insertCall, insertSql]) {
        for (final m in re.allMatches(text)) {
          hits.add('${f.path}:${text.substring(0, m.start).split('\n').length}');
        }
      }
    }

    expect(hits, hasLength(1), reason: 'found: $hits');
    expect(hits.single.replaceAll('\\', '/'),
        startsWith('lib/core/storage/unmatched_email_store.dart:'));

    // And that one insert sits inside upsertUnmatchedEmails.
    final store = File('lib/core/storage/unmatched_email_store.dart')
        .readAsStringSync();
    final start = store.indexOf('Future<List<UnmatchedUpsertResult>> '
        'upsertUnmatchedEmails(');
    expect(start, greaterThan(0));
    final insertAt = store.indexOf(insertCall.firstMatch(store)!.group(0)!);
    expect(insertAt, greaterThan(start));
    final nextMember = store.indexOf('  /// F245 (Sprint 77, Harold Q21)', start);
    expect(insertAt, lessThan(nextMember),
        reason: 'the insert must be inside the upsert helper');
  });
}
