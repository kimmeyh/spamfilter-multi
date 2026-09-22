/// F233 (Sprint 72): the diagnostic log must be REACHABLE from Settings.
///
/// **This file exists because manual validation found the UI missing
/// entirely.** The logger, the settings keys, the rotation and the delete
/// function all shipped. There was no toggle, so the log could never be
/// enabled, so it could never write a single line. Harold opened Settings,
/// found nothing, and asked "where".
///
/// **Why the existing tests did not catch it.** They set the enabled flag
/// through `DiagnosticLogger.debugSetEnabled` -- the test seam -- and asserted
/// the logger behaved. Every one passed. None of them went through the path a
/// user has: Settings. That is the repo's own source-gate lesson almost
/// verbatim: proving a symbol EXISTS is not proving the feature WORKS.
///
/// **What these tests do NOT catch** (CLAUDE.md IMP-1): they assert the
/// controls are wired into the Settings source and that the persistence round
/// trips. They do not mount the Settings screen -- it needs a database and
/// several providers -- so they cannot prove the controls RENDER. The keys are
/// here so a future widget test can find them, and manual validation is what
/// confirms they appear.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/ui/screens/settings_screen.dart').readAsStringSync();
  });

  group('F233: the controls exist in Settings', () {
    test('THE GAP: there is an enable toggle', () {
      expect(source.contains("Key('diagnostic_log_toggle')"), isTrue,
          reason: 'THE ASSERTION THAT WAS MISSING. Without this the feature is '
              'unreachable -- shipped, tested, and impossible to turn on.');
      expect(source.contains('Write a diagnostic log'), isTrue);
    });

    test('it reads and writes the persisted setting', () {
      expect(source.contains('setDiagnosticLogEnabled('), isTrue,
          reason: 'the toggle must persist, not just flip a field');
      expect(source.contains('getDiagnosticLogEnabled()'), isTrue,
          reason: 'and it must load the stored value on open, or it would '
              'read OFF every launch while the log was on');
    });

    test('the logger cache is reset when the toggle changes', () {
      // Phase 7 review: this used to assert `debugSetEnabled(null)`. It worked,
      // but `debug*` is this repo's convention for a TEST-ONLY seam
      // (gmail_api_adapter.dart:56 -- "production code never calls this"), so a
      // future reader trusting that convention would guard it away and silently
      // break the toggle. `invalidateCache()` is the production API, and it
      // also clears the DIRECTORY cache, which was never invalidated at all.
      expect(source.contains('DiagnosticLogger.invalidateCache()'), isTrue,
          reason: 'the logger caches the enabled flag AND the directory; '
              'without a reset the user turns it on and nothing is written');
      expect(source.contains('DiagnosticLogger.debugSetEnabled('), isFalse,
          reason: 'production must not call a debug seam');
    });

    test('the retention flag is offered', () {
      expect(source.contains("Key('diagnostic_log_keep_all')"), isTrue);
      expect(source.contains('setDiagnosticLogKeepAll('), isTrue);
    });

    test("HAROLD'S CONDITION: the logs can be deleted from inside the app", () {
      // "if the user can easily get to them to delete the files" was attached
      // to the retention request as a condition, not an aside.
      expect(source.contains("Key('diagnostic_log_delete')"), isTrue);
      expect(source.contains('DiagnosticLogger.deleteAll()'), isTrue,
          reason: 'deleting from inside the app is the answer to "easily get '
              'to them" -- the user must never have to hunt in a file manager');
    });

    test('the size is shown next to the delete action', () {
      expect(source.contains('DiagnosticLogger.totalBytes()'), isTrue,
          reason: 'the honest half: the user can see what they are carrying '
              'before deciding whether to clear it');
      expect(source.contains('Diagnostic logs: '), isTrue);
    });

    test('the delete button is disabled when there is nothing to delete', () {
      // Now reads the FutureBuilder's snapshot rather than a cached field --
      // Phase 7 review found the cached value went stale, so a user with real
      // logs could face a DISABLED delete button. Asserting the guard exists
      // rather than its exact spelling.
      expect(source.contains('onPressed: bytes == 0'), isTrue,
          reason: 'an enabled button that does nothing teaches the user to '
              'distrust the control');
    });

    test('the size is read live, not from a cached field', () {
      expect(source.contains("Key('diagnostic_log_size')"), isTrue);
      expect(source.contains('FutureBuilder<int>'), isTrue,
          reason: 'the cached value went stale after a background failure '
              'wrote logs, leaving Delete disabled with logs present -- a '
              'non-functional control, not cosmetic staleness');
    });

    test('retention and delete are hidden until logging is ON', () {
      expect(source.contains('if (_diagnosticLogEnabled) ...['), isTrue,
          reason: 'controls for a feature that is off are noise; this also '
              'keeps the default Settings view unchanged for users who never '
              'enable it');
    });

    test('the subtitle states the privacy position plainly', () {
      // Unbroken fragment: the production string wraps across source lines,
      // so a whole-sentence match fails for formatting, not behavior.
      expect(source.contains('No message content'), isTrue,
          reason: 'the log must say what it does not contain');
      expect(
          source.contains('email addresses are shortened'),
          isTrue,
          reason: 'a log the user is asked to hand over must say what it does '
              'not contain');
    });
  });
}
