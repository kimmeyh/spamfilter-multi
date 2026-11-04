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
import 'safe_miner_core.dart';
import 'reply_pair_core.dart';
import 'trash_miner_core.dart';

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
    if (env['RULE_MINER_MODE'] == 'replypairs') {
      // F270 R-4: the JSONL holds recipient addresses of Harold's Sent mail.
      final sentJsonl = env['RULE_MINER_SENT_JSONL'] ?? '';
      if (sentJsonl.isEmpty) {
        fail('replypairs mode needs RULE_MINER_SENT_JSONL (use rule_miner.ps1 -SentJsonl).');
      }
      final rr = await mineReplyPairs(readSentJsonl(sentJsonl), dbDir);
      final rreport = renderReplyPairReport(rr, showAddresses: env['RULE_MINER_SHOW_PHRASES'] == '1');
      writeOutput(outYaml, renderReplyPairYaml(rr));
      if (outReport.isNotEmpty) writeOutput(outReport, rreport);
      // ignore: avoid_print
      print('\n$rreport');
      return;
    }
    if (env['RULE_MINER_MODE'] == 'safe') {
      // F310 safe mode: the Trash2 JSONL is optional (extra delete-rule mail
      // with an unknown auth class); the history copy is the main input.
      final jsonl = env['RULE_MINER_TRASH_JSONL'] ?? '';
      final sr = await mineSafe(jsonl.isEmpty ? <TrashRecord>[] : readTrashJsonl(jsonl), dbDir);
      final sreport = renderSafeReport(sr, showDomains: env['RULE_MINER_SHOW_PHRASES'] == '1');
      writeSafeOutput(outYaml, renderSafeYaml(sr.reported));
      if (outReport.isNotEmpty) writeSafeOutput(outReport, sreport);
      // ignore: avoid_print
      print('\n$sreport');
      return;
    }
    if (env['RULE_MINER_MODE'] == 'trash2') {
      // F308 trash2 mode: the JSONL is private mail text read by the probe.
      final trashJsonl = env['RULE_MINER_TRASH_JSONL'] ?? '';
      if (trashJsonl.isEmpty) {
        fail('trash2 mode needs RULE_MINER_TRASH_JSONL (use rule_miner.ps1 -Trash2Jsonl).');
      }
      final tr = await mineTrash(readTrashJsonl(trashJsonl), dbDir);
      final treport = renderTrashReport(tr, showPhrases: env['RULE_MINER_SHOW_PHRASES'] == '1');
      writeTrashOutput(outYaml, renderTrashYaml([...tr.reported(tr.singles), ...tr.reported(tr.combos)]));
      if (outReport.isNotEmpty) writeTrashOutput(outReport, treport);
      // ignore: avoid_print
      print('\n$treport');
      return;
    }
    final result = await mine(dbDir);
    final report = renderMinerReport(result);
    writeOutput(outYaml, renderYaml(result.passed));
    if (outReport.isNotEmpty) writeOutput(outReport, report);
    // ignore: avoid_print
    print('\n$report');
  }, timeout: Timeout.none);
}
