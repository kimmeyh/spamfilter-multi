/// Shared conflict resolution for rules and safe senders
///
/// When adding a block rule, checks for and removes conflicting safe senders.
/// When adding a safe sender, checks for and removes conflicting block rules.
/// Used by ResultsDisplayScreen (inline), RuleQuickAddScreen, and
/// SafeSenderQuickAddScreen to ensure consistent behavior.
library;

import 'package:logger/logger.dart';

import '../models/rule_set.dart';
import '../models/safe_sender_list.dart';
import '../providers/rule_set_provider.dart';
import 'pattern_compiler.dart';

/// Result of a conflict resolution check
class ConflictResolutionResult {
  /// Number of conflicting items found
  final int conflictsFound;

  /// Number of conflicting items removed
  final int conflictsRemoved;

  /// Descriptions of the conflicts found (for UI display)
  final List<String> conflictDescriptions;

  const ConflictResolutionResult({
    required this.conflictsFound,
    required this.conflictsRemoved,
    required this.conflictDescriptions,
  });

  bool get hasConflicts => conflictsFound > 0;

  static const empty = ConflictResolutionResult(
    conflictsFound: 0,
    conflictsRemoved: 0,
    conflictDescriptions: [],
  );
}

/// Resolves conflicts between rules and safe senders
///
/// This service centralizes the conflict detection and removal logic that
/// was previously duplicated across RuleQuickAddScreen, SafeSenderQuickAddScreen,
/// and missing from ResultsDisplayScreen (the root cause of Issue #154).
class RuleConflictResolver {
  final Logger _logger = Logger();
  final PatternCompiler _compiler = PatternCompiler();

  /// Find and remove safe senders that conflict with a new block rule.
  ///
  /// When a user creates a block rule for an email, any safe sender pattern
  /// that matches that email must be removed, because safe senders are
  /// evaluated first by RuleEvaluator and would prevent the block rule
  /// from firing.
  ///
  /// [emailAddress] is the normalized email address being blocked.
  /// [ruleProvider] is used to read current safe senders and remove conflicts.
  ///
  /// Returns a [ConflictResolutionResult] describing what was found and removed.
  Future<ConflictResolutionResult> removeConflictingSafeSenders({
    required String emailAddress,
    required RuleSetProvider ruleProvider,
  }) async {
    final safeSenders = ruleProvider.safeSenders;
    if (safeSenders.safeSenders.isEmpty) return ConflictResolutionResult.empty;

    final normalizedEmail = emailAddress.toLowerCase().trim();
    final descriptions = <String>[];
    int removedCount = 0;

    for (final pattern in List<String>.from(safeSenders.safeSenders)) {
      if (_patternMatchesEmail(pattern, normalizedEmail)) {
        descriptions.add('Safe sender "$pattern" matches this email');
        try {
          await ruleProvider.removeSafeSender(pattern);
          removedCount++;
          _logger.i('Removed conflicting safe sender: $pattern (conflicts with block rule for $normalizedEmail)');
        } catch (e) {
          _logger.w('Failed to remove conflicting safe sender "$pattern": $e');
        }
      }
    }

    if (removedCount > 0) {
      _logger.i('Removed $removedCount conflicting safe sender(s) for block rule on $normalizedEmail');
    }

    return ConflictResolutionResult(
      conflictsFound: descriptions.length,
      conflictsRemoved: removedCount,
      conflictDescriptions: descriptions,
    );
  }

  /// Find and remove block rules that conflict with a new safe sender.
  ///
  /// When a user adds a safe sender for an email, any block rule with
  /// from-header conditions matching that email should be removed, because
  /// safe senders take priority and the block rule would never fire.
  ///
  /// [emailAddress] is the normalized email address being whitelisted.
  /// [ruleProvider] is used to read current rules and remove conflicts.
  ///
  /// Returns a [ConflictResolutionResult] describing what was found and removed.
  Future<ConflictResolutionResult> removeConflictingRules({
    required String emailAddress,
    required RuleSetProvider ruleProvider,
  }) async {
    final rules = ruleProvider.rules;
    if (rules.rules.isEmpty) return ConflictResolutionResult.empty;

    final normalizedEmail = emailAddress.toLowerCase().trim();
    final descriptions = <String>[];
    int removedCount = 0;

    for (final rule in List<Rule>.from(rules.rules)) {
      // Check from conditions
      if (rule.conditions.from.isEmpty && rule.conditions.header.isEmpty) continue;

      bool ruleMatchesEmail = false;

      // Check from conditions
      for (final fromPattern in rule.conditions.from) {
        if (_patternMatchesEmail(fromPattern, normalizedEmail)) {
          ruleMatchesEmail = true;
          break;
        }
      }

      // Check header conditions (which also match from)
      if (!ruleMatchesEmail) {
        for (final headerPattern in rule.conditions.header) {
          if (_patternMatchesEmail(headerPattern, normalizedEmail)) {
            ruleMatchesEmail = true;
            break;
          }
        }
      }

      if (ruleMatchesEmail) {
        descriptions.add('Rule "${rule.name}" matches this email');
        try {
          await ruleProvider.removeRule(rule.name);
          removedCount++;
          _logger.i('Removed conflicting rule: ${rule.name} (conflicts with safe sender for $normalizedEmail)');
        } catch (e) {
          _logger.w('Failed to remove conflicting rule "${rule.name}": $e');
        }
      }
    }

    if (removedCount > 0) {
      _logger.i('Removed $removedCount conflicting rule(s) for safe sender on $normalizedEmail');
    }

    return ConflictResolutionResult(
      conflictsFound: descriptions.length,
      conflictsRemoved: removedCount,
      conflictDescriptions: descriptions,
    );
  }

  /// Check if a regex pattern matches an email address
  bool _patternMatchesEmail(String pattern, String normalizedEmail) {
    try {
      final regex = _compiler.compile(pattern);
      return regex.hasMatch(normalizedEmail);
    } catch (e) {
      // If pattern is not valid regex, check exact match
      return pattern.toLowerCase() == normalizedEmail;
    }
  }
}
