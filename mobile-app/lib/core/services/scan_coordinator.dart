/// F175 (Sprint 62): in-process scan mutual exclusion + active-scan registry.
///
/// Harold's requirement (2026-08-19, verbatim intent): background scans must
/// not run concurrently with each other, background must not run concurrently
/// with manual live scans, and a manual scan must be able to DETECT an active
/// background scan and tell the user to wait, with an average completion time
/// where reasonably computable.
///
/// Why this exists: during the Sprint 61 F161 validation, four AOL scans
/// stacked concurrently (2 periodic + 1 test + 1 background retry + a manual
/// scan), each opening its own IMAP session; the earliest hung and the rest
/// queued behind AOL's per-account session cap -- all sat `in_progress` at
/// 0 emails for 20+ minutes over a ~140-email mailbox.
///
/// ONE acquisition chokepoint: `EmailScanner.scanInbox` acquires a lease
/// before connecting and releases it in its `finally`, so EVERY scan type
/// (manual, background, test, demo) is serialized within a process. Waiters
/// queue FIFO; a crashed scan releases its lease via the same `finally`
/// (T-1 pins release-on-failure).
///
/// **Declared platform exception (ADR-0042)**: on Windows, background scans
/// run in a SEPARATE headless process (Task Scheduler, ADR-0039), which an
/// in-process lock cannot see. Cross-process exclusion there is already
/// provided by the existing F109 foreground-deferral + per-account task
/// serialization -- duplicating that OS-level mechanism here would be a
/// second source of truth. On Android every scan shares one process, so this
/// coordinator IS the whole guarantee. Cross-process DETECTION (the manual-
/// scan notice) is platform-uniform via the shared database instead -- see
/// [ScanResultStore.getActiveBackgroundScan].
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logger/logger.dart';

/// What is currently scanning, for detection and diagnostics.
class ActiveScanInfo {
  ActiveScanInfo({
    required this.scanType,
    required this.accountId,
    required this.startedAt,
  });

  final String scanType;
  final String accountId;
  final DateTime startedAt;
}

/// A granted right to scan. Pass back to [ScanCoordinator.release] exactly
/// once, in a `finally`.
class ScanLease {
  ScanLease._(this.info);
  final ActiveScanInfo info;
  bool _released = false;
}

class ScanCoordinator {
  ScanCoordinator._();

  static ScanCoordinator _instance = ScanCoordinator._();
  static ScanCoordinator get instance => _instance;

  /// Reset to a fresh coordinator -- tests only (the singleton is
  /// process-global and tests must not inherit each other's lease state).
  @visibleForTesting
  static void resetForTest() {
    _instance = ScanCoordinator._();
  }

  /// F175 R-4: the hard ceiling on how long any single scan may hold the
  /// lease (and, by extension, how long a queued scan can be kept waiting
  /// by ONE predecessor). A scan exceeding this is failed with a timeout
  /// error instead of sitting `in_progress` forever -- see
  /// BackgroundScanCore's timeout wrap and
  /// ScanResultStore.reconcileStaleInProgressScans, which both use it.
  static const Duration scanTimeout = Duration(minutes: 30);

  final Logger _logger = Logger();

  ActiveScanInfo? _active;
  final Queue<_Waiter> _waiters = Queue();

  /// The currently-scanning holder, or null when idle. In-process view only
  /// (see the class doc for the Windows cross-process exception).
  ActiveScanInfo? get active => _active;

  /// Acquire the process-wide scan lease. Completes immediately when idle;
  /// otherwise queues FIFO behind the active scan and any earlier waiters.
  ///
  /// [waitLimit] bounds the queue wait (default: [scanTimeout], the worst
  /// case for one predecessor). On expiry the waiter is removed and a
  /// [TimeoutException] is thrown -- a scan must never wait forever on a
  /// lease a dead scan failed to release.
  Future<ScanLease> acquire({
    required String scanType,
    required String accountId,
    Duration? waitLimit,
  }) async {
    final info = ActiveScanInfo(
      scanType: scanType,
      accountId: accountId,
      startedAt: DateTime.now(),
    );

    if (_active == null && _waiters.isEmpty) {
      _active = info;
      _logger.i('ScanCoordinator: lease granted immediately '
          '($scanType, queue empty)');
      return ScanLease._(info);
    }

    _logger.i('ScanCoordinator: $scanType scan queued behind '
        '${_active?.scanType ?? "queued predecessors"} '
        '(${_waiters.length} already waiting)');
    final waiter = _Waiter(info);
    _waiters.add(waiter);

    try {
      return await waiter.completer.future
          .timeout(waitLimit ?? scanTimeout);
    } on TimeoutException {
      _waiters.remove(waiter);
      _logger.e('ScanCoordinator: $scanType scan gave up waiting for the '
          'lease after ${(waitLimit ?? scanTimeout).inMinutes} minutes');
      rethrow;
    }
  }

  /// Release [lease] and hand the lease to the next FIFO waiter, if any.
  /// Idempotent: releasing twice (or releasing a stale lease after the
  /// coordinator was reset) is a logged no-op, never an error -- release
  /// lives in `finally` blocks and must be safe on every path.
  void release(ScanLease lease) {
    if (lease._released) return;
    lease._released = true;

    if (!identical(_active, lease.info)) {
      _logger.w('ScanCoordinator: released a non-active lease '
          '(${lease.info.scanType}) -- ignoring');
      return;
    }

    if (_waiters.isEmpty) {
      _active = null;
      _logger.i('ScanCoordinator: lease released, idle');
      return;
    }

    final next = _waiters.removeFirst();
    next.info = ActiveScanInfo(
      scanType: next.info.scanType,
      accountId: next.info.accountId,
      startedAt: DateTime.now(),
    );
    _active = next.info;
    _logger.i('ScanCoordinator: lease handed to queued '
        '${next.info.scanType} scan (${_waiters.length} still waiting)');
    next.completer.complete(ScanLease._(next.info));
  }
}

class _Waiter {
  _Waiter(this.info);
  ActiveScanInfo info;
  final Completer<ScanLease> completer = Completer<ScanLease>();
}
