/// F161 (Sprint 61): the platform-factory scheduler -- every implementation
/// tested, per ADR-0042's first factory rule ("a shared interface with one
/// tested implementation is uneven coverage in a nicer wrapper", the Sprint 60
/// accounts-FK shape).
///
/// Coverage map, stated so the gaps are decisions rather than accidents:
///   - [AndroidSchedulerAdapter]: REAL behavior tests against a fake
///     `WorkmanagerPlatform` (the plugin's own injection seam) -- asserts the
///     exact registration WorkManager would receive: per-account unique name
///     with the environment suffix, frequency, accountId inputData, network
///     constraint, and the UPDATE policy that makes re-scheduling idempotent.
///   - [UnsupportedPlatformScheduler]: full contract (the explicit-no-op rules).
///   - [BackgroundScanSchedulerFactory]: the test override seam.
///   - [WindowsSchedulerAdapter]: NOT unit-tested here, deliberately -- its
///     three calls delegate to `WindowsTaskSchedulerService` statics that shell
///     out to schtasks.exe, so a unit test would either run real schtasks
///     commands on the host or test a mock of itself. Its exists->update/create
///     logic is the same decision `settings_screen` made inline for 15 sprints
///     (moved verbatim), and the live path is exercised by every Windows
///     background-scan cycle on the dev machine.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:workmanager/workmanager.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

import 'package:my_email_spam_filter/core/services/app_environment.dart';
import 'package:my_email_spam_filter/core/services/android_doze_alarm.dart';
import 'package:my_email_spam_filter/core/services/background_scan_scheduler.dart';
import 'package:my_email_spam_filter/core/utils/account_id_sanitizer.dart';

/// Fake platform capturing what the adapter sends to WorkManager. Uses the
/// plugin's own `WorkmanagerPlatform.instance` seam, so the adapter under test
/// is the REAL adapter end to end -- nothing in it is mocked.
class _FakeWorkmanagerPlatform extends WorkmanagerPlatform
    with MockPlatformInterfaceMixin {
  final List<Map<String, Object?>> periodicRegistrations = [];
  final List<Map<String, Object?>> oneOffRegistrations = [];
  final List<String> cancelledUniqueNames = [];
  final Set<String> scheduledNames = {};
  bool throwOnRegister = false;

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? flexInterval,
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    if (throwOnRegister) throw StateError('platform rejected registration');
    periodicRegistrations.add({
      'uniqueName': uniqueName,
      'taskName': taskName,
      'frequency': frequency,
      'inputData': inputData,
      'networkType': constraints?.networkType,
      'existingWorkPolicy': existingWorkPolicy,
      'backoffPolicy': backoffPolicy,
      'backoffPolicyDelay': backoffPolicyDelay,
    });
    scheduledNames.add(uniqueName);
  }

  @override
  Future<void> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    OutOfQuotaPolicy? outOfQuotaPolicy,
    bool expedited = false,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    oneOffRegistrations.add({
      'uniqueName': uniqueName,
      'taskName': taskName,
      'inputData': inputData,
      'backoffPolicy': backoffPolicy,
    });
  }

  /// 7.7.1 H-2: throw on the Nth cancel call (1 = the periodic work, 2 = the
  /// test one-off), to drive the failure notes.
  int? throwOnCancelCall;
  int _cancelCalls = 0;

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    if (++_cancelCalls == throwOnCancelCall) {
      throw StateError('platform rejected cancel');
    }
    cancelledUniqueNames.add(uniqueName);
    scheduledNames.remove(uniqueName);
  }

  @override
  Future<bool> isScheduledByUniqueName(String uniqueName) async =>
      scheduledNames.contains(uniqueName);
}

void main() {
  const accountId = 'aol-user@aol.com';

  // Construct the Workmanager singleton BEFORE any fake is injected. Its
  // one-time constructor runs _ensurePlatformImplementation(), which
  // REPLACES WorkmanagerPlatform.instance whenever the instance is not a
  // recognized platform implementation -- on a Linux host (GitHub CI) that
  // replaced the injected fake with WorkmanagerLinux, whose no-op
  // registerPeriodicTask made the first test's registration vanish (ok ==
  // true, nothing recorded). Windows has no replacement branch, which is
  // why the suite was green locally and red only on CI. With the singleton
  // already constructed, the per-test instance injection below sticks on
  // every host.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(Workmanager.new);

  group('AndroidSchedulerAdapter (real adapter, fake platform)', () {
    late _FakeWorkmanagerPlatform fake;
    const adapter = AndroidSchedulerAdapter();

    setUp(() {
      fake = _FakeWorkmanagerPlatform();
      WorkmanagerPlatform.instance = fake;
    });

    test(
        'schedule registers per-account unique periodic work with the exact '
        'payload the Windows model mirrors (ADR-0039)', () async {
      final ok = await adapter.schedule(
          accountId: accountId, intervalMinutes: 60, caller: 'test');

      expect(ok, isTrue);
      expect(fake.periodicRegistrations, hasLength(1));
      final reg = fake.periodicRegistrations.single;

      expect(
          reg['uniqueName'],
          'spamfilter_background_scan_${sanitizeAccountId(accountId)}'
          '${AppEnvironment.taskNameSuffix}',
          reason: 'the unique name must mirror the Windows '
              'SpamFilterBackgroundScan_<sanitized><envSuffix> convention -- '
              'same sanitizer, same env suffix -- so per-account AND per-'
              'environment uniqueness is the identical invariant on both '
              'platforms');
      expect(reg['frequency'], const Duration(minutes: 60));
      expect((reg['inputData'] as Map)['accountId'], accountId,
          reason: 'the dispatcher reads the account from inputData; without '
              'it a scheduled run would fall back to scanning all enabled '
              'accounts');
      expect(reg['networkType'], NetworkType.connected,
          reason: 'an IMAP scan without a network can only fail and burn the '
              'work budget (declared Android constraint, ADR-0042)');
      expect(reg['existingWorkPolicy'], ExistingPeriodicWorkPolicy.update,
          reason: 'UPDATE is what makes schedule() idempotent per the '
              'interface contract: a frequency change re-registers and takes '
              'effect instead of duplicating work or keeping the stale '
              'schedule (the plugin docs call out exactly this trap with '
              'keep)');
    });

    group('F264: the Doze alarm gets the user\'s minutes, WorkManager its '
        'documented 15-minute minimum', () {
      // What this does NOT catch: Android actually honoring a 5-minute alarm
      // (it limits while-idle alarms to about one per nine minutes) -- that is
      // phone validation, and the Background note says so to the user.
      final alarmCalls = <Map<Object?, Object?>>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      setUp(() {
        alarmCalls.clear();
        messenger.setMockMethodCallHandler(AndroidDozeAlarm.channel,
            (call) async {
          if (call.method == 'schedule') {
            alarmCalls.add(Map<Object?, Object?>.from(call.arguments as Map));
          }
          return true;
        });
      });
      tearDown(
          () => messenger.setMockMethodCallHandler(AndroidDozeAlarm.channel, null));

      test('AC-8: 5 minutes -> alarm 5, WorkManager 15', () async {
        expect(await adapter.schedule(
          accountId: accountId, intervalMinutes: 5, caller: 'test'),
            isTrue);
        expect(alarmCalls.single['intervalMinutes'], 5,
            reason: 'BEFORE F264 the clamp ran above the alarm call, so the '
                'alarm was armed at 15');
        expect(fake.periodicRegistrations.single['frequency'],
            const Duration(minutes: 15));
      });

      test('AC-8: 30 minutes -> 30 to both', () async {
        await adapter.schedule(
          accountId: accountId, intervalMinutes: 30, caller: 'test');
        expect(alarmCalls.single['intervalMinutes'], 30);
        expect(fake.periodicRegistrations.single['frequency'],
            const Duration(minutes: 30));
      });

      test('AC-2 (Android half): 120 and 240 minutes are scheduled, not '
          'refused', () async {
        for (final m in [120, 240, 5940]) {
          alarmCalls.clear();
          fake.periodicRegistrations.clear();
          expect(await adapter.schedule(
          accountId: accountId, intervalMinutes: m, caller: 'test'),
              isTrue,
              reason: 'the old ScanFrequency enum could not represent these');
          expect(alarmCalls.single['intervalMinutes'], m);
          expect(fake.periodicRegistrations.single['frequency'],
              Duration(minutes: m));
        }
      });
    });

    test('schedule with a non-positive interval refuses without touching '
        'WorkManager', () async {
      final ok = await adapter.schedule(
          accountId: accountId, intervalMinutes: 0, caller: 'test');
      expect(ok, isFalse);
      expect(fake.periodicRegistrations, isEmpty,
          reason: 'disabled means no work registered -- registering a 0-minute '
              'periodic task would be reinterpreted by WorkManager, not '
              'honored');
    });

    test('schedule reports false when the platform rejects the registration',
        () async {
      fake.throwOnRegister = true;
      final ok = await adapter.schedule(
          accountId: accountId, intervalMinutes: 60, caller: 'test');
      expect(ok, isFalse,
          reason: 'a platform failure must surface as false, never as a '
              'silent success -- the silent-claim failure mode ADR-0042 '
              'warns factories can hide');
    });

    // Sprint 79 7.7.1 H-2: a FAILED scheduler line names its reason, and
    // whether the Doze alarm was left armed. What this does NOT catch: the
    // Windows adapter's notes (its calls shell out to schtasks.exe; covered by
    // the source gate below), or a Doze alarm call that throws (the host has
    // no native side, so the alarm half reports false here).
    group('7.7.1 H-2: failure notes', () {
      test('an invalid interval says so', () async {
        final r = await adapter.scheduleDetailed(accountId, 0);
        expect(r.ok, isFalse);
        expect(r.note, 'invalid interval 0m');
      });

      test('a WorkManager registration failure carries the reason', () async {
        fake.throwOnRegister = true;
        final r = await adapter.scheduleDetailed(accountId, 60);
        expect(r.ok, isFalse);
        expect(r.note, contains('WorkManager failed:'));
        expect(r.note, contains('platform rejected registration'));
        expect(r.note, startsWith('Doze alarm'),
            reason: 'the note says what state the alarm half was left in');
      });

      test('a cancel failure names the step and that the alarm stays armed',
          () async {
        fake.throwOnCancelCall = 2; // the test one-off
        final r = await adapter.cancelDetailed(accountId);
        expect(r.ok, isFalse);
        expect(r.note, startsWith('test-task cancel failed; Doze alarm NOT '
            'cancelled: '));
        expect(r.note, contains('platform rejected cancel'));
      });
    });

    test(
        'cancel removes the per-account periodic work AND any pending test '
        'one-off (F175 R-6)', () async {
      await adapter.schedule(
          accountId: accountId, intervalMinutes: 60, caller: 'test');
      final ok = await adapter.cancel(accountId, caller: 'test');

      expect(ok, isTrue);
      expect(fake.cancelledUniqueNames, [
        AndroidSchedulerAdapter.uniqueNameFor(accountId),
        '${AndroidSchedulerAdapter.uniqueNameFor(accountId)}_test',
      ],
          reason: 'Sprint 61 escape: disabling background scanning cancelled '
              'only the periodic work, leaving a failed test one-off to '
              'retry at EVERY app launch until WorkManager\'s database was '
              'deleted by hand');
    });

    test('registrations carry the bounded exponential backoff (F175 R-6)',
        () async {
      await adapter.schedule(
          accountId: accountId, intervalMinutes: 60, caller: 'test');
      await adapter.runTestScan(accountId);

      expect(fake.periodicRegistrations.single['backoffPolicy'],
          BackoffPolicy.exponential,
          reason: 'a killed task must re-fire with backoff, not immediately '
              'at every app launch (the Sprint 61 retry re-detonation)');
      expect(fake.periodicRegistrations.single['backoffPolicyDelay'],
          const Duration(minutes: 10));
      expect(fake.oneOffRegistrations.single['backoffPolicy'],
          BackoffPolicy.exponential);
    });

    test('isScheduled round-trips through the platform query', () async {
      expect(await adapter.isScheduled(accountId), isFalse);
      await adapter.schedule(
          accountId: accountId, intervalMinutes: 60, caller: 'test');
      expect(await adapter.isScheduled(accountId), isTrue);
      await adapter.cancel(accountId, caller: 'test');
      expect(await adapter.isScheduled(accountId), isFalse);
    });

    test('runTestScan queues a one-off task through the SAME dispatcher path',
        () async {
      final ok = await adapter.runTestScan(accountId);
      expect(ok, isTrue);
      expect(fake.oneOffRegistrations, hasLength(1));
      final reg = fake.oneOffRegistrations.single;
      expect(reg['taskName'], 'spamfilter_background_scan_test',
          reason: 'the test task name is what tells the dispatcher to bypass '
              'the per-account enabled check (isTest), mirroring the Windows '
              'Test button semantics');
      expect((reg['inputData'] as Map)['accountId'], accountId);
    });
  });

  group('UnsupportedPlatformScheduler (the explicit no-op, ADR-0042)', () {
    const scheduler = UnsupportedPlatformScheduler('linux');

    test('cannot claim success for work no mechanism will run', () async {
      expect(scheduler.isSupported, isFalse);
      expect(
          await scheduler.schedule(
          accountId: accountId, intervalMinutes: 60, caller: 'test'),
          isFalse,
          reason: 'returning true would let a caller believe work was '
              'scheduled when nothing exists to run it -- the exact silent-'
              'failure class the explicit no-op rule prevents');
      expect(await scheduler.isScheduled(accountId), isFalse);
    });

    test('cancel is idempotently true (the post-condition already holds)',
        () async {
      expect(await scheduler.cancel(accountId, caller: 'test'), isTrue);
    });
  });

  group('BackgroundScanSchedulerFactory', () {
    tearDown(() => BackgroundScanSchedulerFactory.overrideForTest(null));

    test('the test override wins over platform resolution', () {
      const injected = UnsupportedPlatformScheduler('test');
      BackgroundScanSchedulerFactory.overrideForTest(injected);
      expect(identical(BackgroundScanSchedulerFactory.instance, injected),
          isTrue,
          reason: 'the override is the seam behavior tests inject fakes '
              'through; if platform resolution ever won over it, those tests '
              'would silently exercise the real platform');
    });
  });

  // Sprint 79 Task 1 R-9: every schedule/cancel leaves a diagnostic line.
  // What this does NOT catch: a cancel made outside these two adapters (none
  // exists in Dart today; native code cannot write this log).
  group('scheduler change log line (R-9)', () {
    test('names the masked account, interval, result and caller', () {
      expect(
          schedulerChangeLine(
              action: 'schedule',
              accountId: 'kimmeyh@gmail.com',
              intervalMinutes: 5,
              ok: true,
              caller: 'settings: background on'),
          'schedule k***@gmail.com every 5m ok (from settings: background on)');
      expect(
          schedulerChangeLine(
              action: 'cancel',
              accountId: 'kimmeyh@gmail.com',
              ok: false,
              caller: 'unknown'),
          'cancel k***@gmail.com FAILED (from unknown)');
    });

    // 7.7.1 Q3 (Harold, "q3 1"): the caller is a required label, not a
    // stack-trace guess. What this does NOT catch: a label that names the
    // wrong job (only review catches that).
    test('the caller label reaches the line; no stack-trace guess remains', () {
      expect(
          schedulerChangeLine(
              action: 'schedule',
              accountId: 'kimmeyh@gmail.com',
              intervalMinutes: 15,
              ok: true,
              caller: 'settings: background on'),
          'schedule k***@gmail.com every 15m ok (from settings: background on)');
      final src = File('lib/core/services/background_scan_scheduler.dart')
          .readAsStringSync();
      expect(src.contains('StackTrace.current'), isFalse);
      expect(src.contains('schedulerCallerFrom'), isFalse);
      expect(
          RegExp(r"_logSchedulerChange\('\w+',[^;]*caller: caller,")
              .allMatches(src)
              .length,
          4,
          reason: 'all four adapter calls pass their own label through');
    });

    test('the production call sites carry job labels', () {
      // `required` makes a missing label a compile error; this pins the
      // "<where>: <job>" form so the log stays readable.
      final label = RegExp(r"caller: '[a-z]+: [^']+'");
      expect(label.allMatches(File('lib/main.dart').readAsStringSync()).length,
          1);
      expect(
          label
              .allMatches(
                  File('lib/ui/screens/settings_screen.dart').readAsStringSync())
              .length,
          2);
    });

    // F-PRECHECK (Sprint 79): a Doze alarm that failed to arm or cancel while
    // WorkManager succeeded reached logcat only, so the log read a bare "ok".
    // What this does NOT catch: the native alarm reporting success for an
    // alarm it did not set (only a device log can show that).
    test('a failed Doze-alarm half is named beside ok', () {
      expect(
          schedulerChangeLine(
              action: 'cancel',
              accountId: 'kimmeyh@gmail.com',
              ok: true,
              caller: 'settings: background off',
              note: 'Doze alarm NOT cancelled'),
          'cancel k***@gmail.com ok (Doze alarm NOT cancelled) '
          '(from settings: background off)');
    });

    test('source gate: the Android adapter passes the alarm note through', () {
      final src = File('lib/core/services/background_scan_scheduler.dart')
          .readAsStringSync();
      expect(src, contains("note: alarmArmed ? null : 'Doze alarm NOT armed'"));
      expect(src,
          contains("note: alarmCancelled ? null : 'Doze alarm NOT cancelled'"));
      expect(
          RegExp(r"_logSchedulerChange\('android',[^;]*note: note\)")
              .allMatches(src)
              .length,
          2);
      // ...and the one log helper hands it to the line builder.
      expect(RegExp(r'detail: schedulerChangeLine\([^;]*note: note,').hasMatch(src),
          isTrue);
    });

    test('source gate (7.7.1 H-2): the Windows adapter logs a reason too', () {
      final src = File('lib/core/services/background_scan_scheduler.dart')
          .readAsStringSync();
      // Both Windows calls record the exception before rethrowing it, and
      // pass the note to the log.
      expect(
          RegExp(r'catch \(e\) \{\s*note = DiagnosticLogger\.describeError\(e\);\s*rethrow;')
              .allMatches(src)
              .length,
          2);
      expect(
          RegExp(r"_logSchedulerChange\('windows',[^;]*note: note\)")
              .allMatches(src)
              .length,
          2);
      expect(src, contains("note = 'invalid interval \${intervalMinutes}m'"));
    });

    test('source gate: both adapters log schedule AND cancel', () {
      final src = File('lib/core/services/background_scan_scheduler.dart')
          .readAsStringSync();
      for (final p in ['windows', 'android']) {
        for (final action in ['schedule', 'cancel']) {
          expect(
              RegExp("_logSchedulerChange\\('$p',\\s*action: '$action'")
                  .hasMatch(src),
              isTrue,
              reason: '$p $action');
        }
      }
    });
  });
}
