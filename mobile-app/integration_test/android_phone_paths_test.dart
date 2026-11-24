// Sprint 86, F359 -- the paths only a phone found, run on the Android emulator.
//
// Four defects in Sprints 78-84 were found only on an emulator or a phone
// (docs/research/F350_RISK_BASED_TESTING.md R-2). This file holds one case for
// each path:
//
//   1. WorkManager worker start and stop. The REAL dispatcher
//      (`androidBackgroundScanDispatcher`) is started by WorkManager in its own
//      engine, then cancelled while it runs. The stop handler writes the stop
//      line, ending with `powerSave=<v> deviceIdle=<v> thermal=<v>` (F346). A real
//      `true` or `false` proves the local plugin `spamfilter_device_state`
//      reached the WorkManager background engine; `unknown` means it did not.
//   2. The diagnostic log's cross-isolate mutex, with two isolates in ONE
//      process. On Android/Linux `RandomAccessFile.lock` is a POSIX record lock
//      held per PROCESS, so it never excluded the UI isolate from a WorkManager
//      isolate (Sprint 76 IMP-3). The file is written under the app's external
//      files folder, the same kind of storage the user-visible log lives in.
//   3. Turning background scanning on: the shared enable path
//      (`BackgroundScanEnabler`, used by Settings > Background > Enable
//      Background Scanning and by "Turn on" on the account list) with the real
//      WorkManager and the real Android scheduler.
//
// Cases 1 and 3 run on Android only (ADR-0042 declared exception: WorkManager has
// no counterpart on Windows or iOS). Case 2 runs everywhere: on Windows the lock
// is per handle, on iOS it is a POSIX record lock, so the same cases apply there.
//
// What these cases do NOT catch:
//   - the OS permission prompt itself. The notification permission request is
//     replaced by `BackgroundScanEnabler.permissionRequestOverride`, because a
//     system dialog is invisible to Flutter finders and would hang the run. The
//     case proves the request is made BEFORE the work is scheduled; it does not
//     prove what the user sees.
//   - a stop reason other than "cancelled by the app" (Doze, quota, memory);
//     only the app can cause the one this file produces.
//   - Samsung-specific storage behavior (the Fold). The emulator is stock
//     Android.
//
// Run on the emulator (the runner starts it through ANDROID_HOME and leaves it
// running):
//   python mobile-app/scripts/run-integration-tests.py --android-emulator
// By hand:
//   flutter test integration_test/android_phone_paths_test.dart -d emulator-5554 \
//       --flavor dev --dart-define=APP_ENV=dev

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import 'package:my_email_spam_filter/adapters/storage/app_paths.dart';
import 'package:my_email_spam_filter/core/services/android_background_scan_worker.dart';
import 'package:my_email_spam_filter/core/services/background_scan_enabler.dart';
import 'package:my_email_spam_filter/core/services/background_scan_scheduler.dart';
import 'package:my_email_spam_filter/core/services/diagnostic_logger.dart';
import 'package:my_email_spam_filter/core/storage/database_helper.dart';
import 'package:my_email_spam_filter/core/storage/settings_store.dart';

/// The WorkManager unique name of the probe task started by case 1.
const String _probeTask = 'f359_worker_probe';

/// Writes [count] lines of `[<tag>] line <i> xxx...` (200 x) with
/// [DiagnosticLogger.appendLocked] to [path]. Top level so an isolate can run it.
Future<void> _writeLines(String path, String tag, int count) async {
  final file = File(path);
  for (var i = 0; i < count; i++) {
    await DiagnosticLogger.appendLocked(file, '[$tag] line $i ${'x' * 200}\n');
  }
}

/// A folder the lock cases write into. On Android it is the app's external
/// files folder (shared storage behind the FUSE layer, where the Fold's torn
/// lines appeared); elsewhere the system temp folder.
Future<Directory> _lockTestDir(String name) async {
  Directory base;
  if (Platform.isAndroid) {
    base = (await getExternalStorageDirectory()) ??
        await getApplicationSupportDirectory();
  } else {
    base = Directory.systemTemp;
  }
  return Directory('${base.path}${Platform.pathSeparator}f359_$name')
      .create(recursive: true);
}

/// Lines of every `*.log` file in [dir] that were written at or after [since]
/// and contain [needle].
List<String> _logLinesSince(Directory dir, DateTime since, String needle) {
  final out = <String>[];
  if (!dir.existsSync()) return out;
  final stamp = RegExp(r'^\[(\d{4}-\d{2}-\d{2}T[^\]]+)\]');
  for (final f in dir.listSync().whereType<File>()) {
    if (!f.path.endsWith('.log')) continue;
    for (final line in f.readAsLinesSync()) {
      final m = stamp.firstMatch(line);
      if (m == null || !line.contains(needle)) continue;
      final at = DateTime.tryParse(m.group(1)!);
      if (at != null && !at.isBefore(since)) out.add(line);
    }
  }
  return out;
}

/// Polls [probe] every 250 ms until it returns a non-empty list, or fails the
/// test after [limit].
Future<List<String>> _waitFor(
  List<String> Function() probe,
  String what, {
  Duration limit = const Duration(seconds: 90),
}) async {
  final end = DateTime.now().add(limit);
  while (DateTime.now().isBefore(end)) {
    final found = probe();
    if (found.isNotEmpty) return found;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  fail('timed out after ${limit.inSeconds} s waiting for: $what');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('F359 diagnostic log lock, two isolates in one process', () {
    testWidgets('two isolates appending at once leave only whole lines',
        (tester) async {
      await tester.runAsync(() async {
        final dir = await _lockTestDir('tear');
        addTearDown(() => dir.delete(recursive: true));
        final path = '${dir.path}${Platform.pathSeparator}diag.log';
        await Future.wait([
          Isolate.run(() => _writeLines(path, 'a', 150)),
          Isolate.run(() => _writeLines(path, 'b', 150)),
        ]);
        final lines = File(path).readAsLinesSync();
        expect(lines.length, 300);
        final whole = RegExp(r'^\[[ab]\] line \d+ x{200}$');
        expect(lines.where((l) => !whole.hasMatch(l)), isEmpty,
            reason: 'a fragment means two isolates wrote at the same offset');
        expect(File('$path.lock').existsSync(), isFalse,
            reason: 'the mutex is released after every line');
      });
    });

    testWidgets('a second isolate waits for the lock the first one holds',
        (tester) async {
      await tester.runAsync(() async {
        final dir = await _lockTestDir('wait');
        addTearDown(() => dir.delete(recursive: true));
        final path = '${dir.path}${Platform.pathSeparator}diag.log';
        final lockPath = '$path.lock';

        // Isolate A holds the lock for 1.5 s: [rotate] runs INSIDE the mutex,
        // so its delay is time spent holding it.
        final first = Isolate.run(() async {
          await DiagnosticLogger.appendLocked(
            File(path),
            'first holder\n',
            rotate: (_) => Future<void>.delayed(const Duration(milliseconds: 1500)),
          );
        });
        // Start B only once A really holds the lock, so the order is not a
        // race between two isolate start-up times.
        final held = DateTime.now().add(const Duration(seconds: 20));
        while (!File(lockPath).existsSync() && DateTime.now().isBefore(held)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(File(lockPath).existsSync(), isTrue,
            reason: 'isolate A never took the lock');
        final second = Isolate.run(() async {
          await DiagnosticLogger.appendLocked(File(path), 'second writer\n');
        });
        await Future.wait([first, second]);

        // B started while A held the lock and A writes only after its 1.5 s
        // delay. Without a mutex B writes first.
        expect(File(path).readAsLinesSync(), ['first holder', 'second writer'],
            reason: 'the second isolate did not wait for the first');
        expect(File(lockPath).existsSync(), isFalse);
      });
    });
  });

  group('F359 WorkManager worker on the emulator', () {
    final android = Platform.isAndroid;

    setUpAll(() async {
      if (!android) return;
      await Workmanager().initialize(androidBackgroundScanDispatcher);
    });

    testWidgets('start, then stop: the stop line carries a real device state',
        skip: !android,
        timeout: const Timeout(Duration(minutes: 4)),
        (tester) async {
      await tester.runAsync(() async {
        // The worker is another isolate in another engine: it reads the REAL
        // app database, not a test one, so the diagnostic log is switched on
        // there. This is an emulator-only app copy.
        final paths = AppPaths();
        await paths.initialize();
        DatabaseHelper().setAppPaths(paths);
        final settings = SettingsStore();
        final wasEnabled = await settings.getDiagnosticLogEnabled();
        final wasExportDir = await settings.getCsvExportDirectory();
        await settings.setDiagnosticLogEnabled(true);
        // The default log folder is shared storage (Documents). A file there
        // written by an EARLIER install of this app is not readable or
        // writable by the next install (scoped storage: MediaProvider "Permission
        // to access file ... is denied"), so the worker would log nothing on every
        // run after the first. The app's own external folder is removed with the
        // app, so each install starts clean.
        final external = await getExternalStorageDirectory() ??
            await getApplicationSupportDirectory();
        final exportDir =
            await Directory('${external.path}/f359_export').create(recursive: true);
        await settings.setCsvExportDirectory(exportDir.path);
        DiagnosticLogger.invalidateCache();
        addTearDown(() async {
          // Bounded and best-effort. The stop below kills the worker's engine
          // while it may still be inside the rule-seeding transaction, and a
          // write from this isolate can then wait on that transaction for
          // good (seen on the emulator: a run that hung after the test body
          // passed). The emulator copy of the app is reinstalled each run, so
          // a restore that does not finish costs nothing.
          try {
            await settings.setDiagnosticLogEnabled(wasEnabled).timeout(
                const Duration(seconds: 5));
            await settings.setCsvExportDirectory(wasExportDir).timeout(
                const Duration(seconds: 5));
          } catch (e) {
            // ignore: avoid_print
            print('F359 restore of the emulator settings did not finish: $e');
          }
          DiagnosticLogger.invalidateCache();
        });
        final logDir = Directory(await DiagnosticLogger.resolveLogDir());
        final since = DateTime.now();

        await Workmanager().cancelByUniqueName(_probeTask);
        await Workmanager().registerOneOffTask(
          _probeTask,
          kAndroidScanTestTaskName,
        );

        // START: the worker's own first line proves WorkManager started the
        // real dispatcher in its background engine.
        final started = await _waitFor(
          () => _logLinesSince(logDir, since, '[worker/android] start [TEST]'),
          'the worker start line in ${logDir.path}',
        );
        expect(started, isNotEmpty);

        // STOP: cancel while the worker is still running. A fresh install seeds
        // the bundled rules inside ONE database transaction. A stop that lands
        // inside it leaves the stop handler no database to read its settings
        // from, so its log line cannot be written (seen on the emulator, runs
        // 2 and 3). This query waits for that transaction to commit, so the
        // cancel lands in the worker's later steps (default-rule checks and
        // rule loading), which still take about two seconds on the emulator.
        final db = await DatabaseHelper().database;
        await db
            .rawQuery('SELECT COUNT(*) FROM rules')
            .timeout(const Duration(seconds: 60));
        await Workmanager().cancelByUniqueName(_probeTask);
        final stopped = await _waitFor(
          () => _logLinesSince(
              logDir, since, 'stopped by WorkManager before it finished'),
          'the worker stop line',
          limit: const Duration(seconds: 60),
        );
        final line = stopped.first;
        // ignore: avoid_print
        print('F359 stop line: $line');
        expect(line, contains('reason=cancelledByApp raw=1'));
        expect(
          line,
          matches(RegExp(r'powerSave=(true|false) deviceIdle=(true|false) '
              r'thermal=(none|light|moderate|severe|critical|emergency|shutdown)')),
          reason: 'unknown means the device-state plugin did not reach the '
              'WorkManager background engine',
        );
      });
    });
  });

  group('F359 turning background scanning on', () {
    final android = Platform.isAndroid;

    setUpAll(() async {
      if (!android) return;
      await Workmanager().initialize(androidBackgroundScanDispatcher);
    });

    tearDown(() {
      BackgroundScanEnabler.permissionRequestOverride = null;
    });

    testWidgets(
        'the shared enable path asks for the notification permission, then '
        'schedules the real work', skip: !android, (tester) async {
      await tester.runAsync(() async {
        const accountId = 'f359-probe@example.invalid';
        const scheduler = AndroidSchedulerAdapter();
        final order = <String>[];
        BackgroundScanEnabler.permissionRequestOverride = () async {
          order.add('permission');
        };

        final result = await BackgroundScanEnabler.schedule(
          accountId: accountId,
          minutes: 15,
          caller: 'f359 integration test',
          scheduler: scheduler,
        ).timeout(const Duration(seconds: 30),
            onTimeout: () => fail('enabling hung: the UI isolate would ANR'));
        addTearDown(() => scheduler.cancel(accountId, caller: 'f359 test'));

        expect(result, BackgroundEnableResult.scheduled);
        expect(order, ['permission'],
            reason: 'the permission request must run once, before scheduling');
        expect(await scheduler.isScheduled(accountId), isTrue,
            reason: 'WorkManager must hold the periodic work');
        expect(BackgroundScanEnabler.messageFor(result), isNull);

        // Turning it off removes the work: the control is a real toggle.
        expect(await scheduler.cancel(accountId, caller: 'f359 test'), isTrue);
        expect(await scheduler.isScheduled(accountId), isFalse);
      });
    });
  });
}
