import 'dart:convert';

import 'package:logger/logger.dart';

import '../../core/models/rule_set.dart';
import '../../core/models/safe_sender_list.dart';
import 'database_helper.dart';

/// Exception thrown when rule database storage operations fail
class RuleDatabaseStorageException implements Exception {
  final String message;
  final dynamic originalError;

  RuleDatabaseStorageException(this.message, [this.originalError]);

  @override
  String toString() =>
      'RuleDatabaseStorageException: $message${originalError != null ? '\nCause: $originalError' : ''}';
}

/// Database-backed storage for rules and safe senders
///
/// This storage implementation mirrors LocalRuleStore API but uses SQLite:
/// - Reads/writes rules to database rules table
/// - Reads/writes safe senders to database safe_senders table
/// - JSON serialization for array fields (conditions, actions, exceptions)
/// - Provides atomic get/add/update/delete operations
///
/// Example:
/// ```dart
/// final dbHelper = DatabaseHelper();
/// final store = RuleDatabaseStore(dbHelper);
///
/// // Load all rules
/// final ruleSet = await store.loadRules();
///
/// // Add a new rule
/// await store.addRule(newRule);
///
/// // Update existing rule
/// await store.updateRule(updatedRule);
///
/// // Delete rule
/// await store.deleteRule('RuleName');
/// ```
class RuleDatabaseStore {
  final RuleDatabaseProvider databaseProvider;
  final Logger _logger = Logger();

  RuleDatabaseStore(RuleDatabaseProvider provider) : databaseProvider = provider;

  /// Load all rules from database as RuleSet
  ///
  /// Returns a RuleSet containing all enabled and disabled rules.
  /// If no rules exist, returns empty RuleSet.
  Future<RuleSet> loadRules() async {
    try {
      _logger.i('Loading rules from database');

      final rulesData = await databaseProvider.queryRules();
      final rules = <Rule>[];

      for (final ruleData in rulesData) {
        try {
          final rule = _mapDatabaseRowToRule(ruleData);
          rules.add(rule);
        } catch (e) {
          _logger.w('Failed to map rule "${ruleData['name']}" from database: $e');
          // Continue loading other rules, skip malformed ones
        }
      }

      // Sort by execution_order
      rules.sort((a, b) => a.executionOrder.compareTo(b.executionOrder));

      final ruleSet = RuleSet(
        version: '1.0',
        settings: {},
        rules: rules,
      );

      _logger.i('Loaded ${rules.length} rules from database');
      return ruleSet;
    } catch (e) {
      throw RuleDatabaseStorageException('Failed to load rules from database', e);
    }
  }

  /// Load all safe senders from database as SafeSenderList
  ///
  /// Returns a SafeSenderList containing all safe sender patterns.
  /// If no patterns exist, returns empty SafeSenderList.
  Future<SafeSenderList> loadSafeSenders() async {
    try {
      _logger.i('Loading safe senders from database');

      final sendersData = await databaseProvider.querySafeSenders();
      final patterns = <String>[];

      for (final senderData in sendersData) {
        try {
          final pattern = senderData['pattern'] as String;
          patterns.add(pattern);
        } catch (e) {
          _logger.w('Failed to load safe sender pattern from database: $e');
          // Continue loading other patterns
        }
      }

      final safeSenders = SafeSenderList(safeSenders: patterns);

      _logger.i('Loaded ${patterns.length} safe sender patterns from database');
      return safeSenders;
    } catch (e) {
      throw RuleDatabaseStorageException('Failed to load safe senders from database', e);
    }
  }

  /// Save all rules to database (replace existing)
  ///
  /// Atomically replaces all rules with provided RuleSet.
  /// WARNING: This deletes all existing rules and inserts new ones.
  /// For incremental updates, use addRule/updateRule/deleteRule instead.
  Future<void> saveRules(RuleSet ruleSet) async {
    try {
      _logger.i('Saving ${ruleSet.rules.length} rules to database');

      // Delete all existing rules (cascade deletes related email_actions)
      final db = await databaseProvider.database;
      await db.delete('rules');

      // Insert all rules
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final rule in ruleSet.rules) {
        await _insertRuleToDatabase(rule, now);
      }

      _logger.i('Saved ${ruleSet.rules.length} rules to database');
    } catch (e) {
      throw RuleDatabaseStorageException('Failed to save rules to database', e);
    }
  }

  /// Save all safe senders to database (replace existing)
  ///
  /// Atomically replaces all safe senders with provided SafeSenderList.
  /// WARNING: This deletes all existing safe senders.
  /// For incremental updates, use addSafeSender/removeSafeSender instead.
  Future<void> saveSafeSenders(SafeSenderList safeSenders) async {
    try {
      _logger.i('Saving ${safeSenders.safeSenders.length} safe sender patterns to database');

      // Delete all existing safe senders
      final db = await databaseProvider.database;
      await db.delete('safe_senders');

      // Insert all patterns
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final pattern in safeSenders.safeSenders) {
        final patternType = _determinePatternType(pattern);
        await db.insert('safe_senders', {
          'pattern': pattern,
          'pattern_type': patternType,
          'exception_patterns': null,
          'date_added': now,
          'created_by': 'manual',
        });
      }

      _logger.i('Saved ${safeSenders.safeSenders.length} safe sender patterns to database');
    } catch (e) {
      throw RuleDatabaseStorageException('Failed to save safe senders to database', e);
    }
  }

  /// Get single rule by name
  ///
  /// Returns the rule if found, null if not found.
  Future<Rule?> getRule(String ruleName) async {
    try {
      final db = await databaseProvider.database;
      final results = await db.query(
        'rules',
        where: 'name = ?',
        whereArgs: [ruleName],
      );

      if (results.isEmpty) {
        return null;
      }

      return _mapDatabaseRowToRule(results.first);
    } catch (e) {
      throw RuleDatabaseStorageException('Failed to get rule "$ruleName"', e);
    }
  }

  /// Add new rule to database
  ///
  /// Throws exception if rule with same name already exists (UNIQUE constraint).
  Future<void> addRule(Rule rule) async {
    try {
      _logger.i('Adding rule "${rule.name}" to database');

      final now = DateTime.now().millisecondsSinceEpoch;
      await _insertRuleToDatabase(rule, now);

      _logger.i('Added rule "${rule.name}" to database');
    } catch (e) {
      throw RuleDatabaseStorageException('Failed to add rule "${rule.name}"', e);
    }
  }

  /// Update existing rule in database
  ///
  /// Throws exception if rule does not exist.
  Future<void> updateRule(Rule rule) async {
    try {
      _logger.i('Updating rule "${rule.name}" in database');

      final db = await databaseProvider.database;

      // Check if rule exists
      final existing = await db.query(
        'rules',
        where: 'name = ?',
        whereArgs: [rule.name],
      );

      if (existing.isEmpty) {
        throw RuleDatabaseStorageException('Rule "${rule.name}" does not exist');
      }

      final updateData = {
        'enabled': rule.enabled ? 1 : 0,
        'is_local': rule.isLocal ? 1 : 0,
        'execution_order': rule.executionOrder,
        'condition_type': rule.conditions.type,
        'condition_from': rule.conditions.from.isNotEmpty ? jsonEncode(rule.conditions.from) : null,
        'condition_header': rule.conditions.header.isNotEmpty ? jsonEncode(rule.conditions.header) : null,
        'condition_subject': rule.conditions.subject.isNotEmpty ? jsonEncode(rule.conditions.subject) : null,
        'condition_body': rule.conditions.body.isNotEmpty ? jsonEncode(rule.conditions.body) : null,
        'action_delete': rule.actions.delete ? 1 : 0,
        'action_move_to_folder': rule.actions.moveToFolder,
        'action_assign_category': rule.actions.assignToCategory,
        'exception_from': rule.exceptions?.from.isNotEmpty ?? false ? jsonEncode(rule.exceptions!.from) : null,
        'exception_header': rule.exceptions?.header.isNotEmpty ?? false ? jsonEncode(rule.exceptions!.header) : null,
        'exception_subject': rule.exceptions?.subject.isNotEmpty ?? false ? jsonEncode(rule.exceptions!.subject) : null,
        'exception_body': rule.exceptions?.body.isNotEmpty ?? false ? jsonEncode(rule.exceptions!.body) : null,
        'metadata': rule.metadata != null ? jsonEncode(rule.metadata) : null,
        'date_modified': DateTime.now().millisecondsSinceEpoch,
      };

      await db.update(
        'rules',
        updateData,
        where: 'name = ?',
        whereArgs: [rule.name],
      );

      _logger.i('Updated rule "${rule.name}" in database');
    } catch (e) {
      throw RuleDatabaseStorageException('Failed to update rule "${rule.name}"', e);
    }
  }

  /// Delete rule from database by name
  ///
  /// Throws exception if rule does not exist.
  Future<void> deleteRule(String ruleName) async {
    try {
      _logger.i('Deleting rule "$ruleName" from database');

      final db = await databaseProvider.database;

      final deletedCount = await db.delete(
        'rules',
        where: 'name = ?',
        whereArgs: [ruleName],
      );

      if (deletedCount == 0) {
        throw RuleDatabaseStorageException('Rule "$ruleName" does not exist');
      }

      _logger.i('Deleted rule "$ruleName" from database');
    } catch (e) {
      throw RuleDatabaseStorageException('Failed to delete rule "$ruleName"', e);
    }
  }

  /// Add new safe sender pattern to database
  ///
  /// Throws exception if pattern already exists (UNIQUE constraint).
  Future<void> addSafeSender(String pattern) async {
    try {
      _logger.i('Adding safe sender pattern "$pattern" to database');

      final db = await databaseProvider.database;
      final patternType = _determinePatternType(pattern);

      await db.insert('safe_senders', {
        'pattern': pattern,
        'pattern_type': patternType,
        'exception_patterns': null,
        'date_added': DateTime.now().millisecondsSinceEpoch,
        'created_by': 'manual',
      });

      _logger.i('Added safe sender pattern "$pattern" to database');
    } catch (e) {
      throw RuleDatabaseStorageException('Failed to add safe sender pattern "$pattern"', e);
    }
  }

  /// Remove safe sender pattern from database
  ///
  /// Throws exception if pattern does not exist.
  Future<void> removeSafeSender(String pattern) async {
    try {
      _logger.i('Removing safe sender pattern "$pattern" from database');

      final db = await databaseProvider.database;

      final deletedCount = await db.delete(
        'safe_senders',
        where: 'pattern = ?',
        whereArgs: [pattern],
      );

      if (deletedCount == 0) {
        throw RuleDatabaseStorageException('Safe sender pattern "$pattern" does not exist');
      }

      _logger.i('Removed safe sender pattern "$pattern" from database');
    } catch (e) {
      throw RuleDatabaseStorageException('Failed to remove safe sender pattern "$pattern"', e);
    }
  }

  /// Map database row to Rule object
  Rule _mapDatabaseRowToRule(Map<String, dynamic> row) {
    return Rule(
      name: row['name'] as String,
      enabled: (row['enabled'] as int?) == 1,
      isLocal: (row['is_local'] as int?) == 1,
      executionOrder: row['execution_order'] as int,
      conditions: RuleConditions(
        type: row['condition_type'] as String? ?? 'AND',
        from: _decodeJsonArray(row['condition_from']),
        header: _decodeJsonArray(row['condition_header']),
        subject: _decodeJsonArray(row['condition_subject']),
        body: _decodeJsonArray(row['condition_body']),
      ),
      actions: RuleActions(
        delete: (row['action_delete'] as int?) == 1,
        moveToFolder: row['action_move_to_folder'] as String?,
        assignToCategory: row['action_assign_category'] as String?,
      ),
      exceptions: row['exception_from'] != null || row['exception_header'] != null || row['exception_subject'] != null || row['exception_body'] != null
          ? RuleExceptions(
              from: _decodeJsonArray(row['exception_from']),
              header: _decodeJsonArray(row['exception_header']),
              subject: _decodeJsonArray(row['exception_subject']),
              body: _decodeJsonArray(row['exception_body']),
            )
          : null,
      metadata: row['metadata'] != null ? jsonDecode(row['metadata'] as String) as Map<String, dynamic> : null,
    );
  }

  /// Decode JSON array from database string
  List<String> _decodeJsonArray(dynamic value) {
    if (value == null) return [];
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.cast<String>();
        }
      } catch (e) {
        _logger.w('Failed to decode JSON array: $e');
      }
    }
    return [];
  }

  /// Determine pattern type from pattern string
  String _determinePatternType(String pattern) {
    if (pattern.contains('@')) {
      if (pattern.startsWith(r'^[^@')) {
        return 'domain';
      } else if (pattern.startsWith('^')) {
        return 'email';
      } else {
        return 'subdomain';
      }
    }
    return 'domain';
  }

  /// Insert rule to database (helper method)
  Future<void> _insertRuleToDatabase(Rule rule, int timestamp) async {
    final db = await databaseProvider.database;
    final dbRule = {
      'name': rule.name,
      'enabled': rule.enabled ? 1 : 0,
      'is_local': rule.isLocal ? 1 : 0,
      'execution_order': rule.executionOrder,
      'condition_type': rule.conditions.type,
      'condition_from': rule.conditions.from.isNotEmpty ? jsonEncode(rule.conditions.from) : null,
      'condition_header': rule.conditions.header.isNotEmpty ? jsonEncode(rule.conditions.header) : null,
      'condition_subject': rule.conditions.subject.isNotEmpty ? jsonEncode(rule.conditions.subject) : null,
      'condition_body': rule.conditions.body.isNotEmpty ? jsonEncode(rule.conditions.body) : null,
      'action_delete': rule.actions.delete ? 1 : 0,
      'action_move_to_folder': rule.actions.moveToFolder,
      'action_assign_category': rule.actions.assignToCategory,
      'exception_from': rule.exceptions?.from.isNotEmpty ?? false ? jsonEncode(rule.exceptions!.from) : null,
      'exception_header': rule.exceptions?.header.isNotEmpty ?? false ? jsonEncode(rule.exceptions!.header) : null,
      'exception_subject': rule.exceptions?.subject.isNotEmpty ?? false ? jsonEncode(rule.exceptions!.subject) : null,
      'exception_body': rule.exceptions?.body.isNotEmpty ?? false ? jsonEncode(rule.exceptions!.body) : null,
      'metadata': rule.metadata != null ? jsonEncode(rule.metadata) : null,
      'date_added': timestamp,
      'created_by': 'manual',
    };

    await db.insert('rules', dbRule);
  }
}
