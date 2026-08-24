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
      // remove() returns true when the waiter WAS found and removed here --
      // false means release() already popped it (naming per PR #355 review).
      final removedFromQueue = _waiters.remove(waiter);
      if (!removedFromQueue) {
        // Sprint 62 code review (C-1), defensive: release() popped this
        // waiter around the moment the timeout fired, so the lease it
        // granted belongs to a caller that is throwing -- hand it straight
        // back, or `_active` stays pinned to a scan that will never run
        // and the coordinator is wedged until app restart. Analysis (and a
        // fakeAsync reproduction attempt) says the single-threaded event
        // loop cannot actually open this gap today; the guard is kept
        // because it costs nothing and the wedge would be permanent.
        unawaited(waiter.completer.future.then(release));
      }
      // PR #355 review: inMinutes truncates a sub-minute limit to
      // "0 minutes" -- log seconds below one minute.
      final limit = waitLimit ?? scanTimeout;
      final limitText = limit.inMinutes >= 1
          ? '${limit.inMinutes} minutes'
          : '${limit.inSeconds} seconds';
      _logger.e('ScanCoordinator: $scanType scan gave up waiting for the '
          'lease after $limitText');
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

    _handOffOrIdle();
  }

  /// Force-release the active lease WITHOUT its [ScanLease] handle -- for
  /// the background-scan timeout path (Sprint 62 code review, C-2), where
  /// the hung scan still holds the lease object inside its own stack and
  /// its `finally` will not run until (unless) the hang ever resolves.
  ///
  /// Releases ONLY when the active holder matches [scanType] AND
  /// [accountId], so a timeout can never evict an unrelated live scan --
  /// in particular, a timed-out scan that was still QUEUED (never active)
  /// must not free somebody else's lease. If the zombie scan later
  /// completes, its own `finally` releases a stale lease, which the
  /// `identical()` guard above already ignores.
  void releaseActiveByOwner({
    required String scanType,
    required String accountId,
  }) {
    final holder = _active;
    if (holder == null) return;
    if (holder.scanType != scanType || holder.accountId != accountId) {
      _logger.w('ScanCoordinator: timeout force-release skipped -- the '
          'active holder is a ${holder.scanType} scan, not the timed-out '
          '$scanType scan');
      return;
    }
    _logger.w('ScanCoordinator: force-releasing the ${holder.scanType} '
        'lease -- its scan timed out without completing');
    _handOffOrIdle();
  }

  /// Hand the lease to the next LIVE FIFO waiter, or go idle. Waiters whose
  /// completer already completed (timed out in the C-1 race) are drained
  /// and skipped -- their acquire() side hands any granted lease back via
  /// release(), never runs a scan on it.
  void _handOffOrIdle() {
    while (_waiters.isNotEmpty) {
      final next = _waiters.removeFirst();
      if (next.completer.isCompleted) continue;
      next.info = ActiveScanInfo(
        scanType: next.info.scanType,
        accountId: next.info.accountId,
        startedAt: DateTime.now(),
      );
      _active = next.info;
      _logger.i('ScanCoordinator: lease handed to queued '
          '${next.info.scanType} scan (${_waiters.length} still waiting)');
      next.completer.complete(ScanLease._(next.info));
      return;
    }
    _active = null;
    _logger.i('ScanCoordinator: lease released, idle');
  }
}

class _Waiter {
  _Waiter(this.info);
  ActiveScanInfo info;
  final Completer<ScanLease> completer = Completer<ScanLease>();
}
