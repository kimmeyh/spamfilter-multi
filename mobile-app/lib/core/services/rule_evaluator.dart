import '../models/email_message.dart';
import '../models/rule_set.dart';
import '../models/safe_sender_list.dart';
import '../models/evaluation_result.dart';
import 'pattern_compiler.dart';

/// Evaluates emails against rules to determine actions
class RuleEvaluator {
  final RuleSet ruleSet;
  final SafeSenderList safeSenderList;
  final PatternCompiler compiler;

  RuleEvaluator({
    required this.ruleSet,
    required this.safeSenderList,
    required this.compiler,
  });

  /// Evaluate an email and return the action to take
  Future<EvaluationResult> evaluate(EmailMessage message) async {
    // Check safe senders first
    if (safeSenderList.isSafe(message.from)) {
      return EvaluationResult.safeSender(message.from);
    }

    // Evaluate rules in execution order
    final sortedRules = List<Rule>.from(ruleSet.rules)
      ..sort((a, b) => a.executionOrder.compareTo(b.executionOrder));

    for (final rule in sortedRules) {
      if (!rule.enabled) continue;

      // Check exceptions first
      if (rule.exceptions != null && _matchesExceptions(message, rule.exceptions!)) {
        continue;
      }

      // Check conditions
      if (_matchesConditions(message, rule.conditions)) {
        return EvaluationResult(
          shouldDelete: rule.actions.delete,
          shouldMove: rule.actions.moveToFolder != null,
          targetFolder: rule.actions.moveToFolder,
          matchedRule: rule.name,
          matchedPattern: _getMatchedPattern(message, rule.conditions),
        );
      }
    }

    return EvaluationResult.noMatch();
  }

  bool _matchesConditions(EmailMessage message, RuleConditions conditions) {
    final matches = <bool>[
      _matchesPatternList(message.from, conditions.from),
      _matchesPatternList(message.from, conditions.header),
      _matchesPatternList(message.subject, conditions.subject),
      _matchesPatternList(message.body, conditions.body),
    ];

    if (conditions.type == 'AND') {
      return matches.every((m) => m);
    } else {
      return matches.any((m) => m);
    }
  }

  bool _matchesExceptions(EmailMessage message, RuleExceptions exceptions) {
    return _matchesPatternList(message.from, exceptions.from) ||
        _matchesPatternList(message.from, exceptions.header) ||
        _matchesPatternList(message.subject, exceptions.subject) ||
        _matchesPatternList(message.body, exceptions.body);
  }

  bool _matchesPatternList(String text, List<String> patterns) {
    if (patterns.isEmpty) return false;
    final normalized = text.toLowerCase().trim();
    
    return patterns.any((pattern) {
      try {
        final regex = compiler.compile(pattern);
        return regex.hasMatch(normalized);
      } catch (e) {
        return false;
      }
    });
  }

  String _getMatchedPattern(EmailMessage message, RuleConditions conditions) {
    for (final pattern in conditions.from) {
      if (_matchesPattern(message.from, pattern)) return pattern;
    }
    for (final pattern in conditions.header) {
      if (_matchesPattern(message.from, pattern)) return pattern;
    }
    for (final pattern in conditions.subject) {
      if (_matchesPattern(message.subject, pattern)) return pattern;
    }
    for (final pattern in conditions.body) {
      if (_matchesPattern(message.body, pattern)) return pattern;
    }
    return '';
  }

  bool _matchesPattern(String text, String pattern) {
    try {
      final regex = compiler.compile(pattern);
      return regex.hasMatch(text.toLowerCase().trim());
    } catch (e) {
      return false;
    }
  }
}
