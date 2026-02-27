import 'package:logger/logger.dart';

import '../models/email_message.dart';
import '../models/rule_set.dart';
import '../models/safe_sender_list.dart';
import 'pattern_compiler.dart';

/// Describes a conflict between a new rule and an existing rule or safe sender
class RuleConflict {
  /// The name of the existing rule or 'Safe Sender' that would override
  final String conflictingRuleName;

  /// The execution order of the conflicting rule (0 for safe senders)
  final int conflictingOrder;

  /// The execution order of the new rule
  final int newRuleOrder;

  /// The action the conflicting rule would take
  final String conflictingAction;

  /// Whether the conflict is with a safe sender (always wins)
  final bool isSafeSenderConflict;

  /// The pattern in the conflicting rule that matched
  final String conflictingPattern;

  const RuleConflict({
    required this.conflictingRuleName,
    required this.conflictingOrder,
    required this.newRuleOrder,
    required this.conflictingAction,
    this.isSafeSenderConflict = false,
    required this.conflictingPattern,
  });

  /// Human-readable description of the conflict
  String get description {
    if (isSafeSenderConflict) {
      return 'A safe sender pattern "$conflictingPattern" matches this email. '
          'Safe senders always take priority over rules, so the new rule '
          'will not be evaluated for emails matching this pattern.';
    }
    return 'Rule "$conflictingRuleName" (order=$conflictingOrder) would match '
        'this email before the new rule (order=$newRuleOrder). '
        'Action: $conflictingAction.';
  }
}

/// Detects conflicts when adding a new rule
///
/// Checks if an existing rule with higher priority (lower executionOrder)
/// or a safe sender pattern would prevent the new rule from being evaluated.
/// This helps users understand why their new rule might not take effect.
class RuleConflictDetector {
  final Logger _logger = Logger();
  final PatternCompiler _compiler = PatternCompiler();

  /// Detect conflicts between a new rule and existing rules/safe senders
  ///
  /// Evaluates [email] against existing [ruleSet] and [safeSenderList] to
  /// determine if any existing rule or safe sender would match before
  /// the new rule at [newRuleOrder].
  ///
  /// Returns a list of [RuleConflict] instances. Empty list means no conflicts.
  List<RuleConflict> detectConflicts({
    required EmailMessage email,
    required Rule newRule,
    required RuleSet ruleSet,
    required SafeSenderList safeSenderList,
  }) {
    final conflicts = <RuleConflict>[];

    // Check safe sender conflicts first (safe senders always win)
    final safeSenderConflict = _checkSafeSenderConflict(
      email: email,
      safeSenderList: safeSenderList,
    );
    if (safeSenderConflict != null) {
      conflicts.add(safeSenderConflict);
    }

    // Check existing rule conflicts (rules with lower executionOrder)
    final ruleConflicts = _checkRuleConflicts(
      email: email,
      newRule: newRule,
      ruleSet: ruleSet,
    );
    conflicts.addAll(ruleConflicts);

    if (conflicts.isNotEmpty) {
      _logger.d('Detected ${conflicts.length} conflict(s) for new rule "${newRule.name}"');
    }

    return conflicts;
  }

  /// Check if any safe sender pattern matches the email
  RuleConflict? _checkSafeSenderConflict({
    required EmailMessage email,
    required SafeSenderList safeSenderList,
  }) {
    final match = safeSenderList.findMatch(email.from);
    if (match != null) {
      return RuleConflict(
        conflictingRuleName: 'Safe Sender',
        conflictingOrder: 0,
        newRuleOrder: 0,
        conflictingAction: 'Allow (whitelist)',
        isSafeSenderConflict: true,
        conflictingPattern: match.pattern,
      );
    }
    return null;
  }

  /// Check if any existing rule with higher priority would match the email
  List<RuleConflict> _checkRuleConflicts({
    required EmailMessage email,
    required Rule newRule,
    required RuleSet ruleSet,
  }) {
    final conflicts = <RuleConflict>[];

    // Sort rules by execution order (ascending = higher priority first)
    final sortedRules = List<Rule>.from(ruleSet.rules)
      ..sort((a, b) => a.executionOrder.compareTo(b.executionOrder));

    for (final existingRule in sortedRules) {
      // Skip disabled rules
      if (!existingRule.enabled) continue;

      // Only check rules with higher priority (lower executionOrder)
      if (existingRule.executionOrder >= newRule.executionOrder) continue;

      // Skip the rule if it is the same rule being edited
      if (existingRule.name == newRule.name) continue;

      // Check if existing rule's exceptions would skip this email
      if (existingRule.exceptions != null &&
          _matchesExceptions(email, existingRule.exceptions!)) {
        continue;
      }

      // Check if existing rule's conditions would match this email
      if (_matchesConditions(email, existingRule.conditions)) {
        final matchedPattern = _getMatchedPattern(email, existingRule.conditions);
        final action = _describeAction(existingRule.actions);

        conflicts.add(RuleConflict(
          conflictingRuleName: existingRule.name,
          conflictingOrder: existingRule.executionOrder,
          newRuleOrder: newRule.executionOrder,
          conflictingAction: action,
          conflictingPattern: matchedPattern,
        ));
      }
    }

    return conflicts;
  }

  /// Check if email matches rule conditions (mirrors RuleEvaluator logic)
  bool _matchesConditions(EmailMessage email, RuleConditions conditions) {
    final matches = <bool>[];

    if (conditions.from.isNotEmpty) {
      matches.add(_matchesPatternList(email.from, conditions.from));
    }
    if (conditions.header.isNotEmpty) {
      matches.add(_matchesHeaderList(email, conditions.header));
    }
    if (conditions.subject.isNotEmpty) {
      matches.add(_matchesPatternList(email.subject, conditions.subject));
    }
    if (conditions.body.isNotEmpty) {
      matches.add(_matchesPatternList(email.body, conditions.body));
    }

    if (matches.isEmpty) return false;

    if (conditions.type == 'AND') {
      return matches.every((m) => m);
    } else {
      return matches.any((m) => m);
    }
  }

  /// Check if email matches rule exceptions
  bool _matchesExceptions(EmailMessage email, RuleExceptions exceptions) {
    return _matchesPatternList(email.from, exceptions.from) ||
        _matchesHeaderList(email, exceptions.header) ||
        _matchesPatternList(email.subject, exceptions.subject) ||
        _matchesPatternList(email.body, exceptions.body);
  }

  bool _matchesPatternList(String text, List<String> patterns) {
    if (patterns.isEmpty) return false;
    final normalized = text.toLowerCase().trim();

    return patterns.any((pattern) {
      try {
        final regex = _compiler.compile(pattern);
        return regex.hasMatch(normalized);
      } catch (e) {
        return false;
      }
    });
  }

  bool _matchesHeaderList(EmailMessage email, List<String> patterns) {
    if (patterns.isEmpty) return false;

    return patterns.any((pattern) {
      try {
        final regex = _compiler.compile(pattern);
        for (final entry in email.headers.entries) {
          String testValue;
          if (entry.key.toLowerCase() == 'from') {
            testValue = email.from.toLowerCase().trim();
          } else {
            testValue = '${entry.key}:${entry.value}'.toLowerCase().trim();
          }
          if (regex.hasMatch(testValue)) return true;
        }
        return false;
      } catch (e) {
        return false;
      }
    });
  }

  /// Get the first matching pattern from conditions
  String _getMatchedPattern(EmailMessage email, RuleConditions conditions) {
    for (final pattern in conditions.from) {
      if (_matchesPattern(email.from, pattern)) return pattern;
    }
    for (final pattern in conditions.subject) {
      if (_matchesPattern(email.subject, pattern)) return pattern;
    }
    for (final pattern in conditions.body) {
      if (_matchesPattern(email.body, pattern)) return pattern;
    }
    for (final pattern in conditions.header) {
      if (_matchesHeaderPattern(email, pattern)) return pattern;
    }
    return '(unknown)';
  }

  bool _matchesPattern(String text, String pattern) {
    try {
      final regex = _compiler.compile(pattern);
      return regex.hasMatch(text.toLowerCase().trim());
    } catch (e) {
      return false;
    }
  }

  bool _matchesHeaderPattern(EmailMessage email, String pattern) {
    try {
      final regex = _compiler.compile(pattern);
      for (final entry in email.headers.entries) {
        String testValue;
        if (entry.key.toLowerCase() == 'from') {
          testValue = email.from.toLowerCase().trim();
        } else {
          testValue = '${entry.key}:${entry.value}'.toLowerCase().trim();
        }
        if (regex.hasMatch(testValue)) return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Describe a rule's action in human-readable form
  String _describeAction(RuleActions actions) {
    if (actions.delete) return 'Delete';
    if (actions.moveToFolder != null) return 'Move to ${actions.moveToFolder}';
    return 'No action';
  }
}
