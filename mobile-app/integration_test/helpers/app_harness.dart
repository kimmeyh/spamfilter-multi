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
//
// NO APP SHUTDOWN BETWEEN TESTS (Harold steering 2026-06-20):
// The WinWright lane relaunches the whole app process before every script
// (~6s each) ONLY because `winwright run` force-closes the attached app at
// end-of-run with no keep-alive. integration_test has NO such constraint: all
// testWidgets cases run in ONE process, and bootApp() does an in-VM fresh
// pumpWidget + isolated temp DB -- a fast widget-tree reset, not an app
// shutdown/relaunch. Do NOT port the WinWright per-test process-kill pattern
// here; back-to-back cases are cheap (multiple boots ran in ~1s total).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:my_email_spam_filter/main.dart' show SpamFilterApp;
import 'package:my_email_spam_filter/adapters/storage/app_paths.dart';
import 'package:my_email_spam_filter/core/services/app_environment.dart';
import 'package:my_email_spam_filter/core/services/default_rule_set_service.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';

// EXECUTION MODEL (Harold direction 2026-06-20): the F99 runner invokes each
// integration_test/*_test.dart in its OWN `flutter test` process (see
// scripts/run-integration-tests.ps1). This is the standard Flutter pattern for
// stateful apps and gives clean isolation at the FILE boundary -- the app's
// process-wide singletons (DatabaseHelper, the fire-and-forget
// RuleSetProvider.initialize() async tail) cannot bleed across files. WITHIN a
// file, multiple testWidgets share one process and reset cleanly via bootDbOnly
// + HarnessSession.dispose() (no app shutdown between tests).
//
// PREFER bootDbOnly: it seeds an isolated temp DB and lets the test pump the
// SPECIFIC screen(s) it exercises. This is deterministic and fully awaited.
// bootAppWithDevDbCopy boots the WHOLE SpamFilterApp (whose RuleSetProvider.
// initialize() has an un-awaitable async tail) -- use it sparingly and ideally
// as the SOLE test in its file.

/// Seeds an isolated temp DB (FFI + AppPaths override + bundled-rule seed) and
/// returns a session. The test pumps the screen(s) it needs. Fully awaited and
/// deterministic -- the preferred boot for F99 lifecycle / picker / visual tests.
Future<HarnessSession> bootDbOnly(WidgetTester tester) async {
  final session = await _newSessionWithSeededDb();
  return session;
}

/// Boots the FULL [SpamFilterApp] against a COPY of the dev DB in an isolated
/// temp dir (Harold's "copy the DB, test on the copy, delete the copy" pattern),
/// for UI tests that need realistic existing data. The real dev DB is copied
/// once and never opened. Returns null (skip the test) if the dev DB is absent
/// so the suite still runs on a clean checkout / CI.
///
/// Because this boots the full app (un-awaitable provider init tail), keep such
/// a test as the only test in its file -- the per-file runner isolates it.
Future<HarnessSession?> bootAppWithDevDbCopy(WidgetTester tester) async {
  final devDb = _devDbFile();
  if (!devDb.existsSync()) {
    return null;
  }
  final tempDir = await Directory.systemTemp.createTemp('spamfilter_it_');
  await devDb.copy('${tempDir.path}/spam_filter.db');
  AppPaths.testOverrideBaseDir = tempDir.path;

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // IMP-1 (Sprint 42 retro): verify the override resolves under the OS temp root
  // BEFORE pumping the full app (which will open + write the DB).
  final guardPaths = AppPaths();
  await guardPaths.initialize();
  _assertTempDataPath(guardPaths.databaseFilePath);

  await tester.pumpWidget(const SpamFilterApp());
  // _AppInitializer kicks RuleSetProvider.initialize() (async DB I/O) off a
  // microtask; settle until the loading spinner clears (= init complete).
  await tester.pumpAndSettle(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();

  return HarnessSession._(tempDir);
}

/// Shared: create temp dir, point AppPaths + DatabaseHelper at it, seed bundled
/// rules. Awaited end-to-end.
Future<HarnessSession> _newSessionWithSeededDb() async {
  final tempDir = await Directory.systemTemp.createTemp('spamfilter_it_');
  AppPaths.testOverrideBaseDir = tempDir.path;

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // bootDbOnly does not pump the full app, so it must set the DatabaseHelper
  // instance's AppPaths explicitly (the full-app path gets this via
  // RuleSetProvider.initialize()). The AppPaths honors testOverrideBaseDir.
  final appPaths = AppPaths();
  await appPaths.initialize();
  // IMP-1 (Sprint 42 retro): hard-assert the resolved DB path is under the OS
  // temp root BEFORE any write/seed. This is the guard that would have caught
  // the F99 dev-DB contamination: if isolation ever silently fails, fail loudly
  // here instead of writing to the real dev DB.
  _assertTempDataPath(appPaths.databaseFilePath);
  final db = DatabaseHelper();
  db.setAppPaths(appPaths);

  await DefaultRuleSetService(db).seedIfEmpty();
  return HarnessSession._(tempDir);
}

/// Fails the test immediately if [dbPath] is NOT under the OS temp root -- the
/// safety guard against ever writing to the real dev/prod DB from a test.
void _assertTempDataPath(String dbPath) {
  final tempRoot = Directory.systemTemp.path.toLowerCase();
  final resolved = dbPath.toLowerCase();
  if (!resolved.startsWith(tempRoot)) {
    throw StateError(
      'HARNESS ISOLATION FAILURE: resolved DB path is NOT under the OS temp '
      'root.\n  DB path:   $dbPath\n  temp root: ${Directory.systemTemp.path}\n'
      'Refusing to run -- a test must never write to the real dev/prod DB. '
      '(AppPaths.testOverrideBaseDir likely did not take effect.)',
    );
  }
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
    // Close the cached singleton DB connection so the next testWidgets in this
    // file re-opens against its own fresh override dir, then clear the override.
    try {
      await DatabaseHelper().close();
    } catch (_) {
      // ignore -- nothing open
    }
    AppPaths.testOverrideBaseDir = null;
    try {
      if (await _tempDir.exists()) {
        await _tempDir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort; a leftover temp dir under the OS temp root is harmless and
      // never touches the dev DB.
    }
  }
}
