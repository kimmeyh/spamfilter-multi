// Sprint 85 Phase 5.2: a queued DiagnosticLogger write picks its folder when it
// RUNS, not when the line is logged. Tests that reset the folder with
// `debugSetDir(null)` in tearDown let lines from one test land in the NEXT
// test's temp folder (about 90 `f259_diag_*` folders were left in %TEMP%), and
// a test could start with another test's writes still queued ahead of its own.
// The full suite at 33f9d420 failed `f259_gmail_label_cursor_test` "the other
// callers of the lookup" with an empty log; the test passes alone.
//
// Prevention: tests reset with `await DiagnosticLogger.debugReset()`, which
// waits for the queue first. This gate has two halves:
//   1. source: no test calls `debugSetDir(null)` (use debugReset instead);
//   2. behavior: debugReset really waits, so no queued line reaches the
//      folder set after it.
//
// What this does NOT catch: a test that never resets at all (its queued lines
// still go wherever the next test points the logger), or production code that
// changes the export folder while lines are queued (they go to the new folder;
// harmless, and not what these tests are about). It also does not prove that
// the f259 empty-log failure had this cause: that run's own lines were not
// kept, so the cause of that one failure is still unproven.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/diagnostic_logger.dart';
import 'package:path/path.dart' as p;

String _readAll(Directory d) => d.existsSync()
    ? d
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.log'))
        .map((f) => f.readAsStringSync())
        .join()
    : '';

void main() {
  test('no test resets the diagnostic log folder with debugSetDir(null)', () {
    final offenders = <String>[];
    for (final f in Directory('test').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final rel = p.relative(f.path, from: 'test').replaceAll(r'\', '/');
      if (rel == 'policy/diagnostic_logger_reset_test.dart') continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('DiagnosticLogger.debugSetDir(null)')) {
          offenders.add('$rel:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Reset with `await DiagnosticLogger.debugReset();` in an async '
            'tearDown. debugSetDir(null) does not wait for queued writes, so '
            'they land in the next test\'s folder.');
  });

  test('tests read the log folder through readDiagnosticLog', () {
    // A hand-rolled reader lists the writer's transient `.lock` file and fails
    // when the writer deletes it before the read.
    const exempt = {
      'policy/diagnostic_logger_reset_test.dart',
      // Tests the logger's own files (rotation, .bak); awaits every write.
      'unit/services/diagnostic_logger_test.dart',
    };
    final handRolled = RegExp(r'(listSync\(|\.list\(\))[\s\S]{0,200}readAsString');
    final offenders = <String>[];
    for (final f in Directory('test').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final rel = p.relative(f.path, from: 'test').replaceAll(r'\', '/');
      if (exempt.contains(rel)) continue;
      final src = f.readAsStringSync();
      if (src.contains('DiagnosticLogger.debugSetDir(') &&
          handRolled.hasMatch(src)) {
        offenders.add(rel);
      }
    }
    expect(offenders, isEmpty,
        reason: 'Read the diagnostic log folder with readDiagnosticLog() from '
            'test/helpers/diagnostic_log_reader.dart.');
  });

  test('debugReset waits for queued writes before the folder changes', () async {
    final a = Directory.systemTemp.createTempSync('diag_reset_a_');
    final b = Directory.systemTemp.createTempSync('diag_reset_b_');
    addTearDown(() async {
      await DiagnosticLogger.debugReset();
      for (final d in [a, b]) {
        if (d.existsSync()) d.deleteSync(recursive: true);
      }
    });

    DiagnosticLogger.debugSetEnabled(true);
    DiagnosticLogger.debugSetDir(a.path);
    // Queue lines WITHOUT awaiting them, as fire-and-forget callers do.
    for (var i = 0; i < 30; i++) {
      unawaited(DiagnosticLogger.appEvent('reset-probe line $i'));
    }
    await DiagnosticLogger.debugReset();

    DiagnosticLogger.debugSetEnabled(true);
    DiagnosticLogger.debugSetDir(b.path);
    await DiagnosticLogger.appEvent('after reset');

    final inA = _readAll(a);
    final inB = _readAll(b);
    expect(RegExp('reset-probe line').allMatches(inA).length, 30,
        reason: 'every line queued before debugReset is written to folder A');
    expect(inB, isNot(contains('reset-probe')),
        reason: 'no line queued before debugReset may land in the folder set '
            'after it');
    expect(inB, contains('after reset'));
  });
}
