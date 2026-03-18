/// Fix script to convert wildcard TLD patterns to .com TLD.
///
/// Entire domain patterns like @(?:[a-z0-9-]+\.)*DOMAIN\.[a-z0-9.-]+$
/// have a wildcard TLD ([a-z0-9.-]+) instead of a specific TLD (.com).
/// This script converts them to use .com$ as the default TLD.
///
/// Deduplication: if a .com version already exists, the wildcard version
/// is deleted instead of converted.
///
/// Usage:
///   cd mobile-app
///   dart run scripts/fix_wildcard_tld.dart
///
/// Undo:
///   Copy spam_filter.db.backup_pre_wildcard_fix over spam_filter.db

import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  print('=== Wildcard TLD Fix Tool ===');
  print('');

  final appDataPath = Platform.environment['APPDATA'];
  if (appDataPath == null) {
    print('[FAIL] APPDATA environment variable not found');
    exit(1);
  }
  final dbPath = '$appDataPath\\MyEmailSpamFilter\\MyEmailSpamFilter\\spam_filter.db';
  final backupPath = '$appDataPath\\MyEmailSpamFilter\\MyEmailSpamFilter\\spam_filter.db.backup_pre_wildcard_fix';

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

  // Step 3: Find all entire_domain rules with wildcard TLD patterns
  print('');
  print('Step 3: Finding wildcard TLD patterns...');

  // Search both entire_domain and exact_domain since the split script
  // misclassified wildcard TLD patterns as exact_domain
  final candidates = await db.query(
    'rules',
    where: "pattern_category = ? AND (pattern_sub_type = ? OR pattern_sub_type = ?)",
    whereArgs: ['header_from', 'entire_domain', 'exact_domain'],
  );

  print('  Total header_from rules (entire_domain + exact_domain): ${candidates.length}');

  // Wildcard TLD suffix in decoded pattern string
  final wildcardTldSuffix = r'.[a-z0-9.-]+$';

  final wildcardRules = <Map<String, dynamic>>[];
  final conversions = <_Conversion>[];

  for (final rule in candidates) {
    final condHeader = rule['condition_header'] as String?;
    if (condHeader == null) continue;

    // Decode JSON array to get actual pattern
    List<String> patterns;
    try {
      final decoded = jsonDecode(condHeader);
      if (decoded is List) {
        patterns = decoded.cast<String>();
      } else {
        continue;
      }
    } catch (_) {
      continue;
    }

    if (patterns.isEmpty) continue;
    final pattern = patterns.first;

    // Check if pattern ends with wildcard TLD: \.[a-z0-9.-]+$
    // (the decoded pattern has single backslash: \.)
    if (!pattern.endsWith(wildcardTldSuffix)) continue;

    wildcardRules.add(rule);

    // Convert: replace \.[a-z0-9.-]+$ with \.com$
    final newPattern = '${pattern.substring(0, pattern.length - wildcardTldSuffix.length)}.com\$';

    // Extract domain for new source_domain from existing source_domain
    // Current source_domain is like: (?:[a-z0-9-]+.)*-offers.[a-z0-9.-]+
    // We want just: -offers.com (or offers.com)
    final existingSource = (rule['source_domain'] as String?) ?? '';

    // Try to extract the domain name part
    // Pattern: (?:[a-z0-9-]+.)*DOMAIN.[a-z0-9.-]+
    final sourceMatch = RegExp(r'\(\?:\[a-z0-9-\]\+\.\)\*(.+)\.\[a-z0-9\.\-\]\+').firstMatch(existingSource);
    String newSourceDomain;
    if (sourceMatch != null) {
      final rawDomain = sourceMatch.group(1)!;
      newSourceDomain = '$rawDomain.com';
    } else {
      // Simpler fallback: strip the wildcard suffix from source and add .com
      final stripped = existingSource.replaceAll('.[a-z0-9.-]+', '').replaceAll('(?:[a-z0-9-]+.)*', '');
      newSourceDomain = stripped.isNotEmpty ? '$stripped.com' : existingSource;
    }

    // Generate new name
    final newName = newSourceDomain.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._@-]'), '_');

    conversions.add(_Conversion(
      oldName: rule['name'] as String,
      oldPattern: pattern,
      newPattern: newPattern,
      newSourceDomain: newSourceDomain,
      newName: newName.length > 100 ? newName.substring(0, 100) : newName,
    ));
  }

  print('  Wildcard TLD patterns found: ${wildcardRules.length}');

  if (wildcardRules.isEmpty) {
    print('');
    print('No wildcard TLD patterns to fix. Exiting.');
    await db.close();
    exit(0);
  }

  // Show samples
  print('');
  print('  Sample conversions (first 5):');
  for (var i = 0; i < conversions.length && i < 5; i++) {
    final c = conversions[i];
    print('    ${c.oldName}');
    print('      old: ${c.oldPattern}');
    print('      new: ${c.newPattern}');
    print('      domain: ${c.newSourceDomain}');
    print('');
  }

  // Step 4: Check for duplicates
  print('Step 4: Checking for duplicates...');

  // Build set of existing rule names and patterns for dedup
  final allRules = await db.query('rules', columns: ['name', 'condition_header']);
  final existingNames = <String>{};
  final existingPatterns = <String>{};

  for (final r in allRules) {
    existingNames.add(r['name'] as String);
    final ch = r['condition_header'] as String?;
    if (ch != null) {
      try {
        final decoded = jsonDecode(ch);
        if (decoded is List) {
          for (final p in decoded) {
            existingPatterns.add(p as String);
          }
        }
      } catch (_) {}
    }
  }

  int duplicateCount = 0;
  int convertCount = 0;
  final toDelete = <String>[]; // Rules to delete (duplicate after conversion)
  final toUpdate = <_Conversion>[]; // Rules to update

  for (final c in conversions) {
    if (existingPatterns.contains(c.newPattern)) {
      // A rule with this .com pattern already exists -- delete the wildcard version
      duplicateCount++;
      toDelete.add(c.oldName);
    } else {
      convertCount++;
      toUpdate.add(c);
      existingPatterns.add(c.newPattern); // Track to prevent self-duplicates
    }
  }

  print('  Will convert: $convertCount');
  print('  Will delete (duplicate): $duplicateCount');

  // Step 5: Apply changes
  print('');
  print('Step 5: Applying changes...');

  int updated = 0;
  int deleted = 0;

  await db.transaction((txn) async {
    // Delete duplicates
    for (final name in toDelete) {
      await txn.delete('rules', where: 'name = ?', whereArgs: [name]);
      deleted++;
    }

    // Update remaining
    for (final c in toUpdate) {
      // Generate unique name
      var newName = c.newName;
      if (existingNames.contains(newName) && newName != c.oldName) {
        for (var i = 2; i < 10000; i++) {
          final candidate = '${newName}_$i';
          if (!existingNames.contains(candidate)) {
            newName = candidate;
            break;
          }
        }
      }
      existingNames.remove(c.oldName);
      existingNames.add(newName);

      await txn.update(
        'rules',
        {
          'name': newName,
          'condition_header': jsonEncode([c.newPattern]),
          'source_domain': c.newSourceDomain,
          'pattern_sub_type': 'entire_domain',
          'execution_order': 20, // entire_domain execution order
          'date_modified': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'name = ?',
        whereArgs: [c.oldName],
      );
      updated++;
    }
  });

  print('[OK] Updated $updated rules, deleted $deleted duplicates');

  // Step 6: Verify
  print('');
  print('Step 6: Verifying...');

  // Check no wildcard patterns remain
  final remaining = await db.query(
    'rules',
    where: "pattern_category = ? AND pattern_sub_type = ?",
    whereArgs: ['header_from', 'entire_domain'],
  );

  int remainingWildcard = 0;
  for (final r in remaining) {
    final ch = r['condition_header'] as String?;
    if (ch != null && ch.contains(wildcardTldSuffix)) {
      remainingWildcard++;
    }
  }

  final subTypeCounts = await db.rawQuery(
    "SELECT pattern_sub_type, COUNT(*) as count FROM rules WHERE pattern_category = 'header_from' GROUP BY pattern_sub_type ORDER BY pattern_sub_type",
  );

  print('  Remaining wildcard TLD patterns: $remainingWildcard');
  print('  Header/From rules by sub-type:');
  for (final row in subTypeCounts) {
    print('    ${row['pattern_sub_type']}: ${row['count']}');
  }

  final totalRules = await db.rawQuery("SELECT COUNT(*) as count FROM rules");
  print('  Total rules in DB: ${totalRules.first['count']}');

  print('');
  print('=== Wildcard TLD Fix Complete ===');
  print('  Converted: $updated');
  print('  Deleted (duplicates): $deleted');
  print('  Remaining wildcard: $remainingWildcard');
  print('  Backup at: $backupPath');
  print('');
  print('To undo: copy $backupPath over $dbPath');

  await db.close();
}

class _Conversion {
  final String oldName;
  final String oldPattern;
  final String newPattern;
  final String newSourceDomain;
  final String newName;

  _Conversion({
    required this.oldName,
    required this.oldPattern,
    required this.newPattern,
    required this.newSourceDomain,
    required this.newName,
  });
}
