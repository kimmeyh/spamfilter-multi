import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../providers/email_scan_provider.dart';
import '../storage/settings_store.dart';
import 'app_environment.dart';
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
///   - Runtime log:    `{logs}/{prefix}live_scan_v0.5.4.log`
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
      final logFile = File(
        path.join(logDir, '${logPrefix}live_scan_v0.5.4.log'),
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

      final exportDir = await getLogDir();
      final dir = Directory(exportDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final safeAccountId = accountId
          .replaceAll('@', '_at_')
          .replaceAll('.', '_');
      final dateStr = DateTime.now().toIso8601String().split('T')[0];
      final devSuffix = AppEnvironment.isDev ? '_dev' : '';
      final xlsxFilename = 'live_scan_${safeAccountId}_$dateStr$devSuffix.xlsx';
      final dataFilename = 'live_scan_${safeAccountId}_$dateStr$devSuffix.data.csv';
      final xlsxPath = path.join(exportDir, xlsxFilename);
      final dataPath = path.join(exportDir, dataFilename);

      final newRows = scanProvider.getExcelRows();

      final dataFile = File(dataPath);
      final buffer = StringBuffer();

      if (newRows.isEmpty) {
        final scanDate = DateTime.now().toIso8601String();
        buffer.writeln('$scanDate\t$scanDate\t\t\t\t\t<no records to process>\t\t\t');
      } else {
        for (final row in newRows) {
          buffer.writeln(row.join('\t'));
        }
      }

      await dataFile.writeAsString(
        buffer.toString(),
        mode: FileMode.append,
      );

      final allDataLines = (await dataFile.readAsString())
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      const headers = [
        'Scan Date and Time',
        'Received Date and Time',
        'Status',
        'Folder',
        'Action',
        'Rule',
        'From',
        'Subject',
        'Match Condition',
        'Email ID',
      ];

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.name = 'Live Scan';

      for (var col = 0; col < headers.length; col++) {
        final cell = sheet.getRangeByIndex(1, col + 1);
        cell.setText(headers[col]);
        cell.cellStyle.bold = true;
        cell.cellStyle.backColor = '#E2F3D9';
      }

      for (var row = 0; row < allDataLines.length; row++) {
        final cells = allDataLines[row].split('\t');
        for (var col = 0; col < cells.length && col < headers.length; col++) {
          sheet.getRangeByIndex(row + 2, col + 1).setText(cells[col]);
        }
      }

      for (var col = 1; col <= headers.length; col++) {
        sheet.autoFitColumn(col);
      }

      final bytes = workbook.saveAsStream();
      await File(xlsxPath).writeAsBytes(bytes);
      workbook.dispose();

      final addedRows = newRows.isEmpty ? 1 : newRows.length;
      await log(
        'Debug CSV exported for ${Redact.accountId(accountId)} '
        '($addedRows new rows, ${allDataLines.length} total)',
      );
      return addedRows;
    } catch (e) {
      await log('Debug CSV export failed: $e');
      return 0;
    }
  }

}
