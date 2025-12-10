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
}
