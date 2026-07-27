/// F123 (Sprint 50, Issue #281): repair legacy-mislabeled `pattern_type`
/// values in the `safe_senders` table.
///
/// Root cause (evidenced 2026-07-25 on the live prod DB): 350 of 525 rows
/// store a `pattern_type` that disagrees with what the CURRENT writer
/// (`SafeSenderDatabaseStore.determinePatternType`) computes from the
/// pattern -- legacy write-time misclassification by older classifier
/// versions. Observed classes:
///   - 37 rows: exact-email-shaped pattern (`^user@dom\.com$`) stored as
///     'subdomain' -> displayed "Entire Domain" (Harold's 0.5.6 observation);
///   - 297 rows: subdomain-wildcard pattern (`(?:[a-z0-9-]+\.)*`) stored as
///     'domain' -> displayed "Exact Domain";
///   - 16 rows: plain `@domain` string stored as 'subdomain'.
///
/// The display precedence (stored patternType is authoritative --
/// `SafeSenderCategory.categorize`, Sprint 37) is NOT changed; the DATA is
/// corrected to what the current writer would store. `pattern_type` also
/// feeds duplicate detection (`manual_rule_duplicate_checker.dart`), so this
/// repair fixes behavior, not only labels.
///
/// A stored value of 'custom' is a user-explicit choice (quick-add) and is
/// NEVER repaired. Rows whose recomputation yields 'unknown' are left
/// untouched (report-not-mutate on ambiguity).
///
/// Safety discipline (mirrors remove_ambiguous_tld_rules.dart):
///   - DRY-RUN by default; --apply mutates after a timestamped backup:
///       spam_filter.db.backup_pre_f123_<env>_<timestamp>
///   - --db <path> targets an explicit DB file (rehearsal seam).
///
/// Usage:
///   dart run scripts/repair_safe_sender_types.dart --env prod          # dry-run
///   dart run scripts/repair_safe_sender_types.dart --env prod --apply
///   dart run scripts/repair_safe_sender_types.dart --db <path> [--apply]
library;

import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// MIRROR of `SafeSenderDatabaseStore.determinePatternType` (which cannot be
/// imported here: its import chain pulls Flutter, unavailable to `dart run`).
/// A unit test pins this mirror byte-for-byte-equivalent in behavior to the
/// store implementation (F-PRECHECK class (a): mirror/parallel-site sync).
String determinePatternTypeMirror(String pattern) {
  if (pattern.isEmpty) return 'unknown';

  final hasRegex = pattern.contains(RegExp(r'[\[\]()*+?\\^$|]'));

  if (pattern.startsWith('@') && !hasRegex) {
    return 'domain';
  }
  if (pattern.contains('@') && !hasRegex) {
    return 'email';
  }
  if (hasRegex) {
    if (pattern.contains(r'(?:[a-z0-9-]+\.)*')) {
      return 'subdomain';
    }
    if (pattern.contains('@') && !pattern.contains(r'(?:[a-z0-9-]+\.)*')) {
      if (pattern.contains(r'[^@\s]+@') || pattern.contains(r'[^@\\s]+@')) {
        return 'domain';
      }
      return 'email';
    }
    return 'subdomain';
  }
  return 'unknown';
}

/// One planned repair: row [id] changes `pattern_type` [from] -> [to].
class SafeSenderTypeRepair {
  final int id;
  final String pattern;
  final String from;
  final String to;
  SafeSenderTypeRepair(this.id, this.pattern, this.from, this.to);
}

/// Compute the repair set. Pure function for unit testing.
///
/// Repairs ONLY rows where:
///   - the stored type is one of the auto-written classes
///     ('email' / 'domain' / 'subdomain' / 'unknown') -- never 'custom';
///   - the recomputed type differs from the stored type;
///   - the recomputed type is not 'unknown' (never degrade a labeled row).
List<SafeSenderTypeRepair> computeSafeSenderTypeRepairs(
    List<Map<String, Object?>> rows) {
  const autoWritten = {'email', 'domain', 'subdomain', 'unknown'};
  final repairs = <SafeSenderTypeRepair>[];
  for (final r in rows) {
    final stored = r['pattern_type'] as String? ?? 'unknown';
    if (!autoWritten.contains(stored)) continue;
    final pattern = r['pattern'] as String? ?? '';
    final computed = determinePatternTypeMirror(pattern);
    if (computed == 'unknown' || computed == stored) continue;
    repairs.add(SafeSenderTypeRepair(r['id'] as int, pattern, stored, computed));
  }
  return repairs;
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

  print('=== F123 Safe-Sender pattern_type Repair (${apply ? "APPLY" : "DRY-RUN"}) ===');
  print('Environment: $env');
  print('Database: $dbPath');
  print('');

  if (!File(dbPath).existsSync()) {
    stderr.writeln('[FAIL] Database not found at $dbPath');
    exit(1);
  }

  final db = await openDatabase(dbPath);
  final rows = await db.query('safe_senders',
      columns: ['id', 'pattern', 'pattern_type']);
  final repairs = computeSafeSenderTypeRepairs(rows);

  final byClass = <String, int>{};
  for (final r in repairs) {
    byClass['${r.from} -> ${r.to}'] = (byClass['${r.from} -> ${r.to}'] ?? 0) + 1;
  }
  print('Total safe senders: ${rows.length}');
  print('Rows needing repair: ${repairs.length}');
  byClass.forEach((k, v) => print('  $k: $v'));
  for (final r in repairs) {
    print('  id=${r.id}  ${r.from} -> ${r.to}  ${r.pattern}');
  }

  if (!apply) {
    print('');
    print('DRY-RUN only -- no changes made. Re-run with --apply to execute.');
    await db.close();
    return;
  }

  if (repairs.isEmpty) {
    print('');
    print('[OK] Nothing to repair.');
    await db.close();
    return;
  }

  final backupPath = '$dbPath.backup_pre_f123_${env}_'
      '${DateTime.now().toIso8601String().replaceAll(RegExp(r"[:.]"), "-")}';
  print('');
  print('Backing up DB to: $backupPath');
  await db.close();
  File(dbPath).copySync(backupPath);

  final wdb = await openDatabase(dbPath);
  int updated = 0;
  await wdb.transaction((txn) async {
    for (final r in repairs) {
      updated += await txn.update('safe_senders', {'pattern_type': r.to},
          where: 'id = ?', whereArgs: [r.id]);
    }
  });
  final remaining = computeSafeSenderTypeRepairs(await wdb.query(
      'safe_senders',
      columns: ['id', 'pattern', 'pattern_type']));
  await wdb.close();

  print('Updated: $updated rows');
  print('Remaining repairable after apply: ${remaining.length} (expected 0)');
  print('[OK] Backup retained at: $backupPath');
  if (remaining.isNotEmpty) {
    stderr.writeln('[WARNING] Repairs remain after apply -- inspect before '
        'trusting the run.');
    exit(1);
  }
}
