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

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

import 'package:my_email_spam_filter/core/services/app_environment.dart';
import 'package:my_email_spam_filter/core/services/background_scan_scheduler.dart';
import 'package:my_email_spam_filter/core/services/scan_frequency.dart';
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
    });
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    cancelledUniqueNames.add(uniqueName);
    scheduledNames.remove(uniqueName);
  }

  @override
  Future<bool> isScheduledByUniqueName(String uniqueName) async =>
      scheduledNames.contains(uniqueName);
}

void main() {
  const accountId = 'aol-user@aol.com';

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
          accountId: accountId, frequency: ScanFrequency.every1hour);

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

    test('schedule with disabled frequency refuses without touching WorkManager',
        () async {
      final ok = await adapter.schedule(
          accountId: accountId, frequency: ScanFrequency.disabled);
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
          accountId: accountId, frequency: ScanFrequency.every1hour);
      expect(ok, isFalse,
          reason: 'a platform failure must surface as false, never as a '
              'silent success -- the silent-claim failure mode ADR-0042 '
              'warns factories can hide');
    });

    test('cancel removes exactly the per-account unique name', () async {
      await adapter.schedule(
          accountId: accountId, frequency: ScanFrequency.every1hour);
      final ok = await adapter.cancel(accountId);

      expect(ok, isTrue);
      expect(fake.cancelledUniqueNames,
          [AndroidSchedulerAdapter.uniqueNameFor(accountId)]);
    });

    test('isScheduled round-trips through the platform query', () async {
      expect(await adapter.isScheduled(accountId), isFalse);
      await adapter.schedule(
          accountId: accountId, frequency: ScanFrequency.every1hour);
      expect(await adapter.isScheduled(accountId), isTrue);
      await adapter.cancel(accountId);
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
              accountId: accountId, frequency: ScanFrequency.every1hour),
          isFalse,
          reason: 'returning true would let a caller believe work was '
              'scheduled when nothing exists to run it -- the exact silent-'
              'failure class the explicit no-op rule prevents');
      expect(await scheduler.isScheduled(accountId), isFalse);
    });

    test('cancel is idempotently true (the post-condition already holds)',
        () async {
      expect(await scheduler.cancel(accountId), isTrue);
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
}
