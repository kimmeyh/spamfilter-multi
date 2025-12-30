/// Local file-based rule storage for YAML persistence
/// 
/// Manages reading/writing rules.yaml and rules_safe_senders.yaml
/// with automatic backups and default file creation.
library;

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logger/logger.dart';

import '../../core/models/rule_set.dart';
import '../../core/models/safe_sender_list.dart';
import '../../core/services/yaml_service.dart';
import 'app_paths.dart';

/// Exception thrown when rule storage operations fail
class RuleStorageException implements Exception {
  final String message;
  final dynamic originalError;

  RuleStorageException(this.message, [this.originalError]);

  @override
  String toString() => 'RuleStorageException: $message${originalError != null ? '\nCause: $originalError' : ''}';
}

/// Local file-based storage for rules and safe senders
/// 
/// This storage implementation:
/// - Stores rules.yaml and rules_safe_senders.yaml in app support directory
/// - Automatically creates default files if they don't exist
/// - Creates timestamped backups before writing
/// - Normalizes and validates YAML on read
/// 
/// Example:
/// ```dart
/// final appPaths = AppPaths();
/// await appPaths.initialize();
/// 
/// final store = LocalRuleStore(appPaths);
/// 
/// // Load rules
/// final ruleSet = await store.loadRules();
/// 
/// // Load safe senders
/// final safeSenders = await store.loadSafeSenders();
/// 
/// // Save updated rules
/// await store.saveRules(ruleSet);
/// ```
class LocalRuleStore {
  final AppPaths appPaths;
  final YamlService yamlService = YamlService();
  final Logger _logger = Logger();

  LocalRuleStore(this.appPaths);

  /// Load rules from local storage (or create defaults if missing)
  Future<RuleSet> loadRules() async {
    try {
      final rulesFilePath = appPaths.rulesFilePath;
      final rulesFile = File(rulesFilePath);

      // If file doesn't exist, create default
      if (!await rulesFile.exists()) {
        _logger.i('Rules file not found, creating defaults');
        await _createDefaultRulesFile();
      }

      // Load using YamlService
      final ruleSet = await yamlService.loadRules(rulesFilePath);

      _logger.i('Loaded ${ruleSet.rules.length} rules from $rulesFilePath');
      return ruleSet;
    } catch (e) {
      throw RuleStorageException('Failed to load rules', e);
    }
  }

  /// Load safe senders from local storage (or create defaults if missing)
  Future<SafeSenderList> loadSafeSenders() async {
    try {
      final safeSendersFilePath = appPaths.safeSendersFilePath;
      final safeSendersFile = File(safeSendersFilePath);

      // If file doesn't exist, create default
      if (!await safeSendersFile.exists()) {
        _logger.i('Safe senders file not found, creating defaults');
        await _createDefaultSafeSendersFile();
      }

      // Load using YamlService
      final safeSenders = await yamlService.loadSafeSenders(safeSendersFilePath);

      _logger.i('Loaded ${safeSenders.safeSenders.length} safe sender patterns from $safeSendersFilePath');
      return safeSenders;
    } catch (e) {
      throw RuleStorageException('Failed to load safe senders', e);
    }
  }

  /// Save rules to local storage with automatic backup
  /// 
  /// Creates a timestamped backup of existing file before writing new content
  Future<void> saveRules(RuleSet ruleSet) async {
    try {
      // YamlService.exportRules already handles backup creation
      await yamlService.exportRules(ruleSet, appPaths.rulesFilePath);

      _logger.i('Saved ${ruleSet.rules.length} rules to ${appPaths.rulesFilePath}');
    } catch (e) {
      throw RuleStorageException('Failed to save rules', e);
    }
  }

  /// Save safe senders to local storage with automatic backup
  Future<void> saveSafeSenders(SafeSenderList safeSenders) async {
    try {
      // YamlService.exportSafeSenders already handles backup creation
      await yamlService.exportSafeSenders(safeSenders, appPaths.safeSendersFilePath);

      _logger.i('Saved ${safeSenders.safeSenders.length} safe sender patterns to ${appPaths.safeSendersFilePath}');
    } catch (e) {
      throw RuleStorageException('Failed to save safe senders', e);
    }
  }

  /// Create default rules.yaml file
  Future<void> _createDefaultRulesFile() async {
    try {
      final bundledCopied = await _copyBundledRules(
        assetPath: 'assets/rules/rules.yaml',
        targetPath: appPaths.rulesFilePath,
      );

      if (!bundledCopied) {
        final defaultRuleSet = RuleSet(
          version: '1.0',
          settings: {},
          rules: [],
        );

        await yamlService.exportRules(defaultRuleSet, appPaths.rulesFilePath);
        _logger.i('Created empty default rules file: ${appPaths.rulesFilePath}');
      }
    } catch (e) {
      throw RuleStorageException('Failed to create default rules file', e);
    }
  }

  /// Create default rules_safe_senders.yaml file
  Future<void> _createDefaultSafeSendersFile() async {
    try {
      final bundledCopied = await _copyBundledRules(
        assetPath: 'assets/rules/rules_safe_senders.yaml',
        targetPath: appPaths.safeSendersFilePath,
      );

      if (!bundledCopied) {
        final defaultSafeSenders = SafeSenderList(
          safeSenders: [],
        );

        await yamlService.exportSafeSenders(defaultSafeSenders, appPaths.safeSendersFilePath);
        _logger.i('Created empty default safe senders file: ${appPaths.safeSendersFilePath}');
      }
    } catch (e) {
      throw RuleStorageException('Failed to create default safe senders file', e);
    }
  }

  /// Copy bundled YAML from assets into app storage.
  /// Returns true if the bundled asset was written successfully.
  Future<bool> _copyBundledRules({required String assetPath, required String targetPath}) async {
    try {
      final contents = await rootBundle.loadString(assetPath);
      final targetFile = File(targetPath);
      await targetFile.writeAsString(contents);
      _logger.i('Copied bundled asset $assetPath to $targetPath');
      return true;
    } catch (e) {
      _logger.w('Failed to copy bundled asset $assetPath, falling back to empty defaults', error: e);
      return false;
    }
  }

  /// List available backup files
  Future<List<FileSystemEntity>> listBackups() async {
    try {
      final backupDir = appPaths.backupDirectory;
      final entities = await backupDir.list().toList();
      return entities.where((e) => e is File).toList();
    } catch (e) {
      throw RuleStorageException('Failed to list backups', e);
    }
  }

  /// Delete old backup files (keep last N backups)
  /// 
  /// Useful for cleaning up after many edits
  Future<void> pruneOldBackups({int keepCount = 5}) async {
    try {
      final backups = (await listBackups()).cast<File>().toList();
      if (backups.length <= keepCount) return;

      // Sort by modification time, keep newest
      backups.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      for (int i = keepCount; i < backups.length; i++) {
        await backups[i].delete();
        _logger.d('Deleted old backup: ${backups[i].path}');
      }
    } catch (e) {
      _logger.w('Failed to prune old backups', error: e);
      // Don't throw - cleanup failure shouldn't break the app
    }
  }
}

