/// F161 (Sprint 61): the platform-agnostic background-scan scheduling contract,
/// plus the factory that resolves the right implementation per platform.
///
/// This is the canonical **platform factory** case from ADR-0042: the whole
/// CAPABILITY differs per platform (Windows Task Scheduler versus Android
/// WorkManager), while the contract -- schedule, reschedule, and cancel
/// per-account periodic work -- is identical. Callers talk to
/// [BackgroundScanScheduler] and contain no platform branch at all.
///
/// ADR-0042 requires three things of a factory, all honored here:
///   1. **Every implementation gets its own tests.** A shared interface with one
///      tested implementation is uneven coverage in a nicer wrapper -- which is
///      exactly the Sprint 60 shape, where accounts-row creation existed only on
///      the Windows path and Android silently persisted nothing for months.
///   2. **A deliberate no-op is an explicitly named class**, never an empty
///      method body. See [UnsupportedPlatformScheduler].
///   3. **The interface is the SHARED contract**, not the richer platform's
///      capabilities. Windows-only concepts (task-path repair, orphan-task
///      enumeration, the legacy global task) deliberately stay on
///      `WindowsTaskSchedulerService` rather than being forced into this
///      interface, where Android would have to no-op them.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:logger/logger.dart';
import 'package:workmanager/workmanager.dart';

import '../utils/account_id_sanitizer.dart';
import 'android_background_scan_worker.dart' show kAndroidScanTaskName, kAndroidScanTestTaskName;
import 'app_environment.dart';
import 'scan_frequency.dart';
import 'windows_task_scheduler_service.dart';

/// What every platform's background-scan scheduler must be able to do.
///
/// Deliberately small. Anything only one platform can do does NOT belong here.
abstract class BackgroundScanScheduler {
  /// Whether this platform can actually schedule background scans.
  ///
  /// Callers use this to decide what to OFFER, so the UI never presents a
  /// control that silently does nothing.
  bool get isSupported;

  /// Human-readable platform mechanism, for logs and diagnostics only --
  /// never for user-facing content (F167: Help describes the capability, not
  /// the mechanism).
  String get mechanismLabel;

  /// Is periodic work currently scheduled for [accountId]?
  Future<bool> isScheduled(String accountId);

  /// Schedule (or reschedule) periodic work for [accountId] at [frequency].
  ///
  /// Returns true on success. Implementations must be IDEMPOTENT: calling this
  /// when work already exists updates it rather than creating a duplicate --
  /// per-account uniqueness is the ADR-0039 invariant both platforms share.
  Future<bool> schedule({
    required String accountId,
    required ScanFrequency frequency,
  });

  /// Cancel periodic work for [accountId]. Returns true if it is gone
  /// afterwards, INCLUDING when nothing was scheduled to begin with -- cancel
  /// is idempotent by design, so a caller does not have to check first.
  Future<bool> cancel(String accountId);
}

/// The explicit no-op used on platforms with no scheduling mechanism.
///
/// ADR-0042 requires a deliberate no-op to be a NAMED class whose documentation
/// says it does nothing and why -- never an empty method body that a reader
/// cannot distinguish from an unfinished implementation.
///
/// [isSupported] is false, so callers can avoid offering scheduling at all
/// rather than offering it and having it silently fail.
class UnsupportedPlatformScheduler implements BackgroundScanScheduler {
  const UnsupportedPlatformScheduler(this._platformName);

  final String _platformName;

  @override
  bool get isSupported => false;

  @override
  String get mechanismLabel => 'none ($_platformName)';

  /// Always false: nothing can be scheduled, so nothing is ever scheduled.
  @override
  Future<bool> isScheduled(String accountId) async => false;

  /// Always false -- and deliberately so. Returning true would let a caller
  /// believe work was scheduled when no mechanism exists to run it, which is
  /// the silent-failure class this whole design is built to prevent.
  @override
  Future<bool> schedule({
    required String accountId,
    required ScanFrequency frequency,
  }) async =>
      false;

  /// True: there is nothing scheduled, so the post-condition "not scheduled"
  /// already holds. Cancel is idempotent.
  @override
  Future<bool> cancel(String accountId) async => true;
}

/// Resolves the scheduler for the current platform.
///
/// The ONE place the platform decision is made. Everything downstream is
/// platform-free (ADR-0042 requirement 1: fork at the narrowest possible point).
class BackgroundScanSchedulerFactory {
  BackgroundScanSchedulerFactory._();

  static BackgroundScanScheduler? _override;

  /// Injects a scheduler for tests, so a test never has to mock `dart:io`.
  @visibleForTesting
  static void overrideForTest(BackgroundScanScheduler? scheduler) =>
      _override = scheduler;

  /// The scheduler for the current platform.
  static BackgroundScanScheduler get instance {
    final override = _override;
    if (override != null) return override;

    if (Platform.isWindows) return const WindowsSchedulerAdapter();
    if (Platform.isAndroid) return const AndroidSchedulerAdapter();

    // iOS/macOS/Linux are architecturally supported but have no scheduling
    // implementation. An explicit unsupported scheduler beats a crash or a
    // silent success.
    return UnsupportedPlatformScheduler(Platform.operatingSystem);
  }
}

/// Windows implementation -- delegates to the existing per-account Task
/// Scheduler service (ADR-0039). Deliberately a thin adapter: the Windows
/// service keeps its richer Windows-only API (path repair, orphan enumeration),
/// and only the shared contract is exposed here.
class WindowsSchedulerAdapter implements BackgroundScanScheduler {
  const WindowsSchedulerAdapter();

  @override
  bool get isSupported => true;

  @override
  String get mechanismLabel => 'Windows Task Scheduler';

  @override
  Future<bool> isScheduled(String accountId) =>
      WindowsTaskSchedulerService.taskExists(accountId: accountId);

  @override
  Future<bool> schedule({
    required String accountId,
    required ScanFrequency frequency,
  }) async {
    if (frequency == ScanFrequency.disabled) return false;
    // Idempotent per the interface contract: update when a task already
    // exists, create otherwise. This mirrors what settings_screen did inline
    // before F161 moved the decision behind the interface.
    final exists =
        await WindowsTaskSchedulerService.taskExists(accountId: accountId);
    return exists
        ? WindowsTaskSchedulerService.updateScheduledTask(
            frequency: frequency, accountId: accountId)
        : WindowsTaskSchedulerService.createScheduledTask(
            frequency: frequency, accountId: accountId);
  }

  @override
  Future<bool> cancel(String accountId) =>
      WindowsTaskSchedulerService.deleteScheduledTask(accountId: accountId);
}

/// Android implementation -- WorkManager per-account unique periodic work,
/// mirroring the Windows per-account Task Scheduler model (ADR-0039; F144
/// established the 1:1 mapping).
///
/// Android-specific constraints, DECLARED per ADR-0042:
///   - **15-minute floor**: WorkManager cannot run periodic work more often
///     than every 15 minutes. `ScanFrequency.every15min` is the app's own
///     minimum, so the floor guard below is defensive rather than reachable
///     through the UI today.
///   - **Inexact timing**: Android batches periodic work for battery (Doze,
///     App Standby); a "15 minutes" task fires approximately, not on the
///     minute. Windows Task Scheduler is exact. Accepted difference -- the
///     scan is periodic hygiene, not a deadline.
///   - **Network constraint**: registered with `NetworkType.connected`, since
///     an IMAP scan without a network can only fail and burn the work budget.
class AndroidSchedulerAdapter implements BackgroundScanScheduler {
  const AndroidSchedulerAdapter();

  @override
  bool get isSupported => true;

  @override
  String get mechanismLabel => 'Android WorkManager';

  /// Unique WorkManager name for [accountId] -- mirrors the Windows
  /// `SpamFilterBackgroundScan_<sanitizedAccountId><envSuffix>` convention
  /// (same sanitizer, same env suffix) so the per-account + per-environment
  /// uniqueness invariant is identical on both platforms.
  static String uniqueNameFor(String accountId) =>
      '${kAndroidScanTaskName}_${sanitizeAccountId(accountId)}'
      '${AppEnvironment.taskNameSuffix}';

  @override
  Future<bool> isScheduled(String accountId) async {
    try {
      return await Workmanager()
          .isScheduledByUniqueName(uniqueNameFor(accountId));
    } catch (e) {
      // Query failure must not masquerade as "not scheduled" silently -- but
      // the interface returns bool, so log loudly and report false (callers
      // treat unknown as re-schedulable; schedule() is idempotent).
      Logger().w('WorkManager isScheduled query failed: $e');
      return false;
    }
  }

  @override
  Future<bool> schedule({
    required String accountId,
    required ScanFrequency frequency,
  }) async {
    if (frequency == ScanFrequency.disabled) return false;
    try {
      // Declared floor guard (see class doc): unreachable via the UI today
      // because every15min is already the app minimum, but a future frequency
      // below 15 minutes must clamp rather than let WorkManager reject or
      // silently reinterpret the request.
      final minutes = frequency.minutes < 15 ? 15 : frequency.minutes;

      await Workmanager().registerPeriodicTask(
        uniqueNameFor(accountId),
        kAndroidScanTaskName,
        frequency: Duration(minutes: minutes),
        inputData: {'accountId': accountId},
        constraints: Constraints(networkType: NetworkType.connected),
        // Idempotent per the interface contract: re-registering the same
        // unique name UPDATES the existing work (frequency changes take
        // effect) instead of duplicating it or keeping the stale schedule.
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        // F175 R-6 (Sprint 62): a killed task re-fires with EXPONENTIAL
        // backoff instead of immediately at every app launch. During the
        // Sprint 61 validation, a crashing scan re-detonated on each
        // relaunch (WorkManager retries persisted work until it ever
        // succeeds), stacking concurrent scans. Backoff bounds the blast
        // radius; the F177 memory fix removes the crash cause itself.
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 10),
      );
      return true;
    } catch (e) {
      Logger().e('WorkManager schedule failed for account: $e');
      return false;
    }
  }

  @override
  Future<bool> cancel(String accountId) async {
    try {
      await Workmanager().cancelByUniqueName(uniqueNameFor(accountId));
      // F175 R-6 (Sprint 62): also cancel any pending TEST one-off.
      // Disabling background scanning used to cancel only the periodic
      // work, leaving a failed test task to retry at every app launch
      // FOREVER (the Sprint 61 stuck-retry that had to be cleared by
      // deleting WorkManager's database by hand). Cancel-with-nothing-
      // pending is a no-op, per the interface's idempotent-cancel rule.
      await Workmanager()
          .cancelByUniqueName('${uniqueNameFor(accountId)}_test');
      return true;
    } catch (e) {
      Logger().e('WorkManager cancel failed: $e');
      return false;
    }
  }

  /// Run the background pipeline ONCE, immediately -- the Android counterpart
  /// of the Windows "Test Background Scan" button, which verifies scheduler,
  /// credentials, and rules line up before trusting the scheduled run.
  Future<bool> runTestScan(String accountId) async {
    try {
      await Workmanager().registerOneOffTask(
        '${uniqueNameFor(accountId)}_test',
        kAndroidScanTestTaskName,
        inputData: {'accountId': accountId},
        constraints: Constraints(networkType: NetworkType.connected),
        // F175 R-6: same bounded backoff as the periodic task -- a crashed
        // test scan must not re-detonate immediately at every app launch.
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 10),
      );
      return true;
    } catch (e) {
      Logger().e('WorkManager test scan failed: $e');
      return false;
    }
  }
}
