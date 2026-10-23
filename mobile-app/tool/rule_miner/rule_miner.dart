/// F268 entry point. Run through the wrapper:
///
///   powershell -NoProfile -File tool\rule_miner\rule_miner.ps1 -DbDir <copy folder> -OutYaml <file>
///
/// A `test()` for the same reason as tool/rule_eval/rule_eval.dart: the engine
/// imports Flutter, so `flutter test` hosts it. Inputs arrive as environment
/// variables: RULE_MINER_DB_DIR, RULE_MINER_OUT_YAML, RULE_MINER_OUT_REPORT
/// (optional).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../rule_eval/rule_eval_core.dart';
import 'rule_miner_core.dart';

void main() {
  test('rule_miner', () async {
    sqfliteFfiInit();
    final env = Platform.environment;
    final dbDir = env['RULE_MINER_DB_DIR'];
    final outYaml = env['RULE_MINER_OUT_YAML'];
    if (dbDir == null || outYaml == null || outYaml.isEmpty) {
      fail('Set RULE_MINER_DB_DIR and RULE_MINER_OUT_YAML (use rule_miner.ps1).');
    }
    final outReport = env['RULE_MINER_OUT_REPORT'] ?? '';
    for (final path in [dbDir, outYaml, if (outReport.isNotEmpty) outReport]) {
      final refusal = liveDatabaseRefusal(path);
      if (refusal != null) {
        // ignore: avoid_print
        print(refusal);
        fail(refusal);
      }
    }
    final result = await mine(dbDir);
    final report = renderMinerReport(result);
    writeOutput(outYaml, renderYaml(result.passed));
    if (outReport.isNotEmpty) writeOutput(outReport, report);
    // ignore: avoid_print
    print('\n$report');
  }, timeout: Timeout.none);
}
