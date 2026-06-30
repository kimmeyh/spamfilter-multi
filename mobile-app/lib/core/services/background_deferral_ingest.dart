/// F109c (Sprint 44): ingest background-scan deferral events recorded by the
/// native Windows runner (`windows/runner/main.cpp`).
///
/// WHY A HANDOFF FILE: a scheduled `--background-scan` process detects "the
/// foreground UI is running" via a read-only mutex probe in `main.cpp` and
/// exits BEFORE any Flutter/Dart/DB code runs (F98 / BUG-S37-1 DB-contention
/// protection). So the deferral cannot write a `background_scan_log` row
/// directly. Instead `main.cpp` appends one line per deferral to a handoff
/// TSV file in the app-support ROOT (`{appSupport}{suffix}/
/// background_scan_deferrals.tsv`) -- deliberately NOT under `logs/`, so the
/// email-derived account id stays out of the shareable log area (PR #266
/// Copilot review). This service -- run on the next FOREGROUND launch -- reads
/// the file, inserts a `status='deferred'` row per line into
/// `background_scan_log` (no DB migration; the table already has a `status`
/// column), then deletes the file (minimal retention).
///
/// Idempotent + best-effort: if the file is absent there is nothing to do; a
/// malformed line is skipped; ingest failure is logged and swallowed so it can
/// never block app startup.
library;

import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

import '../storage/background_scan_log_store.dart';
import 'live_scan_logger.dart';

/// The `status` value used for a deferred (skipped-because-UI-open) run.
const String kDeferredStatus = 'deferred';

/// File the native runner appends deferral records to. One line per deferral:
/// `<epochMillis>\t<accountId>`.
const String kDeferralHandoffFilename = 'background_scan_deferrals.tsv';

class BackgroundDeferralIngest {
  final BackgroundScanLogStore _logStore;
  final Logger _logger = Logger();

  /// Optional override for the handoff file's parent directory.
  /// Production leaves this null and resolves the app-support ROOT (the parent
  /// of the logs dir). Tests inject a temp dir so the ingest is exercisable
  /// without the path_provider plugin.
  final String? dirOverride;

  BackgroundDeferralIngest(this._logStore, {this.dirOverride});

  /// Resolve the handoff file path. The native runner writes it to the
  /// app-support ROOT (NOT logs/) so the email-derived account id stays out of
  /// the shareable log area (PR #266 Copilot review). [LiveScanLogger.getLogDir]
  /// returns `{appSupport}{suffix}/logs`, so the handoff dir is its PARENT.
  Future<String> _handoffPath() async {
    final dir = dirOverride ?? path.dirname(await LiveScanLogger.getLogDir());
    return path.join(dir, kDeferralHandoffFilename);
  }

  /// Read the handoff file, insert a `deferred` row per record, then delete the
  /// file. Returns the number of deferral rows ingested (0 when no file).
  /// Never throws -- safe to call unconditionally at startup.
  Future<int> ingest() async {
    try {
      final file = File(await _handoffPath());
      if (!await file.exists()) return 0;

      final lines = (await file.readAsLines())
          .where((l) => l.trim().isNotEmpty)
          .toList();

      var inserted = 0;
      for (final line in lines) {
        final parts = line.split('\t');
        if (parts.isEmpty) continue;
        final epochMillis = int.tryParse(parts[0].trim());
        if (epochMillis == null) continue; // malformed -> skip
        final accountId =
            parts.length > 1 ? parts[1].trim() : '';
        if (accountId.isEmpty) continue; // FK requires a real account
        await _logStore.insertLog(BackgroundScanLogEntry(
          accountId: accountId,
          scheduledTime: epochMillis,
          actualStartTime: epochMillis,
          actualEndTime: epochMillis,
          status: kDeferredStatus,
          errorMessage:
              'Deferred: foreground UI was open (background scans pause while the app is running).',
        ));
        inserted++;
      }

      // Consume the file so the same deferrals are not ingested twice.
      await file.delete();
      if (inserted > 0) {
        _logger.i('F109c: ingested $inserted background-scan deferral(s)');
      }
      return inserted;
    } catch (e) {
      // Best-effort: a failed ingest must never block startup.
      _logger.w('F109c: deferral ingest failed (non-fatal): $e');
      return 0;
    }
  }

  /// The most recent deferral across all accounts, or null if none recorded.
  /// Used by the Settings > Background status line ("last run deferred at ...").
  Future<BackgroundScanLogEntry?> latestDeferral() async {
    try {
      final deferred = await _logStore.getLogsByStatus(kDeferredStatus);
      return deferred.isEmpty ? null : deferred.first;
    } catch (e) {
      _logger.w('F109c: latestDeferral lookup failed (non-fatal): $e');
      return null;
    }
  }
}
