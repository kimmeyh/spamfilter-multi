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
  /// frequently used for spam. They are added to the SpamAutoDeleteHeader
  /// rule's condition_header list if not already present. This migration is
  /// idempotent: running it multiple times has no effect beyond the first run.
  ///
  /// If new TLD patterns are added in future sprints, append them here --
  /// the migration will add only the missing ones.
  static const List<String> _postSeedTldBlockPatterns = <String>[
    r'@.*\.cc$', // Cocos Islands (F53, Sprint 33)
    r'@.*\.ne$', // Niger (F53, Sprint 33)
  ];

  /// Name of the bundled rule that holds TLD block patterns in its
  /// condition_header array. Keep in sync with assets/rules/rules.yaml.
  static const String _tldBlockRuleName = 'SpamAutoDeleteHeader';

  /// Ensure post-seed TLD block patterns are present in existing databases.
  ///
  /// Called during app initialization after seedIfEmpty. On existing
  /// installs (where seedIfEmpty is a no-op), this adds any TLD block
  /// patterns listed in _postSeedTldBlockPatterns that are missing from
  /// the SpamAutoDeleteHeader rule's condition_header JSON array.
  ///
  /// Returns the number of patterns added. Returns 0 if all patterns are
  /// already present (idempotent).
  ///
  /// If the rule does not exist (fresh install will have been seeded from
  /// YAML which already contains the patterns), this is a no-op.
  Future<int> ensureTldBlockRules() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'rules',
      columns: ['id', 'condition_header'],
      where: 'name = ?',
      whereArgs: [_tldBlockRuleName],
      limit: 1,
    );

    if (rows.isEmpty) {
      _logger.d('$_tldBlockRuleName rule not found; skipping TLD migration');
      return 0;
    }

    final row = rows.first;
    final ruleId = row['id'] as int;
    final conditionHeaderJson = row['condition_header'] as String?;

    final List<String> headers = conditionHeaderJson == null
        ? <String>[]
        : List<String>.from(jsonDecode(conditionHeaderJson) as List);

    final existing = headers.toSet();
    final toAdd = _postSeedTldBlockPatterns
        .where((p) => !existing.contains(p))
        .toList(growable: false);

    if (toAdd.isEmpty) {
      _logger.d('All post-seed TLD block patterns already present');
      return 0;
    }

    headers.addAll(toAdd);
    headers.sort();

    await db.update(
      'rules',
      {'condition_header': jsonEncode(headers)},
      where: 'id = ?',
      whereArgs: [ruleId],
    );

    _logger.i('Added ${toAdd.length} TLD block pattern(s) to '
        '$_tldBlockRuleName: ${toAdd.join(", ")}');
    return toAdd.length;
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
