/// Fix script to reclassify TLD patterns from exact_domain to top_level_domain.
///
/// The original split script classified @.*\.TLD$ patterns as exact_domain
/// instead of top_level_domain. This script updates the pattern_sub_type
/// and execution_order for all TLD patterns in the database.
///
/// Usage:
///   cd mobile-app
///   dart run scripts/fix_tld_rules.dart
///
/// Undo:
///   Copy spam_filter.db.backup_pre_tld_fix over spam_filter.db

import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  print('=== TLD Rule Fix Tool ===');
  print('');

  // Determine DB path
  final appDataPath = Platform.environment['APPDATA'];
  if (appDataPath == null) {
    print('[FAIL] APPDATA environment variable not found');
    exit(1);
  }
  final dbPath = '$appDataPath\\MyEmailSpamFilter\\MyEmailSpamFilter\\spam_filter.db';
  final backupPath = '$appDataPath\\MyEmailSpamFilter\\MyEmailSpamFilter\\spam_filter.db.backup_pre_tld_fix';

  print('Database: $dbPath');

  if (!File(dbPath).existsSync()) {
    print('[FAIL] Database not found');
    exit(1);
  }

  // Step 1: Backup
  print('');
  print('Step 1: Creating backup...');
  File(dbPath).copySync(backupPath);
  print('[OK] Backup created: $backupPath');

  // Step 2: Open database
  print('');
  print('Step 2: Opening database...');
  final db = await openDatabase(dbPath);

  // Step 3: Find all header_from/exact_domain rules with TLD patterns
  print('');
  print('Step 3: Finding TLD patterns misclassified as exact_domain...');

  // TLD patterns match: @.*\.TLD$ (with optional escaping)
  // They are in condition_header as JSON arrays with a single pattern
  final candidates = await db.query(
    'rules',
    where: "pattern_category = ? AND pattern_sub_type = ?",
    whereArgs: ['header_from', 'exact_domain'],
  );

  print('  Total header_from/exact_domain rules: ${candidates.length}');

  // Identify TLD patterns by source_domain format.
  // TLD patterns have source_domain like: .*.xyz, .*.ru, .*.store, .*.in.net
  // (the split script stored the unescaped pattern remainder as source_domain)
  final tldSourceRegex = RegExp(r'^\.\*\.(.+)$');

  final tldRules = <Map<String, dynamic>>[];
  final tldNames = <String>[];

  for (final rule in candidates) {
    final sourceDomain = rule['source_domain'] as String? ?? '';

    if (tldSourceRegex.hasMatch(sourceDomain)) {
      tldRules.add(rule);
      final match = tldSourceRegex.firstMatch(sourceDomain);
      tldNames.add(match?.group(1) ?? sourceDomain);
    }
  }

  print('  TLD patterns found: ${tldRules.length}');

  if (tldRules.isEmpty) {
    print('');
    print('No TLD patterns to fix. Exiting.');
    await db.close();
    exit(0);
  }

  // Show sample
  print('');
  print('  Sample TLD patterns (first 10):');
  for (var i = 0; i < tldNames.length && i < 10; i++) {
    print('    .${tldNames[i]} (${tldRules[i]['name']})');
  }
  if (tldNames.length > 10) {
    print('    ... and ${tldNames.length - 10} more');
  }

  // Step 4: Update pattern_sub_type and execution_order
  print('');
  print('Step 4: Updating ${tldRules.length} rules to top_level_domain...');

  int updated = 0;
  await db.transaction((txn) async {
    for (final rule in tldRules) {
      await txn.update(
        'rules',
        {
          'pattern_sub_type': 'top_level_domain',
          'execution_order': 10, // TLD = highest priority in header_from
          'date_modified': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'name = ?',
        whereArgs: [rule['name']],
      );
      updated++;
    }
  });

  print('[OK] Updated $updated rules');

  // Step 5: Verify
  print('');
  print('Step 5: Verifying...');

  final tldCount = await db.rawQuery(
    "SELECT COUNT(*) as count FROM rules WHERE pattern_sub_type = 'top_level_domain'",
  );
  final finalTldCount = tldCount.first['count'] as int;

  final subTypeCounts = await db.rawQuery(
    "SELECT pattern_sub_type, COUNT(*) as count FROM rules WHERE pattern_category = 'header_from' GROUP BY pattern_sub_type ORDER BY pattern_sub_type",
  );

  print('  Header/From rules by sub-type:');
  for (final row in subTypeCounts) {
    print('    ${row['pattern_sub_type']}: ${row['count']}');
  }

  print('');
  print('=== TLD Fix Complete ===');
  print('  TLD rules updated: $updated');
  print('  Total TLD rules in DB: $finalTldCount');
  print('  Backup at: $backupPath');
  print('');
  print('To undo: copy $backupPath over $dbPath');

  await db.close();
}
