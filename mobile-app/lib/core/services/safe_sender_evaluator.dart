import 'package:logger/logger.dart';

import '../storage/safe_sender_database_store.dart';
import 'pattern_compiler.dart';

/// Exception thrown when safe sender evaluation fails
class SafeSenderEvaluationException implements Exception {
  final String message;
  final dynamic originalError;

  SafeSenderEvaluationException(this.message, [this.originalError]);

  @override
  String toString() =>
      'SafeSenderEvaluationException: $message${originalError != null ? '\nCause: $originalError' : ''}';
}

/// Evaluates emails against safe sender patterns with exception support
///
/// This evaluator implements the following logic:
/// 1. Load safe sender pattern (e.g., @company.com)
/// 2. Try to match email against pattern
/// 3. If no match: return FALSE (not a safe sender)
/// 4. If match: load exception patterns
/// 5. For each exception: try to match email
/// 6. If any exception matches: return FALSE
/// 7. If no exception matches: return TRUE
///
/// Example usage:
/// ```dart
/// final dbHelper = DatabaseHelper();
/// final store = SafeSenderDatabaseStore(dbHelper);
/// final compiler = PatternCompiler();
/// final evaluator = SafeSenderEvaluator(store, compiler);
///
/// // Check if email is safe (not an exception)
/// final isSafe = await evaluator.isSafe('user@company.com');
/// // Returns: true if user@company.com matches a safe sender pattern
/// //          and does not match any exceptions
///
/// // Evaluate all safe senders
/// final result = await evaluator.evaluateSafeSenders('spammer@company.com');
/// // Returns: SafeSenderEvaluationResult with matching pattern and exception info
/// ```
class SafeSenderEvaluator {
  final SafeSenderDatabaseStore databaseStore;
  final PatternCompiler patternCompiler;
  final Logger _logger = Logger();

  SafeSenderEvaluator(SafeSenderDatabaseStore store, PatternCompiler compiler)
      : databaseStore = store,
        patternCompiler = compiler;

  /// Check if an email address is a safe sender
  ///
  /// Returns true if:
  /// 1. Email matches at least one safe sender pattern, AND
  /// 2. Email does NOT match any exception patterns
  ///
  /// Returns false if:
  /// - Email does not match any safe sender pattern, OR
  /// - Email matches an exception pattern
  Future<bool> isSafe(String emailAddress) async {
    try {
      final result = await evaluateSafeSenders(emailAddress);
      return result.isSafe;
    } catch (e) {
      _logger.e('Failed to evaluate safe sender: $e');
      return false;
    }
  }

  /// Evaluate email against all safe sender patterns
  ///
  /// Returns detailed evaluation result including:
  /// - Whether email is safe
  /// - Which pattern matched (if any)
  /// - Which exception matched (if any)
  /// - Evaluation details
  Future<SafeSenderEvaluationResult> evaluateSafeSenders(String emailAddress) async {
    try {
      final normalized = emailAddress.toLowerCase().trim();

      // Load all safe sender patterns
      final safeSenders = await databaseStore.loadSafeSenders();

      if (safeSenders.isEmpty) {
        return SafeSenderEvaluationResult(
          isSafe: false,
          emailAddress: emailAddress,
          matchedPattern: null,
          matchedException: null,
          reason: 'No safe sender patterns configured',
        );
      }

      // Check each safe sender pattern
      for (final sender in safeSenders) {
        // Try to match email against safe sender pattern
        if (_matchesPattern(normalized, sender.pattern)) {
          // Email matches safe sender pattern
          _logger.d('Email "$emailAddress" matches safe sender pattern: "${sender.pattern}"');

          // Check exceptions
          if (sender.exceptionPatterns != null && sender.exceptionPatterns!.isNotEmpty) {
            for (final exceptionPattern in sender.exceptionPatterns!) {
              if (_matchesPattern(normalized, exceptionPattern)) {
                // Email matches exception pattern - NOT a safe sender
                _logger.d(
                  'Email "$emailAddress" matches exception to pattern "${sender.pattern}": '
                  '"$exceptionPattern"',
                );

                return SafeSenderEvaluationResult(
                  isSafe: false,
                  emailAddress: emailAddress,
                  matchedPattern: sender.pattern,
                  matchedException: exceptionPattern,
                  reason: 'Matched safe sender pattern but exception applies',
                );
              }
            }
          }

          // Email matches safe sender pattern and no exceptions apply
          _logger.d('Email "$emailAddress" is safe sender (pattern: "${sender.pattern}")');

          return SafeSenderEvaluationResult(
            isSafe: true,
            emailAddress: emailAddress,
            matchedPattern: sender.pattern,
            matchedException: null,
            reason: 'Matches safe sender pattern with no exceptions',
          );
        }
      }

      // Email did not match any safe sender pattern
      _logger.d('Email "$emailAddress" does not match any safe sender patterns');

      return SafeSenderEvaluationResult(
        isSafe: false,
        emailAddress: emailAddress,
        matchedPattern: null,
        matchedException: null,
        reason: 'Does not match any safe sender pattern',
      );
    } catch (e) {
      throw SafeSenderEvaluationException('Failed to evaluate safe senders', e);
    }
  }

  /// Check if text matches a pattern
  ///
  /// Handles both simple string matching and regex patterns.
  /// Returns true if:
  /// - For exact email patterns (no regex): performs case-insensitive exact match
  /// - For domain patterns (start with @): matches any user at that domain
  /// - For regex patterns: uses compiled regex matching
  bool _matchesPattern(String text, String pattern) {
    try {
      final normalizedText = text.toLowerCase();
      final normalizedPattern = pattern.toLowerCase();

      // Check if pattern contains regex special characters
      final hasRegex = normalizedPattern.contains(RegExp(r'[\[\]()*+?\\^$|]'));

      String patternToMatch = normalizedPattern;
      if (!hasRegex) {
        if (normalizedPattern.startsWith('@')) {
          // Domain pattern: match any user at this domain
          // Convert @example.com to ^[^@\s]+@example\.com$
          patternToMatch = '^[^@\\s]+${RegExp.escape(normalizedPattern)}\$';
        } else {
          // Simple email pattern: exact match only
          patternToMatch = '^${RegExp.escape(normalizedPattern)}\$';
        }
      }

      // Try to compile and match as regex
      final regex = patternCompiler.compile(patternToMatch);
      return regex.hasMatch(normalizedText);
    } catch (e) {
      _logger.w('Failed to match pattern "$pattern" against "$text": $e');
      return false;
    }
  }

  /// Get statistics about the evaluator
  ///
  /// Useful for debugging and performance monitoring
  Map<String, dynamic> getStatistics() {
    return {
      'pattern_compiler': patternCompiler.getStats(),
    };
  }

  /// Clear the pattern cache
  ///
  /// Call this to free memory and clear cached patterns.
  /// Cache will be rebuilt on next evaluation.
  void clearCache() {
    patternCompiler.clear();
    _logger.i('Cleared pattern cache');
  }
}

/// Result of safe sender evaluation
///
/// Contains:
/// - isSafe: Whether the email is a safe sender
/// - emailAddress: The email that was evaluated
/// - matchedPattern: The safe sender pattern that matched (if any)
/// - matchedException: The exception pattern that matched (if any)
/// - reason: Human-readable explanation of the result
class SafeSenderEvaluationResult {
  final bool isSafe;
  final String emailAddress;
  final String? matchedPattern;
  final String? matchedException;
  final String reason;

  SafeSenderEvaluationResult({
    required this.isSafe,
    required this.emailAddress,
    required this.matchedPattern,
    required this.matchedException,
    required this.reason,
  });

  @override
  String toString() => 'SafeSenderEvaluationResult('
      'isSafe: $isSafe, '
      'email: $emailAddress, '
      'pattern: $matchedPattern, '
      'exception: $matchedException, '
      'reason: $reason)';
}
