import 'dart:io';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../models/rule.dart';
import '../models/safe_sender_pattern.dart';
import '../storage/rule_database_store.dart';
import '../storage/safe_sender_database_store.dart';
import '../storage/local_rule_store.dart';

/// Service for exporting rules and safe senders from database to YAML files.
///
/// This implements the "dual-write pattern" where:
/// - Primary storage: SQLite database (RuleDatabaseStore, SafeSenderDatabaseStore)
/// - Secondary storage: YAML files (for version control and portability)
///
/// YAML exports are non-blocking - failures are logged but do not propagate to caller.
class YamlExportService {
  final RuleDatabaseStore _ruleDatabaseStore;
  final SafeSenderDatabaseStore _safeSenderDatabaseStore;
  final LocalRuleStore _localRuleStore;
  final Logger _logger = Logger();

  YamlExportService({
    required RuleDatabaseStore ruleDatabaseStore,
    required SafeSenderDatabaseStore safeSenderDatabaseStore,
    required LocalRuleStore localRuleStore,
  })  : _ruleDatabaseStore = ruleDatabaseStore,
        _safeSenderDatabaseStore = safeSenderDatabaseStore,
        _localRuleStore = localRuleStore;

  /// Exports all rules from database to rules.yaml.
  ///
  /// Process:
  /// 1. Load all rules from database
  /// 2. Create timestamped backup of existing rules.yaml
  /// 3. Write rules to rules.yaml with proper formatting
  /// 4. Log result
  ///
  /// Returns true if export succeeded, false otherwise.
  /// Never throws - all exceptions are caught and logged.
  Future<bool> exportRulesToYaml() async {
    try {
      _logger.i('Exporting rules to YAML...');

      // Load rules from database
      final rules = await _ruleDatabaseStore.loadRules();
      if (rules.isEmpty) {
        _logger.w('No rules to export');
        return false;
      }

      // Convert rules to YAML format
      final yamlContent = _rulesToYaml(rules);

      // Create backup before overwrite
      await _createBackup(_localRuleStore.rulesFilePath);

      // Write to file
      final file = File(_localRuleStore.rulesFilePath);
      await file.writeAsString(yamlContent);

      _logger.i('Successfully exported ${rules.length} rules to YAML');
      return true;
    } catch (e) {
      _logger.e('Error exporting rules to YAML: $e');
      return false;
    }
  }

  /// Exports all safe senders from database to rules_safe_senders.yaml.
  ///
  /// Process:
  /// 1. Load all safe sender patterns from database
  /// 2. Extract pattern strings
  /// 3. Sort alphabetically
  /// 4. Create timestamped backup of existing rules_safe_senders.yaml
  /// 5. Write patterns to rules_safe_senders.yaml
  /// 6. Log result
  ///
  /// Returns true if export succeeded, false otherwise.
  /// Never throws - all exceptions are caught and logged.
  Future<bool> exportSafeSendersToYaml() async {
    try {
      _logger.i('Exporting safe senders to YAML...');

      // Load safe sender patterns from database
      final safeSenders =
          await _safeSenderDatabaseStore.loadSafeSenders();
      if (safeSenders.isEmpty) {
        _logger.w('No safe senders to export');
        return false;
      }

      // Extract pattern strings and sort
      final patterns = safeSenders.map((s) => s.pattern).toList();
      patterns.sort();

      // Convert to YAML format
      final yamlContent = _safeSendersToYaml(patterns);

      // Create backup before overwrite
      await _createBackup(_localRuleStore.safeSendersFilePath);

      // Write to file
      final file = File(_localRuleStore.safeSendersFilePath);
      await file.writeAsString(yamlContent);

      _logger.i(
        'Successfully exported ${patterns.length} safe senders to YAML',
      );
      return true;
    } catch (e) {
      _logger.e('Error exporting safe senders to YAML: $e');
      return false;
    }
  }

  /// Converts rules list to YAML format.
  ///
  /// Format:
  /// ```yaml
  /// version: "1.0"
  /// settings:
  ///   default_execution_order_increment: 10
  /// rules:
  ///   - name: "RuleName"
  ///     enabled: "True"
  ///     ...
  /// ```
  String _rulesToYaml(List<Rule> rules) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('version: "1.0"');
    buffer.writeln('settings:');
    buffer.writeln('  default_execution_order_increment: 10');
    buffer.writeln('rules:');

    // Rules
    for (final rule in rules) {
      buffer.writeln('  - name: "${rule.name}"');
      buffer.writeln('    enabled: "${rule.enabled ? 'True' : 'False'}"');
      buffer.writeln('    conditions:');
      buffer.writeln('      type: "${rule.conditions.type}"');

      // Conditions
      if (rule.conditions.header.isNotEmpty) {
        buffer.writeln('      header:');
        for (final pattern in rule.conditions.header) {
          buffer.writeln("        - '$pattern'");
        }
      }

      if (rule.conditions.subject.isNotEmpty) {
        buffer.writeln('      subject:');
        for (final pattern in rule.conditions.subject) {
          buffer.writeln("        - '$pattern'");
        }
      }

      if (rule.conditions.body.isNotEmpty) {
        buffer.writeln('      body:');
        for (final pattern in rule.conditions.body) {
          buffer.writeln("        - '$pattern'");
        }
      }

      // Actions
      buffer.writeln('    actions:');
      if (rule.actions.delete) {
        buffer.writeln('      delete: true');
      } else if (rule.actions.moveToFolder.isNotEmpty) {
        buffer.writeln('      move_to_folder: "${rule.actions.moveToFolder}"');
      }

      // Exceptions (if any)
      if (rule.exceptions.from.isNotEmpty ||
          rule.exceptions.subject.isNotEmpty ||
          rule.exceptions.body.isNotEmpty) {
        buffer.writeln('    exceptions:');

        if (rule.exceptions.from.isNotEmpty) {
          buffer.writeln('      from:');
          for (final pattern in rule.exceptions.from) {
            buffer.writeln("        - '$pattern'");
          }
        }

        if (rule.exceptions.subject.isNotEmpty) {
          buffer.writeln('      subject:');
          for (final pattern in rule.exceptions.subject) {
            buffer.writeln("        - '$pattern'");
          }
        }

        if (rule.exceptions.body.isNotEmpty) {
          buffer.writeln('      body:');
          for (final pattern in rule.exceptions.body) {
            buffer.writeln("        - '$pattern'");
          }
        }
      }
    }

    return buffer.toString();
  }

  /// Converts safe senders list to YAML format.
  ///
  /// Format:
  /// ```yaml
  /// safe_senders:
  ///   - '^user@example\.com$'
  ///   - '@example\.com$'
  /// ```
  String _safeSendersToYaml(List<String> patterns) {
    final buffer = StringBuffer();

    buffer.writeln('safe_senders:');
    for (final pattern in patterns) {
      buffer.writeln("  - '$pattern'");
    }

    return buffer.toString();
  }

  /// Creates a timestamped backup of the specified file.
  ///
  /// Backup filename format: `original_filename.$timestamp.bak`
  /// Example: `rules.yaml.20260126_143022.bak`
  ///
  /// Returns true if backup created successfully, false otherwise.
  /// Never throws - exceptions are logged and function returns false.
  Future<bool> _createBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _logger.d('File does not exist, skipping backup: $filePath');
        return true; // Not an error if file does not exist yet
      }

      // Generate backup filename with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupPath = '$filePath.$timestamp.bak';

      // Copy file to backup
      await file.copy(backupPath);
      _logger.d('Created backup: $backupPath');
      return true;
    } catch (e) {
      _logger.w('Error creating backup of $filePath: $e');
      return false; // Non-blocking failure
    }
  }
}
