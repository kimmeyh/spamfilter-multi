/// Sprint 76 (Harold, 2026-10-06: "q1 1"): a new daily scan export starts with
/// a header row; the "<no records to process>" row stays (Harold: keep it).
///
/// What this does NOT catch: how a given spreadsheet app opens a tab-separated
/// `.csv` (column detection is the app's), and the workbook's own styled
/// header (unchanged, written separately from the `.data.csv`).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/scan_sheet_export.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('s76_hdr_'));
  tearDown(() => dir.delete(recursive: true));

  Future<ScanSheetExportResult> append(List<List<String>> rows) =>
      ScanSheetExport.appendAndWrite(
        dir: dir.path,
        filePrefix: 'background_scan',
        accountToken: 'someone_at_example_com',
        sheetName: 'Background Scan',
        headerColor: '#D9E2F3',
        newRows: rows,
      );

  File dataFile() => dir
      .listSync()
      .whereType<File>()
      .singleWhere((f) => f.path.endsWith('.data.csv'));

  List<String> row(String id) =>
      ['t', 't', 'Success', 'Bulk', 'Delete', 'r', 'a@b.c', 's', 'p', id, ''];

  test('a new file starts with the column names, once', () async {
    final first = await append([row('1')]);
    final second = await append([row('2')]);

    final lines = dataFile().readAsLinesSync();
    expect(lines.first, scanSheetHeaders.join('\t'));
    expect(lines.where((l) => l == scanSheetHeaders.join('\t')).length, 1,
        reason: 'the header is written only when the file is new');
    expect(lines.length, 3);
    expect(first.totalRows, 1, reason: 'the header is not counted as a row');
    expect(second.totalRows, 2);
  });

  test('an empty scan still writes the "<no records to process>" row', () async {
    await append(const []);
    final lines = dataFile().readAsLinesSync();
    expect(lines.first, scanSheetHeaders.join('\t'));
    expect(lines[1], contains('<no records to process>'));
  });

  test('a file started today without a header is not rewritten', () async {
    // Learn today's real file name (it carries the build's dev/prod suffix),
    // then make it look like a file an older build wrote: rows, no header.
    await append([row('0')]);
    final file = dataFile()..writeAsStringSync('${row('0').join('\t')}\n');

    await append([row('1')]);
    final lines = file.readAsLinesSync();
    expect(lines.first, isNot(scanSheetHeaders.join('\t')));
    expect(lines.length, 2);
  });
}
