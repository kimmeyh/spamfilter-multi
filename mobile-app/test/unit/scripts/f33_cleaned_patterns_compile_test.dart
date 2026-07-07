import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/pattern_compiler.dart';

/// F33 (Sprint 46): safety net verifying that EVERY body-rule pattern in the
/// cleaned dev DB (1) is a valid Dart RegExp and (2) passes the ReDoS guard,
/// so none of the 648 F33-converted URL-anchored patterns silently became an
/// invalid / never-matching / rejected pattern after the cleanup.
///
/// Reads a snapshot exported from the dev DB post-apply. The snapshot path is
/// the scratchpad export produced during F33 verification; if it is absent
/// (e.g. on CI where the dev DB does not exist) the test skips rather than
/// fails, so it is a local-verification aid, not a CI gate.
void main() {
  const snapshotPath =
      r'C:\Users\kimme\AppData\Local\Temp\claude\D--Data-Harold-github-spamfilter-multi\1ca36477-c303-4cb2-b4f7-d2b2b2e720ce\scratchpad\cleaned_body_patterns.txt';

  test('all cleaned body-rule patterns compile and pass the ReDoS guard', () {
    final file = File(snapshotPath);
    if (!file.existsSync()) {
      markTestSkipped('Cleaned-pattern snapshot not present ($snapshotPath) '
          '-- run the F33 export first. Skipping (local-only verification).');
      return;
    }

    final lines = file.readAsLinesSync();
    final invalid = <String>[];
    final redos = <String>[];
    var total = 0;
    var urlAnchored = 0;

    for (final raw in lines) {
      if (raw.trim().isEmpty) continue;
      List<String> pats;
      try {
        pats = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
      } catch (e) {
        invalid.add('JSON-FAIL: $raw ($e)');
        continue;
      }
      for (final p in pats) {
        total++;
        if (p.contains('(?:://|[/.])')) urlAnchored++;
        try {
          RegExp(p);
        } catch (e) {
          invalid.add('REGEX-FAIL: $p ($e)');
          continue;
        }
        final warnings = PatternCompiler.detectReDoS(p);
        if (warnings.isNotEmpty) redos.add('REDOS: $p -> ${warnings.first}');
      }
    }

    // ignore: avoid_print
    print('F33 cleaned patterns checked: $total '
        '(URL-anchored: $urlAnchored, invalid: ${invalid.length}, '
        'redos: ${redos.length})');

    expect(invalid, isEmpty,
        reason: 'Cleaned patterns must all be valid RegExps:\n'
            '${invalid.take(10).join("\n")}');
    expect(redos, isEmpty,
        reason: 'Cleaned patterns must all pass the ReDoS guard:\n'
            '${redos.take(10).join("\n")}');
    expect(total, greaterThan(0));
  });
}
