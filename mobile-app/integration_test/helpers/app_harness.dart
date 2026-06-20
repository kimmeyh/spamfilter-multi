// Sprint 42, F99 -- shared bootstrap for the Flutter integration_test E2E harness.
//
// In-VM second lane complementing the WinWright UIA harness
// (docs/TESTING_STRATEGY.md). integration_test drives the real widget tree in
// the Dart VM by Key/Finder with pumpAndSettle() -- immune to the dialog-settle
// / cursor / DPI flakiness that bit the WinWright F56 create/save and F37 picker
// scripts in Sprint 41 (see ALL_SPRINTS_MASTER_PLAN.md F76/F56/F37 -> F99).
//
// DB ISOLATION (critical -- Harold direction 2026-06-20):
// The app self-initializes its real data dir via AppPaths.initialize() ->
// getApplicationSupportDirectory(), and RuleSetProvider.initialize() constructs
// its OWN AppPaths(), so overriding DatabaseHelper.setAppPaths() does not
// isolate, and mocking the path_provider channel does not work on Windows
// desktop (path_provider does not use a MethodChannel there). The working seam
// is AppPaths.testOverrideBaseDir (F99): when set, the WHOLE app resolves its
// data dir to that path. Two modes:
//
//   bootApp            -> fresh EMPTY temp dir; the app seeds the bundled rule
//                         set (deterministic ~4000+ rules), exactly like a clean
//                         install. Never touches dev data.
//   bootAppWithDevDbCopy -> COPY the dev DB into the temp dir and run against the
//                         copy (Harold's "copy the DB, test on the copy, delete
//                         the copy" pattern), for tests that need realistic data.
//                         The real dev DB is never opened.
//
// Both delete the temp dir and clear the override in HarnessSession.dispose().

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_email_spam_filter/main.dart' show SpamFilterApp;
import 'package:my_email_spam_filter/adapters/storage/app_paths.dart';
import 'package:my_email_spam_filter/core/services/app_environment.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';

/// Boots [SpamFilterApp] against a FRESH empty isolated temp dir (the app seeds
/// the bundled rule set). Use for tests that do not need pre-existing user data.
Future<HarnessSession> bootApp(WidgetTester tester) async {
  final tempDir = await Directory.systemTemp.createTemp('spamfilter_it_');
  AppPaths.testOverrideBaseDir = tempDir.path;
  await _pumpBootedApp(tester);
  return HarnessSession._(tempDir);
}

/// Boots [SpamFilterApp] against a COPY of the dev DB placed in an isolated temp
/// dir. Use for UI tests that need realistic existing rules/safe-senders. The
/// real dev DB is copied once and never opened by the app.
///
/// Returns null (and the test should skip) if the dev DB is not present, so the
/// suite still runs on a clean checkout / CI without dev data.
Future<HarnessSession?> bootAppWithDevDbCopy(WidgetTester tester) async {
  final devDb = _devDbFile();
  if (!devDb.existsSync()) {
    return null;
  }
  final tempDir = await Directory.systemTemp.createTemp('spamfilter_it_');
  // Place the copy at <temp>/spam_filter.db so AppPaths.databaseFilePath
  // (which is <appSupportDir>/spam_filter.db) resolves to the copy.
  await devDb.copy('${tempDir.path}/spam_filter.db');
  AppPaths.testOverrideBaseDir = tempDir.path;
  await _pumpBootedApp(tester);
  return HarnessSession._(tempDir);
}

Future<void> _pumpBootedApp(WidgetTester tester) async {
  await tester.pumpWidget(const SpamFilterApp());
  // _AppInitializer kicks RuleSetProvider.initialize() off a microtask; settle
  // until the loading spinner is replaced by the home screen.
  await tester.pumpAndSettle();
}

/// Resolves the real dev DB path (read-only source for the copy mode):
/// %APPDATA%\MyEmailSpamFilter\MyEmailSpamFilter_Dev\spam_filter.db
File _devDbFile() {
  final appData = Platform.environment['APPDATA'] ?? '';
  final suffix = AppEnvironment.dataDirSuffix; // '_Dev' in dev builds
  return File(
    '$appData\\MyEmailSpamFilter\\MyEmailSpamFilter$suffix\\spam_filter.db',
  );
}

/// Owns the per-test temp directory + the AppPaths override so they are cleaned
/// up in tearDown. ALWAYS dispose, even on test failure.
class HarnessSession {
  HarnessSession._(this._tempDir);
  final Directory _tempDir;

  Future<void> dispose() async {
    AppPaths.testOverrideBaseDir = null;
    // Close the cached singleton DB connection so the next test re-opens against
    // its OWN override dir (DatabaseHelper caches _database across tests).
    try {
      await DatabaseHelper().close();
    } catch (_) {
      // ignore -- nothing open
    }
    try {
      if (await _tempDir.exists()) {
        await _tempDir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort cleanup; a leftover temp dir under the OS temp root is
      // harmless and never touches the dev DB.
    }
  }
}
