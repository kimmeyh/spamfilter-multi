import 'package:logger/logger.dart';

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
  final Logger _logger = Logger();

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

    // DIAGNOSTIC: Log rule evaluation for first few emails
    if (sortedRules.isEmpty) {
      _logger.w('RuleEvaluator: No rules available for evaluation of "${message.subject}"');
      return EvaluationResult.noMatch();
    }

    int enabledRuleCount = 0;
    for (final rule in sortedRules) {
      if (!rule.enabled) {
        _logger.d('Rule "${rule.name}" is disabled, skipping');
        continue;
      }
      enabledRuleCount++;

      // Check exceptions first
      if (rule.exceptions != null && _matchesExceptions(message, rule.exceptions!)) {
        _logger.d('Email "${message.subject}" matched exception in rule "${rule.name}", skipping');
        continue;
      }

      // Check conditions
      if (_matchesConditions(message, rule.conditions)) {
        _logger.i('✓ Email "${message.subject}" matched rule "${rule.name}"');
        return EvaluationResult(
          shouldDelete: rule.actions.delete,
          shouldMove: rule.actions.moveToFolder != null,
          targetFolder: rule.actions.moveToFolder,
          matchedRule: rule.name,
          matchedPattern: _getMatchedPattern(message, rule.conditions),
        );
      }
    }

    _logger.d('✗ Email "${message.subject}" did not match any of $enabledRuleCount enabled rules');
    return EvaluationResult.noMatch();
  }

  bool _matchesConditions(EmailMessage message, RuleConditions conditions) {
    final matches = <bool>[];

    // Only check non-empty pattern lists
    if (conditions.from.isNotEmpty) {
      matches.add(_matchesPatternList(message.from, conditions.from));
    }
    if (conditions.header.isNotEmpty) {
      matches.add(_matchesHeaderList(message, conditions.header));
    }
    if (conditions.subject.isNotEmpty) {
      matches.add(_matchesPatternList(message.subject, conditions.subject));
    }
    if (conditions.body.isNotEmpty) {
      matches.add(_matchesPatternList(message.body, conditions.body));
    }

    // If no patterns specified, don't match
    if (matches.isEmpty) {
      return false;
    }

    if (conditions.type == 'AND') {
      return matches.every((m) => m);
    } else {
      return matches.any((m) => m);
    }
  }

  bool _matchesExceptions(EmailMessage message, RuleExceptions exceptions) {
    return _matchesPatternList(message.from, exceptions.from) ||
        _matchesHeaderList(message, exceptions.header) ||
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

  /// Match header patterns against email headers
  /// For "From" header, match against email address only (without "from:" prefix)
  /// For other headers, match against "key:value" format (e.g., "x-spam-status:yes")
  bool _matchesHeaderList(EmailMessage message, List<String> patterns) {
    if (patterns.isEmpty) return false;

    return patterns.any((pattern) {
      try {
        final regex = compiler.compile(pattern);
        // Check each header
        for (final entry in message.headers.entries) {
          String testValue;

          // For "From" header, match against email address only (not "from:email")
          // Use message.from which has already been extracted from "Name <email>" format
          if (entry.key.toLowerCase() == 'from') {
            testValue = message.from.toLowerCase().trim();
          } else {
            // For other headers, use "key:value" format
            testValue = '${entry.key}:${entry.value}'.toLowerCase().trim();
          }

          if (regex.hasMatch(testValue)) {
            return true;
          }
        }
        return false;
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
      if (_matchesHeaderPattern(message, pattern)) return pattern;
    }
    for (final pattern in conditions.subject) {
      if (_matchesPattern(message.subject, pattern)) return pattern;
    }
    for (final pattern in conditions.body) {
      if (_matchesPattern(message.body, pattern)) return pattern;
    }
    return '';
  }

  /// Check if a single header pattern matches any header
  /// For "From" header, match against email address only (without "from:" prefix)
  /// For other headers, match against "key:value" format
  bool _matchesHeaderPattern(EmailMessage message, String pattern) {
    try {
      final regex = compiler.compile(pattern);
      for (final entry in message.headers.entries) {
        String testValue;

        // For "From" header, match against email address only (not "from:email")
        // Use message.from which has already been extracted from "Name <email>" format
        if (entry.key.toLowerCase() == 'from') {
          testValue = message.from.toLowerCase().trim();
        } else {
          // For other headers, use "key:value" format
          testValue = '${entry.key}:${entry.value}'.toLowerCase().trim();
        }

        if (regex.hasMatch(testValue)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
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
