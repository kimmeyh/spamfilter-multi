/// F248 (Sprint 76): R-8 (no doubled `diagnostics` folder) and R-3 (the Gmail
/// native sign-in names the step that failed).
///
/// R-8 before: with the export folder set to `Documents/diagnostics`, the log
/// went to `Documents/diagnostics/diagnostics` (the Fold, 2026-10-04). After:
/// a chosen folder that is itself the diagnostics folder is used as is.
///
/// R-3 before: native sign-in failed AFTER the account pick on the Fold and
/// fell back to the browser, and nothing recorded which call threw. After:
/// the step is tracked and written on failure.
///
/// What these do NOT catch: R-3 is a SOURCE gate -- google_sign_in's native
/// SDK has no seam on this host, so the ordering is asserted in the source and
/// the real failure is read from a phone log (Task 3). R-8 does not cover a
/// folder named `diagnostics` in a DEV build, whose log folder is
/// `diagnostics_Dev` (the rule matches the exact log-folder name).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:my_email_spam_filter/core/services/app_environment.dart';
import 'package:my_email_spam_filter/core/services/diagnostic_logger.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

import '../../helpers/database_test_helper.dart';

void main() {
  setUpAll(DatabaseTestHelper.initializeFfi);

  group('R-8: the log folder', () {
    late DatabaseTestHelper testHelper;
    late Directory root;

    setUp(() async {
      testHelper = DatabaseTestHelper();
      await testHelper.setUp();
      root = await Directory.systemTemp.createTemp('f248_r8_');
      DiagnosticLogger.invalidateCache();
    });

    tearDown(() async {
      DiagnosticLogger.invalidateCache();
      await testHelper.tearDown();
      if (await root.exists()) await root.delete(recursive: true);
    });

    final sub = 'diagnostics${AppEnvironment.dataDirSuffix}';

    test('a chosen folder that IS the log folder is used as is, not nested',
        () async {
      final chosen = await Directory(path.join(root.path, sub)).create();
      await SettingsStore().setCsvExportDirectory(chosen.path);
      DiagnosticLogger.invalidateCache();
      expect(await DiagnosticLogger.resolveLogDir(), chosen.path);
    });

    test('any other chosen folder still gets the log subfolder', () async {
      final chosen = await Directory(path.join(root.path, 'Exports')).create();
      await SettingsStore().setCsvExportDirectory(chosen.path);
      DiagnosticLogger.invalidateCache();
      expect(await DiagnosticLogger.resolveLogDir(), path.join(chosen.path, sub));
    });
  });

  // SOURCE-TEXT VERIFIED: settled only by a Gmail add on the Fold with logging on.
  // google_sign_in's native authenticate() and authorizeScopes() cannot run
  // on a desktop test host, so R-3 is asserted in the source. On the Fold
  // (Sprint 76 Task 3, F250) the log must show
  // "native <step> FAILED" naming authenticate or authorizeScopes, followed by
  // "falling back to the browser sign-in".
  test('R-3: native sign-in records its step before each call and writes the '
      'failing step (source gate -- the native SDK has no seam here)', () {
    final src =
        File('lib/adapters/auth/google_auth_service.dart').readAsStringSync();
    final start = src.indexOf('Future<AuthResult> _signInNative(');
    final end = src.indexOf('Future<AuthResult> _signInDesktop(', start);
    expect(start, greaterThan(0));
    final body = src.substring(start, end);
    final stepAuth = body.indexOf("step = 'authenticate';");
    final callAuth = body.indexOf('_googleSignIn.authenticate()');
    final stepScopes = body.indexOf("step = 'authorizeScopes';");
    final callScopes = body.indexOf('authorizationClient.authorizeScopes(');
    expect(stepAuth, greaterThan(0));
    expect(callAuth, greaterThan(stepAuth));
    expect(stepScopes, greaterThan(callAuth));
    expect(callScopes, greaterThan(stepScopes));
    expect(body.indexOf(r"_signInLog('native $step FAILED: "),
        greaterThan(callScopes),
        reason: 'the catch must write which step was running');
    expect(body.contains("_signInLog('falling back to the browser sign-in')"),
        isTrue);
  });

  test('Q4: every rule-action run from Results logs its outcome -- preview, '
      'nothing to do, and acted on N of M (source gate; settled on the phone '
      'by checklist item 2)', () {
    final src =
        File('lib/ui/screens/results_display_screen.dart').readAsStringSync();
    final start = src.indexOf('Future<ReProcessOutcome> _reProcessAffectedEmails(');
    final end = src.indexOf('Future<void> _addSafeSender(', start);
    final body = src.substring(start, end);
    int before(String log, String ret) {
      final r = body.indexOf(ret);
      final l = body.lastIndexOf(log, r);
      return r - l;
    }

    expect(before("detail: 'read-only preview: would delete",
            'return ReProcessOutcome.readOnly('),
        inInclusiveRange(1, 400));
    expect(before("detail: 'nothing to act on", 'return const ReProcessOutcome.nothingToDo();'),
        inInclusiveRange(1, 400));
    expect(before("detail: 'acted on \$successCount of \$total",
            '    return ReProcessOutcome(\n'),
        inInclusiveRange(1, 1200));
  });
}
