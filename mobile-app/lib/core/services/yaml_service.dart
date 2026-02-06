import 'dart:io';
import 'package:yaml/yaml.dart';
import '../models/rule_set.dart';
import '../models/safe_sender_list.dart';

/// Handles YAML import/export for rules and safe senders
class YamlService {
  /// Load rules from YAML file
  Future<RuleSet> loadRules(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Rules file not found', filePath);
    }
    final content = await file.readAsString();
    final yaml = loadYaml(content);
    final converted = _convertYamlToMap(yaml);
    return RuleSet.fromMap(converted as Map<String, dynamic>);
  }
  
  /// Recursively convert YamlMap/YamlList to regular Map/List
  dynamic _convertYamlToMap(dynamic yaml) {
    if (yaml is YamlMap) {
      final map = <String, dynamic>{};
      yaml.forEach((key, value) {
        map[key.toString()] = _convertYamlToMap(value);
      });
      return map;
    } else if (yaml is YamlList) {
      return yaml.map((item) => _convertYamlToMap(item)).toList();
    } else {
      return yaml;
    }
  }

  /// Load safe senders from YAML file
  Future<SafeSenderList> loadSafeSenders(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Safe senders file not found', filePath);
    }
    final content = await file.readAsString();
    final yaml = loadYaml(content) as Map;
    return SafeSenderList.fromMap(Map<String, dynamic>.from(yaml));
  }

  /// Export rules to YAML file with backup
  Future<void> exportRules(RuleSet ruleSet, String filePath) async {
    // Create backup if file exists
    final file = File(filePath);
    if (await file.exists()) {
      await _createBackup(filePath);
    }

    // Normalize and sort
    final normalized = _normalizeRuleSet(ruleSet);
    
    // Write YAML with single quotes for patterns
    final yaml = _convertToYaml(normalized.toMap());
    await file.writeAsString(yaml);
  }

  /// Export safe senders to YAML file with backup
  Future<void> exportSafeSenders(SafeSenderList safeSenders, String filePath) async {
    // Create backup if file exists
    final file = File(filePath);
    if (await file.exists()) {
      await _createBackup(filePath);
    }

    // Normalize and sort
    final normalized = _normalizeSafeSenders(safeSenders);
    
    // Write YAML
    final yaml = _convertToYaml(normalized.toMap());
    await file.writeAsString(yaml);
  }

  Future<void> _createBackup(String filePath) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final backupDir = '${_getDirectory(filePath)}/Archive';
    await Directory(backupDir).create(recursive: true);
    
    final fileName = _getFileName(filePath);
    final backupPath = '$backupDir/${fileName}_backup_$timestamp';
    await File(filePath).copy(backupPath);
  }

  RuleSet _normalizeRuleSet(RuleSet ruleSet) {
    final normalizedRules = ruleSet.rules.map((rule) {
      return Rule(
        name: rule.name,
        enabled: rule.enabled,
        isLocal: rule.isLocal,
        executionOrder: rule.executionOrder,
        conditions: RuleConditions(
          type: rule.conditions.type,
          from: _normalizeList(rule.conditions.from),
          header: _normalizeList(rule.conditions.header),
          subject: _normalizeList(rule.conditions.subject),
          body: _normalizeList(rule.conditions.body),
        ),
        actions: rule.actions,
        exceptions: rule.exceptions != null
            ? RuleExceptions(
                from: _normalizeList(rule.exceptions!.from),
                header: _normalizeList(rule.exceptions!.header),
                subject: _normalizeList(rule.exceptions!.subject),
                body: _normalizeList(rule.exceptions!.body),
              )
            : null,
        metadata: rule.metadata,
      );
    }).toList();

    return RuleSet(
      version: ruleSet.version,
      settings: ruleSet.settings,
      rules: normalizedRules,
    );
  }

  SafeSenderList _normalizeSafeSenders(SafeSenderList safeSenders) {
    return SafeSenderList(
      safeSenders: _normalizeList(safeSenders.safeSenders),
    );
  }

  List<String> _normalizeList(List<String> items) {
    return items
        .map((s) => s.toLowerCase().trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  String _convertToYaml(Map<String, dynamic> data) {
    // Simple YAML conversion - for production use a proper YAML encoder
    final buffer = StringBuffer();
    _writeYaml(buffer, data, 0);
    return buffer.toString();
  }

  void _writeYaml(StringBuffer buffer, dynamic value, int indent) {
    final spaces = '  ' * indent;
    
    if (value is Map) {
      value.forEach((key, val) {
        if (val is Map || val is List) {
          buffer.writeln('$spaces$key:');
          _writeYaml(buffer, val, indent + 1);
        } else {
          buffer.writeln('$spaces$key: ${_formatValue(val)}');
        }
      });
    } else if (value is List) {
      for (final item in value) {
        if (item is Map) {
          buffer.writeln('$spaces-');
          _writeYaml(buffer, item, indent + 1);
        } else {
          buffer.writeln('$spaces- ${_formatValue(item)}');
        }
      }
    }
  }

  String _formatValue(dynamic value) {
    if (value is String) {
      final escaped = value.replaceAll("'", "''");
      return "'$escaped'";
    }
    return value.toString();
  }

  String _getDirectory(String path) {
    final lastSeparator = path.lastIndexOf(Platform.pathSeparator);
    return lastSeparator >= 0 ? path.substring(0, lastSeparator) : '.';
  }

  String _getFileName(String path) {
    final lastSeparator = path.lastIndexOf(Platform.pathSeparator);
    final nameWithExtension = lastSeparator >= 0 ? path.substring(lastSeparator + 1) : path;
    return nameWithExtension;
  }
}
