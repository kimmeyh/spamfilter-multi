import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:my_email_spam_filter/core/providers/email_scan_provider.dart';
import 'package:my_email_spam_filter/core/services/app_environment.dart';
import 'package:my_email_spam_filter/core/services/app_version.dart';
import 'package:my_email_spam_filter/core/services/live_scan_logger.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

/// F92 (Sprint 39): Dedicated unit tests for [LiveScanLogger].
///
/// `live_scan_logger.dart` shipped in PR #259 (F90) with no dedicated
/// tests. A Copilot review asked for minimal coverage of the gating
/// behavior and the path/filename construction. These tests cover the
/// public API actually present in the source:
///   - `LiveScanLogger.getLogDir()`        -- env-aware, path.join-based
///   - `LiveScanLogger.log(message)`       -- append-mode runtime log,
///                                            silent on IO failure
///   - `LiveScanLogger.exportCsvIfEnabled` -- gated by the
///                                            `getLiveScanDebugCsv` setting
///
/// path_provider is stubbed via its MethodChannel so the tests never
/// touch the real OS application-support directory. NOTE: `getLogDir`
/// memoizes the resolved directory in a private static (`_cachedLogDir`)
/// with no public reset hook, so the mock returns a single stable
/// directory for the whole run rather than a fresh temp dir per call.
/// All assertions therefore key off that stable directory.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');

  // Stable application-support directory for the whole run. `getLogDir`
  // caches the first resolution in a static field, so we cannot vary it
  // per test without a reset hook (which the production class does not
  // expose).
  late Directory appSupport;

  setUpAll(() {
    appSupport = Directory.systemTemp.createTempSync('live_scan_logger_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'getApplicationSupportDirectory') {
        return appSupport.path;
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (appSupport.existsSync()) {
      appSupport.deleteSync(recursive: true);
    }
  });

  // ---------------------------------------------------------------------------
  // getLogDir(): environment-aware, cross-platform path joining
  // ---------------------------------------------------------------------------
  group('getLogDir', () {
    test('is environment-aware (dataDirSuffix) and ends with logs', () async {
      final dir = await LiveScanLogger.getLogDir();

      // Expected: path.join('{appSupport}{dataDirSuffix}', 'logs').
      // We compute the expectation from the SAME helpers the production
      // code uses so this test is correct in both dev and prod builds
      // (flutter test defaults APP_ENV to 'dev', so dataDirSuffix is
      // '_Dev', but we do not hard-code that).
      final expected = p.join(
        '${appSupport.path}${AppEnvironment.dataDirSuffix}',
        'logs',
      );
      expect(dir, expected);
      expect(p.basename(dir), 'logs');
      // The env suffix must be applied to the support dir component.
      expect(
        dir,
        contains('${appSupport.path}${AppEnvironment.dataDirSuffix}'),
      );
    });

    test('uses path.join (no hard-coded backslash separators)', () async {
      final dir = await LiveScanLogger.getLogDir();
      // path.join inserts the platform separator. On a non-Windows host
      // there must be no literal backslash; on Windows the separator is a
      // backslash. Either way the join must equal path.join output and
      // the final component is split correctly by p.basename.
      expect(dir, p.join(p.dirname(dir), 'logs'));
      if (!Platform.isWindows) {
        // Regression guard for the bug called out in the source comment:
        // concatenating '\\logs' on Android would create a literal
        // "files\logs" directory name.
        expect(dir.contains('\\'), isFalse);
      }
    });

    test('returns the same (cached) value on a second call', () async {
      final first = await LiveScanLogger.getLogDir();
      final second = await LiveScanLogger.getLogDir();
      expect(second, first);
    });
  });

  // ---------------------------------------------------------------------------
  // log(): append-mode runtime log, silent on failure
  // ---------------------------------------------------------------------------
  group('log', () {
    // Read the app version from pubspec.yaml so this filename assertion never
    // drifts on a version bump (F118, Sprint 47): the runtime log filename in
    // live_scan_logger.dart embeds the version, and the version-consistency
    // gate updates that source literal on every bump. Hardcoding it here meant
    // the test broke on each bump; deriving it keeps the test honest without
    // manual upkeep.
    String appVersion() {
      final pubspec = File(p.join(Directory.current.path, 'pubspec.yaml'))
          .readAsStringSync();
      final match =
          RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
              .firstMatch(pubspec);
      if (match == null) {
        fail('Could not parse version from pubspec.yaml');
      }
      return match.group(1)!;
    }

    // F-VERSION-DERIVE (Sprint 49): the logger now resolves the version via
    // AppVersion (package_info_plus at runtime). Unit tests have no platform
    // channel, so inject the pubspec-derived version through the test seam --
    // asserting the same single-source-of-truth the runtime uses.
    setUp(() => AppVersion.overrideForTest(appVersion()));
    tearDown(() => AppVersion.overrideForTest(null));

    File runtimeLogFile() {
      final logDir = p.join(
        '${appSupport.path}${AppEnvironment.dataDirSuffix}',
        'logs',
      );
      return File(
        p.join(logDir,
            '${AppEnvironment.logPrefix}live_scan_v${appVersion()}.log'),
      );
    }

    test('writes a timestamped [LIVE] line to the runtime log file',
        () async {
      final logFile = runtimeLogFile();
      if (logFile.existsSync()) logFile.deleteSync();

      await LiveScanLogger.log('hello-from-test');

      expect(logFile.existsSync(), isTrue);
      final contents = await logFile.readAsString();
      expect(contents, contains('[LIVE] hello-from-test'));
      // Timestamp prefix: "[<iso8601>] [LIVE] ...". Match the bracketed
      // ISO-8601 date at the start of the line.
      expect(
        RegExp(r'^\[\d{4}-\d{2}-\d{2}T').hasMatch(contents),
        isTrue,
        reason: 'line should start with a bracketed ISO-8601 timestamp',
      );
    });

    test('appends in append mode (does not truncate prior lines)', () async {
      final logFile = runtimeLogFile();
      if (logFile.existsSync()) logFile.deleteSync();

      await LiveScanLogger.log('first-line');
      await LiveScanLogger.log('second-line');

      final lines = (await logFile.readAsString())
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines.length, 2);
      expect(lines[0], contains('first-line'));
      expect(lines[1], contains('second-line'));
    });

    test('is silent (does not throw) even when the log path is unwritable',
        () async {
      // Make the logs directory un-creatable by planting a *file* where
      // the logs directory is expected. `logFile.parent.create()` will
      // then fail, but log() swallows the error.
      final logFile = runtimeLogFile();
      final logsDir = logFile.parent;
      if (logsDir.existsSync()) {
        logsDir.deleteSync(recursive: true);
      }
      // Create a file at the logs-directory path so directory creation
      // fails (cannot create a dir where a file exists).
      File(logsDir.path).writeAsStringSync('blocker');

      // Must not throw.
      await expectLater(LiveScanLogger.log('should-not-throw'), completes);

      // Cleanup so later groups can recreate the logs directory.
      File(logsDir.path).deleteSync();
    });
  });

  // ---------------------------------------------------------------------------
  // exportCsvIfEnabled(): gated by getLiveScanDebugCsv setting
  // ---------------------------------------------------------------------------
  group('exportCsvIfEnabled', () {
    String logDirPath() => p.join(
          '${appSupport.path}${AppEnvironment.dataDirSuffix}',
          'logs',
        );

    String dataCsvPath(String accountId) {
      final safe = accountId.replaceAll('@', '_at_').replaceAll('.', '_');
      final date = DateTime.now().toIso8601String().split('T')[0];
      final dev = AppEnvironment.isDev ? '_dev' : '';
      return p.join(logDirPath(), 'live_scan_${safe}_$date$dev.data.csv');
    }

    String xlsxPath(String accountId) {
      final safe = accountId.replaceAll('@', '_at_').replaceAll('.', '_');
      final date = DateTime.now().toIso8601String().split('T')[0];
      final dev = AppEnvironment.isDev ? '_dev' : '';
      return p.join(logDirPath(), 'live_scan_${safe}_$date$dev.xlsx');
    }

    setUp(() {
      // Ensure a clean logs directory for each export test.
      final dir = Directory(logDirPath());
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('returns 0 and writes no file when the setting is OFF', () async {
      const accountId = 'aol-off@example.com';
      final result = await LiveScanLogger.exportCsvIfEnabled(
        scanProvider: _FakeScanProvider([
          ['c1', 'c2'],
        ]),
        accountId: accountId,
        settingsStore: _FakeSettingsStore(false),
      );

      expect(result, 0);
      expect(File(dataCsvPath(accountId)).existsSync(), isFalse);
      expect(File(xlsxPath(accountId)).existsSync(), isFalse);
    });

    test('writes CSV + XLSX and returns row count when setting is ON',
        () async {
      const accountId = 'aol-on@example.com';
      final rows = [
        ['scan', 'recv', 'Success', 'INBOX', 'move', 'rule1', 'a@b.com',
            'Subj', 'cond', 'id1'],
        ['scan', 'recv', 'Success', 'INBOX', 'delete', 'rule2', 'c@d.com',
            'Subj2', 'cond2', 'id2'],
      ];
      final result = await LiveScanLogger.exportCsvIfEnabled(
        scanProvider: _FakeScanProvider(rows),
        accountId: accountId,
        settingsStore: _FakeSettingsStore(true),
      );

      expect(result, rows.length);
      final csv = File(dataCsvPath(accountId));
      final xlsx = File(xlsxPath(accountId));
      expect(csv.existsSync(), isTrue);
      expect(xlsx.existsSync(), isTrue);
      // Tab-separated rows were written.
      final csvText = csv.readAsStringSync();
      expect(csvText, contains('a@b.com'));
      expect(csvText, contains('id2'));
      // XLSX is a non-empty zip (PK header).
      expect(xlsx.lengthSync(), greaterThan(0));
    });

    test('writes a single placeholder row when scan rows are empty',
        () async {
      const accountId = 'aol-empty@example.com';
      final result = await LiveScanLogger.exportCsvIfEnabled(
        scanProvider: _FakeScanProvider([]),
        accountId: accountId,
        settingsStore: _FakeSettingsStore(true),
      );

      // Source returns 1 (the placeholder row) when getExcelRows is empty.
      expect(result, 1);
      final csv = File(dataCsvPath(accountId));
      expect(csv.existsSync(), isTrue);
      expect(csv.readAsStringSync(), contains('<no records to process>'));
    });

    test('CSV accumulates across multiple scans (append mode)', () async {
      const accountId = 'aol-multi@example.com';
      final settings = _FakeSettingsStore(true);

      await LiveScanLogger.exportCsvIfEnabled(
        scanProvider: _FakeScanProvider([
          ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'first'],
        ]),
        accountId: accountId,
        settingsStore: settings,
      );
      await LiveScanLogger.exportCsvIfEnabled(
        scanProvider: _FakeScanProvider([
          ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'second'],
        ]),
        accountId: accountId,
        settingsStore: settings,
      );

      final csv = File(dataCsvPath(accountId));
      final lines = csv
          .readAsStringSync()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      // Two scans, one data row each -> CSV accumulates to 2 rows.
      expect(lines.length, 2);
      expect(lines[0], contains('first'));
      expect(lines[1], contains('second'));
      // XLSX is regenerated each call from the accumulated CSV.
      expect(File(xlsxPath(accountId)).existsSync(), isTrue);
    });
  });
}

/// Fake [SettingsStore] that returns a fixed value for [getLiveScanDebugCsv]
/// without touching the database. SettingsStore's no-arg/optional
/// constructor lazily builds a DatabaseHelper, but we never invoke any
/// method that uses it because we override the only method the logger calls.
class _FakeSettingsStore extends SettingsStore {
  _FakeSettingsStore(this._enabled);

  final bool _enabled;

  @override
  Future<bool> getLiveScanDebugCsv() async => _enabled;
}

/// Fake [EmailScanProvider] that returns canned Excel rows without running
/// a scan. Overrides only [getExcelRows], which is all the logger calls.
class _FakeScanProvider extends EmailScanProvider {
  _FakeScanProvider(this._rows);

  final List<List<String>> _rows;

  @override
  List<List<String>> getExcelRows() => _rows;
}
