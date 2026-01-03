import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/services/pattern_compiler.dart';

void main() {
  late PatternCompiler compiler;

  setUp(() {
    compiler = PatternCompiler();
  });

  group('PatternCompiler', () {
    test('compiles valid regex pattern', () {
      final pattern = compiler.compile(r'^test@example\.com$');
      expect(pattern, isNotNull);
      expect(pattern.hasMatch('test@example.com'), isTrue);
      expect(pattern.hasMatch('other@example.com'), isFalse);
    });

    test('caches compiled patterns', () {
      final pattern1 = compiler.compile(r'^test@example\.com$');
      final pattern2 = compiler.compile(r'^test@example\.com$');
      expect(identical(pattern1, pattern2), isTrue);
    });

    test('handles invalid regex gracefully', () {
      final pattern = compiler.compile(r'[invalid(regex');
      // Returns a fallback pattern that never matches
      expect(pattern, isNotNull);
      expect(pattern.hasMatch('anything'), isFalse);
    });

    test('precompiles multiple patterns', () {
      final patterns = [
        r'^test@example\.com$',
        r'^admin@.*\.com$',
        r'.*spam.*',
      ];
      
      compiler.precompile(patterns);
      final stats = compiler.getStats();
      
      expect(stats['cached_patterns'], equals(3));
      expect(stats['cache_hits'], equals(0));
    });

    test('tracks cache hits and misses', () {
      // First compile - cache miss
      compiler.compile(r'^test@example\.com$');
      var stats = compiler.getStats();
      expect(stats['cached_patterns'], equals(1));
      expect(stats['cache_hits'], equals(0));
      expect(stats['cache_misses'], equals(1));
      
      // Second compile - cache hit
      compiler.compile(r'^test@example\.com$');
      stats = compiler.getStats();
      expect(stats['cache_hits'], equals(1));
    });

    test('clears cache', () {
      compiler.compile(r'^test@example\.com$');
      expect(compiler.getStats()['cached_patterns'], equals(1));
      
      compiler.clear();
      expect(compiler.getStats()['cached_patterns'], equals(0));
    });

    test('matches domain patterns', () {
      final pattern = compiler.compile(r'^[^@\s]+@(?:[a-z0-9-]+\.)*example\.com$');
      expect(pattern, isNotNull);
      expect(pattern.hasMatch('user@example.com'), isTrue);
      expect(pattern.hasMatch('user@mail.example.com'), isTrue);
      expect(pattern.hasMatch('user@sub.mail.example.com'), isTrue);
      expect(pattern.hasMatch('user@otherdomain.com'), isFalse);
    });
  });

  group('PatternCompiler - Failure Tracking', () {
    test('tracks compilation failures', () {
      final invalidPattern = r'[invalid(regex';
      compiler.compile(invalidPattern);

      final failures = compiler.compilationFailures;
      expect(failures, isNotEmpty);
      expect(failures.containsKey(invalidPattern), isTrue);
      expect(failures[invalidPattern], isNotNull);
      expect(failures[invalidPattern], contains('FormatException'));
    });

    test('isPatternValid returns false for invalid patterns', () {
      final invalidPattern = r'[unclosed[bracket';
      compiler.compile(invalidPattern);

      expect(compiler.isPatternValid(invalidPattern), isFalse);
    });

    test('isPatternValid returns true for valid patterns', () {
      final validPattern = r'^test@example\.com$';
      compiler.compile(validPattern);

      expect(compiler.isPatternValid(validPattern), isTrue);
    });

    test('invalid pattern cached as never-match fallback', () {
      final invalidPattern = r'(unclosed(group';
      final regex = compiler.compile(invalidPattern);

      // Should return a fallback pattern that never matches
      expect(regex, isNotNull);
      expect(regex.hasMatch('anything'), isFalse);
      expect(regex.hasMatch(''), isFalse);
      expect(regex.hasMatch('(unclosed(group'), isFalse);
    });

    test('failed patterns count included in stats', () {
      compiler.compile(r'[invalid');
      compiler.compile(r'(unclosed');
      compiler.compile(r'^valid$');  // Valid pattern

      final stats = compiler.getStats();
      expect(stats['failed_patterns'], equals(2));
      expect(stats['cached_patterns'], equals(3)); // All cached (valid + invalid)
    });

    test('multiple invalid patterns tracked separately', () {
      final invalid1 = r'[unclosed';
      final invalid2 = r'(unclosed';
      final invalid3 = r'*invalid';

      compiler.compile(invalid1);
      compiler.compile(invalid2);
      compiler.compile(invalid3);

      final failures = compiler.compilationFailures;
      expect(failures.length, equals(3));
      expect(failures.keys, containsAll([invalid1, invalid2, invalid3]));
    });

    test('clear() removes all failures', () {
      compiler.compile(r'[invalid');
      compiler.compile(r'(unclosed');

      expect(compiler.compilationFailures, isNotEmpty);

      compiler.clear();

      expect(compiler.compilationFailures, isEmpty);
      expect(compiler.getStats()['failed_patterns'], equals(0));
    });

    test('compilationFailures returns unmodifiable map', () {
      compiler.compile(r'[invalid');
      final failures = compiler.compilationFailures;

      // Attempting to modify should throw
      expect(() => failures['new'] = 'error', throwsUnsupportedError);
    });

    test('recompiling invalid pattern uses cached fallback', () {
      final invalidPattern = r'[unclosed';

      // First compile - creates fallback
      final regex1 = compiler.compile(invalidPattern);
      final stats1 = compiler.getStats();

      // Second compile - uses cache
      final regex2 = compiler.compile(invalidPattern);
      final stats2 = compiler.getStats();

      // Should be same object (cached)
      expect(identical(regex1, regex2), isTrue);
      expect(stats2['cache_hits'], equals(stats1['cache_hits']! + 1));

      // Should still be tracked as failure only once
      expect(compiler.compilationFailures.length, equals(1));
    });
  });
}
