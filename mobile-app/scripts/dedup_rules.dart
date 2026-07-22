/// F121 (Sprint 49): one-time dedup of content-identical rules.
///
/// WHY: the Store 0.5.6 prod DB carried 12,539 rules of which ~7.6k are
/// content-identical duplicates with `_2`/`_3` suffixed names. Root cause:
/// the pre-F73 rule import ran multiple times (date_added clusters on
/// 2026-04-24), creating duplicate monolithic rows; the F73 split migration
/// then faithfully split ALL of them, using _generateUniqueName's collision
/// suffixing instead of skipping content-identical rows. Every duplicate is
/// dead weight in rule evaluation (~2.5x slower scans and, pre-F120, 1-2
/// minute quick-action freezes).
///
/// WHAT: groups rules by their FULL functional content -- every condition,
/// action, exception column plus enabled/is_local/execution_order and the
/// classification metadata -- compared as RAW column strings (no JSON decode,
/// so an undecodable condition can never be misjudged; BUG-DECODE class).
/// Keeps the LOWEST id of each group (the original, un-suffixed name);
/// removes the rest.
///
/// SAFETY: dry-run by default; `--apply` makes a timestamped DB backup first;
/// the report reconciles keepers + removals == total scanned.
///
/// Usage:
///   dart run scripts/dedup_rules.dart                 (dev DB, dry-run)
///   dart run scripts/dedup_rules.dart --env prod       (prod DB, dry-run)
///   dart run scripts/dedup_rules.dart --env prod --apply
library;

import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The columns that define a rule's FUNCTIONAL identity. Two rows identical
/// across all of these are interchangeable at evaluation time regardless of
/// name/date/provenance. Classification metadata (pattern_category, sub_type,
/// source_domain) is included to keep the dedup strictly conservative.
const List<String> kContentColumns = [
  'enabled',
  'is_local',
  'execution_order',
  'condition_type',
  'condition_from',
  'condition_header',
  'condition_subject',
  'condition_body',
  'action_delete',
  'action_move_to_folder',
  'action_assign_category',
  'exception_from',
  'exception_header',
  'exception_subject',
  'exception_body',
  'pattern_category',
  'pattern_sub_type',
  'source_domain',
];

class DedupAnalysis {
  /// content-key -> ids in the group, sorted ascending (first = keeper).
  final Map<String, List<int>> groups;
  final int total;

  DedupAnalysis({required this.groups, required this.total});

  List<int> get keeperIds =>
      groups.values.map((ids) => ids.first).toList(growable: false);

  List<int> get removalIds => [
        for (final ids in groups.values)
          if (ids.length > 1) ...ids.sublist(1),
      ];
}

/// Pure analysis over raw DB rows (exported for unit tests).
DedupAnalysis analyzeDuplicates(List<Map<String, Object?>> rows) {
  final groups = <String, List<int>>{};
  for (final row in rows) {
    // Copilot review (PR #276): NULL and empty-string are DISTINCT values in
    // SQLite; collapsing them ((row[c] ?? '') did that) could group two
    // non-identical rows and delete one on --apply. NULL gets an explicit
    // sentinel that cannot collide with real content (a lone ASCII NUL).
    final key = kContentColumns
        .map((c) => row[c] == null ? '\x00' : row[c].toString())
        // F-PRECHECK class-4 note (Sprint 49 dogfood of the new 5.1.2
        // checklist): the separator must be a character that cannot appear
        // in rule content, and it must be VISIBLE in source -- a raw control
        // byte here is invisible and editor-fragile. Escaped unit separator.
        .join('\x1f');
    groups.putIfAbsent(key, () => <int>[]).add(row['id'] as int);
  }
  for (final ids in groups.values) {
    ids.sort();
  }
  return DedupAnalysis(groups: groups, total: rows.length);
}

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final apply = args.contains('--apply');
  final envIndex = args.indexOf('--env');
  final env = (envIndex >= 0 && envIndex + 1 < args.length)
      ? args[envIndex + 1]
      : 'dev';
  // Test/verification seam: --db <path> targets an explicit DB file (e.g. a
  // copy) instead of the live env DB. Dry-run verification never touches the
  // real DB this way.
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
    final dataDir = env == 'prod' ? 'MyEmailSpamFilter' : 'MyEmailSpamFilter_Dev';
    dbPath = '$appDataPath\\MyEmailSpamFilter\\$dataDir\\spam_filter.db';
  }

  print('=== F121 Rule Dedup (${apply ? "APPLY" : "DRY-RUN"}) ===');
  print('Environment: $env${dbOverride != null ? " (explicit --db override)" : ""}');
  print('Database: $dbPath');
  print('');

  if (!File(dbPath).existsSync()) {
    stderr.writeln('[FAIL] Database not found at $dbPath');
    exit(1);
  }

  final db = await openDatabase(dbPath);
  final rows = await db.query('rules', columns: ['id', ...kContentColumns]);
  final analysis = analyzeDuplicates(rows);

  final keepers = analysis.keeperIds.length;
  final removals = analysis.removalIds.length;
  final dupGroups =
      analysis.groups.values.where((ids) => ids.length > 1).length;

  print('Total rules scanned:        ${analysis.total}');
  print('Distinct content groups:    ${analysis.groups.length}');
  print('Groups with duplicates:     $dupGroups');
  print('Keepers (lowest id/group):  $keepers');
  print('Removals (dupes):           $removals');
  print('Reconciliation: keepers + removals == total -> '
      '${keepers + removals == analysis.total ? "[OK]" : "[FAIL] MISMATCH -- DO NOT APPLY"}');

  if (keepers + removals != analysis.total) {
    await db.close();
    exit(1);
  }

  if (!apply) {
    print('');
    print('DRY-RUN only -- no changes made. Re-run with --apply to execute.');
    await db.close();
    return;
  }

  // --- APPLY path ---
  final backupPath = '$dbPath.backup_pre_f121_${env}_'
      '${DateTime.now().toIso8601String().replaceAll(RegExp(r"[:.]"), "-")}';
  print('');
  print('Backing up DB to: $backupPath');
  await db.close();
  File(dbPath).copySync(backupPath);
  final wdb = await openDatabase(dbPath);

  var removed = 0;
  await wdb.transaction((txn) async {
    for (final id in analysis.removalIds) {
      removed += await txn.delete('rules', where: 'id = ?', whereArgs: [id]);
    }
  });

  final remaining =
      ((await wdb.rawQuery('SELECT COUNT(*) FROM rules')).first.values.first
              as int?) ??
          -1;
  await wdb.close();

  print('[OK] Removed: $removed duplicate rule(s)');
  print('[OK] Remaining rules: $remaining (expected $keepers)');
  if (remaining != keepers) {
    stderr.writeln('[FAIL] Post-apply count mismatch -- restore from backup: '
        '$backupPath');
    exit(1);
  }
  print('[OK] Dedup complete. Backup retained at: $backupPath');
}
