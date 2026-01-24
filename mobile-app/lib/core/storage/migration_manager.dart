import 'dart:io';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

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

  bool get isSuccess => rulesFailed == 0 && safeSendersFailed == 0;

  @override
  String toString() => '''
MigrationResults:
  Rules imported: $rulesImported (failed: $rulesFailed)
  Safe senders imported: $safeSendersImported (failed: $safeSendersFailed)
  Completed: $completedAt
  Success: $isSuccess
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

  /// Perform migration from YAML to database
  ///
  /// Returns MigrationResults with detailed statistics
  Future<MigrationResults> migrate() async {
    _logger.i('Starting YAML to SQLite migration');
    final results = MigrationResults();

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

      // Step 2: Create backup of YAML files
      await _createYamlBackups();

      // Step 3: Import rules if file exists
      if (rulesFileExists) {
        await _importRules(results);
      }

      // Step 4: Import safe senders if file exists
      if (safeSendersFileExists) {
        await _importSafeSenders(results);
      }

      // Step 5: Verify import completeness
      await _verifyImport(results);

      results.completedAt = DateTime.now();
      _logger.i('Migration completed: ${results.toString()}');

      return results;
    } catch (e) {
      _logger.e('Migration failed: $e');
      throw MigrationException('YAML to SQLite migration failed', e);
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

  /// Import rules from YAML file to database
  Future<void> _importRules(MigrationResults results) async {
    try {
      _logger.i('Importing rules from YAML');

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

          await databaseHelper.insertRule(dbRule);
          results.rulesImported++;
        } catch (e) {
          _logger.w('Failed to import rule "${rule.name}": $e');
          results.rulesFailed++;
          results.skippedRules.add('${rule.name}: ${e.toString()}');
        }
      }

      _logger.i('Imported ${results.rulesImported} rules, failed: ${results.rulesFailed}');
    } catch (e) {
      _logger.e('Failed to import rules: $e');
      results.errors.add('Rules import failed: ${e.toString()}');
    }
  }

  /// Import safe senders from YAML file to database
  Future<void> _importSafeSenders(MigrationResults results) async {
    try {
      _logger.i('Importing safe senders from YAML');

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

          await databaseHelper.insertSafeSender(dbSafeSender);
          results.safeSendersImported++;
        } catch (e) {
          _logger.w('Failed to import safe sender "$pattern": $e');
          results.safeSendersFailed++;
          results.skippedSafeSenders.add('$pattern: ${e.toString()}');
        }
      }

      _logger.i('Imported ${results.safeSendersImported} safe senders, failed: ${results.safeSendersFailed}');
    } catch (e) {
      _logger.e('Failed to import safe senders: $e');
      results.errors.add('Safe senders import failed: ${e.toString()}');
    }
  }

  /// Verify migration completeness
  Future<void> _verifyImport(MigrationResults results) async {
    try {
      _logger.i('Verifying import completeness');

      // Count rules in database
      final dbRules = await databaseHelper.queryRules();
      _logger.i('Database contains ${dbRules.length} rules');

      // Count safe senders in database
      final dbSafeSenders = await databaseHelper.querySafeSenders();
      _logger.i('Database contains ${dbSafeSenders.length} safe senders');

      // Get statistics
      final stats = await databaseHelper.getStatistics();
      _logger.i('Database statistics: $stats');
    } catch (e) {
      _logger.w('Failed to verify import: $e');
      // Verification failure is not critical
    }
  }

  /// Check if migration has been completed
  ///
  /// Returns true if database has rules (indicating migration already done)
  Future<bool> isMigrationComplete() async {
    try {
      final rules = await databaseHelper.queryRules();
      return rules.isNotEmpty;
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
