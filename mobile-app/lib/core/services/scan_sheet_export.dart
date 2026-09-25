/// F206 (Sprint 74): the per-scan CSV/XLSX export, shared by the live-scan and
/// background-scan exporters.
///
/// Both previously carried their own copy of this body, differing only in the
/// file prefix, sheet name and header colour. The background copy lived in the
/// WINDOWS worker, so Android's "export CSV after each background scan" toggle
/// did nothing at all (F206 finding). One body, called from both platforms'
/// workers and from live scans, ends that.
///
/// Format is unchanged: a daily `<prefix>_<account>_<date>{_dev}.data.csv`
/// accumulator (tab-separated) plus a regenerated `.xlsx` of every row so far.
library;

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../providers/email_scan_provider.dart';
import '../storage/settings_store.dart';
import '../utils/account_id_sanitizer.dart';
import 'app_environment.dart';
import 'export_directories.dart';

/// The 11 export columns (Sprint 25 order + the Sprint 43 auth column).
const List<String> scanSheetHeaders = [
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
  // F110 (Sprint 43): comma-separated list of the SPF/DKIM/DMARC checks this
  // email HARD-FAILED (e.g. "SPF,DMARC"); blank when none failed.
  'Phishing SPF/DKIM/DMARC',
];

/// Outcome of one append.
class ScanSheetExportResult {
  final int addedRows;
  final int totalRows;
  final String xlsxPath;
  const ScanSheetExportResult(this.addedRows, this.totalRows, this.xlsxPath);
}

class ScanSheetExport {
  ScanSheetExport._();

  /// Append [newRows] to today's accumulator in [dir] and rewrite the workbook.
  /// An empty scan still writes one placeholder row, so the file shows the
  /// scan ran.
  static Future<ScanSheetExportResult> appendAndWrite({
    required String dir,
    required String filePrefix,
    required String accountToken,
    required String sheetName,
    required String headerColor,
    required List<List<String>> newRows,
  }) async {
    final dateStr = DateTime.now().toIso8601String().split('T')[0];
    final devSuffix = AppEnvironment.isDev ? '_dev' : '';
    final base = '${filePrefix}_${accountToken}_$dateStr$devSuffix';
    final xlsxPath = path.join(dir, '$base.xlsx');
    final dataFile = File(path.join(dir, '$base.data.csv'));

    final buffer = StringBuffer();
    if (newRows.isEmpty) {
      final scanDate = DateTime.now().toIso8601String();
      // 11 columns; the "<no records>" marker sits in the From column.
      buffer.writeln(
          '$scanDate\t$scanDate\t\t\t\t\t<no records to process>\t\t\t\t');
    } else {
      for (final row in newRows) {
        buffer.writeln(row.join('\t'));
      }
    }
    await dataFile.writeAsString(buffer.toString(), mode: FileMode.append);

    final allDataLines = (await dataFile.readAsString())
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final workbook = xlsio.Workbook();
    try {
      final sheet = workbook.worksheets[0];
      sheet.name = sheetName;
      for (var col = 0; col < scanSheetHeaders.length; col++) {
        final cell = sheet.getRangeByIndex(1, col + 1);
        cell.setText(scanSheetHeaders[col]);
        cell.cellStyle.bold = true;
        cell.cellStyle.backColor = headerColor;
      }
      for (var row = 0; row < allDataLines.length; row++) {
        final cells = allDataLines[row].split('\t');
        for (var col = 0;
            col < cells.length && col < scanSheetHeaders.length;
            col++) {
          sheet.getRangeByIndex(row + 2, col + 1).setText(cells[col]);
        }
      }
      for (var col = 1; col <= scanSheetHeaders.length; col++) {
        sheet.autoFitColumn(col);
      }
      await File(xlsxPath).writeAsBytes(workbook.saveAsStream());
    } finally {
      workbook.dispose();
    }

    return ScanSheetExportResult(
        newRows.isEmpty ? 1 : newRows.length, allDataLines.length, xlsxPath);
  }
}

/// The BACKGROUND-scan export, called by BOTH platform workers (ADR-0042 --
/// it used to exist only in the Windows worker).
class BackgroundScanExport {
  BackgroundScanExport._();

  /// Writes the export when Settings > Background "export CSV" is on. Never
  /// throws: an export problem must not fail the scan it describes. [log]
  /// is the calling worker's own log sink.
  static Future<void> exportIfEnabled({
    required EmailScanProvider scanProvider,
    required String accountId,
    required SettingsStore settingsStore,
    required Future<void> Function(String message) log,
  }) async {
    try {
      if (!await settingsStore.getBackgroundScanDebugCsv()) return;
      final dir = await ExportDirectories.resolve(
          subfolder: 'scan_exports', settingsStore: settingsStore);
      final redact = await settingsStore.getExportRedacted();
      final result = await ScanSheetExport.appendAndWrite(
        dir: dir,
        filePrefix: 'background_scan',
        accountToken: sanitizeAccountId(accountId),
        sheetName: 'Background Scan',
        headerColor: '#D9E2F3',
        newRows: scanProvider.getExcelRows(redact: redact),
      );
      await log('Background scan export written (${result.addedRows} new '
          'rows, ${result.totalRows} total${redact ? ', redacted' : ''})');
    } catch (e) {
      await log('Background scan export failed: $e');
    }
  }
}
