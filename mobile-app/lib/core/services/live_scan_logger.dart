import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../providers/email_scan_provider.dart';
import '../storage/settings_store.dart';
import 'app_environment.dart';
import 'app_version.dart';
import 'export_directories.dart';
import 'scan_sheet_export.dart';
import '../../util/redact.dart';

/// F90 (Sprint 39, 2026-05-23): live-scan logging parity with background-scan
/// logs. Mirrors `BackgroundScanWindowsWorker._bgLog` and
/// `_exportDebugCsvIfEnabled` so live scans produce the same dual-log
/// artifacts (runtime log file + per-account per-day CSV/XLSX) that
/// background scans already produce.
///
/// Sourced from 2026-05-23 debug session where a safe-sender re-injection
/// pattern (F91) had to be reverse-engineered from the `email_actions`
/// table alone because live scans were not capturing logs to disk.
///
/// File layout (mirrors background-scan with `live_scan_` prefix):
///   - Runtime log:    `{logs}/{prefix}live_scan_v<version>.log`
///   - Per-account CSV: `{logs}/live_scan_{safe_email}_{date}{_dev}.data.csv`
///   - Per-account XLSX: `{logs}/live_scan_{safe_email}_{date}{_dev}.xlsx`
///
/// `{prefix}` is `dev_` in dev builds and empty in prod (per
/// `AppEnvironment.logPrefix`). `{_dev}` is `_dev` in dev and empty in
/// prod (matches background-scan CSV naming).
class LiveScanLogger {
  static String? _cachedLogDir;

  /// Resolve the log directory once via `path_provider`. MSIX-safe.
  /// Returns the environment-aware `{appSupport}{_Dev}/logs` path
  /// (matches `BackgroundScanWindowsWorker._getLogDir`).
  static Future<String> getLogDir() async {
    if (_cachedLogDir != null) return _cachedLogDir!;
    final appSupport = await getApplicationSupportDirectory();
    final envSuffix = AppEnvironment.dataDirSuffix;
    // Use platform-correct separators (path.join). Live scans run on all
    // platforms (Windows desktop, Android, iOS, macOS, Linux), unlike
    // `BackgroundScanWindowsWorker` which is Windows-only and hard-codes
    // backslashes. Concatenating `\\logs` here on Android would create a
    // literal "files\logs" directory name on the Linux filesystem.
    _cachedLogDir = path.join('${appSupport.path}$envSuffix', 'logs');
    return _cachedLogDir!;
  }

  /// Append a single line to the live-scan runtime log file.
  /// Format mirrors `_bgLog`: `[<iso-timestamp>] [LIVE] <message>\n`.
  /// Silent on failure (best-effort logging must not break the scan).
  static Future<void> log(String message) async {
    try {
      final logDir = await getLogDir();
      final logPrefix = AppEnvironment.logPrefix;
      // F-VERSION-DERIVE (Sprint 49): version comes from AppVersion (runtime,
      // pubspec-backed) -- never a hardcoded literal that drifts on a bump.
      final version = await AppVersion.get();
      final logFile = File(
        path.join(logDir, '${logPrefix}live_scan_v$version.log'),
      );
      final timestamp = DateTime.now().toIso8601String();
      await logFile.parent.create(recursive: true);
      await logFile.writeAsString(
        '[$timestamp] [LIVE] $message\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // Intentionally silent -- live-scan logging must never break the scan.
    }
  }

  /// Export the live scan's per-message rows to a per-account per-day
  /// CSV (always) and XLSX (regenerated from the CSV on every call).
  /// Gated by the `live_scan_debug_csv` app setting (default false) so
  /// users who do not want the artifacts can opt out. Mirrors
  /// `BackgroundScanWindowsWorker._exportDebugCsvIfEnabled`.
  ///
  /// Returns the number of rows appended this call (0 if disabled,
  /// excluded by an error, or `scanProvider.getExcelRows()` was empty
  /// and we wrote a single placeholder row).
  static Future<int> exportCsvIfEnabled({
    required EmailScanProvider scanProvider,
    required String accountId,
    required SettingsStore settingsStore,
  }) async {
    try {
      final enabled = await settingsStore.getLiveScanDebugCsv();
      if (!enabled) return 0;

      // F206 (Sprint 74): to the EXPORT folder (Settings > General, else the
      // platform default), not app-private logs -- on Android the user could
      // not reach the file at all. The runtime log stays in getLogDir().
      final exportDir = await ExportDirectories.resolve(
          subfolder: 'scan_exports', settingsStore: settingsStore);
      final redact = await settingsStore.getExportRedacted();
      final safeAccountId = accountId
          .replaceAll('@', '_at_')
          .replaceAll('.', '_');
      final result = await ScanSheetExport.appendAndWrite(
        dir: exportDir,
        filePrefix: 'live_scan',
        accountToken: safeAccountId,
        sheetName: 'Live Scan',
        headerColor: '#E2F3D9',
        newRows: scanProvider.getExcelRows(redact: redact),
      );
      await log(
        'Debug CSV exported for ${Redact.accountId(accountId)} '
        '(${result.addedRows} new rows, ${result.totalRows} total)',
      );
      return result.addedRows;
    } catch (e) {
      await log('Debug CSV export failed: $e');
      return 0;
    }
  }

}
