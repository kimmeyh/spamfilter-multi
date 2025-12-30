import 'dart:collection';

/// Precompiles and caches regex patterns for performance
class PatternCompiler {
  final Map<String, RegExp> _cache = HashMap();
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
      // Invalid regex - cache a pattern that never matches
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
    _hits = 0;
    _misses = 0;
  }

  /// Get cache statistics
  Map<String, int> getStats() {
    return {
      'cached_patterns': _cache.length,
      'cache_hits': _hits,
      'cache_misses': _misses,
    };
  }
}
