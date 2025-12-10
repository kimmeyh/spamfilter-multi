import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/models/rule_set.dart';
import 'package:spam_filter_mobile/core/models/safe_sender_list.dart';
import 'package:spam_filter_mobile/core/services/yaml_service.dart';
import 'package:spam_filter_mobile/core/services/pattern_compiler.dart';

void main() {
  group('YAML Loading Integration Tests', () {
    late YamlService yamlService;
    late PatternCompiler compiler;

    setUp(() {
      yamlService = YamlService();
      compiler = PatternCompiler();
    });

    test('load production rules.yaml from repository root', () async {
      // Path relative to mobile-app directory
      final rulesPath = '../rules.yaml';
      final file = File(rulesPath);
      
      if (!await file.exists()) {
        print('Skipping test - rules.yaml not found at: ${file.absolute.path}');
        return;
      }

      final ruleSet = await yamlService.loadRules(rulesPath);
      
      expect(ruleSet, isNotNull);
      expect(ruleSet.rules, isNotEmpty);
      
      print('Loaded ${ruleSet.rules.length} rules');
      
      // Verify rule structure
      for (final rule in ruleSet.rules.take(5)) {
        expect(rule.name, isNotEmpty);
        expect(rule.enabled, isNotNull);
        expect(rule.executionOrder, greaterThan(0));
        
        // At least one condition should exist
        final hasConditions = 
          (rule.conditions.header?.isNotEmpty ?? false) ||
          (rule.conditions.body?.isNotEmpty ?? false) ||
          (rule.conditions.subject?.isNotEmpty ?? false) ||
          (rule.conditions.from?.isNotEmpty ?? false);
        expect(hasConditions, isTrue, reason: 'Rule ${rule.name} has no conditions');
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('load production rules_safe_senders.yaml from repository root', () async {
      final safeSendersPath = '../rules_safe_senders.yaml';
      final file = File(safeSendersPath);
      
      if (!await file.exists()) {
        print('Skipping test - rules_safe_senders.yaml not found at: ${file.absolute.path}');
        return;
      }

      final safeSenderList = await yamlService.loadSafeSenders(safeSendersPath);
      
      expect(safeSenderList, isNotNull);
      expect(safeSenderList.safeSenders, isNotEmpty);
      
      print('Loaded ${safeSenderList.safeSenders.length} safe sender patterns');
      
      // Verify patterns are valid
      int validPatterns = 0;
      for (final pattern in safeSenderList.safeSenders.take(10)) {
        expect(pattern, isNotEmpty);
        
        // Try to compile as regex
        final compiled = compiler.compile(pattern);
        if (compiled != null) {
          validPatterns++;
        }
      }
      
      expect(validPatterns, greaterThan(0), 
        reason: 'At least some patterns should be valid regex');
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('compile all rules regex patterns', () async {
      final rulesPath = '../rules.yaml';
      final file = File(rulesPath);
      
      if (!await file.exists()) {
        print('Skipping test - rules.yaml not found');
        return;
      }

      final ruleSet = await yamlService.loadRules(rulesPath);
      final stopwatch = Stopwatch()..start();
      
      // Collect all patterns
      final allPatterns = <String>[];
      for (final rule in ruleSet.rules) {
        if (rule.conditions.header != null) {
          allPatterns.addAll(rule.conditions.header!);
        }
        if (rule.conditions.body != null) {
          allPatterns.addAll(rule.conditions.body!);
        }
        if (rule.conditions.subject != null) {
          allPatterns.addAll(rule.conditions.subject!);
        }
        if (rule.conditions.from != null) {
          allPatterns.addAll(rule.conditions.from!);
        }
      }
      
      print('Total patterns to compile: ${allPatterns.length}');
      
      // Precompile all patterns
      compiler.precompile(allPatterns);
      
      stopwatch.stop();
      final compileTime = stopwatch.elapsedMilliseconds;
      
      print('Compiled ${allPatterns.length} patterns in ${compileTime}ms');
      print('Average: ${(compileTime / allPatterns.length).toStringAsFixed(2)}ms per pattern');
      
      final stats = compiler.getStats();
      print('Cache stats: ${stats['cached_patterns']} cached, '
            '${stats['cache_hits']} hits, ${stats['cache_misses']} misses');
      
      // Performance target: should compile all patterns in under 5 seconds
      expect(compileTime, lessThan(5000), 
        reason: 'Pattern compilation took ${compileTime}ms, target is <5000ms');
      
      expect(stats['cached_patterns'], equals(allPatterns.length));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('YAML round-trip (load and export)', () async {
      final rulesPath = '../rules.yaml';
      final file = File(rulesPath);
      
      if (!await file.exists()) {
        print('Skipping test - rules.yaml not found');
        return;
      }

      // Load original
      final original = await yamlService.loadRules(rulesPath);
      
      // Export to temp file
      final tempPath = 'test_output_rules.yaml';
      await yamlService.exportRules(original, tempPath);
      
      // Load exported
      final reloaded = await yamlService.loadRules(tempPath);
      
      // Compare
      expect(reloaded.rules.length, equals(original.rules.length));
      
      // Check first few rules match
      for (int i = 0; i < 3 && i < original.rules.length; i++) {
        expect(reloaded.rules[i].name, equals(original.rules[i].name));
        expect(reloaded.rules[i].enabled, equals(original.rules[i].enabled));
      }
      
      // Cleanup
      await File(tempPath).delete();
      
      print('Round-trip successful: ${original.rules.length} rules preserved');
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
