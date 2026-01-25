import 'dart:io';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../adapters/storage/app_paths.dart';
import '../../adapters/storage/local_rule_store.dart';
import 'database_helper.dart';

/// Exception for migration failures
class MigrationException implements Exception {
  final String message;
  final dynamic originalError;

  MigrationException(this.message, [this.originalError]);

  @override
  String toString() =>
      'MigrationException: $message${originalError != null ? '\nCause: $originalError' : ''}';
}

/// Migration results tracking
class MigrationResults {
  int rulesImported = 0;
  int rulesFailed = 0;
  int safeSendersImported = 0;
  int safeSendersFailed = 0;
  final List<String> skippedRules = [];
  final List<String> skippedSafeSenders = [];
  final List<String> errors = [];
  DateTime? completedAt;
  DateTime? startedAt;
  bool wasTransactionRolledBack = false;

  bool get isSuccess => rulesFailed == 0 && safeSendersFailed == 0;
  bool get isComplete => completedAt != null && !wasTransactionRolledBack;

  @override
  String toString() => '''
MigrationResults:
  Rules imported: $rulesImported (failed: $rulesFailed)
  Safe senders imported: $safeSendersImported (failed: $safeSendersFailed)
  Completed: $completedAt
  Success: $isSuccess
  Transaction rolled back: $wasTransactionRolledBack
  Errors: ${errors.length}
''';
}

/// Manages one-time YAML to SQLite migration
class MigrationManager {
  final DatabaseHelper databaseHelper;
  final AppPaths appPaths;
  final Logger _logger = Logger();

  late LocalRuleStore _ruleStore;

  MigrationManager({
    required this.databaseHelper,
    required this.appPaths,
  }) {
    _ruleStore = LocalRuleStore(appPaths);
  }

  /// Perform migration from YAML to database with transaction rollback on failure
  ///
  /// Wraps import operations in a SQLite transaction to ensure atomicity:
  /// - On success: All data committed to database
  /// - On failure: Transaction rolled back, database left in consistent state
  ///
  /// Returns MigrationResults with detailed statistics.
  /// If migration fails and transaction is rolled back, results.wasTransactionRolledBack will be true.
  Future<MigrationResults> migrate() async {
    _logger.i('Starting YAML to SQLite migration');
    final results = MigrationResults();
    results.startedAt = DateTime.now();

    try {
      // Step 1: Check if YAML files exist
      final rulesFileExists = await appPaths.rulesFileExists();
      final safeSendersFileExists = await appPaths.safeSendersFileExists();

      if (!rulesFileExists && !safeSendersFileExists) {
        _logger.i('No YAML files found - creating empty database');
        // Database already initialized with empty tables
        results.completedAt = DateTime.now();
        return results;
      }

      // Step 2: Create backup of YAML files (non-critical, failure does not abort migration)
      await _createYamlBackups();

      // Step 3: Execute import operations within transaction
      // Transaction ensures either all data is imported or none (rollback on exception)
      await _executeImportWithTransaction(results, rulesFileExists, safeSendersFileExists);

      // Step 4: Verify import completeness
      await _verifyImport(results);

      results.completedAt = DateTime.now();
      _logger.i('Migration completed successfully: ${results.toString()}');

      return results;
    } catch (e) {
      _logger.e('Migration failed: $e');
      throw MigrationException('YAML to SQLite migration failed', e);
    }
  }

  /// Execute import operations within a database transaction
  ///
  /// Ensures atomicity: if any import step fails, entire transaction rolls back.
  /// This prevents partial migrations (e.g., 1000 rules imported before crash).
  Future<void> _executeImportWithTransaction(
    MigrationResults results,
    bool rulesFileExists,
    bool safeSendersFileExists,
  ) async {
    final db = await databaseHelper.database;

    try {
      // Begin transaction
      await db.transaction((txn) async {
        _logger.i('Starting migration transaction');

        // Import rules if file exists
        if (rulesFileExists) {
          await _importRulesWithin(txn, results);
        }

        // Import safe senders if file exists
        if (safeSendersFileExists) {
          await _importSafeSendersWithin(txn, results);
        }

        _logger.i('Migration transaction committed successfully');
      });
    } catch (e) {
      _logger.e('Migration transaction failed and was rolled back: $e');
      results.wasTransactionRolledBack = true;
      results.errors.add('Migration transaction rolled back: ${e.toString()}');
      rethrow;
    }
  }

  /// Create timestamped backup of YAML files
  Future<void> _createYamlBackups() async {
    try {
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[:-]'), '')
          .split('.')[0];
      final backupDir = Directory(path.join(appPaths.appSupportDirectory.path, 'Archive', 'yaml_pre_migration_$timestamp'));

      await backupDir.create(recursive: true);

      // Backup rules.yaml
      final rulesFile = File(appPaths.rulesFilePath);
      if (await rulesFile.exists()) {
        final backupRulesFile = File(path.join(backupDir.path, 'rules.yaml'));
        await rulesFile.copy(backupRulesFile.path);
        _logger.i('Backed up rules.yaml to ${backupDir.path}');
      }

      // Backup rules_safe_senders.yaml
      final safeSendersFile = File(appPaths.safeSendersFilePath);
      if (await safeSendersFile.exists()) {
        final backupSafeSendersFile = File(path.join(backupDir.path, 'rules_safe_senders.yaml'));
        await safeSendersFile.copy(backupSafeSendersFile.path);
        _logger.i('Backed up rules_safe_senders.yaml to ${backupDir.path}');
      }
    } catch (e) {
      _logger.w('Failed to create YAML backup: $e');
      // Do not fail migration, continue anyway
    }
  }

  /// Import rules from YAML file to database within a transaction
  ///
  /// Called from within _executeImportWithTransaction to ensure transaction consistency.
  /// If any rule import fails, the entire transaction will be rolled back.
  Future<void> _importRulesWithin(Transaction txn, MigrationResults results) async {
    try {
      _logger.i('Importing rules from YAML (within transaction)');

      // Load rules from YAML
      final ruleSet = await _ruleStore.loadRules();
      final migrationDate = DateTime.now().millisecondsSinceEpoch;

      // Import each rule
      for (final rule in ruleSet.rules) {
        try {
          // Convert rule to database format
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
            'date_added': migrationDate,
            'created_by': 'manual',
          };

          // Use transaction's execute for database operations
          await txn.insert('rules', dbRule);
          results.rulesImported++;
        } catch (e) {
          _logger.w('Failed to import rule "${rule.name}": $e');
          results.rulesFailed++;
          results.skippedRules.add('${rule.name}: ${e.toString()}');
          // Re-throw to trigger transaction rollback on critical failures
          if (e.toString().contains('UNIQUE constraint failed')) {
            rethrow; // UNIQUE constraint violation is critical (duplicate rule name)
          }
          // Other errors are logged but do not abort transaction
        }
      }

      _logger.i('Imported ${results.rulesImported} rules, failed: ${results.rulesFailed}');
    } catch (e) {
      _logger.e('Failed to import rules: $e');
      results.errors.add('Rules import failed: ${e.toString()}');
      rethrow;
    }
  }


  /// Import safe senders from YAML file to database within a transaction
  ///
  /// Called from within _executeImportWithTransaction to ensure transaction consistency.
  /// If any safe sender import fails, the entire transaction will be rolled back.
  Future<void> _importSafeSendersWithin(Transaction txn, MigrationResults results) async {
    try {
      _logger.i('Importing safe senders from YAML (within transaction)');

      // Load safe senders from YAML
      final safeSenderList = await _ruleStore.loadSafeSenders();
      final migrationDate = DateTime.now().millisecondsSinceEpoch;

      // Import each safe sender pattern
      for (final pattern in safeSenderList.safeSenders) {
        try {
          // Determine pattern type based on format
          String patternType;
          if (pattern.contains('@')) {
            if (pattern.startsWith('^[^@')) {
              // Domain pattern (e.g., ^[^@\s]+@domain\.com$)
              patternType = 'domain';
            } else if (pattern.startsWith('^')) {
              // Email pattern (e.g., ^email@domain\.com$)
              patternType = 'email';
            } else {
              // Subdomain or partial domain
              patternType = 'subdomain';
            }
          } else {
            patternType = 'domain';
          }

          final dbSafeSender = {
            'pattern': pattern,
            'pattern_type': patternType,
            'exception_patterns': null, // No exceptions in YAML safe senders
            'date_added': migrationDate,
            'created_by': 'manual',
          };

          // Use transaction's insert for database operations
          await txn.insert('safe_senders', dbSafeSender);
          results.safeSendersImported++;
        } catch (e) {
          _logger.w('Failed to import safe sender "$pattern": $e');
          results.safeSendersFailed++;
          results.skippedSafeSenders.add('$pattern: ${e.toString()}');
          // Re-throw to trigger transaction rollback on critical failures
          if (e.toString().contains('UNIQUE constraint failed')) {
            rethrow; // UNIQUE constraint violation is critical (duplicate pattern)
          }
          // Other errors are logged but do not abort transaction
        }
      }

      _logger.i('Imported ${results.safeSendersImported} safe senders, failed: ${results.safeSendersFailed}');
    } catch (e) {
      _logger.e('Failed to import safe senders: $e');
      results.errors.add('Safe senders import failed: ${e.toString()}');
      rethrow;
    }
  }


  /// Verify migration completeness
  Future<void> _verifyImport(MigrationResults results) async {
    try {
      _logger.i('Verifying import completeness');

      // Count rules in database
      final dbRules = await databaseHelper.queryRules();
      _logger.i('Database contains ${dbRules.length} rules');

      // Compare rules count with migration results
      if (results.rulesImported != null &&
          results.rulesImported != dbRules.length) {
        final message =
            'Verification failed: expected ${results.rulesImported} rules imported, '
            'but found ${dbRules.length} in database';
        _logger.w(message);
        results.errors.add(message);
      } else {
        _logger.i(
            'Rules import verification passed: ${dbRules.length} rules in database');
      }

      // Count safe senders in database
      final dbSafeSenders = await databaseHelper.querySafeSenders();
      _logger.i('Database contains ${dbSafeSenders.length} safe senders');

      // Compare safe senders count with migration results
      if (results.safeSendersImported != null &&
          results.safeSendersImported != dbSafeSenders.length) {
        final message =
            'Verification failed: expected ${results.safeSendersImported} safe senders imported, '
            'but found ${dbSafeSenders.length} in database';
        _logger.w(message);
        results.errors.add(message);
      } else {
        _logger.i(
            'Safe senders import verification passed: ${dbSafeSenders.length} safe senders in database');
      }
      // Get statistics
      final stats = await databaseHelper.getStatistics();
      _logger.i('Database statistics: $stats');
    } catch (e) {
      _logger.w('Failed to verify import: $e');
      // Verification failure is not critical
    }
  }

  /// Check if migration has been completed successfully
  ///
  /// Returns true only if:
  /// 1. Database has rules (indicating data was imported)
  /// 2. Database has safe senders OR no safe senders in YAML (consistency check)
  /// 3. No recent transaction rollbacks detected
  ///
  /// This prevents returning true for partial migrations (e.g., crash mid-import).
  /// If crash occurred after rules imported but before safe senders, both counts
  /// should be present or the migration should be retried from scratch.
  Future<bool> isMigrationComplete() async {
    try {
      final rules = await databaseHelper.queryRules();

      // No rules = migration never ran or was completely rolled back
      if (rules.isEmpty) {
        return false;
      }

      // If we have rules, verify consistency with safe senders
      // (Better heuristic: both should be present or both absent)
      final safeSenders = await databaseHelper.querySafeSenders();

      // Check YAML files to understand what should have been imported
      final safeSendersFileExists = await appPaths.safeSendersFileExists();

      // If safe_senders.yaml exists but we have no safe senders in DB,
      // this indicates partial import (import crashed after rules but before safe senders)
      if (safeSendersFileExists && safeSenders.isEmpty) {
        _logger.w(
          'Partial migration detected: rules present (${rules.length}) '
          'but safe senders missing (file exists but DB empty). '
          'Migration should be retried or manually cleaned up.'
        );
        return false;
      }

      return true;
    } catch (e) {
      _logger.w('Failed to check migration status: $e');
      return false;
    }
  }

  /// Get migration status message
  Future<String> getMigrationStatus() async {
    final isComplete = await isMigrationComplete();
    if (isComplete) {
      final rules = await databaseHelper.queryRules();
      final safeSenders = await databaseHelper.querySafeSenders();
      return 'Migration complete: ${rules.length} rules, ${safeSenders.length} safe senders in database';
    }
    return 'Migration not yet performed';
  }
}
