/// F126 (Sprint 50, Issue #279): remove the 4 ambiguous legacy TLD-block
/// body rules that the F33-PROD run (Sprint 49) left report-only:
///
///   /%\.nl/   /%\.ru/   /%\.store/   /.*\.xyz
///
/// TLD blocking is covered by the proper top_level_domain rules; Harold's
/// Product Owner delete decision was recorded 2026-07-25 (sprint scope
/// selection). Rows are matched by EXACT condition_body content (never by
/// rowid guess), restricted to pattern_category='body'.
///
/// Safety discipline (mirrors cleanup_body_rules.dart / dedup_rules.dart):
///   - DRY-RUN by default: lists the matched rows and count, changes nothing.
///   - --apply ABORTS unless the match count is exactly 4 (kExpectedCount).
///   - --apply first copies the DB to a timestamped backup:
///       spam_filter.db.backup_pre_f126_<env>_<timestamp>
///   - --db <path> targets an explicit DB file (rehearsal seam).
///
/// Usage:
///   dart run scripts/remove_ambiguous_tld_rules.dart              # dev dry-run
///   dart run scripts/remove_ambiguous_tld_rules.dart --env prod   # prod dry-run
///   dart run scripts/remove_ambiguous_tld_rules.dart --env prod --apply
///   dart run scripts/remove_ambiguous_tld_rules.dart --db <path> [--apply]
library;

import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Exact condition_body values (raw DB strings) of the 4 legacy rows.
/// Verified against the live prod DB 2026-07-25 (ids 5865-5868).
const List<String> kTargetBodies = [
  r'["/%\\.nl/"]',
  r'["/%\\.ru/"]',
  r'["/%\\.store/"]',
  r'["/.*\\.xyz"]',
];

/// The apply gate: exactly this many rows must match or --apply aborts.
const int kExpectedCount = 4;

/// Select the target rows by exact condition_body content, restricted to
/// body-category rows. Pure function so the selection and the abort gate are
/// unit-testable without a live DB.
List<Map<String, Object?>> selectAmbiguousTldTargets(
    List<Map<String, Object?>> rows) {
  return rows
      .where((r) =>
          r['pattern_category'] == 'body' &&
          kTargetBodies.contains(r['condition_body']))
      .toList();
}

void main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final apply = args.contains('--apply');
  final envIndex = args.indexOf('--env');
  final env = (envIndex >= 0 && envIndex + 1 < args.length)
      ? args[envIndex + 1]
      : 'dev';
  final dbIndex = args.indexOf('--db');
  final dbOverride = (dbIndex >= 0 && dbIndex + 1 < args.length)
      ? args[dbIndex + 1]
      : null;

  final String dbPath;
  if (dbOverride != null) {
    dbPath = dbOverride;
  } else {
    final appDataPath = Platform.environment['APPDATA'];
    if (appDataPath == null) {
      stderr.writeln('[FAIL] APPDATA environment variable not found');
      exit(1);
    }
    final dataDir = env == 'prod'
        ? 'MyEmailSpamFilter'
        : 'MyEmailSpamFilter_Dev';
    dbPath = '$appDataPath\\MyEmailSpamFilter\\$dataDir\\spam_filter.db';
  }

  print('=== F126 Ambiguous-TLD Rule Removal (${apply ? "APPLY" : "DRY-RUN"}) ===');
  print('Environment: $env');
  print('Database: $dbPath');
  print('');

  if (!File(dbPath).existsSync()) {
    stderr.writeln('[FAIL] Database not found at $dbPath');
    exit(1);
  }

  final db = await openDatabase(dbPath);
  final totalBefore =
      (await db.rawQuery('SELECT COUNT(*) AS c FROM rules')).first['c'] as int;
  final rows = await db.query(
    'rules',
    columns: ['id', 'name', 'condition_body', 'pattern_category'],
    where: "pattern_category = 'body'",
  );
  final targets = selectAmbiguousTldTargets(rows);

  print('Total rules: $totalBefore');
  print('Matched target rows: ${targets.length} (expected $kExpectedCount)');
  for (final t in targets) {
    print('  id=${t['id']}  name=${t['name']}  body=${t['condition_body']}');
  }

  if (!apply) {
    print('');
    print('DRY-RUN only -- no changes made. Re-run with --apply to execute.');
    await db.close();
    return;
  }

  if (targets.length != kExpectedCount) {
    stderr.writeln('');
    stderr.writeln('[FAIL] ABORT: matched ${targets.length} rows, expected '
        'exactly $kExpectedCount. No changes made.');
    await db.close();
    exit(1);
  }

  final backupPath = '$dbPath.backup_pre_f126_${env}_'
      '${DateTime.now().toIso8601String().replaceAll(RegExp(r"[:.]"), "-")}';
  print('');
  print('Backing up DB to: $backupPath');
  await db.close();
  File(dbPath).copySync(backupPath);

  final wdb = await openDatabase(dbPath);
  final ids = targets.map((t) => t['id'] as int).toList();
  int removed = 0;
  await wdb.transaction((txn) async {
    for (final id in ids) {
      removed += await txn.delete('rules', where: 'id = ?', whereArgs: [id]);
    }
  });
  final totalAfter =
      (await wdb.rawQuery('SELECT COUNT(*) AS c FROM rules')).first['c'] as int;
  await wdb.close();

  print('Removed: $removed rows (ids: ${ids.join(", ")})');
  print('Total rules: $totalBefore -> $totalAfter');
  print('[OK] Backup retained at: $backupPath');
  if (totalAfter != totalBefore - kExpectedCount) {
    stderr.writeln('[WARNING] Post-apply count does not equal pre-apply '
        'count minus $kExpectedCount -- inspect before trusting the run.');
    exit(1);
  }
}
