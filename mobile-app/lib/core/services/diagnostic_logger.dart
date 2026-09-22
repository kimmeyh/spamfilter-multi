import 'dart:io';

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

  /// Test seam: force the enabled state without touching the database.
  static void debugSetEnabled(bool? enabled) => _cachedEnabled = enabled;

  /// Test seam: force the directory, bypassing `path_provider`.
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

      final file = await _currentFile();
      await file.parent.create(recursive: true);
      await _rotateIfNeeded(file);

      final line = '[${DateTime.now().toIso8601String()}] '
          '[$kind] [$context] $detail\n';
      await file.writeAsString(line, mode: FileMode.append);
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
      if (entity is File && entity.path.endsWith('.bak')) rolls.add(entity);
    }
    rolls.sort((a, b) => b.path.compareTo(a.path));
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
