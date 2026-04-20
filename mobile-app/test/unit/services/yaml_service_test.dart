import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/services/yaml_service.dart';

void main() {
  late YamlService yamlService;

  setUp(() {
    yamlService = YamlService();
  });

  group('parseRulesFromString', () {
    test('parses valid YAML with a single rule', () {
      const yaml = '''
version: '2.0'
settings:
  mode: regex
rules:
  - name: Block spam domain
    enabled: 'true'
    isLocal: 'false'
    executionOrder: 1
    conditions:
      type: OR
      header:
        - '@spam\\.com\$'
    actions:
      delete: true
''';

      final ruleSet = yamlService.parseRulesFromString(yaml);

      expect(ruleSet.version, '2.0');
      expect(ruleSet.settings['mode'], 'regex');
      expect(ruleSet.rules, hasLength(1));

      final rule = ruleSet.rules.first;
      expect(rule.name, 'Block spam domain');
      expect(rule.enabled, isTrue);
      expect(rule.isLocal, isFalse);
      expect(rule.executionOrder, 1);
      expect(rule.conditions.type, 'OR');
      expect(rule.conditions.header, [r'@spam\.com$']);
      expect(rule.actions.delete, isTrue);
      expect(rule.exceptions, isNull);
    });

    test('parses multiple rules with different condition types', () {
      const yaml = '''
version: '1.0'
settings: {}
rules:
  - name: Header rule
    enabled: 'true'
    isLocal: 'false'
    executionOrder: 1
    conditions:
      type: OR
      header:
        - '@example\\.com\$'
    actions:
      delete: false
      move_to_folder: Junk
  - name: Subject rule
    enabled: 'true'
    isLocal: 'true'
    executionOrder: 2
    conditions:
      type: AND
      subject:
        - 'free money'
        - 'act now'
    actions:
      delete: true
''';

      final ruleSet = yamlService.parseRulesFromString(yaml);

      expect(ruleSet.rules, hasLength(2));

      final headerRule = ruleSet.rules[0];
      expect(headerRule.name, 'Header rule');
      expect(headerRule.conditions.header, hasLength(1));
      expect(headerRule.actions.delete, isFalse);
      expect(headerRule.actions.moveToFolder, 'Junk');

      final subjectRule = ruleSet.rules[1];
      expect(subjectRule.name, 'Subject rule');
      expect(subjectRule.isLocal, isTrue);
      expect(subjectRule.executionOrder, 2);
      expect(subjectRule.conditions.type, 'AND');
      expect(subjectRule.conditions.subject, hasLength(2));
      expect(subjectRule.actions.delete, isTrue);
    });

    test('parses rule with exceptions', () {
      const yaml = '''
version: '1.0'
settings: {}
rules:
  - name: Rule with exceptions
    enabled: 'true'
    isLocal: 'false'
    executionOrder: 1
    conditions:
      type: OR
      from:
        - '@marketing\\.com\$'
    actions:
      delete: true
    exceptions:
      from:
        - '^support@marketing\\.com\$'
''';

      final ruleSet = yamlService.parseRulesFromString(yaml);
      final rule = ruleSet.rules.first;

      expect(rule.exceptions, isNotNull);
      expect(rule.exceptions!.from, hasLength(1));
      expect(rule.exceptions!.from.first, r'^support@marketing\.com$');
    });

    test('parses rule with classification fields', () {
      const yaml = '''
version: '1.0'
settings: {}
rules:
  - name: Classified rule
    enabled: 'true'
    isLocal: 'false'
    executionOrder: 1
    patternCategory: header_from
    patternSubType: entire_domain
    sourceDomain: spammer.com
    conditions:
      type: OR
      header:
        - '@(?:[a-z0-9-]+\\.)*spammer\\.com\$'
    actions:
      delete: true
''';

      final ruleSet = yamlService.parseRulesFromString(yaml);
      final rule = ruleSet.rules.first;

      expect(rule.patternCategory, 'header_from');
      expect(rule.patternSubType, 'entire_domain');
      expect(rule.sourceDomain, 'spammer.com');
    });

    test('handles empty rules list', () {
      const yaml = '''
version: '1.0'
settings: {}
rules: []
''';

      final ruleSet = yamlService.parseRulesFromString(yaml);

      expect(ruleSet.version, '1.0');
      expect(ruleSet.rules, isEmpty);
    });

    test('handles missing optional fields with defaults', () {
      const yaml = '''
rules:
  - name: Minimal rule
    enabled: 'true'
    isLocal: 'false'
    executionOrder: 0
    conditions:
      type: OR
    actions:
      delete: false
''';

      final ruleSet = yamlService.parseRulesFromString(yaml);

      // Version defaults to '1.0' when missing
      expect(ruleSet.version, '1.0');
      // Settings defaults to empty map when missing
      expect(ruleSet.settings, isEmpty);

      final rule = ruleSet.rules.first;
      expect(rule.conditions.from, isEmpty);
      expect(rule.conditions.header, isEmpty);
      expect(rule.conditions.subject, isEmpty);
      expect(rule.conditions.body, isEmpty);
      expect(rule.exceptions, isNull);
      expect(rule.patternCategory, isNull);
    });

    test('parses rule with body conditions', () {
      const yaml = '''
version: '1.0'
settings: {}
rules:
  - name: Body pattern rule
    enabled: 'true'
    isLocal: 'false'
    executionOrder: 5
    conditions:
      type: OR
      body:
        - 'click here to unsubscribe'
        - 'you have been selected'
    actions:
      delete: true
''';

      final ruleSet = yamlService.parseRulesFromString(yaml);
      final rule = ruleSet.rules.first;

      expect(rule.conditions.body, hasLength(2));
      expect(rule.conditions.body[0], 'click here to unsubscribe');
      expect(rule.conditions.body[1], 'you have been selected');
    });

    test('parses rule with assign_to_category action', () {
      const yaml = '''
version: '1.0'
settings: {}
rules:
  - name: Categorize rule
    enabled: 'true'
    isLocal: 'false'
    executionOrder: 1
    conditions:
      type: OR
      from:
        - '@newsletter\\.com\$'
    actions:
      delete: false
      assign_to_category: Promotions
''';

      final ruleSet = yamlService.parseRulesFromString(yaml);
      final rule = ruleSet.rules.first;

      expect(rule.actions.assignToCategory, 'Promotions');
      expect(rule.actions.delete, isFalse);
    });
  });

  group('parseSafeSendersFromString', () {
    test('parses valid safe senders YAML', () {
      const yaml = '''
safe_senders:
  - '^[^@\\s]+@(?:[a-z0-9-]+\\.)*trusted\\.com\$'
  - '^support@example\\.com\$'
  - '^[^@\\s]+@safe\\.org\$'
''';

      final safeSenders = yamlService.parseSafeSendersFromString(yaml);

      expect(safeSenders.safeSenders, hasLength(3));
      expect(
        safeSenders.safeSenders[0],
        r'^[^@\s]+@(?:[a-z0-9-]+\.)*trusted\.com$',
      );
      expect(safeSenders.safeSenders[1], r'^support@example\.com$');
      expect(safeSenders.safeSenders[2], r'^[^@\s]+@safe\.org$');
    });

    test('handles empty safe senders list', () {
      const yaml = '''
safe_senders: []
''';

      final safeSenders = yamlService.parseSafeSendersFromString(yaml);

      expect(safeSenders.safeSenders, isEmpty);
    });

    test('normalizes entries to lowercase', () {
      const yaml = '''
safe_senders:
  - 'Admin@Example.COM'
  - 'USER@DOMAIN.ORG'
''';

      final safeSenders = yamlService.parseSafeSendersFromString(yaml);

      expect(safeSenders.safeSenders[0], 'admin@example.com');
      expect(safeSenders.safeSenders[1], 'user@domain.org');
    });

    test('handles missing safe_senders key gracefully', () {
      const yaml = '''
other_key: value
''';

      final safeSenders = yamlService.parseSafeSendersFromString(yaml);

      expect(safeSenders.safeSenders, isEmpty);
    });

    test('trims whitespace from entries', () {
      const yaml = '''
safe_senders:
  - '  spaced@example.com  '
  - 'normal@example.com'
''';

      final safeSenders = yamlService.parseSafeSendersFromString(yaml);

      expect(safeSenders.safeSenders[0], 'spaced@example.com');
      expect(safeSenders.safeSenders[1], 'normal@example.com');
    });

    test('parses single safe sender entry', () {
      const yaml = '''
safe_senders:
  - '^only@one\\.com\$'
''';

      final safeSenders = yamlService.parseSafeSendersFromString(yaml);

      expect(safeSenders.safeSenders, hasLength(1));
      expect(safeSenders.safeSenders.first, r'^only@one\.com$');
    });
  });
}
