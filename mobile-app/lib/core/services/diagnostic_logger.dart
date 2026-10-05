import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../util/redact.dart';
import '../storage/settings_store.dart';
import 'app_environment.dart';
import 'app_version.dart';
import 'export_directories.dart';

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
/// and it does not replace `AppLogger` or `LiveScanLogger`. It is off by
/// default, and when on it captures the events a field report needs.
///
/// **Scope widened by F248 (Sprint 76).** It used to capture FAILURE paths
/// only (re-processing and a few IMAP batch problems) -- and that left the
/// 0.17.0 phone defects undiagnosable: a background scan stuck at Found 0 and
/// a Gmail sign-in that fell back to the browser wrote nothing at all. It now
/// also records each scan's stages ([kindScan], for every scan type and
/// platform), Gmail sign-in steps ([kindSignIn]) and app start / logging-on
/// lines ([kindApp]). `LiveScanLogger` was checked and is not a substitute: it
/// covers manual scans only and writes to app-private storage, which cannot
/// be reached on Android.
///
/// **Two writers.** The UI and a background worker (another isolate on
/// Android, another process on Windows) can append to the same file. Each
/// record is one small append, so the worst case is lines from the two
/// writers interleaving -- every line carries its own timestamp and context.
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

  /// F248 (Sprint 76): a scan stage -- start, claim, connect, fetch, stop
  /// request, outcome. Written for manual, background and test scans alike.
  static const String kindScan = 'SCAN';

  /// F248: a Gmail sign-in step -- which call ran, how it ended, whether the
  /// browser fallback was taken.
  static const String kindSignIn = 'SIGN_IN';

  /// F248: app start and "logging turned on" -- so the file exists as soon as
  /// logging is on, and a reader can see which build wrote what follows.
  static const String kindApp = 'APP';

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
  /// The export folder's `diagnostics` subfolder (F206, Sprint 74): the
  /// user-chosen folder when set, else the platform default (Android
  /// Documents, Windows Downloads) -- a location the user can reach from a
  /// file manager, which on Android is what makes the files deletable without
  /// the app, a condition Harold set for keeping them. Before F206 the
  /// no-folder case fell back to app-private storage, unreachable on Android.
  /// App support remains only as the last resort if no export folder resolves,
  /// so logging never stops.
  static Future<String> resolveLogDir() async {
    // F206 R-7: drop the cached folder whenever the export folder changes
    // (registered once; the store ignores a duplicate).
    SettingsStore.addExportDirectoryListener(invalidateCache);
    if (_cachedDir != null) return _cachedDir!;

    // F206 (Sprint 74): the export folder's `diagnostics` subfolder -- the
    // user's chosen folder if set, else the platform default (Android
    // Documents, Windows Downloads). It used to fall back to app-private
    // storage, which on Android meant the log could not be retrieved at all
    // unless a folder had been configured first. A resolution failure still
    // falls back to app support, so logging never stops.
    try {
      // Environment-suffixed (review I-1, ADR-0035): DEV and PROD resolve
      // the SAME export folder, and "Delete logs" / rotation in one must
      // never touch the other's files.
      final sub = 'diagnostics${AppEnvironment.dataDirSuffix}';
      // F248 R-8: a user who picks the diagnostics folder ITSELF as the
      // export folder (found on the Fold, 2026-10-04: the log landed in
      // Documents/diagnostics/diagnostics) gets the log in that folder, not
      // one level deeper.
      String? chosen;
      try {
        chosen = await SettingsStore().getCsvExportDirectory();
      } catch (_) {
        chosen = null;
      }
      final alreadyThere =
          chosen != null && chosen.isNotEmpty && path.basename(chosen) == sub;
      _cachedDir = await ExportDirectories.resolve(
          subfolder: alreadyThere ? null : sub);
      return _cachedDir!;
    } catch (_) {
      final appSupport = await getApplicationSupportDirectory();
      _cachedDir = path.join(
        '${appSupport.path}${AppEnvironment.dataDirSuffix}',
        'logs',
      );
      return _cachedDir!;
    }
  }

  static Future<bool> _enabled() async {
    if (_cachedEnabled != null) return _cachedEnabled!;
    try {
      // F248 (Sprint 76): CACHE what was read. Before, every log call read the
      // setting from the database -- harmless while the log had a handful of
      // failure lines, but F248 puts a line at every scan stage and on UI
      // paths, so each became a database query (and, in widget tests, a
      // sqflite timer still pending when a test ended). The Settings toggle
      // already calls [invalidateCache] when it changes, so the cache cannot
      // go stale in this isolate; a background worker reads it once per run.
      return _cachedEnabled = await SettingsStore().getDiagnosticLogEnabled();
    } catch (_) {
      // Default OFF on any failure -- never start writing files because a
      // settings read threw.
      return false;
    }
  }

  /// The most recent write failure in THIS isolate (null after a successful
  /// write). Review MEDIUM-3 (Sprint 76): read by Settings.
  static String? lastWriteError;

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
        lastWriteError = null;
      }).catchError((Object e) {
        // Swallow so the chain survives; the caller already treats logging as
        // best-effort. Review MEDIUM-3 (Sprint 76): but REMEMBER it, so
        // Settings can say the log is not being written instead of showing a
        // confident "Writing to: <folder>".
        lastWriteError = scrub(e.toString());
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

  static final RegExp _addressInText =
      RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');

  /// F248 R-5: redact every email address inside free text (an exception
  /// message can carry one -- "No credentials found for account x@y").
  static String scrub(String text) =>
      text.replaceAllMapped(_addressInText, (m) => Redact.email(m.group(0)));

  /// F248: an error as `<Type>: <scrubbed message>`, capped so one huge
  /// message cannot flood the file.
  static String describeError(Object error) {
    final text = scrub(error.toString());
    final capped = text.length > 300 ? '${text.substring(0, 300)}...' : text;
    return '${error.runtimeType}: $capped';
  }

  /// F248 R-4: an app-level record (start, logging turned on) carrying the
  /// build that wrote what follows. No address, nothing private.
  static Future<void> appEvent(String what) async {
    String version;
    try {
      version = await AppVersion.get();
    } catch (_) {
      version = '?';
    }
    return log(
      kind: kindApp,
      context: 'app',
      detail: '$what -- v$version env=${AppEnvironment.current} '
          'platform=${Platform.operatingSystem}',
    );
  }

  /// F248: one scan-stage record, with the account redacted.
  ///
  /// [scanType] is `manual`, `background` or `demo`; [stage] is a short
  /// fixed word (`start`, `claim`, `connect`, `fetch`, `stop-request`,
  /// `outcome` ...) so a reader can grep for it; [detail] must not contain an
  /// unredacted address, a subject or a token.
  static Future<void> scanEvent({
    required String scanType,
    required String accountId,
    required String stage,
    String detail = '',
  }) {
    final tail = detail.isEmpty ? '' : ' -- $detail';
    return log(
      kind: kindScan,
      context: 'scan/$scanType',
      detail: '${Redact.accountId(accountId)} $stage$tail',
    );
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
