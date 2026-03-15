/// Standalone Dart CLI script to split monolithic rules into individual rules.
///
/// This is a one-time migration tool that:
/// 1. Backs up the current database
/// 2. Reads monolithic rules (e.g., SpamAutoDeleteHeader with 1,742 patterns)
/// 3. Splits each pattern into an individual rule with classification fields
/// 4. Deletes the original monolithic rules
/// 5. Reports results and any edge cases
///
/// Usage:
///   cd mobile-app
///   dart run scripts/split_rules.dart
///
/// Undo:
///   Copy spam_filter.db.backup_pre_split over spam_filter.db
///
/// Requirements:
///   - sqflite_common_ffi (already in pubspec.yaml dev_dependencies)
///   - Run from mobile-app directory

import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pattern classification result
class PatternClassification {
  final String name;
  final String pattern;
  final String patternCategory; // header_from, subject, body
  final String patternSubType; // entire_domain, exact_domain, exact_email, top_level_domain
  final String sourceDomain; // extracted domain for display
  final int executionOrder;
  final String conditionField; // header, subject, body (DB column)

  PatternClassification({
    required this.name,
    required this.pattern,
    required this.patternCategory,
    required this.patternSubType,
    required this.sourceDomain,
    required this.executionOrder,
    required this.conditionField,
  });
}

/// Edge case that could not be automatically classified
class EdgeCase {
  final String sourceRule;
  final String pattern;
  final String conditionField;
  final String reason;

  EdgeCase({
    required this.sourceRule,
    required this.pattern,
    required this.conditionField,
    required this.reason,
  });
}

/// Execution order mapping by category
const Map<String, int> executionOrders = {
  'header_from_top_level_domain': 10,
  'header_from_entire_domain': 20,
  'header_from_exact_domain': 30,
  'header_from_exact_email': 40,
  'body': 50,
  'subject': 60,
};

void main() async {
  // Initialize FFI for desktop SQLite access
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  print('=== Rule Split Tool ===');
  print('');

  // Determine DB path
  final appDataPath = Platform.environment['APPDATA'];
  if (appDataPath == null) {
    print('[FAIL] APPDATA environment variable not found');
    exit(1);
  }
  final dbPath = '$appDataPath\\MyEmailSpamFilter\\MyEmailSpamFilter\\spam_filter.db';
  final backupPath = '$appDataPath\\MyEmailSpamFilter\\MyEmailSpamFilter\\spam_filter.db.backup_pre_split';

  print('Database: $dbPath');

  // Verify DB exists
  if (!File(dbPath).existsSync()) {
    print('[FAIL] Database not found at: $dbPath');
    exit(1);
  }

  // Step 1: Backup
  print('');
  print('Step 1: Creating backup...');
  if (File(backupPath).existsSync()) {
    print('[WARNING] Backup already exists at: $backupPath');
    print('  Overwriting previous backup.');
  }
  File(dbPath).copySync(backupPath);
  print('[OK] Backup created: $backupPath');

  // Step 2: Open database
  print('');
  print('Step 2: Opening database...');
  final db = await openDatabase(dbPath);

  // Verify or apply v2 schema (pattern_category column)
  try {
    await db.rawQuery("SELECT pattern_category FROM rules LIMIT 1");
    print('[OK] Database schema v2 confirmed (pattern_category column exists)');
  } catch (e) {
    print('  Database schema is v1. Applying v2 migration...');
    await db.execute('ALTER TABLE rules ADD COLUMN pattern_category TEXT;');
    await db.execute('ALTER TABLE rules ADD COLUMN pattern_sub_type TEXT;');
    await db.execute('ALTER TABLE rules ADD COLUMN source_domain TEXT;');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rules_category ON rules(pattern_category, pattern_sub_type);');
    print('[OK] v2 migration applied successfully');
  }

  // Step 3: Read existing rules
  print('');
  print('Step 3: Reading existing rules...');
  final existingRules = await db.query('rules', orderBy: 'execution_order');
  print('  Found ${existingRules.length} existing rules:');
  for (final rule in existingRules) {
    final headerCount = _countPatterns(rule['condition_header']);
    final fromCount = _countPatterns(rule['condition_from']);
    final subjectCount = _countPatterns(rule['condition_subject']);
    final bodyCount = _countPatterns(rule['condition_body']);
    final total = headerCount + fromCount + subjectCount + bodyCount;
    print('  - ${rule['name']} (header: $headerCount, from: $fromCount, subject: $subjectCount, body: $bodyCount, total: $total)');
  }

  // Check if already split (has pattern_category values)
  final alreadySplit = existingRules.any((r) => r['pattern_category'] != null);
  if (alreadySplit) {
    print('');
    print('[WARNING] Some rules already have pattern_category set.');
    print('  This may indicate the split was already run.');
    print('  Proceeding will only split rules WITHOUT pattern_category.');
  }

  // Step 4: Classify all patterns
  print('');
  print('Step 4: Classifying patterns...');
  final classifications = <PatternClassification>[];
  final edgeCases = <EdgeCase>[];
  final usedNames = <String>{};

  for (final rule in existingRules) {
    final ruleName = rule['name'] as String;

    // Skip rules that already have classification (already split)
    if (rule['pattern_category'] != null) {
      print('  Skipping ${ruleName} (already classified)');
      continue;
    }

    final enabled = rule['enabled'] as int;
    final actionDelete = rule['action_delete'] as int;

    // Process header patterns -> header_from
    final headerPatterns = _decodeJsonArray(rule['condition_header']);
    for (final pattern in headerPatterns) {
      final result = _classifyHeaderPattern(pattern, usedNames);
      if (result != null) {
        classifications.add(result);
        usedNames.add(result.name);
      } else {
        edgeCases.add(EdgeCase(
          sourceRule: ruleName,
          pattern: pattern,
          conditionField: 'header',
          reason: 'Could not classify header pattern',
        ));
      }
    }

    // Process from patterns -> convert to header_from
    final fromPatterns = _decodeJsonArray(rule['condition_from']);
    for (final pattern in fromPatterns) {
      final result = _classifyFromPattern(pattern, usedNames);
      if (result != null) {
        classifications.add(result);
        usedNames.add(result.name);
      } else {
        edgeCases.add(EdgeCase(
          sourceRule: ruleName,
          pattern: pattern,
          conditionField: 'from',
          reason: 'Could not classify from pattern',
        ));
      }
    }

    // Process subject patterns
    final subjectPatterns = _decodeJsonArray(rule['condition_subject']);
    for (final pattern in subjectPatterns) {
      final result = _classifySubjectPattern(pattern, usedNames);
      if (result != null) {
        classifications.add(result);
        usedNames.add(result.name);
      } else {
        edgeCases.add(EdgeCase(
          sourceRule: ruleName,
          pattern: pattern,
          conditionField: 'subject',
          reason: 'Could not classify subject pattern',
        ));
      }
    }

    // Process body patterns
    final bodyPatterns = _decodeJsonArray(rule['condition_body']);
    for (final pattern in bodyPatterns) {
      final result = _classifyBodyPattern(pattern, usedNames);
      if (result != null) {
        classifications.add(result);
        usedNames.add(result.name);
      } else {
        edgeCases.add(EdgeCase(
          sourceRule: ruleName,
          pattern: pattern,
          conditionField: 'body',
          reason: 'Could not classify body pattern',
        ));
      }
    }
  }

  // Step 5: Report classification results
  print('');
  print('Step 5: Classification results');
  print('  Total patterns classified: ${classifications.length}');
  print('  Edge cases: ${edgeCases.length}');
  print('');

  // Count by category
  final categoryCounts = <String, int>{};
  for (final c in classifications) {
    final key = '${c.patternCategory}/${c.patternSubType}';
    categoryCounts[key] = (categoryCounts[key] ?? 0) + 1;
  }
  print('  By category:');
  for (final entry in categoryCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    print('    ${entry.key}: ${entry.value}');
  }

  // Report edge cases
  if (edgeCases.isNotEmpty) {
    print('');
    print('  Edge cases (grouped by reason):');
    final groupedEdgeCases = <String, List<EdgeCase>>{};
    for (final ec in edgeCases) {
      final key = '${ec.reason} (${ec.conditionField})';
      groupedEdgeCases.putIfAbsent(key, () => []).add(ec);
    }
    for (final entry in groupedEdgeCases.entries) {
      print('');
      print('    ${entry.key}: ${entry.value.length} patterns');
      for (final ec in entry.value.take(5)) {
        print('      - ${ec.pattern}');
      }
      if (entry.value.length > 5) {
        print('      ... and ${entry.value.length - 5} more');
      }
    }
  }

  // Step 6: Insert new individual rules
  print('');
  print('Step 6: Inserting ${classifications.length} individual rules...');

  final now = DateTime.now().millisecondsSinceEpoch;
  int inserted = 0;
  int errors = 0;

  await db.transaction((txn) async {
    for (final c in classifications) {
      try {
        // Build condition: pattern goes into the correct condition field
        // From patterns are converted to header patterns
        final conditionField = c.conditionField == 'from' ? 'header' : c.conditionField;

        await txn.insert('rules', {
          'name': c.name,
          'enabled': 1,
          'is_local': 1,
          'execution_order': c.executionOrder,
          'condition_type': 'OR',
          'condition_from': null,
          'condition_header': conditionField == 'header' ? jsonEncode([c.pattern]) : null,
          'condition_subject': conditionField == 'subject' ? jsonEncode([c.pattern]) : null,
          'condition_body': conditionField == 'body' ? jsonEncode([c.pattern]) : null,
          'action_delete': 1,
          'action_move_to_folder': null,
          'action_assign_category': null,
          'exception_from': null,
          'exception_header': null,
          'exception_subject': null,
          'exception_body': null,
          'metadata': jsonEncode({'split_from': 'monolithic_rules', 'split_date': DateTime.now().toIso8601String()}),
          'date_added': now,
          'date_modified': null,
          'created_by': 'split_script',
          'pattern_category': c.patternCategory,
          'pattern_sub_type': c.patternSubType,
          'source_domain': c.sourceDomain,
        });
        inserted++;
      } catch (e) {
        errors++;
        if (errors <= 10) {
          print('  [FAIL] Failed to insert "${c.name}": $e');
        }
      }
    }

    // Step 7: Delete original monolithic rules (only those without pattern_category)
    print('');
    print('Step 7: Deleting original monolithic rules...');
    for (final rule in existingRules) {
      if (rule['pattern_category'] == null) {
        final name = rule['name'] as String;
        await txn.delete('rules', where: 'name = ?', whereArgs: [name]);
        print('  Deleted: $name');
      }
    }
  });

  print('');
  print('=== Split Complete ===');
  print('  Inserted: $inserted individual rules');
  print('  Errors: $errors');
  print('  Edge cases: ${edgeCases.length}');
  print('  Backup at: $backupPath');
  print('');

  // Verify final state
  final finalRules = await db.query('rules');
  print('Final database state: ${finalRules.length} rules');
  final finalCategoryCounts = <String, int>{};
  for (final r in finalRules) {
    final cat = r['pattern_category'] as String? ?? 'uncategorized';
    finalCategoryCounts[cat] = (finalCategoryCounts[cat] ?? 0) + 1;
  }
  for (final entry in finalCategoryCounts.entries) {
    print('  ${entry.key}: ${entry.value}');
  }

  await db.close();

  if (edgeCases.isNotEmpty) {
    // Write edge cases to file for review
    final edgeCaseFile = File('scripts/split_edge_cases.txt');
    final buffer = StringBuffer();
    buffer.writeln('Edge Cases from Rule Split - ${DateTime.now().toIso8601String()}');
    buffer.writeln('');
    final grouped = <String, List<EdgeCase>>{};
    for (final ec in edgeCases) {
      final key = '${ec.reason} (${ec.conditionField})';
      grouped.putIfAbsent(key, () => []).add(ec);
    }
    for (final entry in grouped.entries) {
      buffer.writeln('${entry.key}: ${entry.value.length} patterns');
      for (final ec in entry.value) {
        buffer.writeln('  source: ${ec.sourceRule}');
        buffer.writeln('  pattern: ${ec.pattern}');
        buffer.writeln('');
      }
    }
    edgeCaseFile.writeAsStringSync(buffer.toString());
    print('');
    print('Edge cases written to: ${edgeCaseFile.path}');
  }

  print('');
  print('To undo: copy $backupPath over $dbPath');
}

// ============================================================================
// Classification functions
// ============================================================================

/// Classify a header pattern (from SpamAutoDeleteHeader)
///
/// Header patterns are almost all "entire domain" patterns like:
///   @(?:[a-z0-9-]+\.)*DOMAIN\.[a-z0-9.-]+$
///
/// But may also include exact domain, exact email, or TLD patterns.
PatternClassification? _classifyHeaderPattern(String pattern, Set<String> usedNames) {
  // Pattern: @(?:[a-z0-9-]+\.)*DOMAIN\.TLD$  -> entire_domain
  // This is the most common header pattern format
  final entireDomainMatch = RegExp(r'^@\(\?:\[a-z0-9\-\]\+\\\.\)\*(.+)\\\.([\w.-]+)\$$').firstMatch(pattern);
  if (entireDomainMatch != null) {
    final domainPart = entireDomainMatch.group(1)!.replaceAll(r'\-', '-').replaceAll(r'\.', '.');
    final tldPart = entireDomainMatch.group(2)!;
    // Check if tldPart is a wildcard like [a-z0-9.-]+
    String domain;
    String subType;
    if (tldPart.contains('[') || tldPart.contains('+')) {
      // Wildcard TLD: entire_domain (matches any TLD)
      domain = domainPart;
      subType = 'entire_domain';
    } else {
      domain = '$domainPart.$tldPart';
      subType = 'entire_domain';
    }
    final name = _generateUniqueName(domain, usedNames);
    return PatternClassification(
      name: name,
      pattern: pattern,
      patternCategory: 'header_from',
      patternSubType: subType,
      sourceDomain: domain,
      executionOrder: executionOrders['header_from_entire_domain']!,
      conditionField: 'header',
    );
  }

  // Pattern: @DOMAIN\.TLD$ -> exact_domain
  final exactDomainMatch = RegExp(r'^@(.+)\$$').firstMatch(pattern);
  if (exactDomainMatch != null) {
    final domainRaw = exactDomainMatch.group(1)!.replaceAll(r'\.', '.').replaceAll(r'\-', '-');
    final name = _generateUniqueName(domainRaw, usedNames);
    return PatternClassification(
      name: name,
      pattern: pattern,
      patternCategory: 'header_from',
      patternSubType: 'exact_domain',
      sourceDomain: domainRaw,
      executionOrder: executionOrders['header_from_exact_domain']!,
      conditionField: 'header',
    );
  }

  // Pattern: ^USER@DOMAIN$ -> exact_email
  final exactEmailMatch = RegExp(r'^\^(.+@.+)\$$').firstMatch(pattern);
  if (exactEmailMatch != null) {
    final email = exactEmailMatch.group(1)!.replaceAll(r'\.', '.').replaceAll(r'\-', '-');
    final name = _generateUniqueName(email, usedNames);
    return PatternClassification(
      name: name,
      pattern: pattern,
      patternCategory: 'header_from',
      patternSubType: 'exact_email',
      sourceDomain: email,
      executionOrder: executionOrders['header_from_exact_email']!,
      conditionField: 'header',
    );
  }

  // Fallback: try to extract something meaningful
  // Pattern starts with @ -- treat as exact_domain
  if (pattern.startsWith('@')) {
    final domainRaw = pattern.substring(1).replaceAll(r'\.', '.').replaceAll(r'\-', '-').replaceAll(r'$', '');
    final name = _generateUniqueName(domainRaw, usedNames);
    return PatternClassification(
      name: name,
      pattern: pattern,
      patternCategory: 'header_from',
      patternSubType: 'exact_domain',
      sourceDomain: domainRaw,
      executionOrder: executionOrders['header_from_exact_domain']!,
      conditionField: 'header',
    );
  }

  // Bare email address like "user@domain\.com" or "user@domain.com"
  // These are exact_email patterns without @ prefix or ^ anchor
  if (pattern.contains('@')) {
    final emailRaw = pattern.replaceAll(r'\.', '.').replaceAll(r'\-', '-').replaceAll(r'\ ', ' ').replaceAll(r'\+', '+').replaceAll(r'$', '');
    final name = _generateUniqueName(emailRaw, usedNames);
    return PatternClassification(
      name: name,
      pattern: pattern,
      patternCategory: 'header_from',
      patternSubType: 'exact_email',
      sourceDomain: emailRaw,
      executionOrder: executionOrders['header_from_exact_email']!,
      conditionField: 'header',
    );
  }

  // Bare domain without @ (like "firebaseapp\.com")
  if (pattern.contains(r'\.') || pattern.contains('.')) {
    final domainRaw = pattern.replaceAll(r'\.', '.').replaceAll(r'\-', '-').replaceAll(r'$', '');
    final name = _generateUniqueName(domainRaw, usedNames);
    return PatternClassification(
      name: name,
      pattern: pattern,
      patternCategory: 'header_from',
      patternSubType: 'entire_domain',
      sourceDomain: domainRaw,
      executionOrder: executionOrders['header_from_entire_domain']!,
      conditionField: 'header',
    );
  }

  // Last resort: treat as exact_domain with the raw pattern as identifier
  final fallbackName = _generateUniqueName(pattern.replaceAll(r'\', '').replaceAll(' ', '_'), usedNames);
  return PatternClassification(
    name: fallbackName,
    pattern: pattern,
    patternCategory: 'header_from',
    patternSubType: 'exact_domain',
    sourceDomain: pattern.replaceAll(r'\.', '.').replaceAll(r'\-', '-').replaceAll(r'\ ', ' '),
    executionOrder: executionOrders['header_from_exact_domain']!,
    conditionField: 'header',
  );
}

/// Classify a "from" pattern and convert it to header_from
///
/// From patterns like .*@greyhub\.com are moved to header condition
PatternClassification? _classifyFromPattern(String pattern, Set<String> usedNames) {
  // Pattern: .*@DOMAIN\.TLD -> entire_domain (matches any user at domain)
  final fromDomainMatch = RegExp(r'^\.\*@(.+)$').firstMatch(pattern);
  if (fromDomainMatch != null) {
    final domainRaw = fromDomainMatch.group(1)!.replaceAll(r'\.', '.').replaceAll(r'\-', '-');
    // Convert from pattern to header pattern format
    final headerPattern = '@(?:[a-z0-9-]+\\.)*${_escapeForRegex(domainRaw)}\$';
    final name = _generateUniqueName(domainRaw, usedNames);
    return PatternClassification(
      name: name,
      pattern: headerPattern,
      patternCategory: 'header_from',
      patternSubType: 'entire_domain',
      sourceDomain: domainRaw,
      executionOrder: executionOrders['header_from_entire_domain']!,
      conditionField: 'header', // Stored in header, not from
    );
  }

  // Pattern: ^USER@DOMAIN$ -> exact_email
  final exactMatch = RegExp(r'^\^?(.+@.+)\$?$').firstMatch(pattern);
  if (exactMatch != null) {
    final email = exactMatch.group(1)!.replaceAll(r'\.', '.').replaceAll(r'\-', '-');
    if (email.contains('@')) {
      final headerPattern = '@${email.split('@').last}\$';
      final name = _generateUniqueName(email, usedNames);
      return PatternClassification(
        name: name,
        pattern: headerPattern,
        patternCategory: 'header_from',
        patternSubType: 'exact_email',
        sourceDomain: email,
        executionOrder: executionOrders['header_from_exact_email']!,
        conditionField: 'header',
      );
    }
  }

  return null; // Edge case
}

/// Classify a subject pattern
PatternClassification? _classifySubjectPattern(String pattern, Set<String> usedNames) {
  // Subject patterns are typically: (?i).*KEYWORD.*
  // Extract the keyword for the name
  String keyword = pattern;

  // Remove (?i) prefix
  keyword = keyword.replaceFirst(RegExp(r'^\(\?i\)'), '');
  // Remove leading/trailing .*
  keyword = keyword.replaceFirst(RegExp(r'^\.\*'), '');
  keyword = keyword.replaceFirst(RegExp(r'\.\*$'), '');
  // Unescape
  keyword = keyword.replaceAll(r'\ ', ' ').replaceAll(r'\-', '-').replaceAll(r'\.', '.');

  final name = _generateUniqueName('subject_$keyword', usedNames);
  return PatternClassification(
    name: name,
    pattern: pattern,
    patternCategory: 'subject',
    patternSubType: 'exact_domain', // Subject patterns do not have domain subTypes; use a generic one
    sourceDomain: keyword,
    executionOrder: executionOrders['subject']!,
    conditionField: 'subject',
  );
}

/// Classify a body pattern
PatternClassification? _classifyBodyPattern(String pattern, Set<String> usedNames) {
  // Body patterns are URLs/domains like:
  //   /DOMAIN.TLD  or  /DOMAIN.  or  /.DOMAIN.  or  /IP_ADDRESS

  String identifier = pattern;

  // Remove leading / if present
  if (identifier.startsWith('/')) {
    identifier = identifier.substring(1);
  }
  // Remove leading . if present (like .imgur.)
  if (identifier.startsWith('.')) {
    identifier = identifier.substring(1);
  }
  // Unescape
  identifier = identifier.replaceAll(r'\.', '.').replaceAll(r'\-', '-');
  // Remove trailing wildcards
  identifier = identifier.replaceAll(RegExp(r'\.\*$'), '');

  // Determine if this is a TLD pattern (like %\.nl/ -> .nl)
  if (pattern.startsWith('/%\\.') || pattern.startsWith('/%\\.')) {
    // TLD pattern like /%\.nl/
    final tld = identifier.replaceAll('%', '').replaceAll('/', '');
    final name = _generateUniqueName('body_tld_$tld', usedNames);
    return PatternClassification(
      name: name,
      pattern: pattern,
      patternCategory: 'body',
      patternSubType: 'top_level_domain',
      sourceDomain: tld,
      executionOrder: executionOrders['body']!,
      conditionField: 'body',
    );
  }

  // IP address pattern
  if (RegExp(r'^\d+\.\d+\.\d+\.\d+').hasMatch(identifier)) {
    final name = _generateUniqueName('body_ip_$identifier', usedNames);
    return PatternClassification(
      name: name,
      pattern: pattern,
      patternCategory: 'body',
      patternSubType: 'exact_domain', // IP treated as exact
      sourceDomain: identifier,
      executionOrder: executionOrders['body']!,
      conditionField: 'body',
    );
  }

  // Domain pattern - extract domain name
  // Remove trailing / if present
  identifier = identifier.replaceAll('/', '');

  // If no TLD detected, default to .com
  if (!identifier.contains('.') || identifier.endsWith('.')) {
    identifier = '${identifier}com';
  }

  final name = _generateUniqueName('body_$identifier', usedNames);
  return PatternClassification(
    name: name,
    pattern: pattern,
    patternCategory: 'body',
    patternSubType: 'entire_domain',
    sourceDomain: identifier,
    executionOrder: executionOrders['body']!,
    conditionField: 'body',
  );
}

// ============================================================================
// Helper functions
// ============================================================================

/// Generate a unique rule name, appending suffix if needed
String _generateUniqueName(String base, Set<String> usedNames) {
  // Sanitize: lowercase, replace special chars
  var name = base.toLowerCase().trim();
  name = name.replaceAll(RegExp(r'[^a-z0-9._@-]'), '_');
  // Truncate to reasonable length
  if (name.length > 100) {
    name = name.substring(0, 100);
  }

  if (!usedNames.contains(name)) return name;

  // Add numeric suffix
  for (var i = 2; i < 10000; i++) {
    final candidate = '${name}_$i';
    if (!usedNames.contains(candidate)) return candidate;
  }
  return '${name}_${DateTime.now().millisecondsSinceEpoch}';
}

/// Decode JSON array from DB value
List<String> _decodeJsonArray(dynamic value) {
  if (value == null) return [];
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
  }
  return [];
}

/// Count patterns in a JSON array field
int _countPatterns(dynamic value) {
  return _decodeJsonArray(value).length;
}

/// Escape a domain string for use in a regex pattern
String _escapeForRegex(String domain) {
  return domain.replaceAll('.', '\\.').replaceAll('-', '\\-');
}
