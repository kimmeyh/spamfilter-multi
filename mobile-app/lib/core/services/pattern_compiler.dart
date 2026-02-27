import 'dart:collection';
import 'package:logger/logger.dart';

/// Precompiles and caches regex patterns for performance
class PatternCompiler {
  final Logger _logger = Logger();
  final Map<String, RegExp> _cache = HashMap();
  final Map<String, String> _failures = HashMap();
  int _hits = 0;
  int _misses = 0;

  /// Compile a pattern and cache it
  RegExp compile(String pattern) {
    if (_cache.containsKey(pattern)) {
      _hits++;
      return _cache[pattern]!;
    }

    _misses++;
    try {
      // Strip Python-style inline flags (?i), (?m), (?s), (?x) or combinations like (?im)
      // Dart RegExp doesn't support inline flags but we already use caseSensitive: false
      // Only a leading inline-flag block is removed; other (?...) constructs like (?:...) or (?=...)
      // are preserved because they don't match the following regex.
      String cleanPattern = pattern;
      if (pattern.startsWith('(?') && pattern.contains(')')) {
        final flagMatch = RegExp(r'^\(\?[imsx]+\)').firstMatch(pattern);
        if (flagMatch != null) {
          cleanPattern = pattern.substring(flagMatch.end);
          _logger.d('Stripped inline flags from pattern: "$pattern" -> "$cleanPattern"');
        }
      }

      final regex = RegExp(cleanPattern, caseSensitive: false);
      _cache[pattern] = regex;
      return regex;
    } catch (e) {
      // Invalid regex - log error, track failure, cache a pattern that never matches
      final errorMsg = e.toString();
      _logger.e('Invalid regex pattern: "$pattern" - Error: $errorMsg');
      _failures[pattern] = errorMsg;

      final fallback = RegExp(r'(?!)'); // Never matches
      _cache[pattern] = fallback;
      return fallback;
    }
  }

  /// Precompile a list of patterns
  void precompile(List<String> patterns) {
    for (final pattern in patterns) {
      compile(pattern);
    }
  }

  /// Clear the cache
  void clear() {
    _cache.clear();
    _failures.clear();
    _hits = 0;
    _misses = 0;
  }

  /// Get cache statistics
  Map<String, int> getStats() {
    return {
      'cached_patterns': _cache.length,
      'cache_hits': _hits,
      'cache_misses': _misses,
      'failed_patterns': _failures.length,
    };
  }

  /// Get all compilation failures (pattern -> error message)
  Map<String, String> get compilationFailures => Map.unmodifiable(_failures);

  /// Check if a pattern is valid (compiled successfully)
  bool isPatternValid(String pattern) => !_failures.containsKey(pattern);

  /// Validate a pattern and return warnings for common mistakes.
  ///
  /// Unlike [compile], this does not cache the pattern. It checks for
  /// structural issues that indicate the pattern may not work as intended.
  /// Returns an empty list if no warnings are found.
  ///
  /// Warnings do not prevent pattern compilation; they help users write
  /// better patterns.
  List<String> validatePattern(String pattern) {
    final warnings = <String>[];

    // Check for unescaped dots in domain-like patterns
    // e.g. "@spam.com$" should be "@spam\.com$"
    final domainLike = RegExp(r'@[a-z0-9-]+\.[a-z]+\$?$');
    if (domainLike.hasMatch(pattern) && !pattern.contains(r'\.')) {
      warnings.add('Pattern contains unescaped dot in what appears to be a domain. '
          'Use "\\." for literal dot (e.g., "@spam\\.com\$").');
    }

    // Check for redundant leading wildcards like ".*.*"
    if (pattern.contains('.*.*')) {
      warnings.add('Pattern contains redundant ".*.*". '
          'A single ".*" already matches everything.');
    }

    // Check for empty alternation branches like "(foo|)" or "(|bar)"
    if (RegExp(r'\(\||\|\)|\|\|').hasMatch(pattern)) {
      warnings.add('Pattern contains empty alternation branch. '
          'Empty branches match everything, which is likely unintended.');
    }

    // Check for patterns with 3+ repeated literal characters that will
    // not match after body normalization reduces them
    final repeatedChars = RegExp(r'(.)\1{2,}');
    if (repeatedChars.hasMatch(pattern)) {
      final match = repeatedChars.firstMatch(pattern)!;
      final char = match.group(1);
      // Only warn for non-regex metacharacters
      if (char != null && !r'.*+?{}[]()|\^$'.contains(char)) {
        warnings.add('Pattern contains 3+ repeated "$char" characters. '
            'Body normalization reduces these to 1 character. '
            'Match the normalized form instead.');
      }
    }

    return warnings;
  }
}
