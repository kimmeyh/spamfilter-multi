import '../models/email_message.dart';
import '../models/rule_set.dart';
import '../models/safe_sender_list.dart';
import '../models/evaluation_result.dart';
import '../utils/app_logger.dart';
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
    final safeSenderMatch = safeSenderList.findMatch(message.from);
    if (safeSenderMatch != null) {
      return EvaluationResult.safeSender(
        safeSenderMatch.pattern,
        patternType: safeSenderMatch.patternType,
      );
    }

    // Evaluate rules in execution order
    final sortedRules = List<Rule>.from(ruleSet.rules)
      ..sort((a, b) => a.executionOrder.compareTo(b.executionOrder));

    // DIAGNOSTIC: Log rule evaluation for first few emails
    if (sortedRules.isEmpty) {
      AppLogger.rules('No rules available for evaluation of "${message.subject}" from ${message.from}');
      return EvaluationResult.noMatch();
    }

    int enabledRuleCount = 0;
    for (final rule in sortedRules) {
      if (!rule.enabled) {
        AppLogger.debug('Rule "${rule.name}" is disabled, skipping');
        continue;
      }
      enabledRuleCount++;

      // Check exceptions first
      if (rule.exceptions != null && _matchesExceptions(message, rule.exceptions!)) {
        AppLogger.eval('Email "${message.subject}" from ${message.from} matched exception in rule "${rule.name}", skipping');
        continue;
      }

      // Check conditions
      if (_matchesConditions(message, rule.conditions)) {
        final matchInfo = _getMatchedPatternWithType(message, rule.conditions);
        final pattern = matchInfo.pattern;
        final patternType = matchInfo.patternType;
        AppLogger.eval('Email from ${message.from} matched rule "${rule.name}" (pattern: $pattern, type: $patternType, subject: "${message.subject}")');
        return EvaluationResult(
          shouldDelete: rule.actions.delete,
          shouldMove: rule.actions.moveToFolder != null,
          targetFolder: rule.actions.moveToFolder,
          matchedRule: rule.name,
          matchedPattern: pattern,
          matchedPatternType: patternType,
        );
      }
    }

    AppLogger.eval('Email "${message.subject}" from ${message.from} did not match any of $enabledRuleCount enabled rules');
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

  /// Get matched pattern along with its type for visual indicators
  ({String pattern, String? patternType}) _getMatchedPatternWithType(
      EmailMessage message, RuleConditions conditions) {
    // Check 'from' field patterns first
    for (final pattern in conditions.from) {
      if (_matchesPattern(message.from, pattern)) {
        return (pattern: pattern, patternType: _determinePatternType(pattern, 'from'));
      }
    }
    // Check 'header' field patterns
    for (final pattern in conditions.header) {
      if (_matchesHeaderPattern(message, pattern)) {
        return (pattern: pattern, patternType: _determinePatternType(pattern, 'header'));
      }
    }
    // Check 'subject' field patterns
    for (final pattern in conditions.subject) {
      if (_matchesPattern(message.subject, pattern)) {
        return (pattern: pattern, patternType: 'subject');
      }
    }
    // Check 'body' field patterns
    for (final pattern in conditions.body) {
      if (_matchesPattern(message.body, pattern)) {
        return (pattern: pattern, patternType: 'body');
      }
    }
    return (pattern: '', patternType: null);
  }

  /// Determine the pattern type based on the pattern and field type
  String? _determinePatternType(String pattern, String fieldType) {
    // If from subject/body/header fields, use field type
    if (fieldType == 'subject') return 'subject';
    if (fieldType == 'body') return 'body';

    // For 'from' and 'header' field patterns, analyze the regex
    // Check for subdomain wildcard patterns (entire domain)
    // Patterns like: @(?:[a-z0-9-]+\.)*domain\.com$
    if (pattern.contains(r'(?:') || pattern.contains(r'[a-z0-9-]+\.)*')) {
      return 'entire_domain';
    }

    // Check if pattern includes username part (exact email)
    // Patterns like: ^user@domain\.com$ or specific\.user@domain\.com$
    // Look for patterns that have specific content before @ (not wildcards)
    if (pattern.contains('@')) {
      // Find the position of @ in the pattern
      final atIndex = pattern.indexOf('@');
      if (atIndex > 0) {
        final beforeAt = pattern.substring(0, atIndex);
        // If there is specific text before @ that is not just anchors or wildcards
        // and not a character class like [^@\s]+, it is an exact email
        if (!beforeAt.endsWith('[^@\\s]+') &&
            !beforeAt.endsWith(r'[^@\s]+') &&
            !beforeAt.contains(r'(?:') &&
            beforeAt != '^' &&
            beforeAt != '') {
          // Check if it starts with ^ and has actual characters
          final cleanBefore = beforeAt.startsWith('^') ? beforeAt.substring(1) : beforeAt;
          if (cleanBefore.isNotEmpty && !cleanBefore.startsWith('[')) {
            return 'exact_email';
          }
        }
      }
    }

    // Check for exact domain pattern (matches @domain.com without subdomains)
    // Patterns like: ^[^@\s]+@domain\.com$ or @domain\.com$
    if (pattern.contains('@') && !pattern.contains(r'(?:') && !pattern.contains(r'[a-z0-9-]+\.)*')) {
      return 'exact_domain';
    }

    // For header field without @, it is a header pattern
    if (fieldType == 'header') {
      return 'header';
    }

    // Default fallback for from patterns
    return 'exact_domain';
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
