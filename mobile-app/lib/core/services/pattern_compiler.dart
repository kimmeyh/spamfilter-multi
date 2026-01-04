import 'dart:collection';
import 'package:logger/logger.dart';

/// Precompiles and caches regex patterns for performance
/// 
/// Features:
/// - Compiles regex patterns with case-insensitive matching
/// - Caches compiled patterns for reuse across multiple emails
/// - Tracks compilation failures to avoid repeated attempts
/// - Provides hit/miss statistics for cache performance monitoring
/// 
/// Cache Management:
/// - Cache is automatically cleared when rules are loaded/reloaded via RuleSetProvider
/// - Cache grows based on unique pattern strings (not number of rules)
/// - For typical usage with ~50 rules, memory impact is negligible (~5KB)
/// - Manual clearing available via clear() method if needed
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
      final regex = RegExp(pattern, caseSensitive: false);
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
}
