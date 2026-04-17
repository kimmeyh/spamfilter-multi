/// Script to rebuild bundled rules.yaml from existing monolithic rules
///
/// Usage: dart rebuild_rules_yaml.dart
///
/// This script:
/// 1. Reads the current monolithic rules.yaml
/// 2. Extracts patterns from the header rule (SpamAutoDeleteHeader)
/// 3. Classifies each pattern as TLD, entire_domain, or exact_domain
/// 4. Generates individual YAML entries for each pattern
/// 5. Filters to include only header_from rules (excludes exact_email, subject, body)
/// 6. Writes the new YAML to assets/rules/rules.yaml
///
/// The new format has individual rules for each pattern with classification fields.

import 'dart:io';
import 'package:yaml/yaml.dart';

void main() async {
  print('[INFO] Rebuilding bundled rules.yaml from monolithic format...\n');

  final currentDir = Directory.current;
  final rulesYamlPath = File('${currentDir.path}/assets/rules/rules.yaml');

  if (!rulesYamlPath.existsSync()) {
    print('[ERROR] rules.yaml not found at: ${rulesYamlPath.path}');
    exit(1);
  }

  try {
    // Load current YAML
    final yamlContent = rulesYamlPath.readAsStringSync();
    final yaml = loadYaml(yamlContent) as Map;

    // Extract header patterns from SpamAutoDeleteHeader
    final rules = yaml['rules'] as List;
    final headerRule = rules.firstWhere(
      (r) => (r as Map)['name'] == 'SpamAutoDeleteHeader',
      orElse: () => null,
    );

    if (headerRule == null) {
      print('[ERROR] SpamAutoDeleteHeader rule not found');
      exit(1);
    }

    final headerPatterns = (headerRule['conditions']['header'] as List?)?.cast<String>() ?? [];
    print('[INFO] Found ${headerPatterns.length} header patterns to classify');

    // Classify patterns
    final classifiedPatterns = <Map<String, dynamic>>[];
    int tldCount = 0;
    int entireDomainCount = 0;
    int exactDomainCount = 0;
    int skippedCount = 0;

    for (final pattern in headerPatterns) {
      final (classification, sourceDomain) = _classifyPattern(pattern);

      if (classification == null) {
        skippedCount++;
        continue;
      }

      // Count by type
      if (classification == 'top_level_domain') {
        tldCount++;
      } else if (classification == 'entire_domain') {
        entireDomainCount++;
      } else if (classification == 'exact_domain') {
        exactDomainCount++;
      }

      classifiedPatterns.add({
        'pattern': pattern,
        'type': classification,
        'sourceDomain': sourceDomain,
      });
    }

    print('\n[INFO] Classification summary:');
    print('  - TLD: $tldCount');
    print('  - Entire Domain: $entireDomainCount');
    print('  - Exact Domain: $exactDomainCount');
    print('  - Skipped: $skippedCount');
    print('  - Total to include: ${classifiedPatterns.length}');

    // Generate individual YAML rules
    final newRules = <Map<String, dynamic>>[];
    int executionOrder = 10; // TLD patterns at order 10

    // Sort patterns by type to group them
    final sortedPatterns = classifiedPatterns..sort((a, b) {
      final typeOrder = {'top_level_domain': 0, 'entire_domain': 1, 'exact_domain': 2};
      return (typeOrder[a['type']] ?? 99).compareTo(typeOrder[b['type']] ?? 99);
    });

    for (final pat in sortedPatterns) {
      final patternType = pat['type'] as String;
      final sourceDomain = pat['sourceDomain'] as String;

      // Determine execution order based on type
      int order = 10; // TLD
      if (patternType == 'entire_domain') order = 20;
      if (patternType == 'exact_domain') order = 30;

      // Generate rule name from source domain
      final ruleName = sourceDomain.replaceAll(RegExp(r'[^\w.-]'), '');

      newRules.add({
        'name': ruleName,
        'enabled': 'True',
        'isLocal': 'True',
        'executionOrder': order,
        'conditions': {
          'type': 'OR',
          'header': [pat['pattern'] as String],
        },
        'actions': {
          'delete': 'True',
        },
        'patternCategory': 'header_from',
        'patternSubType': patternType,
        'sourceDomain': sourceDomain,
      });
    }

    // Build new RuleSet
    final newRuleSet = {
      'version': '1.0',
      'settings': {
        'default_execution_order_increment': 10,
      },
      'rules': newRules,
    };

    // Write new YAML
    final newYamlContent = _generateYaml(newRuleSet);
    rulesYamlPath.writeAsStringSync(newYamlContent);

    print('\n[OK] Rebuilt rules.yaml with ${newRules.length} individual rules');
    print('[OK] Written to: ${rulesYamlPath.path}');
  } catch (e) {
    print('[ERROR] Failed to rebuild YAML: $e');
    exit(1);
  }
}

/// Classify a pattern as TLD, entire_domain, or exact_domain
/// Returns tuple of (classification, sourceDomain)
(String?, String) _classifyPattern(String pattern) {
  // TLD pattern: @.*\.cc$ or @.*\.ne$
  if (RegExp(r'@\.\*\\\\\.[a-z]+\$').hasMatch(pattern)) {
    final tld = pattern.replaceFirst('@.*\\\\.', '').replaceFirst('\$', '');
    return ('top_level_domain', '.*.$tld');
  }

  // Entire domain: @(?:[a-z0-9-]+\.)*domain\.com$
  if (pattern.contains('(?:[a-z0-9-]+\\\\.)*')) {
    final domainMatch = RegExp(r'\(\?:\[a-z0-9-\]\+\\\\\.\)\*([a-z0-9.-]+)\\\\\.\[a-z0-9.-\]\+\$').firstMatch(pattern);
    if (domainMatch != null) {
      final domain = domainMatch.group(1) ?? '';
      return ('entire_domain', domain);
    }

    // Alternative format without the complex regex
    final simpleMatch = RegExp(r'@[^@]+\.([a-z0-9.-]+)\$').firstMatch(pattern);
    if (simpleMatch != null) {
      final domain = simpleMatch.group(1) ?? '';
      return ('entire_domain', domain);
    }
  }

  // Exact domain: @domain\.com$
  if (pattern.startsWith('@') && pattern.endsWith('\$')) {
    final domain = pattern.replaceFirst('@', '').replaceFirst('\$', '').replaceAll('\\\\', '');
    if (domain.isNotEmpty && !domain.contains('(') && !domain.contains('?')) {
      return ('exact_domain', domain);
    }
  }

  return (null, '');
}

/// Generate YAML content with proper formatting
String _generateYaml(Map<String, dynamic> data) {
  final buffer = StringBuffer();

  // Header
  buffer.writeln("'version': '${data['version']}'");
  buffer.writeln("'settings':");
  final settings = data['settings'] as Map;
  for (final entry in settings.entries) {
    buffer.writeln("  '${entry.key}': !!int '${entry.value}'");
  }

  buffer.writeln("'rules':");
  final rules = data['rules'] as List;

  for (final rule in rules) {
    buffer.writeln("- 'name': '${rule['name']}'");
    buffer.writeln("  'enabled': '${rule['enabled']}'");
    buffer.writeln("  'isLocal': '${rule['isLocal']}'");
    buffer.writeln("  'executionOrder': '${rule['executionOrder']}'");

    // Conditions
    buffer.writeln("  'conditions':");
    final conditions = rule['conditions'] as Map;
    buffer.writeln("    'type': '${conditions['type']}'");
    buffer.writeln("    'from': []");

    if (conditions['header'] != null) {
      buffer.writeln("    'header':");
      final headers = conditions['header'] as List;
      for (final h in headers) {
        buffer.writeln("    - '$h'");
      }
    } else {
      buffer.writeln("    'header': []");
    }

    buffer.writeln("    'subject': []");
    buffer.writeln("    'body': []");

    // Actions
    buffer.writeln("  'actions':");
    final actions = rule['actions'] as Map;
    buffer.writeln("    'delete': '${actions['delete']}'");

    // Classification fields
    if (rule['patternCategory'] != null) {
      buffer.writeln("  'patternCategory': '${rule['patternCategory']}'");
    }
    if (rule['patternSubType'] != null) {
      buffer.writeln("  'patternSubType': '${rule['patternSubType']}'");
    }
    if (rule['sourceDomain'] != null) {
      buffer.writeln("  'sourceDomain': '${rule['sourceDomain']}'");
    }
  }

  return buffer.toString();
}
