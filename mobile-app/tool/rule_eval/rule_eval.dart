/// F267 entry point. Run through the wrapper:
///
///   powershell -NoProfile -File tool\rule_eval\rule_eval.ps1 -Candidate <yaml> -DbDir <copy folder>
///
/// Why this is a `test()` and not a plain `dart run` main: the app's engine
/// imports `package:flutter/foundation.dart` (through `redact.dart`), which
/// needs `dart:ui`, so `dart run` fails to compile it. `flutter test` hosts
/// the unchanged engine. Inputs arrive as environment variables set by the
/// wrapper: RULE_EVAL_CANDIDATE, RULE_EVAL_DB_DIR, RULE_EVAL_OUT (optional).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'rule_eval_core.dart';

void main() {
  test('rule_eval', () async {
    sqfliteFfiInit();
    final env = Platform.environment;
    final candidate = env['RULE_EVAL_CANDIDATE'];
    final dbDir = env['RULE_EVAL_DB_DIR'];
    if (candidate == null || dbDir == null) {
      fail('Set RULE_EVAL_CANDIDATE and RULE_EVAL_DB_DIR (use rule_eval.ps1).');
    }
    final refusal = liveDatabaseRefusal(dbDir);
    if (refusal != null) {
      // ignore: avoid_print
      print(refusal);
      fail(refusal);
    }
    final history = await loadHistory(dbDir);
    final report = renderReport(history, await scoreCandidates(loadCandidates(candidate), history));
    // ignore: avoid_print
    print('\n$report');
    final out = env['RULE_EVAL_OUT'];
    if (out != null && out.isNotEmpty) {
      File(out).writeAsStringSync(report);
    }
  }, timeout: Timeout.none);
}
