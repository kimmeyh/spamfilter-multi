import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import '../storage/database_helper.dart';
import 'yaml_service.dart';

/// Service for managing default rule set seeding and reset.
///
/// Reads the bundled YAML assets (rules.yaml and rules_safe_senders.yaml)
/// and seeds the database with default rules and safe senders when the
/// database is empty (new install) or on user request (reset to defaults).
class DefaultRuleSetService {
  final DatabaseHelper _dbHelper;
  final Logger _logger = Logger();

  static const String _rulesAssetPath = 'assets/rules/rules.yaml';
  static const String _safeSendersAssetPath =
      'assets/rules/rules_safe_senders.yaml';

  DefaultRuleSetService(this._dbHelper);

  /// Seed the database with default rules if it is empty.
  ///
  /// Called during app initialization after database is ready.
  /// Only seeds if both rules and safe senders tables are empty.
  /// Returns the number of rules and safe senders seeded.
  Future<({int rules, int safeSenders})> seedIfEmpty() async {
    final db = await _dbHelper.database;

    final existingRules = await db.query('rules', limit: 1);
    final existingSafeSenders = await db.query('safe_senders', limit: 1);

    if (existingRules.isNotEmpty || existingSafeSenders.isNotEmpty) {
      _logger.d('Database already has rules or safe senders, skipping seed');
      return (rules: 0, safeSenders: 0);
    }

    _logger.i('Empty database detected, seeding with default rules');
    return _seedFromAssets(db);
  }

  /// Reset the database to default rules and safe senders.
  ///
  /// Clears all existing rules and safe senders, then seeds from bundled
  /// YAML assets. Returns the number of rules and safe senders seeded.
  Future<({int rules, int safeSenders})> resetToDefaults() async {
    final db = await _dbHelper.database;

    _logger.i('Resetting rules and safe senders to defaults');

    return db.transaction((txn) async {
      // Clear existing data
      await txn.delete('rules');
      await txn.delete('safe_senders');
      _logger.i('Cleared existing rules and safe senders');

      // Seed from bundled assets within the same transaction
      return _seedFromAssetsInTransaction(txn);
    });
  }

  /// Load and seed rules and safe senders from bundled YAML assets.
  Future<({int rules, int safeSenders})> _seedFromAssets(Database db) async {
    return await db.transaction((txn) async {
      return await _seedFromAssetsInTransaction(txn);
    });
  }

  Future<({int rules, int safeSenders})> _seedFromAssetsInTransaction(
      Transaction txn) async {
    int rulesSeeded = 0;
    int safeSendersSeeded = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Seed rules
    try {
      final rulesYaml = await rootBundle.loadString(_rulesAssetPath);
      final yamlService = YamlService();
      final ruleSet = yamlService.parseRulesFromString(rulesYaml);

      for (final rule in ruleSet.rules) {
        final dbRule = {
          'name': rule.name,
          'enabled': rule.enabled ? 1 : 0,
          'is_local': rule.isLocal ? 1 : 0,
          'execution_order': rule.executionOrder,
          'condition_type': rule.conditions.type,
          'condition_from': rule.conditions.from.isNotEmpty
              ? jsonEncode(rule.conditions.from)
              : null,
          'condition_header': rule.conditions.header.isNotEmpty
              ? jsonEncode(rule.conditions.header)
              : null,
          'condition_subject': rule.conditions.subject.isNotEmpty
              ? jsonEncode(rule.conditions.subject)
              : null,
          'condition_body': rule.conditions.body.isNotEmpty
              ? jsonEncode(rule.conditions.body)
              : null,
          'action_delete': rule.actions.delete ? 1 : 0,
          'action_move_to_folder': rule.actions.moveToFolder,
          'action_assign_category': rule.actions.assignToCategory,
          'exception_from': rule.exceptions?.from.isNotEmpty ?? false
              ? jsonEncode(rule.exceptions!.from)
              : null,
          'exception_header': rule.exceptions?.header.isNotEmpty ?? false
              ? jsonEncode(rule.exceptions!.header)
              : null,
          'exception_subject': rule.exceptions?.subject.isNotEmpty ?? false
              ? jsonEncode(rule.exceptions!.subject)
              : null,
          'exception_body': rule.exceptions?.body.isNotEmpty ?? false
              ? jsonEncode(rule.exceptions!.body)
              : null,
          'metadata': rule.metadata != null ? jsonEncode(rule.metadata) : null,
          'date_added': now,
          'created_by': 'default',
          'pattern_category': rule.patternCategory,
          'pattern_sub_type': rule.patternSubType,
          'source_domain': rule.sourceDomain,
        };

        await txn.insert('rules', dbRule);
        rulesSeeded++;
      }

      _logger.i('Seeded $rulesSeeded default rules');
    } catch (e) {
      _logger.e('Failed to seed default rules', error: e);
    }

    // Seed safe senders
    try {
      final safeSendersYaml =
          await rootBundle.loadString(_safeSendersAssetPath);
      final yamlService = YamlService();
      final safeSenderList = yamlService.parseSafeSendersFromString(safeSendersYaml);

      for (final pattern in safeSenderList.safeSenders) {
        final dbSafeSender = {
          'pattern': pattern,
          'pattern_type': _classifyPatternType(pattern),
          'date_added': now,
          'created_by': 'default',
        };

        await txn.insert('safe_senders', dbSafeSender);
        safeSendersSeeded++;
      }

      _logger.i('Seeded $safeSendersSeeded default safe senders');
    } catch (e) {
      _logger.e('Failed to seed default safe senders', error: e);
    }

    return (rules: rulesSeeded, safeSenders: safeSendersSeeded);
  }

  /// TLD block patterns added post-initial-seed (F53, Sprint 33).
  ///
  /// These patterns block emails from specific top-level domains that are
  /// frequently used for spam. Each pattern is ensured to exist as an
  /// individual per-pattern row in the rules table. This migration is
  /// idempotent: running it multiple times has no effect beyond the first run.
  ///
  /// If new TLD patterns are added in future sprints, append them here --
  /// the migration will add only the missing ones.
  static const List<String> _postSeedTldBlockPatterns = <String>[
    r'@.*\.cc$', // Cocos Islands (F53, Sprint 33)
    r'@.*\.ne$', // Niger (F53, Sprint 33)
  ];

  /// Name of the legacy monolithic rule that previously held TLD block
  /// patterns in its condition_header array. Retained for backwards-compat
  /// lookup during migration (F73).
  static const String _tldBlockRuleName = 'SpamAutoDeleteHeader';

  /// Ensure post-seed TLD block patterns exist as individual per-pattern rows.
  ///
  /// Called during app initialization after seedIfEmpty. On existing installs
  /// (where seedIfEmpty is a no-op), this ensures each pattern in
  /// [_postSeedTldBlockPatterns] exists as its own row in the rules table.
  ///
  /// For each pattern, checks two locations:
  /// 1. Individual row: condition_header matches the single-pattern JSON array
  ///    AND pattern_category = 'header_from' AND pattern_sub_type =
  ///    'top_level_domain'.
  /// 2. Legacy monolithic row: the old SpamAutoDeleteHeader rule (if it still
  ///    exists) contains the pattern in its condition_header JSON array.
  ///
  /// If found in either location, the pattern is skipped. If not found, a new
  /// individual rule row is inserted.
  ///
  /// Returns the number of patterns added. Returns 0 if all patterns are
  /// already present (idempotent).
  Future<int> ensureTldBlockRules() async {
    final db = await _dbHelper.database;
    int added = 0;

    // Pre-fetch the legacy monolithic rule (if it still exists) for
    // backwards-compat checking.
    final legacyRows = await db.query(
      'rules',
      columns: ['condition_header'],
      where: 'name = ?',
      whereArgs: [_tldBlockRuleName],
      limit: 1,
    );
    final Set<String> legacyPatterns = <String>{};
    if (legacyRows.isNotEmpty) {
      final legacyJson = legacyRows.first['condition_header'] as String?;
      if (legacyJson != null) {
        legacyPatterns.addAll(
          List<String>.from(jsonDecode(legacyJson) as List),
        );
      }
    }

    for (final pattern in _postSeedTldBlockPatterns) {
      // Extract the TLD from the pattern (e.g., 'cc' from r'@.*\.cc$').
      final tldMatch = RegExp(r'\\\.([\w]+)\$$').firstMatch(pattern);
      final tld = tldMatch?.group(1) ?? 'unknown';

      // Check 1: any existing individual row already carries this pattern as
      // its sole condition_header entry, regardless of pattern_sub_type.
      // The bundled YAML rebuild (F73 Part B) currently classifies bare
      // @.*\.tld$ patterns as exact_domain rather than top_level_domain;
      // we accept either classification here so a fresh-install seeding does
      // not lead to a duplicate insert by this migration. (Copilot review
      // PR #236 finding -- April 2026.)
      final individualRows = await db.query(
        'rules',
        columns: ['id'],
        where: "condition_header = ? AND pattern_category = 'header_from'",
        whereArgs: [jsonEncode([pattern])],
        limit: 1,
      );
      if (individualRows.isNotEmpty) {
        _logger.d('TLD pattern already exists as individual row: $pattern');
        continue;
      }

      // Check 2: pattern exists in the legacy monolithic rule.
      if (legacyPatterns.contains(pattern)) {
        _logger.d('TLD pattern found in legacy $_tldBlockRuleName: $pattern');
        continue;
      }

      // Insert a new individual rule row for this TLD pattern. Use a unique
      // name to avoid colliding with any prior migration variant or
      // user-created rule with the same base name (Copilot review finding).
      final now = DateTime.now().millisecondsSinceEpoch;
      final baseName = '.*.$tld';
      final uniqueName = await _generateUniqueNameOnDb(db, baseName);
      try {
        await db.insert('rules', {
          'name': uniqueName,
          'enabled': 1,
          'is_local': 1,
          'execution_order': 10,
          'condition_type': 'OR',
          'condition_header': jsonEncode([pattern]),
          'action_delete': 1,
          'date_added': now,
          'created_by': 'migration_f53',
          'pattern_category': 'header_from',
          'pattern_sub_type': 'top_level_domain',
          'source_domain': baseName,
        });
        added++;
        _logger.i('Added TLD block rule for .$tld: $pattern (name=$uniqueName)');
      } on DatabaseException catch (e) {
        // Defensive fallback: if a UNIQUE constraint violation slips through
        // (e.g., a concurrent migration produced the same name between the
        // uniqueness check and the insert), treat the pattern as already
        // present rather than crashing app startup.
        if (e.isUniqueConstraintError()) {
          _logger.w(
              'TLD pattern insert hit unique constraint, treating as present: $pattern');
          continue;
        }
        rethrow;
      }
    }

    if (added > 0) {
      _logger.i('ensureTldBlockRules: added $added new TLD block rule(s)');
    } else {
      _logger.d('All post-seed TLD block patterns already present');
    }
    return added;
  }

  // ---------------------------------------------------------------------------
  // F73: Split monolithic rules into individual per-pattern rows
  // ---------------------------------------------------------------------------

  /// Regular expressions used to classify header/from patterns into sub-types.
  static final RegExp _tldPatternRe = RegExp(r'^@\.\*\\\.([a-z]+)\$$');
  static final RegExp _entireDomainRe =
      RegExp(r'\(\?:\[a-z0-9-\]\+\\\.\)\*');
  static final RegExp _exactEmailRe = RegExp(r'^\^[^@]+@.+\$$');

  /// Extract a human-readable domain/identifier from a pattern for use as
  /// the rule name and source_domain.
  static String _extractSourceDomain(
    String pattern,
    String subType,
  ) {
    switch (subType) {
      case 'top_level_domain':
        // e.g., r'@.*\.cc$' -> '.*.cc'
        // (Single-dot form to match ManualRuleCreateScreen and rebuild_rules_yaml.py)
        final m = RegExp(r'\\\.([\w]+)\$$').firstMatch(pattern);
        return m != null ? '.*.${m.group(1)!}' : pattern;

      case 'entire_domain':
        // e.g., r'@(?:[a-z0-9-]+\.)*americasurveys\.com$' -> 'americasurveys.com'
        final m = RegExp(
          r'\(\?:\[a-z0-9-\]\+\\\.\)\*([a-z0-9.-]+)\\\.',
        ).firstMatch(pattern);
        if (m != null) {
          // Reconstruct domain: captured group + remaining TLD after last \.
          final domainPart = m.group(1)!;
          // Get the rest after the match to find the TLD
          final afterMatch = pattern.substring(m.end);
          final tldMatch = RegExp(r'^([a-z0-9.-]+)\$$').firstMatch(afterMatch);
          if (tldMatch != null) {
            return '$domainPart.${tldMatch.group(1)!}';
          }
          return domainPart;
        }
        return _truncate(pattern, 50);

      case 'exact_email':
        // e.g., r'^user@domain.com$' -> 'user@domain.com'
        final cleaned =
            pattern.replaceAll('^', '').replaceAll(r'$', '').replaceAll(r'\.', '.');
        return _truncate(cleaned, 50);

      case 'exact_domain':
        // e.g., r'@domain\.com$' -> 'domain.com'
        final m = RegExp(r'@(.+)\$$').firstMatch(pattern);
        if (m != null) {
          return m.group(1)!.replaceAll(r'\.', '.').replaceAll(r'\', '');
        }
        return _truncate(pattern, 50);

      default:
        return _truncate(pattern, 50);
    }
  }

  /// Truncate a string to the given maximum length.
  static String _truncate(String s, int maxLength) {
    return s.length <= maxLength ? s : s.substring(0, maxLength);
  }

  /// Classify a header/from pattern into (patternCategory, patternSubType,
  /// executionOrder).
  static ({String category, String subType, int order}) _classifyHeaderPattern(
    String pattern,
  ) {
    if (_tldPatternRe.hasMatch(pattern)) {
      return (
        category: 'header_from',
        subType: 'top_level_domain',
        order: 10,
      );
    }
    if (_entireDomainRe.hasMatch(pattern)) {
      return (
        category: 'header_from',
        subType: 'entire_domain',
        order: 20,
      );
    }
    if (_exactEmailRe.hasMatch(pattern)) {
      return (
        category: 'header_from',
        subType: 'exact_email',
        order: 40,
      );
    }
    if (pattern.startsWith('@')) {
      return (
        category: 'header_from',
        subType: 'exact_domain',
        order: 30,
      );
    }
    // Fallback: treat as exact_domain
    return (
      category: 'header_from',
      subType: 'exact_domain',
      order: 30,
    );
  }

  /// Split any remaining monolithic rules into individual per-pattern rows.
  ///
  /// A "monolithic" rule is one with pattern_category IS NULL and at least one
  /// condition field containing a JSON array with more than one pattern. This
  /// migration splits each such rule into individual rows, one per pattern,
  /// with proper classification metadata.
  ///
  /// Idempotent: rules that already have pattern_category set are skipped.
  /// Runs inside a DB transaction for atomicity.
  ///
  /// Returns the total number of individual rules created.
  Future<int> splitMonolithicRules() async {
    final db = await _dbHelper.database;

    // Find all rules without pattern_category (monolithic candidates).
    final monolithicRows = await db.query(
      'rules',
      where: 'pattern_category IS NULL',
    );

    if (monolithicRows.isEmpty) {
      _logger.d('No monolithic rules found to split');
      return 0;
    }

    int totalCreated = 0;

    await db.transaction((txn) async {
      for (final row in monolithicRows) {
        final ruleId = row['id'] as int;
        final ruleName = row['name'] as String? ?? 'unknown';
        final enabled = row['enabled'] as int? ?? 1;
        final isLocal = row['is_local'] as int? ?? 1;
        final actionDelete = row['action_delete'] as int? ?? 1;

        // Collect all patterns from all condition fields.
        final conditionFields = <String, String>{
          'condition_header': 'header',
          'condition_from': 'from',
          'condition_subject': 'subject',
          'condition_body': 'body',
        };

        bool hasMultiPattern = false;
        final List<_PendingIndividualRule> pendingRules = [];

        for (final entry in conditionFields.entries) {
          final fieldName = entry.key;
          final fieldType = entry.value;
          final jsonStr = row[fieldName] as String?;
          if (jsonStr == null) continue;

          final List<dynamic> patterns;
          try {
            patterns = jsonDecode(jsonStr) as List<dynamic>;
          } catch (_) {
            continue;
          }

          if (patterns.length <= 1) continue;
          hasMultiPattern = true;

          for (final p in patterns) {
            final pattern = p as String;
            late String category;
            late String subType;
            late int order;

            if (fieldType == 'header' || fieldType == 'from') {
              final classification = _classifyHeaderPattern(pattern);
              category = classification.category;
              subType = classification.subType;
              order = classification.order;
            } else if (fieldType == 'subject') {
              category = 'subject';
              subType = 'exact_domain';
              order = 60;
            } else {
              // body
              category = 'body';
              subType = 'entire_domain';
              order = 50;
            }

            final sourceDomain = _extractSourceDomain(pattern, subType);

            pendingRules.add(_PendingIndividualRule(
              conditionField: fieldName,
              pattern: pattern,
              category: category,
              subType: subType,
              order: order,
              sourceDomain: sourceDomain,
            ));
          }
        }

        if (!hasMultiPattern) {
          // Rule has no multi-pattern condition fields; skip it.
          continue;
        }

        // Insert individual rows for each pattern.
        for (final pending in pendingRules) {
          final candidateName =
              await _generateUniqueName(txn, pending.sourceDomain);

          await txn.insert('rules', {
            'name': candidateName,
            'enabled': enabled,
            'is_local': isLocal,
            'execution_order': pending.order,
            'condition_type': 'OR',
            pending.conditionField: jsonEncode([pending.pattern]),
            'action_delete': actionDelete,
            'date_added': DateTime.now().millisecondsSinceEpoch,
            'created_by': 'migration_f73',
            'pattern_category': pending.category,
            'pattern_sub_type': pending.subType,
            'source_domain': pending.sourceDomain,
          });
          totalCreated++;
        }

        // Delete the original monolithic rule.
        await txn.delete('rules', where: 'id = ?', whereArgs: [ruleId]);
        _logger.i(
          'F73: Split monolithic rule "$ruleName" (id=$ruleId) into '
          '${pendingRules.length} individual rows',
        );
      }
    });

    if (totalCreated > 0) {
      _logger.i('F73: splitMonolithicRules created $totalCreated individual '
          'rule(s)');
    }
    return totalCreated;
  }

  /// Generate a unique rule name by appending _2, _3, etc. if needed.
  Future<String> _generateUniqueName(
    Transaction txn,
    String baseName,
  ) async {
    // Try the base name first.
    var candidate = baseName;
    var existing = await txn.query(
      'rules',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [candidate],
      limit: 1,
    );
    if (existing.isEmpty) return candidate;

    // Append numeric suffix until unique.
    for (var i = 2; i < 100000; i++) {
      candidate = '${baseName}_$i';
      existing = await txn.query(
        'rules',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [candidate],
        limit: 1,
      );
      if (existing.isEmpty) return candidate;
    }

    // Extremely unlikely fallback.
    return '${baseName}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Generate a unique rule name (Database-context variant of [_generateUniqueName]).
  ///
  /// Used by [ensureTldBlockRules] which runs against a Database handle rather
  /// than inside a Transaction.
  Future<String> _generateUniqueNameOnDb(
    Database db,
    String baseName,
  ) async {
    var candidate = baseName;
    var existing = await db.query(
      'rules',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [candidate],
      limit: 1,
    );
    if (existing.isEmpty) return candidate;

    for (var i = 2; i < 100000; i++) {
      candidate = '${baseName}_$i';
      existing = await db.query(
        'rules',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [candidate],
        limit: 1,
      );
      if (existing.isEmpty) return candidate;
    }
    return '${baseName}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Classify a safe sender pattern into its type.
  ///
  /// Mirrors SafeSenderList._determinePatternType logic.
  static String _classifyPatternType(String pattern) {
    if (pattern.contains(r'(?:') || pattern.contains(r'[a-z0-9-]+\.)*')) {
      return 'entire_domain';
    }
    if (pattern.startsWith('^') && pattern.contains('@')) {
      final beforeAt = pattern.substring(1).split('@')[0];
      if (!beforeAt.startsWith('[') &&
          !beforeAt.startsWith('(') &&
          beforeAt.isNotEmpty) {
        return 'exact_email';
      }
    }
    if (pattern.contains('@') && !pattern.contains(r'[^@')) {
      return 'exact_domain';
    }
    return 'exact_domain';
  }
}

/// Internal helper for collecting pending individual rule data during
/// monolithic rule splitting.
class _PendingIndividualRule {
  final String conditionField;
  final String pattern;
  final String category;
  final String subType;
  final int order;
  final String sourceDomain;

  const _PendingIndividualRule({
    required this.conditionField,
    required this.pattern,
    required this.category,
    required this.subType,
    required this.order,
    required this.sourceDomain,
  });
}
