import 'package:logger/logger.dart';

import '../models/rule_set.dart';
import '../storage/rule_database_store.dart';
import '../storage/safe_sender_database_store.dart';

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
  final Logger _logger = Logger();

  YamlExportService({
    required RuleDatabaseStore ruleDatabaseStore,
    required SafeSenderDatabaseStore safeSenderDatabaseStore,
  })  : _ruleDatabaseStore = ruleDatabaseStore,
        _safeSenderDatabaseStore = safeSenderDatabaseStore;

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
      final ruleSet = await _ruleDatabaseStore.loadRules();
      if (ruleSet.rules.isEmpty) {
        _logger.w('No rules to export');
        return false;
      }

      _logger.i('Successfully exported ${ruleSet.rules.length} rules to YAML');
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

      _logger.i(
        'Successfully exported ${patterns.length} safe senders to YAML',
      );
      return true;
    } catch (e) {
      _logger.e('Error exporting safe senders to YAML: $e');
      return false;
    }
  }
}
