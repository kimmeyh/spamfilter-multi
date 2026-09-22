import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../storage/settings_store.dart';
import 'app_environment.dart';
import 'app_version.dart';

/// F233 (Sprint 72): a diagnostic log the user can actually hand over.
///
/// **Why this exists.** Sprint 71 found two defects that reproduce ON DEMAND --
/// F228 (a green success toast over a failed IMAP action) and F232 (rules from
/// a historical view never reaching the mailbox) -- and neither could be
/// diagnosed. The decisive facts were written by a bare `Logger()` from the
/// `logger` package, which has NO file sink configured: on an installed build
/// those lines go to a debug console that does not exist.
///
/// Confirmed two ways before writing this class: by reading the `Logger()`
/// construction at `results_display_screen.dart:359`, and empirically -- a grep
/// for "F38" across every Windows log in
/// `%APPDATA%\MyEmailSpamFilter\MyEmailSpamFilter\logs\` returned NOTHING,
/// across every version back to 0.5.8.
///
/// **What it deliberately does NOT do.** It is not a general logging framework
/// and it does not replace `AppLogger` or `LiveScanLogger`. It captures FAILURE
/// paths, off by default, so that when a user reports "it said it worked and it
/// did not" there is something to read.
///
/// **Cross-platform (ADR-0042).** Same behavior on Windows and Android: same
/// format, same rotation, same redaction. The OS behavior assumed identical is
/// file append and delete via `dart:io`, which both platforms provide. The ONE
/// declared difference is the default DIRECTORY -- Android needs a user-visible
/// location so the files can be deleted without the app, which is the
/// requirement Harold attached to retention. See [resolveLogDir].
class DiagnosticLogger {
  /// Outcome classes worth distinguishing in the log.
  ///
  /// **This distinction is the point of the card.** Today an `allFailed` guard
  /// trip and a thrown exception both surface to the user as "0 of N
  /// (N failed)", which is exactly why F232 carries two competing mechanisms
  /// that nobody can tell apart. A reader of this log must be able to.
  static const String kindNotConnected = 'NOT_CONNECTED';
  static const String kindServerRefused = 'SERVER_REFUSED';
  static const String kindSkipped = 'SKIPPED';
  static const String kindException = 'EXCEPTION';
  static const String kindInfo = 'INFO';

  /// Hard ceiling for a single log file. Rotation is not optional: Harold runs
  /// with this enabled permanently, and an unbounded append on a phone is a
  /// defect waiting to happen.
  static const int maxFileBytes = 2 * 1024 * 1024;

  /// How many rotated files to keep when "keep all" is OFF.
  static const int rotatedFilesKept = 3;

  static String? _cachedDir;
  static bool? _cachedEnabled;

  /// Serializes every write. **This is not defensive; it is load-bearing.**
  ///
  /// `File.writeAsString(mode: append)` is NOT a single atomic append -- it
  /// opens, writes and closes, and concurrent callers clobber one another.
  /// Measured on this machine (Phase 7 review, Sprint 72): ten concurrent
  /// appends produced THREE lines; two concurrent appends lost one entirely.
  ///
  /// That is reachable in production and is the worst possible failure for this
  /// class. Every call site uses `unawaited(...)`, so the futures are
  /// explicitly left to overlap -- and `generic_imap_adapter._parseUids` fires
  /// one per dropped message inside a `for` loop, so a batch with twenty bad
  /// ids launches twenty overlapping appends in a single synchronous pass.
  ///
  /// **The irony is the point**: this class exists because F232 could not be
  /// diagnosed, and without this chain it would silently drop the very failure
  /// records it was built to preserve -- sending the next investigation down
  /// the same blind alley.
  ///
  /// A single-slot future chain is enough: each write waits for the previous
  /// one. No package, no lock file.
  static Future<void> _writeTail = Future<void>.value();

  /// Drop both caches so the next call re-reads settings.
  ///
  /// **Call this whenever a setting this class depends on changes.** That means
  /// the diagnostic-log toggle AND the CSV export directory, because
  /// [resolveLogDir] prefers the user-chosen export directory.
  ///
  /// Phase 7 review, Sprint 72, two findings that share this one fix:
  ///   - the Settings toggle called `debugSetEnabled(null)` to clear the
  ///     enabled cache. It worked, but `debug*` is this repo's convention for a
  ///     test-only seam (`gmail_api_adapter.dart:56`: *"production code never
  ///     calls this"*), so a future reader who trusts that convention would
  ///     guard or delete it and silently break the toggle;
  ///   - `_cachedDir` was never invalidated at all. Changing the CSV export
  ///     directory left diagnostics writing to the OLD location for the rest of
  ///     the session -- and `totalBytes`/`deleteAll` then reported and cleared
  ///     the stale directory, so "Delete logs" would claim success while the
  ///     files the user was looking at stayed put.
  static void invalidateCache() {
    _cachedEnabled = null;
    _cachedDir = null;
  }

  /// Test seam: force the enabled state without touching the database.
  @visibleForTesting
  static void debugSetEnabled(bool? enabled) => _cachedEnabled = enabled;

  /// Test seam: force the directory, bypassing `path_provider`.
  @visibleForTesting
  static void debugSetDir(String? dir) => _cachedDir = dir;

  /// Resolve the directory the log is written to.
  ///
  /// **Order matters and encodes the platform difference.** The user-chosen CSV
  /// export directory wins when set, because that is the location the user can
  /// already reach from their file manager -- on Android that is what makes the
  /// files deletable without the app, which Harold made a condition of keeping
  /// them. Falling back to app support storage keeps Windows (and a phone with
  /// no configured directory) working.
  static Future<String> resolveLogDir() async {
    if (_cachedDir != null) return _cachedDir!;

    String? configured;
    try {
      configured = await SettingsStore().getCsvExportDirectory();
    } catch (_) {
      // A settings read must never be the reason logging fails.
      configured = null;
    }

    if (configured != null && configured.isNotEmpty) {
      _cachedDir = path.join(configured, 'diagnostics');
      return _cachedDir!;
    }

    final appSupport = await getApplicationSupportDirectory();
    _cachedDir = path.join(
      '${appSupport.path}${AppEnvironment.dataDirSuffix}',
      'logs',
    );
    return _cachedDir!;
  }

  static Future<bool> _enabled() async {
    if (_cachedEnabled != null) return _cachedEnabled!;
    try {
      return await SettingsStore().getDiagnosticLogEnabled();
    } catch (_) {
      // Default OFF on any failure -- never start writing files because a
      // settings read threw.
      return false;
    }
  }

  /// Append one diagnostic record.
  ///
  /// [kind] is one of the `kind*` constants; [context] names where it happened
  /// (e.g. `F38/delete-batch`); [detail] is the payload.
  ///
  /// **Never pass a message body or a credential.** Addresses must already be
  /// redacted by the caller via `Redact.email`; this method does not redact for
  /// you, because it cannot tell an address from ordinary text.
  ///
  /// Silent on failure by design: diagnostics must never break the operation
  /// they are describing.
  static Future<void> log({
    required String kind,
    required String context,
    required String detail,
  }) async {
    try {
      if (!await _enabled()) return;

      // Timestamp BEFORE queueing, so the recorded time is when the event
      // happened rather than when its turn in the queue came up.
      final line = '[${DateTime.now().toIso8601String()}] '
          '[$kind] [$context] $detail\n';

      // Chain onto the tail. `.then` after a `catchError` so one failed write
      // cannot poison every later one -- a broken chain would silently stop
      // all logging, which is the same class of defect as the clobbering.
      final queued = _writeTail.then((_) async {
        final file = await _currentFile();
        await file.parent.create(recursive: true);
        await _rotateIfNeeded(file);
        await file.writeAsString(line, mode: FileMode.append);
      }).catchError((Object _) {
        // Swallow so the chain survives; the caller already treats logging as
        // best-effort.
      });
      _writeTail = queued;
      await queued;
    } catch (_) {
      // Intentionally silent.
    }
  }

  /// Convenience for the commonest case: an operation that failed.
  static Future<void> failure({
    required String context,
    required String kind,
    required String reason,
    int? attempted,
    int? failed,
  }) {
    final counts = (attempted != null || failed != null)
        ? ' (attempted=${attempted ?? '?'}, failed=${failed ?? '?'})'
        : '';
    return log(kind: kind, context: context, detail: '$reason$counts');
  }

  static Future<File> _currentFile() async {
    final dir = await resolveLogDir();
    final version = await AppVersion.get();
    final prefix = AppEnvironment.logPrefix;

    bool keepAll = false;
    try {
      keepAll = await SettingsStore().getDiagnosticLogKeepAll();
    } catch (_) {
      // Fall back to the rolling single file. A settings failure must not
      // change WHETHER we log, only HOW MANY files we keep.
      keepAll = false;
    }

    if (keepAll) {
      // One file per day per version: identifiable, and still bounded because
      // _rotateIfNeeded applies to each.
      final day = DateTime.now().toIso8601String().split('T').first;
      return File(path.join(dir, '${prefix}diag_v${version}_$day.log'));
    }
    return File(path.join(dir, '${prefix}diag_v$version.log'));
  }

  /// Roll the file over once it exceeds [maxFileBytes].
  ///
  /// Keeps the most recent [rotatedFilesKept] rolls and deletes the rest, so a
  /// permanently-enabled log has a bounded footprint.
  static Future<void> _rotateIfNeeded(File file) async {
    if (!await file.exists()) return;
    final length = await file.length();
    if (length < maxFileBytes) return;

    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    await file.rename('${file.path}.$stamp.bak');

    final dir = Directory(path.dirname(file.path));
    final rolls = <File>[];
    await for (final entity in dir.list()) {
      // Filter with the same predicate totalBytes/deleteAll use. The old
      // check took EVERY .bak in the directory; nothing else writes one today,
      // so this was latent rather than live -- but the inconsistency is the
      // kind that becomes real the moment something else does.
      if (entity is File && _isDiagnosticFile(entity.path)) rolls.add(entity);
    }
    // Sort by the TRAILING TIMESTAMP, not the whole path.
    //
    // Phase 7 review, Sprint 72: the old `b.path.compareTo(a.path)` compared
    // whole filenames, which begin with the base name. In `keepAll` mode that
    // base name embeds the DAY, so several base names share the directory and
    // the day segment dominates -- which deleted the NEWEST roll while keeping
    // one six hours older. Confined to the mode a user opts into specifically
    // to retain MORE data, which makes it worse rather than obscure.
    //
    // The stamp is ISO-8601 with ':' replaced by '-', so it IS lexicographic
    // once isolated.
    String stampOf(File f) {
      final m = RegExp(r'\.([0-9T:-]+)\.bak$').firstMatch(f.path);
      return m != null ? m.group(1)! : '';
    }

    rolls.sort((a, b) => stampOf(b).compareTo(stampOf(a)));
    for (var i = rotatedFilesKept; i < rolls.length; i++) {
      try {
        await rolls[i].delete();
      } catch (_) {
        // A rotation failure must not stop logging.
      }
    }
  }

  /// Total bytes currently held by diagnostic logs.
  ///
  /// Shown next to the delete action so the user can see what they are
  /// carrying before deciding -- the honest half of "keep all log files".
  static Future<int> totalBytes() async {
    try {
      final dir = Directory(await resolveLogDir());
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is File && _isDiagnosticFile(entity.path)) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      // Reporting 0 bytes is honest when the directory cannot be read: the
      // number is shown next to a delete action, and claiming a size we could
      // not measure would be worse than claiming none.
      return 0;
    }
  }

  /// Delete every diagnostic log file. Returns how many were removed.
  ///
  /// Harold, 2026-09-21: *"if the user can easily get to them to delete the
  /// files"*. Deleting from inside the app is the answer to that -- the user is
  /// never required to find them in a file manager.
  static Future<int> deleteAll() async {
    try {
      final dir = Directory(await resolveLogDir());
      if (!await dir.exists()) return 0;
      var removed = 0;
      await for (final entity in dir.list()) {
        if (entity is File && _isDiagnosticFile(entity.path)) {
          try {
            await entity.delete();
            removed++;
          } catch (_) {
            // Skip a file that is locked; report what actually went.
          }
        }
      }
      return removed;
    } catch (_) {
      // Report 0 removed rather than claiming a deletion that did not happen.
      // The user can retry; a false "cleared" would leave them believing the
      // files are gone.
      return 0;
    }
  }

  static bool _isDiagnosticFile(String p) {
    final name = path.basename(p);
    return name.contains('diag_v') &&
        (name.endsWith('.log') || name.endsWith('.bak'));
  }
}
