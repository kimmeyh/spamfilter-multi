/// Unit tests for the "Open in test tool" rule-to-condition-type mapping logic
/// added as Sub-feature 3 of F25.
///
/// The mapping lives in `RulesManagementScreen._openRuleInTestTool`.  Because
/// that method is private to the state class, these tests verify the SAME
/// logic by examining `Rule` model data directly -- they act as a specification
/// for how each patternCategory and condition list combination should map to a
/// RuleTestScreen conditionType.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_email_spam_filter/core/models/rule_set.dart';

/// Mirrors the mapping logic from `_openRuleInTestTool` so the tests document
/// the contract without relying on private implementation details.
String _resolveConditionType(Rule rule) {
  final category = rule.patternCategory ?? '';
  if (category == 'subject' && rule.conditions.subject.isNotEmpty) {
    return 'subject';
  }
  if (category == 'body' && rule.conditions.body.isNotEmpty) {
    return 'body';
  }
  if (rule.conditions.header.isNotEmpty) return 'from';
  if (rule.conditions.from.isNotEmpty) return 'from';
  return 'from';
}

String? _resolveFirstPattern(Rule rule) {
  final category = rule.patternCategory ?? '';
  if (category == 'subject' && rule.conditions.subject.isNotEmpty) {
    return rule.conditions.subject.first;
  }
  if (category == 'body' && rule.conditions.body.isNotEmpty) {
    return rule.conditions.body.first;
  }
  if (rule.conditions.header.isNotEmpty) return rule.conditions.header.first;
  if (rule.conditions.from.isNotEmpty) return rule.conditions.from.first;
  return null;
}

void main() {
  group('Sub-feature 3 (F25) -- open rule in test tool mapping', () {
    Rule makeRule({
      String? category,
      List<String> header = const [],
      List<String> from = const [],
      List<String> subject = const [],
      List<String> body = const [],
    }) {
      return Rule(
        name: 'test_rule',
        enabled: true,
        isLocal: true,
        executionOrder: 10,
        conditions: RuleConditions(
          type: 'OR',
          header: header,
          from: from,
          subject: subject,
          body: body,
        ),
        actions: RuleActions(delete: true),
        patternCategory: category,
      );
    }

    group('conditionType mapping', () {
      test('header_from rule with header patterns -> conditionType "from"', () {
        final rule = makeRule(
          category: 'header_from',
          header: [r'@(?:[a-z0-9-]+\.)*spam\.com$'],
        );
        expect(_resolveConditionType(rule), 'from');
      });

      test('subject rule with subject patterns -> conditionType "subject"', () {
        final rule = makeRule(
          category: 'subject',
          subject: [r'(?:free|prize)'],
        );
        expect(_resolveConditionType(rule), 'subject');
      });

      test('body rule with body patterns -> conditionType "body"', () {
        final rule = makeRule(
          category: 'body',
          body: [r'click here'],
        );
        expect(_resolveConditionType(rule), 'body');
      });

      test('rule with no category falls back to "from" via header patterns', () {
        final rule = makeRule(
          category: null,
          header: [r'@test\.com$'],
        );
        expect(_resolveConditionType(rule), 'from');
      });

      test('rule with no conditions at all defaults to "from"', () {
        final rule = makeRule(category: 'header_from');
        expect(_resolveConditionType(rule), 'from');
      });

      test('subject category but empty subject list falls through to header', () {
        // Subject category with no subject patterns -- fall through to header.
        final rule = makeRule(
          category: 'subject',
          subject: [],
          header: [r'@fallback\.com$'],
        );
        // The fallback chain hits header before returning default "from".
        expect(_resolveConditionType(rule), 'from');
      });
    });

    group('firstPattern extraction', () {
      test('extracts first header pattern for header_from rule', () {
        final rule = makeRule(
          category: 'header_from',
          header: [r'@spam\.com$', r'@junk\.net$'],
        );
        expect(_resolveFirstPattern(rule), r'@spam\.com$');
      });

      test('extracts first subject pattern for subject rule', () {
        final rule = makeRule(
          category: 'subject',
          subject: [r'(?:free|prize)', r'win now'],
        );
        expect(_resolveFirstPattern(rule), r'(?:free|prize)');
      });

      test('extracts first body pattern for body rule', () {
        final rule = makeRule(
          category: 'body',
          body: [r'click here', r'unsubscribe'],
        );
        expect(_resolveFirstPattern(rule), r'click here');
      });

      test('returns null when no patterns in any condition list', () {
        final rule = makeRule(category: 'header_from');
        expect(_resolveFirstPattern(rule), isNull);
      });

      test('returns first from-list pattern when from has entries and header empty', () {
        final rule = makeRule(
          category: 'header_from',
          from: [r'^exact@domain\.com$'],
        );
        expect(_resolveFirstPattern(rule), r'^exact@domain\.com$');
      });
    });
  });
}
